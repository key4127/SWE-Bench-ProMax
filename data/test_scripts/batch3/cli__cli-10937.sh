#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 2ee68411a76a62ae703fb5d03fcc8e2995406204 "internal/prompter/accessible_prompter_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/prompter/accessible_prompter_test.go b/internal/prompter/accessible_prompter_test.go
--- a/internal/prompter/accessible_prompter_test.go
+++ b/internal/prompter/accessible_prompter_test.go
@@ -171,7 +171,7 @@ func TestAccessiblePrompter(t *testing.T) {
 
 		go func() {
 			// Wait for prompt to appear
-			_, err := console.ExpectString("Enter some characters (default: 12345abcdefg)")
+			_, err := console.ExpectString("Enter some characters (default: 12345abcdefg):")
 			require.NoError(t, err)
 
 			// Enter nothing
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Go modules are already downloaded during Docker build
go test -v ./internal/prompter/accessible_prompter_test.go

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 2ee68411a76a62ae703fb5d03fcc8e2995406204 "internal/prompter/accessible_prompter_test.go"