#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout all target test files to ensure clean state
git checkout 442867dc2a9fe440804d50c2af5e961e5acc23cc "internal/fsext/ignore_test.go" "internal/llm/provider/openai_test.go" "internal/llm/tools/grep_test.go" "internal/shell/command_block_test.go" "internal/shell/shell_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/fsext/ignore_test.go b/internal/fsext/ignore_test.go
--- a/internal/fsext/ignore_test.go
+++ b/internal/fsext/ignore_test.go
@@ -2,6 +2,7 @@ package fsext
 
 import (
 	"os"
+	"path/filepath"
 	"testing"
 
 	"github.com/stretchr/testify/require"
@@ -30,3 +31,98 @@ func TestCrushIgnore(t *testing.T) {
 	require.False(t, dl.shouldIgnore("test1.txt", nil), ".txt files should not be ignored")
 	require.True(t, dl.shouldIgnore("test3.tmp", nil), ".tmp files should be ignored by common patterns")
 }
+
+func TestShouldExcludeFile(t *testing.T) {
+	t.Parallel()
+
+	// Create a temporary directory structure for testing
+	tempDir := t.TempDir()
+
+	// Create directories that should be ignored
+	nodeModules := filepath.Join(tempDir, "node_modules")
+	target := filepath.Join(tempDir, "target")
+	customIgnored := filepath.Join(tempDir, "custom_ignored")
+	normalDir := filepath.Join(tempDir, "src")
+
+	for _, dir := range []string{nodeModules, target, customIgnored, normalDir} {
+		if err := os.MkdirAll(dir, 0o755); err != nil {
+			t.Fatalf("Failed to create directory %s: %v", dir, err)
+		}
+	}
+
+	// Create .gitignore file
+	gitignoreContent := "node_modules/\ntarget/\n"
+	if err := os.WriteFile(filepath.Join(tempDir, ".gitignore"), []byte(gitignoreContent), 0o644); err != nil {
+		t.Fatalf("Failed to create .gitignore: %v", err)
+	}
+
+	// Create .crushignore file
+	crushignoreContent := "custom_ignored/\n"
+	if err := os.WriteFile(filepath.Join(tempDir, ".crushignore"), []byte(crushignoreContent), 0o644); err != nil {
+		t.Fatalf("Failed to create .crushignore: %v", err)
+	}
+
+	// Test that ignored directories are properly ignored
+	require.True(t, ShouldExcludeFile(tempDir, nodeModules), "Expected node_modules to be ignored by .gitignore")
+	require.True(t, ShouldExcludeFile(tempDir, target), "Expected target to be ignored by .gitignore")
+	require.True(t, ShouldExcludeFile(tempDir, customIgnored), "Expected custom_ignored to be ignored by .crushignore")
+
+	// Test that normal directories are not ignored
+	require.False(t, ShouldExcludeFile(tempDir, normalDir), "Expected src directory to not be ignored")
+
+	// Test that the workspace root itself is not ignored
+	require.False(t, ShouldExcludeFile(tempDir, tempDir), "Expected workspace root to not be ignored")
+}
+
+func TestShouldExcludeFileHierarchical(t *testing.T) {
+	t.Parallel()
+
+	// Create a nested directory structure for testing hierarchical ignore
+	tempDir := t.TempDir()
+
+	// Create nested directories
+	subDir := filepath.Join(tempDir, "subdir")
+	nestedNormal := filepath.Join(subDir, "normal_nested")
+
+	for _, dir := range []string{subDir, nestedNormal} {
+		if err := os.MkdirAll(dir, 0o755); err != nil {
+			t.Fatalf("Failed to create directory %s: %v", dir, err)
+		}
+	}
+
+	// Create .crushignore in subdir that ignores normal_nested
+	subCrushignore := "normal_nested/\n"
+	if err := os.WriteFile(filepath.Join(subDir, ".crushignore"), []byte(subCrushignore), 0o644); err != nil {
+		t.Fatalf("Failed to create subdir .crushignore: %v", err)
+	}
+
+	// Test hierarchical ignore behavior - this should work because the .crushignore is in the parent directory
+	require.True(t, ShouldExcludeFile(tempDir, nestedNormal), "Expected normal_nested to be ignored by subdir .crushignore")
+	require.False(t, ShouldExcludeFile(tempDir, subDir), "Expected subdir itself to not be ignored")
+}
+
+func TestShouldExcludeFileCommonPatterns(t *testing.T) {
+	t.Parallel()
+
+	tempDir := t.TempDir()
+
+	// Create directories that should be ignored by common patterns
+	commonIgnored := []string{
+		filepath.Join(tempDir, ".git"),
+		filepath.Join(tempDir, "node_modules"),
+		filepath.Join(tempDir, "__pycache__"),
+		filepath.Join(tempDir, "target"),
+		filepath.Join(tempDir, ".vscode"),
+	}
+
+	for _, dir := range commonIgnored {
+		if err := os.MkdirAll(dir, 0o755); err != nil {
+			t.Fatalf("Failed to create directory %s: %v", dir, err)
+		}
+	}
+
+	// Test that common patterns are ignored even without explicit ignore files
+	for _, dir := range commonIgnored {
+		require.True(t, ShouldExcludeFile(tempDir, dir), "Expected %s to be ignored by common patterns", filepath.Base(dir))
+	}
+}
diff --git a/internal/llm/provider/openai_test.go b/internal/llm/provider/openai_test.go
--- a/internal/llm/provider/openai_test.go
+++ b/internal/llm/provider/openai_test.go
@@ -75,7 +75,7 @@ func TestOpenAIClientStreamChoices(t *testing.T) {
 		},
 	}
 
-	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
+	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
 	defer cancel()
 
 	eventsChan := client.stream(ctx, messages, nil)
diff --git a/internal/llm/tools/grep_test.go b/internal/llm/tools/grep_test.go
--- a/internal/llm/tools/grep_test.go
+++ b/internal/llm/tools/grep_test.go
@@ -1,8 +1,6 @@
 package tools
 
 import (
-	"context"
-	"encoding/json"
 	"os"
 	"path/filepath"
 	"regexp"
@@ -59,6 +57,7 @@ func TestGlobToRegexCaching(t *testing.T) {
 }
 
 func TestGrepWithIgnoreFiles(t *testing.T) {
+	t.Parallel()
 	tempDir := t.TempDir()
 
 	// Create test files
@@ -84,32 +83,42 @@ func TestGrepWithIgnoreFiles(t *testing.T) {
 	crushignoreContent := "node_modules/\n"
 	require.NoError(t, os.WriteFile(filepath.Join(tempDir, ".crushignore"), []byte(crushignoreContent), 0o644))
 
-	// Create grep tool
-	grepTool := NewGrepTool(tempDir)
+	// Test both implementations
+	for name, fn := range map[string]func(pattern, path, include string) ([]grepMatch, error){
+		"regex": searchFilesWithRegex,
+		"rg": func(pattern, path, include string) ([]grepMatch, error) {
+			return searchWithRipgrep(t.Context(), pattern, path, include)
+		},
+	} {
+		t.Run(name, func(t *testing.T) {
+			t.Parallel()
+
+			if name == "rg" && getRg() == "" {
+				t.Skip("rg is not in $PATH")
+			}
+
+			matches, err := fn("hello world", tempDir, "")
+			require.NoError(t, err)
 
-	// Create grep parameters
-	params := GrepParams{
-		Pattern: "hello world",
-		Path:    tempDir,
+			// Convert matches to a set of file paths for easier testing
+			foundFiles := make(map[string]bool)
+			for _, match := range matches {
+				foundFiles[filepath.Base(match.path)] = true
+			}
+
+			// Should find file1.txt and file2.txt
+			require.True(t, foundFiles["file1.txt"], "Should find file1.txt")
+			require.True(t, foundFiles["file2.txt"], "Should find file2.txt")
+
+			// Should NOT find ignored files
+			require.False(t, foundFiles["file3.txt"], "Should not find file3.txt (ignored by .gitignore)")
+			require.False(t, foundFiles["lib.js"], "Should not find lib.js (ignored by .crushignore)")
+			require.False(t, foundFiles["secret.key"], "Should not find secret.key (ignored by .gitignore)")
+
+			// Should find exactly 2 matches
+			require.Equal(t, 2, len(matches), "Should find exactly 2 matches")
+		})
 	}
-	paramsJSON, err := json.Marshal(params)
-	require.NoError(t, err)
-
-	// Run grep
-	call := ToolCall{Input: string(paramsJSON)}
-	response, err := grepTool.Run(context.Background(), call)
-	require.NoError(t, err)
-
-	// Check results - should only find file1.txt and file2.txt
-	// ignored/file3.txt should be ignored by .gitignore
-	// node_modules/lib.js should be ignored by .crushignore
-	// secret.key should be ignored by .gitignore
-	result := response.Content
-	require.Contains(t, result, "file1.txt")
-	require.Contains(t, result, "file2.txt")
-	require.NotContains(t, result, "file3.txt")
-	require.NotContains(t, result, "lib.js")
-	require.NotContains(t, result, "secret.key")
 }
 
 func TestSearchImplementations(t *testing.T) {
diff --git a/internal/shell/command_block_test.go b/internal/shell/command_block_test.go
--- a/internal/shell/command_block_test.go
+++ b/internal/shell/command_block_test.go
@@ -1,7 +1,6 @@
 package shell
 
 import (
-	"context"
 	"strings"
 	"testing"
 
@@ -92,7 +91,7 @@ func TestCommandBlocking(t *testing.T) {
 				BlockFuncs: tt.blockFuncs,
 			})
 
-			_, _, err := shell.Exec(context.Background(), tt.command)
+			_, _, err := shell.Exec(t.Context(), tt.command)
 
 			if tt.shouldBlock {
 				if err == nil {
diff --git a/internal/shell/shell_test.go b/internal/shell/shell_test.go
--- a/internal/shell/shell_test.go
+++ b/internal/shell/shell_test.go
@@ -16,7 +16,7 @@ func BenchmarkShellQuickCommands(b *testing.B) {
 	b.ReportAllocs()
 
 	for b.Loop() {
-		_, _, err := shell.Exec(context.Background(), "echo test")
+		_, _, err := shell.Exec(b.Context(), "echo test")
 		exitCode := ExitCode(err)
 		if err != nil || exitCode != 0 {
 			b.Fatalf("Command failed: %v, exit code: %d", err, exitCode)
@@ -100,7 +100,7 @@ func TestRunContinuity(t *testing.T) {
 
 func TestCrossPlatformExecution(t *testing.T) {
 	shell := NewShell(&Options{WorkingDir: "."})
-	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
+	ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
 	defer cancel()
 
 	// Test a simple command that should work on all platforms
EOF_114329324912

# Set Go environment variables (ensuring they're active for test execution)
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc
export GOTOOLCHAIN=go1.25.0

# Run tests for all packages containing the modified test files
# Combining into a single command for efficiency
# Using -v for verbose output to help with debugging
go test -v ./internal/fsext ./internal/llm/provider ./internal/llm/tools ./internal/shell
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore all original test files
git checkout 442867dc2a9fe440804d50c2af5e961e5acc23cc "internal/fsext/ignore_test.go" "internal/llm/provider/openai_test.go" "internal/llm/tools/grep_test.go" "internal/shell/command_block_test.go" "internal/shell/shell_test.go"