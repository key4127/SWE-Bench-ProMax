#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout be52cc241cdb9ba946e02301fe25ce5640c3d334 "tests/integration_1.sh" "tests/integration_3.sh" "tests/unit.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/integration_1.sh b/tests/integration_1.sh
--- a/tests/integration_1.sh
+++ b/tests/integration_1.sh
@@ -4,7 +4,7 @@ set -eu
 
 . "$(dirname "$0")/helper.sh"
 
-ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value";
+ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value"
 
 function test_setbit_getbit() {
   print_test_header "test_setbit_getbit"
@@ -177,6 +177,123 @@ function test_min_max() {
   rcall_assert "R.MAX test_min_max" "-1" "Get max after unsetting all bits"
 }
 
+function test_bitop_diff() {
+  print_test_header "test_bitop_diff"
+
+  # Test 1: Empty/non-existent keys
+  rcall_assert "R.BITOP DIFF diff_res empty_key_1 empty_key_2" "0"
+
+  # Test 2: Basic DIFF operation - X - Y (single Y key)
+  rcall_assert "R.SETINTARRAY bitop_x_2 1 2 3 4 5" "OK" "Set bitmap X with values 1-5"
+  rcall_assert "R.SETINTARRAY bitop_y_1 3 4 5 6 7" "OK" "Set bitmap Y with values 3-7"
+  rcall_assert "R.BITOP DIFF diff_res_2 bitop_x_2 bitop_y_1" "2" "DIFF X - Y"
+  rcall_assert "R.GETINTARRAY diff_res_2" "$(echo -e "1\n2")" "Result should be {1, 2}"
+
+  # Test 3: DIFF with multiple Y keys - X - Y1 - Y2
+  rcall_assert "R.SETINTARRAY bitop_x_3 1 2 3 4 5 6 7 8" "OK" "Set bitmap X with values 1-8"
+  rcall_assert "R.SETINTARRAY bitop_y1_1 2 3" "OK" "Set bitmap Y1 with values 2-3"
+  rcall_assert "R.SETINTARRAY bitop_y2_1 5 6" "OK" "Set bitmap Y2 with values 5-6"
+  rcall_assert "R.BITOP DIFF diff_res_3 bitop_x_3 bitop_y1_1 bitop_y2_1" "4" "DIFF X - Y1 - Y2"
+  rcall_assert "R.GETINTARRAY diff_res_3" "$(echo -e "1\n4\n7\n8")" "Result should be {1, 4, 7, 8}"
+
+  # Test 4: DIFF with three Y keys
+  rcall_assert "R.SETINTARRAY bitop_x_4 1 2 3 4 5 6 7 8 9 10" "OK" "Set bitmap X with values 1-10"
+  rcall_assert "R.SETINTARRAY bitop_y1_2 1 2" "OK" "Set bitmap Y1"
+  rcall_assert "R.SETINTARRAY bitop_y2_2 3 4" "OK" "Set bitmap Y2"
+  rcall_assert "R.SETINTARRAY bitop_y3_1 5 6" "OK" "Set bitmap Y3"
+  rcall_assert "R.BITOP DIFF diff_res_4 bitop_x_4 bitop_y1_2 bitop_y2_2 bitop_y3_1" "4" "DIFF X - Y1 - Y2 - Y3"
+  rcall_assert "R.GETINTARRAY diff_res_4" "$(echo -e "7\n8\n9\n10")" "Result should be {7, 8, 9, 10}"
+
+  # Test 5: DIFF where X is completely contained in Y (empty result)
+  rcall_assert "R.SETINTARRAY bitop_x_5 1 2 3" "OK" "Set bitmap X with values 1-3"
+  rcall_assert "R.SETINTARRAY bitop_y_2 1 2 3 4 5" "OK" "Set bitmap Y with superset"
+  rcall_assert "R.BITOP DIFF diff_res_5 bitop_x_5 bitop_y_2" "0" "DIFF where X subset of Y"
+  rcall_assert "R.GETINTARRAY diff_res_5" "" "Result should be empty"
+
+  # Test 6: DIFF where X and Y are disjoint (result equals X)
+  rcall_assert "R.SETINTARRAY bitop_x_6 1 2 3" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y_3 7 8 9" "OK" "Set bitmap Y (disjoint)"
+  rcall_assert "R.BITOP DIFF diff_res_6 bitop_x_6 bitop_y_3" "3" "DIFF with disjoint sets"
+  rcall_assert "R.GETINTARRAY diff_res_6" "$(echo -e "1\n2\n3")" "Result should equal X"
+
+  # Test 7: DIFF with empty X bitmap
+  rcall_assert "R.SETINTARRAY bitop_y_4 1 2 3" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF diff_res_7 bitop_x_7 bitop_y_4" "0" "DIFF with empty X"
+  rcall_assert "R.GETINTARRAY diff_res_7" "" "Result should be empty"
+
+  # Test 8: DIFF with empty Y bitmap (result equals X)
+  rcall_assert "R.SETINTARRAY bitop_x_8 1 2 3 4" "OK" "Set bitmap X"
+  rcall_assert "R.BITOP DIFF diff_res_8 bitop_x_8 bitop_y_5" "4" "DIFF with empty Y"
+  rcall_assert "R.GETINTARRAY diff_res_8" "$(echo -e "1\n2\n3\n4")" "Result should equal X"
+
+  # Test 9: DIFF with overlapping Y keys
+  rcall_assert "R.SETINTARRAY bitop_x_9 1 2 3 4 5 6" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y1_3 2 3 4" "OK" "Set bitmap Y1"
+  rcall_assert "R.SETINTARRAY bitop_y2_3 3 4 5" "OK" "Set bitmap Y2 (overlaps Y1)"
+  rcall_assert "R.BITOP DIFF diff_res_9 bitop_x_9 bitop_y1_3 bitop_y2_3" "2" "DIFF with overlapping Y keys"
+  rcall_assert "R.GETINTARRAY diff_res_9" "$(echo -e "1\n6")" "Result should be {1, 6}"
+
+  # Test 10: Overwrite existing destination key
+  rcall_assert "R.SETINTARRAY diff_res_10 99 100" "OK" "Pre-populate destination key"
+  rcall_assert "R.SETINTARRAY bitop_x_10 5 6 7" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y_6 6" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF diff_res_10 bitop_x_10 bitop_y_6" "2" "DIFF overwrites existing key"
+  rcall_assert "R.GETINTARRAY diff_res_10" "$(echo -e "5\n7")" "Destination should be overwritten, not {99, 100}"
+
+  # Test 11: DIFF with large values
+  rcall_assert "R.SETINTARRAY bitop_x_11 1000 2000 3000 4000" "OK" "Set bitmap X with large values"
+  rcall_assert "R.SETINTARRAY bitop_y_7 2000 3000" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF diff_res_11 bitop_x_11 bitop_y_7" "2" "DIFF with large values"
+  rcall_assert "R.GETINTARRAY diff_res_11" "$(echo -e "1000\n4000")" "Result should be {1000, 4000}"
+
+  # Test 12: DIFF result as input to another operation
+  rcall_assert "R.SETINTARRAY bitop_x_12 1 2 3 4 5" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y_8 3 4" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF diff_temp bitop_x_12 bitop_y_8" "3" "First DIFF operation"
+  rcall_assert "R.SETINTARRAY bitop_y_9 1" "OK" "Set another bitmap"
+  rcall_assert "R.BITOP DIFF diff_res_12 diff_temp bitop_y_9" "2" "Chain DIFF operations"
+  rcall_assert "R.GETINTARRAY diff_res_12" "$(echo -e "2\n5")" "Chained result should be {2, 5}"
+
+  # Test 13: Verify X and Y keys are not modified
+  rcall_assert "R.SETINTARRAY bitop_x_13 10 20 30" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y_10 20" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF diff_res_13 bitop_x_13 bitop_y_10" "2" "Perform DIFF"
+  rcall_assert "R.GETINTARRAY bitop_x_13" "$(echo -e "10\n20\n30")" "X should remain unchanged"
+  rcall_assert "R.GETINTARRAY bitop_y_10" "20" "Y should remain unchanged"
+
+  # Test 14: DIFF with destination key as one of the source keys (in-place operation)
+  rcall_assert "R.SETINTARRAY bitop_dest_src 1 2 3 4 5 6" "OK" "Set bitmap that will be both dest and src"
+  rcall_assert "R.SETINTARRAY bitop_y_11 3 4 5" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF bitop_dest_src bitop_dest_src bitop_y_11" "3" "DIFF with dest as source (in-place)"
+  rcall_assert "R.GETINTARRAY bitop_dest_src" "$(echo -e "1\n2\n6")" "Dest should be modified in-place to {1, 2, 6}"
+
+  # Test 15: DIFF with destination key as middle source key
+  rcall_assert "R.SETINTARRAY bitop_x_14 1 2 3 4 5 6 7 8" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_dest_src_2 2 3 4" "OK" "Set bitmap that will be dest and middle src"
+  rcall_assert "R.SETINTARRAY bitop_y_12 6 7" "OK" "Set bitmap Y"
+  rcall_assert "R.BITOP DIFF bitop_dest_src_2 bitop_x_14 bitop_dest_src_2 bitop_y_12" "3" "DIFF: X - dest - Y"
+  rcall_assert "R.GETINTARRAY bitop_dest_src_2" "$(echo -e "1\n5\n8")" "Result should be {1, 5, 8}"
+
+  # Test 16: DIFF with destination key as last source key
+  rcall_assert "R.SETINTARRAY bitop_x_15 10 20 30 40 50" "OK" "Set bitmap X"
+  rcall_assert "R.SETINTARRAY bitop_y_13 20 30" "OK" "Set bitmap Y1"
+  rcall_assert "R.SETINTARRAY bitop_dest_src_3 40" "OK" "Set bitmap that will be dest and last src"
+  rcall_assert "R.BITOP DIFF bitop_dest_src_3 bitop_x_15 bitop_y_13 bitop_dest_src_3" "2" "DIFF: X - Y - dest"
+  rcall_assert "R.GETINTARRAY bitop_dest_src_3" "$(echo -e "10\n50")" "Result should be {10, 50}"
+
+  # Test 17: DIFF with destination key appearing multiple times in sources
+  rcall_assert "R.SETINTARRAY bitop_dest_src_4 5 10 15 20" "OK" "Set bitmap for dest/multi-src test"
+  rcall_assert "R.SETINTARRAY bitop_x_16 1 2 3 4 5 10 15 20 25 30" "OK" "Set bitmap X"
+  rcall_assert "R.BITOP DIFF bitop_dest_src_4 bitop_x_16 bitop_dest_src_4 bitop_dest_src_4" "6" "DIFF: X - dest - dest"
+  rcall_assert "R.GETINTARRAY bitop_dest_src_4" "$(echo -e "1\n2\n3\n4\n25\n30")" "Result should be X minus original dest values"
+
+  # Test 18: DIFF with dest as first source and empty result
+  rcall_assert "R.SETINTARRAY bitop_dest_src_5 7 8 9" "OK" "Set bitmap for dest/src"
+  rcall_assert "R.SETINTARRAY bitop_y_14 7 8 9 10 11" "OK" "Set bitmap Y (superset)"
+  rcall_assert "R.BITOP DIFF bitop_dest_src_5 bitop_dest_src_5 bitop_y_14" "0" "DIFF with dest as src, empty result"
+  rcall_assert "R.GETINTARRAY bitop_dest_src_5" "" "Dest should be empty after operation"
+}
+
 function test_bitop_one() {
   print_test_header "test_bitop_one"
 
@@ -204,7 +321,7 @@ function test_bitop_one() {
   rcall_assert "R.SETINTARRAY test_bitop_one_key_a 0 4 5 6" "OK" "Set bits in test_bitop_one_key_a"
   rcall_assert "R.SETINTARRAY test_bitop_one_key_b 1 5 6" "OK" "Set bits in test_bitop_one_key_b"
   rcall_assert "R.SETINTARRAY test_bitop_one_key_c 2 3 5 6 7" "OK" "Set bits in test_bitop_one_key_c"
-  
+
   rcall_assert "R.BITOP ONE test_bitop_one_result_three test_bitop_one_key_a test_bitop_one_key_b test_bitop_one_key_c" "6" "BITOP ONE with three bitmaps"
   rcall_assert "R.GETINTARRAY test_bitop_one_result_three" "0\n1\n2\n3\n4\n7" "Result should contain bits appearing exactly once"
 
@@ -357,7 +474,7 @@ function test_contains() {
   # Test with single element bitmaps
   rcall_assert "R.SETINTARRAY test_contains_single1 3" "OK" "Setup single element bitmap with [3]"
   rcall_assert "R.SETINTARRAY test_contains_single2 7" "OK" "Setup single element bitmap with [7]"
-  
+
   rcall_assert "R.CONTAINS test_contains1 test_contains_single1" "1" "test_contains1 intersects with test_contains_single1 [3]"
   rcall_assert "R.CONTAINS test_contains1 test_contains_single2" "0" "test_contains1 doesn't intersect with test_contains_single2 [7]"
   rcall_assert "R.CONTAINS test_contains1 test_contains_single1 ALL" "1" "test_contains_single1 [3] is subset of test_contains1"
@@ -368,7 +485,7 @@ function test_contains() {
   rcall_assert "R.CONTAINS nonexistent test_contains1" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent first key"
   rcall_assert "R.CONTAINS test_contains1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent second key"
   rcall_assert "R.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Should return error when both keys don't exist"
-  
+
   # Test invalid mode
   rcall_assert "R.CONTAINS test_contains1 test_contains2 INVALID_MODE" "ERR invalid mode argument: INVALID_MODE" "Should return error for invalid mode"
   rcall_assert "R.CONTAINS test_contains1 test_contains2 all" "ERR invalid mode argument: all" "Should return error for lowercase mode (case sensitive)"
@@ -377,7 +494,7 @@ function test_contains() {
   rcall_assert "R.SETINTARRAY test_contains_large1 $(seq 1 1000 | tr '\n' ' ')" "OK" "Setup large test_contains1 with 1-1000"
   rcall_assert "R.SETINTARRAY test_contains_large2 $(seq 100 200 | tr '\n' ' ')" "OK" "Setup large test_contains2 with 100-200"
   rcall_assert "R.SETINTARRAY test_contains_large3 $(seq 1001 1100 | tr '\n' ' ')" "OK" "Setup large test_contains3 with 1001-1100"
-  
+
   rcall_assert "R.CONTAINS test_contains_large1 test_contains_large2" "1" "Large bitmaps intersection test"
   rcall_assert "R.CONTAINS test_contains_large1 test_contains_large3" "0" "Large bitmaps no intersection test"
   rcall_assert "R.CONTAINS test_contains_large1 test_contains_large2 ALL" "1" "Large bitmap subset test"
@@ -388,7 +505,7 @@ function test_contains() {
   rcall_assert "R.SETINTARRAY test_contains_range1 1 5 10 15 20" "OK" "Setup sparse range bitmap"
   rcall_assert "R.SETINTARRAY test_contains_range2 5 15" "OK" "Setup subset range bitmap"
   rcall_assert "R.SETINTARRAY test_contains_range3 5 25" "OK" "Setup partial overlap range bitmap"
-  
+
   rcall_assert "R.CONTAINS test_contains_range1 test_contains_range2" "1" "Sparse range intersection test"
   rcall_assert "R.CONTAINS test_contains_range1 test_contains_range3" "1" "Partial overlap intersection test"
   rcall_assert "R.CONTAINS test_contains_range1 test_contains_range2 ALL" "1" "Sparse range subset test"
@@ -434,7 +551,7 @@ function test_stat() {
 number of array containers: 1\n\tarray container values: 1\n\tarray container bytes: 2
 bitset  containers: 0\n\tbitset  container values: 0\n\tbitset  container bytes: 0
 run containers: 0\n\trun container values: 0\n\trun container bytes: 0'
-  
+
   rcall_assert "R.STAT test_stat" "$EXPECTED_STAT" "Get bitmap statistics"
 
   EXPECTED_STAT=$'{"type":"bitmap","cardinality":"1","number_of_containers":"1","max_value":"100","min_value":"100","array_container":{"number_of_containers":"1","container_cardinality":"1","container_allocated_bytes":"2"},"bitset_container":{"number_of_containers":"0","container_cardinality":"0","container_allocated_bytes":"0"},"run_container":{"number_of_containers":"0","container_cardinality":"0","container_allocated_bytes":"0"}}'
@@ -458,6 +575,7 @@ test_getbitarray_setbitarray
 test_appendintarray_deleteintarray
 test_min_max
 test_bitop_one
+test_bitop_diff
 test_setrage
 test_clear
 test_diff
diff --git a/tests/integration_3.sh b/tests/integration_3.sh
--- a/tests/integration_3.sh
+++ b/tests/integration_3.sh
@@ -4,7 +4,7 @@ set -eu
 
 . "$(dirname "$0")/helper.sh"
 
-ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value";
+ERRORMSG_WRONGTYPE="WRONGTYPE Operation against a key holding the wrong kind of value"
 
 function test_setbit_getbit() {
   print_test_header "test_setbit_getbit (64)"
@@ -177,6 +177,117 @@ function test_min_max() {
   rcall_assert "R64.MAX test_min_max" "-1" "Get max after unsetting all bits"
 }
 
+function test_bitop_diff() {
+  print_test_header "test_bitop_diff (64)"
+
+  # Test 1: Empty/non-existent keys
+  rcall_assert "R64.BITOP DIFF diff_res empty_key_1 empty_key_2" "0"
+
+  # Test 2: Basic DIFF operation - X - Y (single Y key)
+  rcall_assert "R64.SETINTARRAY bitop_x_2 1 2 3 4 5" "OK" "Set bitmap X with values 1-5"
+  rcall_assert "R64.SETINTARRAY bitop_y_1 3 4 5 6 7" "OK" "Set bitmap Y with values 3-7"
+  rcall_assert "R64.BITOP DIFF diff_res_2 bitop_x_2 bitop_y_1" "2" "DIFF X - Y"
+  rcall_assert "R64.GETINTARRAY diff_res_2" "$(echo -e "1\n2")" "Result should be {1, 2}"
+
+  # Test 3: DIFF with multiple Y keys - X - Y1 - Y2
+  rcall_assert "R64.SETINTARRAY bitop_x_3 1 2 3 4 5 6 7 8" "OK" "Set bitmap X with values 1-8"
+  rcall_assert "R64.SETINTARRAY bitop_y1_1 2 3" "OK" "Set bitmap Y1 with values 2-3"
+  rcall_assert "R64.SETINTARRAY bitop_y2_1 5 6" "OK" "Set bitmap Y2 with values 5-6"
+  rcall_assert "R64.BITOP DIFF diff_res_3 bitop_x_3 bitop_y1_1 bitop_y2_1" "4" "DIFF X - Y1 - Y2"
+  rcall_assert "R64.GETINTARRAY diff_res_3" "$(echo -e "1\n4\n7\n8")" "Result should be {1, 4, 7, 8}"
+
+  # Test 4: DIFF with three Y keys
+  rcall_assert "R64.SETINTARRAY bitop_x_4 1 2 3 4 5 6 7 8 9 10" "OK" "Set bitmap X with values 1-10"
+  rcall_assert "R64.SETINTARRAY bitop_y1_2 1 2" "OK" "Set bitmap Y1"
+  rcall_assert "R64.SETINTARRAY bitop_y2_2 3 4" "OK" "Set bitmap Y2"
+  rcall_assert "R64.SETINTARRAY bitop_y3_1 5 6" "OK" "Set bitmap Y3"
+  rcall_assert "R64.BITOP DIFF diff_res_4 bitop_x_4 bitop_y1_2 bitop_y2_2 bitop_y3_1" "4" "DIFF X - Y1 - Y2 - Y3"
+  rcall_assert "R64.GETINTARRAY diff_res_4" "$(echo -e "7\n8\n9\n10")" "Result should be {7, 8, 9, 10}"
+
+  # Test 5: DIFF where X is completely contained in Y (empty result)
+  rcall_assert "R64.SETINTARRAY bitop_x_5 1 2 3" "OK" "Set bitmap X with values 1-3"
+  rcall_assert "R64.SETINTARRAY bitop_y_2 1 2 3 4 5" "OK" "Set bitmap Y with superset"
+  rcall_assert "R64.BITOP DIFF diff_res_5 bitop_x_5 bitop_y_2" "0" "DIFF where X subset of Y"
+  rcall_assert "R64.GETINTARRAY diff_res_5" "" "Result should be empty"
+
+  # Test 6: DIFF where X and Y are disjoint (result equals X)
+  rcall_assert "R64.SETINTARRAY bitop_x_6 1 2 3" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y_3 7 8 9" "OK" "Set bitmap Y (disjoint)"
+  rcall_assert "R64.BITOP DIFF diff_res_6 bitop_x_6 bitop_y_3" "3" "DIFF with disjoint sets"
+  rcall_assert "R64.GETINTARRAY diff_res_6" "$(echo -e "1\n2\n3")" "Result should equal X"
+
+  # Test 7: DIFF with empty X bitmap
+  rcall_assert "R64.SETINTARRAY bitop_y_4 1 2 3" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF diff_res_7 bitop_x_7 bitop_y_4" "0" "DIFF with empty X"
+  rcall_assert "R64.GETINTARRAY diff_res_7" "" "Result should be empty"
+
+  # Test 8: DIFF with empty Y bitmap (result equals X)
+  rcall_assert "R64.SETINTARRAY bitop_x_8 1 2 3 4" "OK" "Set bitmap X"
+  rcall_assert "R64.BITOP DIFF diff_res_8 bitop_x_8 bitop_y_5" "4" "DIFF with empty Y"
+  rcall_assert "R64.GETINTARRAY diff_res_8" "$(echo -e "1\n2\n3\n4")" "Result should equal X"
+
+  # Test 9: DIFF with overlapping Y keys
+  rcall_assert "R64.SETINTARRAY bitop_x_9 1 2 3 4 5 6" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y1_3 2 3 4" "OK" "Set bitmap Y1"
+  rcall_assert "R64.SETINTARRAY bitop_y2_3 3 4 5" "OK" "Set bitmap Y2 (overlaps Y1)"
+  rcall_assert "R64.BITOP DIFF diff_res_9 bitop_x_9 bitop_y1_3 bitop_y2_3" "2" "DIFF with overlapping Y keys"
+  rcall_assert "R64.GETINTARRAY diff_res_9" "$(echo -e "1\n6")" "Result should be {1, 6}"
+
+  # Test 10: Overwrite existing destination key
+  rcall_assert "R64.SETINTARRAY diff_res_10 99 100" "OK" "Pre-populate destination key"
+  rcall_assert "R64.SETINTARRAY bitop_x_10 5 6 7" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y_6 6" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF diff_res_10 bitop_x_10 bitop_y_6" "2" "DIFF overwrites existing key"
+  rcall_assert "R64.GETINTARRAY diff_res_10" "$(echo -e "5\n7")" "Destination should be overwritten, not {99, 100}"
+
+  # Test 11: DIFF with large values
+  rcall_assert "R64.SETINTARRAY bitop_x_11 1000 2000 3000 4000" "OK" "Set bitmap X with large values"
+  rcall_assert "R64.SETINTARRAY bitop_y_7 2000 3000" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF diff_res_11 bitop_x_11 bitop_y_7" "2" "DIFF with large values"
+  rcall_assert "R64.GETINTARRAY diff_res_11" "$(echo -e "1000\n4000")" "Result should be {1000, 4000}"
+
+  # Test 12: DIFF result as input to another operation
+  rcall_assert "R64.SETINTARRAY bitop_x_12 1 2 3 4 5" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y_8 3 4" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF diff_temp bitop_x_12 bitop_y_8" "3" "First DIFF operation"
+  rcall_assert "R64.SETINTARRAY bitop_y_9 1" "OK" "Set another bitmap"
+  rcall_assert "R64.BITOP DIFF diff_res_12 diff_temp bitop_y_9" "2" "Chain DIFF operations"
+  rcall_assert "R64.GETINTARRAY diff_res_12" "$(echo -e "2\n5")" "Chained result should be {2, 5}"
+
+  # Test 13: Verify X and Y keys are not modified
+  rcall_assert "R64.SETINTARRAY bitop_x_13 10 20 30" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y_10 20" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF diff_res_13 bitop_x_13 bitop_y_10" "2" "Perform DIFF"
+  rcall_assert "R64.GETINTARRAY bitop_x_13" "$(echo -e "10\n20\n30")" "X should remain unchanged"
+  rcall_assert "R64.GETINTARRAY bitop_y_10" "20" "Y should remain unchanged"
+
+  # Test 15: DIFF with destination key as middle source key
+  rcall_assert "R64.SETINTARRAY bitop_x_14 1 2 3 4 5 6 7 8" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_dest_src_2 2 3 4" "OK" "Set bitmap that will be dest and middle src"
+  rcall_assert "R64.SETINTARRAY bitop_y_12 6 7" "OK" "Set bitmap Y"
+  rcall_assert "R64.BITOP DIFF bitop_dest_src_2 bitop_x_14 bitop_dest_src_2 bitop_y_12" "3" "DIFF: X - dest - Y"
+  rcall_assert "R64.GETINTARRAY bitop_dest_src_2" "$(echo -e "1\n5\n8")" "Result should be {1, 5, 8}"
+
+  # Test 16: DIFF with destination key as last source key
+  rcall_assert "R64.SETINTARRAY bitop_x_15 10 20 30 40 50" "OK" "Set bitmap X"
+  rcall_assert "R64.SETINTARRAY bitop_y_13 20 30" "OK" "Set bitmap Y1"
+  rcall_assert "R64.SETINTARRAY bitop_dest_src_3 40" "OK" "Set bitmap that will be dest and last src"
+  rcall_assert "R64.BITOP DIFF bitop_dest_src_3 bitop_x_15 bitop_y_13 bitop_dest_src_3" "2" "DIFF: X - Y - dest"
+  rcall_assert "R64.GETINTARRAY bitop_dest_src_3" "$(echo -e "10\n50")" "Result should be {10, 50}"
+
+  # Test 17: DIFF with destination key appearing multiple times in sources
+  rcall_assert "R64.SETINTARRAY bitop_dest_src_4 5 10 15 20" "OK" "Set bitmap for dest/multi-src test"
+  rcall_assert "R64.SETINTARRAY bitop_x_16 1 2 3 4 5 10 15 20 25 30" "OK" "Set bitmap X"
+  rcall_assert "R64.BITOP DIFF bitop_dest_src_4 bitop_x_16 bitop_dest_src_4 bitop_dest_src_4" "6" "DIFF: X - dest - dest"
+  rcall_assert "R64.GETINTARRAY bitop_dest_src_4" "$(echo -e "1\n2\n3\n4\n25\n30")" "Result should be X minus original dest values"
+
+  # Test 18: DIFF with dest as first source and empty result
+  rcall_assert "R64.SETINTARRAY bitop_dest_src_5 7 8 9" "OK" "Set bitmap for dest/src"
+  rcall_assert "R64.SETINTARRAY bitop_y_14 7 8 9 10 11" "OK" "Set bitmap Y (superset)"
+  rcall_assert "R64.BITOP DIFF bitop_dest_src_5 bitop_dest_src_5 bitop_y_14" "0" "DIFF with dest as src, empty result"
+  rcall_assert "R64.GETINTARRAY bitop_dest_src_5" "" "Dest should be empty after operation"
+}
+
 function test_bitop_one() {
   print_test_header "test_bitop_one (64)"
 
@@ -204,7 +315,7 @@ function test_bitop_one() {
   rcall_assert "R.SETINTARRAY test_bitop_one64_key_a 0 4 5 6" "OK" "Set bits in test_bitop_one64_key_a"
   rcall_assert "R.SETINTARRAY test_bitop_one64_key_b 1 5 6" "OK" "Set bits in test_bitop_one64_key_b"
   rcall_assert "R.SETINTARRAY test_bitop_one64_key_c 2 3 5 6 7" "OK" "Set bits in test_bitop_one64_key_c"
-  
+
   rcall_assert "R.BITOP ONE test_bitop_one64_result_three test_bitop_one64_key_a test_bitop_one64_key_b test_bitop_one64_key_c" "6" "BITOP ONE with three bitmaps"
   rcall_assert "R.GETINTARRAY test_bitop_one64_result_three" "0\n1\n2\n3\n4\n7" "Result should contain bits appearing exactly once"
 
@@ -325,7 +436,6 @@ function test_contains() {
   rcall_assert "R64.SETINTARRAY test_contains_eq1 1 2 3 4 5" "OK" "Setup eq1 with [1,2,3,4,5]"
   rcall_assert "R64.SETINTARRAY test_contains_eq2 1 2 3 4 5" "OK" "Setup eq2 with [1,2,3,4,5] (same as eq1)"
 
-
   # Test basic intersection (default mode - should be NONE)
   rcall_assert "R64.CONTAINS test_contains1 test_contains2" "1" "test_contains1 contains some elements from test_contains2 (intersection exists)"
   rcall_assert "R64.CONTAINS test_contains1 test_contains6" "0" "test_contains1 doesn't intersect with test_contains6"
@@ -358,7 +468,7 @@ function test_contains() {
   # Test with single element bitmaps
   rcall_assert "R64.SETINTARRAY test_contains_single1 3" "OK" "Setup single element bitmap with [3]"
   rcall_assert "R64.SETINTARRAY test_contains_single2 7" "OK" "Setup single element bitmap with [7]"
-  
+
   rcall_assert "R64.CONTAINS test_contains1 test_contains_single1" "1" "test_contains1 intersects with test_contains_single1 [3]"
   rcall_assert "R64.CONTAINS test_contains1 test_contains_single2" "0" "test_contains1 doesn't intersect with test_contains_single2 [7]"
   rcall_assert "R64.CONTAINS test_contains1 test_contains_single1 ALL" "1" "test_contains_single1 [3] is subset of test_contains1"
@@ -369,7 +479,7 @@ function test_contains() {
   rcall_assert "R64.CONTAINS nonexistent test_contains1" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent first key"
   rcall_assert "R64.CONTAINS test_contains1 nonexistent" "${ERRORMSG_WRONGTYPE}" "Should return error for non-existent second key"
   rcall_assert "R64.CONTAINS nonexistent1 nonexistent2" "${ERRORMSG_WRONGTYPE}" "Should return error when both keys don't exist"
-  
+
   # Test invalid mode
   rcall_assert "R64.CONTAINS test_contains1 test_contains2 INVALID_MODE" "ERR invalid mode argument: INVALID_MODE" "Should return error for invalid mode"
   rcall_assert "R64.CONTAINS test_contains1 test_contains2 all" "ERR invalid mode argument: all" "Should return error for lowercase mode (case sensitive)"
@@ -378,7 +488,7 @@ function test_contains() {
   rcall_assert "R64.SETINTARRAY test_contains_large1 $(seq 1 1000 | tr '\n' ' ')" "OK" "Setup large test_contains1 with 1-1000"
   rcall_assert "R64.SETINTARRAY test_contains_large2 $(seq 100 200 | tr '\n' ' ')" "OK" "Setup large test_contains2 with 100-200"
   rcall_assert "R64.SETINTARRAY test_contains_large3 $(seq 1001 1100 | tr '\n' ' ')" "OK" "Setup large test_contains3 with 1001-1100"
-  
+
   rcall_assert "R64.CONTAINS test_contains_large1 test_contains_large2" "1" "Large bitmaps intersection test"
   rcall_assert "R64.CONTAINS test_contains_large1 test_contains_large3" "0" "Large bitmaps no intersection test"
   rcall_assert "R64.CONTAINS test_contains_large1 test_contains_large2 ALL" "1" "Large bitmap subset test"
@@ -389,7 +499,7 @@ function test_contains() {
   rcall_assert "R64.SETINTARRAY test_contains_range1 1 5 10 15 20" "OK" "Setup sparse range bitmap"
   rcall_assert "R64.SETINTARRAY test_contains_range2 5 15" "OK" "Setup subset range bitmap"
   rcall_assert "R64.SETINTARRAY test_contains_range3 5 25" "OK" "Setup partial overlap range bitmap"
-  
+
   rcall_assert "R64.CONTAINS test_contains_range1 test_contains_range2" "1" "Sparse range intersection test"
   rcall_assert "R64.CONTAINS test_contains_range1 test_contains_range3" "1" "Partial overlap intersection test"
   rcall_assert "R64.CONTAINS test_contains_range1 test_contains_range2 ALL" "1" "Sparse range subset test"
@@ -435,7 +545,7 @@ function test_stat() {
 number of array containers: 1\n\tarray container values: 1\n\tarray container bytes: 2
 bitset  containers: 0\n\tbitset  container values: 0\n\tbitset  container bytes: 0
 run containers: 0\n\trun container values: 0\n\trun container bytes: 0'
-  
+
   rcall_assert "R.STAT test_stat" "$EXPECTED_STAT" "Get bitmap statistics"
 
   EXPECTED_STAT=$'{"type":"bitmap64","cardinality":"1","number_of_containers":"1","max_value":"100","min_value":"100","array_container":{"number_of_containers":"1","container_cardinality":"1","container_allocated_bytes":"2"},"bitset_container":{"number_of_containers":"0","container_cardinality":"0","container_allocated_bytes":"0"},"run_container":{"number_of_containers":"0","container_cardinality":"0","container_allocated_bytes":"0"}}'
@@ -460,6 +570,7 @@ test_appendintarray_deleteintarray
 test_setrage
 test_clear
 test_min_max
+test_bitop_diff
 test_bitop_one
 test_diff
 test_optimize_nokey
diff --git a/tests/unit.c b/tests/unit.c
--- a/tests/unit.c
+++ b/tests/unit.c
@@ -26,6 +26,8 @@
 #include "unit/test_bitmap64_xor.c"
 #include "unit/test_bitmap64_not.c"
 #include "unit/test_bitmap_andor.c"
+#include "unit/test_bitmap_andnot.c"
+#include "unit/test_bitmap64_andnot.c"
 #include "unit/test_bitmap64_andor.c"
 #include "unit/test_bitmap_one.c"
 #include "unit/test_bitmap64_one.c"
@@ -71,6 +73,8 @@ int main(int argc, char* argv[]) {
   test_bitmap_and();
   test_bitmap_or();
   test_bitmap_andor();
+  test_bitmap_andnot();
+  test_bitmap64_andnot();
   test_bitmap64_andor();
   test_bitmap64_one();
   test_bitmap_one();
diff --git a/tests/unit/test_bitmap64_andnot.c b/tests/unit/test_bitmap64_andnot.c
new file mode 100644
--- /dev/null
+++ b/tests/unit/test_bitmap64_andnot.c
@@ -0,0 +1,165 @@
+#include "data-structure.h"
+#include "../test-utils.h"
+
+void test_bitmap64_andnot() {
+  DESCRIBE("bitmap64_andnot")
+  {
+    IT("Should clear bitmap when n is 0")
+    {
+      Bitmap64* result = roaring64_bitmap_from(1, 2, 3);
+
+      bitmap64_andnot(result, 0, NULL);
+
+      ASSERT_EQ(0, roaring64_bitmap_get_cardinality(result));
+      ASSERT_TRUE(roaring64_bitmap_is_empty(result));
+
+      roaring64_bitmap_free(result);
+    }
+
+    IT("Should copy bitmap when n is 1")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* input = roaring64_bitmap_from(10, 20, 30);
+
+      const Bitmap64* bitmaps[] = { input };
+      bitmap64_andnot(result, 1, bitmaps);
+
+      ASSERT_BITMAP64_EQ(input, result);
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(input);
+    }
+
+    IT("Should compute A AND NOT B when n is 2")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* a = roaring64_bitmap_from(1, 2, 3, 4);
+      Bitmap64* b = roaring64_bitmap_from(2, 4);
+
+      const Bitmap64* bitmaps[] = { a, b };
+      bitmap64_andnot(result, 2, bitmaps);
+
+      uint64_t expected[] = { 1, 3 };
+
+      ASSERT_BITMAP64_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      roaring64_bitmap_free(b);
+    }
+
+    IT("Should compute A AND NOT (B OR C OR D) when n > 2")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* a = roaring64_bitmap_from(1, 2, 3, 4, 5, 6, 7, 8);
+      Bitmap64* b = roaring64_bitmap_from(2, 3);
+      Bitmap64* c = roaring64_bitmap_from(4, 5);
+      Bitmap64* d = roaring64_bitmap_from(6, 7);
+
+      // Result should be A AND NOT (B OR C OR D) = {1, 8}
+      const Bitmap64* bitmaps[] = { a, b, c, d };
+      bitmap64_andnot(result, 4, bitmaps);
+
+      uint64_t expected[] = { 1, 8 };
+
+      ASSERT_BITMAP64_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      roaring64_bitmap_free(b);
+      roaring64_bitmap_free(c);
+      roaring64_bitmap_free(d);
+    }
+
+    IT("Should handle empty bitmaps")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* a = roaring64_bitmap_from(1, 2);
+      Bitmap64* b = roaring64_bitmap_create();
+      Bitmap64* c = roaring64_bitmap_create();
+
+      const Bitmap64* bitmaps[] = { a, b, c };
+      bitmap64_andnot(result, 3, bitmaps);
+
+      // Result should be A AND NOT (empty OR empty) = A
+      uint64_t expected[] = { 1, 2 };
+
+      ASSERT_BITMAP64_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      roaring64_bitmap_free(b);
+      roaring64_bitmap_free(c);
+    }
+
+    IT("Should handle result being empty")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* a = roaring64_bitmap_from(1, 2);
+      Bitmap64* b = roaring64_bitmap_from(1, 2, 3);
+
+      const Bitmap64* bitmaps[] = { a, b };
+      bitmap64_andnot(result, 2, bitmaps);
+
+      ASSERT_EQ(0, roaring64_bitmap_get_cardinality(result));
+      ASSERT_TRUE(roaring64_bitmap_is_empty(result));
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      roaring64_bitmap_free(b);
+    }
+
+    IT("Should handle result bitmap with existing data")
+    {
+      Bitmap64* result = roaring64_bitmap_from(100, 200);
+      Bitmap64* a = roaring64_bitmap_from(1, 2);
+      Bitmap64* b = roaring64_bitmap_from(1);
+
+      const Bitmap64* bitmaps[] = { a, b };
+      bitmap64_andnot(result, 2, bitmaps);
+
+      uint64_t expected[] = { 2 };
+
+      ASSERT_BITMAP64_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      roaring64_bitmap_free(b);
+    }
+
+    IT("Should handle large number of bitmaps")
+    {
+      Bitmap64* result = roaring64_bitmap_create();
+      Bitmap64* a = roaring64_bitmap_create();
+
+      const int num_bitmaps = 10;
+      Bitmap64* others[num_bitmaps];
+      const Bitmap64* bitmaps[num_bitmaps + 1];
+
+      // A = {0, 1, 2, ..., 19}
+      for (uint64_t i = 0; i < 20; i++) {
+        roaring64_bitmap_add(a, i);
+      }
+
+      bitmaps[0] = a;
+
+      // Each other bitmap removes 2 values
+      for (int i = 0; i < num_bitmaps; i++) {
+        others[i] = roaring64_bitmap_create();
+        roaring64_bitmap_add(others[i], i * 2);
+        roaring64_bitmap_add(others[i], i * 2 + 1);
+        bitmaps[i + 1] = others[i];
+      }
+
+      bitmap64_andnot(result, num_bitmaps + 1, bitmaps);
+
+      ASSERT_EQ(0, roaring64_bitmap_get_cardinality(result));
+
+      roaring64_bitmap_free(result);
+      roaring64_bitmap_free(a);
+      for (int i = 0; i < num_bitmaps; i++) {
+        roaring64_bitmap_free(others[i]);
+      }
+    }
+  }
+}
diff --git a/tests/unit/test_bitmap_andnot.c b/tests/unit/test_bitmap_andnot.c
new file mode 100644
--- /dev/null
+++ b/tests/unit/test_bitmap_andnot.c
@@ -0,0 +1,165 @@
+#include "data-structure.h"
+#include "../test-utils.h"
+
+void test_bitmap_andnot() {
+  DESCRIBE("bitmap_andnot")
+  {
+    IT("Should clear bitmap when n is 0")
+    {
+      Bitmap* result = roaring_bitmap_from(1, 2, 3);
+
+      bitmap_andnot(result, 0, NULL);
+
+      ASSERT_EQ(0, roaring_bitmap_get_cardinality(result));
+      ASSERT_TRUE(roaring_bitmap_is_empty(result));
+
+      roaring_bitmap_free(result);
+    }
+
+    IT("Should copy bitmap when n is 1")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* input = roaring_bitmap_from(10, 20, 30);
+
+      const Bitmap* bitmaps[] = { input };
+      bitmap_andnot(result, 1, bitmaps);
+
+      ASSERT_BITMAP_EQ(input, result);
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(input);
+    }
+
+    IT("Should compute A AND NOT B when n is 2")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* a = roaring_bitmap_from(1, 2, 3, 4);
+      Bitmap* b = roaring_bitmap_from(2, 4);
+
+      const Bitmap* bitmaps[] = { a, b };
+      bitmap_andnot(result, 2, bitmaps);
+
+      uint32_t expected[] = { 1, 3 };
+
+      ASSERT_BITMAP_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      roaring_bitmap_free(b);
+    }
+
+    IT("Should compute A AND NOT (B OR C OR D) when n > 2")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* a = roaring_bitmap_from(1, 2, 3, 4, 5, 6, 7, 8);
+      Bitmap* b = roaring_bitmap_from(2, 3);
+      Bitmap* c = roaring_bitmap_from(4, 5);
+      Bitmap* d = roaring_bitmap_from(6, 7);
+
+      // Result should be A AND NOT (B OR C OR D) = {1, 8}
+      const Bitmap* bitmaps[] = { a, b, c, d };
+      bitmap_andnot(result, 4, bitmaps);
+
+      uint32_t expected[] = { 1, 8 };
+
+      ASSERT_BITMAP_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      roaring_bitmap_free(b);
+      roaring_bitmap_free(c);
+      roaring_bitmap_free(d);
+    }
+
+    IT("Should handle empty bitmaps")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* a = roaring_bitmap_from(1, 2);
+      Bitmap* b = roaring_bitmap_create();
+      Bitmap* c = roaring_bitmap_create();
+
+      const Bitmap* bitmaps[] = { a, b, c };
+      bitmap_andnot(result, 3, bitmaps);
+
+      // Result should be A AND NOT (empty OR empty) = A
+      uint32_t expected[] = { 1, 2 };
+
+      ASSERT_BITMAP_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      roaring_bitmap_free(b);
+      roaring_bitmap_free(c);
+    }
+
+    IT("Should handle result being empty")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* a = roaring_bitmap_from(1, 2);
+      Bitmap* b = roaring_bitmap_from(1, 2, 3);
+
+      const Bitmap* bitmaps[] = { a, b };
+      bitmap_andnot(result, 2, bitmaps);
+
+      ASSERT_EQ(0, roaring_bitmap_get_cardinality(result));
+      ASSERT_TRUE(roaring_bitmap_is_empty(result));
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      roaring_bitmap_free(b);
+    }
+
+    IT("Should handle result bitmap with existing data")
+    {
+      Bitmap* result = roaring_bitmap_from(100, 200);
+      Bitmap* a = roaring_bitmap_from(1, 2);
+      Bitmap* b = roaring_bitmap_from(1);
+
+      const Bitmap* bitmaps[] = { a, b };
+      bitmap_andnot(result, 2, bitmaps);
+
+      uint32_t expected[] = { 2 };
+
+      ASSERT_BITMAP_EQ_ARRAY(expected, ARRAY_LENGTH(expected), result);
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      roaring_bitmap_free(b);
+    }
+
+    IT("Should handle large number of bitmaps")
+    {
+      Bitmap* result = roaring_bitmap_create();
+      Bitmap* a = roaring_bitmap_create();
+
+      const int num_bitmaps = 10;
+      Bitmap* others[num_bitmaps];
+      const Bitmap* bitmaps[num_bitmaps + 1];
+
+      // A = {0, 1, 2, ..., 19}
+      for (uint32_t i = 0; i < 20; i++) {
+        roaring_bitmap_add(a, i);
+      }
+
+      bitmaps[0] = a;
+
+      // Each other bitmap removes 2 values
+      for (int i = 0; i < num_bitmaps; i++) {
+        others[i] = roaring_bitmap_create();
+        roaring_bitmap_add(others[i], i * 2);
+        roaring_bitmap_add(others[i], i * 2 + 1);
+        bitmaps[i + 1] = others[i];
+      }
+
+      bitmap_andnot(result, num_bitmaps + 1, bitmaps);
+
+      ASSERT_EQ(0, roaring_bitmap_get_cardinality(result));
+
+      roaring_bitmap_free(result);
+      roaring_bitmap_free(a);
+      for (int i = 0; i < num_bitmaps; i++) {
+        roaring_bitmap_free(others[i]);
+      }
+    }
+  }
+}
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed/build
cmake .. && make -j$(nproc)

# Return to testbed root
cd /testbed

# Source the helper script for test utilities
source tests/helper.sh

# Setup test environment
setup

# Clean up any existing Redis persistence files
rm -f dump.rdb appendonly.aof

# Run unit tests with valgrind
echo "=== Running unit tests ==="
valgrind --leak-check=full --error-exitcode=1 ./build/unit
unit_rc=$?

# Stop any running Redis instances and clean up
stop_redis
rm -f dump.rdb appendonly.aof

# Run integration_1.sh tests
echo "=== Running integration_1.sh tests ==="
start_redis --valgrind
./tests/integration_1.sh
integration_1_rc=$?
stop_redis
rm -f dump.rdb appendonly.aof

# Run integration_3.sh tests
echo "=== Running integration_3.sh tests ==="
start_redis --valgrind
./tests/integration_3.sh
integration_3_rc=$?
stop_redis
rm -f dump.rdb appendonly.aof

# Calculate overall exit code (non-zero if any test failed)
rc=0
if [ $unit_rc -ne 0 ]; then
    rc=$unit_rc
elif [ $integration_1_rc -ne 0 ]; then
    rc=$integration_1_rc
elif [ $integration_3_rc -ne 0 ]; then
    rc=$integration_3_rc
fi

echo "=== Test Results Summary ==="
echo "Unit tests: $unit_rc"
echo "Integration 1 tests: $integration_1_rc"
echo "Integration 3 tests: $integration_3_rc"
echo "Overall: $rc"

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout be52cc241cdb9ba946e02301fe25ce5640c3d334 "tests/integration_1.sh" "tests/integration_3.sh" "tests/unit.c"