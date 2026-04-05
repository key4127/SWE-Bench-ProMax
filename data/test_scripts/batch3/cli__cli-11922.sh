#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout ae9a7ed542680f52b11c6db132e5676313ea96eb "pkg/cmd/auth/login/login_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/auth/login/login_test.go b/pkg/cmd/auth/login/login_test.go
--- a/pkg/cmd/auth/login/login_test.go
+++ b/pkg/cmd/auth/login/login_test.go
@@ -483,6 +483,9 @@ func Test_loginRun_nontty(t *testing.T) {
 			tt.opts.HttpClient = func() (*http.Client, error) {
 				return &http.Client{Transport: reg}, nil
 			}
+			tt.opts.PlainHttpClient = func() (*http.Client, error) {
+				return &http.Client{Transport: reg}, nil
+			}
 			if tt.httpStubs != nil {
 				tt.httpStubs(reg)
 			}
@@ -775,6 +778,9 @@ func Test_loginRun_Survey(t *testing.T) {
 			tt.opts.HttpClient = func() (*http.Client, error) {
 				return &http.Client{Transport: reg}, nil
 			}
+			tt.opts.PlainHttpClient = func() (*http.Client, error) {
+				return &http.Client{Transport: reg}, nil
+			}
 			if tt.httpStubs != nil {
 				tt.httpStubs(reg)
 			} else {
EOF_114329324912

# Run the target test with verbose output
go test -v ./pkg/cmd/auth/login/

# Capture exit code
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout ae9a7ed542680f52b11c6db132e5676313ea96eb "pkg/cmd/auth/login/login_test.go"