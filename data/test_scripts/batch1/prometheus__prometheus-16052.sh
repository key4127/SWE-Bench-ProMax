#!/bin/bash
set -uxo pipefail
cd /testbed

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/config/config_test.go b/config/config_test.go
--- a/config/config_test.go
+++ b/config/config_test.go
@@ -2222,6 +2222,7 @@ func TestEmptyConfig(t *testing.T) {
 	exp := DefaultConfig
 	exp.loaded = true
 	require.Equal(t, exp, *c)
+	require.Equal(t, 75, c.Runtime.GoGC)
 }
 
 func TestExpandExternalLabels(t *testing.T) {
@@ -2269,7 +2270,6 @@ func TestEmptyGlobalBlock(t *testing.T) {
 	c, err := Load("global:\n", promslog.NewNopLogger())
 	require.NoError(t, err)
 	exp := DefaultConfig
-	exp.Runtime = DefaultRuntimeConfig
 	exp.loaded = true
 	require.Equal(t, exp, *c)
 }
EOF_114329324912

# Run tests for the config package (instead of isolated test file)
go test -v ./config/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Revert changes to the test file
git checkout d72c1ec2c2f8bf8e3c7b96e9f18ea616aef3f162 "config/config_test.go"