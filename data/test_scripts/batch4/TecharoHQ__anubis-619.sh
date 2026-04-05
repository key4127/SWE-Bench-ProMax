#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 6594ae0eef89119de5c01254452d0bd12fe7d792 "internal/xff_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/internal/xff_test.go b/internal/xff_test.go
--- a/internal/xff_test.go
+++ b/internal/xff_test.go
@@ -23,7 +23,7 @@ func TestXForwardedForUpdateIgnoreUnix(t *testing.T) {
 
 	w := httptest.NewRecorder()
 
-	XForwardedForUpdate(h).ServeHTTP(w, r)
+	XForwardedForUpdate(true, h).ServeHTTP(w, r)
 
 	if r.RemoteAddr != remoteAddr {
 		t.Errorf("wanted remoteAddr to be %s, got: %s", r.RemoteAddr, remoteAddr)
@@ -43,7 +43,7 @@ func TestXForwardedForUpdateAddToChain(t *testing.T) {
 		w.WriteHeader(http.StatusOK)
 	})
 
-	srv := httptest.NewServer(XForwardedForUpdate(h))
+	srv := httptest.NewServer(XForwardedForUpdate(true, h))
 
 	r, err := http.NewRequest(http.MethodGet, srv.URL, nil)
 	if err != nil {
@@ -81,6 +81,15 @@ func TestComputeXFFHeader(t *testing.T) {
 			},
 			result: "1.1.1.1,127.0.0.1",
 		},
+		{
+			name:          "StripPrivate",
+			remoteAddr:    "127.0.0.1:80",
+			origXFFHeader: "1.1.1.1,10.0.0.1",
+			pref: XFFComputePreferences{
+				StripPrivate: false,
+			},
+			result: "1.1.1.1,10.0.0.1,127.0.0.1",
+		},
 		{
 			name:          "StripLoopback",
 			remoteAddr:    "127.0.0.1:80",
EOF_114329324912

# Set Go environment variables (ensure they're available in this shell)
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go

# Run the target tests at package level (includes all necessary source and test files)
# This approach automatically includes headers.go and any other required source files
go test -v ./internal -run "TestXForwardedFor|TestComputeXFFHeader"
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 6594ae0eef89119de5c01254452d0bd12fe7d792 "internal/xff_test.go"