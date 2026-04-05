#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 585b6392736ec024b2e80fefab52a0d6c85b352d "pkg/cmd/agent-task/capi/sessions_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/capi/sessions_test.go b/pkg/cmd/agent-task/capi/sessions_test.go
--- a/pkg/cmd/agent-task/capi/sessions_test.go
+++ b/pkg/cmd/agent-task/capi/sessions_test.go
@@ -117,19 +117,18 @@ func TestListSessionsForViewer(t *testing.T) {
 			},
 			wantOut: []*Session{
 				{
-					session: session{
-						ID:           "sess1",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2000,
-						CreatedAt:    sampleDate,
-					},
+
+					ID:           "sess1",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2000,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2000",
@@ -260,19 +259,17 @@ func TestListSessionsForViewer(t *testing.T) {
 			},
 			wantOut: []*Session{
 				{
-					session: session{
-						ID:           "sess1",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2000,
-						CreatedAt:    sampleDate,
-					},
+					ID:           "sess1",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2000,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2000",
@@ -289,19 +286,17 @@ func TestListSessionsForViewer(t *testing.T) {
 					},
 				},
 				{
-					session: session{
-						ID:           "sess2",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2001,
-						CreatedAt:    sampleDate,
-					},
+					ID:           "sess2",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2001,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2001",
@@ -525,19 +520,17 @@ func TestListSessionsForRepo(t *testing.T) {
 			},
 			wantOut: []*Session{
 				{
-					session: session{
-						ID:           "sess1",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2000,
-						CreatedAt:    sampleDate,
-					},
+					ID:           "sess1",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2000,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2000",
@@ -668,19 +661,17 @@ func TestListSessionsForRepo(t *testing.T) {
 			},
 			wantOut: []*Session{
 				{
-					session: session{
-						ID:           "sess1",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2000,
-						CreatedAt:    sampleDate,
-					},
+					ID:           "sess1",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2000,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2000",
@@ -697,19 +688,17 @@ func TestListSessionsForRepo(t *testing.T) {
 					},
 				},
 				{
-					session: session{
-						ID:           "sess2",
-						Name:         "Build artifacts",
-						UserID:       1,
-						AgentID:      2,
-						Logs:         "",
-						State:        "completed",
-						OwnerID:      10,
-						RepoID:       1000,
-						ResourceType: "pull",
-						ResourceID:   2001,
-						CreatedAt:    sampleDate,
-					},
+					ID:           "sess2",
+					Name:         "Build artifacts",
+					UserID:       1,
+					AgentID:      2,
+					Logs:         "",
+					State:        "completed",
+					OwnerID:      10,
+					RepoID:       1000,
+					ResourceType: "pull",
+					ResourceID:   2001,
+					CreatedAt:    sampleDate,
 					PullRequest: &api.PullRequest{
 						ID:             "PR_node",
 						FullDatabaseID: "2001",
EOF_114329324912

# Run the target tests
# Running all tests in the pkg/cmd/agent-task/capi package
# This includes TestListSessionsForViewer, TestListSessionForRepoRequiresRepo, and TestListSessionsForRepo
go test -v ./pkg/cmd/agent-task/capi/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 585b6392736ec024b2e80fefab52a0d6c85b352d "pkg/cmd/agent-task/capi/sessions_test.go"