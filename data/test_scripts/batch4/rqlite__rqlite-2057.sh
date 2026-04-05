#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test file to ensure clean state
git checkout 000abd80ae237adc7e538e2e800d80a099861f7e "http/service_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/http/service_test.go b/http/service_test.go
--- a/http/service_test.go
+++ b/http/service_test.go
@@ -248,6 +248,48 @@ func Test_HasVersionHeaderUnknown(t *testing.T) {
 	}
 }
 
+func Test_LeaderAddrsOK(t *testing.T) {
+	m := &MockStore{
+		leaderAddr: "foo:1234",
+	}
+	c := &mockClusterService{
+		apiAddr: "http://bar:5678",
+	}
+	s := New("127.0.0.1:0", m, c, nil)
+	if err := s.Start(); err != nil {
+		t.Fatalf("failed to start service")
+	}
+	defer s.Close()
+
+	addr, err := s.LeaderAddr()
+	if err != nil {
+		t.Fatalf("failed to get leader address")
+	}
+	if addr != "foo:1234" {
+		t.Fatalf("incorrect leader address, got: %s", addr)
+	}
+
+	addr = s.LeaderAPIAddr()
+	if addr != "http://bar:5678" {
+		t.Fatalf("incorrect leader API address, got: %s", addr)
+	}
+}
+
+func Test_LeaderAddrsFail(t *testing.T) {
+	m := &MockStore{}
+	c := &mockClusterService{}
+	s := New("127.0.0.1:0", m, c, nil)
+	if err := s.Start(); err != nil {
+		t.Fatalf("failed to start service")
+	}
+	defer s.Close()
+
+	_, err := s.LeaderAddr()
+	if err != ErrLeaderNotFound {
+		t.Fatalf("failed to get expected ErrLeaderNotFound")
+	}
+}
+
 func Test_404Routes(t *testing.T) {
 	m := &MockStore{}
 	c := &mockClusterService{}
EOF_114329324912

# Execute tests for the http package
# Using the recommended flags from context retrieval: -v (verbose) and -timeout 10m
go test -v -timeout 10m ./http/
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 000abd80ae237adc7e538e2e800d80a099861f7e "http/service_test.go"