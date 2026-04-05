#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 10a5115c3ec017149e14b11eb7287629efb284d6 "tests/test_download_photos.py" "tests/test_download_photos_id.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_download_photos.py b/tests/test_download_photos.py
--- a/tests/test_download_photos.py
+++ b/tests/test_download_photos.py
@@ -133,9 +133,9 @@ def test_download_photos_and_set_exif(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -436,7 +436,7 @@ def test_handle_io_error(self) -> None:
     def test_handle_session_error_during_download(self) -> None:
         base_dir = os.path.join(self.fixtures_path, inspect.stack()[0][3])
 
-        def mock_raise_response_error(_arg: Any, _size: Any) -> NoReturn:
+        def mock_raise_response_error(_arg: Any, _session: Any, _size: Any) -> NoReturn:
             raise PyiCloudAPIResponseException("Invalid global session", "100")
 
         with mock.patch("time.sleep") as sleep_mock:  # noqa: SIM117
@@ -1134,9 +1134,9 @@ def test_download_and_dedupe_existing_photos(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(self: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(self: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(self, _url, start)
+                response = orig_download(self, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1321,9 +1321,9 @@ def test_download_one_recent_live_photo(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1376,9 +1376,9 @@ def test_download_one_recent_live_photo_chinese(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1645,7 +1645,7 @@ def test_download_normalized_names(self) -> None:
     def test_handle_internal_error_during_download(self) -> None:
         base_dir = os.path.join(self.fixtures_path, inspect.stack()[0][3])
 
-        def mock_raise_response_error(_arg: Any, _size: Any) -> NoReturn:
+        def mock_raise_response_error(_arg: Any, _session: Any, _size: Any) -> NoReturn:
             raise PyiCloudAPIResponseException("INTERNAL_ERROR", "INTERNAL_ERROR")
 
         with mock.patch("time.sleep") as sleep_mock:  # noqa: SIM117
diff --git a/tests/test_download_photos_id.py b/tests/test_download_photos_id.py
--- a/tests/test_download_photos_id.py
+++ b/tests/test_download_photos_id.py
@@ -129,9 +129,9 @@ def test_download_photos_and_set_exif_name_id7(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -428,7 +428,7 @@ def test_handle_io_error_name_id7(self) -> None:
     def test_handle_session_error_during_download_name_id7(self) -> None:
         base_dir = os.path.join(self.fixtures_path, inspect.stack()[0][3])
 
-        def mock_raise_response_error(_arg: Any, _size: Any) -> NoReturn:
+        def mock_raise_response_error(_arg: Any, _session: Any, _size: Any) -> NoReturn:
             raise PyiCloudAPIResponseException("Invalid global session", "100")
 
         with mock.patch("time.sleep") as sleep_mock:  # noqa: SIM117
@@ -1074,9 +1074,9 @@ def test_download_and_dedupe_existing_photos_name_id7(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(self: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(self: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(self, _url, start)
+                response = orig_download(self, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1238,9 +1238,9 @@ def test_download_one_recent_live_photo_name_id7(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1293,9 +1293,9 @@ def test_download_one_recent_live_photo_chinese_name_id7(self) -> None:
         # Download the first photo, but mock the video download
         orig_download = PhotoAsset.download
 
-        def mocked_download(pa: PhotoAsset, _url: str, start: int) -> Response:
+        def mocked_download(pa: PhotoAsset, session: Any, _url: str, start: int) -> Response:
             if not hasattr(PhotoAsset, "already_downloaded"):
-                response = orig_download(pa, _url, start)
+                response = orig_download(pa, session, _url, start)
                 setattr(PhotoAsset, "already_downloaded", True)  # noqa: B010
                 return response
             return mock.MagicMock()
@@ -1564,7 +1564,7 @@ def test_download_normalized_names_name_id7(self) -> None:
     def test_handle_internal_error_during_download_name_id7(self) -> None:
         base_dir = os.path.join(self.fixtures_path, inspect.stack()[0][3])
 
-        def mock_raise_response_error(_arg: Any, _size: Any) -> NoReturn:
+        def mock_raise_response_error(_arg: Any, _session: Any, _size: Any) -> NoReturn:
             raise PyiCloudAPIResponseException("INTERNAL_ERROR", "INTERNAL_ERROR")
 
         with mock.patch("time.sleep") as sleep_mock:  # noqa: SIM117
EOF_114329324912

# Run the target test files
# Note: Running in single-process mode for stability in virtualized environment
# Using -v for verbose output to help with debugging
# Using --tb=short for concise traceback output
pytest tests/test_download_photos.py tests/test_download_photos_id.py -v --tb=short --no-header -rA
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 10a5115c3ec017149e14b11eb7287629efb284d6 "tests/test_download_photos.py" "tests/test_download_photos_id.py"