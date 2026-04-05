#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 559e729f9a8ed0d0f073f73985c016f82b212785

# Checkout the specific test file and any related files to ensure they're in the correct state
git checkout 559e729f9a8ed0d0f073f73985c016f82b212785 "pkg/cmd/run/download/zip_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/run/download/zip_test.go b/internal/zip/zip_test.go
rename from pkg/cmd/run/download/zip_test.go
rename to internal/zip/zip_test.go
--- a/pkg/cmd/run/download/zip_test.go
+++ b/internal/zip/zip_test.go
@@ -1,4 +1,4 @@
-package download
+package zip
 
 import (
 	"archive/zip"
@@ -19,7 +19,7 @@ func Test_extractZip(t *testing.T) {
 	require.NoError(t, err)
 	defer zipFile.Close()
 
-	err = extractZip(&zipFile.Reader, extractPath)
+	err = ExtractZip(&zipFile.Reader, extractPath)
 	require.NoError(t, err)
 
 	_, err = os.Stat(filepath.Join(extractPath.String(), "src", "main.go"))
EOF_114329324912

# After applying the patch, the test file is moved to internal/zip/
# We need to ensure test fixtures are accessible from the new location
# Copy the fixtures directory to the new location if it exists
if [ -d "pkg/cmd/run/download/fixtures" ]; then
    mkdir -p internal/zip/fixtures
    cp -r pkg/cmd/run/download/fixtures/* internal/zip/fixtures/ 2>/dev/null || true
fi

# Ensure dependencies are downloaded
go mod download

# Run the specific test file in its new location after the patch
# The patch moves the test file from pkg/cmd/run/download/zip_test.go to internal/zip/zip_test.go
# Using -v for verbose output to see test results clearly
go test -v ./internal/zip/

# Capture the exit code
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 559e729f9a8ed0d0f073f73985c016f82b212785 "pkg/cmd/run/download/zip_test.go"
# Clean up any created directories
rm -rf internal/zip/fixtures 2>/dev/null || true