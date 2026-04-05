#!/bin/bash
set -uxo pipefail

# Set environment variables
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH
export GRADLE_OPTS="-Xmx1536m -Dorg.gradle.daemon=false"

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 95a578d7ad96aa3c82dccd305f556c83b3360528 "core/src/test/java/org/apache/iceberg/TestTransaction.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/core/src/test/java/org/apache/iceberg/TestTransaction.java b/core/src/test/java/org/apache/iceberg/TestTransaction.java
--- a/core/src/test/java/org/apache/iceberg/TestTransaction.java
+++ b/core/src/test/java/org/apache/iceberg/TestTransaction.java
@@ -502,10 +502,8 @@ public void testTransactionRetryAndAppendManifestsWithoutSnapshotIdInheritance()
     // create a manifest append
     OutputFile manifestLocation = Files.localOutput("/tmp/" + UUID.randomUUID() + ".avro");
     ManifestWriter<DataFile> writer = ManifestFiles.write(table.spec(), manifestLocation);
-    try {
+    try (writer) {
       writer.add(FILE_D);
-    } finally {
-      writer.close();
     }
 
     Transaction txn = table.newTransaction();
@@ -692,7 +690,7 @@ public void testTransactionRewriteManifestsAppendedDirectly() throws IOException
   }
 
   @TestTemplate
-  public void testSimpleTransactionNotDeletingMetadataOnUnknownSate() throws IOException {
+  public void testSimpleTransactionNotDeletingMetadataOnUnknownSate() {
     Table table = TestTables.tableWithCommitSucceedButStateUnknown(tableDir, "test");
 
     Transaction transaction = table.newTransaction();
@@ -889,4 +887,58 @@ public void testOverwriteWithConcurrentManifestRewrite() throws IOException {
         files(FILE_A, FILE_A2, FILE_B),
         statuses(Status.EXISTING, Status.DELETED, Status.EXISTING));
   }
+
+  @TestTemplate
+  public void testExtendBaseTransaction() {
+    assertThat(version()).isEqualTo(0);
+    TableMetadata base = readMetadata();
+
+    Transaction txn =
+        new AppendToBranchTransaction(
+            table.name(),
+            table.ops(),
+            BaseTransaction.TransactionType.SIMPLE,
+            table.ops().refresh());
+    AppendFiles appendFiles = txn.newAppend().appendFile(FILE_A);
+    Snapshot branchSnapshot = appendFiles.apply();
+    appendFiles.commit();
+
+    assertThat(readMetadata()).isSameAs(base);
+    assertThat(version()).isEqualTo(0);
+
+    // first snapshot write to main
+    table.newAppend().appendFile(FILE_B).commit();
+
+    Snapshot mainSnapshot = readMetadata().currentSnapshot();
+    assertThat(version()).isEqualTo(1);
+    validateSnapshot(base.currentSnapshot(), mainSnapshot, FILE_B);
+
+    // second snapshot write to branch
+    txn.commitTransaction();
+    assertThat(version()).isEqualTo(2);
+
+    assertThat(readMetadata().refs()).hasSize(2).containsKey("main").containsKey("branch");
+    assertThat(readMetadata().ref("main").snapshotId()).isEqualTo(mainSnapshot.snapshotId());
+    assertThat(readMetadata().snapshot(mainSnapshot.snapshotId()).allManifests(table.io()))
+        .hasSize(1);
+    assertThat(readMetadata().ref("branch").snapshotId()).isEqualTo(branchSnapshot.snapshotId());
+    assertThat(readMetadata().snapshot(branchSnapshot.snapshotId()).allManifests(table.io()))
+        .hasSize(2);
+  }
+
+  private static class AppendToBranchTransaction extends BaseTransaction {
+
+    AppendToBranchTransaction(
+        String tableName, TableOperations ops, TransactionType type, TableMetadata start) {
+      super(tableName, ops, type, start);
+    }
+
+    @Override
+    public AppendFiles newAppend() {
+      AppendFiles append =
+          new MergeAppend(tableName(), ((HasTableOperations) table()).operations())
+              .toBranch("branch");
+      return appendUpdate(append);
+    }
+  }
 }
EOF_114329324912

# Verify the patch was applied by showing the first 50 lines of the test file
echo "=== Verifying test patch application ==="
head -50 core/src/test/java/org/apache/iceberg/TestTransaction.java

# Ensure Gradle wrapper is executable
chmod +x ./gradlew

# Run the target test with verbose output and additional flags
# --tests to target specific test class
# --no-daemon to avoid daemon issues in containers
# --console=plain for better logging output
# -DsparkVersions= -DflinkVersions= -DkafkaVersions= to skip unnecessary integration tests
# -Pquick=true for faster execution
# --info for verbose test output
echo "=== Running tests ==="
./gradlew :iceberg-core:test \
    --tests "org.apache.iceberg.TestTransaction" \
    --no-daemon \
    --console=plain \
    -DsparkVersions= \
    -DflinkVersions= \
    -DkafkaVersions= \
    -Pquick=true \
    --info 2>&1 | tee test_output.log

# Capture exit code
rc=$?

# Show test results summary
echo "=== Test execution completed with exit code: $rc ==="
if [ -f "core/build/test-results/test/TEST-org.apache.iceberg.TestTransaction.xml" ]; then
    echo "=== Test results file found ==="
    cat core/build/test-results/test/TEST-org.apache.iceberg.TestTransaction.xml
fi

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 95a578d7ad96aa3c82dccd305f556c83b3360528 "core/src/test/java/org/apache/iceberg/TestTransaction.java"