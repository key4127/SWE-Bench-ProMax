#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout c3087cde991bce40b29e5133201507f167159115 "pkg/cmd/pr/create/create_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/create/create_test.go b/pkg/cmd/pr/create/create_test.go
--- a/pkg/cmd/pr/create/create_test.go
+++ b/pkg/cmd/pr/create/create_test.go
@@ -1686,7 +1686,9 @@ func Test_generateCompareURL(t *testing.T) {
 		{
 			name: "basic",
 			ctx: CreateContext{
-				BaseRepo:        api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				PrRefs: shared.PullRequestRefs{
+					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				},
 				BaseBranch:      "main",
 				HeadBranchLabel: "feature",
 			},
@@ -1696,7 +1698,9 @@ func Test_generateCompareURL(t *testing.T) {
 		{
 			name: "with labels",
 			ctx: CreateContext{
-				BaseRepo:        api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				PrRefs: shared.PullRequestRefs{
+					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				},
 				BaseBranch:      "a",
 				HeadBranchLabel: "b",
 			},
@@ -1709,7 +1713,9 @@ func Test_generateCompareURL(t *testing.T) {
 		{
 			name: "'/'s in branch names/labels are percent-encoded",
 			ctx: CreateContext{
-				BaseRepo:        api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				PrRefs: shared.PullRequestRefs{
+					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				},
 				BaseBranch:      "main/trunk",
 				HeadBranchLabel: "owner:feature",
 			},
@@ -1725,7 +1731,9 @@ func Test_generateCompareURL(t *testing.T) {
 				    - See https://github.com/golang/go/issues/27559.
 			*/
 			ctx: CreateContext{
-				BaseRepo:        api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				PrRefs: shared.PullRequestRefs{
+					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				},
 				BaseBranch:      "main/trunk",
 				HeadBranchLabel: "owner:!$&'()+,;=@",
 			},
@@ -1735,7 +1743,9 @@ func Test_generateCompareURL(t *testing.T) {
 		{
 			name: "with template",
 			ctx: CreateContext{
-				BaseRepo:        api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				PrRefs: shared.PullRequestRefs{
+					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+				},
 				BaseBranch:      "main",
 				HeadBranchLabel: "feature",
 			},
EOF_114329324912

# Run the specific test package
# Using the package path approach (recommended for Go tests) to ensure all package dependencies are included
go test -v ./pkg/cmd/pr/create/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout c3087cde991bce40b29e5133201507f167159115 "pkg/cmd/pr/create/create_test.go"