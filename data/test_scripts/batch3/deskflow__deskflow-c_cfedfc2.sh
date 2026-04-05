#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout cfd580fb21816484851fb63741e60a2fedc5678b "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/CoreArgParserTests.cpp b/src/unittests/deskflow/CoreArgParserTests.cpp
--- a/src/unittests/deskflow/CoreArgParserTests.cpp
+++ b/src/unittests/deskflow/CoreArgParserTests.cpp
@@ -290,6 +290,26 @@ void CoreArgParserTests::hookOptions_true()
   QVERIFY(Settings::value(Settings::Core::UseHooks).toBool());
 }
 
+void CoreArgParserTests::server_peerCheck_false()
+{
+  QStringList args = {"stub", "server", "--peerCertCheck", "false"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(!Settings::value(Settings::Security::CheckPeers).toBool());
+}
+
+void CoreArgParserTests::server_peerCheck_true()
+{
+  QStringList args = {"stub", "server", "--peerCertCheck", "true"};
+
+  CoreArgParser parser(args);
+  parser.parse();
+
+  QVERIFY(Settings::value(Settings::Security::CheckPeers).toBool());
+}
+
 void CoreArgParserTests::preventSleep_true()
 {
   QStringList args = {"stub", "client", "--prevent-sleep", "true"};
diff --git a/src/unittests/deskflow/CoreArgParserTests.h b/src/unittests/deskflow/CoreArgParserTests.h
--- a/src/unittests/deskflow/CoreArgParserTests.h
+++ b/src/unittests/deskflow/CoreArgParserTests.h
@@ -42,6 +42,8 @@ private Q_SLOTS:
   void restartShortOption_true();
   void hookOptions_false();
   void hookOptions_true();
+  void server_peerCheck_false();
+  void server_peerCheck_true();
 
 private:
   inline static const QString m_settingsPath = QStringLiteral("tmp/test");
EOF_114329324912

# Rebuild the affected test binary to incorporate changes from the patch
# Using parallel build with limited parallelism (4 cores max) for safety in virtualized environment
cd /testbed/build
cmake --build . --config Debug --parallel 4 --target CoreArgParserTests

# Ensure QT_QPA_PLATFORM is set for headless execution (already set in Dockerfile, but ensuring it's active)
export QT_QPA_PLATFORM=minimal

# Run the target test executable
# Test binary is located in build/src/unittests/deskflow/ based on CMake configuration
cd /testbed
./build/src/unittests/deskflow/CoreArgParserTests
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout cfd580fb21816484851fb63741e60a2fedc5678b "src/unittests/deskflow/CoreArgParserTests.cpp" "src/unittests/deskflow/CoreArgParserTests.h"