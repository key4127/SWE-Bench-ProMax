#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 9b32dd2fd384bc8adefd39595f897e99c024a25f \
    "src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java" \
    "src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java" \
    "src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java" \
    "src/test/java/com/google/devtools/build/lib/runtime/BUILD" \
    "src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java" \
    "src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java b/src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java
--- a/src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java
+++ b/src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java
@@ -68,7 +68,7 @@ public final class ResourceManagerTest {
 
   private final FileSystem fs = new InMemoryFileSystem(DigestHashFunction.SHA256);
   private final ActionExecutionMetadata resourceOwner = new ResourceOwnerStub();
-  private final ResourceManager manager = ResourceManager.instanceForTestingOnly();
+  private final ResourceManager manager = new ResourceManager();
   private Worker worker;
   private WorkerProcessStatus workerStatus;
   private AtomicInteger counter;
diff --git a/src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java b/src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java
--- a/src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java
+++ b/src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java
@@ -212,7 +212,7 @@ public Subprocess create(SubprocessBuilder params) {
     }
   }
 
-  private final ResourceManager resourceManager = ResourceManager.instanceForTestingOnly();
+  private final ResourceManager resourceManager = new ResourceManager();
 
   private static ImmutableMap<String, String> keepLocalEnvUnchanged(
       Map<String, String> env, BinTools binTools, String fallbackTmpDir) {
@@ -412,7 +412,7 @@ public void noProcessWrapper() throws Exception {
             fs.getPath("/execroot"),
             options,
             resourceManager,
-            /*processWrapper=*/ null,
+            /* processWrapper= */ null,
             LocalSpawnRunnerTest::keepLocalEnvUnchanged);
 
     FileOutErr fileOutErr = new FileOutErr(fs.getPath("/out/stdout"), fs.getPath("/out/stderr"));
@@ -846,7 +846,7 @@ public void hasExecutionStatistics() throws Exception {
     // TODO(b/62588075) Currently no process-wrapper or execution statistics support in Windows.
     assumeTrue(OS.getCurrent() != OS.WINDOWS);
 
-    FileSystem fs = new UnixFileSystem(DigestHashFunction.SHA256, /*hashAttributeName=*/ "");
+    FileSystem fs = new UnixFileSystem(DigestHashFunction.SHA256, /* hashAttributeName= */ "");
 
     LocalExecutionOptions options = Options.getDefaults(LocalExecutionOptions.class);
 
@@ -934,7 +934,7 @@ public void relativePath() throws Exception {
             fs.getPath("/execroot"),
             Options.getDefaults(LocalExecutionOptions.class),
             resourceManager,
-            /*processWrapper=*/ null,
+            /* processWrapper= */ null,
             LocalSpawnRunnerTest::keepLocalEnvUnchanged);
 
     FileOutErr fileOutErr = new FileOutErr(fs.getPath("/out/stdout"), fs.getPath("/out/stderr"));
diff --git a/src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java b/src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java
--- a/src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java
+++ b/src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java
@@ -120,7 +120,7 @@ private ByteArrayOutputStream start(ImmutableSet<ProfilerTask> tasks, Profiler.F
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -149,7 +149,7 @@ private void startUnbuffered(ImmutableSet<ProfilerTask> tasks) throws IOExceptio
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -263,7 +263,7 @@ public void testProfilerRecordingAllEvents() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -361,7 +361,7 @@ public void testProfilerWorkerMetrics() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             workerProcessMetricsCollector,
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ true,
             /* collectLoadAverage= */ false,
@@ -407,7 +407,7 @@ public void testProfilerRecordingOnlySlowestEvents() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -541,7 +541,7 @@ public void testProfilerRecordsNothing() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -748,7 +748,7 @@ public long nanoTime() {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -803,7 +803,7 @@ public void write(int b) throws IOException {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -843,7 +843,7 @@ public void write(int b) throws IOException {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -878,7 +878,7 @@ public void testPrimaryOutputForAction() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -928,7 +928,7 @@ public void testTargetLabelForAction() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -978,7 +978,7 @@ public void testTargetConfigurationForAction() throws Exception {
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
@@ -1021,7 +1021,7 @@ private ByteArrayOutputStream getJsonProfileOutputStream(boolean slimProfile) th
         new CollectLocalResourceUsage(
             BugReporter.defaultInstance(),
             WorkerProcessMetricsCollector.instance(),
-            ResourceManager.instance(),
+            new ResourceManager(),
             InMemoryGraph.create(),
             /* collectWorkerDataInProfiler= */ false,
             /* collectLoadAverage= */ false,
diff --git a/src/test/java/com/google/devtools/build/lib/runtime/BUILD b/src/test/java/com/google/devtools/build/lib/runtime/BUILD
--- a/src/test/java/com/google/devtools/build/lib/runtime/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/runtime/BUILD
@@ -38,6 +38,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/actions:execution_requirements",
         "//src/main/java/com/google/devtools/build/lib/actions:file_metadata",
         "//src/main/java/com/google/devtools/build/lib/actions:localhost_capacity",
+        "//src/main/java/com/google/devtools/build/lib/actions:resource_manager",
         "//src/main/java/com/google/devtools/build/lib/analysis:analysis_cluster",
         "//src/main/java/com/google/devtools/build/lib/analysis:analysis_phase_complete_event",
         "//src/main/java/com/google/devtools/build/lib/analysis:blaze_directories",
diff --git a/src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java b/src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java
--- a/src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java
+++ b/src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java
@@ -20,6 +20,7 @@
 
 import com.google.common.collect.ImmutableList;
 import com.google.common.eventbus.EventBus;
+import com.google.devtools.build.lib.actions.ResourceManager;
 import com.google.devtools.build.lib.analysis.BlazeDirectories;
 import com.google.devtools.build.lib.analysis.ServerDirectories;
 import com.google.devtools.build.lib.exec.BinTools;
@@ -259,7 +260,8 @@ private CommandEnvironment createCommandEnvironment(BlazeRuntime runtime) throws
         NO_OP_COMMAND_EXTENSION_REPORTER,
         /* attemptNumber= */ 1,
         /* buildRequestIdOverride= */ null,
-        ConfigFlagDefinitions.NONE);
+        ConfigFlagDefinitions.NONE,
+        new ResourceManager());
   }
 
   private static class FooCommandModule extends BlazeModule {
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java
@@ -878,7 +878,7 @@ public void testSharedActionsNoOutputs() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -986,7 +986,7 @@ public void testSharedActionsRacing() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1134,7 +1134,7 @@ public void testThreeSharedActionsRacing() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1225,7 +1225,7 @@ public void sharedActionsWithTree() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1346,7 +1346,7 @@ public void sharedActionTemplate() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1568,7 +1568,7 @@ public void incrementalSharedActions() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1672,7 +1672,7 @@ public void interruptDoesntSuppressErrorOutput() throws Exception {
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1792,7 +1792,7 @@ public void analysisEventsNotStoredInExecution(@TestParameter boolean skymeld) t
     var unused =
         skyframeExecutor.buildArtifacts(
             reporter,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             new DummyExecutor(fileSystem, rootDirectory),
             ImmutableSet.of(),
             ImmutableSet.of(),
@@ -1977,7 +1977,7 @@ private void runCatastropheHaltsBuild() throws Exception {
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2117,7 +2117,7 @@ public ActionResult execute(ActionExecutionContext actionExecutionContext)
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2241,7 +2241,7 @@ public ActionResult execute(ActionExecutionContext actionExecutionContext)
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2362,7 +2362,7 @@ public Void call() throws ActionExecutionException {
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2473,7 +2473,7 @@ public void testKeepGoingExitCodeWithUserError() throws Exception {
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2570,7 +2570,7 @@ public void testKeepGoingExitCodeWithUserAndInfrastructureError() throws Excepti
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
@@ -2652,7 +2652,7 @@ public NestedSet<Artifact> discoverInputs(ActionExecutionContext actionExecution
     Builder builder =
         new SkyframeBuilder(
             skyframeExecutor,
-            ResourceManager.instanceForTestingOnly(),
+            new ResourceManager(),
             NULL_CHECKER,
             ModifiedFileSet.EVERYTHING_MODIFIED,
             /* fileCache= */ null,
diff --git a/src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java b/src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java
--- a/src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java
+++ b/src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java
@@ -72,9 +72,7 @@
 import org.junit.runners.JUnit4;
 import org.mockito.Mockito;
 
-/**
- * Test StandaloneSpawnStrategy.
- */
+/** Test StandaloneSpawnStrategy. */
 @RunWith(JUnit4.class)
 public class StandaloneSpawnStrategyTest {
   private static final String WINDOWS_SYSTEM_DRIVE = "C:";
@@ -130,7 +128,7 @@ public final void setUp() throws Exception {
     optionsParser.parse("--verbose_failures");
     LocalExecutionOptions localExecutionOptions = Options.getDefaults(LocalExecutionOptions.class);
 
-    ResourceManager resourceManager = ResourceManager.instanceForTestingOnly();
+    ResourceManager resourceManager = new ResourceManager();
     resourceManager.setAvailableResources(
         ResourceSet.create(/* memoryMb= */ 1, /* cpu= */ 1, /* localTestCount= */ 1));
     Path execRoot = directories.getExecRoot(TestConstants.WORKSPACE_NAME);
@@ -169,6 +167,7 @@ private static Spawn createSpawn(String... arguments) {
   private String out() {
     return outErr.outAsLatin1();
   }
+
   private String err() {
     return outErr.errAsLatin1();
   }
@@ -269,10 +268,10 @@ public void testCommandHonorsEnvironment() throws Exception {
             OS.getCurrent() == OS.WINDOWS
                 ? ImmutableList.of(CMD_EXE, "/c", "set")
                 : ImmutableList.of("/usr/bin/env"),
-            /*environment=*/ ImmutableMap.of("foo", "bar", "baz", "boo"),
-            /*executionInfo=*/ ImmutableMap.of(),
-            /*inputs=*/ NestedSetBuilder.emptySet(Order.STABLE_ORDER),
-            /*outputs=*/ ImmutableSet.of(),
+            /* environment= */ ImmutableMap.of("foo", "bar", "baz", "boo"),
+            /* executionInfo= */ ImmutableMap.of(),
+            /* inputs= */ NestedSetBuilder.emptySet(Order.STABLE_ORDER),
+            /* outputs= */ ImmutableSet.of(),
             ResourceSet.ZERO);
     run(spawn);
     HashSet<String> environment = Sets.newHashSet(out().split(System.lineSeparator()));
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export BAZEL_TEST_RLIMIT_INFINITY=1
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Run all target tests in a single Bazel invocation for efficiency
# This combines all test targets to minimize Bazel startup overhead
echo "=== Running all target tests ==="
bazel test \
    --test_output=errors \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/actions:ActionsTests \
    //src/test/java/com/google/devtools/build/lib/exec/local:ExecLocalTests \
    //src/test/java/com/google/devtools/build/lib/profiler:ProfilerTests \
    //src/test/java/com/google/devtools/build/lib/runtime:RuntimeTests \
    //src/test/java/com/google/devtools/build/lib/skyframe:SkyframeTests \
    //src/test/java/com/google/devtools/build/lib/standalone:StandaloneTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 9b32dd2fd384bc8adefd39595f897e99c024a25f \
    "src/test/java/com/google/devtools/build/lib/actions/ResourceManagerTest.java" \
    "src/test/java/com/google/devtools/build/lib/exec/local/LocalSpawnRunnerTest.java" \
    "src/test/java/com/google/devtools/build/lib/profiler/ProfilerTest.java" \
    "src/test/java/com/google/devtools/build/lib/runtime/BUILD" \
    "src/test/java/com/google/devtools/build/lib/runtime/BlazeRuntimeTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/SequencedSkyframeExecutorTest.java" \
    "src/test/java/com/google/devtools/build/lib/standalone/StandaloneSpawnStrategyTest.java"