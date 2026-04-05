#!/bin/bash
set -uxo pipefail

# Change to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout afbbe06b6c18e411a42861a18da652fdecdf360a "tests/test_authentication.py" "tests/test_download_photos.py" "tests/test_download_photos_id.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_authentication.py b/tests/test_authentication.py
--- a/tests/test_authentication.py
+++ b/tests/test_authentication.py
@@ -16,7 +16,6 @@
 from icloudpd.logger import setup_logger
 from icloudpd.mfa_provider import MFAProvider
 from icloudpd.status import StatusExchange
-from pyicloud_ipd.file_match import FileMatchPolicy
 from pyicloud_ipd.raw_policy import RawTreatmentPolicy
 from pyicloud_ipd.session import PyiCloudSession
 from pyicloud_ipd.sms import parse_trusted_phone_numbers_payload
@@ -46,7 +45,6 @@ def test_failed_auth(self) -> None:
                     setup_logger(),
                     "com",
                     RawTreatmentPolicy.AS_IS,
-                    FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                     {"test": (constant("dummy"), dummy_password_writter)},
                     MFAProvider.CONSOLE,
                     StatusExchange(),
@@ -258,7 +256,6 @@ def test_non_2fa(self) -> None:
                 setup_logger(),
                 "com",
                 RawTreatmentPolicy.AS_IS,
-                FileMatchPolicy.NAME_SIZE_DEDUP_WITH_SUFFIX,
                 {"test": (constant("dummy"), dummy_password_writter)},
                 MFAProvider.CONSOLE,
                 StatusExchange(),
diff --git a/tests/test_download_photos.py b/tests/test_download_photos.py
--- a/tests/test_download_photos.py
+++ b/tests/test_download_photos.py
@@ -355,6 +355,8 @@ def test_until_found(self) -> None:
                             LivePhotoVersionSize.MEDIUM
                             if (f[2] == "photo" and f[1].endswith(".MOV"))
                             else AssetVersionSize.ORIGINAL,
+                            ANY,  # file_match_policy
+                            ANY,  # filename_cleaner
                         ),
                         files_to_download_ext,
                     )
@@ -890,6 +892,8 @@ def test_download_two_sizes_with_force_size(self) -> None:
                         f"{os.path.join(data_dir, os.path.normpath('2018/07/31/IMG_7409-thumb.JPG'))}",
                         ANY,
                         AssetVersionSize.THUMB,
+                        ANY,  # file_match_policy
+                        ANY,  # filename_cleaner
                     )
 
                     assert result.exit_code == 0
diff --git a/tests/test_download_photos_id.py b/tests/test_download_photos_id.py
--- a/tests/test_download_photos_id.py
+++ b/tests/test_download_photos_id.py
@@ -351,6 +351,8 @@ def test_until_found_name_id7(self) -> None:
                             LivePhotoVersionSize.MEDIUM
                             if (f[2] == "photo" and f[1].endswith(".MOV"))
                             else AssetVersionSize.ORIGINAL,
+                            ANY,  # file_match_policy
+                            ANY,  # filename_cleaner
                         ),
                         files_to_download_ext,
                     )
EOF_114329324912

# Execute the target test files using pytest
# Note: Running in single-process mode for system stability
# Using -v for verbose output and --timeout=300 as specified in the context
# Using --tb=short for concise traceback output
pytest tests/test_authentication.py tests/test_download_photos.py tests/test_download_photos_id.py -v --timeout=300 --tb=short --no-header -rA

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout afbbe06b6c18e411a42861a18da652fdecdf360a "tests/test_authentication.py" "tests/test_download_photos.py" "tests/test_download_photos_id.py"

# Exit with the captured return code
exit $rc