#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 91b1e8e28afc7f76ed5930b469b23fd13303eda3 \
    "src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java" \
    "src/test/shell/integration/flagset_test.sh"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java b/src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java
--- a/src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java
@@ -40,20 +40,24 @@ public void buildWithNoProjectFiles() throws Exception {
     scratch.file("pkg/BUILD", "genrule(name='f', cmd = '', srcs=[], outs=['a.out'])");
 
     assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter))
-        .isNull();
+            Project.getProjectFiles(
+                    ImmutableList.of(Label.parseCanonical("//pkg:f")),
+                    getSkyframeExecutor(),
+                    reporter)
+                .isEmpty())
+        .isTrue();
   }
 
   @Test
   public void buildWithOneProjectFile() throws Exception {
     scratch.file("pkg/BUILD", "genrule(name='f', cmd = '', srcs=[], outs=['a.out'])");
     scratch.file("pkg/" + PROJECT_FILE_NAME, "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter))
-        .isEqualTo(Label.parseCanonical("//pkg:" + PROJECT_FILE_NAME));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//pkg:" + PROJECT_FILE_NAME));
   }
 
   @Test
@@ -63,12 +67,12 @@ public void buildWithTwoProjectFiles() throws Exception {
     scratch.file("foo/" + PROJECT_FILE_NAME, "project = {}");
     scratch.file("foo/bar/" + PROJECT_FILE_NAME, "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//foo/bar:f")),
-                getSkyframeExecutor(),
-                reporter))
-        .isEqualTo(Label.parseCanonical("//foo/bar:PROJECT.scl"));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//foo/bar:f")), getSkyframeExecutor(), reporter);
+
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//foo/bar:" + PROJECT_FILE_NAME));
   }
 
   @Test
@@ -77,13 +81,14 @@ public void twoTargetsSameProjectFile() throws Exception {
     scratch.file("foo/BUILD", "genrule(name='parent', cmd = '', srcs=[], outs=['p.out'])");
     scratch.file("foo/" + PROJECT_FILE_NAME, "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(
-                    Label.parseCanonical("//foo:parent"), Label.parseCanonical("//foo/bar:child")),
-                getSkyframeExecutor(),
-                reporter))
-        .isEqualTo(Label.parseCanonical("//foo:" + PROJECT_FILE_NAME));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(
+                Label.parseCanonical("//foo:parent"), Label.parseCanonical("//foo/bar:child")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//foo:" + PROJECT_FILE_NAME));
   }
 
   @Test
@@ -93,27 +98,45 @@ public void twoTargetsDifferentProjectFiles() throws Exception {
     scratch.file("foo/" + PROJECT_FILE_NAME, "project = {}");
     scratch.file("bar/" + PROJECT_FILE_NAME, "project = {}");
 
-    var thrown =
-        assertThrows(
-            ProjectResolutionException.class,
-            () ->
-                Project.getProjectFile(
-                    ImmutableList.of(
-                        Label.parseCanonical("//foo:f"), Label.parseCanonical("//bar:g")),
-                    getSkyframeExecutor(),
-                    reporter));
-    assertThat(thrown)
-        .hasMessageThat()
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//foo:f"), Label.parseCanonical("//bar:g")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(
+            Label.parseCanonical("//foo:" + PROJECT_FILE_NAME),
+            Label.parseCanonical("//bar:" + PROJECT_FILE_NAME));
+    assertThat(projectFiles.differentProjectsDetails())
         .contains(
             """
-This build doesn't support automatic project resolution. Targets have different project settings:
+Targets have different project settings:
   - //foo:f -> //foo:PROJECT.scl
   - //bar:g -> //bar:PROJECT.scl\
 """);
   }
 
   @Test
-  public void twoTargetsOnlyOneHasProjectFile() throws Exception {}
+  public void twoTargetsOnlyOneHasProjectFile() throws Exception {
+    scratch.file("foo/BUILD", "genrule(name='f', cmd = '', srcs=[], outs=['f.out'])");
+    scratch.file("bar/BUILD", "genrule(name='g', cmd = '', srcs=[], outs=['g.out'])");
+    scratch.file("foo/" + PROJECT_FILE_NAME, "project = {}");
+
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//foo:f"), Label.parseCanonical("//bar:g")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//foo:" + PROJECT_FILE_NAME));
+    assertThat(projectFiles.differentProjectsDetails())
+        .contains(
+            """
+Targets have different project settings:
+  - //foo:f -> //foo:PROJECT.scl
+  - //bar:g -> no project file\
+""");
+  }
 
   @Test
   public void innermostPackageIsAParentDirectory() throws Exception {
@@ -123,12 +146,13 @@ public void innermostPackageIsAParentDirectory() throws Exception {
     // Doesn't count because it's not colocated with a BUILD file:
     scratch.file("pkg/subdir" + PROJECT_FILE_NAME, "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//pkg/subdir:fake_target")),
-                getSkyframeExecutor(),
-                reporter))
-        .isEqualTo(Label.parseCanonical("//pkg:" + PROJECT_FILE_NAME));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg/subdir:fake_target")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//pkg:" + PROJECT_FILE_NAME));
   }
 
   @Test
@@ -144,10 +168,11 @@ public void aliasProjectFile() throws Exception {
     scratch.file("canonical/BUILD");
     scratch.file("canonical/PROJECT.scl", "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter))
-        .isEqualTo(Label.parseCanonical("//canonical:PROJECT.scl"));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//canonical:PROJECT.scl"));
   }
 
   @Test
@@ -165,7 +190,7 @@ public void aliasActualAttributeWrongType() throws Exception {
         assertThrows(
             ProjectResolutionException.class,
             () ->
-                Project.getProjectFile(
+                Project.getProjectFiles(
                     ImmutableList.of(Label.parseCanonical("//pkg:f")),
                     getSkyframeExecutor(),
                     reporter));
@@ -190,7 +215,7 @@ public void aliasWithExtraProjectData() throws Exception {
         assertThrows(
             ProjectResolutionException.class,
             () ->
-                Project.getProjectFile(
+                Project.getProjectFiles(
                     ImmutableList.of(Label.parseCanonical("//pkg:f")),
                     getSkyframeExecutor(),
                     reporter));
@@ -215,7 +240,7 @@ public void aliasWithExtraGlobalSymbol() throws Exception {
         assertThrows(
             ProjectResolutionException.class,
             () ->
-                Project.getProjectFile(
+                Project.getProjectFiles(
                     ImmutableList.of(Label.parseCanonical("//pkg:f")),
                     getSkyframeExecutor(),
                     reporter));
@@ -243,7 +268,7 @@ public void aliasRefDoesntExist() throws Exception {
         assertThrows(
             ProjectResolutionException.class,
             () ->
-                Project.getProjectFile(
+                Project.getProjectFiles(
                     ImmutableList.of(Label.parseCanonical("//pkg:f")),
                     getSkyframeExecutor(),
                     reporter));
@@ -276,10 +301,11 @@ public void aliasToAlias() throws Exception {
     scratch.file("canonical/BUILD");
     scratch.file("canonical/PROJECT.scl", "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter))
-        .isEqualTo(Label.parseCanonical("//canonical:PROJECT.scl"));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg:f")), getSkyframeExecutor(), reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//canonical:PROJECT.scl"));
   }
 
   @Test
@@ -303,13 +329,13 @@ public void sameProjectFileAfterAliasResolution() throws Exception {
     scratch.file("canonical/BUILD");
     scratch.file("canonical/PROJECT.scl", "project = {}");
 
-    assertThat(
-            Project.getProjectFile(
-                ImmutableList.of(
-                    Label.parseCanonical("//pkg1:f"), Label.parseCanonical("//pkg2:g")),
-                getSkyframeExecutor(),
-                reporter))
-        .isEqualTo(Label.parseCanonical("//canonical:PROJECT.scl"));
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg1:f"), Label.parseCanonical("//pkg2:g")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.projectFiles())
+        .containsExactly(Label.parseCanonical("//canonical:PROJECT.scl"));
   }
 
   @Test
@@ -335,20 +361,15 @@ public void differentProjectFilesAfterAliasResolution() throws Exception {
     scratch.file("canonical2/BUILD");
     scratch.file("canonical2/PROJECT.scl", "project = {}");
 
-    var thrown =
-        assertThrows(
-            ProjectResolutionException.class,
-            () ->
-                Project.getProjectFile(
-                    ImmutableList.of(
-                        Label.parseCanonical("//pkg1:f"), Label.parseCanonical("//pkg2:g")),
-                    getSkyframeExecutor(),
-                    reporter));
-    assertThat(thrown)
-        .hasMessageThat()
+    var projectFiles =
+        Project.getProjectFiles(
+            ImmutableList.of(Label.parseCanonical("//pkg1:f"), Label.parseCanonical("//pkg2:g")),
+            getSkyframeExecutor(),
+            reporter);
+    assertThat(projectFiles.differentProjectsDetails())
         .contains(
             """
-This build doesn't support automatic project resolution. Targets have different project settings:
+Targets have different project settings:
   - //pkg1:f -> //canonical1:PROJECT.scl
   - //pkg2:g -> //canonical2:PROJECT.scl\
 """);
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
@@ -33,7 +33,6 @@ java_library(
         "//third_party:guava",
         "//third_party:jsr305",
         "//third_party:junit4",
-        "//third_party:mockito",
         "//third_party:truth",
         "//third_party/pprof:profile_java_proto",
         "@com_google_protobuf//:protobuf_java",
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java
@@ -161,9 +161,7 @@ public void serializingWithMultipleTopLevelProjectFiles_hasError() throws Except
         assertThrows(LoadingFailedException.class, () -> buildTarget("//foo:empty", "//bar:empty"));
     assertThat(exception)
         .hasMessageThat()
-        .contains(
-            "This build doesn't support automatic project resolution. Targets have different"
-                + " project settings:");
+        .contains("Skycache only works on single-project builds. This is a multi-project build");
   }
 
   @Test
diff --git a/src/test/shell/integration/flagset_test.sh b/src/test/shell/integration/flagset_test.sh
--- a/src/test/shell/integration/flagset_test.sh
+++ b/src/test/shell/integration/flagset_test.sh
@@ -136,7 +136,12 @@ function test_scl_config_plus_external_target_in_test_suite_fails(){
   # This failure kicks in as soon as there's a valid project file, even if it
   # doesn't contain any configs.
   cat > test/PROJECT.scl <<EOF
-project = {}
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
 EOF
   cat >> test/BUILD <<EOF
 test_suite(name='test_suite', tests=['//other:other'])
@@ -153,10 +158,178 @@ EOF
 echo hi
 EOF
 
-  bazel build --nobuild //test:test_suite //other:other &> "$TEST_log" && \
-    fail "expected build to fail"
+  bazel build --nobuild //test:test_suite //other:other --scl_config=test_config \
+    &> "$TEST_log" && fail "expected build to fail"
+
+  expect_log "Can't set --scl_config for a build where only some targets have projects."
+}
+
+function test_multi_project_builds_fail_with_scl_config(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p test2
+  cat > test2/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test2/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
+
+  bazel build --nobuild //test1:g //test2:h --scl_config=test_config \
+    &> "$TEST_log" && fail "expected build to fail"
+
+  expect_log "Can't set --scl_config for a multi-project build."
+}
+
+function test_multi_project_builds_succeed_with_consistent_default_config(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p test2
+  cat > test2/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test2/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
+
+  bazel build --nobuild //test1:g //test2:h  \
+    &> "$TEST_log" || fail "expected success"
+}
+
+function test_multi_project_builds_succeed_with_no_defined_configs(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p test2
+  cat > test2/PROJECT.scl <<EOF
+project = {
+}
+EOF
+  cat > test2/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
+
+  bazel build --nobuild //test1:g //test2:h  \
+    &> "$TEST_log" || fail "expected success"
+}
+
+function test_multi_project_builds_fail_with_inconsistent_default_configs(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p test2
+  cat > test2/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=baz"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test2/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
+
+  bazel build --nobuild //test1:g //test2:h \
+    &> "$TEST_log" && fail "expected build to fail"
+
+  expect_log "Mismatching default configs for a multi-project build."
+}
+
+function test_partial_project_builds_fail_with_non_noop_default_config(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": ["--define=foo=bar"],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p noproject
+  cat > noproject/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
+
+  bazel build --nobuild //test1:g //noproject:h \
+    &> "$TEST_log" && fail "expected build to fail"
+
+  expect_log "Mismatching default configs for a build where only some targets have projects."
+}
+
+function test_partial_project_builds_succeed_with_noop_default_config(){
+  mkdir -p test1
+  cat > test1/PROJECT.scl <<EOF
+project = {
+  "configs": {
+    "test_config": [],
+  },
+  "default_config" : "test_config"
+}
+EOF
+  cat > test1/BUILD <<EOF
+genrule(name='g', outs=['g.txt'], cmd='echo hi > \$@')
+EOF
+
+  mkdir -p noproject
+  cat > noproject/BUILD <<EOF
+genrule(name='h', outs=['h.txt'], cmd='echo hi > \$@')
+EOF
 
-  expect_log "This build doesn't support automatic project resolution"
+  bazel build --nobuild //test1:g //noproject:h \
+    &> "$TEST_log" || fail "expected success"
 }
 
 run_suite "Integration tests for flagsets/scl_config"
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
    --config=ci-linux \
    --test_output=errors \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/buildtool:ProjectResolutionTest \
    //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:all \
    //src/test/shell/integration:flagset_test

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 91b1e8e28afc7f76ed5930b469b23fd13303eda3 \
    "src/test/java/com/google/devtools/build/lib/buildtool/ProjectResolutionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FrontierSerializerTestBase.java" \
    "src/test/shell/integration/flagset_test.sh"