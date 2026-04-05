#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Ensure environment variables are set
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/build-tools/35.0.0:$PATH

# Checkout the original test file to ensure clean state
git checkout 01df27fc22206fd2b792861423e8a71d5b5ad570 "app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java b/app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java
--- a/app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java
+++ b/app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java
@@ -11,12 +11,16 @@
 import org.robolectric.annotation.LooperMode;
 
 import java.io.IOException;
-import java.util.Arrays;
 
 import io.github.muntashirakon.AppManager.BuildConfig;
 import io.github.muntashirakon.AppManager.backup.struct.BackupMetadataV5;
+import io.github.muntashirakon.AppManager.backup.struct.BackupOpOptions;
+import io.github.muntashirakon.AppManager.backup.struct.DeleteOpOptions;
+import io.github.muntashirakon.AppManager.backup.struct.RestoreOpOptions;
+import io.github.muntashirakon.AppManager.batchops.struct.BatchBackupOptions;
+import io.github.muntashirakon.AppManager.db.utils.AppDb;
 import io.github.muntashirakon.AppManager.settings.Prefs;
-import io.github.muntashirakon.AppManager.types.UserPackagePair;
+import io.github.muntashirakon.AppManager.utils.ContextUtils;
 import io.github.muntashirakon.AppManager.utils.RoboUtils;
 import io.github.muntashirakon.io.Path;
 import io.github.muntashirakon.io.Paths;
@@ -41,10 +45,10 @@ public void testBackupV4Default() throws BackupException, IOException {
         testRestoreV4Default();
         // Do backup
         Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.backup(null, null);
-        BackupItems.BackupItem backupItem = BackupItems.findBackupItemV4(0, null, "dnsfilter.android");
+        BackupManager bm = new BackupManager();
+        BackupOpOptions options = new BackupOpOptions("dnsfilter.android", 0, 1110, null, true);
+        bm.backup(options, null);
+        BackupItems.BackupItem backupItem = BackupItems.findBackupItem("dnsfilter.android/0");
         assertEquals(1, backupItem.getSourceFiles().length);
         assertEquals(1, backupItem.getDataFiles(0).length);
         assertEquals(1, backupItem.getDataFiles(1).length);
@@ -60,7 +64,7 @@ public void testBackupV4Default() throws BackupException, IOException {
         assertEquals(2, metadata.metadata.dataDirs.length);
         assertEquals(BuildConfig.APPLICATION_ID, metadata.metadata.installer);
         assertFalse(metadata.metadata.isSplitApk);
-        bm.verify(null);
+        bm.verify("dnsfilter.android/0");
     }
 
 
@@ -70,11 +74,10 @@ public void testBackupV4Custom() throws BackupException, IOException {
         testRestoreV4Default();
         // Do backup
         Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110 | BackupFlags.BACKUP_MULTIPLE);
-        bm.backup(new String[]{"test_backup"}, null);
-        System.out.println(Arrays.toString(Prefs.Storage.getAppManagerDirectory().findFile("dnsfilter.android").listFileNames()));
-        BackupItems.BackupItem backupItem = BackupItems.findBackupItemV4(0, "test_backup", "dnsfilter.android");
+        BackupManager bm = new BackupManager();
+        BackupOpOptions options = new BackupOpOptions("dnsfilter.android", 0, 1110 | BackupFlags.BACKUP_MULTIPLE, "test_backup", false);
+        bm.backup(options, null);
+        BackupItems.BackupItem backupItem = BackupItems.findBackupItem("dnsfilter.android/0_test_backup");
         assertEquals(1, backupItem.getSourceFiles().length);
         assertEquals(1, backupItem.getDataFiles(0).length);
         assertEquals(1, backupItem.getDataFiles(1).length);
@@ -90,39 +93,68 @@ public void testBackupV4Custom() throws BackupException, IOException {
         assertEquals(2, metadata.metadata.dataDirs.length);
         assertEquals(BuildConfig.APPLICATION_ID, metadata.metadata.installer);
         assertFalse(metadata.metadata.isSplitApk);
-        bm.verify("0_test_backup");
+        bm.verify("dnsfilter.android/0_test_backup");
     }
 
     @Test
     public void testRestoreV4Default() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.restore(null, null);
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        RestoreOpOptions options = new RestoreOpOptions("dnsfilter.android", 0, null, 1110);
+        bm.restore(options, null);
+    }
+
+    @Test
+    public void testRestoreV4DefaultBatchOps() throws BackupException {
+        Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, null);
+        bm.restore(options.getRestoreOpOptions("dnsfilter.android", 0), null);
     }
 
     @Test
     public void testRestoreV4DefaultAsCustom() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.restore(new String[]{"0"}, null);
+        BackupManager bm = new BackupManager();
+        RestoreOpOptions options = new RestoreOpOptions("dnsfilter.android", 0, "dnsfilter.android/0", 1110);
+        bm.restore(options, null);
+    }
+
+    @Test
+    public void testRestoreV4DefaultAsRelativeDirBatchOps() throws BackupException {
+        Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, new String[]{"dnsfilter.android/0"});
+        bm.restore(options.getRestoreOpOptions("dnsfilter.android", 0), null);
     }
 
     @Test
     public void testRestoreV4Custom() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.restore(new String[]{"0_test"}, null);
+        BackupManager bm = new BackupManager();
+        RestoreOpOptions options = new RestoreOpOptions("dnsfilter.android", 0, "dnsfilter.android/0_test", 1110);
+        bm.restore(options, null);
+    }
+
+    @Test
+    public void testRestoreV4CustomAsBackupNameBatchOps() throws BackupException {
+        Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, new String[]{"test"}, null);
+        bm.restore(options.getRestoreOpOptions("dnsfilter.android", 0), null);
     }
 
     @Test
-    public void testRestoreV4CustomWithoutUserIdFails() {
+    public void testRestoreV4CustomAsRelativeDirBatchOps() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        assertThrows(IllegalArgumentException.class, () -> bm.restore(new String[]{"test"}, null));
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, new String[]{"dnsfilter.android/0_test"});
+        bm.restore(options.getRestoreOpOptions("dnsfilter.android", 0), null);
     }
 
     @Test
@@ -132,9 +164,26 @@ public void testDeleteV4Default() throws IOException, BackupException {
                 .copyTo(tmpBackupPath, true));
         Path amDir = tmpBackupPath.findFile("AppManager");
         assertTrue(amDir.exists());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.deleteBackup(null);
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        DeleteOpOptions options = new DeleteOpOptions("dnsfilter.android", 0, null);
+        bm.deleteBackup(options);
+        assertTrue(amDir.exists());
+        Path appBackupPath = amDir.findFile("dnsfilter.android");
+        appBackupPath.findFile("0_test");
+    }
+
+    @Test
+    public void testDeleteV4DefaultBatchOps() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, null);
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
         assertTrue(amDir.exists());
         Path appBackupPath = amDir.findFile("dnsfilter.android");
         appBackupPath.findFile("0_test");
@@ -147,9 +196,25 @@ public void testDeleteV4DefaultAsCustom() throws IOException, BackupException {
                 .copyTo(tmpBackupPath, true));
         Path amDir = tmpBackupPath.findFile("AppManager");
         assertTrue(amDir.exists());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.deleteBackup(new String[]{"0"});
+        BackupManager bm = new BackupManager();
+        DeleteOpOptions options = new DeleteOpOptions("dnsfilter.android", 0, new String[]{"dnsfilter.android/0"});
+        bm.deleteBackup(options);
+        assertTrue(amDir.exists());
+        Path appBackupPath = amDir.findFile("dnsfilter.android");
+        appBackupPath.findFile("0_test");
+    }
+
+    @Test
+    public void testDeleteV4DefaultRelativeDirBatchOps() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, new String[]{"dnsfilter.android/0"});
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
         assertTrue(amDir.exists());
         Path appBackupPath = amDir.findFile("dnsfilter.android");
         appBackupPath.findFile("0_test");
@@ -162,59 +227,108 @@ public void testDeleteV4Custom() throws IOException, BackupException {
                 .copyTo(tmpBackupPath, true));
         Path amDir = tmpBackupPath.findFile("AppManager");
         assertTrue(amDir.exists());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.deleteBackup(new String[]{"0_test"});
+        BackupManager bm = new BackupManager();
+        DeleteOpOptions options = new DeleteOpOptions("dnsfilter.android", 0, new String[]{"dnsfilter.android/0_test"});
+        bm.deleteBackup(options);
         assertTrue(amDir.exists());
         Path appBackupPath = amDir.findFile("dnsfilter.android");
         appBackupPath.findFile("0");
     }
 
     @Test
-    public void testDeleteV4CustomWithoutUserIdFails() throws IOException {
+    public void testDeleteV4CustomRelativeDirBatchOps() throws IOException, BackupException {
         Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
         assertNotNull(rscBackupPath.findFile("AppManager")
                 .copyTo(tmpBackupPath, true));
         Path amDir = tmpBackupPath.findFile("AppManager");
         assertTrue(amDir.exists());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        assertThrows(IllegalArgumentException.class, () -> bm.deleteBackup(new String[]{"test"}));
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, new String[]{"dnsfilter.android/0_test"});
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
         assertTrue(amDir.exists());
         Path appBackupPath = amDir.findFile("dnsfilter.android");
         appBackupPath.findFile("0");
-        appBackupPath.findFile("0_test");
     }
 
     @Test
-    public void testVerifyV4Default() throws BackupException {
-        Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.verify(null);
+    public void testDeleteV4CustomBackupNameBatchOps() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, new String[]{"test"}, null);
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
+        assertTrue(amDir.exists());
+        Path appBackupPath = amDir.findFile("dnsfilter.android");
+        appBackupPath.findFile("0");
     }
 
     @Test
-    public void testVerifyV4DefaultAsCustom() throws BackupException {
+    public void testDeleteV4DefaultAndCustom() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        BackupManager bm = new BackupManager();
+        DeleteOpOptions options = new DeleteOpOptions("dnsfilter.android", 0, new String[]{"dnsfilter.android/0", "dnsfilter.android/0_test"});
+        bm.deleteBackup(options);
+        assertTrue(amDir.exists());
+        assertFalse(amDir.hasFile("dnsfilter.android"));
+    }
+
+    @Test
+    public void testDeleteV4DefaultAndCustomRelativeDirsBatchOps() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, null, new String[]{"dnsfilter.android/0", "dnsfilter.android/0_test"});
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
+        assertTrue(amDir.exists());
+        assertFalse(amDir.hasFile("dnsfilter.android"));
+    }
+
+    @Test
+    public void testDeleteV4DefaultAndCustomBackupNamesBatchOps() throws IOException, BackupException {
+        Prefs.Storage.setVolumePath(tmpBackupPath.getUri().toString());
+        assertNotNull(rscBackupPath.findFile("AppManager")
+                .copyTo(tmpBackupPath, true));
+        Path amDir = tmpBackupPath.findFile("AppManager");
+        assertTrue(amDir.exists());
+        new AppDb().loadInstalledOrBackedUpApplications(ContextUtils.getContext());
+        BackupManager bm = new BackupManager();
+        BatchBackupOptions options = new BatchBackupOptions(1110, new String[]{null, "test"}, null);
+        bm.deleteBackup(options.getDeleteOpOptions("dnsfilter.android", 0));
+        assertTrue(amDir.exists());
+        assertFalse(amDir.hasFile("dnsfilter.android"));
+    }
+
+    @Test
+    public void testVerifyV4Default() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.verify("0");
+        BackupManager bm = new BackupManager();
+        bm.verify("dnsfilter.android/0");
     }
 
     @Test
-    public void testVerifyV4Custom() throws BackupException {
+    public void testVerifyV4DefaultAsCustom() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        bm.verify("0_test");
+        BackupManager bm = new BackupManager();
+        bm.verify("dnsfilter.android/0");
     }
 
     @Test
-    public void testVerifyV4CustomWithoutUserIdFails() {
+    public void testVerifyV4Custom() throws BackupException {
         Prefs.Storage.setVolumePath(rscBackupPath.getUri().toString());
-        UserPackagePair pair = new UserPackagePair("dnsfilter.android", 0);
-        BackupManager bm = new BackupManager(pair, 1110);
-        assertThrows(IllegalArgumentException.class, () -> bm.verify("test"));
+        BackupManager bm = new BackupManager();
+        bm.verify("dnsfilter.android/0_test");
     }
 }
\ No newline at end of file
EOF_114329324912

# Make gradlew executable (ensure it's executable)
chmod +x gradlew

# Clean previous test results to ensure fresh run
rm -rf app/build/test-results/testDebugUnitTest/
rm -rf app/build/reports/tests/testDebugUnitTest/

# Run the specific test using Gradle with verbose output
# Using --info for detailed logging
# Using --console=plain for better output visibility
# Using --no-daemon to avoid daemon issues in Docker
# Using --stacktrace for better error reporting if test fails
echo "=========================================="
echo "Running BackupManagerTest..."
echo "=========================================="

./gradlew :app:testDebugUnitTest \
    --tests "io.github.muntashirakon.AppManager.backup.BackupManagerTest" \
    --no-daemon \
    --stacktrace \
    --info \
    --console=plain

# Capture the exit code
rc=$?

echo "=========================================="
echo "Test execution completed with exit code: $rc"
echo "=========================================="

# Display test results if they exist
if [ -d "app/build/test-results/testDebugUnitTest/" ]; then
    echo "=========================================="
    echo "Test Results XML Files:"
    echo "=========================================="
    find app/build/test-results/testDebugUnitTest/ -name "*.xml" -exec echo "File: {}" \; -exec cat {} \; -exec echo "" \;
fi

# Display test report summary if it exists
if [ -f "app/build/reports/tests/testDebugUnitTest/index.html" ]; then
    echo "=========================================="
    echo "Test report generated at: app/build/reports/tests/testDebugUnitTest/index.html"
    echo "=========================================="
fi

# List all test result files
echo "=========================================="
echo "All test result files:"
echo "=========================================="
find app/build/test-results/ -type f 2>/dev/null || echo "No test result files found"

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 01df27fc22206fd2b792861423e8a71d5b5ad570 "app/src/test/java/io/github/muntashirakon/AppManager/backup/BackupManagerTest.java"

# Exit with the captured return code
exit $rc