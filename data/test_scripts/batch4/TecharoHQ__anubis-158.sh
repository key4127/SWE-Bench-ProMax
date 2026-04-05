#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 052316ba25c86d5dcc870cd5b4c045ea67110562 "decaymap/decaymap_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/decaymap/decaymap_test.go b/decaymap/decaymap_test.go
--- a/decaymap/decaymap_test.go
+++ b/decaymap/decaymap_test.go
@@ -29,3 +29,32 @@ func TestImpl(t *testing.T) {
 		t.Error("got value even though it was supposed to be expired")
 	}
 }
+
+func TestCleanup(t *testing.T) {
+	dm := New[string, string]()
+
+	dm.Set("test1", "hi1", 1*time.Second)
+	dm.Set("test2", "hi2", 2*time.Second)
+	dm.Set("test3", "hi3", 3*time.Second)
+
+	dm.expire("test1") // Force expire test1
+	dm.expire("test2") // Force expire test2
+
+	dm.Cleanup()
+
+	finalLen := dm.Len() // Get the length after cleanup
+
+	if finalLen != 1 { // "test3" should be the only one left
+		t.Errorf("Cleanup failed to remove expired entries. Expected length 1, got %d", finalLen)
+	}
+
+	if _, ok := dm.Get("test1"); ok { // Verify Get still behaves correctly after Cleanup
+		t.Error("test1 should not be found after cleanup")
+	}
+	if _, ok := dm.Get("test2"); ok {
+		t.Error("test2 should not be found after cleanup")
+	}
+	if val, ok := dm.Get("test3"); !ok || val != "hi3" {
+		t.Error("test3 should still be found after cleanup")
+	}
+}
EOF_114329324912

# Set Go environment variables (ensure they're available in this shell)
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go

# Run the target test file
go test -v ./decaymap/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 052316ba25c86d5dcc870cd5b4c045ea67110562 "decaymap/decaymap_test.go"