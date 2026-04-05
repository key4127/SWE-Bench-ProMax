#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout de3b9d8e2e588e32163366ccf12a4dd39a3ed58e "src/test/shared/gui/mocks/AppConfigMock.h"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/shared/gui/mocks/AppConfigMock.h b/src/test/shared/gui/mocks/AppConfigMock.h
--- a/src/test/shared/gui/mocks/AppConfigMock.h
+++ b/src/test/shared/gui/mocks/AppConfigMock.h
@@ -39,7 +39,6 @@ class AppConfigMock : public deskflow::gui::IAppConfig
   MOCK_METHOD(const QString &, screenName, (), (const, override));
   MOCK_METHOD(bool, logToFile, (), (const, override));
   MOCK_METHOD(const QString &, logFilename, (), (const, override));
-  MOCK_METHOD(QString, coreServerName, (), (const, override));
   MOCK_METHOD(void, persistLogDir, (), (const, override));
   MOCK_METHOD(bool, languageSync, (), (const, override));
   MOCK_METHOD(bool, invertScrollDirection, (), (const, override));
EOF_114329324912

# Rebuild tests to ensure the patched AppConfigMock.h is compiled correctly
cd /testbed
cmake --build build --config Release -j4

# Set required environment variables for headless Qt testing
export QT_QPA_PLATFORM=offscreen
export DISPLAY=:99

# Run unittests - AppConfigMock is used by GUI tests
# Focus on GUI-related tests that use AppConfigMock
./build/bin/unittests --gtest_filter="*Gui*:*AppConfig*:*ClientConnection*"

# Capture exit code from unittests
rc=$?

# Also run integtests if they exist and use AppConfigMock
if [ -f ./build/bin/integtests ]; then
    ./build/bin/integtests --gtest_filter="*Gui*:*AppConfig*"
    integ_rc=$?
    # Use the worse of the two exit codes
    if [ $integ_rc -ne 0 ]; then
        rc=$integ_rc
    fi
fi

echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original file
git checkout de3b9d8e2e588e32163366ccf12a4dd39a3ed58e "src/test/shared/gui/mocks/AppConfigMock.h"