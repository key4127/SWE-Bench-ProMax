#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test file to ensure clean state
git checkout 92bcff8e0b50570294c3d13f6b598821ad3daff6 "db/swappable_db_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/db/swappable_db_test.go b/db/swappable_db_test.go
--- a/db/swappable_db_test.go
+++ b/db/swappable_db_test.go
@@ -12,7 +12,7 @@ func Test_OpenSwappable_Success(t *testing.T) {
 	defer os.Remove(path)
 
 	// Attempt to open a swappable database
-	swappableDB, err := OpenSwappable(path, false, false)
+	swappableDB, err := OpenSwappable(path, nil, false, false)
 	if err != nil {
 		t.Fatalf("failed to open swappable database: %s", err)
 	}
@@ -40,7 +40,7 @@ func Test_OpenSwappable_InvalidPath(t *testing.T) {
 	invalidPath := "/invalid/path/to/database"
 
 	// Attempt to open a swappable database with an invalid path
-	swappableDB, err := OpenSwappable(invalidPath, false, false)
+	swappableDB, err := OpenSwappable(invalidPath, nil, false, false)
 	if err == nil {
 		swappableDB.Close()
 		t.Fatalf("expected an error when opening swappable database with invalid path, got nil")
@@ -68,7 +68,7 @@ func Test_SwapSuccess(t *testing.T) {
 	// Create a SwappableDB with an empty database
 	swappablePath := mustTempPath()
 	defer os.Remove(swappablePath)
-	swappableDB, err := OpenSwappable(swappablePath, false, false)
+	swappableDB, err := OpenSwappable(swappablePath, nil, false, false)
 	if err != nil {
 		t.Fatalf("failed to open swappable database: %s", err)
 	}
@@ -98,7 +98,7 @@ func Test_SwapInvalidSQLiteFile(t *testing.T) {
 	// Create a SwappableDB with an empty database
 	swappablePath := mustTempPath()
 	defer os.Remove(swappablePath)
-	swappableDB, err := OpenSwappable(swappablePath, false, false)
+	swappableDB, err := OpenSwappable(swappablePath, nil, false, false)
 	if err != nil {
 		t.Fatalf("failed to open swappable database: %s", err)
 	}
EOF_114329324912

# Execute tests for the entire db package to ensure all type definitions are available
# Using -run flag to target only the swappable-related tests from the target file
go test -v -timeout 10m -run 'Test_OpenSwappable|Test_Swap' ./db/
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 92bcff8e0b50570294c3d13f6b598821ad3daff6 "db/swappable_db_test.go"