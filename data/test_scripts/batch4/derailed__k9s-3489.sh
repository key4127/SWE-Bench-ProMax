#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout af27aff6ac16d0620ff3ba4b7e5113bd10b431d3 "internal/view/context_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/view/context_test.go b/internal/view/context_test.go
--- a/internal/view/context_test.go
+++ b/internal/view/context_test.go
@@ -17,5 +17,5 @@ func TestContext(t *testing.T) {
 
 	require.NoError(t, ctx.Init(makeCtx(t)))
 	assert.Equal(t, "Contexts", ctx.Name())
-	assert.Len(t, ctx.Hints(), 5)
+	assert.Len(t, ctx.Hints(), 6)
 }
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests at package level
# Using -run to filter for tests in context_test.go (tests starting with TestContext)
# Running at package level ensures all source files are compiled together
# This allows test files to access unexported functions from the package
go test -v ./internal/view -run '^TestContext'

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout af27aff6ac16d0620ff3ba4b7e5113bd10b431d3 "internal/view/context_test.go"