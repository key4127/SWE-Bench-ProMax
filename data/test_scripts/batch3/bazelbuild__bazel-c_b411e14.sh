#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 0a4d5dc477bc2ee11472e72a3b5268878e3f73f2 "src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java b/src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java
--- a/src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java
+++ b/src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java
@@ -23,11 +23,13 @@
 import static java.util.concurrent.ForkJoinPool.commonPool;
 import static org.junit.Assert.assertThrows;
 
+import com.google.common.collect.ImmutableList;
 import com.google.common.collect.Lists;
 import com.google.common.util.concurrent.Futures;
 import com.google.common.util.concurrent.ListenableFuture;
 import com.google.common.util.concurrent.SettableFuture;
-import com.google.devtools.build.lib.concurrent.RequestBatcher.RequestResponse;
+import com.google.devtools.build.lib.concurrent.RequestBatcher.Operation;
+import com.google.devtools.build.lib.concurrent.RequestBatcher.ResponseSink;
 import com.google.devtools.build.lib.unsafe.UnsafeProvider;
 
 import java.lang.ref.Cleaner;
@@ -77,7 +79,7 @@ public void queueOverflow_sleeps() throws Exception {
             /* maxBatchSize= */ batchSize - 1,
             /* maxConcurrentRequests= */ 1);
     ListenableFuture<Response> response0 = batcher.submit(new Request(0));
-    BatchedRequestResponses requestResponses0 = multiplexer.queue.take();
+    BatchedOperations requestResponses0 = multiplexer.queue.take();
     // The first worker is busy until requestResponse0 is populated.
 
     var responses = new ArrayList<ListenableFuture<Response>>();
@@ -132,7 +134,7 @@ public void submitWithWorkersFull_enqueuesThenExecutes() throws Exception {
         RequestBatcher.<Request, Response>create(
             commonPool(), multiplexer, /* maxBatchSize= */ 255, /* maxConcurrentRequests= */ 1);
     ListenableFuture<Response> response1 = batcher.submit(new Request(1));
-    BatchedRequestResponses requestResponses1 = multiplexer.queue.take();
+    BatchedOperations requestResponses1 = multiplexer.queue.take();
 
     ListenableFuture<Response> response2 = batcher.submit(new Request(2));
     // The first batch is not yet complete. The 2nd request waits in an internal queue. Ideally, we
@@ -143,7 +145,7 @@ public void submitWithWorkersFull_enqueuesThenExecutes() throws Exception {
     requestResponses1.setSimpleResponses();
 
     // With the first batch done, the worker picks up the enqueued 2nd request and executes it.
-    BatchedRequestResponses requestResponses2 = multiplexer.queue.take();
+    BatchedOperations requestResponses2 = multiplexer.queue.take();
     requestResponses2.setSimpleResponses();
 
     assertThat(response1.get()).isEqualTo(new Response(1));
@@ -167,10 +169,9 @@ public void concurrentWorkCompletion_startsNewWorker() throws Exception {
     long countersAddress = getAlignedAddress(baseAddress, /* offset= */ 0);
     var batcher =
         new RequestBatcher<Request, Response>(
-            /* responseDistributionExecutor= */ commonPool(),
             /* queueDrainingExecutor= */ queueDrainingExecutor,
-            (RequestBatcher.Multiplexer<Request, Response>)
-                requests -> immediateFuture(respondTo(requests)),
+            RequestBatcher.createBatchExecutionStrategy(
+                requests -> immediateFuture(respondTo(requests)), commonPool()),
             /* maxBatchSize= */ 255,
             /* maxConcurrentRequests= */ 1,
             countersAddress,
@@ -358,7 +359,7 @@ public void perResponseMultiplexer_missingFuture_throwsIllegalState() throws Exc
           @Override
           public void execute(
               List<Request> requests,
-              List<? extends RequestBatcher.FutureResponseSink<Response>> sinks) {
+              ImmutableList<? extends RequestBatcher.FutureResponseSink<Response>> sinks) {
             // Faulty implementation: only sets the first future in the batch, and "forgets" to set
             // the rest.
             var futureResponse = SettableFuture.<Response>create();
@@ -421,52 +422,250 @@ public void execute(Runnable command) {
     ListenableFuture<Response> response = batcher.submit(new Request(1));
     response.cancel(true);
 
-    BatchedRequestResponses requestResponses = multiplexer.queue.take();
+    BatchedOperations requestResponses = multiplexer.queue.take();
     requestResponses.setSimpleResponses();
 
     assertThat(response.isCancelled()).isTrue();
     assertThat(uncaughtException.get()).isNull();
   }
 
-  private static class FakeConcurrentFifo
-      extends ConcurrentFifo<RequestResponse<Request, Response>> {
-    private final ConcurrentLinkedQueue<RequestResponse<Request, Response>> queue =
+  @Test
+  public void callbackMultiplexer_allSucceed() throws Exception {
+    var events = new LinkedBlockingQueue<BatcherEvent>();
+    RequestBatcher<Request, Response> batcher = createCallbackMultiplexerBatcher(events);
+
+    ListenableFuture<Response> response1 = batcher.submit(new Request(1));
+    // A batch begins executing immediately with response1.
+    var firstBatch = (BatchOperation) events.poll();
+
+    // The next 2 requests are enqueued.
+    ListenableFuture<Response> response2 = batcher.submit(new Request(2));
+    ListenableFuture<Response> response3 = batcher.submit(new Request(3));
+
+    // No other batches have started and no callbacks have been called.
+    assertThat(events.poll()).isNull();
+
+    firstBatch.defaultReplyAll();
+    assertThat(response1.get()).isEqualTo(new Response(1));
+
+    // The done callback is always called first.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+
+    var secondBatch = (BatchOperation) events.take();
+    secondBatch.defaultReplyAll();
+    assertThat(response2.get()).isEqualTo(new Response(2));
+    assertThat(response3.get()).isEqualTo(new Response(3));
+
+    // The done callback is called after the 2nd batch completes.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+  }
+
+  private sealed interface BatcherEvent {}
+
+  private enum DoneCallbackCalled implements BatcherEvent {
+    INSTANCE
+  }
+
+  private record BatchOperation(
+      List<Request> requests, ImmutableList<? extends ResponseSink<Response>> sinks)
+      implements BatcherEvent {
+    private void defaultReplyAll() {
+      for (int i = 0; i < requests.size(); i++) {
+        sinks.get(i).acceptResponse(new Response(requests.get(i).x()));
+      }
+    }
+
+    private void failAll(Throwable t) {
+      for (ResponseSink<Response> sink : sinks) {
+        sink.acceptFailure(t);
+      }
+    }
+  }
+
+  private static RequestBatcher<Request, Response> createCallbackMultiplexerBatcher(
+      LinkedBlockingQueue<BatcherEvent> events) {
+    var multiplexer =
+        new RequestBatcher.CallbackMultiplexer<Request, Response>() {
+          @Override
+          public Runnable execute(
+              List<Request> requests, ImmutableList<? extends ResponseSink<Response>> sinks) {
+            assertThat(requests).hasSize(sinks.size());
+            events.offer(new BatchOperation(requests, sinks));
+            return () -> events.offer(DoneCallbackCalled.INSTANCE);
+          }
+        };
+
+    return RequestBatcher.<Request, Response>create(
+        commonPool(), multiplexer, /* maxBatchSize= */ 1, /* maxConcurrentRequests= */ 1);
+  }
+
+  @Test
+  public void callbackMultiplexer_allFail() throws Exception {
+    var events = new LinkedBlockingQueue<BatcherEvent>();
+    RequestBatcher<Request, Response> batcher = createCallbackMultiplexerBatcher(events);
+
+    var failure = new RuntimeException("Test Failure");
+
+    ListenableFuture<Response> response1 = batcher.submit(new Request(1));
+
+    // A batch begins executing immediately with response1.
+    var firstBatch = (BatchOperation) events.poll();
+
+    // The next 2 requests are enqueued.
+    ListenableFuture<Response> response2 = batcher.submit(new Request(2));
+    ListenableFuture<Response> response3 = batcher.submit(new Request(3));
+
+    assertThat(events.poll()).isNull(); // No new events have occurred.
+
+    firstBatch.failAll(failure);
+    var e1 = assertThrows(ExecutionException.class, response1::get);
+    assertThat(e1).hasCauseThat().isEqualTo(failure);
+
+    // The done callback is always called before the next batch starts.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+
+    var secondBatch = (BatchOperation) events.take();
+    secondBatch.failAll(failure);
+
+    var e2 = assertThrows(ExecutionException.class, response2::get);
+    assertThat(e2).hasCauseThat().isEqualTo(failure);
+    var e3 = assertThrows(ExecutionException.class, response3::get);
+    assertThat(e3).hasCauseThat().isEqualTo(failure);
+
+    // The done callback is called after the 2nd batch completes.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+  }
+
+  @Test
+  public void callbackMultiplexer_mixedSuccessFailure() throws Exception {
+    var events = new LinkedBlockingQueue<BatcherEvent>();
+    RequestBatcher<Request, Response> batcher = createCallbackMultiplexerBatcher(events);
+
+    ListenableFuture<Response> response1 = batcher.submit(new Request(1));
+    // A batch begins executing immediately with response1.
+    var firstBatch = (BatchOperation) events.poll();
+
+    // The next 2 requests are enqueued.
+    ListenableFuture<Response> response2 = batcher.submit(new Request(2));
+    ListenableFuture<Response> response3 = batcher.submit(new Request(3));
+
+    assertThat(events.poll()).isNull(); // No new events have occurred.
+
+    firstBatch.defaultReplyAll();
+    assertThat(response1.get()).isEqualTo(new Response(1));
+
+    // The done callback is always called before the next batch starts.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+
+    var secondBatch = (BatchOperation) events.take();
+
+    var failure = new IllegalArgumentException("Bad Request");
+
+    assertThat(secondBatch.sinks).hasSize(2);
+
+    secondBatch.sinks.get(0).acceptResponse(new Response(secondBatch.requests.get(0).x()));
+    secondBatch.sinks.get(1).acceptFailure(failure);
+
+    assertThat(response2.get()).isEqualTo(new Response(2));
+    var e3 = assertThrows(ExecutionException.class, response3::get);
+    assertThat(e3).hasCauseThat().isEqualTo(failure);
+
+    // The done callback is called after the 2nd batch completes.
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+  }
+
+  @Test
+  public void callbackMultiplexer_nullResponse() throws Exception {
+    var events = new LinkedBlockingQueue<BatcherEvent>();
+    RequestBatcher<Request, Response> batcher = createCallbackMultiplexerBatcher(events);
+
+    ListenableFuture<Response> response1 = batcher.submit(new Request(1));
+
+    var batch = (BatchOperation) events.poll();
+    batch.sinks.get(0).acceptResponse(null);
+
+    assertThat(response1.get()).isNull();
+
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+  }
+
+  @Test
+  public void callbackMultiplexer_batching() throws Exception {
+    var events = new LinkedBlockingQueue<BatcherEvent>();
+    RequestBatcher<Request, Response> batcher = createCallbackMultiplexerBatcher(events);
+
+    // These should form three batches: (1), (2, 3), (4, 5)
+    ListenableFuture<Response> response1 = batcher.submit(new Request(1));
+    ListenableFuture<Response> response2 = batcher.submit(new Request(2));
+    ListenableFuture<Response> response3 = batcher.submit(new Request(3));
+    ListenableFuture<Response> response4 = batcher.submit(new Request(4));
+    ListenableFuture<Response> response5 = batcher.submit(new Request(5));
+
+    var batch1 = (BatchOperation) events.take();
+
+    assertThat(batch1.requests()).containsExactly(new Request(1));
+    batch1.defaultReplyAll();
+
+    assertThat(response1.get()).isEqualTo(new Response(1));
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+
+    var batch2 = (BatchOperation) events.take();
+    assertThat(batch2.requests()).containsExactly(new Request(2), new Request(3)).inOrder();
+    batch2.defaultReplyAll();
+
+    assertThat(response2.get()).isEqualTo(new Response(2));
+    assertThat(response3.get()).isEqualTo(new Response(3));
+
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+
+    var batch3 = (BatchOperation) events.take();
+    assertThat(batch3.requests()).containsExactly(new Request(4), new Request(5)).inOrder();
+    batch3.defaultReplyAll();
+
+    assertThat(response4.get()).isEqualTo(new Response(4));
+    assertThat(response5.get()).isEqualTo(new Response(5));
+
+    assertThat(events.take()).isEqualTo(DoneCallbackCalled.INSTANCE);
+  }
+
+  private static class FakeConcurrentFifo extends ConcurrentFifo<Operation<Request, Response>> {
+    private final ConcurrentLinkedQueue<Operation<Request, Response>> queue =
         new ConcurrentLinkedQueue<>();
 
     private final Semaphore tryAppendTokens = new Semaphore(0);
     private final Semaphore appendPermits = new Semaphore(0);
 
     private FakeConcurrentFifo(long sizeAddress, long appendIndexAddress, long takeIndexAddress) {
-      super(RequestResponse.class, sizeAddress, appendIndexAddress, takeIndexAddress);
+      super(Operation.class, sizeAddress, appendIndexAddress, takeIndexAddress);
     }
 
     @Override
-    boolean tryAppend(RequestResponse<Request, Response> task) {
+    boolean tryAppend(Operation<Request, Response> task) {
       tryAppendTokens.release();
       appendPermits.acquireUninterruptibly();
       queue.add(task);
       return true;
     }
 
     @Override
-    RequestResponse<Request, Response> take() {
+    Operation<Request, Response> take() {
       return queue.poll();
     }
   }
 
   private static class SettableMultiplexer
       implements RequestBatcher.Multiplexer<Request, Response> {
-    private final LinkedBlockingQueue<BatchedRequestResponses> queue = new LinkedBlockingQueue<>();
+    private final LinkedBlockingQueue<BatchedOperations> queue = new LinkedBlockingQueue<>();
 
     @Override
     public ListenableFuture<List<Response>> execute(List<Request> requests) {
       var responses = SettableFuture.<List<Response>>create();
-      queue.add(new BatchedRequestResponses(requests, responses));
+      queue.add(new BatchedOperations(requests, responses));
       return responses;
     }
   }
 
-  private record BatchedRequestResponses(
+  private record BatchedOperations(
       List<Request> requests, SettableFuture<List<Response>> responses) {
     private void setSimpleResponses() {
       responses().set(respondTo(requests()));
@@ -488,7 +687,8 @@ private static class PerResponseSettableMultiplexer
 
     @Override
     public void execute(
-        List<Request> requests, List<? extends RequestBatcher.FutureResponseSink<Response>> sinks) {
+        List<Request> requests,
+        ImmutableList<? extends RequestBatcher.FutureResponseSink<Response>> sinks) {
       assertThat(requests).hasSize(sinks.size());
 
       List<SettableFuture<Response>> settableFutures = new ArrayList<>();
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test target for RequestBatcherTest
echo "=== Running RequestBatcherTest ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/concurrent:ConcurrentTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 0a4d5dc477bc2ee11472e72a3b5268878e3f73f2 "src/test/java/com/google/devtools/build/lib/concurrent/RequestBatcherTest.java"