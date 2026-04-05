#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 965782a444bbb9779f9f6bfb34fc1f1bca510156 "pkg/cmd/repo/autolink/create/create_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/repo/autolink/create/create_test.go b/pkg/cmd/repo/autolink/create/create_test.go
--- a/pkg/cmd/repo/autolink/create/create_test.go
+++ b/pkg/cmd/repo/autolink/create/create_test.go
@@ -6,7 +6,6 @@ import (
 	"net/http"
 	"testing"
 
-	"github.com/MakeNowJust/heredoc"
 	"github.com/cli/cli/v2/internal/browser"
 	"github.com/cli/cli/v2/internal/ghrepo"
 	"github.com/cli/cli/v2/pkg/cmd/repo/autolink/shared"
@@ -133,10 +132,7 @@ func TestCreateRun(t *testing.T) {
 				URLTemplate: "https://example.com/TICKET?query=<num>",
 			},
 			stubCreator: stubAutoLinkCreator{},
-			wantStdout: heredoc.Doc(`
-				✓ Alphanumeric autolink created in OWNER/REPO (id: 1)
-				  TICKET-<num> → https://example.com/TICKET?query=<num>
-			`),
+			wantStdout:  "✓ Created repository autolink 1 on OWNER/REPO\n",
 		},
 		{
 			name: "success, numeric",
@@ -146,10 +142,7 @@ func TestCreateRun(t *testing.T) {
 				Numeric:     true,
 			},
 			stubCreator: stubAutoLinkCreator{},
-			wantStdout: heredoc.Doc(`
-				✓ Numeric autolink created in OWNER/REPO (id: 1)
-				  TICKET-<num> → https://example.com/TICKET?query=<num>
-			`),
+			wantStdout:  "✓ Created repository autolink 1 on OWNER/REPO\n",
 		},
 		{
 			name: "client error",
@@ -180,7 +173,7 @@ func TestCreateRun(t *testing.T) {
 			if tt.expectedErr != nil {
 				require.Error(t, err)
 				assert.ErrorIs(t, err, tt.expectedErr)
-				assert.Equal(t, err.Error(), tt.errMsg)
+				assert.Equal(t, tt.errMsg, err.Error())
 			} else {
 				require.NoError(t, err)
 			}
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
go test -v ./pkg/cmd/repo/autolink/create/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 965782a444bbb9779f9f6bfb34fc1f1bca510156 "pkg/cmd/repo/autolink/create/create_test.go"