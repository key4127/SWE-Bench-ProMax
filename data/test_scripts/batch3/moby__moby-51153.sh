#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout ae28867804b5a3ec72895678e4117b052816e1b1 "client/pkg/streamformatter/streamformatter_test.go" "daemon/internal/streamformatter/streamformatter_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/client/pkg/streamformatter/streamformatter_test.go b/client/pkg/streamformatter/streamformatter_test.go
--- a/client/pkg/streamformatter/streamformatter_test.go
+++ b/client/pkg/streamformatter/streamformatter_test.go
@@ -41,14 +41,14 @@ func TestFormatStatus(t *testing.T) {
 
 func TestFormatError(t *testing.T) {
 	res := FormatError(errors.New("Error for formatter"))
-	expected := `{"errorDetail":{"message":"Error for formatter"},"error":"Error for formatter"}` + "\r\n"
+	expected := `{"errorDetail":{"message":"Error for formatter"}}` + "\r\n"
 	assert.Check(t, is.Equal(expected, string(res)))
 }
 
 func TestFormatJSONError(t *testing.T) {
 	err := &jsonstream.Error{Code: 50, Message: "Json error"}
 	res := FormatError(err)
-	expected := `{"errorDetail":{"code":50,"message":"Json error"},"error":"Json error"}` + streamNewline
+	expected := `{"errorDetail":{"code":50,"message":"Json error"}}` + streamNewline
 	assert.Check(t, is.Equal(expected, string(res)))
 }
 
@@ -61,12 +61,12 @@ func TestJsonProgressFormatterFormatProgress(t *testing.T) {
 	}
 	aux := "aux message"
 	res := sf.formatProgress("id", "action", jsonProgress, aux)
-	msg := &jsonMessage{}
+	msg := &jsonstream.Message{}
 
 	assert.NilError(t, json.Unmarshal(res, msg))
 
 	rawAux := json.RawMessage(`"` + aux + `"`)
-	expected := &jsonMessage{
+	expected := &jsonstream.Message{
 		ID:       "id",
 		Status:   "action",
 		Aux:      &rawAux,
diff --git a/daemon/internal/streamformatter/streamformatter_test.go b/daemon/internal/streamformatter/streamformatter_test.go
--- a/daemon/internal/streamformatter/streamformatter_test.go
+++ b/daemon/internal/streamformatter/streamformatter_test.go
@@ -20,14 +20,14 @@ func TestFormatStatus(t *testing.T) {
 
 func TestFormatError(t *testing.T) {
 	res := FormatError(errors.New("Error for formatter"))
-	expected := `{"errorDetail":{"message":"Error for formatter"},"error":"Error for formatter"}` + "\r\n"
+	expected := `{"error":"Error for formatter","errorDetail":{"message":"Error for formatter"}}` + "\r\n"
 	assert.Check(t, is.Equal(expected, string(res)))
 }
 
 func TestFormatJSONError(t *testing.T) {
 	err := &jsonstream.Error{Code: 50, Message: "Json error"}
 	res := FormatError(err)
-	expected := `{"errorDetail":{"code":50,"message":"Json error"},"error":"Json error"}` + streamNewline
+	expected := `{"error":"Json error","errorDetail":{"code":50,"message":"Json error"}}` + streamNewline
 	assert.Check(t, is.Equal(expected, string(res)))
 }
 
@@ -40,12 +40,12 @@ func TestJsonProgressFormatterFormatProgress(t *testing.T) {
 	}
 	aux := "aux message"
 	res := sf.formatProgress("id", "action", jsonProgress, aux)
-	msg := &jsonMessage{}
+	msg := &jsonstream.Message{}
 
 	assert.NilError(t, json.Unmarshal(res, msg))
 
 	rawAux := json.RawMessage(`"` + aux + `"`)
-	expected := &jsonMessage{
+	expected := &jsonstream.Message{
 		ID:       "id",
 		Status:   "action",
 		Aux:      &rawAux,
EOF_114329324912

# Verify Go environment is properly set up
export GO111MODULE=on
export CGO_ENABLED=1
export GOOS=linux
export GOARCH=amd64

# Initialize exit code tracker
overall_rc=0

# Run client tests from the client module directory
echo "=========================================="
echo "Running client/pkg/streamformatter tests..."
echo "=========================================="
cd /testbed/client
go test -v -timeout=5m ./pkg/streamformatter/
client_rc=$?
echo "Client tests exit code: $client_rc"

# Run daemon tests from the root module directory
echo "=========================================="
echo "Running daemon/internal/streamformatter tests..."
echo "=========================================="
cd /testbed
go test -v -timeout=5m ./daemon/internal/streamformatter/
daemon_rc=$?
echo "Daemon tests exit code: $daemon_rc"

# Combine exit codes - fail if either test failed
if [ $client_rc -ne 0 ] || [ $daemon_rc -ne 0 ]; then
    overall_rc=1
fi

# Required: Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$overall_rc"

# Cleanup: Restore the original test files
cd /testbed
git checkout ae28867804b5a3ec72895678e4117b052816e1b1 "client/pkg/streamformatter/streamformatter_test.go" "daemon/internal/streamformatter/streamformatter_test.go"