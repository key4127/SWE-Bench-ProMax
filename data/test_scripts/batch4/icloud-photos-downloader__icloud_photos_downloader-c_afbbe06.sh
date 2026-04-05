#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 4b778b3b1e8602d381bde7c663e92958aea1dc9b "tests/test_authentication.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_authentication.py b/tests/test_authentication.py
--- a/tests/test_authentication.py
+++ b/tests/test_authentication.py
@@ -10,7 +10,7 @@
 from vcr import VCR
 
 import pyicloud_ipd
-from foundation.core import constant, identity
+from foundation.core import constant
 from icloudpd.authentication import authenticator
 from icloudpd.base import dummy_password_writter
 from icloudpd.logger import setup_logger
@@ -45,7 +45,6 @@ def test_failed_auth(self) -> None:
                 authenticator(
                     setup_logger(),
                     "com",
-                    identity,
                     RawTreatmentPolicy.AS_IS,
                     FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                     {"test": (constant("dummy"), dummy_password_writter)},
@@ -258,7 +257,6 @@ def test_non_2fa(self) -> None:
             authenticator(
                 setup_logger(),
                 "com",
-                identity,
                 RawTreatmentPolicy.AS_IS,
                 FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                 {"test": (constant("dummy"), dummy_password_writter)},
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# Using -v for verbose output to help with debugging
# Using --tb=short for concise traceback output
# Using --timeout=300 as specified in pytest configuration
pytest tests/test_authentication.py -v --tb=short --no-header -rA --timeout=300
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 4b778b3b1e8602d381bde7c663e92958aea1dc9b "tests/test_authentication.py"