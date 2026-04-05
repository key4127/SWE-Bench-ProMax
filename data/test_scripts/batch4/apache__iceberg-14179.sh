#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 317ebe53ea295e92e440913c6369189a664691db \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
@@ -188,7 +188,7 @@ public void testInvalidCherrypickSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.cherrypick_snapshot('', 1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
 
     assertThatThrownBy(() -> sql("CALL %s.system.cherrypick_snapshot('t', 2.2)", catalogName))
         .isInstanceOf(AnalysisException.class)
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
@@ -191,7 +191,7 @@ public void testInvalidExpireSnapshotsCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.expire_snapshots('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
@@ -190,7 +190,7 @@ public void testInvalidFastForwardBranchCases() {
     assertThatThrownBy(
             () -> sql("CALL %s.system.fast_forward('', 'main', 'newBranch')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
@@ -186,6 +186,6 @@ public void testInvalidApplyWapChangesCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.publish_changes('', 'not_valid')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 }
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
@@ -272,7 +272,7 @@ public void testInvalidRemoveOrphanFilesCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.remove_orphan_files('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
@@ -326,7 +326,7 @@ public void testInvalidRewriteManifestsCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.rewrite_manifests('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
@@ -282,6 +282,6 @@ public void testInvalidRollbackToSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.rollback_to_snapshot('', 1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 }
diff --git a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
--- a/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
+++ b/spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
@@ -219,7 +219,7 @@ public void testInvalidRollbackToSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.set_current_snapshot(1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot parse identifier for arg table: 1");
+        .hasMessage("Cannot parse identifier for parameter 'table': 1");
 
     assertThatThrownBy(
             () -> sql("CALL %s.system.set_current_snapshot(snapshot_id => 1L)", catalogName))
@@ -236,7 +236,7 @@ public void testInvalidRollbackToSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.set_current_snapshot('', 1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
 
     assertThatThrownBy(
             () ->
EOF_114329324912

# Verify test files exist after patching
echo "Verifying test files after patch..."
ls -la spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/Test*Procedure.java

# Ensure Gradle wrapper is executable
chmod +x ./gradlew

# Clean previous test results to ensure fresh execution
./gradlew :iceberg-spark:iceberg-spark-extensions-3.5_2.12:cleanTest --no-daemon

# Run the target tests using Gradle with correct module name
# Using :iceberg-spark:iceberg-spark-extensions-3.5_2.12:test for the correct module path
# --tests flag to target specific test classes
# --no-daemon to avoid daemon issues in containers
# --rerun-tasks to force re-execution of tests
# --info for detailed output about test discovery and execution
# -DsparkVersions=3.5 to specify Spark version
# -DscalaVersion=2.12 to specify Scala version
# --console=plain for better logging
# -DflinkVersions= -DkafkaVersions= to skip unnecessary integration tests
./gradlew :iceberg-spark:iceberg-spark-extensions-3.5_2.12:test \
    --tests "org.apache.iceberg.spark.extensions.TestCherrypickSnapshotProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestExpireSnapshotsProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestFastForwardBranchProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestPublishChangesProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRemoveOrphanFilesProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRewriteManifestsProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRollbackToSnapshotProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestSetCurrentSnapshotProcedure" \
    --no-daemon \
    --console=plain \
    --info \
    --rerun-tasks \
    -DsparkVersions=3.5 \
    -DscalaVersion=2.12 \
    -DflinkVersions= \
    -DkafkaVersions=

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Check for test results to verify tests actually ran
echo "Checking for test results..."
find /testbed -path "*/test-results/test/*.xml" -type f -exec echo "Found test result: {}" \;

# Restore original test files
git checkout 317ebe53ea295e92e440913c6369189a664691db \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java" \
    "spark/v3.5/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java"