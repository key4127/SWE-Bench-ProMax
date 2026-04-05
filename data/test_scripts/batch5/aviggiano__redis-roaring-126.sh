#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files before applying patch
git checkout 0f31e2c8ab2dd2e747780a063904897cac43b47e "tests/integration_1.sh" "tests/integration_3.sh"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/integration_1.sh b/tests/integration_1.sh
--- a/tests/integration_1.sh
+++ b/tests/integration_1.sh
@@ -5,6 +5,9 @@ set -eu
 . "$(dirname "$0")/helper.sh"
 
 ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value"
+ERRORMSG_KEY_MISSED="Roaring: key does not exist"
+ERRORMSG_KEY_EXISTS="Roaring: key already exist"
+ERRORMSG_SET_VALUE="Roaring: error setting value"
 
 function test_setbit_getbit() {
   print_test_header "test_setbit_getbit"
@@ -531,7 +534,7 @@ function test_diff() {
   print_test_header "test_diff"
 
   rcall_assert "R.DIFF test_diff_res" "ERR wrong number of arguments for 'R.DIFF' command" "DIFF with wrong number of arguments"
-  rcall_assert "R.DIFF test_diff_res empty_key_1 empty_key_2" "${ERRORMSG_WRONGTYPE}" "DIFF with empty keys"
+  rcall_assert "R.DIFF test_diff_res empty_key_1 empty_key_2" "${ERRORMSG_KEY_MISSED}" "DIFF with empty keys"
 
   rcall_assert "R.SETINTARRAY test_diff_1 1 2 3 4" "OK" "Set first array for diff test"
   rcall_assert "R.SETINTARRAY test_diff_2 3 4 5 6" "OK" "Set second array for diff test"
@@ -562,7 +565,7 @@ function test_clear() {
 
 function test_optimize_nokey() {
   print_test_header "test_optimize nokey"
-  rcall_assert "R.OPTIMIZE no-key" "ERR no such key" "Optimize non-existent key"
+  rcall_assert "R.OPTIMIZE no-key" "${ERRORMSG_KEY_MISSED}" "Optimize non-existent key"
 }
 
 function test_setfull() {
@@ -634,9 +637,9 @@ function test_contains() {
   rcall_assert "R.CONTAINS test_contains1 test_contains_single1 ALL_STRICT" "1" "test_contains_single1 [3] is strict subset of test_contains1"
 
   # Test error cases
-  rcall_assert "R.CONTAINS nonexistent test_contains1" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent first key"
-  rcall_assert "R.CONTAINS test_contains1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent second key"
-  rcall_assert "R.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Should return error when both keys don't exist"
+  rcall_assert "R.CONTAINS nonexistent test_contains1" "${ERRORMSG_KEY_MISSED}" "Should return error for non-existent first key"
+  rcall_assert "R.CONTAINS test_contains1 nonexistent" "${ERRORMSG_KEY_MISSED}" "Should return error for non-existent second key"
+  rcall_assert "R.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_KEY_MISSED}" "Should return error when both keys don't exist"
 
   # Test invalid mode
   rcall_assert "R.CONTAINS test_contains1 test_contains2 INVALID_MODE" "ERR invalid mode argument: INVALID_MODE" "Should return error for invalid mode"
@@ -690,8 +693,8 @@ function test_jaccard() {
   rcall_assert "R.JACCARD jaccard3 jaccard_empty1" "0" "Jaccard index with one empty bitmap"
   rcall_assert "R.JACCARD jaccard_single jaccard_single2" "1" "Jaccard index of identical single element bitmaps"
   rcall_assert "R.JACCARD jaccard_no_overlap1 jaccard_single" "0" "Jaccard index with single element and no overlap"
-  rcall_assert "R.JACCARD nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Jaccard index with non-existent keys"
-  rcall_assert "R.JACCARD jaccard1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Jaccard index with one non-existent key"
+  rcall_assert "R.JACCARD nonexistent1 nonexistent2" "${ERRORMSG_KEY_MISSED}" "Jaccard index with non-existent keys"
+  rcall_assert "R.JACCARD jaccard1 nonexistent" "${ERRORMSG_KEY_MISSED}" "Jaccard index with one non-existent key"
 }
 
 function test_stat() {
diff --git a/tests/integration_3.sh b/tests/integration_3.sh
--- a/tests/integration_3.sh
+++ b/tests/integration_3.sh
@@ -5,6 +5,9 @@ set -eu
 . "$(dirname "$0")/helper.sh"
 
 ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value"
+ERRORMSG_KEY_MISSED="Roaring: key does not exist"
+ERRORMSG_KEY_EXISTS="Roaring: key already exist"
+ERRORMSG_SET_VALUE="Roaring: error setting value"
 
 function test_setbit_getbit() {
   print_test_header "test_setbit_getbit (64)"
@@ -525,7 +528,7 @@ function test_diff() {
   print_test_header "test_diff (64)"
 
   rcall_assert "R64.DIFF test_diff_res" "ERR wrong number of arguments for 'R64.DIFF' command" "DIFF with wrong number of arguments"
-  rcall_assert "R64.DIFF test_diff_res empty_key_1 empty_key_2" "${ERRORMSG_WRONGTYPE}" "DIFF with empty keys"
+  rcall_assert "R64.DIFF test_diff_res empty_key_1 empty_key_2" "${ERRORMSG_KEY_MISSED}" "DIFF with empty keys"
 
   rcall_assert "R64.SETINTARRAY test_diff_1 1 2 3 4" "OK" "Set first array for diff test"
   rcall_assert "R64.SETINTARRAY test_diff_2 3 4 5 6" "OK" "Set second array for diff test"
@@ -556,7 +559,7 @@ function test_clear() {
 
 function test_optimize_nokey() {
   print_test_header "test_optimize nokey (64)"
-  rcall_assert "R64.OPTIMIZE no-key" "ERR no such key" "Optimize non-existent key"
+  rcall_assert "R64.OPTIMIZE no-key" "${ERRORMSG_KEY_MISSED}" "Optimize non-existent key"
 }
 
 function test_setfull() {
@@ -628,9 +631,9 @@ function test_contains() {
   rcall_assert "R64.CONTAINS test_contains1 test_contains_single1 ALL_STRICT" "1" "test_contains_single1 [3] is strict subset of test_contains1"
 
   # Test error cases
-  rcall_assert "R64.CONTAINS nonexistent test_contains1" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent first key"
-  rcall_assert "R64.CONTAINS test_contains1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent second key"
-  rcall_assert "R64.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Should return error when both keys don't exist"
+  rcall_assert "R64.CONTAINS nonexistent test_contains1" "${ERRORMSG_KEY_MISSED}" "Should return error for non-existent first key"
+  rcall_assert "R64.CONTAINS test_contains1 nonexistent" "${ERRORMSG_KEY_MISSED}" "Should return error for non-existent second key"
+  rcall_assert "R64.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_KEY_MISSED}" "Should return error when both keys don't exist"
 
   # Test invalid mode
   rcall_assert "R64.CONTAINS test_contains1 test_contains2 INVALID_MODE" "ERR invalid mode argument: INVALID_MODE" "Should return error for invalid mode"
@@ -684,8 +687,8 @@ function test_jaccard() {
   rcall_assert "R64.JACCARD jaccard3 jaccard_empty1" "0" "Jaccard index with one empty bitmap"
   rcall_assert "R64.JACCARD jaccard_single jaccard_single2" "1" "Jaccard index of identical single element bitmaps"
   rcall_assert "R64.JACCARD jaccard_no_overlap1 jaccard_single" "0" "Jaccard index with single element and no overlap"
-  rcall_assert "R64.JACCARD nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Jaccard index with non-existent keys"
-  rcall_assert "R64.JACCARD jaccard1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Jaccard index with one non-existent key"
+  rcall_assert "R64.JACCARD nonexistent1 nonexistent2" "${ERRORMSG_KEY_MISSED}" "Jaccard index with non-existent keys"
+  rcall_assert "R64.JACCARD jaccard1 nonexistent" "${ERRORMSG_KEY_MISSED}" "Jaccard index with one non-existent key"
 }
 
 function test_stat() {
EOF_114329324912

# Source the helper script which provides setup, start_redis, and stop_redis functions
source tests/helper.sh

# Setup the test environment
setup

# Start Redis with the redis-roaring module loaded
start_redis

# Execute the target integration tests
# Run integration_1.sh (Basic roaring bitmap operations)
bash tests/integration_1.sh
test1_rc=$?

# Flush Redis database to clear all keys before running the next test
# This prevents type conflicts between 32-bit (R.*) and 64-bit (R64.*) operations
./deps/redis/src/redis-cli FLUSHALL

# Run integration_3.sh (64-bit roaring bitmap operations)
bash tests/integration_3.sh
test3_rc=$?

# Stop Redis server
stop_redis

# Determine overall test result (both tests must pass)
if [ $test1_rc -eq 0 ] && [ $test3_rc -eq 0 ]; then
    rc=0
else
    rc=1
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 0f31e2c8ab2dd2e747780a063904897cac43b47e "tests/integration_1.sh" "tests/integration_3.sh"