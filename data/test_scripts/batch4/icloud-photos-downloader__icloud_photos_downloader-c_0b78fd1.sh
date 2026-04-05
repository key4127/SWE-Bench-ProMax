#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout a25ba6f72065ec43303ad7fe9a0f23a15f2a63c0 "tests/test_authentication.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_authentication.py b/tests/test_authentication.py
--- a/tests/test_authentication.py
+++ b/tests/test_authentication.py
@@ -16,7 +16,6 @@
 from icloudpd.logger import setup_logger
 from icloudpd.mfa_provider import MFAProvider
 from icloudpd.status import StatusExchange
-from pyicloud_ipd.raw_policy import RawTreatmentPolicy
 from pyicloud_ipd.session import PyiCloudSession
 from pyicloud_ipd.sms import parse_trusted_phone_numbers_payload
 from tests.helpers import path_from_project_root, recreate_path, run_cassette
@@ -44,7 +43,6 @@ def test_failed_auth(self) -> None:
                 authenticator(
                     setup_logger(),
                     "com",
-                    RawTreatmentPolicy.AS_IS,
                     {"test": (constant("dummy"), dummy_password_writter)},
                     MFAProvider.CONSOLE,
                     StatusExchange(),
@@ -255,7 +253,6 @@ def test_non_2fa(self) -> None:
             authenticator(
                 setup_logger(),
                 "com",
-                RawTreatmentPolicy.AS_IS,
                 {"test": (constant("dummy"), dummy_password_writter)},
                 MFAProvider.CONSOLE,
                 StatusExchange(),
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# Using -v for verbose output to help with debugging
# Using --tb=short for concise traceback output
pytest tests/test_authentication.py -v --tb=short --no-header -rA

# Required: capture exit code immediately after test execution
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout a25ba6f72065ec43303ad7fe9a0f23a15f2a63c0 "tests/test_authentication.py"