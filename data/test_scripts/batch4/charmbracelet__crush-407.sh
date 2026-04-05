#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit
git checkout cd3ef8dbd487252fc811041b43110a8fe32f28b1

# Apply test patch (adds/modifies internal/log/http_test.go)
git apply -v - <<'EOF_114329324912'
diff --git a/internal/log/http_test.go b/internal/log/http_test.go
new file mode 100644
--- /dev/null
+++ b/internal/log/http_test.go
@@ -0,0 +1,73 @@
+package log
+
+import (
+	"net/http"
+	"net/http/httptest"
+	"strings"
+	"testing"
+)
+
+func TestHTTPRoundTripLogger(t *testing.T) {
+	// Create a test server that returns a 500 error
+	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
+		w.Header().Set("Content-Type", "application/json")
+		w.Header().Set("X-Custom-Header", "test-value")
+		w.WriteHeader(http.StatusInternalServerError)
+		w.Write([]byte(`{"error": "Internal server error", "code": 500}`))
+	}))
+	defer server.Close()
+
+	// Create HTTP client with logging
+	client := NewHTTPClient()
+
+	// Make a request
+	req, err := http.NewRequestWithContext(
+		t.Context(),
+		http.MethodPost,
+		server.URL,
+		strings.NewReader(`{"test": "data"}`),
+	)
+	if err != nil {
+		t.Fatal(err)
+	}
+	req.Header.Set("Content-Type", "application/json")
+	req.Header.Set("Authorization", "Bearer secret-token")
+
+	resp, err := client.Do(req)
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer resp.Body.Close()
+
+	// Verify response
+	if resp.StatusCode != http.StatusInternalServerError {
+		t.Errorf("Expected status code 500, got %d", resp.StatusCode)
+	}
+}
+
+func TestFormatHeaders(t *testing.T) {
+	headers := http.Header{
+		"Content-Type":  []string{"application/json"},
+		"Authorization": []string{"Bearer secret-token"},
+		"X-API-Key":     []string{"api-key-123"},
+		"User-Agent":    []string{"test-agent"},
+	}
+
+	formatted := formatHeaders(headers)
+
+	// Check that sensitive headers are redacted
+	if formatted["Authorization"][0] != "[REDACTED]" {
+		t.Error("Authorization header should be redacted")
+	}
+	if formatted["X-API-Key"][0] != "[REDACTED]" {
+		t.Error("X-API-Key header should be redacted")
+	}
+
+	// Check that non-sensitive headers are preserved
+	if formatted["Content-Type"][0] != "application/json" {
+		t.Error("Content-Type header should be preserved")
+	}
+	if formatted["User-Agent"][0] != "test-agent" {
+		t.Error("User-Agent header should be preserved")
+	}
+}
EOF_114329324912

# Verify Go environment is properly set
export GO111MODULE=on
export CGO_ENABLED=0
export GOPROXY=https://proxy.golang.org,direct

# Ensure dependencies are available
go mod download

# Run tests in the internal/log package where http_test.go was added/modified
# Using -v for verbose output to see which tests are executed
# Using -count=1 to disable test caching and ensure fresh runs
go test -v -count=1 ./internal/log/...
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes made by the test patch
git checkout cd3ef8dbd487252fc811041b43110a8fe32f28b1