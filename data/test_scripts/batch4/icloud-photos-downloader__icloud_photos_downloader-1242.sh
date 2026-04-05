#!/bin/bash
set -uxo pipefail

# Change to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 4747fe4b822dec134a9116fb064b7aa74253f151 "tests/test_download_photos.py" "tests/test_download_photos_id.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_download_photos.py b/tests/test_download_photos.py
--- a/tests/test_download_photos.py
+++ b/tests/test_download_photos.py
@@ -355,8 +355,7 @@ def test_until_found(self) -> None:
                             LivePhotoVersionSize.MEDIUM
                             if (f[2] == "photo" and f[1].endswith(".MOV"))
                             else AssetVersionSize.ORIGINAL,
-                            ANY,  # file_match_policy
-                            ANY,  # filename_cleaner
+                            ANY,  # filename_builder
                         ),
                         files_to_download_ext,
                     )
@@ -892,8 +891,7 @@ def test_download_two_sizes_with_force_size(self) -> None:
                         f"{os.path.join(data_dir, os.path.normpath('2018/07/31/IMG_7409-thumb.JPG'))}",
                         ANY,
                         AssetVersionSize.THUMB,
-                        ANY,  # file_match_policy
-                        ANY,  # filename_cleaner
+                        ANY,  # filename_builder
                     )
 
                     assert result.exit_code == 0
diff --git a/tests/test_download_photos_id.py b/tests/test_download_photos_id.py
--- a/tests/test_download_photos_id.py
+++ b/tests/test_download_photos_id.py
@@ -351,8 +351,7 @@ def test_until_found_name_id7(self) -> None:
                             LivePhotoVersionSize.MEDIUM
                             if (f[2] == "photo" and f[1].endswith(".MOV"))
                             else AssetVersionSize.ORIGINAL,
-                            ANY,  # file_match_policy
-                            ANY,  # filename_cleaner
+                            ANY,  # filename_builder
                         ),
                         files_to_download_ext,
                     )
EOF_114329324912

# Execute the target test files using pytest
# Note: Running in single-process mode for system stability
# Using -v for verbose output to help with debugging
pytest tests/test_download_photos.py tests/test_download_photos_id.py -v --tb=short --no-header -rA

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 4747fe4b822dec134a9116fb064b7aa74253f151 "tests/test_download_photos.py" "tests/test_download_photos_id.py"

# Exit with the captured return code
exit $rc