#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout b44530d79eda6ac03a7f0e9dec220259b65c060b \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
@@ -52,7 +52,9 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization:serialization_module",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:long_version_getter_test_injection",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:remote_analysis_caching_services_supplier",
         "//src/main/java/com/google/devtools/build/lib/versioning:long_version_getter",
+        "//third_party:guava",
         "//third_party:junit4",
         "//third_party:mockito",
         "//third_party:truth",
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java
@@ -14,9 +14,11 @@
 package com.google.devtools.build.lib.skyframe.serialization.analysis;
 
 import static com.google.common.truth.Truth.assertThat;
+import static com.google.common.util.concurrent.Futures.immediateFuture;
 import static com.google.devtools.build.lib.skyframe.serialization.analysis.LongVersionGetterTestInjection.injectVersionGetterForTesting;
 import static org.mockito.Mockito.mock;
 
+import com.google.common.util.concurrent.ListenableFuture;
 import com.google.devtools.build.lib.runtime.BlazeRuntime;
 import com.google.devtools.build.lib.skyframe.SkyFunctions;
 import com.google.devtools.build.lib.skyframe.serialization.FingerprintValueService;
@@ -37,11 +39,22 @@ public void injectVersionGetter() {
   }
 
   private class ModuleWithOverrides extends SerializationModule {
+    @Override
+    protected RemoteAnalysisCachingServicesSupplier getAnalysisCachingServicesSupplier() {
+      return new TestServicesSupplier(service);
+    }
+  }
+
+  private static class TestServicesSupplier implements RemoteAnalysisCachingServicesSupplier {
+    private final ListenableFuture<FingerprintValueService> wrappedService;
+
+    private TestServicesSupplier(FingerprintValueService fingerprintValueService) {
+      this.wrappedService = immediateFuture(fingerprintValueService);
+    }
 
     @Override
-    protected FingerprintValueService.Factory getFingerprintValueServiceFactory() {
-      // service is re-instantiated for each test case with a @Before setup step.
-      return (unused) -> service;
+    public ListenableFuture<FingerprintValueService> getFingerprintValueService() {
+      return wrappedService;
     }
   }
 
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
@@ -76,16 +76,18 @@
 public abstract class FrontierSerializerTestBase extends BuildIntegrationTestCase {
   @Rule public TestName testName = new TestName();
 
-  protected FingerprintValueService service;
+  /**
+   * A unique instance of the fingerprint value service per test case.
+   *
+   * <p>This ensures that test cases don't share state. The instance will then last the lifetime of
+   * the test case, regardless of the number of command invocations.
+   */
+  protected FingerprintValueService service = createFingerprintValueService();
+
   private final ClearCountingSyscallCache syscallCache = new ClearCountingSyscallCache();
 
   @Before
   public void setup() {
-    // Give each test case a unique instance of the fingerprint value service, so that test cases
-    // don't share state. This instance will then last the lifetime of the test case, regardless
-    // of the number of command invocations.
-    service = createFingerprintValueService();
-
     // TODO: b/367284400 - replace this with a barebones diffawareness check that works in Bazel
     // integration tests (e.g. making LocalDiffAwareness supported and not return
     // EVERYTHING_MODIFIED) for baseline diffs.
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test
# Based on the collected information, the test target is:
# //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:FrontierSerializerTest
echo "=== Running FrontierSerializerTest ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --test_summary=detailed \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:FrontierSerializerTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout b44530d79eda6ac03a7f0e9dec220259b65c060b \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java"