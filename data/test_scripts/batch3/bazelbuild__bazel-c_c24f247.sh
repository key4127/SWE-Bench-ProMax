#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 11f8f6642db67b3c393426a63ca502e3f72a5e57 "src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java" "src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD" "src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java" "src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java b/src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java
--- a/src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java
+++ b/src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java
@@ -361,10 +361,13 @@ public String toString() {
   public static final ActionTemplateExpansionKey NULL_TEMPLATE_EXPANSION_ARTIFACT_OWNER =
       ActionTemplateExpansionValue.key(NULL_ARTIFACT_OWNER, /*actionIndex=*/ 0);
 
+  @SerializationConstant
+  static final InMemoryFileSystem DUMMY_ARTIFACT_FILE_SYSTEM =
+      new InMemoryFileSystem(DigestHashFunction.SHA256);
+
   public static final Artifact DUMMY_ARTIFACT =
       new Artifact.SourceArtifact(
-          ArtifactRoot.asSourceRoot(
-              Root.absoluteRoot(new InMemoryFileSystem(DigestHashFunction.SHA256))),
+          ArtifactRoot.asSourceRoot(Root.absoluteRoot(DUMMY_ARTIFACT_FILE_SYSTEM)),
           PathFragment.create("/dummy"),
           NULL_ARTIFACT_OWNER);
 
@@ -967,4 +970,22 @@ public void resetOutputs(Iterable<? extends Artifact> outputs) {
       throw new UnsupportedOperationException();
     }
   }
+
+  /**
+   * Ensures the special, meaningless, `memoizedIsInitialized` field in {@link ActionOwner} is set.
+   *
+   * <p>This field is set upon serializing a proto. It's intended to memoize checking that all the
+   * required fields are set. Since the protos in question are proto3, there are no required fields
+   * so the field is meaningless. However, serialization tests sometimes use reflection to compare
+   * the round tripped output to the input.
+   *
+   * <p>In particular, {@link BuildConfigurationEvent} contains a couple of instances of this field.
+   */
+  public static void ensureMemoizedIsInitializedIsSet(ActionAnalysisMetadata action) {
+    BuildConfigurationEvent buildConfigurationEvent =
+        action.getOwner().getBuildConfigurationEvent();
+    assertThat(buildConfigurationEvent.getEventId().isInitialized()).isTrue();
+    assertThat(buildConfigurationEvent.asStreamProto(/* unusedConverters= */ null).isInitialized())
+        .isTrue();
+  }
 }
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD b/src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD
--- a/src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD
@@ -22,8 +22,13 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/actions:thread_state_receiver",
         "//src/main/java/com/google/devtools/build/lib/analysis:analysis_cluster",
         "//src/main/java/com/google/devtools/build/lib/analysis:extra/extra_action_info_file_write_action",
+        "//src/main/java/com/google/devtools/build/lib/analysis/config:build_options",
         "//src/main/java/com/google/devtools/build/lib/collect/nestedset",
         "//src/main/java/com/google/devtools/build/lib/exec:blaze_executor",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/testutils",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/testutils:depsutils",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/testutils:dumper",
         "//src/main/java/com/google/devtools/build/lib/vfs",
         "//src/main/protobuf:extra_actions_base_java_proto",
         "//src/test/java/com/google/devtools/build/lib/actions/util",
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java b/src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java
@@ -15,6 +15,8 @@
 
 import static com.google.common.truth.Truth.assertThat;
 import static com.google.devtools.build.lib.actions.util.ActionsTestUtil.NULL_ACTION_OWNER;
+import static com.google.devtools.build.lib.actions.util.ActionsTestUtil.ensureMemoizedIsInitializedIsSet;
+import static com.google.devtools.build.lib.skyframe.serialization.testutils.Dumper.dumpStructureWithEquivalenceReduction;
 import static org.mockito.Mockito.mock;
 import static org.mockito.Mockito.verify;
 import static org.mockito.Mockito.when;
@@ -43,11 +45,16 @@
 import com.google.devtools.build.lib.actions.extra.JavaCompileInfo;
 import com.google.devtools.build.lib.actions.util.ActionsTestUtil;
 import com.google.devtools.build.lib.actions.util.ActionsTestUtil.NullAction;
+import com.google.devtools.build.lib.analysis.config.BuildOptions.MapBackedChecksumCache;
+import com.google.devtools.build.lib.analysis.config.BuildOptions.OptionsChecksumCache;
 import com.google.devtools.build.lib.collect.nestedset.NestedSetBuilder;
 import com.google.devtools.build.lib.collect.nestedset.Order;
 import com.google.devtools.build.lib.exec.BlazeExecutor;
 import com.google.devtools.build.lib.exec.util.FakeActionInputFileCache;
 import com.google.devtools.build.lib.exec.util.TestExecutorBuilder;
+import com.google.devtools.build.lib.skyframe.serialization.ArrayCodec;
+import com.google.devtools.build.lib.skyframe.serialization.testutils.SerializationDepsUtils;
+import com.google.devtools.build.lib.skyframe.serialization.testutils.SerializationTester;
 import com.google.devtools.build.lib.testutil.FoundationTestCase;
 import com.google.devtools.build.lib.vfs.Path;
 import com.google.devtools.build.lib.vfs.Root;
@@ -206,4 +213,63 @@ public void testUpdateInputsNotPassedToShadowedAction() throws Exception {
     extraAction.updateInputs(NestedSetBuilder.create(Order.STABLE_ORDER, extraIn, discoveredIn));
     verify(shadowedAction, Mockito.never()).updateInputs(ArgumentMatchers.any());
   }
+
+  @Test
+  public void testSerializationRoundTrip_resetsInputs() throws Exception {
+    Path execRoot = scratch.getFileSystem().getPath("/");
+    ArtifactRoot out = ArtifactRoot.asDerivedRoot(execRoot, RootType.Output, "out");
+    ArtifactRoot src = ArtifactRoot.asSourceRoot(Root.fromPath(scratch.dir("/src")));
+    Artifact extraInput = ActionsTestUtil.createArtifact(src, scratch.file("/src/extra.in"));
+    Artifact discoveredInput =
+        ActionsTestUtil.createArtifact(src, scratch.file("/src/discovered.in"));
+    var output =
+        (Artifact.DerivedArtifact)
+            ActionsTestUtil.createArtifact(out, scratch.file("/out/test.out"));
+    output.setGeneratingActionKey(ActionsTestUtil.NULL_ACTION_LOOKUP_DATA);
+    ExtraAction extraAction =
+        new ExtraAction(
+            NULL_ACTION_OWNER,
+            NestedSetBuilder.create(Order.STABLE_ORDER, extraInput),
+            ImmutableSet.of(output),
+            /* shadowedAction= */ new InputDiscoveringNullAction(),
+            /* createDummyOutput= */ false,
+            CommandLine.of(ImmutableList.of()),
+            ActionEnvironment.EMPTY,
+            ImmutableMap.of(),
+            "Executing extra action bla bla",
+            "bla bla");
+    ensureMemoizedIsInitializedIsSet(extraAction);
+    String originalStructure = dumpStructureWithEquivalenceReduction(extraAction);
+
+    extraAction.updateInputs(
+        NestedSetBuilder.create(Order.STABLE_ORDER, extraInput, discoveredInput));
+
+    new SerializationTester(extraAction)
+        .makeMemoizingAndAllowFutureBlocking(/* allowFutureBlocking= */ true)
+        .addCodec(ArrayCodec.forComponentType(Artifact.class))
+        .setVerificationFunction(
+            (unusedInput, deserialized) ->
+                assertThat(dumpStructureWithEquivalenceReduction(deserialized))
+                    .isEqualTo(originalStructure))
+        .addDependencies(getCommonSerializationDependencies())
+        .addDependencies(SerializationDepsUtils.SERIALIZATION_DEPS_FOR_TEST)
+        .addDependency(OptionsChecksumCache.class, new MapBackedChecksumCache())
+        .runTests();
+  }
+
+  /**
+   * Exists to work around the check in {@link
+   * com.google.devtools.build.lib.actions.AbstractAction#updateInputs}.
+   */
+  private static final class InputDiscoveringNullAction extends NullAction {
+    @Override
+    public boolean discoversInputs() {
+      return true;
+    }
+
+    @Override
+    protected boolean inputsDiscovered() {
+      return false;
+    }
+  }
 }
diff --git a/src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java b/src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java
--- a/src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java
+++ b/src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java
@@ -17,6 +17,7 @@
 import static org.junit.Assert.fail;
 
 import com.google.common.base.Splitter;
+import com.google.common.collect.ImmutableClassToInstanceMap;
 import com.google.common.collect.Iterables;
 import com.google.common.eventbus.EventBus;
 import com.google.devtools.build.lib.clock.BlazeClock;
@@ -146,4 +147,11 @@ protected void assertDoesNotContainEvent(String expectedMessage) {
   protected void assertContainsEventsInOrder(String... expectedMessages) {
     MoreAsserts.assertContainsEventsInOrder(eventCollector, expectedMessages);
   }
+
+  protected ImmutableClassToInstanceMap<Object> getCommonSerializationDependencies() {
+    return ImmutableClassToInstanceMap.builder()
+        .put(FileSystem.class, fileSystem)
+        .put(Root.RootCodecDependencies.class, new Root.RootCodecDependencies(root))
+        .build();
+  }
 }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the ExtraActionTest using Bazel
# Based on the collected information, the test target is //src/test/java/com/google/devtools/build/lib/analysis/extra:ExtraActionTest
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/analysis/extra:ExtraActionTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 11f8f6642db67b3c393426a63ca502e3f72a5e57 "src/test/java/com/google/devtools/build/lib/actions/util/ActionsTestUtil.java" "src/test/java/com/google/devtools/build/lib/analysis/extra/BUILD" "src/test/java/com/google/devtools/build/lib/analysis/extra/ExtraActionTest.java" "src/test/java/com/google/devtools/build/lib/testutil/FoundationTestCase.java"