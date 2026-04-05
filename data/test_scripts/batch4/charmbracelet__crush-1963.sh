#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 77bfd1a708e19b58d3c6525c46dd0c2c3add3cf7 "internal/agent/common_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/agent/common_test.go b/internal/agent/common_test.go
--- a/internal/agent/common_test.go
+++ b/internal/agent/common_test.go
@@ -112,7 +112,7 @@ func testEnv(t *testing.T) fakeEnv {
 	require.NoError(t, err)
 
 	q := db.New(conn)
-	sessions := session.NewService(q)
+	sessions := session.NewService(q, conn)
 	messages := message.NewService(q)
 
 	permissions := permission.NewPermissionService(workingDir, true, []string{})
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc

# Run tests for the target test file
# Using the package path approach to ensure all necessary dependencies are included
go test -v ./internal/agent -run "^Test.*" -count=1
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 77bfd1a708e19b58d3c6525c46dd0c2c3add3cf7 "internal/agent/common_test.go"