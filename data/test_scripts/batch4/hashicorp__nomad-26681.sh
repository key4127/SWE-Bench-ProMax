#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9950ef515c031fc4c067a726c0303b860d0ef991 \
    "client/allocrunner/taskrunner/secrets/nomad_provider_test.go" \
    "client/allocrunner/taskrunner/secrets/plugin_provider_test.go" \
    "client/allocrunner/taskrunner/secrets/vault_provider_test.go" \
    "client/allocrunner/taskrunner/secrets_hook_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/client/allocrunner/taskrunner/secrets/nomad_provider_test.go b/client/allocrunner/taskrunner/secrets/nomad_provider_test.go
--- a/client/allocrunner/taskrunner/secrets/nomad_provider_test.go
+++ b/client/allocrunner/taskrunner/secrets/nomad_provider_test.go
@@ -4,8 +4,6 @@
 package secrets
 
 import (
-	"os"
-	"path/filepath"
 	"testing"
 
 	"github.com/hashicorp/nomad/nomad/structs"
@@ -82,23 +80,3 @@ func TestNomadProvider_BuildTemplate(t *testing.T) {
 		must.Error(t, err)
 	})
 }
-
-func TestNomadProvider_Parse(t *testing.T) {
-	testDir := t.TempDir()
-	tmplFile := "foo"
-	tmplPath := filepath.Join(testDir, tmplFile)
-
-	data := "foo=bar"
-	err := os.WriteFile(tmplPath, []byte(data), 0777)
-	must.NoError(t, err)
-
-	p, err := NewNomadProvider(&structs.Secret{}, testDir, tmplFile, "default")
-	must.NoError(t, err)
-
-	vars, err := p.Parse()
-	must.NoError(t, err)
-	must.Eq(t, vars, map[string]string{"foo": "bar"})
-
-	_, err = os.Stat(tmplPath)
-	must.ErrorContains(t, err, "no such file")
-}
diff --git a/client/allocrunner/taskrunner/secrets/plugin_provider_test.go b/client/allocrunner/taskrunner/secrets/plugin_provider_test.go
--- a/client/allocrunner/taskrunner/secrets/plugin_provider_test.go
+++ b/client/allocrunner/taskrunner/secrets/plugin_provider_test.go
@@ -44,8 +44,9 @@ func TestExternalPluginProvider_Fetch(t *testing.T) {
 
 		testProvider := NewExternalPluginProvider(mockSecretPlugin, "test", "test")
 
-		err := testProvider.Fetch(context.Background())
+		vars, err := testProvider.Fetch(t.Context())
 		must.ErrorContains(t, err, "something bad")
+		must.Nil(t, vars)
 	})
 
 	t.Run("errors if fetch response contains error", func(t *testing.T) {
@@ -58,35 +59,28 @@ func TestExternalPluginProvider_Fetch(t *testing.T) {
 
 		testProvider := NewExternalPluginProvider(mockSecretPlugin, "test", "test")
 
-		err := testProvider.Fetch(context.Background())
+		vars, err := testProvider.Fetch(t.Context())
 		must.ErrorContains(t, err, "error returned from secret plugin")
+		must.Nil(t, vars)
 	})
-}
 
-func TestExternalPluginProvider_Parse(t *testing.T) {
 	t.Run("formats response correctly", func(t *testing.T) {
-		testProvider := NewExternalPluginProvider(nil, "test", "test")
-		testProvider.response = &commonplugins.SecretResponse{
+		mockSecretPlugin := new(MockSecretPlugin)
+		mockSecretPlugin.On("Fetch", mock.Anything).Return(&commonplugins.SecretResponse{
 			Result: map[string]string{
 				"testkey": "testvalue",
 			},
-		}
+			Error: nil,
+		}, nil)
 
-		result, err := testProvider.Parse()
+		testProvider := NewExternalPluginProvider(mockSecretPlugin, "test", "test")
+
+		result, err := testProvider.Fetch(t.Context())
 		must.NoError(t, err)
 
 		exp := map[string]string{
 			"secret.test.testkey": "testvalue",
 		}
 		must.Eq(t, exp, result)
-
-	})
-	t.Run("errors if response is nil", func(t *testing.T) {
-		testProvider := NewExternalPluginProvider(nil, "test", "test")
-		testProvider.response = nil
-
-		result, err := testProvider.Parse()
-		must.Error(t, err)
-		must.Nil(t, result)
 	})
 }
diff --git a/client/allocrunner/taskrunner/secrets/vault_provider_test.go b/client/allocrunner/taskrunner/secrets/vault_provider_test.go
--- a/client/allocrunner/taskrunner/secrets/vault_provider_test.go
+++ b/client/allocrunner/taskrunner/secrets/vault_provider_test.go
@@ -4,8 +4,6 @@
 package secrets
 
 import (
-	"os"
-	"path/filepath"
 	"testing"
 
 	"github.com/hashicorp/nomad/nomad/structs"
@@ -89,24 +87,3 @@ func TestVaultProvider_BuildTemplate(t *testing.T) {
 		must.Error(t, err)
 	})
 }
-
-func TestVaultProvider_Parse(t *testing.T) {
-	testDir := t.TempDir()
-
-	tmplFile := "foo"
-	tmplPath := filepath.Join(testDir, tmplFile)
-
-	data := "foo=bar"
-	err := os.WriteFile(tmplPath, []byte(data), 0777)
-	must.NoError(t, err)
-
-	p, err := NewVaultProvider(&structs.Secret{}, testDir, tmplFile)
-	must.NoError(t, err)
-
-	vars, err := p.Parse()
-	must.NoError(t, err)
-	must.Eq(t, vars, map[string]string{"foo": "bar"})
-
-	_, err = os.Stat(tmplPath)
-	must.ErrorContains(t, err, "no such file")
-}
diff --git a/client/allocrunner/taskrunner/secrets_hook_test.go b/client/allocrunner/taskrunner/secrets_hook_test.go
--- a/client/allocrunner/taskrunner/secrets_hook_test.go
+++ b/client/allocrunner/taskrunner/secrets_hook_test.go
@@ -30,7 +30,7 @@ import (
 func TestSecretsHook_Prestart_Nomad(t *testing.T) {
 	ci.Parallel(t)
 
-	t.Run("nomad provider successfully renders valid secret", func(t *testing.T) {
+	t.Run("nomad provider successfully renders valid secrets", func(t *testing.T) {
 		secretsResp := `
 		{
 		  "CreateIndex": 812,
@@ -83,6 +83,14 @@ func TestSecretsHook_Prestart_Nomad(t *testing.T) {
 					"namespace": "default",
 				},
 			},
+			{
+				Name:     "test_secret1",
+				Provider: "nomad",
+				Path:     "testnomadvar1",
+				Config: map[string]any{
+					"namespace": "default",
+				},
+			},
 		})
 
 		req := &interfaces.TaskPrestartRequest{
@@ -98,8 +106,10 @@ func TestSecretsHook_Prestart_Nomad(t *testing.T) {
 		must.NoError(t, err)
 
 		expected := map[string]string{
-			"secret.test_secret.key1": "value1",
-			"secret.test_secret.key2": "value2",
+			"secret.test_secret.key1":  "value1",
+			"secret.test_secret.key2":  "value2",
+			"secret.test_secret1.key1": "value1",
+			"secret.test_secret1.key2": "value2",
 		}
 		must.Eq(t, expected, taskEnv.Build().TaskSecrets)
 	})
@@ -277,6 +287,14 @@ func TestSecretsHook_Prestart_Vault(t *testing.T) {
 				"engine": "kv_v2",
 			},
 		},
+		{
+			Name:     "test_secret1",
+			Provider: "vault",
+			Path:     "/test/path1",
+			Config: map[string]any{
+				"engine": "kv_v2",
+			},
+		},
 	})
 
 	// Start template hook with a timeout context to ensure it exists.
@@ -293,7 +311,8 @@ func TestSecretsHook_Prestart_Vault(t *testing.T) {
 	must.NoError(t, err)
 
 	exp := map[string]string{
-		"secret.test_secret.secret": "secret",
+		"secret.test_secret.secret":  "secret",
+		"secret.test_secret1.secret": "secret",
 	}
 
 	must.Eq(t, exp, taskEnv.Build().TaskSecrets)
EOF_114329324912

# Set build tags environment variable
export GO_TAGS="hashicorpmetrics ui"
export CGO_ENABLED=1

# Run the target tests using gotestsum
# All test files are in the same package, so we can run them in a single command
gotestsum --format=testname --packages="github.com/hashicorp/nomad/client/allocrunner/taskrunner/secrets" -- \
    -cover \
    -timeout=25m \
    -count=1 \
    -tags "${GO_TAGS}" \
    -run="" \
    github.com/hashicorp/nomad/client/allocrunner/taskrunner/secrets

# Capture exit code immediately
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 9950ef515c031fc4c067a726c0303b860d0ef991 \
    "client/allocrunner/taskrunner/secrets/nomad_provider_test.go" \
    "client/allocrunner/taskrunner/secrets/plugin_provider_test.go" \
    "client/allocrunner/taskrunner/secrets/vault_provider_test.go" \
    "client/allocrunner/taskrunner/secrets_hook_test.go"