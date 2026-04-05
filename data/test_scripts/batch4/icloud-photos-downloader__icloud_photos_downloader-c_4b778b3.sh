#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 7e47141c1fc6de162e6ecb22a097419c22472383 "tests/test_authentication.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_authentication.py b/tests/test_authentication.py
--- a/tests/test_authentication.py
+++ b/tests/test_authentication.py
@@ -12,7 +12,7 @@
 import pyicloud_ipd
 from foundation.core import constant, identity
 from icloudpd.authentication import authenticator
-from icloudpd.base import dummy_password_writter, lp_filename_concatinator
+from icloudpd.base import dummy_password_writter
 from icloudpd.logger import setup_logger
 from icloudpd.mfa_provider import MFAProvider
 from icloudpd.status import StatusExchange
@@ -46,7 +46,6 @@ def test_failed_auth(self) -> None:
                     setup_logger(),
                     "com",
                     identity,
-                    lp_filename_concatinator,
                     RawTreatmentPolicy.AS_IS,
                     FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                     {"test": (constant("dummy"), dummy_password_writter)},
@@ -260,7 +259,6 @@ def test_non_2fa(self) -> None:
                 setup_logger(),
                 "com",
                 identity,
-                lp_filename_concatinator,
                 RawTreatmentPolicy.AS_IS,
                 FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                 {"test": (constant("dummy"), dummy_password_writter)},
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# Using -v for verbose output to help with debugging
# Using --tb=short for concise traceback output
# Using --no-header to reduce output noise
# Using -rA to show all test outcomes
pytest tests/test_authentication.py -v --tb=short --no-header -rA
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 7e47141c1fc6de162e6ecb22a097419c22472383 "tests/test_authentication.py"