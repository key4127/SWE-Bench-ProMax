#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout cd0ef838d94af2a647125fdcb7c8055bc257c6b5 "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java" "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java
--- a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java
+++ b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java
@@ -47,7 +47,7 @@ public static ModuleKey createModuleKey(String name, String version) {
 
   public static DepSpec createDepSpec(String name, String version, int maxCompatibilityLevel) {
     try {
-      return DepSpec.create(name, Version.parse(version), maxCompatibilityLevel);
+      return new DepSpec(name, Version.parse(version), maxCompatibilityLevel);
     } catch (Version.ParseException e) {
       throw new IllegalArgumentException(e);
     }
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java
--- a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java
@@ -120,7 +120,7 @@ public void diamond_withIgnoredNonAffectingMaxCompatibilityLevel() throws Except
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "1.0", 3))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -137,7 +137,7 @@ public void diamond_withIgnoredNonAffectingMaxCompatibilityLevel() throws Except
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "1.0", 3))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -182,7 +182,7 @@ public void diamond_withSelectedNonAffectingMaxCompatibilityLevel() throws Excep
                 .addOriginalDep("ddd_from_bbb", createModuleKey("ddd", "1.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
-                .addDep("ddd_from_ccc", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_ccc", createDepSpec("ddd", "2.0", 4))
                 .addOriginalDep("ddd_from_ccc", createDepSpec("ddd", "2.0", 4))
                 .buildEntry(),
             InterimModuleBuilder.create("ddd", "2.0", 1).buildEntry())
@@ -200,7 +200,7 @@ public void diamond_withSelectedNonAffectingMaxCompatibilityLevel() throws Excep
                 .addOriginalDep("ddd_from_bbb", createModuleKey("ddd", "1.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
-                .addDep("ddd_from_ccc", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_ccc", createDepSpec("ddd", "2.0", 4))
                 .addOriginalDep("ddd_from_ccc", createDepSpec("ddd", "2.0", 4))
                 .buildEntry(),
             InterimModuleBuilder.create("ddd", "1.0", 1).buildEntry(),
@@ -429,7 +429,7 @@ public void maxCompatibilityBasedSelection() throws Exception {
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 2))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "1.0", 2))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -446,7 +446,7 @@ public void maxCompatibilityBasedSelection() throws Exception {
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 2))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "1.0", 2))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -486,7 +486,7 @@ public void maxCompatibilityBasedSelection_sameVersion() throws Exception {
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -503,7 +503,7 @@ public void maxCompatibilityBasedSelection_sameVersion() throws Exception {
                 .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
                 .buildEntry(),
             InterimModuleBuilder.create("bbb", "1.0")
-                .addDep("ddd_from_bbb", createModuleKey("ddd", "2.0"))
+                .addDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .addOriginalDep("ddd_from_bbb", createDepSpec("ddd", "2.0", 3))
                 .buildEntry(),
             InterimModuleBuilder.create("ccc", "2.0")
@@ -591,7 +591,7 @@ public void maxCompatibilityBasedSelection_unreferencedNotSelected() throws Exce
                 .setKey(ModuleKey.ROOT)
                 .addDep("bbb", createModuleKey("bbb", "1.1"))
                 .addOriginalDep("bbb", createModuleKey("bbb", "1.0"))
-                .addDep("ccc", createModuleKey("ccc", "1.1"))
+                .addDep("ccc", createDepSpec("ccc", "1.1", 2))
                 .addOriginalDep("ccc", createDepSpec("ccc", "1.0", 2))
                 .addDep("ddd", createModuleKey("ddd", "1.0"))
                 .addDep("eee", createModuleKey("eee", "1.0"))
@@ -612,7 +612,7 @@ public void maxCompatibilityBasedSelection_unreferencedNotSelected() throws Exce
                 .setKey(ModuleKey.ROOT)
                 .addDep("bbb", createModuleKey("bbb", "1.1"))
                 .addOriginalDep("bbb", createModuleKey("bbb", "1.0"))
-                .addDep("ccc", createModuleKey("ccc", "1.1"))
+                .addDep("ccc", createDepSpec("ccc", "1.1", 2))
                 .addOriginalDep("ccc", createDepSpec("ccc", "1.0", 2))
                 .addDep("ddd", createModuleKey("ddd", "1.0"))
                 .addDep("eee", createModuleKey("eee", "1.0"))
@@ -632,6 +632,133 @@ public void maxCompatibilityBasedSelection_unreferencedNotSelected() throws Exce
                 .buildEntry());
   }
 
+  @Test
+  public void maxCompatibilityBasedSelection_withMultipleVersionOverride() throws Exception {
+    ImmutableMap<ModuleKey, InterimModule> depGraph =
+        ImmutableMap.<ModuleKey, InterimModule>builder()
+            .put(
+                InterimModuleBuilder.create("aaa", Version.EMPTY)
+                    .setKey(ModuleKey.ROOT)
+                    .addDep("bbb_from_aaa", createModuleKey("bbb", "1.0"))
+                    .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
+                    .buildEntry())
+            .put(
+                InterimModuleBuilder.create("bbb", "1.0")
+                    .addDep("ccc_from_bbb", createDepSpec("ccc", "1.5", 2))
+                    .buildEntry())
+            .put(InterimModuleBuilder.create("ccc", "1.0").buildEntry())
+            .put(InterimModuleBuilder.create("ccc", "1.5").buildEntry())
+            .put(InterimModuleBuilder.create("ccc", "2.0", 2).buildEntry())
+            .buildOrThrow();
+    ImmutableMap<String, ModuleOverride> overrides =
+        ImmutableMap.of(
+            "ccc",
+            MultipleVersionOverride.create(
+                ImmutableList.of(Version.parse("1.0"), Version.parse("2.0")), ""));
+
+    Selection.Result selectionResult = Selection.run(depGraph, overrides);
+    assertThat(selectionResult.resolvedDepGraph().entrySet())
+        .containsExactly(
+            InterimModuleBuilder.create("aaa", Version.EMPTY)
+                .setKey(ModuleKey.ROOT)
+                .addDep("bbb_from_aaa", createModuleKey("bbb", "1.0"))
+                .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("bbb", "1.0")
+                .addDep("ccc_from_bbb", createDepSpec("ccc", "2.0", 2))
+                .addOriginalDep("ccc_from_bbb", createDepSpec("ccc", "1.5", 2))
+                .buildEntry(),
+            InterimModuleBuilder.create("ccc", "2.0", 2).buildEntry())
+        .inOrder();
+
+    assertThat(selectionResult.unprunedDepGraph().entrySet())
+        .containsExactly(
+            InterimModuleBuilder.create("aaa", Version.EMPTY)
+                .setKey(ModuleKey.ROOT)
+                .addDep("bbb_from_aaa", createModuleKey("bbb", "1.0"))
+                .addDep("ccc_from_aaa", createModuleKey("ccc", "2.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("bbb", "1.0")
+                .addDep("ccc_from_bbb", createDepSpec("ccc", "2.0", 2))
+                .addOriginalDep("ccc_from_bbb", createDepSpec("ccc", "1.5", 2))
+                .buildEntry(),
+            InterimModuleBuilder.create("ccc", "1.0").buildEntry(),
+            InterimModuleBuilder.create("ccc", "1.5").buildEntry(),
+            InterimModuleBuilder.create("ccc", "2.0", 2).buildEntry())
+        .inOrder();
+  }
+
+  @Test
+  public void maxCompatibilityBasedSelection_nonGreedySelection() throws Exception {
+    // A dep graph in which always picking the highest (or lowest) reachable compatibility level for
+    // each module does *not* result in a valid selection: c@1.0 and b@2.0 mutually depend on each
+    // other and so do c@2.0 and b@1.0.
+    ImmutableMap<ModuleKey, InterimModule> depGraph =
+        ImmutableMap.<ModuleKey, InterimModule>builder()
+            .put(
+                InterimModuleBuilder.create("aaa", Version.EMPTY)
+                    .setKey(ModuleKey.ROOT)
+                    .addDep("bbb_from_aaa", createDepSpec("bbb", "1.0", 2))
+                    .addDep("ccc_from_aaa", createDepSpec("ccc", "1.0", 2))
+                    .buildEntry())
+            .put(
+                InterimModuleBuilder.create("bbb", "1.0", 1)
+                    .addDep("ccc_from_bbb", createModuleKey("ccc", "2.0"))
+                    .buildEntry())
+            .put(
+                InterimModuleBuilder.create("bbb", "2.0", 2)
+                    .addDep("ccc_from_bbb", createModuleKey("ccc", "1.0"))
+                    .buildEntry())
+            .put(
+                InterimModuleBuilder.create("ccc", "1.0", 1)
+                    .addDep("bbb_from_ccc", createModuleKey("bbb", "2.0"))
+                    .buildEntry())
+            .put(
+                InterimModuleBuilder.create("ccc", "2.0", 2)
+                    .addDep("bbb_from_ccc", createModuleKey("bbb", "1.0"))
+                    .buildEntry())
+            .buildOrThrow();
+
+    Selection.Result selectionResult = Selection.run(depGraph, ImmutableMap.of());
+    assertThat(selectionResult.resolvedDepGraph().entrySet())
+        .containsExactly(
+            InterimModuleBuilder.create("aaa", Version.EMPTY)
+                .setKey(ModuleKey.ROOT)
+                .addDep("bbb_from_aaa", createDepSpec("bbb", "1.0", 2))
+                .addDep("ccc_from_aaa", createDepSpec("ccc", "2.0", 2))
+                .addOriginalDep("ccc_from_aaa", createDepSpec("ccc", "1.0", 2))
+                .buildEntry(),
+            InterimModuleBuilder.create("bbb", "1.0", 1)
+                .addDep("ccc_from_bbb", createModuleKey("ccc", "2.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("ccc", "2.0", 2)
+                .addDep("bbb_from_ccc", createModuleKey("bbb", "1.0"))
+                .buildEntry())
+        .inOrder();
+
+    assertThat(selectionResult.unprunedDepGraph().entrySet())
+        .containsExactly(
+            InterimModuleBuilder.create("aaa", Version.EMPTY)
+                .setKey(ModuleKey.ROOT)
+                .addDep("bbb_from_aaa", createDepSpec("bbb", "1.0", 2))
+                .addDep("ccc_from_aaa", createDepSpec("ccc", "2.0", 2))
+                .addOriginalDep("ccc_from_aaa", createDepSpec("ccc", "1.0", 2))
+                .buildEntry(),
+            InterimModuleBuilder.create("bbb", "1.0", 1)
+                .addDep("ccc_from_bbb", createModuleKey("ccc", "2.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("bbb", "2.0", 2)
+                .addDep("ccc_from_bbb", createModuleKey("ccc", "1.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("ccc", "1.0", 1)
+                .addDep("bbb_from_ccc", createModuleKey("bbb", "2.0"))
+                .buildEntry(),
+            InterimModuleBuilder.create("ccc", "2.0", 2)
+                .addDep("bbb_from_ccc", createModuleKey("bbb", "1.0"))
+                .buildEntry())
+        .inOrder();
+  }
+
   @Test
   public void differentCompatibilityLevelIsOkIfUnreferenced() throws Exception {
     // aaa 1.0 -> bbb 1.0 -> ccc 2.0
@@ -811,6 +938,9 @@ public void multipleVersionOverride_fork_sameVersionUsedTwice() throws Exception
         .containsMatch(
             "aaa@_ depends on bbb@1.5 at least twice \\(with repo names (bbb2 and bbb3)|(bbb3 and"
                 + " bbb2)\\)");
+    assertThat(e)
+        .hasMessageThat()
+        .contains("if you want to depend on multiple versions of bbb simultaneously");
   }
 
   @Test
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory as required by pre-test setup
mkdir -p $HOME/bazeltest

# Run the BzlmodTests suite which includes SelectionTest and uses BzlmodTestUtil
# Using --config=ci-linux as specified in the test execution requirements
# Using --test_filter to run only SelectionTest to focus on the actual test file
bazel test \
    --config=ci-linux \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=com.google.devtools.build.lib.bazel.bzlmod.SelectionTest \
    //src/test/java/com/google/devtools/build/lib/bazel/bzlmod:BzlmodTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout cd0ef838d94af2a647125fdcb7c8055bc257c6b5 "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BzlmodTestUtil.java" "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/SelectionTest.java"