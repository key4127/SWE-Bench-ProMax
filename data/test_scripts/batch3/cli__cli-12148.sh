#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 680a8c4c4fe23fe962f43e5ae2c26b68a062aa8b "pkg/cmd/agent-task/capi/job_test.go" "pkg/cmd/agent-task/capi/sessions_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/capi/job_test.go b/pkg/cmd/agent-task/capi/job_test.go
--- a/pkg/cmd/agent-task/capi/job_test.go
+++ b/pkg/cmd/agent-task/capi/job_test.go
@@ -7,7 +7,6 @@ import (
 	"time"
 
 	"github.com/MakeNowJust/heredoc"
-	"github.com/cli/cli/v2/internal/config"
 	"github.com/cli/cli/v2/pkg/httpmock"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
@@ -168,8 +167,7 @@ func TestGetJob(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			job, err := capiClient.GetJob(context.Background(), "OWNER", "REPO", "job123")
 
@@ -412,8 +410,7 @@ func TestCreateJob(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			job, err := capiClient.CreateJob(context.Background(), "OWNER", "REPO", "Do the thing", tt.baseBranch, tt.customAgent)
 
diff --git a/pkg/cmd/agent-task/capi/sessions_test.go b/pkg/cmd/agent-task/capi/sessions_test.go
--- a/pkg/cmd/agent-task/capi/sessions_test.go
+++ b/pkg/cmd/agent-task/capi/sessions_test.go
@@ -9,8 +9,6 @@ import (
 
 	"github.com/MakeNowJust/heredoc"
 	"github.com/cli/cli/v2/api"
-
-	"github.com/cli/cli/v2/internal/config"
 	"github.com/cli/cli/v2/pkg/httpmock"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
@@ -1163,8 +1161,7 @@ func TestListLatestSessionsForViewer(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			if tt.perPage != 0 {
 				last := defaultSessionsPerPage
@@ -1543,8 +1540,7 @@ func TestListSessionsByResourceID(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			if tt.perPage != 0 {
 				last := defaultSessionsPerPage
@@ -1823,8 +1819,7 @@ func TestGetSession(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			session, err := capiClient.GetSession(context.Background(), "some-uuid")
 
@@ -1900,8 +1895,7 @@ func TestGetPullRequestDatabaseID(t *testing.T) {
 
 			httpClient := &http.Client{Transport: reg}
 
-			cfg := config.NewBlankConfig()
-			capiClient := NewCAPIClient(httpClient, cfg.Authentication())
+			capiClient := NewCAPIClient(httpClient, "", "github.com")
 
 			databaseID, url, err := capiClient.GetPullRequestDatabaseID(context.Background(), "github.com", "OWNER", "REPO", 42)
 
EOF_114329324912

# Run the target tests
# Using the specific test command from context retrieval agent
# Running tests for the specific package containing both test files
go test -v ./pkg/cmd/agent-task/capi
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 680a8c4c4fe23fe962f43e5ae2c26b68a062aa8b "pkg/cmd/agent-task/capi/job_test.go" "pkg/cmd/agent-task/capi/sessions_test.go"