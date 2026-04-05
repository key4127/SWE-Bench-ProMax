#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout specific test file to ensure clean state
git checkout 1c933372feef33015155c5031694bb455a55a1d5 "cmd/gitannex/gitannex_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cmd/gitannex/gitannex_test.go b/cmd/gitannex/gitannex_test.go
--- a/cmd/gitannex/gitannex_test.go
+++ b/cmd/gitannex/gitannex_test.go
@@ -190,14 +190,10 @@ func TestMessageParser(t *testing.T) {
 }
 
 func TestConfigDefinitionOneName(t *testing.T) {
-	var parsed string
-	var defaultValue = "abc"
-
 	configFoo := configDefinition{
 		names:        []string{"foo"},
 		description:  "The foo config is utterly useless.",
-		destination:  &parsed,
-		defaultValue: &defaultValue,
+		defaultValue: "abc",
 	}
 
 	assert.Equal(t, "foo",
@@ -209,14 +205,10 @@ func TestConfigDefinitionOneName(t *testing.T) {
 }
 
 func TestConfigDefinitionTwoNames(t *testing.T) {
-	var parsed string
-	var defaultValue = "abc"
-
 	configFoo := configDefinition{
 		names:        []string{"foo", "bar"},
 		description:  "The foo config is utterly useless.",
-		destination:  &parsed,
-		defaultValue: &defaultValue,
+		defaultValue: "abc",
 	}
 
 	assert.Equal(t, "foo",
@@ -228,14 +220,10 @@ func TestConfigDefinitionTwoNames(t *testing.T) {
 }
 
 func TestConfigDefinitionThreeNames(t *testing.T) {
-	var parsed string
-	var defaultValue = "abc"
-
 	configFoo := configDefinition{
 		names:        []string{"foo", "bar", "baz"},
 		description:  "The foo config is utterly useless.",
-		destination:  &parsed,
-		defaultValue: &defaultValue,
+		defaultValue: "abc",
 	}
 
 	assert.Equal(t, "foo",
EOF_114329324912

# Execute the test using package syntax instead of file syntax
# This ensures the test is compiled with all package dependencies
RCLONE_CONFIG="/notfound" go test -v ./cmd/gitannex/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 1c933372feef33015155c5031694bb455a55a1d5 "cmd/gitannex/gitannex_test.go"