#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout fb5e0584a75a443ee7f76a52281f7e72a353e5d3 "internal/config/load_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/config/load_test.go b/internal/config/load_test.go
--- a/internal/config/load_test.go
+++ b/internal/config/load_test.go
@@ -11,6 +11,7 @@ import (
 	"github.com/charmbracelet/catwalk/pkg/catwalk"
 	"github.com/charmbracelet/crush/internal/csync"
 	"github.com/charmbracelet/crush/internal/env"
+	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 )
 
@@ -453,6 +454,44 @@ func TestConfig_IsConfigured(t *testing.T) {
 	})
 }
 
+func TestConfig_setupAgentsWithNoDisabledTools(t *testing.T) {
+	cfg := &Config{
+		Options: &Options{
+			DisabledTools: []string{},
+		},
+	}
+
+	cfg.SetupAgents()
+	coderAgent, ok := cfg.Agents["coder"]
+	require.True(t, ok)
+	assert.Equal(t, allToolNames(), coderAgent.AllowedTools)
+
+	taskAgent, ok := cfg.Agents["task"]
+	require.True(t, ok)
+	assert.Equal(t, []string{"glob", "grep", "ls", "sourcegraph", "view"}, taskAgent.AllowedTools)
+}
+
+func TestConfig_setupAgentsWithDisabledTools(t *testing.T) {
+	cfg := &Config{
+		Options: &Options{
+			DisabledTools: []string{
+				"edit",
+				"download",
+				"grep",
+			},
+		},
+	}
+
+	cfg.SetupAgents()
+	coderAgent, ok := cfg.Agents["coder"]
+	require.True(t, ok)
+	assert.Equal(t, []string{"bash", "multiedit", "fetch", "glob", "ls", "sourcegraph", "view", "write"}, coderAgent.AllowedTools)
+
+	taskAgent, ok := cfg.Agents["task"]
+	require.True(t, ok)
+	assert.Equal(t, []string{"glob", "ls", "sourcegraph", "view"}, taskAgent.AllowedTools)
+}
+
 func TestConfig_configureProvidersWithDisabledProvider(t *testing.T) {
 	knownProviders := []catwalk.Provider{
 		{
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc
export GOTOOLCHAIN=go1.25.0

# Run tests for the entire internal/config package
# This is the standard Go way to run tests and will include all necessary files
go test -v ./internal/config/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout fb5e0584a75a443ee7f76a52281f7e72a353e5d3 "internal/config/load_test.go"