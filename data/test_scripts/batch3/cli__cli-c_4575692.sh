#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 01371508486e86f5c4b772f0eee777e74cfa9b70 "git/client_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/git/client_test.go b/git/client_test.go
--- a/git/client_test.go
+++ b/git/client_test.go
@@ -730,89 +730,48 @@ func TestClientReadBranchConfig(t *testing.T) {
 		cmdExitStatus    int
 		cmdStdout        string
 		cmdStderr        string
-		wantCmdArgs      string
+		branch           string
 		wantBranchConfig BranchConfig
+		wantError        *GitError
 	}{
 		{
 			name:             "read branch config",
+			cmdExitStatus:    0,
 			cmdStdout:        "branch.trunk.remote origin\nbranch.trunk.merge refs/heads/trunk\nbranch.trunk.gh-merge-base trunk",
-			wantCmdArgs:      `path/to/git config --get-regexp ^branch\.trunk\.(remote|merge|gh-merge-base)$`,
+			branch:           "trunk",
 			wantBranchConfig: BranchConfig{RemoteName: "origin", MergeRef: "refs/heads/trunk", MergeBase: "trunk"},
+			wantError:        nil,
 		},
-	}
-	for _, tt := range tests {
-		t.Run(tt.name, func(t *testing.T) {
-			cmd, cmdCtx := createCommandContext(t, tt.cmdExitStatus, tt.cmdStdout, tt.cmdStderr)
-			client := Client{
-				GitPath:        "path/to/git",
-				commandContext: cmdCtx,
-			}
-			branchConfig, _ := client.ReadBranchConfig(context.Background(), "trunk")
-			assert.Equal(t, tt.wantCmdArgs, strings.Join(cmd.Args[3:], " "))
-			assert.Equal(t, tt.wantBranchConfig, branchConfig)
-		})
-	}
-}
-
-func Test_readGitBranchConfig(t *testing.T) {
-	tests := []struct {
-		name           string
-		branch         string
-		cmdExitStatus  int
-		cmdStdout      string
-		cmdStderr      string
-		expectedOutput []string
-		expectedError  *GitError
-	}{
 		{
-			name:          "read branch config",
-			branch:        "trunk",
-			cmdExitStatus: 0,
-			cmdStdout:     "branch.trunk.remote origin\nbranch.trunk.merge refs/heads/trunk\nbranch.trunk.gh-merge-base trunk",
-			expectedOutput: []string{
-				"branch.trunk.remote origin",
-				"branch.trunk.merge refs/heads/trunk",
-				"branch.trunk.gh-merge-base trunk"},
-			expectedError: nil,
-		},
-		{
-			name:           "command failure",
-			branch:         "trunk",
-			cmdExitStatus:  1,
-			cmdStderr:      "git error message",
-			expectedOutput: []string{},
-			expectedError: &GitError{
-				ExitCode: 1,
-				Stderr:   "git error message",
-			},
+			name:             "command error",
+			cmdExitStatus:    1,
+			cmdStdout:        "",
+			cmdStderr:        "git error message",
+			branch:           "trunk",
+			wantBranchConfig: BranchConfig{},
+			wantError:        &GitError{ExitCode: 1, Stderr: "git error message"},
 		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			commandString := fmt.Sprintf("path/to/git config --get-regexp ^branch\\.%s\\.(remote|merge|gh-merge-base)$", tt.branch)
-			cmdCtx := createMockedCommandContext(t, map[args]commandResult{
-				args(commandString): {
-					ExitStatus: tt.cmdExitStatus,
-					Stdout:     tt.cmdStdout,
-					Stderr:     tt.cmdStderr,
-				},
-			})
+			cmd, cmdCtx := createCommandContext(t, tt.cmdExitStatus, tt.cmdStdout, tt.cmdStderr)
 			client := Client{
 				GitPath:        "path/to/git",
 				commandContext: cmdCtx,
 			}
-
-			out, err := client.readGitBranchConfig(context.Background(), tt.branch)
-			assert.Equal(t, tt.expectedOutput, out)
-			if err != nil {
-				assert.Equal(t, tt.cmdStderr, err.(*GitError).Stderr)
-				assert.Equal(t, tt.cmdExitStatus, err.(*GitError).ExitCode)
+			branchConfig, err := client.ReadBranchConfig(context.Background(), tt.branch)
+			wantCmdArgs := fmt.Sprintf("path/to/git config --get-regexp ^branch\\.%s\\.(remote|merge|gh-merge-base)$", tt.branch)
+			assert.Equal(t, wantCmdArgs, strings.Join(cmd.Args[3:], " "))
+			assert.Equal(t, tt.wantBranchConfig, branchConfig)
+			if tt.wantError != nil {
+				assert.Equal(t, tt.wantError.ExitCode, err.(*GitError).ExitCode)
+				assert.Equal(t, tt.wantError.Stderr, err.(*GitError).Stderr)
 			}
 		})
 	}
 }
 
-func Test_createBranchConfig(t *testing.T) {
+func Test_parseBranchConfig(t *testing.T) {
 	tests := []struct {
 		name                  string
 		gitBranchConfigOutput []string
@@ -855,8 +814,7 @@ func Test_createBranchConfig(t *testing.T) {
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			client := Client{}
-			branchConfig := client.createBranchConfig(tt.gitBranchConfigOutput)
+			branchConfig := parseBranchConfig(tt.gitBranchConfigOutput)
 			assert.Equal(t, tt.wantBranchConfig, branchConfig)
 		})
 	}
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Testing the git package which contains client_test.go
go test -v ./git/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 01371508486e86f5c4b772f0eee777e74cfa9b70 "git/client_test.go"