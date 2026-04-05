#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout both target test files to ensure clean state
git checkout 3b9babbc87819a6ec047c6f9ab11d92d45a6ad5d "internal/home/home_test.go" "internal/llm/prompt/prompt_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/home/home_test.go b/internal/home/home_test.go
new file mode 100644
--- /dev/null
+++ b/internal/home/home_test.go
@@ -0,0 +1,26 @@
+package home
+
+import (
+	"path/filepath"
+	"testing"
+
+	"github.com/stretchr/testify/require"
+)
+
+func TestDir(t *testing.T) {
+	require.NotEmpty(t, Dir())
+}
+
+func TestShort(t *testing.T) {
+	d := filepath.Join(Dir(), "documents", "file.txt")
+	require.Equal(t, filepath.FromSlash("~/documents/file.txt"), Short(d))
+	ad := filepath.FromSlash("/absolute/path/file.txt")
+	require.Equal(t, ad, Short(ad))
+}
+
+func TestLong(t *testing.T) {
+	d := filepath.FromSlash("~/documents/file.txt")
+	require.Equal(t, filepath.Join(Dir(), "documents", "file.txt"), Long(d))
+	ad := filepath.FromSlash("/absolute/path/file.txt")
+	require.Equal(t, ad, Long(ad))
+}
diff --git a/internal/llm/prompt/prompt_test.go b/internal/llm/prompt/prompt_test.go
--- a/internal/llm/prompt/prompt_test.go
+++ b/internal/llm/prompt/prompt_test.go
@@ -2,10 +2,10 @@ package prompt
 
 import (
 	"os"
-	"path/filepath"
-	"runtime"
 	"strings"
 	"testing"
+
+	"github.com/charmbracelet/crush/internal/home"
 )
 
 func TestExpandPath(t *testing.T) {
@@ -25,16 +25,14 @@ func TestExpandPath(t *testing.T) {
 			name:  "tilde expansion",
 			input: "~/documents",
 			expected: func() string {
-				home, _ := os.UserHomeDir()
-				return filepath.Join(home, "documents")
+				return home.Dir() + "/documents"
 			},
 		},
 		{
 			name:  "tilde only",
 			input: "~",
 			expected: func() string {
-				home, _ := os.UserHomeDir()
-				return home
+				return home.Dir()
 			},
 		},
 		{
@@ -69,55 +67,3 @@ func TestExpandPath(t *testing.T) {
 		})
 	}
 }
-
-func TestProcessContextPaths(t *testing.T) {
-	// Create a temporary directory and file for testing
-	tmpDir := t.TempDir()
-	testFile := filepath.Join(tmpDir, "test.txt")
-	testContent := "test content"
-
-	err := os.WriteFile(testFile, []byte(testContent), 0o644)
-	if err != nil {
-		t.Fatalf("Failed to create test file: %v", err)
-	}
-
-	// Test with absolute path to file
-	result := processContextPaths("", []string{testFile})
-	expected := "# From:" + testFile + "\n" + testContent
-
-	if result != expected {
-		t.Errorf("processContextPaths with absolute path failed.\nGot: %q\nWant: %q", result, expected)
-	}
-
-	// Test with directory path (should process all files in directory)
-	result = processContextPaths("", []string{tmpDir})
-	if !strings.Contains(result, testContent) {
-		t.Errorf("processContextPaths with directory path failed to include file content")
-	}
-
-	// Test with tilde expansion (if we can create a file in home directory)
-	tmpDir = t.TempDir()
-	setHomeEnv(t, tmpDir)
-	homeTestFile := filepath.Join(tmpDir, "crush_test_file.txt")
-	err = os.WriteFile(homeTestFile, []byte(testContent), 0o644)
-	if err == nil {
-		defer os.Remove(homeTestFile) // Clean up
-
-		tildeFile := "~/crush_test_file.txt"
-		result = processContextPaths("", []string{tildeFile})
-		expected = "# From:" + homeTestFile + "\n" + testContent
-
-		if result != expected {
-			t.Errorf("processContextPaths with tilde expansion failed.\nGot: %q\nWant: %q", result, expected)
-		}
-	}
-}
-
-func setHomeEnv(tb testing.TB, path string) {
-	tb.Helper()
-	key := "HOME"
-	if runtime.GOOS == "windows" {
-		key = "USERPROFILE"
-	}
-	tb.Setenv(key, path)
-}
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc
export GOTOOLCHAIN=go1.25.0

# Run tests for both packages that contain modified test files
# Using -v for verbose output to help with debugging
go test -v ./internal/home/ ./internal/llm/prompt/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore both original test files
git checkout 3b9babbc87819a6ec047c6f9ab11d92d45a6ad5d "internal/home/home_test.go" "internal/llm/prompt/prompt_test.go"