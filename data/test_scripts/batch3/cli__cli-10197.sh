#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 322a43feff32c0071705c8b3fd75091ffb8ebc2f "pkg/cmd/pr/status/status_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/status/status_test.go b/pkg/cmd/pr/status/status_test.go
--- a/pkg/cmd/pr/status/status_test.go
+++ b/pkg/cmd/pr/status/status_test.go
@@ -2,7 +2,6 @@ package status
 
 import (
 	"bytes"
-	"fmt"
 	"io"
 	"net/http"
 	"net/url"
@@ -16,6 +15,7 @@ import (
 	fd "github.com/cli/cli/v2/internal/featuredetection"
 	"github.com/cli/cli/v2/internal/gh"
 	"github.com/cli/cli/v2/internal/ghrepo"
+	"github.com/cli/cli/v2/internal/run"
 	"github.com/cli/cli/v2/pkg/cmdutil"
 	"github.com/cli/cli/v2/pkg/httpmock"
 	"github.com/cli/cli/v2/pkg/iostreams"
@@ -96,6 +96,11 @@ func TestPRStatus(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatus.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -121,6 +126,11 @@ func TestPRStatus_reviewsAndChecks(t *testing.T) {
 	// status,conclusion matches the old StatusContextRollup query
 	http.Register(httpmock.GraphQL(`status,conclusion`), httpmock.FileResponse("./fixtures/prStatusChecks.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -146,6 +156,11 @@ func TestPRStatus_reviewsAndChecksWithStatesByCount(t *testing.T) {
 	// checkRunCount,checkRunCountsByState matches the new StatusContextRollup query
 	http.Register(httpmock.GraphQL(`checkRunCount,checkRunCountsByState`), httpmock.FileResponse("./fixtures/prStatusChecksWithStatesByCount.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommandWithDetector(http, "blueberries", true, "", &fd.EnabledDetectorMock{})
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -170,6 +185,11 @@ func TestPRStatus_currentBranch_showTheMostRecentPR(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranch.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -198,6 +218,11 @@ func TestPRStatus_currentBranch_defaultBranch(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranch.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -232,6 +257,11 @@ func TestPRStatus_currentBranch_Closed(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranchClosed.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -249,6 +279,11 @@ func TestPRStatus_currentBranch_Closed_defaultBranch(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranchClosedOnDefaultBranch.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -266,6 +301,11 @@ func TestPRStatus_currentBranch_Merged(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranchMerged.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -283,6 +323,11 @@ func TestPRStatus_currentBranch_Merged_defaultBranch(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.FileResponse("./fixtures/prStatusCurrentBranchMergedOnDefaultBranch.json"))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -300,6 +345,11 @@ func TestPRStatus_blankSlate(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.StringResponse(`{"data": {}}`))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "blueberries", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -353,6 +403,11 @@ func TestPRStatus_detachedHead(t *testing.T) {
 	defer http.Verify(t)
 	http.Register(httpmock.GraphQL(`query PullRequestStatus\b`), httpmock.StringResponse(`{"data": {}}`))
 
+	// stub successful git command
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 0, "")
+
 	output, err := runCommand(http, "", true, "")
 	if err != nil {
 		t.Errorf("error running command `pr status`: %v", err)
@@ -376,6 +431,15 @@ Requesting a code review from you
 	}
 }
 
+func TestPRStatus_error_ReadBranchConfig(t *testing.T) {
+	rs, cleanup := run.Stub()
+	defer cleanup(t)
+	rs.Register(`git config --get-regexp \^branch\\.`, 1, "")
+
+	_, err := runCommand(initFakeHTTP(), "blueberries", true, "")
+	assert.Error(t, err)
+}
+
 func Test_prSelectorForCurrentBranch(t *testing.T) {
 	tests := []struct {
 		name         string
@@ -537,7 +601,7 @@ func Test_prSelectorForCurrentBranch(t *testing.T) {
 			wantError:    nil,
 		},
 		{
-			name: "Remote URL error",
+			name: "Remote URL errors",
 			branchConfig: git.BranchConfig{
 				RemoteURL: &url.URL{
 					Scheme: "ssh",
@@ -549,10 +613,10 @@ func Test_prSelectorForCurrentBranch(t *testing.T) {
 			prHeadRef:    "monalisa/main",
 			wantPrNumber: 0,
 			wantSelector: "monalisa/main",
-			wantError:    fmt.Errorf("invalid path: /\\invalid?Path/"),
+			wantError:    nil,
 		},
 		{
-			name: "Remote Name error",
+			name: "Remote Name errors",
 			branchConfig: git.BranchConfig{
 				RemoteName: "nonexistentRemote",
 			},
@@ -569,7 +633,7 @@ func Test_prSelectorForCurrentBranch(t *testing.T) {
 			},
 			wantPrNumber: 0,
 			wantSelector: "monalisa/main",
-			wantError:    fmt.Errorf("no matching remote found"),
+			wantError:    nil,
 		},
 	}
 
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Running tests for the entire package to ensure all dependencies are properly resolved
go test -v ./pkg/cmd/pr/status/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 322a43feff32c0071705c8b3fd75091ffb8ebc2f "pkg/cmd/pr/status/status_test.go"