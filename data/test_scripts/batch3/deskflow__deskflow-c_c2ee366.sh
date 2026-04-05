#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a8348b1ccb99c14a71ddbf470834c5dc30906bfa "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -234,18 +234,6 @@ void ArgParserTests::client_setInvertScroll()
   QCOMPARE(clientArgs.m_clientScrollDirection, deskflow::ClientScrollDirection::Inverted);
 }
 
-void ArgParserTests::client_commonArgs()
-{
-  deskflow::ClientArgs clientArgs;
-  clientArgs.m_enableLangSync = false;
-  const int argc = 2;
-  std::array<const char *, argc> kLangCmd = {"stub", "--prevent-sleep"};
-
-  m_parser.parseClientArgs(clientArgs, argc, kLangCmd.data());
-
-  QVERIFY(clientArgs.m_preventSleep);
-}
-
 void ArgParserTests::client_setAddress()
 {
   deskflow::ClientArgs clientArgs;
diff --git a/src/unittests/deskflow/ArgParserTests.h b/src/unittests/deskflow/ArgParserTests.h
--- a/src/unittests/deskflow/ArgParserTests.h
+++ b/src/unittests/deskflow/ArgParserTests.h
@@ -28,7 +28,6 @@ private Q_SLOTS:
   void client_yScroll();
   void client_setLangSync();
   void client_setInvertScroll();
-  void client_commonArgs();
   void client_setAddress();
   void client_badArgs();
   void deprecatedArg_crypoPass_true();
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -160,4 +160,44 @@ void CoreArgParserTests::tlsCert()
   QCOMPARE(Settings::value(Settings::Security::Certificate).toString(), "certFile");
 }
 
+void CoreArgParserTests::preventSleep_false()
+{
+  QStringList args = {"stub", "client", "--prevent-sleep", "false"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Core::PreventSleep).toBool());
+}
+
+void CoreArgParserTests::preventSleep_1()
+{
+  QStringList args = {"stub", "client", "--prevent-sleep", "1"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Core::PreventSleep).toBool());
+}
+
+void CoreArgParserTests::preventSleep_0()
+{
+  QStringList args = {"stub", "client", "--prevent-sleep", "0"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Core::PreventSleep).toBool());
+}
+
+void CoreArgParserTests::preventSleep_true()
+{
+  QStringList args = {"stub", "client", "--prevent-sleep", "true"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Core::PreventSleep).toBool());
+}
+
 QTEST_MAIN(CoreArgParserTests)
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -28,6 +28,10 @@ private Q_SLOTS:
   void secure_0();
   void secure_1();
   void tlsCert();
+  void preventSleep_true();
+  void preventSleep_false();
+  void preventSleep_1();
+  void preventSleep_0();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the test executables to incorporate changes from the patch
cd /testbed/build
cmake --build . --config Release --parallel 4 --target ArgParserTests CoreArgParserTests

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the test executables
cd /testbed

# Run ArgParserTests
./build/src/unittests/deskflow/ArgParserTests
rc1=$?

# Run CoreArgParserTests
./build/src/unittests/deskflow/CoreArgParserTests
rc2=$?

# Combine exit codes - if either test fails, the overall result is failure
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout a8348b1ccb99c14a71ddbf470834c5dc30906bfa "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/ArgParserTests.h" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"