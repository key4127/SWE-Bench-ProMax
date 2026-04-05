#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 4104a8e6a567696c2708f02f228afedfc14869e8 "cmd/restic/cmd_ls_integration_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cmd/restic/cmd_ls_integration_test.go b/cmd/restic/cmd_ls_integration_test.go
--- a/cmd/restic/cmd_ls_integration_test.go
+++ b/cmd/restic/cmd_ls_integration_test.go
@@ -3,6 +3,7 @@ package main
 import (
 	"context"
 	"encoding/json"
+	"fmt"
 	"strings"
 	"testing"
 
@@ -19,7 +20,7 @@ func testRunLsWithOpts(t testing.TB, gopts GlobalOptions, opts LsOptions, args [
 }
 
 func testRunLs(t testing.TB, gopts GlobalOptions, snapshotID string) []string {
-	out := testRunLsWithOpts(t, gopts, LsOptions{Sort: "name"}, []string{snapshotID})
+	out := testRunLsWithOpts(t, gopts, LsOptions{}, []string{snapshotID})
 	return strings.Split(string(out), "\n")
 }
 
@@ -45,35 +46,13 @@ func TestRunLsNcdu(t *testing.T) {
 		{"latest", "/0"},
 		{"latest", "/0", "/0/9"},
 	} {
-		ncdu := testRunLsWithOpts(t, env.gopts, LsOptions{Ncdu: true, Sort: "name"}, paths)
+		ncdu := testRunLsWithOpts(t, env.gopts, LsOptions{Ncdu: true}, paths)
 		assertIsValidJSON(t, ncdu)
 	}
 }
 
 func TestRunLsSort(t *testing.T) {
-	compareName := []string{
-		"/for_cmd_ls",
-		"/for_cmd_ls/file1.txt",
-		"/for_cmd_ls/file2.txt",
-		"/for_cmd_ls/python.py",
-		"", // last empty line
-	}
-
-	compareSize := []string{
-		"/for_cmd_ls",
-		"/for_cmd_ls/file2.txt",
-		"/for_cmd_ls/file1.txt",
-		"/for_cmd_ls/python.py",
-		"",
-	}
-
-	compareExt := []string{
-		"/for_cmd_ls",
-		"/for_cmd_ls/python.py",
-		"/for_cmd_ls/file1.txt",
-		"/for_cmd_ls/file2.txt",
-		"",
-	}
+	rtest.Equals(t, SortMode(0), SortModeName, "unexpected default sort mode")
 
 	env, cleanup := withTestEnvironment(t)
 	defer cleanup()
@@ -82,27 +61,43 @@ func TestRunLsSort(t *testing.T) {
 	opts := BackupOptions{}
 	testRunBackup(t, env.testdata+"/0", []string{"for_cmd_ls"}, opts, env.gopts)
 
-	// sort by size
-	out := testRunLsWithOpts(t, env.gopts, LsOptions{Sort: "size"}, []string{"latest"})
-	fileList := strings.Split(string(out), "\n")
-	rtest.Assert(t, len(fileList) == 5, "invalid ls --sort size, expected 5 array elements, got %v", len(fileList))
-	for i, item := range compareSize {
-		rtest.Assert(t, item == fileList[i], "invalid ls --sort size, expected element '%s', got '%s'", item, fileList[i])
-	}
-
-	// sort by file extension
-	out = testRunLsWithOpts(t, env.gopts, LsOptions{Sort: "extension"}, []string{"latest"})
-	fileList = strings.Split(string(out), "\n")
-	rtest.Assert(t, len(fileList) == 5, "invalid ls --sort extension, expected 5 array elements, got %v", len(fileList))
-	for i, item := range compareExt {
-		rtest.Assert(t, item == fileList[i], "invalid ls --sort extension, expected element '%s', got '%s'", item, fileList[i])
-	}
-
-	// explicit name sort
-	out = testRunLsWithOpts(t, env.gopts, LsOptions{Sort: "name"}, []string{"latest"})
-	fileList = strings.Split(string(out), "\n")
-	rtest.Assert(t, len(fileList) == 5, "invalid ls --sort name, expected 5 array elements, got %v", len(fileList))
-	for i, item := range compareName {
-		rtest.Assert(t, item == fileList[i], "invalid ls --sort name, expected element '%s', got '%s'", item, fileList[i])
+	for _, test := range []struct {
+		mode     SortMode
+		expected []string
+	}{
+		{
+			SortModeSize,
+			[]string{
+				"/for_cmd_ls",
+				"/for_cmd_ls/file2.txt",
+				"/for_cmd_ls/file1.txt",
+				"/for_cmd_ls/python.py",
+				"",
+			},
+		},
+		{
+			SortModeExt,
+			[]string{
+				"/for_cmd_ls",
+				"/for_cmd_ls/python.py",
+				"/for_cmd_ls/file1.txt",
+				"/for_cmd_ls/file2.txt",
+				"",
+			},
+		},
+		{
+			SortModeName,
+			[]string{
+				"/for_cmd_ls",
+				"/for_cmd_ls/file1.txt",
+				"/for_cmd_ls/file2.txt",
+				"/for_cmd_ls/python.py",
+				"", // last empty line
+			},
+		},
+	} {
+		out := testRunLsWithOpts(t, env.gopts, LsOptions{Sort: test.mode}, []string{"latest"})
+		fileList := strings.Split(string(out), "\n")
+		rtest.Equals(t, test.expected, fileList, fmt.Sprintf("mismatch for mode %v", test.mode))
 	}
 }
EOF_114329324912

# Verify Go environment is properly configured
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export CGO_ENABLED=0

# Run the target test file
# Using -v for verbose output, -timeout 30m for sufficient execution time
# Using -p 1 to run tests sequentially for stability in virtualized environment
# Using -run TestLs to execute only the ls-related tests
go test -v -timeout 30m -p 1 ./cmd/restic -run TestLs
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 4104a8e6a567696c2708f02f228afedfc14869e8 "cmd/restic/cmd_ls_integration_test.go"