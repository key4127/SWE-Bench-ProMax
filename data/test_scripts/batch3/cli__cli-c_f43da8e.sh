#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout bf6fdbdfd214c97f45d2610289236ae3537d3ea4 "git/client_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/git/client_test.go b/git/client_test.go
--- a/git/client_test.go
+++ b/git/client_test.go
@@ -754,6 +754,100 @@ func TestClientReadBranchConfig(t *testing.T) {
 	}
 }
 
+func Test_readGitBranchConfig(t *testing.T) {
+	tests := []struct {
+		name        string
+		branch      string
+		cmdExitCode int
+		cmdStdout   string
+		cmdStderr   string
+		wantCmdArgs string
+		wantErr     *GitError
+	}{
+		{
+			name:        "read branch config",
+			branch:      "trunk",
+			cmdStdout:   "branch.trunk.remote origin\nbranch.trunk.merge refs/heads/trunk\nbranch.trunk.gh-merge-base trunk",
+			wantCmdArgs: `path/to/git config --get-regexp ^branch\.trunk\.(remote|merge|gh-merge-base)$`,
+		},
+		{
+			name:        "command failure",
+			branch:      "trunk",
+			wantCmdArgs: `path/to/git config --get-regexp ^branch\.trunk\.(remote|merge|gh-merge-base)$`,
+			cmdExitCode: 1,
+			cmdStderr:   "error",
+			wantErr:     &GitError{ExitCode: 1, Stderr: "error"},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			cmd, cmdCtx := createCommandContext(t, tt.cmdExitCode, tt.cmdStdout, tt.cmdStderr)
+			client := Client{
+				GitPath:        "path/to/git",
+				commandContext: cmdCtx,
+			}
+			out, err := client.readGitBranchConfig(context.Background(), tt.branch)
+			if tt.wantErr != nil {
+				assert.Equal(t, tt.wantErr.ExitCode, err.(*GitError).ExitCode)
+				assert.Equal(t, tt.wantErr.Stderr, err.(*GitError).Stderr)
+			} else {
+				assert.Equal(t, tt.wantCmdArgs, strings.Join(cmd.Args[3:], " "))
+				assert.Equal(t, tt.cmdStdout, string(out))
+			}
+		})
+	}
+}
+
+func Test_createBranchConfig(t *testing.T) {
+	tests := []struct {
+		name                  string
+		gitBranchConfigOutput []string
+		wantBranchConfig      BranchConfig
+	}{
+		{
+			name:                  "remote branch",
+			gitBranchConfigOutput: []string{"branch.trunk.remote origin"},
+			wantBranchConfig: BranchConfig{
+				RemoteName: "origin",
+			},
+		},
+		{
+			name:                  "merge ref",
+			gitBranchConfigOutput: []string{"branch.trunk.merge refs/heads/trunk"},
+			wantBranchConfig: BranchConfig{
+				MergeRef: "refs/heads/trunk",
+			},
+		},
+		{
+			name:                  "merge base",
+			gitBranchConfigOutput: []string{"branch.trunk.gh-merge-base gh-merge-base"},
+			wantBranchConfig: BranchConfig{
+				MergeBase: "gh-merge-base",
+			},
+		},
+		{
+			name: "remote, merge ref, and merge base all specified",
+			gitBranchConfigOutput: []string{
+				"branch.trunk.remote origin",
+				"branch.trunk.merge refs/heads/trunk",
+				"branch.trunk.gh-merge-base gh-merge-base",
+			},
+			wantBranchConfig: BranchConfig{
+				RemoteName: "origin",
+				MergeRef:   "refs/heads/trunk",
+				MergeBase:  "gh-merge-base",
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			client := Client{}
+			branchConfig := client.createBranchConfig(tt.gitBranchConfigOutput)
+			assert.Equal(t, tt.wantBranchConfig, branchConfig)
+		})
+	}
+}
+
 func TestClientDeleteLocalTag(t *testing.T) {
 	tests := []struct {
 		name          string
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Running tests for the entire git package to ensure all dependencies are properly resolved
go test -v ./git/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout bf6fdbdfd214c97f45d2610289236ae3537d3ea4 "git/client_test.go"

exit $rc