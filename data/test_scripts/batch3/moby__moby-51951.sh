#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout d5fd0c50e8f660772204191a3a2ce4f521ca7f75 "daemon/libnetwork/drivers/overlay/encryption_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/daemon/libnetwork/drivers/overlay/encryption_test.go b/daemon/libnetwork/drivers/overlay/encryption_test.go
new file mode 100644
--- /dev/null
+++ b/daemon/libnetwork/drivers/overlay/encryption_test.go
@@ -0,0 +1,51 @@
+//go:build linux
+
+package overlay
+
+import (
+	"encoding/binary"
+	"hash/fnv"
+	"net"
+	"net/netip"
+	"testing"
+)
+
+func legacyBuildSPI(src, dst net.IP, st uint32) int {
+	b := make([]byte, 4)
+	binary.BigEndian.PutUint32(b, st)
+	h := fnv.New32a()
+	h.Write(src)
+	h.Write(b)
+	h.Write(dst)
+	return int(binary.BigEndian.Uint32(h.Sum(nil)))
+}
+
+func TestBuildSPI(t *testing.T) {
+	cases := []struct {
+		src, dst string
+		st       uint32
+	}{
+		{"1.2.3.4", "5.6.7.8", 1234},
+		{"::ffff:1.2.3.4", "::ffff:5.6.7.8", 1234},
+		{"10.0.0.1", "2001:db8::1", 5678},
+		{"2002::abcd:1", "172.15.14.13", 54321},
+		{"2002:db8::42", "2002:db8::69", 9999},
+	}
+	for _, tc := range cases {
+		// The legacy buildSPI function is sensitive to whether src and
+		// dst are in 4-byte or 16-byte form. Versions of the driver
+		// using this function always pass the results of net.ParseIP(),
+		// which always parses the address into 16-byte form.
+		expected := legacyBuildSPI(net.ParseIP(tc.src), net.ParseIP(tc.dst), tc.st)
+
+		src, dst := netip.MustParseAddr(tc.src), netip.MustParseAddr(tc.dst)
+		actual := buildSPI(src, dst, tc.st)
+		if expected != actual {
+			t.Errorf("buildSPI(%v, %v, %v) = %v; want %v", src, dst, tc.st, actual, expected)
+		}
+		actual = buildSPI(src.Unmap(), dst.Unmap(), tc.st)
+		if expected != actual {
+			t.Errorf("buildSPI(%v, %v, %v) = %v; want %v", src.Unmap(), dst.Unmap(), tc.st, actual, expected)
+		}
+	}
+}
EOF_114329324912

# Set up environment variables as specified by context retrieval agent
export GOTOOLCHAIN=local
export CGO_ENABLED=1
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
export GO111MODULE=on
export GOOS=linux
export GOARCH=amd64

# Verify Go module setup
go mod verify || true

# Run the tests in the overlay driver package
echo "=========================================="
echo "Running daemon/libnetwork/drivers/overlay tests..."
echo "=========================================="
cd /testbed && go test -v -timeout=30m ./daemon/libnetwork/drivers/overlay

# Capture the exit code immediately
rc=$?

# Required: Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Restore the original test file
cd /testbed
git checkout d5fd0c50e8f660772204191a3a2ce4f521ca7f75 "daemon/libnetwork/drivers/overlay/encryption_test.go"

exit $rc