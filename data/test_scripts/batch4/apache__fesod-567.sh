#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 651d2a46b44435bc4e39f34985de9f0f30b8528b

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/fastexcel/src/test/java/cn/idev/excel/parameter/AutoStripParameterTest.java b/fastexcel/src/test/java/cn/idev/excel/parameter/AutoStripParameterTest.java
new file mode 100644
--- /dev/null
+++ b/fastexcel/src/test/java/cn/idev/excel/parameter/AutoStripParameterTest.java
@@ -0,0 +1,199 @@
+package cn.idev.excel.parameter;
+
+import cn.idev.excel.ExcelReader;
+import cn.idev.excel.ExcelWriter;
+import cn.idev.excel.FastExcel;
+import cn.idev.excel.context.AnalysisContext;
+import cn.idev.excel.event.AnalysisEventListener;
+import cn.idev.excel.read.metadata.ReadSheet;
+import cn.idev.excel.support.ExcelTypeEnum;
+import cn.idev.excel.util.ParameterUtil;
+import cn.idev.excel.util.SheetUtils;
+import cn.idev.excel.util.StringUtils;
+import cn.idev.excel.util.TestFileUtil;
+import cn.idev.excel.write.metadata.WriteSheet;
+import com.alibaba.fastjson2.JSON;
+import java.io.File;
+import java.util.ArrayList;
+import java.util.List;
+import lombok.extern.slf4j.Slf4j;
+import org.junit.jupiter.api.Assertions;
+import org.junit.jupiter.api.Test;
+
+@Slf4j
+public class AutoStripParameterTest {
+
+    private static File testFile;
+    private static final String FW_SPACES = "　";
+    private static final String SPACES = " ";
+
+    @Test
+    public void test03() {
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, null, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, null, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, null, true);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, false, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, false, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, false, true);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, true, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, true, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLS, true, true);
+
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, null, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, null, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, null, true);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, false, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, false, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, false, true);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, true, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, true, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLS, true, true);
+    }
+
+    @Test
+    public void test07() {
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, null, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, null, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, null, true);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, false, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, false, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, false, true);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, true, null);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, true, false);
+        testAutoStripSheetNameInternal(ExcelTypeEnum.XLSX, true, true);
+
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, null, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, null, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, null, true);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, false, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, false, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, false, true);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, true, null);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, true, false);
+        testAutoStripContentInternal(ExcelTypeEnum.XLSX, true, true);
+    }
+
+    @Test
+    public void testCSV() {
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, null, null);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, null, false);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, null, true);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, false, null);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, false, false);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, false, true);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, true, null);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, true, false);
+        testAutoStripContentInternal(ExcelTypeEnum.CSV, true, true);
+    }
+
+    private void testAutoStripSheetNameInternal(
+            final ExcelTypeEnum excelType, final Boolean autoTrim, final Boolean autoStrip) {
+        testFile = TestFileUtil.createNewFile("auto-strip-sheet-name" + excelType.getValue());
+
+        final String sheetNameSpaces = SPACES + "Sheet1" + SPACES;
+        final String sheetNameFullWidthSpaces = FW_SPACES + "Sheet2" + FW_SPACES;
+
+        List<ParameterData> demoList = new ArrayList<>();
+        ParameterData simpleData = new ParameterData();
+        simpleData.setName("string");
+        demoList.add(simpleData);
+
+        try (ExcelWriter excelWriter = FastExcel.write(testFile, ParameterData.class)
+                .excelType(excelType)
+                .autoTrim(autoTrim)
+                .autoStrip(autoStrip)
+                .build()) {
+            WriteSheet writeSheet = FastExcel.writerSheet(sheetNameSpaces).build();
+            excelWriter.write(demoList, writeSheet);
+            writeSheet = FastExcel.writerSheet(sheetNameFullWidthSpaces).build();
+            excelWriter.write(demoList, writeSheet);
+        }
+
+        try (ExcelReader excelReader = FastExcel.read(testFile)
+                .excelType(excelType)
+                .head(ParameterData.class)
+                .registerReadListenerIfNotNull(new AnalysisEventListener<ParameterData>() {
+                    @Override
+                    public void invoke(ParameterData data, AnalysisContext context) {
+                        log.info("Read one record: {}", JSON.toJSONString(data));
+                    }
+
+                    @Override
+                    public void doAfterAllAnalysed(AnalysisContext context) {
+                        // global configuration match
+                        Assertions.assertEquals(
+                                autoTrim == null ? Boolean.TRUE : autoTrim,
+                                ParameterUtil.getAutoTrimFlag(
+                                        context.readSheetHolder().getReadSheet(), context));
+                        Assertions.assertEquals(
+                                autoStrip == null ? Boolean.FALSE : autoStrip,
+                                ParameterUtil.getAutoStripFlag(
+                                        context.readSheetHolder().getReadSheet(), context));
+
+                        // sheet name match
+                        ReadSheet readSheet = context.readSheetHolder().getReadSheet();
+                        Assertions.assertEquals(readSheet, SheetUtils.match(readSheet, context));
+                    }
+                })
+                .autoTrim(autoTrim)
+                .autoStrip(autoStrip)
+                .build()) {
+
+            // set sheet name
+            excelReader.read(
+                    FastExcel.readSheet(sheetNameSpaces).build(),
+                    FastExcel.readSheet(sheetNameFullWidthSpaces).build());
+        }
+    }
+
+    private void testAutoStripContentInternal(
+            final ExcelTypeEnum excelType, final Boolean autoTrim, final Boolean autoStrip) {
+        testFile = TestFileUtil.createNewFile("auto-strip-content" + excelType.getValue());
+
+        final String testContentSpaces = SPACES + "String Data1" + SPACES;
+        final String testContentFullWidthSpaces = FW_SPACES + "String Data2" + FW_SPACES;
+
+        List<ParameterData> demoList = new ArrayList<>();
+        ParameterData simpleData = new ParameterData();
+        // normal spaces
+        simpleData.setName(testContentSpaces);
+        demoList.add(simpleData);
+
+        simpleData = new ParameterData();
+        // full-width spaces
+        simpleData.setName(testContentFullWidthSpaces);
+        demoList.add(simpleData);
+
+        FastExcel.write(testFile, ParameterData.class)
+                .excelType(excelType)
+                .autoTrim(autoTrim)
+                .autoStrip(autoStrip)
+                .sheet()
+                .doWrite(demoList);
+
+        List<ParameterData> dataList = FastExcel.read(testFile)
+                .excelType(excelType)
+                .head(ParameterData.class)
+                .autoTrim(autoTrim)
+                .autoStrip(autoStrip)
+                .sheet()
+                .doReadSync();
+
+        log.info("Read records: {}", JSON.toJSONString(dataList));
+        Assertions.assertEquals(2, dataList.size());
+        if (Boolean.TRUE.equals(autoStrip)) {
+            Assertions.assertEquals(
+                    StringUtils.strip(testContentSpaces), dataList.get(0).getName());
+            Assertions.assertEquals(
+                    StringUtils.strip(testContentFullWidthSpaces),
+                    dataList.get(1).getName());
+        } else if (autoTrim == null || autoTrim) {
+            Assertions.assertEquals(testContentSpaces.trim(), dataList.get(0).getName());
+            Assertions.assertEquals(
+                    testContentFullWidthSpaces.trim(), dataList.get(1).getName());
+        } else {
+            Assertions.assertEquals(testContentSpaces, dataList.get(0).getName());
+            Assertions.assertEquals(testContentFullWidthSpaces, dataList.get(1).getName());
+        }
+    }
+}
diff --git a/fastexcel/src/test/java/cn/idev/excel/util/StringUtilsTest.java b/fastexcel/src/test/java/cn/idev/excel/util/StringUtilsTest.java
new file mode 100644
--- /dev/null
+++ b/fastexcel/src/test/java/cn/idev/excel/util/StringUtilsTest.java
@@ -0,0 +1,34 @@
+package cn.idev.excel.util;
+
+import org.junit.jupiter.api.Assertions;
+import org.junit.jupiter.api.Test;
+
+public class StringUtilsTest {
+
+    @Test
+    void stripTest() {
+        Assertions.assertNull(StringUtils.strip(null));
+        Assertions.assertEquals("", StringUtils.strip(""));
+        Assertions.assertEquals("", StringUtils.strip("   "));
+        Assertions.assertEquals("abc", StringUtils.strip("abc"));
+        Assertions.assertEquals("abc", StringUtils.strip("  abc"));
+        Assertions.assertEquals("abc", StringUtils.strip("abc  "));
+        Assertions.assertEquals("abc", StringUtils.strip(" abc "));
+        Assertions.assertEquals("abc", StringUtils.strip("　abc　"));
+        Assertions.assertEquals("abc", StringUtils.strip(" abc　"));
+        Assertions.assertEquals("ab　c", StringUtils.strip(" ab　c　"));
+        Assertions.assertEquals("ab c", StringUtils.strip(" ab c "));
+    }
+
+    @Test
+    void isBlankCharTest() {
+        Assertions.assertTrue(StringUtils.isBlankChar(' '));
+        Assertions.assertTrue(StringUtils.isBlankChar('　'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\ufeff'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\u202a'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\u3164'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\u2800'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\u200c'));
+        Assertions.assertTrue(StringUtils.isBlankChar('\u180e'));
+    }
+}
EOF_114329324912

# Apply code formatting (as recommended by context retrieval agent)
./mvnw spotless:apply || true

# Run the specific test files using fully qualified class names
# Based on the test patch analysis, the actual test classes are:
# 1. cn.idev.excel.parameter.AutoStripParameterTest
# 2. cn.idev.excel.util.StringUtilsTest
./mvnw clean test -Dmaven.test.skip=false -Dtest=cn.idev.excel.parameter.AutoStripParameterTest,cn.idev.excel.util.StringUtilsTest -pl fastexcel

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original state
git checkout 651d2a46b44435bc4e39f34985de9f0f30b8528b