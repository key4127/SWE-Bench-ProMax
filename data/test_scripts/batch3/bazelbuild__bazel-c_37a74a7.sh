#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 820ad5de20ba876ed81b4e2ebe1bcf2568412632 "src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java b/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
--- a/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
+++ b/src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java
@@ -25,14 +25,13 @@
 import com.google.devtools.build.docgen.annot.GlobalMethods.Environment;
 import com.google.devtools.build.docgen.annot.StarlarkConstructor;
 import com.google.devtools.build.docgen.starlark.AnnotStarlarkConstructorMethodDoc;
-import com.google.devtools.build.docgen.starlark.AnnotStarlarkMethodDoc;
+import com.google.devtools.build.docgen.starlark.MemberDoc;
 import com.google.devtools.build.docgen.starlark.StarlarkDoc;
 import com.google.devtools.build.docgen.starlark.StarlarkDocExpander;
 import com.google.devtools.build.docgen.starlark.StarlarkDocPage;
 import com.google.devtools.build.lib.analysis.starlark.StarlarkGlobalsImpl;
 import com.google.devtools.build.lib.analysis.starlark.StarlarkRuleContext;
 import com.google.devtools.build.lib.collect.nestedset.Depset;
-import java.util.Collection;
 import java.util.List;
 import java.util.Map;
 import java.util.stream.Collectors;
@@ -77,7 +76,7 @@ private void checkStarlarkTopLevelEnvItemsAreDocumented(Map<String, Object> glob
     ImmutableSet<String> documentedItems =
         Stream.concat(
                 allPages.get(Category.GLOBAL_FUNCTION).stream()
-                    .flatMap(p -> p.getMethods().stream()),
+                    .flatMap(p -> p.getMembers().stream()),
                 allPages.entrySet().stream()
                     .filter(e -> !e.getKey().equals(Category.GLOBAL_FUNCTION))
                     .flatMap(e -> e.getValue().stream()))
@@ -366,8 +365,8 @@ public void testStarlarkCallableParameters() throws Exception {
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassD");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassD#test");
     assertThat(methodDoc.getSignature())
         .isEqualTo(
@@ -382,8 +381,8 @@ public void testStarlarkCallableParametersAndArgs() throws Exception {
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassF");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassF#test");
     assertThat(methodDoc.getSignature())
         .isEqualTo(
@@ -398,8 +397,8 @@ public void testStarlarkCallableParametersAndKwargs() throws Exception {
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassG");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassG#test");
     assertThat(methodDoc.getSignature())
         .isEqualTo(
@@ -414,8 +413,8 @@ public void testStarlarkCallableParametersAndArgsAndKwargs() throws Exception {
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassH");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassH#test");
     assertThat(methodDoc.getSignature())
         .isEqualTo(
@@ -430,8 +429,8 @@ public void testStarlarkUndocumentedParameters() throws Exception {
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassI");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassI#test");
     assertThat(methodDoc.getSignature())
         .isEqualTo(
@@ -451,7 +450,7 @@ public void testStarlarkGlobalLibraryCallable() throws Exception {
             .get();
 
     boolean foundGlobalLibrary = false;
-    for (AnnotStarlarkMethodDoc methodDoc : topLevel.getMethods()) {
+    for (MemberDoc methodDoc : topLevel.getMembers()) {
       if (methodDoc.getName().equals("MockGlobalCallable")) {
         assertThat(methodDoc.getDocumentation()).isEqualTo("GlobalCallable documentation");
         assertThat(methodDoc.getSignature())
@@ -475,8 +474,8 @@ public void testStarlarkCallableOverriding() throws Exception {
             .findAny()
             .get();
     assertThat(moduleDoc.getDocumentation()).isEqualTo("MockClassE");
-    assertThat(moduleDoc.getMethods()).hasSize(1);
-    AnnotStarlarkMethodDoc methodDoc = moduleDoc.getMethods().iterator().next();
+    assertThat(moduleDoc.getMembers()).hasSize(1);
+    MemberDoc methodDoc = moduleDoc.getMembers().getFirst();
     assertThat(methodDoc.getDocumentation()).isEqualTo("MockClassA#get");
     assertThat(methodDoc.getSignature())
         .isEqualTo("<a class=\"anchor\" href=\"../core/int.html\">int</a> MockClassE.get()");
@@ -488,7 +487,7 @@ public void testStarlarkContainerReturnTypesWithoutAnnotations() throws Exceptio
         collect(MockClassWithContainerReturnValues.class);
     assertThat(objects.get(Category.BUILTIN)).hasSize(1);
     StarlarkDocPage moduleDoc = objects.get(Category.BUILTIN).get(0);
-    Collection<? extends AnnotStarlarkMethodDoc> methods = moduleDoc.getMethods();
+    ImmutableList<? extends MemberDoc> methods = moduleDoc.getMembers();
 
     List<String> signatures =
         methods.stream().map(m -> m.getSignature()).collect(Collectors.toList());
@@ -522,12 +521,12 @@ public void testDocumentedModuleTakesPrecedence() throws Exception {
             PointsToCommonNameAndUndocumentedModule.class,
             MockClassCommonNameOne.class,
             MockClassCommonNameUndocumented.class);
-    Collection<? extends AnnotStarlarkMethodDoc> methods =
+    ImmutableList<MemberDoc> methods =
         objects.get(Category.BUILTIN).stream()
             .filter(p -> p.getTitle().equals("MockClassCommonName"))
             .findAny()
             .get()
-            .getMethods();
+            .getMembers();
     List<String> methodNames = methods.stream().map(m -> m.getName()).collect(Collectors.toList());
     assertThat(methodNames).containsExactly("one");
   }
@@ -539,12 +538,12 @@ public void testDocumentModuleSubclass() {
             PointsToCommonNameOneWithSubclass.class,
             MockClassCommonNameOne.class,
             SubclassOfMockClassCommonNameOne.class);
-    Collection<? extends AnnotStarlarkMethodDoc> methods =
+    ImmutableList<MemberDoc> methods =
         objects.get(Category.BUILTIN).stream()
             .filter(p -> p.getTitle().equals("MockClassCommonName"))
             .findAny()
             .get()
-            .getMethods();
+            .getMembers();
     List<String> methodNames = methods.stream().map(m -> m.getName()).collect(Collectors.toList());
     assertThat(methodNames).containsExactly("one", "two");
   }
@@ -553,13 +552,13 @@ public void testDocumentModuleSubclass() {
   public void testDocumentSelfcallConstructor() {
     ImmutableMap<Category, ImmutableList<StarlarkDocPage>> objects =
         collect(MockClassA.class, MockClassWithSelfCallConstructor.class);
-    Collection<? extends AnnotStarlarkMethodDoc> methods =
+    ImmutableList<MemberDoc> methods =
         objects.get(Category.BUILTIN).stream()
             .filter(p -> p.getTitle().equals("MockClassA"))
             .findAny()
             .get()
-            .getMethods();
-    AnnotStarlarkMethodDoc firstMethod = methods.iterator().next();
+            .getMembers();
+    MemberDoc firstMethod = methods.getFirst();
     assertThat(firstMethod).isInstanceOf(AnnotStarlarkConstructorMethodDoc.class);
 
     List<String> methodNames = methods.stream().map(m -> m.getName()).collect(Collectors.toList());
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test
# Based on the collected information, the test target is //src/test/java/com/google/devtools/build/docgen:DocumentationTests
# We use --test_filter to run only StarlarkDocumentationTest
echo "=== Running StarlarkDocumentationTest ==="
bazel test \
    --config=ci-linux \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=StarlarkDocumentationTest \
    //src/test/java/com/google/devtools/build/docgen:DocumentationTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 820ad5de20ba876ed81b4e2ebe1bcf2568412632 "src/test/java/com/google/devtools/build/docgen/StarlarkDocumentationTest.java"