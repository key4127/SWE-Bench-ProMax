#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Verify which test files actually exist at this commit
echo "=== Verifying test files existence at commit ee296cb7dc0a1bbf990374a68a4ed467de69d34b ==="
ls -la src/test/java/net/sourceforge/plantuml/LoadJsonTest.java || echo "LoadJsonTest.java NOT FOUND"
ls -la src/test/java/net/sourceforge/plantuml/PipeTest.java || echo "PipeTest.java NOT FOUND"
ls -la src/test/java/net/sourceforge/plantuml/TestFileDirOption.java || echo "TestFileDirOption.java NOT FOUND"
ls -la src/test/java/net/sourceforge/plantuml/tim/EaterTest.java || echo "EaterTest.java NOT FOUND"
ls -la src/test/java/nonreg/RenderViaPipeTest.java || echo "RenderViaPipeTest.java NOT FOUND"
ls -la src/test/java/test/test/ExportOnUTextTest.java || echo "ExportOnUTextTest.java NOT FOUND"

# List all test files in the repository to understand structure
echo "=== Listing test directory structure ==="
find src/test/java -name "*.java" -type f | grep -E "(LoadJson|Pipe|FileDirOption|Eater|RenderViaPipe|ExportOnUText)" || echo "No matching test files found"

# Checkout the original test files to ensure clean state (only if they exist)
echo "=== Checking out original test files ==="
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/LoadJsonTest.java" 2>/dev/null || echo "LoadJsonTest.java checkout skipped (file may not exist)"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/PipeTest.java" 2>/dev/null || echo "PipeTest.java checkout skipped (file may not exist)"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/TestFileDirOption.java" 2>/dev/null || echo "TestFileDirOption.java checkout skipped (file may not exist)"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/tim/EaterTest.java" 2>/dev/null || echo "EaterTest.java checkout skipped (file may not exist)"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/nonreg/RenderViaPipeTest.java" 2>/dev/null || echo "RenderViaPipeTest.java checkout skipped (file may not exist)"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/test/test/ExportOnUTextTest.java" 2>/dev/null || echo "ExportOnUTextTest.java checkout skipped (file may not exist)"

# Apply the test patch
echo "=== Applying test patch ==="
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/net/sourceforge/plantuml/LoadJsonTest.java b/src/test/java/net/sourceforge/plantuml/LoadJsonTest.java
--- a/src/test/java/net/sourceforge/plantuml/LoadJsonTest.java
+++ b/src/test/java/net/sourceforge/plantuml/LoadJsonTest.java
@@ -17,6 +17,8 @@
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.api.io.TempDir;
 
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 import net.sourceforge.plantuml.security.SFile;
 
 /**
@@ -125,7 +127,7 @@ private String[] optionArray(String... extraOptions) {
 
     private String render(String diagram, String... extraOptions) throws Exception {
 
-        final Option option = new Option(optionArray(extraOptions));
+        final CliOptions option = CliParser.parse(optionArray(extraOptions));
 
         final ByteArrayInputStream bais = new ByteArrayInputStream(diagram.getBytes(UTF_8));
 
diff --git a/src/test/java/net/sourceforge/plantuml/PipeTest.java b/src/test/java/net/sourceforge/plantuml/PipeTest.java
--- a/src/test/java/net/sourceforge/plantuml/PipeTest.java
+++ b/src/test/java/net/sourceforge/plantuml/PipeTest.java
@@ -19,13 +19,15 @@
 import org.junit.jupiter.params.provider.MethodSource;
 import org.junit.jupiter.params.provider.ValueSource;
 
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 import net.sourceforge.plantuml.error.PSystemError;
 
 class PipeTest {
 
 	ByteArrayOutputStream baos;
 	ErrorStatus errorStatus;
-	Option option;
+	CliOptions option;
 	Pipe pipe;
 	PrintStream ps;
 
@@ -36,7 +38,7 @@ void setup() {
 		errorStatus = ErrorStatus.init();
 
 		baos = new ByteArrayOutputStream();
-		option = new Option();
+		option = new CliOptions();
 		ps = new PrintStream(baos);
 
 		pipe = new Pipe(option, ps, new ByteArrayInputStream(new byte[0]), UTF_8.toString());
@@ -168,7 +170,7 @@ static List<TestCase> managePipeTestCases() {
 	@ParameterizedTest
 	@MethodSource("managePipeTestCases")
 	void should_managePipe_manage_success_cases_correctly(TestCase testCase) throws IOException, InterruptedException {
-		option = new Option(testCase.getOptions().split(" "));
+		option = CliParser.parse(testCase.getOptions().split(" "));
 		pipe = new Pipe(option, ps, new ByteArrayInputStream(testCase.getInput().getBytes(UTF_8)), UTF_8.name());
 
 		pipe.managePipe(errorStatus);
diff --git a/src/test/java/net/sourceforge/plantuml/TestFileDirOption.java b/src/test/java/net/sourceforge/plantuml/TestFileDirOption.java
--- a/src/test/java/net/sourceforge/plantuml/TestFileDirOption.java
+++ b/src/test/java/net/sourceforge/plantuml/TestFileDirOption.java
@@ -17,6 +17,8 @@
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.api.io.TempDir;
 
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 import net.sourceforge.plantuml.picoweb.PicoWebServer;
 import net.sourceforge.plantuml.picoweb.RenderRequest;
 
@@ -102,7 +104,7 @@ private String renderViaPicoWeb(String... extraOptions) throws Exception {
 
 	private String renderViaPipe(String... extraOptions) throws Exception {
 
-		final Option option = new Option(optionArray(extraOptions));
+		final CliOptions option = CliParser.parse(optionArray(extraOptions));
 
 		final ByteArrayInputStream bais = new ByteArrayInputStream(DIAGRAM.getBytes(UTF_8));
 
diff --git a/src/test/java/net/sourceforge/plantuml/cli/CliParserTest.java b/src/test/java/net/sourceforge/plantuml/cli/CliParserTest.java
new file mode 100644
--- /dev/null
+++ b/src/test/java/net/sourceforge/plantuml/cli/CliParserTest.java
@@ -0,0 +1,42 @@
+package net.sourceforge.plantuml.cli;
+
+import static org.junit.jupiter.api.Assertions.assertEquals;
+
+import org.junit.jupiter.api.Test;
+
+class CliParserTest {
+
+	@Test
+	void testParse0010() {
+		assertEquals("{AUTHOR=true, GRAPHVIZ_DOT=foo.exe}",
+				CliParser.parse2("-author", "-graphvizdot", "foo.exe").toString());
+	}
+
+	@Test
+	void testParse0011() {
+		assertEquals("{AUTHOR=true}", CliParser.parse2("-authors").toString());
+	}
+
+	@Test
+	void testParse0012() {
+		assertEquals("{T_SVG=true}", CliParser.parse2("-svg").toString());
+		assertEquals("{T_SVG=true}", CliParser.parse2("-tsvg").toString());
+	}
+
+	@Test
+	void testParse0020() {
+		assertEquals("{DEFINE=FOO=42}", CliParser.parse2("-DFOO=42").toString());
+	}
+
+	@Test
+	void testParse0030() {
+		assertEquals("{DEFINE=DUMMY=null}", CliParser.parse2("-DDUMMY").toString());
+	}
+
+	@Test
+	void testParse00430() {
+		assertEquals("{FTP=null}", CliParser.parse2("-ftp").toString());
+		assertEquals("{FTP=42}", CliParser.parse2("-ftp:42").toString());
+	}
+
+}
diff --git a/src/test/java/net/sourceforge/plantuml/klimt/color/ColorTrieNodeTest.java b/src/test/java/net/sourceforge/plantuml/klimt/color/ColorTrieNodeTest.java
new file mode 100644
--- /dev/null
+++ b/src/test/java/net/sourceforge/plantuml/klimt/color/ColorTrieNodeTest.java
@@ -0,0 +1,22 @@
+package net.sourceforge.plantuml.klimt.color;
+
+import static org.junit.jupiter.api.Assertions.assertEquals;
+import static org.junit.jupiter.api.Assertions.assertNotNull;
+import static org.junit.jupiter.api.Assertions.assertNull;
+
+import java.awt.Color;
+
+import org.junit.jupiter.api.Test;
+
+class ColorTrieNodeTest {
+
+	@Test
+	void testInvalidCharacterIgnoredOnPut() {
+		ColorTrieNode root = ColorTrieNode.INSTANCE;
+
+		assertNull(root.getColor("dark-blue"));
+		assertNotNull(root.getColor("darkblue"));
+		assertEquals(new Color(0x00008B), root.getColor("darkblue"));
+	}
+
+}
diff --git a/src/test/java/net/sourceforge/plantuml/tim/EaterTest.java b/src/test/java/net/sourceforge/plantuml/tim/EaterTest.java
--- a/src/test/java/net/sourceforge/plantuml/tim/EaterTest.java
+++ b/src/test/java/net/sourceforge/plantuml/tim/EaterTest.java
@@ -12,13 +12,13 @@
 
 import org.junit.jupiter.api.DisplayNameGenerator.ReplaceUnderscores;
 import org.junit.jupiter.api.IndicativeSentencesGeneration;
-import org.junit.jupiter.api.Test;
 import org.junit.jupiter.params.ParameterizedTest;
 import org.junit.jupiter.params.provider.CsvSource;
 
 import net.sourceforge.plantuml.ErrorStatus;
-import net.sourceforge.plantuml.Option;
 import net.sourceforge.plantuml.Pipe;
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 
 @IndicativeSentencesGeneration(separator = ": ", generator = ReplaceUnderscores.class)
 /**
@@ -48,7 +48,7 @@ private String[] optionArray(String... extraOptions) {
     }
 
     private String render(String diagram, String... extraOptions) throws Exception {
-        final Option option = new Option(optionArray(extraOptions));
+        final CliOptions option = CliParser.parse(optionArray(extraOptions));
         final ByteArrayInputStream bais = new ByteArrayInputStream(diagram.getBytes(UTF_8));
         final ByteArrayOutputStream baos = new ByteArrayOutputStream();
         final Pipe pipe = new Pipe(option, new PrintStream(baos), bais, option.getCharset());
diff --git a/src/test/java/nonreg/RenderViaPipeTest.java b/src/test/java/nonreg/RenderViaPipeTest.java
--- a/src/test/java/nonreg/RenderViaPipeTest.java
+++ b/src/test/java/nonreg/RenderViaPipeTest.java
@@ -10,13 +10,13 @@
 import java.util.Collections;
 import java.util.List;
 
-import org.junit.jupiter.api.Test;
 import org.junit.jupiter.params.ParameterizedTest;
 import org.junit.jupiter.params.provider.CsvSource;
 
 import net.sourceforge.plantuml.ErrorStatus;
-import net.sourceforge.plantuml.Option;
 import net.sourceforge.plantuml.Pipe;
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 
 /**
  * Tests the Render
@@ -46,7 +46,7 @@ private String[] optionArray(String... extraOptions) {
     }
 
     private String renderViaPipe(String diagram, String... extraOptions) throws Exception {
-        final Option option = new Option(optionArray(extraOptions));
+        final CliOptions option = CliParser.parse(optionArray(extraOptions));
         final ByteArrayInputStream bais = new ByteArrayInputStream(diagram.getBytes(UTF_8));
         final ByteArrayOutputStream baos = new ByteArrayOutputStream();
         final Pipe pipe = new Pipe(option, new PrintStream(baos), bais, option.getCharset());
diff --git a/src/test/java/test/test/ExportOnUTextTest.java b/src/test/java/test/test/ExportOnUTextTest.java
--- a/src/test/java/test/test/ExportOnUTextTest.java
+++ b/src/test/java/test/test/ExportOnUTextTest.java
@@ -10,13 +10,13 @@
 import java.util.Collections;
 import java.util.List;
 
-import org.junit.jupiter.api.Test;
 import org.junit.jupiter.params.ParameterizedTest;
 import org.junit.jupiter.params.provider.CsvSource;
 
 import net.sourceforge.plantuml.ErrorStatus;
-import net.sourceforge.plantuml.Option;
 import net.sourceforge.plantuml.Pipe;
+import net.sourceforge.plantuml.cli.CliOptions;
+import net.sourceforge.plantuml.cli.CliParser;
 
 /**
  * Tests the Render UText
@@ -44,7 +44,7 @@ private String[] optionArray(String... extraOptions) {
     }
 
     private String renderViaPipe(String diagram, String... extraOptions) throws Exception {
-        final Option option = new Option(optionArray(extraOptions));
+        final CliOptions option = CliParser.parse(optionArray(extraOptions));
         final ByteArrayInputStream bais = new ByteArrayInputStream(diagram.getBytes(UTF_8));
         final ByteArrayOutputStream baos = new ByteArrayOutputStream();
         final Pipe pipe = new Pipe(option, new PrintStream(baos), bais, option.getCharset());
EOF_114329324912

# Verify test files after patch
echo "=== Verifying test files after patch ==="
ls -la src/test/java/net/sourceforge/plantuml/LoadJsonTest.java 2>/dev/null || echo "LoadJsonTest.java still NOT FOUND after patch"
ls -la src/test/java/net/sourceforge/plantuml/PipeTest.java 2>/dev/null || echo "PipeTest.java still NOT FOUND after patch"
ls -la src/test/java/net/sourceforge/plantuml/TestFileDirOption.java 2>/dev/null || echo "TestFileDirOption.java still NOT FOUND after patch"
ls -la src/test/java/net/sourceforge/plantuml/tim/EaterTest.java 2>/dev/null || echo "EaterTest.java still NOT FOUND after patch"
ls -la src/test/java/nonreg/RenderViaPipeTest.java 2>/dev/null || echo "RenderViaPipeTest.java still NOT FOUND after patch"
ls -la src/test/java/test/test/ExportOnUTextTest.java 2>/dev/null || echo "ExportOnUTextTest.java still NOT FOUND after patch"

# Clean previous test results to ensure fresh execution
echo "=== Cleaning previous test results ==="
./gradlew cleanTest --no-daemon

# Run tests with verbose output and force rerun
# Using --info for detailed output, --no-daemon to avoid daemon issues, --rerun-tasks to force execution
echo "=== Running tests with verbose output ==="
./gradlew test \
    --tests "net.sourceforge.plantuml.LoadJsonTest" \
    --tests "net.sourceforge.plantuml.PipeTest" \
    --tests "net.sourceforge.plantuml.TestFileDirOption" \
    --tests "net.sourceforge.plantuml.tim.EaterTest" \
    --tests "nonreg.RenderViaPipeTest" \
    --tests "test.test.ExportOnUTextTest" \
    --no-daemon \
    --info \
    --rerun-tasks

# Capture the exit code
rc=$?

# Display test results from XML reports
echo "=== Test Results from XML Reports ==="
if [ -d build/test-results/test ]; then
    echo "Test result files found:"
    ls -la build/test-results/test/
    for xml_file in build/test-results/test/TEST-*.xml; do
        if [ -f "$xml_file" ]; then
            echo "=== Content of $xml_file ==="
            cat "$xml_file"
        fi
    done
else
    echo "Test results directory not found"
fi

# Display test report summary
echo "=== Test Report Summary ==="
if [ -d build/reports/tests/test ]; then
    find build/reports/tests/test -name "*.html" -type f | head -10
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files (only if they existed)
echo "=== Restoring original test files ==="
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/LoadJsonTest.java" 2>/dev/null || echo "LoadJsonTest.java restore skipped"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/PipeTest.java" 2>/dev/null || echo "PipeTest.java restore skipped"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/TestFileDirOption.java" 2>/dev/null || echo "TestFileDirOption.java restore skipped"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/net/sourceforge/plantuml/tim/EaterTest.java" 2>/dev/null || echo "EaterTest.java restore skipped"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/nonreg/RenderViaPipeTest.java" 2>/dev/null || echo "RenderViaPipeTest.java restore skipped"
git checkout ee296cb7dc0a1bbf990374a68a4ed467de69d34b "src/test/java/test/test/ExportOnUTextTest.java" 2>/dev/null || echo "ExportOnUTextTest.java restore skipped"