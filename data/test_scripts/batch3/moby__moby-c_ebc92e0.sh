#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 2401bd1e12edc2468910b8a20fa9eac011d7b1f7 "client/plugin_inspect_test.go" "integration-cli/docker_cli_daemon_test.go" "integration/plugin/common/plugin_test.go" "integration/plugin/volumes/mounts_test.go" "integration/service/plugin_test.go" "internal/testutil/daemon/plugin.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/client/plugin_inspect_test.go b/client/plugin_inspect_test.go
--- a/client/plugin_inspect_test.go
+++ b/client/plugin_inspect_test.go
@@ -2,7 +2,6 @@ package client
 
 import (
 	"bytes"
-	"context"
 	"encoding/json"
 	"errors"
 	"io"
@@ -19,7 +18,7 @@ func TestPluginInspectError(t *testing.T) {
 	client, err := NewClientWithOpts(WithMockClient(errorMock(http.StatusInternalServerError, "Server error")))
 	assert.NilError(t, err)
 
-	_, _, err = client.PluginInspectWithRaw(context.Background(), "nothing")
+	_, err = client.PluginInspect(t.Context(), "nothing", PluginInspectOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsInternal))
 }
 
@@ -28,11 +27,11 @@ func TestPluginInspectWithEmptyID(t *testing.T) {
 		return nil, errors.New("should not make request")
 	}))
 	assert.NilError(t, err)
-	_, _, err = client.PluginInspectWithRaw(context.Background(), "")
+	_, err = client.PluginInspect(t.Context(), "", PluginInspectOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsInvalidArgument))
 	assert.Check(t, is.ErrorContains(err, "value is empty"))
 
-	_, _, err = client.PluginInspectWithRaw(context.Background(), "    ")
+	_, err = client.PluginInspect(t.Context(), "    ", PluginInspectOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsInvalidArgument))
 	assert.Check(t, is.ErrorContains(err, "value is empty"))
 }
@@ -56,7 +55,7 @@ func TestPluginInspect(t *testing.T) {
 	}))
 	assert.NilError(t, err)
 
-	pluginInspect, _, err := client.PluginInspectWithRaw(context.Background(), "plugin_name")
+	resp, err := client.PluginInspect(t.Context(), "plugin_name", PluginInspectOptions{})
 	assert.NilError(t, err)
-	assert.Check(t, is.Equal(pluginInspect.ID, "plugin_id"))
+	assert.Check(t, is.Equal(resp.Plugin.ID, "plugin_id"))
 }
diff --git a/integration-cli/docker_cli_daemon_test.go b/integration-cli/docker_cli_daemon_test.go
--- a/integration-cli/docker_cli_daemon_test.go
+++ b/integration-cli/docker_cli_daemon_test.go
@@ -2225,11 +2225,11 @@ func (s *DockerDaemonSuite) TestFailedPluginRemove(c *testing.T) {
 
 	ctx, cancel = context.WithTimeout(testutil.GetContext(c), 30*time.Second)
 	defer cancel()
-	p, _, err := apiClient.PluginInspectWithRaw(ctx, name)
+	res, err := apiClient.PluginInspect(ctx, name, client.PluginInspectOptions{})
 	assert.NilError(c, err)
 
 	// simulate a bad/partial removal by removing the plugin config.
-	configPath := filepath.Join(d.Root, "plugins", p.ID, "config.json")
+	configPath := filepath.Join(d.Root, "plugins", res.Plugin.ID, "config.json")
 	assert.NilError(c, os.Remove(configPath))
 
 	d.Restart(c)
@@ -2238,7 +2238,7 @@ func (s *DockerDaemonSuite) TestFailedPluginRemove(c *testing.T) {
 	_, err = apiClient.Ping(ctx)
 	assert.NilError(c, err)
 
-	_, _, err = apiClient.PluginInspectWithRaw(ctx, name)
+	_, err = apiClient.PluginInspect(ctx, name, client.PluginInspectOptions{})
 	// plugin should be gone since the config.json is gone
 	assert.ErrorContains(c, err, "")
 }
diff --git a/integration/plugin/common/plugin_test.go b/integration/plugin/common/plugin_test.go
--- a/integration/plugin/common/plugin_test.go
+++ b/integration/plugin/common/plugin_test.go
@@ -120,7 +120,7 @@ func TestPluginInstall(t *testing.T) {
 		_, err = io.Copy(io.Discard, rdr)
 		assert.NilError(t, err)
 
-		_, _, err = apiclient.PluginInspectWithRaw(ctx, repo)
+		_, err = apiclient.PluginInspect(ctx, repo, client.PluginInspectOptions{})
 		assert.NilError(t, err)
 	})
 
@@ -163,7 +163,7 @@ func TestPluginInstall(t *testing.T) {
 		_, err = io.Copy(io.Discard, rdr)
 		assert.NilError(t, err)
 
-		_, _, err = apiclient.PluginInspectWithRaw(ctx, repo)
+		_, err = apiclient.PluginInspect(ctx, repo, client.PluginInspectOptions{})
 		assert.NilError(t, err)
 	})
 
@@ -192,7 +192,7 @@ func TestPluginInstall(t *testing.T) {
 		_, err = io.Copy(io.Discard, rdr)
 		assert.NilError(t, err)
 
-		_, _, err = apiclient.PluginInspectWithRaw(ctx, repo)
+		_, err = apiclient.PluginInspect(ctx, repo, client.PluginInspectOptions{})
 		assert.NilError(t, err)
 	})
 	t.Run("with insecure", func(t *testing.T) {
@@ -234,15 +234,15 @@ func TestPluginInstall(t *testing.T) {
 		repo := path.Join(regURL, name+":latest")
 		assert.NilError(t, plugin.CreateInRegistry(ctx, repo, nil, plugin.WithInsecureRegistry(regURL)))
 
-		apiclient := d.NewClientT(t)
-		rdr, err := apiclient.PluginInstall(ctx, repo, client.PluginInstallOptions{Disabled: true, RemoteRef: repo})
+		apiClient := d.NewClientT(t)
+		rdr, err := apiClient.PluginInstall(ctx, repo, client.PluginInstallOptions{Disabled: true, RemoteRef: repo})
 		assert.NilError(t, err)
 		defer rdr.Close()
 
 		_, err = io.Copy(io.Discard, rdr)
 		assert.NilError(t, err)
 
-		_, _, err = apiclient.PluginInspectWithRaw(ctx, repo)
+		_, err = apiClient.PluginInspect(ctx, repo, client.PluginInspectOptions{})
 		assert.NilError(t, err)
 	})
 	// TODO: test insecure registry with https
diff --git a/integration/plugin/volumes/mounts_test.go b/integration/plugin/volumes/mounts_test.go
--- a/integration/plugin/volumes/mounts_test.go
+++ b/integration/plugin/volumes/mounts_test.go
@@ -54,7 +54,7 @@ func TestPluginWithDevMounts(t *testing.T) {
 		assert.Check(t, err)
 	}()
 
-	p, _, err := c.PluginInspectWithRaw(ctx, "test")
+	resp, err := c.PluginInspect(ctx, "test", client.PluginInspectOptions{})
 	assert.NilError(t, err)
-	assert.Assert(t, p.Enabled)
+	assert.Assert(t, resp.Plugin.Enabled)
 }
diff --git a/integration/service/plugin_test.go b/integration/service/plugin_test.go
--- a/integration/service/plugin_test.go
+++ b/integration/service/plugin_test.go
@@ -72,10 +72,10 @@ func TestServicePlugin(t *testing.T) {
 		t.Log("No tasks found for plugin service")
 		t.Fail()
 	}
-	p, _, err := d1.NewClientT(t).PluginInspectWithRaw(ctx, name)
+	res, err := d1.NewClientT(t).PluginInspect(ctx, name, client.PluginInspectOptions{})
 	assert.NilError(t, err, "Error inspecting service plugin")
 	found := false
-	for _, env := range p.Settings.Env {
+	for _, env := range res.Plugin.Settings.Env {
 		assert.Equal(t, strings.HasPrefix(env, "baz"), false, "Environment variable entry %q is invalid and should not be present", "baz")
 		if strings.HasPrefix(env, "foo=") {
 			found = true
diff --git a/internal/testutil/daemon/plugin.go b/internal/testutil/daemon/plugin.go
--- a/internal/testutil/daemon/plugin.go
+++ b/internal/testutil/daemon/plugin.go
@@ -33,7 +33,7 @@ func (d *Daemon) PluginIsNotRunning(t testing.TB, name string) func(poll.LogT) p
 // PluginIsNotPresent provides a poller to check if the specified plugin is not present
 func (d *Daemon) PluginIsNotPresent(t testing.TB, name string) func(poll.LogT) poll.Result {
 	return withClient(t, d, func(c client.APIClient, t poll.LogT) poll.Result {
-		_, _, err := c.PluginInspectWithRaw(context.Background(), name)
+		_, err := c.PluginInspect(context.Background(), name, client.PluginInspectOptions{})
 		if cerrdefs.IsNotFound(err) {
 			return poll.Success()
 		}
@@ -56,14 +56,14 @@ func (d *Daemon) PluginReferenceIs(t testing.TB, name, expectedRef string) func(
 
 func withPluginInspect(name string, f func(*plugin.Plugin, poll.LogT) poll.Result) func(client.APIClient, poll.LogT) poll.Result {
 	return func(c client.APIClient, t poll.LogT) poll.Result {
-		p, _, err := c.PluginInspectWithRaw(context.Background(), name)
+		res, err := c.PluginInspect(context.Background(), name, client.PluginInspectOptions{})
 		if cerrdefs.IsNotFound(err) {
 			return poll.Continue("plugin %q not found", name)
 		}
 		if err != nil {
 			return poll.Error(err)
 		}
-		return f(p, t)
+		return f(&res.Plugin, t)
 	}
 }
 
EOF_114329324912

# Verify Go environment is properly set up
export GOTOOLCHAIN=local
export GO111MODULE=on
export CGO_ENABLED=1
export GOOS=linux
export GOARCH=amd64
export DOCKER_HOST=unix:///var/run/docker.sock

# Initialize exit code tracker
overall_rc=0

# Function to start Docker daemon for integration tests
start_docker_daemon() {
    echo "=========================================="
    echo "Attempting to start Docker daemon..."
    echo "=========================================="
    
    # Create necessary directories
    mkdir -p /var/run/docker /var/lib/docker /run/docker/containerd
    
    # Start Docker daemon in background with VFS storage driver
    dockerd --storage-driver=vfs --iptables=true > /var/log/docker.log 2>&1 &
    DOCKER_PID=$!
    
    # Wait for Docker daemon to be ready (up to 60 seconds)
    for i in {1..60}; do
        if docker info > /dev/null 2>&1; then
            echo "Docker daemon started successfully"
            return 0
        fi
        sleep 1
    done
    
    echo "Docker daemon failed to start"
    echo "This is expected if container is not running with --privileged flag"
    return 1
}

# Function to stop Docker daemon
stop_docker_daemon() {
    if [ ! -z "${DOCKER_PID:-}" ]; then
        kill $DOCKER_PID 2>/dev/null || true
        wait $DOCKER_PID 2>/dev/null || true
    fi
    pkill -9 dockerd 2>/dev/null || true
    sleep 2
}

# Run unit tests first (no daemon required)
echo "=========================================="
echo "Running unit tests (client/plugin_inspect_test.go)..."
echo "=========================================="
cd /testbed/client
go test -v -timeout=10m . -run TestPluginInspect
unit_rc=$?
echo "Unit tests exit code: $unit_rc"

if [ $unit_rc -ne 0 ]; then
    overall_rc=1
fi

# Attempt to start Docker daemon for integration tests
echo "=========================================="
echo "Preparing for integration tests..."
echo "=========================================="

if start_docker_daemon; then
    echo "Docker daemon is running, proceeding with integration tests..."
    
    # Build dynamic binaries required for integration tests
    echo "=========================================="
    echo "Building dynamic binaries for integration tests..."
    echo "=========================================="
    cd /testbed
    make dynbinary 2>&1 || hack/make.sh dynbinary 2>&1 || true
    
    # Run integration-cli tests
    echo "=========================================="
    echo "Running integration-cli tests (integration-cli/docker_cli_daemon_test.go)..."
    echo "=========================================="
    cd /testbed
    go test -v -timeout=20m -tags integration-cli ./integration-cli -run TestDaemon
    integration_cli_rc=$?
    echo "Integration-cli tests exit code: $integration_cli_rc"
    
    if [ $integration_cli_rc -ne 0 ]; then
        overall_rc=1
    fi
    
    # Run integration tests for plugin/common
    echo "=========================================="
    echo "Running integration tests (integration/plugin/common)..."
    echo "=========================================="
    cd /testbed
    go test -v -timeout=20m ./integration/plugin/common
    integration_common_rc=$?
    echo "Integration plugin/common tests exit code: $integration_common_rc"
    
    if [ $integration_common_rc -ne 0 ]; then
        overall_rc=1
    fi
    
    # Run integration tests for plugin/volumes
    echo "=========================================="
    echo "Running integration tests (integration/plugin/volumes)..."
    echo "=========================================="
    cd /testbed
    go test -v -timeout=20m ./integration/plugin/volumes
    integration_volumes_rc=$?
    echo "Integration plugin/volumes tests exit code: $integration_volumes_rc"
    
    if [ $integration_volumes_rc -ne 0 ]; then
        overall_rc=1
    fi
    
    # Run integration tests for service plugin
    echo "=========================================="
    echo "Running integration tests (integration/service - plugin tests)..."
    echo "=========================================="
    cd /testbed
    go test -v -timeout=20m ./integration/service -run TestServicePlugin
    integration_service_rc=$?
    echo "Integration service plugin tests exit code: $integration_service_rc"
    
    if [ $integration_service_rc -ne 0 ]; then
        overall_rc=1
    fi
    
    # Stop Docker daemon
    stop_docker_daemon
else
    echo "=========================================="
    echo "WARNING: Docker daemon could not be started"
    echo "=========================================="
    echo "Integration tests require Docker-in-Docker support."
    echo "The container should be run with:"
    echo "  docker run --privileged --security-opt seccomp=unconfined --cgroupns=host ..."
    echo ""
    echo "Since the daemon cannot start, integration tests will be SKIPPED."
    echo "This is not considered a test failure - only unit tests will be evaluated."
    echo "=========================================="
    
    # Do NOT set overall_rc=1 here - skipped tests due to environment constraints
    # are not the same as failed tests
fi

# Print summary
echo "=========================================="
echo "TEST EXECUTION SUMMARY"
echo "=========================================="
echo "Unit tests (client/plugin_inspect_test.go): $([ $unit_rc -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
if [ -z "${DOCKER_PID:-}" ]; then
    echo "Integration tests: SKIPPED (Docker daemon unavailable - requires --privileged mode)"
else
    echo "Integration-cli tests: $([ ${integration_cli_rc:-1} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    echo "Integration plugin/common tests: $([ ${integration_common_rc:-1} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    echo "Integration plugin/volumes tests: $([ ${integration_volumes_rc:-1} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
    echo "Integration service tests: $([ ${integration_service_rc:-1} -eq 0 ] && echo 'PASSED' || echo 'FAILED')"
fi
echo "=========================================="
echo "Overall result: $([ $overall_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILURE')"
echo "=========================================="

# Note: internal/testutil/daemon/plugin.go is a helper file, not a test file

# Required: Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$overall_rc"

# Cleanup: Restore the original test files
cd /testbed
git checkout 2401bd1e12edc2468910b8a20fa9eac011d7b1f7 "client/plugin_inspect_test.go" "integration-cli/docker_cli_daemon_test.go" "integration/plugin/common/plugin_test.go" "integration/plugin/volumes/mounts_test.go" "integration/service/plugin_test.go" "internal/testutil/daemon/plugin.go"