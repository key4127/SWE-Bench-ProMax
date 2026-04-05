#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 93dc9f6a62bffa885c4af96c53d872f3acab7b5d "viper_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/viper_test.go b/viper_test.go
--- a/viper_test.go
+++ b/viper_test.go
@@ -1583,7 +1583,7 @@ func TestWrongConfigWithSetConfigFileNotFound(t *testing.T) {
 	v.SetConfigFile(`whatareyoutalkingabout.yaml`)
 
 	err := v.ReadInConfig()
-	assert.IsType(t, ConfigFileNotFoundError{name: "", locations: ""}, err)
+	assert.IsType(t, ConfigFileNotFoundFromReadError{}, err)
 
 	// Even though config did not load and the error might have
 	// been ignored by the client, the default still loads
@@ -1669,7 +1669,7 @@ func TestWrongDirsSearchNotFound(t *testing.T) {
 	v.AddConfigPath(`thispathaintthere`)
 
 	err := v.ReadInConfig()
-	assert.IsType(t, ConfigFileNotFoundError{name: "", locations: ""}, err)
+	assert.IsType(t, ConfigFileNotFoundFromFinderError{name: "", locations: ""}, err)
 
 	// Even though config did not load and the error might have
 	// been ignored by the client, the default still loads
@@ -1687,7 +1687,7 @@ func TestWrongDirsSearchNotFoundForMerge(t *testing.T) {
 	v.AddConfigPath(`thispathaintthere`)
 
 	err := v.MergeInConfig()
-	assert.Equal(t, reflect.TypeOf(ConfigFileNotFoundError{name: "", locations: ""}), reflect.TypeOf(err))
+	assert.Equal(t, reflect.TypeOf(ConfigFileNotFoundFromFinderError{name: "", locations: ""}), reflect.TypeOf(err))
 
 	// Even though config did not load and the error might have
 	// been ignored by the client, the default still loads
EOF_114329324912

# Ensure CGO is enabled (required for race detector)
export CGO_ENABLED=1

# Run tests for the entire package with race detector enabled
# Using -v for verbose output to help with debugging
go test -race -v .
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 93dc9f6a62bffa885c4af96c53d872f3acab7b5d "viper_test.go"