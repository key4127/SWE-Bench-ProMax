#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit and test file (if it exists, otherwise git will skip)
git checkout f8da476b54f9f4e3f3178294775d393ee13b7cc1 "internal/lsp/client_test.go" 2>/dev/null || true

# Apply test patch (adds/modifies internal/lsp/client_test.go)
git apply -v - <<'EOF_114329324912'
diff --git a/internal/lsp/client_test.go b/internal/lsp/client_test.go
new file mode 100644
--- /dev/null
+++ b/internal/lsp/client_test.go
@@ -0,0 +1,93 @@
+package lsp
+
+import (
+	"testing"
+
+	"github.com/stretchr/testify/require"
+)
+
+func TestHandlesFile(t *testing.T) {
+	tests := []struct {
+		name      string
+		fileTypes []string
+		filepath  string
+		expected  bool
+	}{
+		{
+			name:      "no file types specified - handles all files",
+			fileTypes: nil,
+			filepath:  "test.go",
+			expected:  true,
+		},
+		{
+			name:      "empty file types - handles all files",
+			fileTypes: []string{},
+			filepath:  "test.go",
+			expected:  true,
+		},
+		{
+			name:      "matches .go extension",
+			fileTypes: []string{".go"},
+			filepath:  "main.go",
+			expected:  true,
+		},
+		{
+			name:      "matches go extension without dot",
+			fileTypes: []string{"go"},
+			filepath:  "main.go",
+			expected:  true,
+		},
+		{
+			name:      "matches one of multiple extensions",
+			fileTypes: []string{".js", ".ts", ".tsx"},
+			filepath:  "component.tsx",
+			expected:  true,
+		},
+		{
+			name:      "does not match extension",
+			fileTypes: []string{".go", ".rs"},
+			filepath:  "script.sh",
+			expected:  false,
+		},
+		{
+			name:      "matches with full path",
+			fileTypes: []string{".sh"},
+			filepath:  "/usr/local/bin/script.sh",
+			expected:  true,
+		},
+		{
+			name:      "case insensitive matching",
+			fileTypes: []string{".GO"},
+			filepath:  "main.go",
+			expected:  true,
+		},
+		{
+			name:      "bash file types",
+			fileTypes: []string{".sh", ".bash", ".zsh", ".ksh"},
+			filepath:  "script.sh",
+			expected:  true,
+		},
+		{
+			name:      "bash should not handle go files",
+			fileTypes: []string{".sh", ".bash", ".zsh", ".ksh"},
+			filepath:  "main.go",
+			expected:  false,
+		},
+		{
+			name:      "bash should not handle json files",
+			fileTypes: []string{".sh", ".bash", ".zsh", ".ksh"},
+			filepath:  "config.json",
+			expected:  false,
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			client := &Client{
+				fileTypes: tt.fileTypes,
+			}
+			result := client.HandlesFile(tt.filepath)
+			require.Equal(t, tt.expected, result)
+		})
+	}
+}
EOF_114329324912

# Verify Go environment is properly set
export GO111MODULE=on
export CGO_ENABLED=1
export GOPROXY=https://proxy.golang.org,direct

# Ensure dependencies are available
go mod download

# Run tests in the internal/lsp package where client_test.go was added/modified
# Using -v for verbose output to see which tests are executed
# Using -count=1 to disable test caching and ensure fresh runs
# Using -race to detect data races (since this commit fixes a data race issue)
go test -v -count=1 -race ./internal/lsp/...
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes made by the test patch
git checkout f8da476b54f9f4e3f3178294775d393ee13b7cc1 "internal/lsp/client_test.go" 2>/dev/null || true