#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 17eb76042532c20b2c3a738e3ccf4d9567f50eaa "fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java b/fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java
@@ -30,7 +30,6 @@ public class CompatibilityTest {
 
     @Test
     public void t01() {
-        // https://github.com/fast-excel/fastexcel/issues/2236
         List<Map<Integer, Object>> list = FastExcel.read(TestFileUtil.getPath() + "compatibility/t01.xls")
                 .sheet()
                 .doReadSync();
@@ -78,7 +77,6 @@ public void t04() {
 
     @Test
     public void t05() {
-        // https://github.com/fast-excel/fastexcel/issues/1956
         // Excel read date needs to be rounded
         List<Map<Integer, String>> list = FastExcel.read(TestFileUtil.getPath() + "compatibility/t05.xlsx")
                 .sheet()
@@ -104,7 +102,6 @@ public void t06() {
 
     @Test
     public void t07() {
-        // https://github.com/fast-excel/fastexcel/issues/2805
         // Excel read date needs to be rounded
         List<Map<Integer, Object>> list = FastExcel.read(TestFileUtil.getPath() + "compatibility/t07.xlsx")
                 .readDefaultReturn(ReadDefaultReturnEnum.ACTUAL_DATA)
@@ -123,7 +120,6 @@ public void t07() {
 
     @Test
     public void t08() {
-        // https://github.com/fast-excel/fastexcel/issues/2693
         // Temporary files may be deleted if there is no operation for a long time, so they need to be recreated.
         File file = TestFileUtil.createNewFile("compatibility/t08.xlsx");
         FastExcel.write(file, SimpleData.class).sheet().doWrite(data());
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java b/fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java
@@ -10,7 +10,7 @@
 import org.apache.poi.ss.usermodel.Hyperlink;
 
 /**
- * 自定义拦截器。对第一行第一列的头超链接到:https://github.com/fast-excel/fastexcel
+ * 自定义拦截器
  *
  *
  */
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java b/fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java
@@ -151,7 +151,6 @@ public void testHolder() {
             excelWriter.write(csvDataList, writeSheet);
         }
 
-        // https://github.com/alibaba/FastExcel/issues/3868
         csvFile = TestFileUtil.readFile(CSV_BASE + "csv-delimiter.csv");
         try (ExcelReader excelReader =
                 FastExcel.read(csvFile, CsvData.class, new CsvDataListener()).build()) {
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java b/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java
@@ -22,7 +22,6 @@ public void IssueTest1() {
                 .doRead();
     }
 
-    // CS304 (manually written) Issue link: https://github.com/alibaba/FastExcel/issues/2319
     @Test
     public void IssueTest2() {
         String fileName = TestFileUtil.getPath() + "temp/issue2319" + File.separator + "test2.xlsx";
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java b/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java
@@ -14,7 +14,6 @@
 
 @Slf4j
 public class Issue2443Test {
-    // CS304 (manually written) Issue link: https://github.com/fast-excel/fastexcel/issues/2443
     @Test
     public void IssueTest1() {
         String fileName = TestFileUtil.getPath() + "temp/issue2443" + File.separator + "date1.xlsx";
@@ -27,7 +26,6 @@ public void IssueTest1() {
                 .doRead();
     }
 
-    // CS304 (manually written) Issue link: https://github.com/fast-excel/fastexcel/issues/2443
     @Test
     public void IssueTest2() {
         String fileName = TestFileUtil.getPath() + "temp/issue2443" + File.separator + "date2.xlsx";
EOF_114329324912

# Run the specific test files in the fastexcel module only
# Using -pl fastexcel to target only the fastexcel module
# Using -Dmaven.test.skip=false to override the default skip setting
cd /testbed
mvn test -pl fastexcel -Dmaven.test.skip=false -Dtest=CompatibilityTest,CustomCellWriteHandler,CsvFormatTest,Issue2319Test,Issue2443Test

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Reset the test files to original state
git checkout 17eb76042532c20b2c3a738e3ccf4d9567f50eaa "fastexcel/src/test/java/cn/idev/excel/test/core/compatibility/CompatibilityTest.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/write/CustomCellWriteHandler.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/csv/CsvFormatTest.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/issue2319/Issue2319Test.java" "fastexcel/src/test/java/cn/idev/excel/test/temp/issue2443/Issue2443Test.java"