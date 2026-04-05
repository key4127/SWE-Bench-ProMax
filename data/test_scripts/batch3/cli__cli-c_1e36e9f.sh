#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 004be9da2005289013167faf5c464cdc92b10dc0 "pkg/cmd/agent-task/capi/sessions_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/capi/sessions_test.go b/pkg/cmd/agent-task/capi/sessions_test.go
--- a/pkg/cmd/agent-task/capi/sessions_test.go
+++ b/pkg/cmd/agent-task/capi/sessions_test.go
@@ -86,7 +86,7 @@ func TestListSessionsForViewer(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.GraphQLQuery(heredoc.Docf(`
 						{
 							"data": {
@@ -105,13 +105,19 @@ func TestListSessionsForViewer(t *testing.T) {
 										"repository": {
 											"nameWithOwner": "OWNER/REPO"
 										}
+									},
+									{
+										"__typename": "User",
+										"login": "octocat",
+										"name": "Octocat",
+										"databaseId": 1
 									}
 								]
 							}
 						}`,
 						sampleDateString,
 					), func(q string, vars map[string]interface{}) {
-						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A"}, vars["ids"])
+						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "U_kgAB"}, vars["ids"])
 					}),
 				)
 			},
@@ -143,6 +149,11 @@ func TestListSessionsForViewer(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 			},
 		},
@@ -213,7 +224,7 @@ func TestListSessionsForViewer(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.GraphQLQuery(heredoc.Docf(`
 						{
 							"data": {
@@ -247,13 +258,19 @@ func TestListSessionsForViewer(t *testing.T) {
 										"repository": {
 											"nameWithOwner": "OWNER/REPO"
 										}
+									},
+									{
+										"__typename": "User",
+										"login": "octocat",
+										"name": "Octocat",
+										"databaseId": 1
 									}
 								]
 							}
 						}`,
 						sampleDateString,
 					), func(q string, vars map[string]interface{}) {
-						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "PR_kwDNA-jNB9E"}, vars["ids"])
+						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "PR_kwDNA-jNB9E", "U_kgAB"}, vars["ids"])
 					}),
 				)
 			},
@@ -284,6 +301,11 @@ func TestListSessionsForViewer(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 				{
 					ID:           "sess2",
@@ -311,6 +333,11 @@ func TestListSessionsForViewer(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 			},
 		},
@@ -365,7 +392,7 @@ func TestListSessionsForViewer(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.StatusStringResponse(500, `{}`),
 				)
 			},
@@ -489,7 +516,7 @@ func TestListSessionsForRepo(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.GraphQLQuery(heredoc.Docf(`
 						{
 							"data": {
@@ -508,13 +535,19 @@ func TestListSessionsForRepo(t *testing.T) {
 										"repository": {
 											"nameWithOwner": "OWNER/REPO"
 										}
+									},
+									{
+										"__typename": "User",
+										"login": "octocat",
+										"name": "Octocat",
+										"databaseId": 1
 									}
 								]
 							}
 						}`,
 						sampleDateString,
 					), func(q string, vars map[string]interface{}) {
-						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A"}, vars["ids"])
+						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "U_kgAB"}, vars["ids"])
 					}),
 				)
 			},
@@ -545,6 +578,11 @@ func TestListSessionsForRepo(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 			},
 		},
@@ -615,7 +653,7 @@ func TestListSessionsForRepo(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.GraphQLQuery(heredoc.Docf(`
 						{
 							"data": {
@@ -649,13 +687,19 @@ func TestListSessionsForRepo(t *testing.T) {
 										"repository": {
 											"nameWithOwner": "OWNER/REPO"
 										}
+									},
+									{
+										"__typename": "User",
+										"login": "octocat",
+										"name": "Octocat",
+										"databaseId": 1
 									}
 								]
 							}
 						}`,
 						sampleDateString,
 					), func(q string, vars map[string]interface{}) {
-						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "PR_kwDNA-jNB9E"}, vars["ids"])
+						assert.Equal(t, []interface{}{"PR_kwDNA-jNB9A", "PR_kwDNA-jNB9E", "U_kgAB"}, vars["ids"])
 					}),
 				)
 			},
@@ -686,6 +730,11 @@ func TestListSessionsForRepo(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 				{
 					ID:           "sess2",
@@ -713,6 +762,11 @@ func TestListSessionsForRepo(t *testing.T) {
 							NameWithOwner: "OWNER/REPO",
 						},
 					},
+					User: &api.GitHubUser{
+						Login:      "octocat",
+						Name:       "Octocat",
+						DatabaseID: 1,
+					},
 				},
 			},
 		},
@@ -767,7 +821,7 @@ func TestListSessionsForRepo(t *testing.T) {
 				)
 				// GraphQL hydration
 				reg.Register(
-					httpmock.GraphQL(`query FetchPRsForAgentTaskSessions\b`),
+					httpmock.GraphQL(`query FetchPRsAndUsersForAgentTaskSessions\b`),
 					httpmock.StatusStringResponse(500, `{}`),
 				)
 			},
EOF_114329324912

# Run the target test
# Using package-level test command without -run filter to execute all tests in the package
go test -v ./pkg/cmd/agent-task/capi
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 004be9da2005289013167faf5c464cdc92b10dc0 "pkg/cmd/agent-task/capi/sessions_test.go"