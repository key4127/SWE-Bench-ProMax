#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2721de220a9eb22ea7f74311c70c15bf751f9a46 "src/test/shared/gui/mocks/AppConfigMock.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/shared/gui/mocks/AppConfigMock.h b/src/test/shared/gui/mocks/AppConfigMock.h
--- a/src/test/shared/gui/mocks/AppConfigMock.h
+++ b/src/test/shared/gui/mocks/AppConfigMock.h
@@ -34,7 +34,6 @@ class AppConfigMock : public deskflow::gui::IAppConfig
 
   MOCK_METHOD(deskflow::gui::IConfigScopes &, scopes, (), (const, override));
   MOCK_METHOD(QString, tlsCertPath, (), (const, override));
-  MOCK_METHOD(int, tlsKeyLength, (), (const, override));
   MOCK_METHOD(ProcessMode, processMode, (), (const, override));
   MOCK_METHOD(ElevateMode, elevateMode, (), (const, override));
   MOCK_METHOD(QString, logLevelText, (), (const, override));
@@ -73,7 +72,6 @@ class AppConfigMock : public deskflow::gui::IAppConfig
   MOCK_METHOD(void, setElevateMode, (ElevateMode elevateMode), (override));
   MOCK_METHOD(void, setPreventSleep, (bool preventSleep), (override));
   MOCK_METHOD(void, setTlsCertPath, (const QString &tlsCertPath), (override));
-  MOCK_METHOD(void, setTlsKeyLength, (int tlsKeyLength), (override));
   MOCK_METHOD(void, setLanguageSync, (bool languageSync), (override));
   MOCK_METHOD(void, setInvertScrollDirection, (bool invertScrollDirection), (override));
   MOCK_METHOD(void, setEnableService, (bool enableService), (override));
EOF_114329324912

# Rebuild tests to ensure the patched mock header compiles correctly
cd /testbed
cmake --build build --config Release -j4

# Capture build exit code
rc=$?

# If build succeeded, run only AppConfig-related tests to verify the mock integrates correctly
if [ $rc -eq 0 ]; then
    export QT_QPA_PLATFORM=offscreen
    ./build/bin/unittests --gtest_filter="*AppConfig*"
    rc=$?
fi

echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original file
git checkout 2721de220a9eb22ea7f74311c70c15bf751f9a46 "src/test/shared/gui/mocks/AppConfigMock.h"