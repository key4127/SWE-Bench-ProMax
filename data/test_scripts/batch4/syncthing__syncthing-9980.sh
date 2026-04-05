#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 8461ca539b21f60292e9b06ddf19b3e5560cf7d1 "lib/api/api_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/api/api_test.go b/lib/api/api_test.go
--- a/lib/api/api_test.go
+++ b/lib/api/api_test.go
@@ -937,6 +937,10 @@ func TestApiCache(t *testing.T) {
 }
 
 func startHTTP(cfg config.Wrapper) (string, context.CancelFunc, error) {
+	return startHTTPWithShutdownTimeout(cfg, 0)
+}
+
+func startHTTPWithShutdownTimeout(cfg config.Wrapper, shutdownTimeout time.Duration) (string, context.CancelFunc, error) {
 	m := new(modelmocks.Model)
 	assetDir := "../../gui"
 	eventSub := new(eventmocks.BufferedSubscription)
@@ -964,6 +968,10 @@ func startHTTP(cfg config.Wrapper) (string, context.CancelFunc, error) {
 	svc := New(protocol.LocalDeviceID, cfg, assetDir, "syncthing", m, eventSub, diskEventSub, events.NoopLogger, discoverer, connections, urService, mockedSummary, errorLog, systemLog, false, kdb).(*service)
 	svc.started = addrChan
 
+	if shutdownTimeout > 0*time.Millisecond {
+		svc.shutdownTimeout = shutdownTimeout
+	}
+
 	// Actually start the API service
 	supervisor := suture.New("API test", suture.Spec{
 		PassThroughPanics: true,
EOF_114329324912

# Verify Go environment
echo "=== Environment Verification ==="
go version
echo "CGO_ENABLED: $CGO_ENABLED"
echo "GOPATH: $GOPATH"
echo "Working directory: $(pwd)"
echo "Test file exists: $(test -f /testbed/lib/api/api_test.go && echo YES || echo NO)"
echo "================================"

# Run the target test file
echo "=== Running Tests ==="

# Execute tests with verbose output, 10-minute timeout, and logger suppression
# Using -count=1 to disable test caching for accurate results
LOGGER_DISCARD=1 go test -v -timeout=10m -count=1 ./lib/api/

# Capture exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 8461ca539b21f60292e9b06ddf19b3e5560cf7d1 "lib/api/api_test.go"

exit $rc