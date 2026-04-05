#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 91610a987e4c805a9305d4ee951963f80dbeb9ee "modules/httplib/serve_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/httplib/serve_test.go b/modules/httplib/serve_test.go
--- a/modules/httplib/serve_test.go
+++ b/modules/httplib/serve_test.go
@@ -27,7 +27,7 @@ func TestServeContentByReader(t *testing.T) {
 		}
 		reader := strings.NewReader(data)
 		w := httptest.NewRecorder()
-		ServeContentByReader(r, w, "test", int64(len(data)), reader)
+		ServeContentByReader(r, w, int64(len(data)), reader, &ServeHeaderOptions{})
 		assert.Equal(t, expectedStatusCode, w.Code)
 		if expectedStatusCode == http.StatusPartialContent || expectedStatusCode == http.StatusOK {
 			assert.Equal(t, fmt.Sprint(len(expectedContent)), w.Header().Get("Content-Length"))
@@ -76,7 +76,7 @@ func TestServeContentByReadSeeker(t *testing.T) {
 		defer seekReader.Close()
 
 		w := httptest.NewRecorder()
-		ServeContentByReadSeeker(r, w, "test", nil, seekReader)
+		ServeContentByReadSeeker(r, w, nil, seekReader, &ServeHeaderOptions{})
 		assert.Equal(t, expectedStatusCode, w.Code)
 		if expectedStatusCode == http.StatusPartialContent || expectedStatusCode == http.StatusOK {
 			assert.Equal(t, fmt.Sprint(len(expectedContent)), w.Header().Get("Content-Length"))
EOF_114329324912

# Run the target tests
# Using the primary command from context retrieval agent
# Running only the specific test file to avoid unnecessary execution time
go test -v ./modules/httplib/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 91610a987e4c805a9305d4ee951963f80dbeb9ee "modules/httplib/serve_test.go"