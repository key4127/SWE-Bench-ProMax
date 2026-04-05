#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 5bd53a0e5e1fe969cf477ccf18f2fa4b174cd493 "tests/test_filenames.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_filenames.py b/tests/test_filenames.py
--- a/tests/test_filenames.py
+++ b/tests/test_filenames.py
@@ -11,11 +11,12 @@ def create_mock_photo_asset(base_filename: str = "IMG_1") -> Any:
     """Create a mock PhotoAsset for testing."""
     mock_photo = Mock()
 
-    def mock_calculate_filename(version: AssetVersion, size: VersionSize) -> str:
+    def mock_calculate_filename(
+        version: AssetVersion, size: VersionSize, filename_override: str | None = None
+    ) -> str:
         """Mock implementation of calculate_version_filename."""
-        override_filename = version.filename_override
-        if override_filename is not None:
-            return override_filename
+        if filename_override is not None:
+            return filename_override
 
         # Simple mock logic - use type to determine extension
         if version.type == "com.apple.quicktime-movie":
@@ -61,12 +62,13 @@ def test_disambiguate_filenames_all_diff(self) -> None:
             AssetVersionSize.ALTERNATIVE: AssetVersion(1, "http", "public.heic", "blah"),
             AssetVersionSize.ADJUSTED: AssetVersion(1, "http", "public.jpeg", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup,
             [AssetVersionSize.ORIGINAL, AssetVersionSize.ALTERNATIVE, AssetVersionSize.ADJUSTED],
             mock_photo,
         )
         self.assertEqual(_result, _expect)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_orgraw_alt_adj(self) -> None:
         """keep originals as raw, keep alt as well, but edit alt; edits are the same file type - alternative will be renamed"""
@@ -93,7 +95,7 @@ def test_disambiguate_filenames_keep_orgraw_alt_adj(self) -> None:
             AssetVersionSize.ALTERNATIVE: AssetVersion(1, "http", "public.jpeg", "blah"),
             AssetVersionSize.ADJUSTED: AssetVersion(1, "http", "public.jpeg", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup,
             [AssetVersionSize.ORIGINAL, AssetVersionSize.ALTERNATIVE, AssetVersionSize.ADJUSTED],
             mock_photo,
@@ -106,7 +108,7 @@ def test_disambiguate_filenames_keep_orgraw_alt_adj(self) -> None:
         self.assertIn(AssetVersionSize.ADJUSTED, _result)
 
         # Alternative should have filename override to disambiguate
-        self.assertIsNotNone(_result[AssetVersionSize.ALTERNATIVE].filename_override)
+        self.assertIsNotNone(_overrides.get(AssetVersionSize.ALTERNATIVE))
 
     def test_disambiguate_filenames_keep_latest(self) -> None:
         """just get the latest version"""
@@ -130,8 +132,11 @@ def test_disambiguate_filenames_keep_latest(self) -> None:
         _expect: Dict[VersionSize, AssetVersion] = {
             AssetVersionSize.ADJUSTED: AssetVersion(1, "http", "public.heic", "blah"),
         }
-        _result = disambiguate_filenames(_setup, [AssetVersionSize.ADJUSTED], mock_photo)
+        _result, _overrides = disambiguate_filenames(
+            _setup, [AssetVersionSize.ADJUSTED], mock_photo
+        )
         self.assertEqual(_result, _expect)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_org_adj_diff(self) -> None:
         """keep then as is"""
@@ -156,10 +161,11 @@ def test_disambiguate_filenames_keep_org_adj_diff(self) -> None:
             AssetVersionSize.ORIGINAL: AssetVersion(1, "http", "public.heic", "blah"),
             AssetVersionSize.ADJUSTED: AssetVersion(1, "http", "public.jpeg", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup, [AssetVersionSize.ORIGINAL, AssetVersionSize.ADJUSTED], mock_photo
         )
         self.assertEqual(_result, _expect)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_org_alt_diff(self) -> None:
         """keep then as is"""
@@ -184,10 +190,11 @@ def test_disambiguate_filenames_keep_org_alt_diff(self) -> None:
             AssetVersionSize.ORIGINAL: AssetVersion(1, "http", "com.adobe.raw-image", "blah"),
             AssetVersionSize.ALTERNATIVE: AssetVersion(1, "http", "public.jpeg", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup, [AssetVersionSize.ORIGINAL, AssetVersionSize.ALTERNATIVE], mock_photo
         )
         self.assertEqual(_result, _expect)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_all_when_org_adj_same(self) -> None:
         """tweak adj"""
@@ -218,7 +225,7 @@ def test_disambiguate_filenames_keep_all_when_org_adj_same(self) -> None:
             ),
             AssetVersionSize.ADJUSTED: AssetVersion(1, "http", "public.jpeg", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup,
             [AssetVersionSize.ORIGINAL, AssetVersionSize.ADJUSTED, AssetVersionSize.ALTERNATIVE],
             mock_photo,
@@ -231,7 +238,7 @@ def test_disambiguate_filenames_keep_all_when_org_adj_same(self) -> None:
         self.assertIn(AssetVersionSize.ADJUSTED, _result)
 
         # Adjusted should have filename override to disambiguate from original
-        self.assertIsNotNone(_result[AssetVersionSize.ADJUSTED].filename_override)
+        self.assertIsNotNone(_overrides.get(AssetVersionSize.ADJUSTED))
 
     def test_disambiguate_filenames_keep_org_alt_missing(self) -> None:
         """keep alt when it is missing"""
@@ -255,10 +262,11 @@ def test_disambiguate_filenames_keep_org_alt_missing(self) -> None:
         _expect: Dict[VersionSize, AssetVersion] = {
             AssetVersionSize.ORIGINAL: AssetVersion(1, "http", "public.heic", "blah"),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup, [AssetVersionSize.ORIGINAL, AssetVersionSize.ALTERNATIVE], mock_photo
         )
         self.assertEqual(_result, _expect)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_alt_missing(self) -> None:
         """keep alt when it is missing"""
@@ -278,11 +286,14 @@ def test_disambiguate_filenames_keep_alt_missing(self) -> None:
                 1, "http", "com.apple.quicktime-movie", "blah"
             ),
         }
-        _result = disambiguate_filenames(_setup, [AssetVersionSize.ALTERNATIVE], mock_photo)
+        _result, _overrides = disambiguate_filenames(
+            _setup, [AssetVersionSize.ALTERNATIVE], mock_photo
+        )
 
         # Should get original as alternative since alternative is missing
         self.assertEqual(len(_result), 1)
         self.assertIn(AssetVersionSize.ALTERNATIVE, _result)
+        self.assertEqual(_overrides, {})
 
     def test_disambiguate_filenames_keep_adj_alt_missing(self) -> None:
         """keep alt when it is missing"""
@@ -302,11 +313,12 @@ def test_disambiguate_filenames_keep_adj_alt_missing(self) -> None:
                 1, "http", "com.apple.quicktime-movie", "blah"
             ),
         }
-        _result = disambiguate_filenames(
+        _result, _overrides = disambiguate_filenames(
             _setup, [AssetVersionSize.ADJUSTED, AssetVersionSize.ALTERNATIVE], mock_photo
         )
 
         # Should get original as both adjusted and alternative since both are missing
         self.assertEqual(len(_result), 2)
         self.assertIn(AssetVersionSize.ADJUSTED, _result)
         self.assertIn(AssetVersionSize.ALTERNATIVE, _result)
+        self.assertEqual(_overrides, {})
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# Using -v for verbose output to help with debugging
# Using --tb=short for concise traceback output
# Using --no-header to reduce output noise
# Using -rA to show all test outcomes
pytest tests/test_filenames.py -v --tb=short --no-header -rA
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 5bd53a0e5e1fe969cf477ccf18f2fa4b174cd493 "tests/test_filenames.py"