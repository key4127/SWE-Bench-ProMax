#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target files to ensure clean state
git checkout df097faa158950ac45cf2a1e98b5d6ec5d7ad981 "fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java b/fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java
@@ -6,6 +6,7 @@
 import cn.idev.excel.write.handler.RowWriteHandler;
 import cn.idev.excel.write.handler.SheetWriteHandler;
 import cn.idev.excel.write.handler.WorkbookWriteHandler;
+import cn.idev.excel.write.handler.context.SheetWriteHandlerContext;
 import cn.idev.excel.write.metadata.holder.WriteSheetHolder;
 import cn.idev.excel.write.metadata.holder.WriteTableHolder;
 import cn.idev.excel.write.metadata.holder.WriteWorkbookHolder;
@@ -28,6 +29,7 @@ public class WriteHandler implements WorkbookWriteHandler, SheetWriteHandler, Ro
     private long afterRowDispose = 0L;
     private long beforeSheetCreate = 0L;
     private long afterSheetCreate = 0L;
+    private long afterSheetDispose = 0L;
     private long beforeWorkbookCreate = 0L;
     private long afterWorkbookCreate = 0L;
     private long afterWorkbookDispose = 0L;
@@ -51,6 +53,7 @@ public void beforeCellCreate(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -76,6 +79,7 @@ public void afterCellCreate(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -101,6 +105,7 @@ public void afterCellDataConverted(
         Assertions.assertEquals(1L, afterRowDispose);
         Assertions.assertEquals(1L, beforeSheetCreate);
         Assertions.assertEquals(1L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -126,6 +131,7 @@ public void afterCellDispose(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -150,6 +156,7 @@ public void beforeRowCreate(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -174,6 +181,7 @@ public void afterRowCreate(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -198,6 +206,7 @@ public void afterRowDispose(
             Assertions.assertEquals(0L, afterRowDispose);
             Assertions.assertEquals(1L, beforeSheetCreate);
             Assertions.assertEquals(1L, afterSheetCreate);
+            Assertions.assertEquals(0L, afterSheetDispose);
             Assertions.assertEquals(1L, beforeWorkbookCreate);
             Assertions.assertEquals(1L, afterWorkbookCreate);
             Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -216,6 +225,7 @@ public void beforeSheetCreate(WriteWorkbookHolder writeWorkbookHolder, WriteShee
         Assertions.assertEquals(0L, afterRowDispose);
         Assertions.assertEquals(0L, beforeSheetCreate);
         Assertions.assertEquals(0L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -233,6 +243,7 @@ public void afterSheetCreate(WriteWorkbookHolder writeWorkbookHolder, WriteSheet
         Assertions.assertEquals(0L, afterRowDispose);
         Assertions.assertEquals(1L, beforeSheetCreate);
         Assertions.assertEquals(0L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -250,6 +261,7 @@ public void beforeWorkbookCreate() {
         Assertions.assertEquals(0L, afterRowDispose);
         Assertions.assertEquals(0L, beforeSheetCreate);
         Assertions.assertEquals(0L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
         Assertions.assertEquals(0L, beforeWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -267,6 +279,7 @@ public void afterWorkbookCreate(WriteWorkbookHolder writeWorkbookHolder) {
         Assertions.assertEquals(0L, afterRowDispose);
         Assertions.assertEquals(0L, beforeSheetCreate);
         Assertions.assertEquals(0L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
@@ -284,12 +297,31 @@ public void afterWorkbookDispose(WriteWorkbookHolder writeWorkbookHolder) {
         Assertions.assertEquals(1L, afterRowDispose);
         Assertions.assertEquals(1L, beforeSheetCreate);
         Assertions.assertEquals(1L, afterSheetCreate);
+        Assertions.assertEquals(1L, afterSheetDispose);
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookCreate);
         Assertions.assertEquals(0L, afterWorkbookDispose);
         afterWorkbookDispose++;
     }
 
+    @Override
+    public void afterSheetDispose(SheetWriteHandlerContext context) {
+        Assertions.assertEquals(1L, beforeCellCreate);
+        Assertions.assertEquals(1L, afterCellCreate);
+        Assertions.assertEquals(1L, afterCellDataConverted);
+        Assertions.assertEquals(1L, afterCellDispose);
+        Assertions.assertEquals(1L, beforeRowCreate);
+        Assertions.assertEquals(1L, afterRowCreate);
+        Assertions.assertEquals(1L, afterRowDispose);
+        Assertions.assertEquals(1L, beforeSheetCreate);
+        Assertions.assertEquals(1L, afterSheetCreate);
+        Assertions.assertEquals(0L, afterSheetDispose);
+        Assertions.assertEquals(1L, beforeWorkbookCreate);
+        Assertions.assertEquals(1L, afterWorkbookCreate);
+        Assertions.assertEquals(0L, afterWorkbookDispose);
+        afterSheetDispose++;
+    }
+
     public void afterAll() {
         Assertions.assertEquals(1L, beforeCellCreate);
         Assertions.assertEquals(1L, afterCellCreate);
@@ -303,5 +335,6 @@ public void afterAll() {
         Assertions.assertEquals(1L, beforeWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookCreate);
         Assertions.assertEquals(1L, afterWorkbookDispose);
+        Assertions.assertEquals(1L, afterSheetDispose);
     }
 }
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java b/fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java
@@ -6,6 +6,8 @@
 import cn.idev.excel.test.util.TestFileUtil;
 import cn.idev.excel.util.ListUtils;
 import cn.idev.excel.util.MapUtils;
+import cn.idev.excel.write.handler.SheetWriteHandler;
+import cn.idev.excel.write.handler.context.SheetWriteHandlerContext;
 import cn.idev.excel.write.metadata.WriteSheet;
 import cn.idev.excel.write.metadata.fill.FillConfig;
 import cn.idev.excel.write.metadata.fill.FillWrapper;
@@ -14,6 +16,8 @@
 import java.util.HashMap;
 import java.util.List;
 import java.util.Map;
+import org.apache.poi.ss.usermodel.Sheet;
+import org.apache.poi.ss.util.CellRangeAddress;
 import org.junit.jupiter.api.Test;
 
 /**
@@ -260,6 +264,27 @@ public void dateFormatFill() {
         FastExcel.write(fileName).withTemplate(templateFileName).sheet().doFill(data());
     }
 
+    @Test
+    public void testFillSheetDispose() {
+        String templateFileName =
+                TestFileUtil.getPath() + "demo" + File.separator + "fill" + File.separator + "simple.xlsx";
+        String fileName = TestFileUtil.getPath() + "simpleFill" + System.currentTimeMillis() + ".xlsx";
+        FillData fillData = new FillData();
+        fillData.setName("Zhang San");
+        fillData.setNumber(5.2);
+        FastExcel.write(fileName)
+                .withTemplate(templateFileName)
+                .sheet()
+                .registerWriteHandler(new SheetWriteHandler() {
+                    @Override
+                    public void afterSheetDispose(SheetWriteHandlerContext context) {
+                        Sheet sheet = context.getWriteSheetHolder().getSheet();
+                        sheet.addMergedRegionUnsafe(new CellRangeAddress(1, 2, 0, 1));
+                    }
+                })
+                .doFill(fillData);
+    }
+
     private List<FillData> data() {
         List<FillData> list = ListUtils.newArrayList();
         for (int i = 0; i < 10; i++) {
diff --git a/fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java b/fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java
--- a/fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java
+++ b/fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java
@@ -22,7 +22,9 @@
 import cn.idev.excel.util.ListUtils;
 import cn.idev.excel.write.handler.CellWriteHandler;
 import cn.idev.excel.write.handler.EscapeHexCellWriteHandler;
+import cn.idev.excel.write.handler.SheetWriteHandler;
 import cn.idev.excel.write.handler.context.CellWriteHandlerContext;
+import cn.idev.excel.write.handler.context.SheetWriteHandlerContext;
 import cn.idev.excel.write.merge.LoopMergeStrategy;
 import cn.idev.excel.write.metadata.WriteSheet;
 import cn.idev.excel.write.metadata.WriteTable;
@@ -42,7 +44,9 @@
 import org.apache.poi.ss.usermodel.CellStyle;
 import org.apache.poi.ss.usermodel.FillPatternType;
 import org.apache.poi.ss.usermodel.IndexedColors;
+import org.apache.poi.ss.usermodel.Sheet;
 import org.apache.poi.ss.usermodel.Workbook;
+import org.apache.poi.ss.util.CellRangeAddress;
 import org.apache.poi.xssf.streaming.SXSSFSheet;
 import org.junit.jupiter.api.Test;
 
@@ -741,6 +745,23 @@ public void noModelWrite() {
         FastExcel.write(fileName).head(head()).sheet("模板").doWrite(dataList());
     }
 
+    @Test
+    public void sheetDisposeTest() {
+        String fileName = TestFileUtil.getPath() + "simpleWrite" + System.currentTimeMillis() + ".xlsx";
+        FastExcel.write(fileName, DemoData.class)
+                .sheet("模板")
+                .registerWriteHandler(new SheetWriteHandler() {
+                    @Override
+                    public void afterSheetDispose(SheetWriteHandlerContext context) {
+                        Sheet sheet = context.getWriteSheetHolder().getSheet();
+                        // 合并区域单元格
+                        sheet.addMergedRegionUnsafe(new CellRangeAddress(1, 10, 2, 2));
+                    }
+                })
+                .doWrite(this::data);
+        System.out.println(fileName);
+    }
+
     private List<LongestMatchColumnWidthData> dataLong() {
         List<LongestMatchColumnWidthData> list = ListUtils.newArrayList();
         for (int i = 0; i < 10; i++) {
EOF_114329324912

# Apply code formatting (as recommended by context retrieval agent)
./mvnw spotless:apply || true

# Run the specific test files using fully qualified class names
# WriteHandler.java is NOT a test class, so we only run the two actual test classes
./mvnw clean test -Dmaven.test.skip=false -Dtest=cn.idev.excel.test.demo.fill.FillTest,cn.idev.excel.test.demo.write.WriteTest -pl fastexcel

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
git checkout df097faa158950ac45cf2a1e98b5d6ec5d7ad981 "fastexcel/src/test/java/cn/idev/excel/test/core/handler/WriteHandler.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/fill/FillTest.java" "fastexcel/src/test/java/cn/idev/excel/test/demo/write/WriteTest.java"