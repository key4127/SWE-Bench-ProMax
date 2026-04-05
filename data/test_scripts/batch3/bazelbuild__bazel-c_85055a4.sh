#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 8cae022d5b8681ca0d68a31ffb7b4cb7a955f1fe "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java
@@ -100,41 +100,26 @@ public void expectCheckedInvalidConfiguration_withDuplicateActiveDirectories() t
   }
 
   @Test
-  public void expectCheckedInvalidConfiguration_withNoActiveDirectoriesOrProjectScl()
-      throws Exception {
+  public void noActiveDirectoriesOrProjectScl_fallsBackToFullSerialization() throws Exception {
     write(
         "foo/BUILD",
         """
         package_group(name = "empty")
         """);
-    addOptions(UPLOAD_MODE_OPTION);
-    InvalidConfigurationException e =
-        assertThrows(InvalidConfigurationException.class, () -> buildTarget("//foo:empty"));
-    assertThat(e)
-        .hasMessageThat()
-        .contains(
-            "Active directories configuration error: No active directories definitions found in"
-                + " --experimental_active_directories or PROJECT.scl");
+    assertUploadSuccess("//foo:empty");
+    assertContainsEvent("No active directories were found. Falling back on full serialization.");
   }
 
   @Test
-  public void expectCheckedInvalidConfiguration_withExplicitEmptyActiveDirectoriesFlag()
-      throws Exception {
+  public void explicitEmptyActiveDirectoriesFlag_fallsBackToFullSerialization() throws Exception {
     write("foo/BUILD", "filegroup(name='A', srcs = [])");
     addOptions("--experimental_active_directories=");
-    addOptions(UPLOAD_MODE_OPTION);
-    InvalidConfigurationException e =
-        assertThrows(InvalidConfigurationException.class, () -> buildTarget("//foo:A"));
-    assertThat(e)
-        .hasMessageThat()
-        .contains(
-            "Active directories configuration error: No active directories definitions found in"
-                + " --experimental_active_directories or PROJECT.scl");
+    assertUploadSuccess("//foo:A");
+    assertContainsEvent("No active directories were found. Falling back on full serialization.");
   }
 
   @Test
-  public void expectCheckedInvalidConfiguration_withNoActiveDirectoriesInProjectScl()
-      throws Exception {
+  public void noActiveDirectoriesInProjectScl_fallsBackToFullSerialization() throws Exception {
     write("foo/BUILD", "filegroup(name='A', srcs = [])");
     writeProjectSclDefinition("test/project_proto.scl", /* alsoWriteBuildFile= */ true);
     write(
@@ -143,47 +128,17 @@ public void expectCheckedInvalidConfiguration_withNoActiveDirectoriesInProjectSc
 load("//test:project_proto.scl", "project_pb2")
 project = project_pb2.Project.create(project_directories = []) # empty
 """);
-    addOptions(UPLOAD_MODE_OPTION);
-    InvalidConfigurationException e =
-        assertThrows(InvalidConfigurationException.class, () -> buildTarget("//foo:A"));
-    assertThat(e)
-        .hasMessageThat()
-        .contains(
-            "Active directories configuration error: No active directories definitions found in"
-                + " --experimental_active_directories or PROJECT.scl");
+    assertUploadSuccess("//foo:A");
+    assertContainsEvent("No active directories were found. Falling back on full serialization.");
   }
 
   @Test
-  public void
-      expectCheckedInvalidConfiguration_withOnlyExcludedDirectories_withActiveDirectoriesFlag()
-          throws Exception {
+  public void onlyExcludedDirectories_withActiveDirectoriesFlag_fallsBackToFullSerialization()
+      throws Exception {
     write("foo/BUILD", "filegroup(name='A', srcs = [])");
     addOptions("--experimental_active_directories=-foo");
-    addOptions(UPLOAD_MODE_OPTION);
-    InvalidConfigurationException e =
-        assertThrows(InvalidConfigurationException.class, () -> buildTarget("//foo:A"));
-    assertThat(e)
-        .hasMessageThat()
-        .contains(
-            "Active directories configuration error: No active directories definitions found in"
-                + " --experimental_active_directories or PROJECT.scl");
-  }
-
-  @Test
-  public void serializingFrontierWithNoProjectFile_withActiveDirectoriesFlag_serializesKeys()
-      throws Exception {
-    setupScenarioWithConfiguredTargets();
-
-    addOptions("--experimental_active_directories=foo");
-    addOptions(UPLOAD_MODE_OPTION);
-
-    buildTarget("//foo:A");
-
-    assertThat(
-            getCommandEnvironment()
-                .getRemoteAnalysisCachingEventListener()
-                .getSerializedKeysCount())
-        .isAtLeast(1);
+    assertUploadSuccess("//foo:A");
+    assertContainsEvent("No active directories were found. Falling back on full serialization.");
   }
 
   @Test
@@ -788,7 +743,6 @@ public void dumpUploadManifestOnlyMode_forTopLevelGenruleConfiguredTarget() thro
 ACTIVE: CONFIGURED_TARGET:ConfiguredTargetKey{label=//A:A, config=
 ACTIVE: CONFIGURED_TARGET:ConfiguredTargetKey{label=//A:A, config=
 ACTIVE: CONFIGURED_TARGET:ConfiguredTargetKey{label=//A:in.txt, config=null}
-ACTION_EXECUTION:ActionLookupData0{actionLookupKey=ConfiguredTargetKey{label=//A:copy_of_A, config=
 """
             .lines()
             .collect(toImmutableList());
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the tests in the serialization/analysis package
# Since SkycacheIntegrationTestBase is a base class, we run all tests in the package
echo "=== Running tests for SkycacheIntegrationTestBase and related tests ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:all

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 8cae022d5b8681ca0d68a31ffb7b4cb7a955f1fe "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/SkycacheIntegrationTestBase.java"