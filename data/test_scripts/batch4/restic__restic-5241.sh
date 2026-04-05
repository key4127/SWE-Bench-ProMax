#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 5190933561160a61bb6c910f0a2e180cc8fdd2a0 "cmd/restic/flags_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cmd/restic/flags_test.go b/cmd/restic/flags_test.go
--- a/cmd/restic/flags_test.go
+++ b/cmd/restic/flags_test.go
@@ -8,7 +8,7 @@ import (
 // TestFlags checks for double defined flags, the commands will panic on
 // ParseFlags() when a shorthand flag is defined twice.
 func TestFlags(t *testing.T) {
-	for _, cmd := range cmdRoot.Commands() {
+	for _, cmd := range newRootCommand().Commands() {
 		t.Run(cmd.Name(), func(t *testing.T) {
 			cmd.Flags().SetOutput(io.Discard)
 			err := cmd.ParseFlags([]string{"--help"})
EOF_114329324912

# Verify Go environment is properly configured
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export CGO_ENABLED=0

# Run the target test - focusing on the specific test file
# Using -v for verbose output to help with debugging
# Using -p 1 to run tests sequentially for stability in virtualized environment
go test -v -p 1 -run TestFlags ./cmd/restic
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 5190933561160a61bb6c910f0a2e180cc8fdd2a0 "cmd/restic/flags_test.go"