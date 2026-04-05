#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 36615f1b71539c8af23ecdcfa7d7e1d8e4c7aec5 "fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java b/fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java
--- a/fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java
+++ b/fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java
@@ -31,6 +31,7 @@
 import org.apache.fesod.excel.support.ExcelTypeEnum;
 import org.apache.fesod.excel.util.TestFileUtil;
 import org.apache.fesod.excel.write.metadata.WriteSheet;
+import org.apache.poi.ss.usermodel.Workbook;
 import org.junit.jupiter.api.Assertions;
 import org.junit.jupiter.api.Test;
 
@@ -106,8 +107,8 @@ private Map<Integer, Integer> initSheetDataSizeList(List<Integer> sheetNoList) {
     }
 
     private void testSheetOrderWithSheetName(ExcelTypeEnum excelTypeEnum) {
-        List<String> sheetNameList = Arrays.asList("Sheet1", "Sheet2", "Sheet3");
-        List<Integer> sheetNoList = Arrays.asList(0, 1, 2);
+        List<String> sheetNameList = Arrays.asList("Sheet1", "Sheet2", "Sheet3", "Sheet111112222233333444445555566666");
+        List<Integer> sheetNoList = Arrays.asList(0, 1, 2, 3);
 
         Map<Integer, Integer> dataMap = initSheetDataSizeList(sheetNoList);
         File testFile = TestFileUtil.createNewFile("writesheet/write-sheet-order-name" + excelTypeEnum.getValue());
@@ -136,6 +137,16 @@ private void testSheetOrderWithSheetName(ExcelTypeEnum excelTypeEnum) {
             excelWriter.write(dataList(dataMap.get(sheetNo)), writeSheet);
             Assertions.assertEquals(
                     sheetNo, excelWriter.writeContext().writeSheetHolder().getSheetNo());
+
+            sheetNo = 3;
+            writeSheet =
+                    FastExcel.writerSheet(sheetNo, sheetNameList.get(sheetNo)).build();
+            excelWriter.write(dataList(dataMap.get(sheetNo)), writeSheet);
+            Assertions.assertEquals(
+                    sheetNameList.get(sheetNo).substring(0, Workbook.MAX_SENSITIVE_SHEET_NAME_LEN),
+                    excelWriter.writeContext().writeSheetHolder().getSheetName());
+            Assertions.assertEquals(
+                    sheetNo, excelWriter.writeContext().writeSheetHolder().getSheetNo());
         }
 
         for (int i = 0; i < sheetNoList.size(); i++) {
EOF_114329324912

# Run the specific test using Maven
# -B: Batch mode (non-interactive)
# -Dmaven.test.skip=false: Enable tests (overrides default skip)
# -pl fesod: Build only fesod module
# -Dtest=WriteSheetTest: Run only WriteSheetTest
./mvnw test -B -Dmaven.test.skip=false -pl fesod -Dtest=WriteSheetTest

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 36615f1b71539c8af23ecdcfa7d7e1d8e4c7aec5 "fesod/src/test/java/org/apache/fesod/excel/writesheet/WriteSheetTest.java"