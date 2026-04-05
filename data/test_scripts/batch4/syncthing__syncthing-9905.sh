#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout dcd280e6e2f21ca3e59ada7950460c86f1d4f81d "lib/model/model_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/model/model_test.go b/lib/model/model_test.go
--- a/lib/model/model_test.go
+++ b/lib/model/model_test.go
@@ -1729,15 +1729,15 @@ func TestGlobalDirectoryTree(t *testing.T) {
 			Name:    name,
 			ModTime: time.Unix(0x666, 0),
 			Size:    0xa,
-			Type:    protocol.FileInfoTypeFile,
+			Type:    protocol.FileInfoTypeFile.String(),
 		}
 	}
 	d := func(name string, entries ...*TreeEntry) *TreeEntry {
 		return &TreeEntry{
 			Name:     name,
 			ModTime:  time.Unix(0x666, 0),
 			Size:     128,
-			Type:     protocol.FileInfoTypeDirectory,
+			Type:     protocol.FileInfoTypeDirectory.String(),
 			Children: entries,
 		}
 	}
EOF_114329324912

# Verify Go environment
echo "=== Environment Verification ==="
go version
echo "CGO_ENABLED: $CGO_ENABLED"
echo "GOPATH: $GOPATH"
echo "Working directory: $(pwd)"
echo "Test file exists: $(test -f lib/model/model_test.go && echo yes || echo no)"
echo "================================"

# Run the target test file
# Using -v for verbose output and -count=1 to disable test caching
# Running only the specific test file in the lib/model package
echo "=== Running Tests ==="

go test -v -count=1 ./lib/model -run ".*"

# Capture exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout dcd280e6e2f21ca3e59ada7950460c86f1d4f81d "lib/model/model_test.go"

exit $rc