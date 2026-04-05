#!/bin/bash
set -uxo pipefail

# Activate the conda environment
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate testbed

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 30947b48b869343e1f9fee1824888b0d15546874 "tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py b/tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py
--- a/tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py
+++ b/tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py
@@ -214,7 +214,7 @@ def mock_api_resource(calendar_api_spec):
 @pytest.fixture
 def prepared_converter(converter, calendar_api_spec):
   """Fixture that provides a converter with the API spec already set."""
-  converter.google_api_spec = calendar_api_spec
+  converter._google_api_spec = calendar_api_spec
   return converter
 
 
@@ -242,14 +242,14 @@ class TestGoogleApiToOpenApiConverter:
 
   def test_init(self, converter):
     """Test converter initialization."""
-    assert converter.api_name == "calendar"
-    assert converter.api_version == "v3"
-    assert converter.google_api_resource is None
-    assert converter.google_api_spec is None
-    assert converter.openapi_spec["openapi"] == "3.0.0"
-    assert "info" in converter.openapi_spec
-    assert "paths" in converter.openapi_spec
-    assert "components" in converter.openapi_spec
+    assert converter._api_name == "calendar"
+    assert converter._api_version == "v3"
+    assert converter._google_api_resource is None
+    assert converter._google_api_spec is None
+    assert converter._openapi_spec["openapi"] == "3.0.0"
+    assert "info" in converter._openapi_spec
+    assert "paths" in converter._openapi_spec
+    assert "components" in converter._openapi_spec
 
   def test_fetch_google_api_spec(
       self, converter_with_patched_build, calendar_api_spec
@@ -259,7 +259,7 @@ def test_fetch_google_api_spec(
     converter_with_patched_build.fetch_google_api_spec()
 
     # Verify the results
-    assert converter_with_patched_build.google_api_spec == calendar_api_spec
+    assert converter_with_patched_build._google_api_spec == calendar_api_spec
 
   def test_fetch_google_api_spec_error(self, monkeypatch, converter):
     """Test error handling when fetching Google API specification."""
@@ -282,14 +282,14 @@ def test_convert_info(self, prepared_converter):
     prepared_converter._convert_info()
 
     # Verify the results
-    info = prepared_converter.openapi_spec["info"]
+    info = prepared_converter._openapi_spec["info"]
     assert info["title"] == "Google Calendar API"
     assert info["description"] == "Accesses the Google Calendar API"
     assert info["version"] == "v3"
     assert info["termsOfService"] == "https://developers.google.com/calendar/"
 
     # Check external docs
-    external_docs = prepared_converter.openapi_spec["externalDocs"]
+    external_docs = prepared_converter._openapi_spec["externalDocs"]
     assert external_docs["url"] == "https://developers.google.com/calendar/"
 
   def test_convert_servers(self, prepared_converter):
@@ -298,7 +298,7 @@ def test_convert_servers(self, prepared_converter):
     prepared_converter._convert_servers()
 
     # Verify the results
-    servers = prepared_converter.openapi_spec["servers"]
+    servers = prepared_converter._openapi_spec["servers"]
     assert len(servers) == 1
     assert servers[0]["url"] == "https://www.googleapis.com/calendar/v3"
     assert servers[0]["description"] == "calendar v3 API"
@@ -309,7 +309,7 @@ def test_convert_security_schemes(self, prepared_converter):
     prepared_converter._convert_security_schemes()
 
     # Verify the results
-    security_schemes = prepared_converter.openapi_spec["components"][
+    security_schemes = prepared_converter._openapi_spec["components"][
         "securitySchemes"
     ]
 
@@ -335,7 +335,7 @@ def test_convert_schemas(self, prepared_converter):
     prepared_converter._convert_schemas()
 
     # Verify the results
-    schemas = prepared_converter.openapi_spec["components"]["schemas"]
+    schemas = prepared_converter._openapi_spec["components"]["schemas"]
 
     # Check Calendar schema
     assert "Calendar" in schemas
@@ -524,7 +524,7 @@ def test_convert_methods(self, prepared_converter, calendar_api_spec):
     prepared_converter._convert_methods(methods, "/calendars")
 
     # Verify the results
-    paths = prepared_converter.openapi_spec["paths"]
+    paths = prepared_converter._openapi_spec["paths"]
 
     # Check GET method
     assert "/calendars/{calendarId}" in paths
@@ -565,7 +565,7 @@ def test_convert_resources(self, prepared_converter, calendar_api_spec):
     prepared_converter._convert_resources(resources)
 
     # Verify the results
-    paths = prepared_converter.openapi_spec["paths"]
+    paths = prepared_converter._openapi_spec["paths"]
 
     # Check top-level resource methods
     assert "/calendars/{calendarId}" in paths
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# --no-header: cleaner output
# -rA: show summary of all test outcomes
# --tb=short: shorter traceback format for better readability
# -p no:cacheprovider: disable cache for clean test execution
pytest --no-header -rA --tb=short -p no:cacheprovider tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test file to its original state
git checkout 30947b48b869343e1f9fee1824888b0d15546874 "tests/unittests/tools/google_api_tool/test_googleapi_to_openapi_converter.py"