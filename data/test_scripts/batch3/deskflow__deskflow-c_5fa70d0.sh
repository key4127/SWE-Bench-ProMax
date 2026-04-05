#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout d01c07cab8f0d46c71a77424ef6378c7469a8901 "src/test/shared/gui/mocks/AppConfigMock.h" "src/test/unittests/gui/core/CoreProcessTests.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/shared/gui/mocks/AppConfigMock.h b/src/test/shared/gui/mocks/AppConfigMock.h
--- a/src/test/shared/gui/mocks/AppConfigMock.h
+++ b/src/test/shared/gui/mocks/AppConfigMock.h
@@ -14,7 +14,6 @@
 
 class AppConfigMock : public deskflow::gui::IAppConfig
 {
-  using ProcessMode = deskflow::gui::ProcessMode;
 
 public:
   AppConfigMock()
@@ -26,7 +25,6 @@ class AppConfigMock : public deskflow::gui::IAppConfig
   //
 
   MOCK_METHOD(deskflow::gui::IConfigScopes &, scopes, (), (const, override));
-  MOCK_METHOD(ProcessMode, processMode, (), (const, override));
   MOCK_METHOD(ElevateMode, elevateMode, (), (const, override));
   MOCK_METHOD(bool, enableService, (), (const, override));
   MOCK_METHOD(bool, isActiveScopeSystem, (), (const, override));
diff --git a/src/test/unittests/gui/core/CoreProcessTests.cpp b/src/test/unittests/gui/core/CoreProcessTests.cpp
--- a/src/test/unittests/gui/core/CoreProcessTests.cpp
+++ b/src/test/unittests/gui/core/CoreProcessTests.cpp
@@ -71,7 +71,7 @@ class CoreProcessTests : public Test
   {
     Settings::setValue(Settings::Server::ExternalConfig, true);
     Settings::setValue(Settings::Server::ExternalConfigFile, m_configFile);
-    ON_CALL(m_appConfig, processMode()).WillByDefault(Return(ProcessMode::kDesktop));
+    Settings::setValue(Settings::Core::ProcessMode, Settings::ProcessMode::Desktop);
   }
 
   NiceMock<AppConfigMock> m_appConfig;
@@ -91,7 +91,7 @@ TEST_F(CoreProcessTests, start_serverDesktop_callsProcessStart)
 
   EXPECT_CALL(m_pDeps->m_process, start(_, _)).Times(1);
 
-  m_coreProcess.start(ProcessMode::kDesktop);
+  m_coreProcess.start(Settings::ProcessMode::Desktop);
 }
 
 TEST_F(CoreProcessTests, start_clientDesktop_callsProcessStart)
@@ -101,7 +101,7 @@ TEST_F(CoreProcessTests, start_clientDesktop_callsProcessStart)
 
   EXPECT_CALL(m_pDeps->m_process, start(_, _)).Times(1);
 
-  m_coreProcess.start(ProcessMode::kDesktop);
+  m_coreProcess.start(Settings::ProcessMode::Desktop);
 }
 
 TEST_F(CoreProcessTests, stop_serverDesktop_callsProcessClose)
@@ -111,7 +111,7 @@ TEST_F(CoreProcessTests, stop_serverDesktop_callsProcessClose)
 
   EXPECT_CALL(m_pDeps->m_process, close()).Times(1);
 
-  m_coreProcess.stop(ProcessMode::kDesktop);
+  m_coreProcess.stop(Settings::ProcessMode::Desktop);
 }
 
 TEST_F(CoreProcessTests, stop_clientDesktop_callsProcessClose)
@@ -122,12 +122,12 @@ TEST_F(CoreProcessTests, stop_clientDesktop_callsProcessClose)
 
   EXPECT_CALL(m_pDeps->m_process, close()).Times(1);
 
-  m_coreProcess.stop(ProcessMode::kDesktop);
+  m_coreProcess.stop(Settings::ProcessMode::Desktop);
 }
 
 TEST_F(CoreProcessTests, restart_serverDesktop_callsProcessStart)
 {
-  ON_CALL(m_appConfig, processMode()).WillByDefault(Return(ProcessMode::kDesktop));
+  Settings::setValue(Settings::Core::ProcessMode, Settings::ProcessMode::Desktop);
   m_coreProcess.setMode(CoreProcess::Mode::Server);
   m_coreProcess.start();
 
EOF_114329324912

# Rebuild tests to ensure the patched files are compiled
cd /testbed
cmake --build build --config Release -j4

# Set required environment variable for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the specific CoreProcess tests
./build/bin/unittests --gtest_filter="CoreProcessTests.*"

# Capture exit code from unittests
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
git checkout d01c07cab8f0d46c71a77424ef6378c7469a8901 "src/test/shared/gui/mocks/AppConfigMock.h" "src/test/unittests/gui/core/CoreProcessTests.cpp"