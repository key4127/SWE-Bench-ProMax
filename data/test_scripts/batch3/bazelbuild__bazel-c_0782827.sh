#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 37a74a725e7f025f56b49877983a5cf8f51c6449 "src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java b/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
--- a/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
+++ b/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
@@ -111,6 +111,7 @@ public Integer get() {
 
   /** MockClassD */
   @StarlarkBuiltin(name = "MockClassD", category = DocCategory.BUILTIN, doc = "MockClassD")
+  @SuppressWarnings("unused") // test code
   private static class MockClassD implements StarlarkValue {
     @StarlarkMethod(
         name = "test",
@@ -137,6 +138,7 @@ public Integer get() {
 
   /** MockClassF */
   @StarlarkBuiltin(name = "MockClassF", category = DocCategory.BUILTIN, doc = "MockClassF")
+  @SuppressWarnings("unused") // test code
   private static class MockClassF implements StarlarkValue {
     @StarlarkMethod(
         name = "test",
@@ -155,6 +157,7 @@ public Integer test(int a, int b, int c, int d, Sequence<?> args) {
 
   /** MockClassG */
   @StarlarkBuiltin(name = "MockClassG", category = DocCategory.BUILTIN, doc = "MockClassG")
+  @SuppressWarnings("unused") // test code
   private static class MockClassG implements StarlarkValue {
     @StarlarkMethod(
         name = "test",
@@ -173,6 +176,7 @@ public Integer test(int a, int b, int c, int d, Dict<?, ?> kwargs) {
 
   /** MockClassH */
   @StarlarkBuiltin(name = "MockClassH", category = DocCategory.BUILTIN, doc = "MockClassH")
+  @SuppressWarnings("unused") // test code
   private static class MockClassH implements StarlarkValue {
     @StarlarkMethod(
         name = "test",
@@ -192,6 +196,7 @@ public Integer test(int a, int b, int c, int d, Sequence<?> args, Dict<?, ?> kwa
 
   /** MockClassI */
   @StarlarkBuiltin(name = "MockClassI", category = DocCategory.BUILTIN, doc = "MockClassI")
+  @SuppressWarnings("unused") // test code
   private static class MockClassI implements StarlarkValue {
     @StarlarkMethod(
         name = "test",
@@ -387,7 +392,7 @@ public void testStarlarkCallableParametersAndArgs() throws Exception {
     assertThat(methodDoc.getSignature())
         .isEqualTo(
             "<a class=\"anchor\" href=\"../core/int.html\">int</a> "
-                + "MockClassF.test(a, b, *, c, d=1, *myArgs)");
+                + "MockClassF.test(a, b, *myArgs, c, d=1)");
     assertThat(methodDoc.getParams()).hasSize(5);
   }
 
@@ -419,7 +424,7 @@ public void testStarlarkCallableParametersAndArgsAndKwargs() throws Exception {
     assertThat(methodDoc.getSignature())
         .isEqualTo(
             "<a class=\"anchor\" href=\"../core/int.html\">int</a> "
-                + "MockClassH.test(a, b, *, c, d=1, *myArgs, **myKwargs)");
+                + "MockClassH.test(a, b, *myArgs, c, d=1, **myKwargs)");
     assertThat(methodDoc.getParams()).hasSize(6);
   }
 
@@ -435,7 +440,7 @@ public void testStarlarkUndocumentedParameters() throws Exception {
     assertThat(methodDoc.getSignature())
         .isEqualTo(
             "<a class=\"anchor\" href=\"../core/int.html\">int</a> "
-                + "MockClassI.test(a, b, *, c, d=1, *myArgs)");
+                + "MockClassI.test(a, b, *myArgs, c, d=1)");
     assertThat(methodDoc.getParams()).hasSize(5);
   }
 
@@ -456,7 +461,7 @@ public void testStarlarkGlobalLibraryCallable() throws Exception {
         assertThat(methodDoc.getSignature())
             .isEqualTo(
                 "<a class=\"anchor\" href=\"../core/int.html\">int</a> "
-                    + "MockGlobalCallable(a, b, *, c, d=1, *myArgs, **myKwargs)");
+                    + "MockGlobalCallable(a, b, *myArgs, c, d=1, **myKwargs)");
         foundGlobalLibrary = true;
         break;
       }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# First, let's check what targets are available in the BUILD file
echo "=== Checking BUILD file for available targets ==="
cat /testbed/src/test/java/com/google/devtools/build/docgen/BUILD | grep -A 5 "StarlarkDocumentationTest" || true

# Query Bazel to find the exact target that includes StarlarkDocumentationTest
echo "=== Querying Bazel for targets containing StarlarkDocumentationTest ==="
bazel query 'attr(srcs, "StarlarkDocumentationTest.java", //src/test/java/com/google/devtools/build/docgen:*)' || true

# Try to run the test using the test filter to specifically target StarlarkDocumentationTest
# This will run only the StarlarkDocumentationTest class within the DocumentationTests suite
bazel test \
    --config=ci-linux \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=com.google.devtools.build.docgen.StarlarkDocumentationTest \
    //src/test/java/com/google/devtools/build/docgen:DocumentationTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 37a74a725e7f025f56b49877983a5cf8f51c6449 "src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java"