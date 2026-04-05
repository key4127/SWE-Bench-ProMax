#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 65f87cb29074cf1f131223db16532a8acda20dcc "integration-tests/bats/admin-conjoin.bats"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/integration-tests/bats/admin-conjoin.bats b/integration-tests/bats/admin-conjoin.bats
--- a/integration-tests/bats/admin-conjoin.bats
+++ b/integration-tests/bats/admin-conjoin.bats
@@ -42,16 +42,16 @@ get_oldgen_storage_ids() {
     [[ "$output" =~ "invalid storage file ID: invalidhash" ]] || false
 }
 
-@test "conjoin: --all flag works (not yet implemented)" {
+@test "conjoin: --all flag works" {
     run dolt admin conjoin --all
-    [ "$status" -eq 1 ]
-    [[ "$output" =~ "conjoin command not yet implemented" ]] || false
+    [ "$status" -eq 0 ]
+    [[ "$output" =~ "No table files to conjoin" ]] || false
 }
 
-@test "conjoin: valid storage file ID works (not yet implemented)" {
+@test "conjoin: valid storage file ID works" {
     run dolt admin conjoin abcdef1234567890abcdef1234567890
     [ "$status" -eq 1 ]
-    [[ "$output" =~ "conjoin command not yet implemented" ]] || false
+    [[ "$output" =~ "storage file not found" ]] || false
 }
 
 @test "conjoin: get storage file IDs and test conjoin with specific IDs" {
@@ -76,9 +76,9 @@ get_oldgen_storage_ids() {
     [ "${#id1}" -eq 32 ]
     [ "${#id2}" -eq 32 ]
     
-    # Test conjoin with the specific IDs (expected to fail with "not yet implemented")
+    # Test conjoin with the specific IDs (should succeed)
     run dolt admin conjoin "$id1" "$id2"
-    [ "$status" -eq 1 ]
-    [[ "$output" =~ "conjoin command not yet implemented" ]] || false
+    [ "$status" -eq 0 ]
+    [[ "$output" =~ "Successfully conjoined table files" ]] || false
 }
 
EOF_114329324912

# Navigate to the go module directory and rebuild dolt binary
# This is critical because the patch may include changes to the conjoin command implementation
cd /testbed/go

# Ensure environment variables are set
export GO111MODULE=on
export CGO_ENABLED=1
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/bin:$PATH

# Rebuild the dolt binary with the patched code
go build -mod=readonly -o /usr/local/bin/dolt ./cmd/dolt

# Navigate to the BATS test directory
cd /testbed/integration-tests/bats

# Run the specific BATS test file
bats admin-conjoin.bats

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
cd /testbed
git checkout 65f87cb29074cf1f131223db16532a8acda20dcc "integration-tests/bats/admin-conjoin.bats"