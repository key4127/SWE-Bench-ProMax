#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout a5fe37f91b7621e7f52a4e975dec513862377193 "pkg/cmd/pr/create/create_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/create/create_test.go b/pkg/cmd/pr/create/create_test.go
--- a/pkg/cmd/pr/create/create_test.go
+++ b/pkg/cmd/pr/create/create_test.go
@@ -332,18 +332,19 @@ func TestNewCmdCreate(t *testing.T) {
 
 func Test_createRun(t *testing.T) {
 	tests := []struct {
-		name               string
-		setup              func(*CreateOptions, *testing.T) func()
-		cmdStubs           func(*run.CommandStubber)
-		promptStubs        func(*prompter.PrompterMock)
-		httpStubs          func(*httpmock.Registry, *testing.T)
-		expectedOutputs    []string
-		expectedOut        string
-		expectedErrOut     string
-		expectedBrowse     string
-		wantErr            string
-		tty                bool
-		customBranchConfig bool
+		name                  string
+		setup                 func(*CreateOptions, *testing.T) func()
+		cmdStubs              func(*run.CommandStubber)
+		promptStubs           func(*prompter.PrompterMock)
+		httpStubs             func(*httpmock.Registry, *testing.T)
+		expectedOutputs       []string
+		expectedOut           string
+		expectedErrOut        string
+		expectedBrowse        string
+		wantErr               string
+		tty                   bool
+		customBranchConfig    bool
+		customPushDestination bool
 	}{
 		{
 			name: "nontty web",
@@ -636,10 +637,6 @@ func Test_createRun(t *testing.T) {
 					}))
 			},
 			cmdStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
-				cs.Register("git config remote.pushDefault", 0, "")
-				cs.Register("git config push.default", 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
@@ -702,10 +699,6 @@ func Test_createRun(t *testing.T) {
 					}))
 			},
 			cmdStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
-				cs.Register("git config remote.pushDefault", 0, "")
-				cs.Register("git config push.default", 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
@@ -751,10 +744,6 @@ func Test_createRun(t *testing.T) {
 					}))
 			},
 			cmdStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
-				cs.Register("git config remote.pushDefault", 0, "")
-				cs.Register("git config push.default", 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
@@ -802,9 +791,10 @@ func Test_createRun(t *testing.T) {
 						assert.Equal(t, "monalisa:feature", input["headRefName"].(string))
 					}))
 			},
+			customPushDestination: true,
 			cmdStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
+				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "")
 				cs.Register("git config remote.pushDefault", 0, "")
 				cs.Register("git config push.default", 0, "")
 				cs.Register("git remote rename origin upstream", 0, "")
@@ -864,6 +854,7 @@ func Test_createRun(t *testing.T) {
 						assert.Equal(t, "monalisa:feature", input["headRefName"].(string))
 					}))
 			},
+			customPushDestination: true,
 			cmdStubs: func(cs *run.CommandStubber) {
 				cs.Register("git show-ref --verify", 0, heredoc.Doc(`
 				deadbeef HEAD
@@ -899,7 +890,8 @@ func Test_createRun(t *testing.T) {
 						assert.Equal(t, "my-feat2", input["headRefName"].(string))
 					}))
 			},
-			customBranchConfig: true,
+			customBranchConfig:    true,
+			customPushDestination: true,
 			cmdStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git config --get-regexp \^branch\\\.feature\\\.`, 0, heredoc.Doc(`
 			branch.feature.remote origin
@@ -1091,11 +1083,7 @@ func Test_createRun(t *testing.T) {
 					httpmock.StringResponse(`{"data": {"viewer": {"login": "OWNER"} } }`))
 			},
 			cmdStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
 				cs.Register(`git( .+)? log( .+)? origin/master\.\.\.feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
-				cs.Register("git config remote.pushDefault", 0, "")
-				cs.Register("git config push.default", 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
@@ -1126,11 +1114,7 @@ func Test_createRun(t *testing.T) {
 				mockRetrieveProjects(t, reg)
 			},
 			cmdStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
 				cs.Register(`git( .+)? log( .+)? origin/master\.\.\.feature`, 0, "")
-				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
-				cs.Register("git config remote.pushDefault", 0, "")
-				cs.Register("git config push.default", 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
@@ -1313,11 +1297,17 @@ func Test_createRun(t *testing.T) {
 				reg.Register(
 					httpmock.GraphQL(`mutation PullRequestCreate\b`),
 					httpmock.StringResponse(`
-							{ "data": { "createPullRequest": { "pullRequest": {
-								"URL": "https://github.com/OWNER/REPO/pull/12"
-							} } } }
+					{ "data": { "createPullRequest": { "pullRequest": {
+						"URL": "https://github.com/OWNER/REPO/pull/12"
+						} } } }
 						`))
 			},
+			customPushDestination: true,
+			cmdStubs: func(cs *run.CommandStubber) {
+				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "")
+				cs.Register("git config remote.pushDefault", 0, "")
+				cs.Register("git config push.default", 0, "")
+			},
 			expectedOut: "https://github.com/OWNER/REPO/pull/12\n",
 		},
 		{
@@ -1538,7 +1528,8 @@ func Test_createRun(t *testing.T) {
 						assert.Equal(t, "monalisa:task1", input["headRefName"].(string))
 					}))
 			},
-			customBranchConfig: true,
+			customBranchConfig:    true,
+			customPushDestination: true,
 			cmdStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git config --get-regexp \^branch\\\.task1\\\.\(remote\|merge\|pushremote\|gh-merge-base\)\$`, 0, heredoc.Doc(`
 					branch.task1.remote origin
@@ -1586,7 +1577,6 @@ func Test_createRun(t *testing.T) {
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
 			branch := "feature"
-
 			reg := &httpmock.Registry{}
 			reg.StubRepoInfoResponse("OWNER", "REPO", "master")
 			defer reg.Verify(t)
@@ -1603,6 +1593,15 @@ func Test_createRun(t *testing.T) {
 			cs, cmdTeardown := run.Stub()
 			defer cmdTeardown(t)
 			cs.Register(`git status --porcelain`, 0, "")
+			// TODO this could be be values in the test struct with a helper
+			// function to invoke the apporpriate command stubs based on
+			// those values.
+			if !tt.customPushDestination {
+				cs.Register(`git show-ref --verify -- HEAD refs/remotes/origin/feature`, 0, "")
+				cs.Register("git rev-parse --abbrev-ref feature@{push}", 0, "origin/feature")
+				cs.Register("git config remote.pushDefault", 0, "")
+				cs.Register("git config push.default", 0, "")
+			}
 			if !tt.customBranchConfig {
 				cs.Register(`git config --get-regexp \^branch\\\..+\\\.\(remote\|merge\|pushremote\|gh-merge-base\)\$`, 0, "")
 			}
EOF_114329324912

# Run the target test file
# Using package-level test execution to ensure all package dependencies are included
go test -v ./pkg/cmd/pr/create/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout a5fe37f91b7621e7f52a4e975dec513862377193 "pkg/cmd/pr/create/create_test.go"