#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout f668c2802875db0a88d4214dbdeb717666318d4d "fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java b/fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java
--- a/fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java
+++ b/fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java
@@ -23,7 +23,7 @@
 import java.util.ArrayList;
 import java.util.Arrays;
 import java.util.List;
-import org.apache.fesod.sheet.FastExcel;
+import org.apache.fesod.sheet.FesodSheet;
 import org.apache.fesod.sheet.enums.HeaderMergeStrategy;
 import org.apache.fesod.sheet.util.TestFileUtil;
 import org.apache.poi.ss.usermodel.Sheet;
@@ -59,7 +59,7 @@ public static void init() {
     @Test
     public void testNoneStrategy() {
         List<List<String>> head = createTestHead();
-        FastExcel.write(fileNone)
+        FesodSheet.write(fileNone)
                 .head(head)
                 .headerMergeStrategy(HeaderMergeStrategy.NONE)
                 .sheet()
@@ -79,7 +79,7 @@ public void testNoneStrategy() {
     @Test
     public void testHorizontalOnlyStrategy() {
         List<List<String>> head = createTestHead();
-        FastExcel.write(fileHorizontalOnly)
+        FesodSheet.write(fileHorizontalOnly)
                 .head(head)
                 .headerMergeStrategy(HeaderMergeStrategy.HORIZONTAL_ONLY)
                 .sheet()
@@ -107,7 +107,7 @@ public void testHorizontalOnlyStrategy() {
     @Test
     public void testVerticalOnlyStrategy() {
         List<List<String>> head = createTestHead();
-        FastExcel.write(fileVerticalOnly)
+        FesodSheet.write(fileVerticalOnly)
                 .head(head)
                 .headerMergeStrategy(HeaderMergeStrategy.VERTICAL_ONLY)
                 .sheet()
@@ -135,7 +135,7 @@ public void testVerticalOnlyStrategy() {
     @Test
     public void testFullRectangleStrategy() {
         List<List<String>> head = createTestHead();
-        FastExcel.write(fileFullRectangle)
+        FesodSheet.write(fileFullRectangle)
                 .head(head)
                 .headerMergeStrategy(HeaderMergeStrategy.FULL_RECTANGLE)
                 .sheet()
@@ -164,7 +164,7 @@ public void testFullRectangleStrategy() {
     @Test
     public void testAutoStrategy() {
         List<List<String>> head = createTestHead();
-        FastExcel.write(fileAuto)
+        FesodSheet.write(fileAuto)
                 .head(head)
                 .headerMergeStrategy(HeaderMergeStrategy.AUTO)
                 .sheet()
EOF_114329324912

# Run the specific test using Maven
# -B: Batch mode (non-interactive)
# -Dmaven.test.skip=false: Enable tests (overrides default skip)
# -pl fesod-sheet: Build only fesod-sheet module
# -Dtest=HeaderMergeStrategyTest: Run only HeaderMergeStrategyTest
./mvnw test -B -Dmaven.test.skip=false -pl fesod-sheet -Dtest=HeaderMergeStrategyTest

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout f668c2802875db0a88d4214dbdeb717666318d4d "fesod-sheet/src/test/java/org/apache/fesod/sheet/head/HeaderMergeStrategyTest.java"