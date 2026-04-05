#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 31da8a2c361ae33fb11755bfe70eb06a15ee7da2 "test/testimportproject.cpp"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/testimportproject.cpp b/test/testimportproject.cpp
--- a/test/testimportproject.cpp
+++ b/test/testimportproject.cpp
@@ -38,6 +38,7 @@ class TestImporter : public ImportProject {
     using ImportProject::importCppcheckGuiProject;
     using ImportProject::importVcxproj;
     using ImportProject::SharedItemsProject;
+    using ImportProject::collectArgs;
 };
 
 
@@ -75,6 +76,13 @@ class TestImportProject : public TestFixture {
         TEST_CASE(importCppcheckGuiProjectPremiumMisra);
         TEST_CASE(ignorePaths);
         TEST_CASE(testVcxprojUnicode);
+        TEST_CASE(testCollectArgs1);
+        TEST_CASE(testCollectArgs2);
+        TEST_CASE(testCollectArgs3);
+        TEST_CASE(testCollectArgs4);
+        TEST_CASE(testCollectArgs5);
+        TEST_CASE(testCollectArgs6);
+        TEST_CASE(testCollectArgs7);
     }
 
     void setDefines() const {
@@ -579,6 +587,99 @@ class TestImportProject : public TestFixture {
         ASSERT_EQUALS(project.fileSettings.back().useMfc, true);
     }
 
+    void testCollectArgs1() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "  gcc -o main main.c  ";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("main.c", args[3]);
+    }
+
+    void testCollectArgs2() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main \"directory with space\"/main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("directory with space/main.c", args[3]);
+    }
+
+    void testCollectArgs3() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main directory\\ with\\ space/main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("directory with space/main.c", args[3]);
+    }
+
+    void testCollectArgs4() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main \'directory with space\'/main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("directory with space/main.c", args[3]);
+    }
+
+    void testCollectArgs5() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main directory_with_quote\\\"/main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("directory_with_quote\"/main.c", args[3]);
+    }
+
+    void testCollectArgs6() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main windows\\\\path\\\\main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("", error);
+        ASSERT_EQUALS(4, args.size());
+        ASSERT_EQUALS("gcc", args[0]);
+        ASSERT_EQUALS("-o", args[1]);
+        ASSERT_EQUALS("main", args[2]);
+        ASSERT_EQUALS("windows\\path\\main.c", args[3]);
+    }
+
+    void testCollectArgs7() const
+    {
+        std::vector<std::string> args;
+        const std::string cmd = "gcc -o main \"non-terminated-quote/main.c";
+        const std::string error = TestImporter::collectArgs(cmd, args);
+
+        ASSERT_EQUALS("Missing closing quote in command string", error);
+    }
+
     // TODO: test fsParseCommand()
 
     // TODO: test vcxproj conditions
EOF_114329324912

# Rebuild the testrunner with the patched test file
# Using Make as the primary build system
make -j4 HAVE_RULES=yes CXXFLAGS="-std=c++11 -O2" testrunner

# Run only the TestImportProject test class from /testbed directory
# The testrunner executable is in /testbed/, not /testbed/test/
./testrunner TestImportProject
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset the test file to original state
git checkout 31da8a2c361ae33fb11755bfe70eb06a15ee7da2 "test/testimportproject.cpp"