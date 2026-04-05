#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ff4c9dc42198ebeabad52a7a65e315a423d86edb "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/ArgParserTests.cpp b/src/unittests/deskflow/ArgParserTests.cpp
--- a/src/unittests/deskflow/ArgParserTests.cpp
+++ b/src/unittests/deskflow/ArgParserTests.cpp
@@ -238,13 +238,12 @@ void ArgParserTests::client_commonArgs()
 {
   deskflow::ClientArgs clientArgs;
   clientArgs.m_enableLangSync = false;
-  const int argc = 4;
-  std::array<const char *, argc> kLangCmd = {"stub", "--tls-cert", "tlsCertPath", "--prevent-sleep"};
+  const int argc = 2;
+  std::array<const char *, argc> kLangCmd = {"stub", "--prevent-sleep"};
 
   m_parser.parseClientArgs(clientArgs, argc, kLangCmd.data());
 
   QVERIFY(clientArgs.m_preventSleep);
-  QCOMPARE(clientArgs.m_tlsCertFile, "tlsCertPath");
 }
 
 void ArgParserTests::client_setAddress()
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -150,4 +150,14 @@ void CoreArgParserTests::secure_1()
   QVERIFY(Settings::value(Settings::Security::TlsEnabled).toBool());
 }
 
+void CoreArgParserTests::tlsCert()
+{
+  QStringList args = {"stub", "client", "--tls-cert", "certFile"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QCOMPARE(Settings::value(Settings::Security::Certificate).toString(), "certFile");
+}
+
 QTEST_MAIN(CoreArgParserTests)
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -27,6 +27,7 @@ private Q_SLOTS:
   void secure_true();
   void secure_0();
   void secure_1();
+  void tlsCert();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the affected test binaries to incorporate changes from the patch
# Using parallel build with limited parallelism (4 cores max) for safety in virtualized environment
cd /testbed/build
cmake --build . --config Debug --parallel 4 --target ArgParserTests CoreArgParserTests

# Ensure QT_QPA_PLATFORM is set for headless execution (already set in Dockerfile, but ensuring it's active)
export QT_QPA_PLATFORM=minimal

# Run the target test executables
# Both test binaries are located in build/src/unittests/deskflow/ based on CMake configuration
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
git checkout ff4c9dc42198ebeabad52a7a65e315a423d86edb "src/unittests/deskflow/ArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"