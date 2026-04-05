#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a78959e66f0864cd473194d52d0a7b22a9c41f1d "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -164,22 +164,12 @@ void ArgParserTests::assembleCommand()
 void ArgParserTests::clientArgs()
 {
   deskflow::ClientArgs args;
-  char const *argv[] = {kAppId, "--help", "--res-w", "888", "127.0.0.1"};
+  char const *argv[] = {kAppId, "--help", "--res-w", "888"};
 
   QVERIFY(m_parser.parseClientArgs(args, sizeof(argv) / sizeof(argv[0]), argv));
   QVERIFY(args.m_shouldExitOk);
 }
 
-void ArgParserTests::client_setAddress()
-{
-  deskflow::ClientArgs clientArgs;
-  const int argc = 2;
-  const char *kAddressCmd[argc] = {"stub", "mock_address"};
-
-  QVERIFY(m_parser.parseClientArgs(clientArgs, argc, kAddressCmd));
-  QCOMPARE(clientArgs.m_serverAddress, "mock_address");
-}
-
 void ArgParserTests::client_badArgs()
 {
   deskflow::ClientArgs clientArgs;
diff --git a/src/unittests/deskflow/ArgParserTests.h b/src/unittests/deskflow/ArgParserTests.h
--- a/src/unittests/deskflow/ArgParserTests.h
+++ b/src/unittests/deskflow/ArgParserTests.h
@@ -22,7 +22,6 @@ private Q_SLOTS:
   void getArgv();
   void assembleCommand();
   void clientArgs();
-  void client_setAddress();
   void client_badArgs();
   void deprecatedArg_crypoPass_true();
   void deprecatedArg_crypoPass_false();
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -410,6 +410,16 @@ void CoreArgParserTests::client_invertScrolling_0()
   QVERIFY(!Settings::value(Settings::Client::InvertScrollDirection).toBool());
 }
 
+void CoreArgParserTests::client_remoteHost()
+{
+  QStringList args = {"stub", "client", "--remoteHost", "127.0.0.1"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QCOMPARE("127.0.0.1", Settings::value(Settings::Client::RemoteHost).toString());
+}
+
 void CoreArgParserTests::preventSleep_true()
 {
   QStringList args = {"stub", "client", "--prevent-sleep", "true"};
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -54,6 +54,7 @@ private Q_SLOTS:
   void client_invertScrolling_false();
   void client_invertScrolling_1();
   void client_invertScrolling_0();
+  void client_remoteHost();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed
cmake --build build --parallel 4

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the ArgParserTests executable
./build/src/unittests/deskflow/ArgParserTests
rc1=$?

# Run the CoreArgParserTests executable
./build/src/unittests/deskflow/CoreArgParserTests
rc2=$?

# Combine exit codes (if either fails, the overall result is failure)
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout a78959e66f0864cd473194d52d0a7b22a9c41f1d "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"