#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 52da806c5713e4bdbc3be05bc1f78124950c7e9f "pkg/commands/git_commands/rebase_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/commands/git_commands/rebase_test.go b/pkg/commands/git_commands/rebase_test.go
--- a/pkg/commands/git_commands/rebase_test.go
+++ b/pkg/commands/git_commands/rebase_test.go
@@ -128,7 +128,7 @@ func TestRebaseDiscardOldFileChanges(t *testing.T) {
 		},
 		{
 			testName:               "returns error when using gpg",
-			gitConfigMockResponses: map[string]string{"commit.gpgsign": "true"},
+			gitConfigMockResponses: map[string]string{"commit.gpgSign": "true"},
 			commits:                []*models.Commit{{Name: "commit", Hash: "123456"}},
 			commitIndex:            0,
 			fileName:               []string{"test999.txt"},
EOF_114329324912

# Verify Go environment is properly configured
export GOFLAGS=-mod=vendor
export CGO_ENABLED=0

# Verify vendor directory exists
ls -la vendor/ || echo "Warning: vendor directory not found"

# Run the target test file using package-level testing
# This automatically includes all necessary files from the package
# Using -run TestRebase to filter only rebase-related tests
go test -v ./pkg/commands/git_commands/ -run TestRebase 2>&1
rc=$?

# Echo exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 52da806c5713e4bdbc3be05bc1f78124950c7e9f "pkg/commands/git_commands/rebase_test.go"