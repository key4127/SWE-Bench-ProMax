#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ead49c402512c6b9faff71280897de43efdf9364 "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -326,22 +326,6 @@ void ArgParserTests::generic_logFileWithSpace()
   QCOMPARE(i, 2);
 }
 
-void ArgParserTests::generic_name()
-{
-  int i = 1;
-  const int argc = 3;
-  const char *kNameCmd[argc] = {"stub", "--name", "mock"};
-  // Somehow cause a dump if not made here.
-  ArgParser parser(nullptr);
-  static deskflow::ArgsBase base;
-
-  parser.setArgsBase(base);
-  parser.parseGenericArgs(argc, kNameCmd, i);
-
-  QCOMPARE(base.m_name, "mock");
-  QCOMPARE(i, 2);
-}
-
 void ArgParserTests::generic_noRestart()
 {
   int i = 1;
diff --git a/src/unittests/deskflow/ArgParserTests.h b/src/unittests/deskflow/ArgParserTests.h
--- a/src/unittests/deskflow/ArgParserTests.h
+++ b/src/unittests/deskflow/ArgParserTests.h
@@ -36,7 +36,6 @@ private Q_SLOTS:
   void generic_logLevel();
   void generic_logFile();
   void generic_logFileWithSpace();
-  void generic_name();
   void generic_noRestart();
   void generic_restart();
   void generic_unknown();
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -60,4 +60,24 @@ void CoreArgParserTests::portShort()
   QCOMPARE(Settings::value(Settings::Core::Port).toInt(), 18768);
 }
 
+void CoreArgParserTests::nameLong()
+{
+  QStringList args = {"stub", "client", "--name", "FancyName"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QCOMPARE(Settings::value(Settings::Core::ScreenName).toString(), "FancyName");
+}
+
+void CoreArgParserTests::nameShort()
+{
+  QStringList args = {"stub", "client", "-n", "ShortName"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QCOMPARE(Settings::value(Settings::Core::ScreenName).toString(), "ShortName");
+}
+
 QTEST_MAIN(CoreArgParserTests)
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -18,6 +18,8 @@ private Q_SLOTS:
   void interfaceShort();
   void portLong();
   void portShort();
+  void nameLong();
+  void nameShort();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed
cmake --build build --parallel 4

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the target test executables
# Based on the test configuration, test executables should be in build/src/unittests/deskflow/
# Run ArgParserTests
./build/src/unittests/deskflow/ArgParserTests
argparser_rc=$?

# Run CoreArgParserTests
./build/src/unittests/deskflow/CoreArgParserTests
coreargparser_rc=$?

# Combine exit codes - if either test fails, the overall result is failure
if [ $argparser_rc -ne 0 ] || [ $coreargparser_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout ead49c402512c6b9faff71280897de43efdf9364 "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"