#!/bin/bash
set -uxo pipefail

# Set environment variables
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH
export SPARK_LOCAL_IP=localhost
export GRADLE_OPTS="-Xmx3160m -Dorg.gradle.daemon=false"

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout df01d88c9360cda398c40493eb4135181a8976c5 \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java
@@ -188,7 +188,7 @@ public void testInvalidCherrypickSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.cherrypick_snapshot('', 1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
 
     assertThatThrownBy(() -> sql("CALL %s.system.cherrypick_snapshot('t', 2.2)", catalogName))
         .isInstanceOf(AnalysisException.class)
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java
@@ -191,7 +191,7 @@ public void testInvalidExpireSnapshotsCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.expire_snapshots('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java
@@ -190,7 +190,7 @@ public void testInvalidFastForwardBranchCases() {
     assertThatThrownBy(
             () -> sql("CALL %s.system.fast_forward('', 'main', 'newBranch')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java
@@ -186,6 +186,6 @@ public void testInvalidApplyWapChangesCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.publish_changes('', 'not_valid')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 }
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java
@@ -273,7 +273,7 @@ public void testInvalidRemoveOrphanFilesCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.remove_orphan_files('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java
@@ -317,7 +317,7 @@ public void testInvalidRewriteManifestsCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.rewrite_manifests('')", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 
   @TestTemplate
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java
@@ -283,6 +283,6 @@ public void testInvalidRollbackToSnapshotCases() {
 
     assertThatThrownBy(() -> sql("CALL %s.system.rollback_to_snapshot('', 1L)", catalogName))
         .isInstanceOf(IllegalArgumentException.class)
-        .hasMessage("Cannot handle an empty identifier for argument table");
+        .hasMessage("Cannot handle an empty identifier for parameter 'table'");
   }
 }
diff --git a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
--- a/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
+++ b/spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java
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

# Verify the patch was applied by showing the first 50 lines of one of the test files
echo "=== Verifying test patch application ==="
head -50 spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java

# Ensure Gradle wrapper is executable
chmod +x ./gradlew

# Run the target tests with verbose output and additional flags
# --tests to target specific test classes
# --no-daemon to avoid daemon issues in containers
# --console=plain for better logging output
# -DsparkVersions=3.4 to run Spark 3.4 tests
# -DscalaVersion=2.12 for Scala 2.12
# -DflinkVersions= -DkafkaVersions= to skip unnecessary integration tests
# -Pquick=true for faster execution
# -x javadoc to skip javadoc generation
echo "=== Running tests ==="
./gradlew -DsparkVersions=3.4 \
    -DscalaVersion=2.12 \
    -DflinkVersions= \
    -DkafkaVersions= \
    :iceberg-spark:iceberg-spark-extensions-3.4_2.12:test \
    --tests "org.apache.iceberg.spark.extensions.TestCherrypickSnapshotProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestExpireSnapshotsProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestFastForwardBranchProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestPublishChangesProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRemoveOrphanFilesProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRewriteManifestsProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestRollbackToSnapshotProcedure" \
    --tests "org.apache.iceberg.spark.extensions.TestSetCurrentSnapshotProcedure" \
    -Pquick=true \
    -x javadoc \
    --no-daemon \
    --console=plain \
    --info 2>&1 | tee test_output.log

# Capture exit code
rc=$?

# Show test results summary
echo "=== Test execution completed with exit code: $rc ==="

# Check for test result XML files
TEST_RESULTS_DIR="spark/v3.4/spark-extensions/build/test-results/test"
if [ -d "$TEST_RESULTS_DIR" ]; then
    echo "=== Test results files found ==="
    ls -la "$TEST_RESULTS_DIR"
    for test_file in "$TEST_RESULTS_DIR"/TEST-*.xml; do
        if [ -f "$test_file" ]; then
            echo "=== Content of $(basename $test_file) ==="
            cat "$test_file"
        fi
    done
fi

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout df01d88c9360cda398c40493eb4135181a8976c5 \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestCherrypickSnapshotProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestExpireSnapshotsProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestFastForwardBranchProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestPublishChangesProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRemoveOrphanFilesProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRewriteManifestsProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestRollbackToSnapshotProcedure.java" \
    "spark/v3.4/spark-extensions/src/test/java/org/apache/iceberg/spark/extensions/TestSetCurrentSnapshotProcedure.java"