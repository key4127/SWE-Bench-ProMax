#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 1e36e9f1e386b9b1bde7840afbd638c8d55a2a09 "pkg/cmd/agent-task/capi/sessions_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/capi/sessions_test.go b/pkg/cmd/agent-task/capi/sessions_test.go
--- a/pkg/cmd/agent-task/capi/sessions_test.go
+++ b/pkg/cmd/agent-task/capi/sessions_test.go
@@ -98,6 +98,7 @@ func TestListSessionsForViewer(t *testing.T) {
 										"number": 42,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/42",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -141,6 +142,7 @@ func TestListSessionsForViewer(t *testing.T) {
 						Number:         42,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/42",
 						Body:           "",
 						CreatedAt:      sampleDate,
@@ -236,6 +238,7 @@ func TestListSessionsForViewer(t *testing.T) {
 										"number": 42,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/42",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -251,6 +254,7 @@ func TestListSessionsForViewer(t *testing.T) {
 										"number": 43,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/43",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -293,6 +297,7 @@ func TestListSessionsForViewer(t *testing.T) {
 						Number:         42,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/42",
 						Body:           "",
 						CreatedAt:      sampleDate,
@@ -325,6 +330,7 @@ func TestListSessionsForViewer(t *testing.T) {
 						Number:         43,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/43",
 						Body:           "",
 						CreatedAt:      sampleDate,
@@ -528,6 +534,7 @@ func TestListSessionsForRepo(t *testing.T) {
 										"number": 42,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/42",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -570,6 +577,7 @@ func TestListSessionsForRepo(t *testing.T) {
 						Number:         42,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/42",
 						Body:           "",
 						CreatedAt:      sampleDate,
@@ -665,6 +673,7 @@ func TestListSessionsForRepo(t *testing.T) {
 										"number": 42,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/42",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -680,6 +689,7 @@ func TestListSessionsForRepo(t *testing.T) {
 										"number": 43,
 										"title": "Improve docs",
 										"state": "OPEN",
+										"isDraft": true,
 										"url": "https://github.com/OWNER/REPO/pull/43",
 										"body": "",
 										"createdAt": "%[1]s",
@@ -722,6 +732,7 @@ func TestListSessionsForRepo(t *testing.T) {
 						Number:         42,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/42",
 						Body:           "",
 						CreatedAt:      sampleDate,
@@ -754,6 +765,7 @@ func TestListSessionsForRepo(t *testing.T) {
 						Number:         43,
 						Title:          "Improve docs",
 						State:          "OPEN",
+						IsDraft:        true,
 						URL:            "https://github.com/OWNER/REPO/pull/43",
 						Body:           "",
 						CreatedAt:      sampleDate,
EOF_114329324912

# Run the target test
# Using package-level test command to ensure all package dependencies are compiled
go test -v ./pkg/cmd/agent-task/capi
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 1e36e9f1e386b9b1bde7840afbd638c8d55a2a09 "pkg/cmd/agent-task/capi/sessions_test.go"