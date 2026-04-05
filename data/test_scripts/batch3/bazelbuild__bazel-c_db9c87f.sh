#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 700db56ed782afb11ff25b65ba4651a8bc4a3e6a \
    "src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD b/src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD
--- a/src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD
@@ -221,6 +221,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/analysis:configured_target",
         "//src/main/java/com/google/devtools/build/lib/cmdline",
         "//src/main/java/com/google/devtools/build/lib/rules/cpp",
+        "//src/main/java/net/starlark/java/eval",
         "//src/test/java/com/google/devtools/build/lib/analysis/util",
         "//third_party:guava",
         "//third_party:guava-testlib",
diff --git a/src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java b/src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java
--- a/src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java
+++ b/src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java
@@ -27,6 +27,7 @@
 import com.google.devtools.build.lib.cmdline.Label;
 import com.google.devtools.build.lib.rules.cpp.CcCompilationHelper.SourceCategory;
 import com.google.devtools.build.lib.rules.cpp.CcToolchainFeatures.FeatureConfiguration;
+import net.starlark.java.eval.Tuple;
 import org.junit.Test;
 import org.junit.runner.RunWith;
 import org.junit.runners.JUnit4;
@@ -59,8 +60,10 @@ public void testConstructorThrowsNPE() throws Exception {
             target.getLabel(),
             MockCppSemantics.INSTANCE,
             FeatureConfiguration.EMPTY,
+            SourceCategory.CC,
             ccToolchain,
             fdoContext,
+            ruleContext.getConfiguration(),
             /* executionInfo= */ ImmutableMap.of(),
             /* shouldProcessHeaders= */ true));
   }
@@ -79,11 +82,13 @@ public void testCanIgnoreObjcSource() throws Exception {
                 ruleContext.getLabel(),
                 MockCppSemantics.INSTANCE,
                 FeatureConfiguration.EMPTY,
+                SourceCategory.CC,
                 ccToolchain,
                 fdoContext,
+                ruleContext.getConfiguration(),
                 /* executionInfo= */ ImmutableMap.of(),
                 /* shouldProcessHeaders= */ true)
-            .addSources(objcSrc);
+            .addSources(Tuple.of(objcSrc));
 
     ImmutableList.Builder<Artifact> helperArtifacts = ImmutableList.builder();
     for (CppSource source : helper.getCompilationUnitSources()) {
@@ -113,7 +118,7 @@ public void testCanConsumeObjcSource() throws Exception {
                 ruleContext.getConfiguration(),
                 ImmutableMap.of(),
                 /* shouldProcessHeaders= */ true)
-            .addSources(objcSrc);
+            .addSources(Tuple.of(objcSrc));
 
     ImmutableList.Builder<Artifact> helperArtifacts = ImmutableList.builder();
     for (CppSource source : helper.getCompilationUnitSources()) {
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export JAVA_VERSION=21
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the CcCompilationHelperTest
echo "=== Running CcCompilationHelperTest ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/rules/cpp:CcCompilationHelperTest

rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 700db56ed782afb11ff25b65ba4651a8bc4a3e6a \
    "src/test/java/com/google/devtools/build/lib/rules/cpp/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/cpp/CcCompilationHelperTest.java"

exit $rc