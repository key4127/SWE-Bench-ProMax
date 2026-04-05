#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 218152f7c5d454bffd019eb63e58645cd1f54639 "pkg/cmd/issue/edit/edit_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/issue/edit/edit_test.go b/pkg/cmd/issue/edit/edit_test.go
--- a/pkg/cmd/issue/edit/edit_test.go
+++ b/pkg/cmd/issue/edit/edit_test.go
@@ -528,8 +528,8 @@ func Test_editRun(t *testing.T) {
 					httpmock.StringResponse(`
 					{ "data": { "repository": { "suggestedActors": {
 						"nodes": [
-							{ "login": "hubot", "id": "HUBOTID" },
-							{ "login": "MonaLisa", "id": "MONAID" }
+							{ "login": "hubot", "id": "HUBOTID", "__typename": "Bot" },
+							{ "login": "MonaLisa", "id": "MONAID", "__typename": "User" }
 						],
 						"pageInfo": { "hasNextPage": false, "endCursor": "Mg" }
 					} } } }
@@ -706,8 +706,8 @@ func mockRepoMetadata(_ *testing.T, reg *httpmock.Registry) {
 		httpmock.StringResponse(`
 		{ "data": { "repository": { "suggestedActors": {
 			"nodes": [
-				{ "login": "hubot", "id": "HUBOTID" },
-				{ "login": "MonaLisa", "id": "MONAID" }
+				{ "login": "hubot", "id": "HUBOTID", "__typename": "Bot" },
+				{ "login": "MonaLisa", "id": "MONAID", "__typename": "User" }
 			],
 			"pageInfo": { "hasNextPage": false }
 		} } } }
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Go modules are already downloaded during Docker build
go test -v ./pkg/cmd/issue/edit/

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 218152f7c5d454bffd019eb63e58645cd1f54639 "pkg/cmd/issue/edit/edit_test.go"