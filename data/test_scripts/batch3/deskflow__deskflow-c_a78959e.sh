#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 5fc00f7af49b3fa9a8997fafda256e8e139fb2ef "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -170,17 +170,6 @@ void ArgParserTests::clientArgs()
   QVERIFY(args.m_shouldExitOk);
 }
 
-void ArgParserTests::client_setInvertScroll()
-{
-  deskflow::ClientArgs clientArgs;
-  const int argc = 2;
-  std::array<const char *, argc> kLangCmd = {"stub", "--invert-scroll"};
-
-  m_parser.parseClientArgs(clientArgs, argc, kLangCmd.data());
-
-  QCOMPARE(clientArgs.m_clientScrollDirection, deskflow::ClientScrollDirection::Inverted);
-}
-
 void ArgParserTests::client_setAddress()
 {
   deskflow::ClientArgs clientArgs;
diff --git a/src/unittests/deskflow/ArgParserTests.h b/src/unittests/deskflow/ArgParserTests.h
--- a/src/unittests/deskflow/ArgParserTests.h
+++ b/src/unittests/deskflow/ArgParserTests.h
@@ -22,7 +22,6 @@ private Q_SLOTS:
   void getArgv();
   void assembleCommand();
   void clientArgs();
-  void client_setInvertScroll();
   void client_setAddress();
   void client_badArgs();
   void deprecatedArg_crypoPass_true();
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -370,6 +370,46 @@ void CoreArgParserTests::client_languageSync_0()
   QVERIFY(!Settings::value(Settings::Client::LanguageSync).toBool());
 }
 
+void CoreArgParserTests::client_invertScrolling_true()
+{
+  QStringList args = {"stub", "client", "--invertScrollDirection", "true"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Client::InvertScrollDirection).toBool());
+}
+
+void CoreArgParserTests::client_invertScrolling_false()
+{
+  QStringList args = {"stub", "client", "--invertScrollDirection", "false"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Client::InvertScrollDirection).toBool());
+}
+
+void CoreArgParserTests::client_invertScrolling_1()
+{
+  QStringList args = {"stub", "client", "--invertScrollDirection", "1"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Client::InvertScrollDirection).toBool());
+}
+
+void CoreArgParserTests::client_invertScrolling_0()
+{
+  QStringList args = {"stub", "client", "--invertScrollDirection", "0"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Client::InvertScrollDirection).toBool());
+}
+
 void CoreArgParserTests::preventSleep_true()
 {
   QStringList args = {"stub", "client", "--prevent-sleep", "true"};
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -50,6 +50,10 @@ private Q_SLOTS:
   void client_languageSync_false();
   void client_languageSync_1();
   void client_languageSync_0();
+  void client_invertScrolling_true();
+  void client_invertScrolling_false();
+  void client_invertScrolling_1();
+  void client_invertScrolling_0();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed
cmake --build build --parallel 4

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the specific test executables with correct paths
# Based on the build log analysis, tests are located in their respective source directories
test_failed=0

echo "Running ArgParserTests..."
./build/src/unittests/deskflow/ArgParserTests
if [ $? -ne 0 ]; then
    test_failed=1
fi

echo "Running CoreArgParserTests..."
./build/src/unittests/deskflow/CoreArgParserTests
if [ $? -ne 0 ]; then
    test_failed=1
fi

rc=$test_failed

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout 5fc00f7af49b3fa9a8997fafda256e8e139fb2ef "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"