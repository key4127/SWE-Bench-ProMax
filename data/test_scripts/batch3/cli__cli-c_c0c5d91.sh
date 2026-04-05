#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 178fb405159431a5df38f5b986006b3b1f644084 "pkg/cmd/pr/create/create_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/create/create_test.go b/pkg/cmd/pr/create/create_test.go
--- a/pkg/cmd/pr/create/create_test.go
+++ b/pkg/cmd/pr/create/create_test.go
@@ -1571,6 +1571,12 @@ func Test_createRun(t *testing.T) {
 				opts.HeadBranch = "otherowner:feature"
 				return func() {}
 			},
+			customPushDestination: true,
+			cmdStubs: func(cs *run.CommandStubber) {
+				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
+				cs.Register("git config remote.pushDefault", 0, "")
+				cs.Register("git config push.default", 0, "")
+			},
 			expectedOut: "https://github.com/OWNER/REPO/pull/12\n",
 		},
 	}
@@ -1687,10 +1693,11 @@ func Test_generateCompareURL(t *testing.T) {
 			name: "basic",
 			ctx: CreateContext{
 				PrRefs: shared.PullRequestRefs{
-					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BaseRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					HeadRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BranchName: "feature",
 				},
-				BaseBranch:      "main",
-				HeadBranchLabel: "feature",
+				BaseBranch: "main",
 			},
 			want:    "https://github.com/OWNER/REPO/compare/main...feature?body=&expand=1",
 			wantErr: false,
@@ -1699,10 +1706,11 @@ func Test_generateCompareURL(t *testing.T) {
 			name: "with labels",
 			ctx: CreateContext{
 				PrRefs: shared.PullRequestRefs{
-					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BaseRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					HeadRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BranchName: "b",
 				},
-				BaseBranch:      "a",
-				HeadBranchLabel: "b",
+				BaseBranch: "a",
 			},
 			state: shared.IssueMetadataState{
 				Labels: []string{"one", "two three"},
@@ -1714,12 +1722,13 @@ func Test_generateCompareURL(t *testing.T) {
 			name: "'/'s in branch names/labels are percent-encoded",
 			ctx: CreateContext{
 				PrRefs: shared.PullRequestRefs{
-					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BaseRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER-UPSTREAM"}}, "github.com"),
+					HeadRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BranchName: "feature",
 				},
-				BaseBranch:      "main/trunk",
-				HeadBranchLabel: "owner:feature",
+				BaseBranch: "main/trunk",
 			},
-			want:    "https://github.com/OWNER/REPO/compare/main%2Ftrunk...owner:feature?body=&expand=1",
+			want:    "https://github.com/OWNER-UPSTREAM/REPO/compare/main%2Ftrunk...OWNER:feature?body=&expand=1",
 			wantErr: false,
 		},
 		{
@@ -1732,22 +1741,26 @@ func Test_generateCompareURL(t *testing.T) {
 			*/
 			ctx: CreateContext{
 				PrRefs: shared.PullRequestRefs{
-					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BaseRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER-UPSTREAM"}}, "github.com"),
+					HeadRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BranchName: "!$&'()+,;=@",
 				},
-				BaseBranch:      "main/trunk",
-				HeadBranchLabel: "owner:!$&'()+,;=@",
+				BaseBranch: "main/trunk",
+				//TODO check this
+				// HeadBranchLabel: "owner:!$&'()+,;=@",
 			},
-			want:    "https://github.com/OWNER/REPO/compare/main%2Ftrunk...owner:%21$&%27%28%29+%2C%3B=@?body=&expand=1",
+			want:    "https://github.com/OWNER-UPSTREAM/REPO/compare/main%2Ftrunk...OWNER:%21$&%27%28%29+%2C%3B=@?body=&expand=1",
 			wantErr: false,
 		},
 		{
 			name: "with template",
 			ctx: CreateContext{
 				PrRefs: shared.PullRequestRefs{
-					BaseRepo: api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BaseRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					HeadRepo:   api.InitRepoHostname(&api.Repository{Name: "REPO", Owner: api.RepositoryOwner{Login: "OWNER"}}, "github.com"),
+					BranchName: "feature",
 				},
-				BaseBranch:      "main",
-				HeadBranchLabel: "feature",
+				BaseBranch: "main",
 			},
 			state: shared.IssueMetadataState{
 				Template: "story.md",
EOF_114329324912

# Run the entire package (recommended approach for Go tests)
# This ensures all package dependencies are included
go test -v ./pkg/cmd/pr/create/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 178fb405159431a5df38f5b986006b3b1f644084 "pkg/cmd/pr/create/create_test.go"