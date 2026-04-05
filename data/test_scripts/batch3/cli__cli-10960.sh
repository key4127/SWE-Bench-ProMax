#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 1e5c3c7426144987f7dece2913c799ad7ca9a454 "api/queries_repo_test.go" "pkg/cmd/pr/shared/survey_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/api/queries_repo_test.go b/api/queries_repo_test.go
--- a/api/queries_repo_test.go
+++ b/api/queries_repo_test.go
@@ -526,17 +526,17 @@ func Test_RepoMilestones(t *testing.T) {
 func TestDisplayName(t *testing.T) {
 	tests := []struct {
 		name     string
-		assignee RepoAssignee
+		assignee AssignableUser
 		want     string
 	}{
 		{
 			name:     "assignee with name",
-			assignee: RepoAssignee{"123", "octocat123", "Octavious Cath"},
+			assignee: AssignableUser{"123", "octocat123", "Octavious Cath"},
 			want:     "octocat123 (Octavious Cath)",
 		},
 		{
 			name:     "assignee without name",
-			assignee: RepoAssignee{"123", "octocat123", ""},
+			assignee: AssignableUser{"123", "octocat123", ""},
 			want:     "octocat123",
 		},
 	}
diff --git a/pkg/cmd/pr/shared/survey_test.go b/pkg/cmd/pr/shared/survey_test.go
--- a/pkg/cmd/pr/shared/survey_test.go
+++ b/pkg/cmd/pr/shared/survey_test.go
@@ -28,9 +28,9 @@ func TestMetadataSurvey_selectAll(t *testing.T) {
 
 	fetcher := &metadataFetcher{
 		metadataResult: &api.RepoMetadataResult{
-			AssignableUsers: []api.RepoAssignee{
-				{Login: "hubot"},
-				{Login: "monalisa"},
+			AssignableUsers: []api.AssignableUser{
+				api.NewAssignableUser("", "hubot", ""),
+				api.NewAssignableUser("", "monalisa", ""),
 			},
 			Labels: []api.RepoLabel{
 				{Name: "help wanted"},
EOF_114329324912

# Run the specific test packages
# Execute all tests in both packages to ensure patched tests are run
# Using -v flag for verbose output to help with debugging
go test -v ./api ./pkg/cmd/pr/shared

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 1e5c3c7426144987f7dece2913c799ad7ca9a454 "api/queries_repo_test.go" "pkg/cmd/pr/shared/survey_test.go"