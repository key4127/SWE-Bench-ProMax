#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 87651f95066dc3f9eeb3e638217db8e1c2468252 "lib/http_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/lib/http_test.go b/lib/http_test.go
--- a/lib/http_test.go
+++ b/lib/http_test.go
@@ -1,10 +1,13 @@
 package lib
 
 import (
+	"net/http"
 	"net/http/httptest"
+	"net/url"
 	"testing"
 
 	"github.com/TecharoHQ/anubis"
+	"github.com/TecharoHQ/anubis/lib/policy"
 )
 
 func TestSetCookie(t *testing.T) {
@@ -129,3 +132,62 @@ func TestClearCookieWithDynamicDomain(t *testing.T) {
 		t.Errorf("wanted cookie max age of -1, got: %d", ckie.MaxAge)
 	}
 }
+
+func TestRenderIndexRedirect(t *testing.T) {
+	s := &Server{
+		opts: Options{
+			PublicUrl: "https://anubis.example.com",
+		},
+	}
+	req := httptest.NewRequest("GET", "/", nil)
+	req.Header.Set("X-Forwarded-Proto", "https")
+	req.Header.Set("X-Forwarded-Host", "example.com")
+	req.Header.Set("X-Forwarded-Uri", "/foo")
+
+	rr := httptest.NewRecorder()
+	s.RenderIndex(rr, req, policy.CheckResult{}, nil, true)
+
+	if rr.Code != http.StatusTemporaryRedirect {
+		t.Errorf("expected status %d, got %d", http.StatusTemporaryRedirect, rr.Code)
+	}
+	location := rr.Header().Get("Location")
+	parsedURL, err := url.Parse(location)
+	if err != nil {
+		t.Fatalf("failed to parse location URL %q: %v", location, err)
+	}
+
+	scheme := "https"
+	if parsedURL.Scheme != scheme {
+		t.Errorf("expected scheme to be %q, got %q", scheme, parsedURL.Scheme)
+	}
+
+	host := "anubis.example.com"
+	if parsedURL.Host != host {
+		t.Errorf("expected url to be %q, got %q", host, parsedURL.Host)
+	}
+
+	redir := parsedURL.Query().Get("redir")
+	expectedRedir := "https://example.com/foo"
+	if redir != expectedRedir {
+		t.Errorf("expected redir param to be %q, got %q", expectedRedir, redir)
+	}
+}
+
+func TestRenderIndexUnauthorized(t *testing.T) {
+	s := &Server{
+		opts: Options{
+			PublicUrl: "",
+		},
+	}
+	req := httptest.NewRequest("GET", "/", nil)
+	rr := httptest.NewRecorder()
+
+	s.RenderIndex(rr, req, policy.CheckResult{}, nil, true)
+
+	if rr.Code != http.StatusUnauthorized {
+		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, rr.Code)
+	}
+	if body := rr.Body.String(); body != "Authorization required" {
+		t.Errorf("expected body %q, got %q", "Authorization required", body)
+	}
+}
EOF_114329324912

# Set Go environment variables (ensure they're available in this shell)
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go

# Add npm binaries to PATH (required for asset generation if needed)
export PATH=/testbed/node_modules/.bin:$PATH

# Run the target test package (not just the single file)
go test -v ./lib
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 87651f95066dc3f9eeb3e638217db8e1c2468252 "lib/http_test.go"