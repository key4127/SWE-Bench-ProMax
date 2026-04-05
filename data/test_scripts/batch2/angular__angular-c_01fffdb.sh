#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 329cf9fbde24044315356a64579d08dc1059981e "packages/core/rxjs-interop/test/rx_resource_spec.ts" "packages/core/test/resource/resource_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/rxjs-interop/test/rx_resource_spec.ts b/packages/core/rxjs-interop/test/rx_resource_spec.ts
--- a/packages/core/rxjs-interop/test/rx_resource_spec.ts
+++ b/packages/core/rxjs-interop/test/rx_resource_spec.ts
@@ -26,12 +26,14 @@ describe('rxResource()', () => {
   it('should cancel the fetch when a new request comes in', async () => {
     const injector = TestBed.inject(Injector);
     const appRef = TestBed.inject(ApplicationRef);
-    let unsub = false;
     const request = signal(1);
-    const res = rxResource({
+    let unsub = false;
+    let lastSeenRequest: number = 0;
+    rxResource({
       request,
-      loader: ({request}) =>
-        new Observable((sub) => {
+      loader: ({request}) => {
+        lastSeenRequest = request;
+        return new Observable((sub) => {
           if (request === 2) {
             sub.next(true);
           }
@@ -40,12 +42,13 @@ describe('rxResource()', () => {
               unsub = true;
             }
           };
-        }),
+        });
+      },
       injector,
     });
 
     // Wait for the resource to reach loading state.
-    await waitFor(() => res.isLoading());
+    await waitFor(() => lastSeenRequest === 1);
 
     // Setting request = 2 should cancel request = 1
     request.set(2);
diff --git a/packages/core/test/resource/resource_spec.ts b/packages/core/test/resource/resource_spec.ts
--- a/packages/core/test/resource/resource_spec.ts
+++ b/packages/core/test/resource/resource_spec.ts
@@ -7,6 +7,7 @@
  */
 
 import {
+  ApplicationRef,
   createEnvironmentInjector,
   EnvironmentInjector,
   Injector,
@@ -81,22 +82,13 @@ describe('resource', () => {
       injector: TestBed.inject(Injector),
     });
 
-    // a freshly created resource is in the idle state
-    expect(echoResource.status()).toBe(ResourceStatus.Idle);
-    expect(echoResource.isLoading()).toBeFalse();
-    expect(echoResource.hasValue()).toBeFalse();
-    expect(echoResource.value()).toBeUndefined();
-    expect(echoResource.error()).toBe(undefined);
-
-    // flush effect to kick off a request
-    // THINK: testing patterns around a resource?
-    TestBed.flushEffects();
+    // a freshly created resource is in the loading state
     expect(echoResource.status()).toBe(ResourceStatus.Loading);
     expect(echoResource.isLoading()).toBeTrue();
     expect(echoResource.hasValue()).toBeFalse();
     expect(echoResource.value()).toBeUndefined();
     expect(echoResource.error()).toBe(undefined);
-
+    TestBed.flushEffects();
     await backend.flush();
     expect(echoResource.status()).toBe(ResourceStatus.Resolved);
     expect(echoResource.isLoading()).toBeFalse();
@@ -362,6 +354,9 @@ describe('resource', () => {
     expect(res.error()).toBe(undefined);
 
     res.reload();
+    expect(res.status()).toBe(ResourceStatus.Reloading);
+    expect(res.value()).toBe('0:0');
+
     TestBed.flushEffects();
     await backend.flush();
     expect(res.status()).toBe(ResourceStatus.Resolved);
@@ -411,4 +406,94 @@ describe('resource', () => {
     // @ts-expect-error
     readonlyRes.value.set;
   });
+
+  it('should synchronously change states', async () => {
+    const request = signal<number | undefined>(undefined);
+    const backend = new MockEchoBackend();
+    const echoResource = resource({
+      request,
+      loader: (params) => backend.fetch(params.request),
+      injector: TestBed.inject(Injector),
+    });
+    // Idle to start.
+    expect(echoResource.status()).toBe(ResourceStatus.Idle);
+    // Switch to loading state should be synchronous.
+    request.set(1);
+    expect(echoResource.status()).toBe(ResourceStatus.Loading);
+    // And back to idle.
+    request.set(undefined);
+    expect(echoResource.status()).toBe(ResourceStatus.Idle);
+    // Allow the load to proceed.
+    request.set(2);
+    TestBed.flushEffects();
+    await backend.flush();
+    expect(echoResource.status()).toBe(ResourceStatus.Resolved);
+    // Reload state should be synchronous.
+    echoResource.reload();
+    expect(echoResource.status()).toBe(ResourceStatus.Reloading);
+    // Back to idle.
+    request.set(undefined);
+    expect(echoResource.status()).toBe(ResourceStatus.Idle);
+  });
+  it('set() should abort a pending load', async () => {
+    const request = signal<number | undefined>(1);
+    const backend = new MockEchoBackend();
+    const echoResource = resource({
+      request,
+      loader: (params) => backend.fetch(params.request),
+      injector: TestBed.inject(Injector),
+    });
+    const appRef = TestBed.inject(ApplicationRef);
+    // Fully resolve the resource to start.
+    TestBed.flushEffects();
+    await backend.flush();
+    expect(echoResource.status()).toBe(ResourceStatus.Resolved);
+    // Trigger loading state.
+    request.set(2);
+    expect(echoResource.status()).toBe(ResourceStatus.Loading);
+    // Set the resource to a new value.
+    echoResource.set(3);
+    // Now run the effect, which should be a no-op as the resource was set to a local value.
+    TestBed.flushEffects();
+    // We should still be in local state.
+    expect(echoResource.status()).toBe(ResourceStatus.Local);
+    expect(echoResource.value()).toBe(3);
+    // Flush the resource
+    await backend.flush();
+    await appRef.whenStable();
+    // We should still be in local state.
+    expect(echoResource.status()).toBe(ResourceStatus.Local);
+    expect(echoResource.value()).toBe(3);
+  });
+
+  it('set() should abort a pending reload', async () => {
+    const request = signal<number | undefined>(1);
+    const backend = new MockEchoBackend();
+    const echoResource = resource({
+      request,
+      loader: (params) => backend.fetch(params.request),
+      injector: TestBed.inject(Injector),
+    });
+    const appRef = TestBed.inject(ApplicationRef);
+    // Fully resolve the resource to start.
+    TestBed.flushEffects();
+    await backend.flush();
+    expect(echoResource.status()).toBe(ResourceStatus.Resolved);
+    // Trigger reloading state.
+    echoResource.reload();
+    expect(echoResource.status()).toBe(ResourceStatus.Reloading);
+    // Set the resource to a new value.
+    echoResource.set(3);
+    // Now run the effect, which should be a no-op as the resource was set to a local value.
+    TestBed.flushEffects();
+    // We should still be in local state.
+    expect(echoResource.status()).toBe(ResourceStatus.Local);
+    expect(echoResource.value()).toBe(3);
+    // Flush the resource
+    await backend.flush();
+    await appRef.whenStable();
+    // We should still be in local state.
+    expect(echoResource.status()).toBe(ResourceStatus.Local);
+    expect(echoResource.value()).toBe(3);
+  });
 });
EOF_114329324912

# Run both test targets in a single Bazel command for efficiency
# This executes tests for both rx_resource_spec.ts and resource_spec.ts
bazelisk test \
  //packages/core/rxjs-interop/test:test \
  //packages/core/test/resource:resource \
  --test_output=errors \
  --flaky_test_attempts=1 \
  --jobs=4

# Capture the exit code from the test execution
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 329cf9fbde24044315356a64579d08dc1059981e "packages/core/rxjs-interop/test/rx_resource_spec.ts" "packages/core/test/resource/resource_spec.ts"