#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2311a046886df4274b83bd9b684582073b74c299 "pkg/cmd/agent-task/shared/capi_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/shared/capi_test.go b/pkg/cmd/agent-task/shared/capi_test.go
--- a/pkg/cmd/agent-task/shared/capi_test.go
+++ b/pkg/cmd/agent-task/shared/capi_test.go
@@ -61,7 +61,7 @@ func TestParsePullRequestAgentSessionURL(t *testing.T) {
 
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			sessionID, err := ParsePullRequestAgentSessionURL(tt.url)
+			sessionID, err := ParseSessionIDFromURL(tt.url)
 
 			if tt.wantErr {
 				require.Error(t, err)
EOF_114329324912

# Run the target tests
# Running all tests in the package without -run filter since the test functions are
# TestIsSession and TestParsePullRequestAgentSessionURL (not TestCapi*)
go test -v ./pkg/cmd/agent-task/shared/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 2311a046886df4274b83bd9b684582073b74c299 "pkg/cmd/agent-task/shared/capi_test.go"