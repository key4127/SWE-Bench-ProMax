#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout e4320ccc4bf39dd3cf0e8eba2a6872b6d42eccca "pkg/cmd/pr/shared/finder_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/shared/finder_test.go b/pkg/cmd/pr/shared/finder_test.go
--- a/pkg/cmd/pr/shared/finder_test.go
+++ b/pkg/cmd/pr/shared/finder_test.go
@@ -10,19 +10,21 @@ import (
 	"github.com/cli/cli/v2/git"
 	"github.com/cli/cli/v2/internal/ghrepo"
 	"github.com/cli/cli/v2/pkg/httpmock"
+	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 )
 
+type args struct {
+	baseRepoFn   func() (ghrepo.Interface, error)
+	branchFn     func() (string, error)
+	branchConfig func(string) (git.BranchConfig, error)
+	remotesFn    func() (context.Remotes, error)
+	selector     string
+	fields       []string
+	baseBranch   string
+}
+
 func TestFind(t *testing.T) {
-	type args struct {
-		baseRepoFn   func() (ghrepo.Interface, error)
-		branchFn     func() (string, error)
-		branchConfig func(string) git.BranchConfig
-		remotesFn    func() (context.Remotes, error)
-		selector     string
-		fields       []string
-		baseBranch   string
-	}
 	tests := []struct {
 		name     string
 		args     args
@@ -231,9 +233,7 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -265,9 +265,7 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -315,11 +313,10 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					c.MergeRef = "refs/heads/blue-upstream-berries"
-					c.RemoteName = "origin"
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{
+					MergeRef:   "refs/heads/blue-upstream-berries",
+					RemoteName: "origin",
+				}, nil),
 				remotesFn: func() (context.Remotes, error) {
 					return context.Remotes{{
 						Remote: &git.Remote{Name: "origin"},
@@ -357,11 +354,12 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
+				branchConfig: func(branch string) (git.BranchConfig, error) {
 					u, _ := url.Parse("https://github.com/UPSTREAMOWNER/REPO")
-					c.MergeRef = "refs/heads/blue-upstream-berries"
-					c.RemoteURL = u
-					return
+					return stubBranchConfig(git.BranchConfig{
+						MergeRef:  "refs/heads/blue-upstream-berries",
+						RemoteURL: u,
+					}, nil)(branch)
 				},
 				remotesFn: nil,
 			},
@@ -395,10 +393,9 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					c.RemoteName = "origin"
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{
+					RemoteName: "origin",
+				}, nil),
 				remotesFn: func() (context.Remotes, error) {
 					return context.Remotes{{
 						Remote: &git.Remote{Name: "origin"},
@@ -436,10 +433,9 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					c.MergeRef = "refs/pull/13/head"
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{
+					MergeRef: "refs/pull/13/head",
+				}, nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -462,10 +458,9 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: func(branch string) (c git.BranchConfig) {
-					c.MergeRef = "refs/pull/13/head"
-					return
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{
+					MergeRef: "refs/pull/13/head",
+				}, nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -561,3 +556,49 @@ func TestFind(t *testing.T) {
 		})
 	}
 }
+
+func Test_parseCurrentBranch(t *testing.T) {
+	tests := []struct {
+		name         string
+		args         args
+		wantSelector string
+		wantPR       int
+		wantError    error
+	}{
+		{
+			name: "failed branch config",
+			args: args{
+				branchConfig: stubBranchConfig(git.BranchConfig{}, errors.New("branchConfigErr")),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
+				},
+			},
+			wantSelector: "",
+			wantPR:       0,
+			wantError:    errors.New("branchConfigErr"),
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			f := finder{
+				httpClient: func() (*http.Client, error) {
+					return &http.Client{}, nil
+				},
+				baseRepoFn:   tt.args.baseRepoFn,
+				branchFn:     tt.args.branchFn,
+				branchConfig: tt.args.branchConfig,
+				remotesFn:    tt.args.remotesFn,
+			}
+			selector, pr, err := f.parseCurrentBranch()
+			assert.Equal(t, tt.wantSelector, selector)
+			assert.Equal(t, tt.wantPR, pr)
+			assert.Equal(t, tt.wantError, err)
+		})
+	}
+}
+
+func stubBranchConfig(branchConfig git.BranchConfig, err error) func(string) (git.BranchConfig, error) {
+	return func(branch string) (git.BranchConfig, error) {
+		return branchConfig, err
+	}
+}
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Running tests for the pkg/cmd/pr/shared package where finder_test.go is located
go test -v ./pkg/cmd/pr/shared/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout e4320ccc4bf39dd3cf0e8eba2a6872b6d42eccca "pkg/cmd/pr/shared/finder_test.go"

exit $rc