#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout b0fe79d52780c425e234ba5ac733b601afb50ee7 "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -170,18 +170,6 @@ void ArgParserTests::clientArgs()
   QVERIFY(args.m_shouldExitOk);
 }
 
-void ArgParserTests::client_setLangSync()
-{
-  deskflow::ClientArgs clientArgs;
-  clientArgs.m_enableLangSync = false;
-  const int argc = 2;
-  std::array<const char *, argc> kLangCmd = {"stub", "--sync-language"};
-
-  m_parser.parseClientArgs(clientArgs, argc, kLangCmd.data());
-
-  QVERIFY(clientArgs.m_enableLangSync);
-}
-
 void ArgParserTests::client_setInvertScroll()
 {
   deskflow::ClientArgs clientArgs;
diff --git a/src/unittests/deskflow/ArgParserTests.h b/src/unittests/deskflow/ArgParserTests.h
--- a/src/unittests/deskflow/ArgParserTests.h
+++ b/src/unittests/deskflow/ArgParserTests.h
@@ -22,7 +22,6 @@ private Q_SLOTS:
   void getArgv();
   void assembleCommand();
   void clientArgs();
-  void client_setLangSync();
   void client_setInvertScroll();
   void client_setAddress();
   void client_badArgs();
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -330,6 +330,46 @@ void CoreArgParserTests::client_yscroll()
   QCOMPARE(15, Settings::value(Settings::Client::ScrollSpeed).toInt());
 }
 
+void CoreArgParserTests::client_languageSync_true()
+{
+  QStringList args = {"stub", "client", "--languageSync", "true"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Client::LanguageSync).toBool());
+}
+
+void CoreArgParserTests::client_languageSync_false()
+{
+  QStringList args = {"stub", "client", "--languageSync", "false"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Client::LanguageSync).toBool());
+}
+
+void CoreArgParserTests::client_languageSync_1()
+{
+  QStringList args = {"stub", "client", "--languageSync", "1"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Client::LanguageSync).toBool());
+}
+
+void CoreArgParserTests::client_languageSync_0()
+{
+  QStringList args = {"stub", "client", "--languageSync", "0"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Client::LanguageSync).toBool());
+}
+
 void CoreArgParserTests::preventSleep_true()
 {
   QStringList args = {"stub", "client", "--prevent-sleep", "true"};
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -46,6 +46,10 @@ private Q_SLOTS:
   void server_peerCheck_true();
   void server_setConfig();
   void client_yscroll();
+  void client_languageSync_true();
+  void client_languageSync_false();
+  void client_languageSync_1();
+  void client_languageSync_0();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed/build
cmake --build . --config Release --parallel 4

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the target test executables
# Based on the test configuration, both ArgParserTests and CoreArgParserTests are in build/src/unittests/deskflow/
cd /testbed

# Run ArgParserTests
./build/src/unittests/deskflow/ArgParserTests
argparser_rc=$?

# Run CoreArgParserTests
./build/src/unittests/deskflow/CoreArgParserTests
coreargparser_rc=$?

# Combine exit codes - fail if either test fails
if [ $argparser_rc -ne 0 ] || [ $coreargparser_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout b0fe79d52780c425e234ba5ac733b601afb50ee7 "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"