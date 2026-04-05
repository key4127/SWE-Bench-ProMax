#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset test files to original state before applying patch
git checkout 3c12d2a80e40930632fc4a4a4e1a45140f33fb12 "recovery_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/recovery_test.go b/recovery_test.go
--- a/recovery_test.go
+++ b/recovery_test.go
@@ -88,6 +88,24 @@ func TestPanicWithAbort(t *testing.T) {
 	assert.Equal(t, http.StatusBadRequest, w.Code)
 }
 
+func TestMaskAuthorization(t *testing.T) {
+	secret := "Bearer aaaabbbbccccddddeeeeffff"
+	headers := []string{
+		"Host: www.example.com",
+		"Authorization: " + secret,
+		"User-Agent: curl/7.51.0",
+		"Accept: */*",
+		"Content-Type: application/json",
+		"Content-Length: 1",
+	}
+	maskAuthorization(headers)
+
+	for _, h := range headers {
+		assert.NotContains(t, h, secret)
+	}
+	assert.Contains(t, headers, "Authorization: *")
+}
+
 func TestSource(t *testing.T) {
 	bs := source(nil, 0)
 	assert.Equal(t, dunnoBytes, bs)
EOF_114329324912

# Execute specific recovery tests using test pattern matching
# Run all test functions that match the recovery/panic test pattern
go test -v -covermode=count -coverprofile=profile.out -run 'TestRecovery|TestPanic' .
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore test files to original state after test execution
git checkout 3c12d2a80e40930632fc4a4a4e1a45140f33fb12 "recovery_test.go"