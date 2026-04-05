#!/bin/bash
set -uxo pipefail
cd /testbed

# Configure git to trust the /testbed directory
git config --global --add safe.directory /testbed

# Checkout the target test file to ensure clean state
git checkout deb1052e2fbd527de60815cb1d03c3173210356d "pkg/kv/kvserver/closedts/sidetransport/sender_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/kv/kvserver/closedts/sidetransport/sender_test.go b/pkg/kv/kvserver/closedts/sidetransport/sender_test.go
--- a/pkg/kv/kvserver/closedts/sidetransport/sender_test.go
+++ b/pkg/kv/kvserver/closedts/sidetransport/sender_test.go
@@ -644,6 +644,12 @@ func newMockDialer(addrs ...nodeAddr) *mockDialer {
 	return d
 }
 
+func newMockSideTransportClientFactory(nd rpcbase.NodeDialer) sideTransportClientFactory {
+	return func(ctx context.Context, nodeID roachpb.NodeID, class rpcbase.ConnectionClass) (ctpb.RPCSideTransportClient, error) {
+		return ctpb.DialSideTransportClient(nd, ctx, nodeID, class, false) // TODO(server): enable DRPC
+	}
+}
+
 func (m *mockDialer) addOrUpdateNode(nid roachpb.NodeID, addr string) {
 	m.mu.Lock()
 	defer m.mu.Unlock()
@@ -699,7 +705,7 @@ func TestRPCConnUnblocksOnStopper(t *testing.T) {
 	defer dialer.Close()
 
 	ch := make(chan struct{})
-	s, stopper := newMockSender(newRPCConnFactory(dialer,
+	s, stopper := newMockSender(newRPCConnFactory(newMockSideTransportClientFactory(dialer),
 		connTestingKnobs{beforeSend: func(_ roachpb.NodeID, msg *ctpb.Update) {
 			// Try to send an update to ch, if anyone is still listening.
 			ch <- struct{}{}
@@ -809,7 +815,7 @@ func TestSenderReceiverIntegration(t *testing.T) {
 		require.NoError(t, err)
 	}
 
-	s, senderStopper := newMockSender(newRPCConnFactory(dialer, connTestingKnobs{}))
+	s, senderStopper := newMockSender(newRPCConnFactory(newMockSideTransportClientFactory(dialer), connTestingKnobs{}))
 	defer senderStopper.Stop(ctx)
 	s.Run(ctx, roachpb.NodeID(1))
 
@@ -863,7 +869,8 @@ func TestRPCConnStopOnClose(t *testing.T) {
 	sleepTime := time.Millisecond
 
 	dialer := &failingDialer{}
-	factory := newRPCConnFactory(dialer, connTestingKnobs{sleepOnErrOverride: sleepTime})
+	factory := newRPCConnFactory(newMockSideTransportClientFactory(dialer),
+		connTestingKnobs{sleepOnErrOverride: sleepTime})
 
 	s, stopper := newMockSender(factory)
 	defer stopper.Stop(ctx)
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go
export HOME=/home/testuser
export GO111MODULE=on
export CGO_ENABLED=1
export GORACE="halt_on_error=1 log_path=stdout"
export GO_TEST_WRAP_TESTV=1

# Switch to testuser and run the sidetransport sender tests
# Using Bazel test command with appropriate flags for test execution
su - testuser -c 'cd /testbed && bazel test //pkg/kv/kvserver/closedts/sidetransport:sidetransport_test --config=test --test_output=all --test_timeout=600'

# Capture the exit code from the test
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout deb1052e2fbd527de60815cb1d03c3173210356d "pkg/kv/kvserver/closedts/sidetransport/sender_test.go"