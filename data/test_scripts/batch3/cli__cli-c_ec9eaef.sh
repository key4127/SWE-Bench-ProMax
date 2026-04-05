#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 527d1db29877fdf8665723cbe4c2668fb069dbe0 "pkg/cmd/pr/status/status_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/status/status_test.go b/pkg/cmd/pr/status/status_test.go
--- a/pkg/cmd/pr/status/status_test.go
+++ b/pkg/cmd/pr/status/status_test.go
@@ -4,23 +4,23 @@ import (
 	"bytes"
 	"io"
 	"net/http"
+	"net/url"
 	"regexp"
 	"strings"
 	"testing"
 
-	"github.com/MakeNowJust/heredoc"
 	"github.com/cli/cli/v2/context"
 	"github.com/cli/cli/v2/git"
 	"github.com/cli/cli/v2/internal/config"
 	fd "github.com/cli/cli/v2/internal/featuredetection"
 	"github.com/cli/cli/v2/internal/gh"
 	"github.com/cli/cli/v2/internal/ghrepo"
-	"github.com/cli/cli/v2/internal/run"
 	"github.com/cli/cli/v2/pkg/cmdutil"
 	"github.com/cli/cli/v2/pkg/httpmock"
 	"github.com/cli/cli/v2/pkg/iostreams"
 	"github.com/cli/cli/v2/test"
 	"github.com/google/shlex"
+	"github.com/stretchr/testify/assert"
 )
 
 func runCommand(rt http.RoundTripper, branch string, isTTY bool, cli string) (*test.CmdOut, error) {
@@ -376,30 +376,48 @@ Requesting a code review from you
 }
 
 func Test_prSelectorForCurrentBranch(t *testing.T) {
-	rs, cleanup := run.Stub()
-	defer cleanup(t)
-
-	rs.Register(`git config --get-regexp \^branch\\.`, 0, heredoc.Doc(`
-		branch.Frederick888/main.remote git@github.com:Frederick888/playground.git
-		branch.Frederick888/main.merge refs/heads/main
-	`))
-
-	repo := ghrepo.NewWithHost("octocat", "playground", "github.com")
-	rem := context.Remotes{
-		&context.Remote{
-			Remote: &git.Remote{Name: "origin"},
-			Repo:   repo,
+	tests := []struct {
+		name         string
+		branchConfig git.BranchConfig
+		baseRepo     ghrepo.Interface
+		prHeadRef    string
+		remotes      context.Remotes
+		wantPrNumber int
+		wantSelector string
+		wantError    error
+	}{
+		{
+			name: "Branch merges from a remote specified by URL",
+			branchConfig: git.BranchConfig{
+				RemoteURL: &url.URL{
+					Scheme: "ssh",
+					User:   url.User("git"),
+					Host:   "github.com",
+					Path:   "Frederick888/playground.git",
+				},
+				MergeRef: "refs/heads/main",
+			},
+			baseRepo:  ghrepo.NewWithHost("octocat", "playground", "github.com"),
+			prHeadRef: "Frederick888/main",
+			remotes: context.Remotes{
+				&context.Remote{
+					Remote: &git.Remote{Name: "origin"},
+					Repo:   ghrepo.NewWithHost("octocat", "playground", "github.com"),
+				},
+			},
+			wantPrNumber: 0,
+			wantSelector: "Frederick888:main",
+			wantError:    nil,
 		},
 	}
-	gitClient := &git.Client{GitPath: "some/path/git"}
-	prNum, headRef, err := prSelectorForCurrentBranch(gitClient, repo, "Frederick888/main", rem)
-	if err != nil {
-		t.Fatalf("prSelectorForCurrentBranch error: %v", err)
-	}
-	if prNum != 0 {
-		t.Errorf("expected prNum to be 0, got %q", prNum)
-	}
-	if headRef != "Frederick888:main" {
-		t.Errorf("expected headRef to be \"Frederick888:main\", got %q", headRef)
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+
+			prNum, headRef, err := prSelectorForCurrentBranch(tt.branchConfig, tt.baseRepo, tt.prHeadRef, tt.remotes)
+			assert.Equal(t, tt.wantPrNumber, prNum)
+			assert.Equal(t, tt.wantSelector, headRef)
+			assert.Equal(t, tt.wantError, err)
+		})
 	}
 }
EOF_114329324912

# Run the specific test package
go test -v ./pkg/cmd/pr/status/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 527d1db29877fdf8665723cbe4c2668fb069dbe0 "pkg/cmd/pr/status/status_test.go"