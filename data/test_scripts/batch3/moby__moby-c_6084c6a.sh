#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout d6aa6ae9bdbcceebaef9302adba3f9bc6e3ce29c \
    "client/network_list_test.go" \
    "integration-cli/requirements_test.go" \
    "integration/network/delete_test.go" \
    "testutil/environment/clean.go" \
    "testutil/environment/protect.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/client/network_list_test.go b/client/network_list_test.go
--- a/client/network_list_test.go
+++ b/client/network_list_test.go
@@ -22,35 +22,35 @@ func TestNetworkListError(t *testing.T) {
 		client: newMockClient(errorMock(http.StatusInternalServerError, "Server error")),
 	}
 
-	_, err := client.NetworkList(context.Background(), ListOptions{})
+	_, err := client.NetworkList(context.Background(), NetworkListOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsInternal))
 }
 
 func TestNetworkList(t *testing.T) {
 	const expectedURL = "/networks"
 
 	listCases := []struct {
-		options         ListOptions
+		options         NetworkListOptions
 		expectedFilters string
 	}{
 		{
-			options:         ListOptions{},
+			options:         NetworkListOptions{},
 			expectedFilters: "",
 		},
 		{
-			options: ListOptions{
+			options: NetworkListOptions{
 				Filters: filters.NewArgs(filters.Arg("dangling", "false")),
 			},
 			expectedFilters: `{"dangling":{"false":true}}`,
 		},
 		{
-			options: ListOptions{
+			options: NetworkListOptions{
 				Filters: filters.NewArgs(filters.Arg("dangling", "true")),
 			},
 			expectedFilters: `{"dangling":{"true":true}}`,
 		},
 		{
-			options: ListOptions{
+			options: NetworkListOptions{
 				Filters: filters.NewArgs(
 					filters.Arg("label", "label1"),
 					filters.Arg("label", "label2"),
diff --git a/integration-cli/requirements_test.go b/integration-cli/requirements_test.go
--- a/integration-cli/requirements_test.go
+++ b/integration-cli/requirements_test.go
@@ -35,7 +35,7 @@ func OnlyDefaultNetworks(ctx context.Context) bool {
 	if err != nil {
 		return false
 	}
-	networks, err := apiClient.NetworkList(ctx, client.ListOptions{})
+	networks, err := apiClient.NetworkList(ctx, client.NetworkListOptions{})
 	if err != nil || len(networks) > 0 {
 		return false
 	}
diff --git a/integration/network/delete_test.go b/integration/network/delete_test.go
--- a/integration/network/delete_test.go
+++ b/integration/network/delete_test.go
@@ -31,7 +31,7 @@ func createAmbiguousNetworks(ctx context.Context, t *testing.T, apiClient client
 	idPrefixNet := network.CreateNoError(ctx, t, apiClient, testNet[:12])
 	fullIDNet := network.CreateNoError(ctx, t, apiClient, testNet)
 
-	nws, err := apiClient.NetworkList(ctx, client.ListOptions{})
+	nws, err := apiClient.NetworkList(ctx, client.NetworkListOptions{})
 	assert.NilError(t, err)
 
 	assert.Check(t, is.Equal(true, containsNetwork(nws, testNet)), "failed to create network testNet")
@@ -79,7 +79,7 @@ func TestDockerNetworkDeletePreferID(t *testing.T) {
 	assert.NilError(t, err)
 
 	// networks "testNet" and "idPrefixNet" should be removed, but "fullIDNet" should still exist
-	nws, err := apiClient.NetworkList(ctx, client.ListOptions{})
+	nws, err := apiClient.NetworkList(ctx, client.NetworkListOptions{})
 	assert.NilError(t, err)
 	assert.Check(t, is.Equal(false, containsNetwork(nws, testNet)), "Network testNet not removed")
 	assert.Check(t, is.Equal(false, containsNetwork(nws, idPrefixNet)), "Network idPrefixNet not removed")
diff --git a/testutil/environment/clean.go b/testutil/environment/clean.go
--- a/testutil/environment/clean.go
+++ b/testutil/environment/clean.go
@@ -143,7 +143,7 @@ func deleteAllVolumes(ctx context.Context, t testing.TB, c client.VolumeAPIClien
 
 func deleteAllNetworks(ctx context.Context, t testing.TB, c client.NetworkAPIClient, daemonPlatform string, protectedNetworks map[string]struct{}) {
 	t.Helper()
-	networks, err := c.NetworkList(ctx, client.ListOptions{})
+	networks, err := c.NetworkList(ctx, client.NetworkListOptions{})
 	assert.Check(t, err, "failed to list networks")
 
 	for _, n := range networks {
diff --git a/testutil/environment/protect.go b/testutil/environment/protect.go
--- a/testutil/environment/protect.go
+++ b/testutil/environment/protect.go
@@ -168,7 +168,7 @@ func ProtectNetworks(ctx context.Context, t testing.TB, testEnv *Execution) {
 func getExistingNetworks(ctx context.Context, t testing.TB, testEnv *Execution) []string {
 	t.Helper()
 	apiClient := testEnv.APIClient()
-	networkList, err := apiClient.NetworkList(ctx, client.ListOptions{})
+	networkList, err := apiClient.NetworkList(ctx, client.NetworkListOptions{})
 	assert.NilError(t, err, "failed to list networks")
 
 	var networks []string
EOF_114329324912

# Verify Go environment is properly set up
export GO111MODULE=on
export CGO_ENABLED=1
export GOTOOLCHAIN=local
export GOOS=linux
export GOARCH=amd64

# Initialize test result variable
rc=0

# Run unit test for client/network_list_test.go
# This test does not require Docker daemon
echo "=========================================="
echo "Running unit test: client/network_list_test.go"
echo "=========================================="
cd /testbed/client && go test -v -run TestNetworkList
unit_rc=$?
if [ $unit_rc -ne 0 ]; then
    rc=$unit_rc
fi

# Check if Docker daemon is available for integration tests
cd /testbed
if [ -S /var/run/docker.sock ]; then
    export DOCKER_HOST=unix:///var/run/docker.sock
    
    echo "=========================================="
    echo "Running integration test: integration-cli/requirements_test.go"
    echo "=========================================="
    cd /testbed/integration-cli && go test -v -run TestRequirements
    integ_cli_rc=$?
    if [ $integ_cli_rc -ne 0 ]; then
        rc=$integ_cli_rc
    fi
    
    echo "=========================================="
    echo "Running integration test: integration/network/delete_test.go"
    echo "=========================================="
    cd /testbed/integration/network && go test -v -run TestDelete
    integ_network_rc=$?
    if [ $integ_network_rc -ne 0 ]; then
        rc=$integ_network_rc
    fi
else
    echo "=========================================="
    echo "WARNING: Docker daemon not available, skipping integration tests"
    echo "=========================================="
fi

# Note: testutil/environment/clean.go and testutil/environment/protect.go are utility files, not executable tests

# Required: Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Restore the original test files
cd /testbed
git checkout d6aa6ae9bdbcceebaef9302adba3f9bc6e3ce29c \
    "client/network_list_test.go" \
    "integration-cli/requirements_test.go" \
    "integration/network/delete_test.go" \
    "testutil/environment/clean.go" \
    "testutil/environment/protect.go"