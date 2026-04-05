#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 501f68825d86890b6db0f0a582eb23c8a5301d32 \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java" \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java" \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java b/src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java
--- a/src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java
+++ b/src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java
@@ -114,14 +114,13 @@ public abstract class AbstractBuildEventServiceTransportTest extends FoundationT
   private static final String BUILD_REQUEST_ID = "feedbeef-dead-4321-beef-deaddeaddead";
   private static final String BUILD_INVOCATION_ID = "feedbeef-dead-4444-beef-deaddeaddead";
   private static final String COMMAND_NAME = "test";
-  private static final String ADDITIONAL_KEYWORD = "user_keyword=foo";
+  private static final ImmutableSet<String> KEYWORDS = ImmutableSet.of("foo=bar", "spam=eggs");
   private static final Timestamp COMMAND_START_TIME = Timestamps.fromMillis(500L);
   private static final BuildEventServiceProtoUtil BES_PROTO_UTIL =
       new BuildEventServiceProtoUtil.Builder()
           .buildRequestId(BUILD_REQUEST_ID)
           .invocationId(BUILD_INVOCATION_ID)
-          .commandName(COMMAND_NAME)
-          .keywords(ImmutableSet.of(ADDITIONAL_KEYWORD))
+          .keywords(KEYWORDS)
           .attemptNumber(1)
           .build();
 
diff --git a/src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java b/src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java
--- a/src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java
+++ b/src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java
@@ -674,9 +674,14 @@ public void testKeywords() throws Exception {
     besOptions.besKeywords = ImmutableList.of("keyword0", "keyword1", "keyword0");
     besOptions.besSystemKeywords = ImmutableList.of("sys_keyword0", "sys_keyword1", "sys_keyword0");
 
-    assertThat(besModule.getBesKeywords(besOptions, null))
+    assertThat(besModule.getBesKeywords("build", besOptions, null))
         .containsExactly(
-            "user_keyword=keyword0", "user_keyword=keyword1", "sys_keyword0", "sys_keyword1");
+            "protocol_name=BEP",
+            "command_name=build",
+            "user_keyword=keyword0",
+            "user_keyword=keyword1",
+            "sys_keyword0",
+            "sys_keyword1");
   }
 
   @Test
diff --git a/src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java b/src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java
--- a/src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java
+++ b/src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java
@@ -16,7 +16,6 @@
 
 import static com.google.common.truth.Truth.assertThat;
 
-import com.google.common.collect.ImmutableList;
 import com.google.common.collect.ImmutableSet;
 import com.google.devtools.build.lib.testutil.ManualClock;
 import com.google.devtools.build.v1.BuildEvent;
@@ -48,17 +47,13 @@ public class BuildEventServiceProtoUtilTest {
   private static final String BUILD_REQUEST_ID = "feedbeef-dead-4321-beef-deaddeaddead";
   private static final String BUILD_INVOCATION_ID = "feedbeef-dead-4444-beef-deaddeaddead";
   private static final String PROJECT_ID = "my_project";
-  private static final String COMMAND_NAME = "test";
-  private static final String ADDITIONAL_KEYWORD = "keyword=foo";
-  private static final ImmutableList<String> EXPECTED_KEYWORDS =
-      ImmutableList.of("command_name=" + COMMAND_NAME, "protocol_name=BEP", ADDITIONAL_KEYWORD);
+  private static final ImmutableSet<String> KEYWORDS = ImmutableSet.of("foo=bar", "spam=eggs");
   private static final BuildEventServiceProtoUtil BES_PROTO_UTIL =
       new BuildEventServiceProtoUtil.Builder()
           .buildRequestId(BUILD_REQUEST_ID)
           .invocationId(BUILD_INVOCATION_ID)
           .projectId(PROJECT_ID)
-          .commandName(COMMAND_NAME)
-          .keywords(ImmutableSet.of(ADDITIONAL_KEYWORD))
+          .keywords(KEYWORDS)
           .attemptNumber(1)
           .build();
   private final ManualClock clock = new ManualClock();
@@ -71,7 +66,7 @@ public void testBuildEnqueued() {
             PublishLifecycleEventRequest.newBuilder()
                 .setServiceLevel(ServiceLevel.INTERACTIVE)
                 .setProjectId(PROJECT_ID)
-                .addAllNotificationKeywords(EXPECTED_KEYWORDS)
+                .addAllNotificationKeywords(KEYWORDS)
                 .setBuildEvent(
                     OrderedBuildEvent.newBuilder()
                         .setStreamId(
@@ -94,7 +89,7 @@ public void testInvocationAttemptStarted() {
             PublishLifecycleEventRequest.newBuilder()
                 .setServiceLevel(ServiceLevel.INTERACTIVE)
                 .setProjectId(PROJECT_ID)
-                .addAllNotificationKeywords(EXPECTED_KEYWORDS)
+                .addAllNotificationKeywords(KEYWORDS)
                 .setBuildEvent(
                     OrderedBuildEvent.newBuilder()
                         .setStreamId(
@@ -118,8 +113,7 @@ public void invocationAttemptStarted_attemptNumber() {
             .buildRequestId(BUILD_REQUEST_ID)
             .invocationId(BUILD_INVOCATION_ID)
             .projectId(PROJECT_ID)
-            .commandName(COMMAND_NAME)
-            .keywords(ImmutableSet.of(ADDITIONAL_KEYWORD))
+            .keywords(KEYWORDS)
             .attemptNumber(2)
             .build();
     Timestamp expected = Timestamps.fromMillis(clock.advanceMillis(100));
@@ -128,7 +122,7 @@ public void invocationAttemptStarted_attemptNumber() {
             PublishLifecycleEventRequest.newBuilder()
                 .setServiceLevel(ServiceLevel.INTERACTIVE)
                 .setProjectId(PROJECT_ID)
-                .addAllNotificationKeywords(EXPECTED_KEYWORDS)
+                .addAllNotificationKeywords(KEYWORDS)
                 .setBuildEvent(
                     OrderedBuildEvent.newBuilder()
                         .setStreamId(
@@ -180,7 +174,7 @@ public void testBuildFinished() {
             PublishLifecycleEventRequest.newBuilder()
                 .setServiceLevel(ServiceLevel.INTERACTIVE)
                 .setProjectId(PROJECT_ID)
-                .addAllNotificationKeywords(EXPECTED_KEYWORDS)
+                .addAllNotificationKeywords(KEYWORDS)
                 .setBuildEvent(
                     OrderedBuildEvent.newBuilder()
                         .setStreamId(
@@ -206,7 +200,7 @@ public void testStreamEvents() {
     assertThat(BES_PROTO_UTIL.bazelEvent(1, firstEventTimestamp, anything))
         .isEqualTo(
             PublishBuildToolEventStreamRequest.newBuilder()
-                .addAllNotificationKeywords(EXPECTED_KEYWORDS)
+                .addAllNotificationKeywords(KEYWORDS)
                 .setProjectId(PROJECT_ID)
                 .setOrderedBuildEvent(
                     OrderedBuildEvent.newBuilder()
@@ -273,9 +267,8 @@ public void testStreamEventsWithCheckPrecedingLifecycleEventsEnabled() {
         new BuildEventServiceProtoUtil.Builder()
             .buildRequestId(BUILD_REQUEST_ID)
             .invocationId(BUILD_INVOCATION_ID)
-            .commandName(COMMAND_NAME)
             .checkPrecedingLifecycleEvents(true)
-            .keywords(ImmutableSet.of(ADDITIONAL_KEYWORD))
+            .keywords(KEYWORDS)
             .attemptNumber(1)
             .build();
     assertThat(
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export BAZEL_TEST_RLIMIT_INFINITY=1
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run all target tests in a single Bazel invocation for efficiency
# Note: Only 2 test targets are needed to cover all 3 test files:
# 1. BazelBuildEventServiceModuleTest covers BazelBuildEventServiceModuleTest.java
# 2. BuildEventTransportTest covers BuildEventServiceProtoUtilTest.java
# AbstractBuildEventServiceTransportTest.java is a java_library (base class), not a test target
echo "=== Running all target tests ==="
bazel test \
    --config=ci-linux \
    --test_output=errors \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/buildeventservice:BazelBuildEventServiceModuleTest \
    //src/test/java/com/google/devtools/build/lib/buildeventservice:BuildEventTransportTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 501f68825d86890b6db0f0a582eb23c8a5301d32 \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/AbstractBuildEventServiceTransportTest.java" \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/BazelBuildEventServiceModuleTest.java" \
    "src/test/java/com/google/devtools/build/lib/buildeventservice/BuildEventServiceProtoUtilTest.java"