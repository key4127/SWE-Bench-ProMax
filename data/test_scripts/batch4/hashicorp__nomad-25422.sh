#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 94fbe30b47b81033df0253b570ee674b0e308949 "command/agent/retry_join_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/command/agent/retry_join_test.go b/command/agent/retry_join_test.go
--- a/command/agent/retry_join_test.go
+++ b/command/agent/retry_join_test.go
@@ -19,7 +19,6 @@ import (
 	"github.com/hashicorp/nomad/helper/testlog"
 	"github.com/hashicorp/nomad/testutil"
 	"github.com/shoenig/test/must"
-	"github.com/stretchr/testify/require"
 )
 
 const stubAddress = "127.0.0.1"
@@ -98,12 +97,6 @@ func TestRetryJoin_Integration(t *testing.T) {
 
 func TestRetryJoin_Server_NonCloud(t *testing.T) {
 	ci.Parallel(t)
-	require := require.New(t)
-
-	serverJoin := &ServerJoin{
-		RetryMaxAttempts: 1,
-		RetryJoin:        []string{"127.0.0.1"},
-	}
 
 	var output []string
 
@@ -113,27 +106,24 @@ func TestRetryJoin_Server_NonCloud(t *testing.T) {
 	}
 
 	joiner := retryJoiner{
-		autoDiscover:  autoDiscover{goDiscover: &MockDiscover{}},
-		serverJoin:    mockJoin,
-		serverEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         make(chan struct{}),
+		autoDiscover: autoDiscover{goDiscover: &MockDiscover{}},
+		joinCfg: &ServerJoin{
+			RetryMaxAttempts: 1,
+			RetryJoin:        []string{"127.0.0.1"},
+		},
+		joinFunc: mockJoin,
+		logger:   testlog.HCLogger(t),
+		errCh:    make(chan struct{}),
 	}
 
-	joiner.RetryJoin(serverJoin)
+	joiner.RetryJoin()
 
-	require.Equal(1, len(output))
-	require.Equal(stubAddress, output[0])
+	must.Eq(t, 1, len(output))
+	must.Eq(t, stubAddress, output[0])
 }
 
 func TestRetryJoin_Server_Cloud(t *testing.T) {
 	ci.Parallel(t)
-	require := require.New(t)
-
-	serverJoin := &ServerJoin{
-		RetryMaxAttempts: 1,
-		RetryJoin:        []string{"provider=aws, tag_value=foo"},
-	}
 
 	var output []string
 
@@ -144,28 +134,25 @@ func TestRetryJoin_Server_Cloud(t *testing.T) {
 
 	mockDiscover := &MockDiscover{}
 	joiner := retryJoiner{
-		autoDiscover:  autoDiscover{goDiscover: mockDiscover},
-		serverJoin:    mockJoin,
-		serverEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         make(chan struct{}),
+		autoDiscover: autoDiscover{goDiscover: mockDiscover},
+		joinCfg: &ServerJoin{
+			RetryMaxAttempts: 1,
+			RetryJoin:        []string{"provider=aws, tag_value=foo"},
+		},
+		joinFunc: mockJoin,
+		logger:   testlog.HCLogger(t),
+		errCh:    make(chan struct{}),
 	}
 
-	joiner.RetryJoin(serverJoin)
+	joiner.RetryJoin()
 
-	require.Equal(1, len(output))
-	require.Equal("provider=aws, tag_value=foo", mockDiscover.ReceivedConfig)
-	require.Equal(stubAddress, output[0])
+	must.Eq(t, 1, len(output))
+	must.Eq(t, "provider=aws, tag_value=foo", mockDiscover.ReceivedConfig)
+	must.Eq(t, stubAddress, output[0])
 }
 
 func TestRetryJoin_Server_MixedProvider(t *testing.T) {
 	ci.Parallel(t)
-	require := require.New(t)
-
-	serverJoin := &ServerJoin{
-		RetryMaxAttempts: 1,
-		RetryJoin:        []string{"provider=aws, tag_value=foo", "127.0.0.1"},
-	}
 
 	var output []string
 
@@ -176,18 +163,21 @@ func TestRetryJoin_Server_MixedProvider(t *testing.T) {
 
 	mockDiscover := &MockDiscover{}
 	joiner := retryJoiner{
-		autoDiscover:  autoDiscover{goDiscover: mockDiscover},
-		serverJoin:    mockJoin,
-		serverEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         make(chan struct{}),
+		autoDiscover: autoDiscover{goDiscover: mockDiscover},
+		joinCfg: &ServerJoin{
+			RetryMaxAttempts: 1,
+			RetryJoin:        []string{"provider=aws, tag_value=foo", "127.0.0.1"},
+		},
+		joinFunc: mockJoin,
+		logger:   testlog.HCLogger(t),
+		errCh:    make(chan struct{}),
 	}
 
-	joiner.RetryJoin(serverJoin)
+	joiner.RetryJoin()
 
-	require.Equal(2, len(output))
-	require.Equal("provider=aws, tag_value=foo", mockDiscover.ReceivedConfig)
-	require.Equal(stubAddress, output[0])
+	must.Eq(t, 2, len(output))
+	must.Eq(t, "provider=aws, tag_value=foo", mockDiscover.ReceivedConfig)
+	must.Eq(t, stubAddress, output[0])
 }
 
 func TestRetryJoin_AutoDiscover(t *testing.T) {
@@ -199,30 +189,29 @@ func TestRetryJoin_AutoDiscover(t *testing.T) {
 		return 0, nil
 	}
 
+	mockDiscover := &MockDiscover{}
+	mockNetaddrs := &MockNetaddrs{}
+
 	// 'exec=*'' tests autoDiscover go-netaddr support
 	// 'provider=aws, tag_value=foo' ensures that provider-prefixed configs are routed to go-discover
 	// 'localhost' ensures that bare hostnames are returned as-is
 	// 'localhost2:4648' ensures hostname:port entries are returned as-is
 	// '127.0.0.1:4648' ensures ip:port entiresare returned as-is
 	// '100.100.100.100' ensures that bare IPs are returned as-is
-	serverJoin := &ServerJoin{
-		RetryMaxAttempts: 1,
-		RetryJoin: []string{
-			"exec=echo 127.0.0.1", "provider=aws, tag_value=foo",
-			"localhost", "localhost2:4648", "127.0.0.1:4648", "100.100.100.100"},
-	}
-
-	mockDiscover := &MockDiscover{}
-	mockNetaddrs := &MockNetaddrs{}
 	joiner := retryJoiner{
-		autoDiscover:  autoDiscover{goDiscover: mockDiscover, netAddrs: mockNetaddrs},
-		serverJoin:    mockJoin,
-		serverEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         make(chan struct{}),
+		autoDiscover: autoDiscover{goDiscover: mockDiscover, netAddrs: mockNetaddrs},
+		joinCfg: &ServerJoin{
+			RetryMaxAttempts: 1,
+			RetryJoin: []string{
+				"exec=echo 127.0.0.1", "provider=aws, tag_value=foo",
+				"localhost", "localhost2:4648", "127.0.0.1:4648", "100.100.100.100"},
+		},
+		joinFunc: mockJoin,
+		logger:   testlog.HCLogger(t),
+		errCh:    make(chan struct{}),
 	}
 
-	joiner.RetryJoin(serverJoin)
+	joiner.RetryJoin()
 
 	must.Eq(t, []string{
 		"127.0.0.1", "127.0.0.1", "localhost", "localhost2:4648",
@@ -234,12 +223,6 @@ func TestRetryJoin_AutoDiscover(t *testing.T) {
 
 func TestRetryJoin_Client(t *testing.T) {
 	ci.Parallel(t)
-	require := require.New(t)
-
-	serverJoin := &ServerJoin{
-		RetryMaxAttempts: 1,
-		RetryJoin:        []string{"127.0.0.1"},
-	}
 
 	var output []string
 
@@ -249,17 +232,20 @@ func TestRetryJoin_Client(t *testing.T) {
 	}
 
 	joiner := retryJoiner{
-		autoDiscover:  autoDiscover{goDiscover: &MockDiscover{}},
-		clientJoin:    mockJoin,
-		clientEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         make(chan struct{}),
+		autoDiscover: autoDiscover{goDiscover: &MockDiscover{}},
+		joinCfg: &ServerJoin{
+			RetryMaxAttempts: 1,
+			RetryJoin:        []string{"127.0.0.1"},
+		},
+		joinFunc: mockJoin,
+		logger:   testlog.HCLogger(t),
+		errCh:    make(chan struct{}),
 	}
 
-	joiner.RetryJoin(serverJoin)
+	joiner.RetryJoin()
 
-	require.Equal(1, len(output))
-	require.Equal(stubAddress, output[0])
+	must.Eq(t, 1, len(output))
+	must.Eq(t, stubAddress, output[0])
 }
 
 // MockFailDiscover implements the DiscoverInterface interface and can be used
@@ -293,13 +279,13 @@ func TestRetryJoin_RetryMaxAttempts(t *testing.T) {
 
 	joiner := retryJoiner{
 		autoDiscover: autoDiscover{goDiscover: &MockFailDiscover{}},
-		clientJoin: func(s []string) (int, error) {
+		joinCfg:      &ServerJoin{RetryMaxAttempts: 1, RetryJoin: []string{"provider=foo"}},
+		joinFunc: func(s []string) (int, error) {
 			output = s
 			return 0, nil
 		},
-		clientEnabled: true,
-		logger:        testlog.HCLogger(t),
-		errCh:         errCh,
+		logger: testlog.HCLogger(t),
+		errCh:  errCh,
 	}
 
 	// Execute the retry join function in a routine, so we can track whether
@@ -308,7 +294,7 @@ func TestRetryJoin_RetryMaxAttempts(t *testing.T) {
 	doneCh := make(chan struct{})
 
 	go func(doneCh chan struct{}) {
-		joiner.RetryJoin(&ServerJoin{RetryMaxAttempts: 1, RetryJoin: []string{"provider=foo"}})
+		joiner.RetryJoin()
 		close(doneCh)
 	}(doneCh)
 
@@ -467,9 +453,9 @@ func TestRetryJoin_Validate(t *testing.T) {
 		t.Run(scenario.reason, func(t *testing.T) {
 			err := joiner.Validate(scenario.config)
 			if scenario.isValid {
-				require.NoError(t, err)
+				must.NoError(t, err)
 			} else {
-				require.Error(t, err)
+				must.Error(t, err)
 			}
 		})
 	}
EOF_114329324912

# Ensure Go environment variables are set
export CGO_ENABLED=1
export GO111MODULE=on

# Run the target tests, skipping TestRetryJoin_Integration which requires privileged cgroup access
# -v for verbose output
# -timeout=15m to prevent hanging tests
# -run TestRetryJoin to execute only the target test functions
# -skip TestRetryJoin_Integration to exclude the integration test that requires privileged container access
echo "=== Running TestRetryJoin tests (excluding TestRetryJoin_Integration) ==="
go test -v -timeout=15m ./command/agent -run TestRetryJoin -skip TestRetryJoin_Integration

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to determine test results
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 94fbe30b47b81033df0253b570ee674b0e308949 "command/agent/retry_join_test.go"

# Exit with the captured return code
exit $rc