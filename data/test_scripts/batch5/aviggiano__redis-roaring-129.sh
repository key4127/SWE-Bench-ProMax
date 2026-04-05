#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 12288bcd72b1b264e90142af4f1efa1c3c511015 "tests/unit/test_bitmap_and.c" "tests/unit/test_bitmap_andor.c" "tests/unit/test_bitmap_or.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/fuzz/fuzz_bitmap64_api.c b/tests/fuzz/fuzz_bitmap64_api.c
new file mode 100644
--- /dev/null
+++ b/tests/fuzz/fuzz_bitmap64_api.c
@@ -0,0 +1,329 @@
+/*
+ * Fuzzer for 64-bit Bitmap API (Simplified)
+ *
+ * This fuzzer tests the main redis-roaring bitmap operations with:
+ * - Single bitmap per iteration (no state management)
+ * - Random sequence of operations
+ * - Edge cases and error handling
+ */
+
+#include "fuzz_common.h"
+
+int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
+    /* Need at least a few bytes to do anything interesting */
+    if (size < 4) {
+        return 0;
+    }
+
+    FuzzInput input;
+    fuzz_input_init(&input, data, size);
+
+    /* Single bitmap - no state management */
+    Bitmap64* bitmap = bitmap64_alloc();
+    if (!bitmap) {
+        return 0;
+    }
+
+    /* Perform random operations */
+    int operations = 0;
+    while (fuzz_input_remaining(&input) > 0 && operations < MAX_FUZZ_OPERATIONS) {
+        operations++;
+
+        uint8_t op = fuzz_consume_u8(&input) % NUM_BITMAP64_OPERATIONS;
+
+        switch (op) {
+            case OP_SETBIT: {
+                uint64_t offset = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                bool value = fuzz_consume_bool(&input);
+                bitmap64_setbit(bitmap, offset, value);
+                break;
+            }
+
+            case OP_GETBIT: {
+                uint64_t offset = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                bitmap64_getbit(bitmap, offset);
+                break;
+            }
+
+            case OP_SETINTARRAY: {
+                size_t array_size;
+                uint64_t* array = generate_uint64_array(&input, &array_size);
+                if (array && array_size > 0) {
+                    Bitmap64* new_bitmap = bitmap64_from_int_array(array_size, array);
+                    if (new_bitmap) {
+                        bitmap64_free(bitmap);
+                        bitmap = new_bitmap;
+                    }
+                    safe_free(array);
+                }
+                break;
+            }
+
+            case OP_GETINTARRAY: {
+                /* Only get array if cardinality is reasonable */
+                uint64_t card = bitmap64_get_cardinality(bitmap);
+                if (card > 0 && card < MAX_SAFE_CARDINALITY) {
+                    size_t result_size;
+                    uint64_t* result = bitmap64_get_int_array(bitmap, &result_size);
+                    safe_free(result);
+                }
+                break;
+            }
+
+            case OP_APPENDINTARRAY: {
+                size_t array_size;
+                uint64_t* array = generate_uint64_array(&input, &array_size);
+                if (array && array_size > 0) {
+                    Bitmap64* new_values = bitmap64_from_int_array(array_size, array);
+                    if (new_values) {
+                        roaring64_bitmap_or_inplace(bitmap, new_values);
+                        bitmap64_free(new_values);
+                    }
+                    safe_free(array);
+                }
+                break;
+            }
+
+            case OP_RANGEINTARRAY: {
+                uint64_t card = bitmap64_get_cardinality(bitmap);
+                if (card > 0) {
+                    size_t start = fuzz_consume_size_in_range(&input, 0, card);
+                    size_t end = fuzz_consume_size_in_range(&input, start, card + 100);
+                    size_t result_count;
+                    uint64_t* result = bitmap64_range_int_array(bitmap, start, end, &result_count);
+                    safe_free(result);
+                }
+                break;
+            }
+
+            case OP_SETBITARRAY: {
+                size_t bit_array_size;
+                char* bit_array = generate_bit_array_string(&input, &bit_array_size);
+                if (bit_array && bit_array_size > 0) {
+                    Bitmap64* new_bitmap = bitmap64_from_bit_array(bit_array_size, bit_array);
+                    if (new_bitmap) {
+                        bitmap64_free(bitmap);
+                        bitmap = new_bitmap;
+                    }
+                    safe_free(bit_array);
+                }
+                break;
+            }
+
+            case OP_GETBITARRAY: {
+                /* Only get bit array if max value is reasonable */
+                if (!bitmap64_is_empty(bitmap)) {
+                    uint64_t max_val = bitmap64_max(bitmap);
+                    if (max_val < MAX_BIT_OFFSET_64) {
+                        size_t result_size;
+                        char* bit_array = bitmap64_get_bit_array(bitmap, &result_size);
+                        bitmap_free_bit_array(bit_array);
+                    }
+                }
+                break;
+            }
+
+            case OP_SETRANGE: {
+                /* Clamp both from and range size to avoid excessive memory */
+                uint64_t from = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                uint64_t range_size = fuzz_consume_u64_in_range(&input, 0, 1000000);
+                uint64_t to = from + range_size;
+                Bitmap64* range_bitmap = bitmap64_from_range(from, to);
+                if (range_bitmap) {
+                    bitmap64_free(bitmap);
+                    bitmap = range_bitmap;
+                }
+                break;
+            }
+
+            case OP_BITOP_AND:
+            case OP_BITOP_OR:
+            case OP_BITOP_XOR:
+            case OP_BITOP_ANDOR:
+            case OP_BITOP_ANDNOT:
+            case OP_BITOP_ORNOT:
+            case OP_BITOP_ONE: {
+                /* Create temporary second bitmap for binary operations */
+                Bitmap64* bitmap2 = bitmap64_alloc();
+                if (bitmap2) {
+                    /* Add some random bits to second bitmap */
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        uint64_t offset = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                        bitmap64_setbit(bitmap2, offset, true);
+                    }
+
+                    const Bitmap64* inputs[2] = {bitmap, bitmap2};
+                    Bitmap64* result = bitmap64_alloc();
+                    if (result) {
+                        switch (op) {
+                            case OP_BITOP_AND:
+                                bitmap64_and(result, 2, inputs);
+                                break;
+                            case OP_BITOP_OR:
+                                bitmap64_or(result, 2, inputs);
+                                break;
+                            case OP_BITOP_XOR:
+                                bitmap64_xor(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ANDOR:
+                                bitmap64_andor(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ANDNOT:
+                                bitmap64_andnot(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ORNOT:
+                                bitmap64_ornot(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ONE:
+                                bitmap64_one(result, 2, inputs);
+                                break;
+                        }
+                        bitmap64_free(result);
+                    }
+                    bitmap64_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_BITOP_NOT: {
+                Bitmap64* result = bitmap64_not(bitmap);
+                if (result) {
+                    bitmap64_free(result);
+                }
+                break;
+            }
+
+            case OP_MIN: {
+                if (!bitmap64_is_empty(bitmap)) {
+                    bitmap64_min(bitmap);
+                }
+                break;
+            }
+
+            case OP_MAX: {
+                if (!bitmap64_is_empty(bitmap)) {
+                    bitmap64_max(bitmap);
+                }
+                break;
+            }
+
+            case OP_OPTIMIZE: {
+                bool shrink = fuzz_consume_bool(&input);
+                bitmap64_optimize(bitmap, shrink);
+                break;
+            }
+
+            case OP_STATISTICS: {
+                int format = fuzz_consume_u8(&input) % 2;
+                int size_out;
+                char* stats = bitmap64_statistics_str(bitmap, format, &size_out);
+                safe_free(stats);
+                break;
+            }
+
+            case OP_CARDINALITY: {
+                bitmap64_get_cardinality(bitmap);
+                break;
+            }
+
+            case OP_ISEMPTY: {
+                bitmap64_is_empty(bitmap);
+                break;
+            }
+
+            case OP_GETBITS: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint64_t* offsets = (uint64_t*)malloc(n_offsets * sizeof(uint64_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        offsets[i] = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                    }
+                    bool* results = bitmap64_getbits(bitmap, n_offsets, offsets);
+                    safe_free(results);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_CLEARBITS: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint64_t* offsets = (uint64_t*)malloc(n_offsets * sizeof(uint64_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        offsets[i] = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                    }
+                    bitmap64_clearbits(bitmap, n_offsets, offsets);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_CLEARBITS_COUNT: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint64_t* offsets = (uint64_t*)malloc(n_offsets * sizeof(uint64_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        offsets[i] = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                    }
+                    bitmap64_clearbits_count(bitmap, n_offsets, offsets);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_INTERSECT: {
+                /* Create temporary second bitmap */
+                Bitmap64* bitmap2 = bitmap64_alloc();
+                if (bitmap2) {
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        uint64_t offset = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                        bitmap64_setbit(bitmap2, offset, true);
+                    }
+                    uint64_t mode = fuzz_consume_u8(&input) % 4;
+                    bitmap64_intersect(bitmap, bitmap2, mode);
+                    bitmap64_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_JACCARD: {
+                /* Create temporary second bitmap */
+                Bitmap64* bitmap2 = bitmap64_alloc();
+                if (bitmap2) {
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint64_t); i++) {
+                        uint64_t offset = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                        bitmap64_setbit(bitmap2, offset, true);
+                    }
+                    bitmap64_jaccard(bitmap, bitmap2);
+                    bitmap64_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_GET_NTH_ELEMENT: {
+                uint64_t n = fuzz_consume_u64(&input);
+                if (n < 1000000) {
+                    bool found;
+                    bitmap64_get_nth_element_present(bitmap, n, &found);
+                    bitmap64_get_nth_element_not_present(bitmap, n, &found);
+                }
+                break;
+            }
+
+            case OP_FREE_AND_ALLOC: {
+                /* Stress test allocation/deallocation */
+                Bitmap64* temp = bitmap64_alloc();
+                if (temp) {
+                    bitmap64_free(temp);
+                }
+                break;
+            }
+
+            default:
+                break;
+        }
+    }
+
+    bitmap64_free(bitmap);
+    return 0;
+}
diff --git a/tests/fuzz/fuzz_bitmap_api.c b/tests/fuzz/fuzz_bitmap_api.c
new file mode 100644
--- /dev/null
+++ b/tests/fuzz/fuzz_bitmap_api.c
@@ -0,0 +1,328 @@
+/*
+ * Fuzzer for 32-bit Bitmap API (Simplified)
+ *
+ * This fuzzer tests the main redis-roaring bitmap operations with:
+ * - Single bitmap per iteration (no state management)
+ * - Random sequence of operations
+ * - Edge cases and error handling
+ */
+
+#include "fuzz_common.h"
+
+int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
+    /* Need at least a few bytes to do anything interesting */
+    if (size < 4) {
+        return 0;
+    }
+
+    FuzzInput input;
+    fuzz_input_init(&input, data, size);
+
+    /* Single bitmap - no state management */
+    Bitmap* bitmap = bitmap_alloc();
+    if (!bitmap) {
+        return 0;
+    }
+
+    /* Perform random operations */
+    int operations = 0;
+    while (fuzz_input_remaining(&input) > 0 && operations < MAX_FUZZ_OPERATIONS) {
+        operations++;
+
+        uint8_t op = fuzz_consume_u8(&input) % NUM_BITMAP_OPERATIONS;
+
+        switch (op) {
+            case OP_SETBIT: {
+                uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                bool value = fuzz_consume_bool(&input);
+                bitmap_setbit(bitmap, offset, value);
+                break;
+            }
+
+            case OP_GETBIT: {
+                uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                bitmap_getbit(bitmap, offset);
+                break;
+            }
+
+            case OP_SETINTARRAY: {
+                size_t array_size;
+                uint32_t* array = generate_uint32_array(&input, &array_size);
+                if (array && array_size > 0) {
+                    Bitmap* new_bitmap = bitmap_from_int_array(array_size, array);
+                    if (new_bitmap) {
+                        bitmap_free(bitmap);
+                        bitmap = new_bitmap;
+                    }
+                    safe_free(array);
+                }
+                break;
+            }
+
+            case OP_GETINTARRAY: {
+                /* Only get array if cardinality is reasonable */
+                uint64_t card = bitmap_get_cardinality(bitmap);
+                if (card > 0 && card < MAX_SAFE_CARDINALITY) {
+                    size_t result_size;
+                    uint32_t* result = bitmap_get_int_array(bitmap, &result_size);
+                    safe_free(result);
+                }
+                break;
+            }
+
+            case OP_APPENDINTARRAY: {
+                size_t array_size;
+                uint32_t* array = generate_uint32_array(&input, &array_size);
+                if (array && array_size > 0) {
+                    Bitmap* new_values = bitmap_from_int_array(array_size, array);
+                    if (new_values) {
+                        roaring_bitmap_or_inplace(bitmap, new_values);
+                        bitmap_free(new_values);
+                    }
+                    safe_free(array);
+                }
+                break;
+            }
+
+            case OP_RANGEINTARRAY: {
+                uint64_t card = bitmap_get_cardinality(bitmap);
+                if (card > 0) {
+                    size_t start = fuzz_consume_size_in_range(&input, 0, card);
+                    size_t end = fuzz_consume_size_in_range(&input, start, card + 100);
+                    size_t result_count;
+                    uint32_t* result = bitmap_range_int_array(bitmap, start, end, &result_count);
+                    safe_free(result);
+                }
+                break;
+            }
+
+            case OP_SETBITARRAY: {
+                size_t bit_array_size;
+                char* bit_array = generate_bit_array_string(&input, &bit_array_size);
+                if (bit_array && bit_array_size > 0) {
+                    Bitmap* new_bitmap = bitmap_from_bit_array(bit_array_size, bit_array);
+                    if (new_bitmap) {
+                        bitmap_free(bitmap);
+                        bitmap = new_bitmap;
+                    }
+                    safe_free(bit_array);
+                }
+                break;
+            }
+
+            case OP_GETBITARRAY: {
+                /* Only get bit array if max value is reasonable */
+                if (!bitmap_is_empty(bitmap)) {
+                    uint32_t max_val = bitmap_max(bitmap);
+                    if (max_val < MAX_BIT_OFFSET_32) {
+                        size_t result_size;
+                        char* bit_array = bitmap_get_bit_array(bitmap, &result_size);
+                        bitmap_free_bit_array(bit_array);
+                    }
+                }
+                break;
+            }
+
+            case OP_SETRANGE: {
+                /* Clamp both from and range size to avoid excessive memory */
+                uint64_t from = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                uint64_t range_size = fuzz_consume_u32_in_range(&input, 0, 1000000);
+                uint64_t to = from + range_size;
+                Bitmap* range_bitmap = bitmap_from_range(from, to);
+                if (range_bitmap) {
+                    bitmap_free(bitmap);
+                    bitmap = range_bitmap;
+                }
+                break;
+            }
+
+            case OP_BITOP_AND:
+            case OP_BITOP_OR:
+            case OP_BITOP_XOR:
+            case OP_BITOP_ANDOR:
+            case OP_BITOP_ANDNOT:
+            case OP_BITOP_ORNOT:
+            case OP_BITOP_ONE: {
+                /* Create temporary second bitmap for binary operations */
+                Bitmap* bitmap2 = bitmap_alloc();
+                if (bitmap2) {
+                    /* Add some random bits to second bitmap */
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                        bitmap_setbit(bitmap2, offset, true);
+                    }
+
+                    const Bitmap* inputs[2] = {bitmap, bitmap2};
+                    Bitmap* result = bitmap_alloc();
+                    if (result) {
+                        switch (op) {
+                            case OP_BITOP_AND:
+                                bitmap_and(result, 2, inputs);
+                                break;
+                            case OP_BITOP_OR:
+                                bitmap_or(result, 2, inputs);
+                                break;
+                            case OP_BITOP_XOR:
+                                bitmap_xor(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ANDOR:
+                                bitmap_andor(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ANDNOT:
+                                bitmap_andnot(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ORNOT:
+                                bitmap_ornot(result, 2, inputs);
+                                break;
+                            case OP_BITOP_ONE:
+                                bitmap_one(result, 2, inputs);
+                                break;
+                        }
+                        bitmap_free(result);
+                    }
+                    bitmap_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_BITOP_NOT: {
+                Bitmap* result = bitmap_not(bitmap);
+                if (result) {
+                    bitmap_free(result);
+                }
+                break;
+            }
+
+            case OP_MIN: {
+                if (!bitmap_is_empty(bitmap)) {
+                    bitmap_min(bitmap);
+                }
+                break;
+            }
+
+            case OP_MAX: {
+                if (!bitmap_is_empty(bitmap)) {
+                    bitmap_max(bitmap);
+                }
+                break;
+            }
+
+            case OP_OPTIMIZE: {
+                bool shrink = fuzz_consume_bool(&input);
+                bitmap_optimize(bitmap, shrink);
+                break;
+            }
+
+            case OP_STATISTICS: {
+                int format = fuzz_consume_u8(&input) % 2;
+                int size_out;
+                char* stats = bitmap_statistics_str(bitmap, format, &size_out);
+                safe_free(stats);
+                break;
+            }
+
+            case OP_CARDINALITY: {
+                bitmap_get_cardinality(bitmap);
+                break;
+            }
+
+            case OP_ISEMPTY: {
+                bitmap_is_empty(bitmap);
+                break;
+            }
+
+            case OP_GETBITS: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint32_t* offsets = (uint32_t*)malloc(n_offsets * sizeof(uint32_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        offsets[i] = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                    }
+                    bool* results = bitmap_getbits(bitmap, n_offsets, offsets);
+                    safe_free(results);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_CLEARBITS: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint32_t* offsets = (uint32_t*)malloc(n_offsets * sizeof(uint32_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        offsets[i] = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                    }
+                    bitmap_clearbits(bitmap, n_offsets, offsets);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_CLEARBITS_COUNT: {
+                size_t n_offsets = fuzz_consume_size_in_range(&input, 1, 100);
+                uint32_t* offsets = (uint32_t*)malloc(n_offsets * sizeof(uint32_t));
+                if (offsets) {
+                    for (size_t i = 0; i < n_offsets && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        offsets[i] = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                    }
+                    bitmap_clearbits_count(bitmap, n_offsets, offsets);
+                    safe_free(offsets);
+                }
+                break;
+            }
+
+            case OP_INTERSECT: {
+                /* Create temporary second bitmap */
+                Bitmap* bitmap2 = bitmap_alloc();
+                if (bitmap2) {
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                        bitmap_setbit(bitmap2, offset, true);
+                    }
+                    uint32_t mode = fuzz_consume_u8(&input) % 4;
+                    bitmap_intersect(bitmap, bitmap2, mode);
+                    bitmap_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_JACCARD: {
+                /* Create temporary second bitmap */
+                Bitmap* bitmap2 = bitmap_alloc();
+                if (bitmap2) {
+                    for (int i = 0; i < 10 && fuzz_input_remaining(&input) > sizeof(uint32_t); i++) {
+                        uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                        bitmap_setbit(bitmap2, offset, true);
+                    }
+                    bitmap_jaccard(bitmap, bitmap2);
+                    bitmap_free(bitmap2);
+                }
+                break;
+            }
+
+            case OP_GET_NTH_ELEMENT: {
+                uint64_t n = fuzz_consume_u64(&input);
+                if (n < 1000000) {
+                    bitmap_get_nth_element_present(bitmap, n);
+                    bitmap_get_nth_element_not_present(bitmap, n);
+                }
+                break;
+            }
+
+            case OP_FREE_AND_ALLOC: {
+                /* Stress test allocation/deallocation */
+                Bitmap* temp = bitmap_alloc();
+                if (temp) {
+                    bitmap_free(temp);
+                }
+                break;
+            }
+
+            default:
+                break;
+        }
+    }
+
+    bitmap_free(bitmap);
+    return 0;
+}
diff --git a/tests/fuzz/fuzz_bitmap_operations.c b/tests/fuzz/fuzz_bitmap_operations.c
new file mode 100644
--- /dev/null
+++ b/tests/fuzz/fuzz_bitmap_operations.c
@@ -0,0 +1,248 @@
+/*
+ * Focused Fuzzer for Bitmap Operations
+ *
+ * This fuzzer specifically targets complex bitmap operations:
+ * - Operations with multiple input bitmaps (2-10 inputs)
+ * - Edge cases: empty bitmaps, full bitmaps, overlapping ranges
+ * - All BITOP variants (AND, OR, XOR, NOT, ANDOR, ANDNOT, ORNOT, ONE)
+ */
+
+#include "fuzz_common.h"
+
+#define MAX_OPERATION_INPUTS 10
+
+/* Operation types for operations fuzzer */
+enum OperationFuzzType {
+    OP_FUZZ_AND = 0,
+    OP_FUZZ_OR,
+    OP_FUZZ_XOR,
+    OP_FUZZ_ANDOR,
+    OP_FUZZ_ANDNOT,
+    OP_FUZZ_ORNOT,
+    OP_FUZZ_ONE,
+    OP_FUZZ_NOT,
+    NUM_OP_FUZZ_TYPES
+};
+
+int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
+    if (size < 8) {
+        return 0;
+    }
+
+    FuzzInput input;
+    fuzz_input_init(&input, data, size);
+
+    /* Decide on number of input bitmaps */
+    int num_inputs = (int)fuzz_consume_u32_in_range(&input, 2, MAX_OPERATION_INPUTS);
+
+    /* Create input bitmaps */
+    Bitmap* inputs[MAX_OPERATION_INPUTS];
+    for (int i = 0; i < num_inputs; i++) {
+        inputs[i] = bitmap_alloc();
+        if (!inputs[i]) {
+            /* Cleanup and return */
+            for (int j = 0; j < i; j++) {
+                bitmap_free(inputs[j]);
+            }
+            return 0;
+        }
+
+        /* Populate each bitmap with different patterns */
+        uint8_t pattern = fuzz_consume_u8(&input) % 6;
+        switch (pattern) {
+            case 0: /* Empty bitmap */
+                break;
+
+            case 1: /* Small sparse set */
+                for (int j = 0; j < 10; j++) {
+                    uint32_t offset = fuzz_consume_u32(&input) % 1000;
+                    bitmap_setbit(inputs[i], offset, true);
+                }
+                break;
+
+            case 2: /* Dense range */
+                {
+                    uint32_t start = fuzz_consume_u32(&input) % 10000;
+                    uint32_t len = fuzz_consume_u32_in_range(&input, 100, 1000);
+                    Bitmap* range = bitmap_from_range(start, start + len);
+                    if (range) {
+                        bitmap_free(inputs[i]);
+                        inputs[i] = range;
+                    }
+                }
+                break;
+
+            case 3: /* Random from array */
+                {
+                    size_t array_size;
+                    uint32_t* array = generate_uint32_array(&input, &array_size);
+                    if (array && array_size > 0) {
+                        Bitmap* from_array = bitmap_from_int_array(array_size, array);
+                        if (from_array) {
+                            bitmap_free(inputs[i]);
+                            inputs[i] = from_array;
+                        }
+                        safe_free(array);
+                    }
+                }
+                break;
+
+            case 4: /* Bit pattern */
+                {
+                    size_t bit_size;
+                    char* bit_array = generate_bit_array_string(&input, &bit_size);
+                    if (bit_array && bit_size > 0) {
+                        Bitmap* from_bits = bitmap_from_bit_array(bit_size, bit_array);
+                        if (from_bits) {
+                            bitmap_free(inputs[i]);
+                            inputs[i] = from_bits;
+                        }
+                        safe_free(bit_array);
+                    }
+                }
+                break;
+
+            case 5: /* Large sparse set */
+                for (int j = 0; j < 100; j++) {
+                    uint32_t offset = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                    bitmap_setbit(inputs[i], offset, true);
+                }
+                break;
+        }
+    }
+
+    /* Create result bitmap */
+    Bitmap* result = bitmap_alloc();
+    if (!result) {
+        for (int i = 0; i < num_inputs; i++) {
+            bitmap_free(inputs[i]);
+        }
+        return 0;
+    }
+
+    /* Create const pointer array for operations */
+    const Bitmap* const_inputs[MAX_OPERATION_INPUTS];
+    for (int i = 0; i < num_inputs; i++) {
+        const_inputs[i] = inputs[i];
+    }
+
+    /* Test various operations */
+    uint8_t operation = fuzz_consume_u8(&input) % NUM_OP_FUZZ_TYPES;
+
+    switch (operation) {
+        case OP_FUZZ_AND:
+            bitmap_and(result, num_inputs, const_inputs);
+
+            /* Verify result is subset of all inputs */
+            for (int i = 0; i < num_inputs; i++) {
+                Bitmap* intersection = bitmap_alloc();
+                const Bitmap* pair[2] = {result, inputs[i]};
+                bitmap_and(intersection, 2, pair);
+
+                /* Result AND input[i] should equal result */
+                uint64_t result_card = bitmap_get_cardinality(result);
+                uint64_t inter_card = bitmap_get_cardinality(intersection);
+
+                /* Basic invariant check (can be removed in production fuzzing) */
+                if (result_card != inter_card) {
+                    /* This shouldn't happen, but we don't abort - just note it */
+                }
+
+                bitmap_free(intersection);
+            }
+            break;
+
+        case OP_FUZZ_OR:
+            bitmap_or(result, num_inputs, const_inputs);
+
+            /* Verify result is superset of all inputs */
+            for (int i = 0; i < num_inputs; i++) {
+                uint64_t input_card = bitmap_get_cardinality(inputs[i]);
+                uint64_t result_card = bitmap_get_cardinality(result);
+
+                /* Result should have at least as many elements as any input */
+                if (result_card < input_card) {
+                    /* Invariant violation (shouldn't happen) */
+                }
+            }
+            break;
+
+        case OP_FUZZ_XOR:
+            bitmap_xor(result, num_inputs, const_inputs);
+
+            /* Just ensure it doesn't crash */
+            bitmap_get_cardinality(result);
+            break;
+
+        case OP_FUZZ_ANDOR:
+            bitmap_andor(result, num_inputs, const_inputs);
+            bitmap_get_cardinality(result);
+            break;
+
+        case OP_FUZZ_ANDNOT:
+            bitmap_andnot(result, num_inputs, const_inputs);
+            bitmap_get_cardinality(result);
+            break;
+
+        case OP_FUZZ_ORNOT:
+            bitmap_ornot(result, num_inputs, const_inputs);
+            bitmap_get_cardinality(result);
+            break;
+
+        case OP_FUZZ_ONE:
+            bitmap_one(result, num_inputs, const_inputs);
+            bitmap_get_cardinality(result);
+            break;
+
+        case OP_FUZZ_NOT:
+            {
+                Bitmap* not_result = bitmap_not(inputs[0]);
+                if (not_result) {
+                    /* NOT followed by NOT should give original (with bounds) */
+                    Bitmap* double_not = bitmap_not(not_result);
+                    if (double_not) {
+                        bitmap_free(double_not);
+                    }
+                    bitmap_free(not_result);
+                }
+            }
+            break;
+    }
+
+    /* Test some additional operations on result */
+    if (!bitmap_is_empty(result)) {
+        bitmap_min(result);
+        bitmap_max(result);
+        bitmap_optimize(result, 1);
+
+        /* Get statistics */
+        Bitmap_statistics stats;
+        bitmap_statistics(result, &stats);
+    }
+
+    /* Test intersect modes between pairs */
+    if (num_inputs >= 2) {
+        for (uint32_t mode = BITMAP_INTERSECT_MODE_NONE;
+             mode <= BITMAP_INTERSECT_MODE_EQ && fuzz_input_remaining(&input) > 0;
+             mode++) {
+            bitmap_intersect(inputs[0], inputs[1], mode);
+        }
+    }
+
+    /* Test jaccard similarity */
+    if (num_inputs >= 2) {
+        double jaccard = bitmap_jaccard(inputs[0], inputs[1]);
+        /* Jaccard should be between 0 and 1 */
+        if (jaccard < 0.0 || jaccard > 1.0) {
+            /* Invariant violation (shouldn't happen unless both empty) */
+        }
+    }
+
+    /* Cleanup */
+    bitmap_free(result);
+    for (int i = 0; i < num_inputs; i++) {
+        bitmap_free(inputs[i]);
+    }
+
+    return 0;
+}
diff --git a/tests/fuzz/fuzz_bitmap_serialization.c b/tests/fuzz/fuzz_bitmap_serialization.c
new file mode 100644
--- /dev/null
+++ b/tests/fuzz/fuzz_bitmap_serialization.c
@@ -0,0 +1,289 @@
+/*
+ * Fuzzer for Bitmap Serialization and Parsing
+ *
+ * This fuzzer focuses on data conversion and parsing operations:
+ * - from_int_array / get_int_array
+ * - from_bit_array / get_bit_array
+ * - Range operations
+ * - Malformed inputs and edge cases
+ */
+
+#include "fuzz_common.h"
+
+/* Test types for serialization fuzzer */
+enum SerializationTestType {
+    TEST_INTARRAY_32 = 0,
+    TEST_INTARRAY_64,
+    TEST_BITARRAY_32,
+    TEST_BITARRAY_64,
+    TEST_RANGE_32,
+    TEST_RANGE_64,
+    NUM_SERIALIZATION_TESTS
+};
+
+int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
+    if (size < 2) {
+        return 0;
+    }
+
+    FuzzInput input;
+    fuzz_input_init(&input, data, size);
+
+    uint8_t test_type = fuzz_consume_u8(&input) % NUM_SERIALIZATION_TESTS;
+
+    switch (test_type) {
+        case TEST_INTARRAY_32:
+            {
+                size_t array_size = fuzz_consume_size_in_range(&input, 0, MAX_ARRAY_SIZE);
+                if (array_size == 0) break;
+
+                uint32_t* array = (uint32_t*)malloc(sizeof(uint32_t) * array_size);
+                if (!array) break;
+
+                /* Fill with fuzz data */
+                for (size_t i = 0; i < array_size && fuzz_input_remaining(&input) >= 4; i++) {
+                    array[i] = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                }
+
+                /* Create bitmap from array */
+                Bitmap* bitmap = bitmap_from_int_array(array_size, array);
+                if (bitmap) {
+                    /* Get array back */
+                    size_t result_size;
+                    uint32_t* result = bitmap_get_int_array(bitmap, &result_size);
+
+                    if (result) {
+                        /* Verify cardinality matches result size */
+                        uint64_t cardinality = bitmap_get_cardinality(bitmap);
+                        if (cardinality != result_size) {
+                            /* Invariant violation */
+                        }
+
+                        /* Try range operations */
+                        if (result_size > 0) {
+                            size_t start = fuzz_consume_size_in_range(&input, 0, result_size);
+                            size_t end = fuzz_consume_size_in_range(&input, start, result_size + 10);
+                            size_t range_count;
+                            uint32_t* range_result = bitmap_range_int_array(bitmap, start, end, &range_count);
+                            safe_free(range_result);
+                        }
+
+                        safe_free(result);
+                    }
+
+                    bitmap_free(bitmap);
+                }
+
+                safe_free(array);
+            }
+            break;
+
+        case TEST_INTARRAY_64:
+            {
+                size_t array_size = fuzz_consume_size_in_range(&input, 0, MAX_ARRAY_SIZE);
+                if (array_size == 0) break;
+
+                uint64_t* array = (uint64_t*)malloc(sizeof(uint64_t) * array_size);
+                if (!array) break;
+
+                /* Fill with fuzz data */
+                for (size_t i = 0; i < array_size && fuzz_input_remaining(&input) >= 8; i++) {
+                    array[i] = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                }
+
+                /* Create bitmap from array */
+                Bitmap64* bitmap = bitmap64_from_int_array(array_size, array);
+                if (bitmap) {
+                    /* Get array back */
+                    uint64_t result_size;
+                    uint64_t* result = bitmap64_get_int_array(bitmap, &result_size);
+
+                    if (result) {
+                        /* Verify cardinality */
+                        uint64_t cardinality = bitmap64_get_cardinality(bitmap);
+                        if (cardinality != result_size) {
+                            /* Invariant violation */
+                        }
+
+                        /* Try range operations */
+                        if (result_size > 0) {
+                            uint64_t start = fuzz_consume_u64_in_range(&input, 0, result_size);
+                            uint64_t end = fuzz_consume_u64_in_range(&input, start, result_size + 10);
+                            uint64_t range_count;
+                            uint64_t* range_result = bitmap64_range_int_array(bitmap, start, end, &range_count);
+                            safe_free(range_result);
+                        }
+
+                        safe_free(result);
+                    }
+
+                    bitmap64_free(bitmap);
+                }
+
+                safe_free(array);
+            }
+            break;
+
+        case TEST_BITARRAY_32:
+            {
+                size_t bit_size = fuzz_consume_size_in_range(&input, 0, MAX_ARRAY_SIZE);
+                if (bit_size == 0) break;
+
+                char* bit_array = (char*)malloc(bit_size + 1);
+                if (!bit_array) break;
+
+                /* Fill with potentially invalid characters */
+                for (size_t i = 0; i < bit_size && fuzz_input_remaining(&input) > 0; i++) {
+                    uint8_t choice = fuzz_consume_u8(&input) % 10;
+                    if (choice < 4) {
+                        bit_array[i] = '0';
+                    } else if (choice < 8) {
+                        bit_array[i] = '1';
+                    } else {
+                        /* Inject some invalid characters */
+                        bit_array[i] = (char)fuzz_consume_u8(&input);
+                    }
+                }
+                bit_array[bit_size] = '\0';
+
+                /* Try to create bitmap (should handle invalid input gracefully) */
+                Bitmap* bitmap = bitmap_from_bit_array(bit_size, bit_array);
+                if (bitmap) {
+                    /* Try to get bit array back */
+                    /* Only get bit array if max value is reasonable */
+                    if (!bitmap_is_empty(bitmap)) {
+                        uint32_t max_val = bitmap_max(bitmap);
+                        if (max_val < MAX_BIT_OFFSET_32) {
+                            size_t result_size;
+                            char* result = bitmap_get_bit_array(bitmap, &result_size);
+
+                            if (result) {
+                                /* Result should only contain '0' and '1' */
+                                for (size_t i = 0; i < result_size; i++) {
+                                    if (result[i] != '0' && result[i] != '1') {
+                                        /* Invalid output */
+                                    }
+                                }
+                                bitmap_free_bit_array(result);
+                            }
+                        }
+                    }
+
+                    bitmap_free(bitmap);
+                }
+
+                safe_free(bit_array);
+            }
+            break;
+
+        case TEST_BITARRAY_64:
+            {
+                size_t bit_size = fuzz_consume_size_in_range(&input, 0, MAX_ARRAY_SIZE);
+                if (bit_size == 0) break;
+
+                char* bit_array = (char*)malloc(bit_size + 1);
+                if (!bit_array) break;
+
+                for (size_t i = 0; i < bit_size && fuzz_input_remaining(&input) > 0; i++) {
+                    uint8_t choice = fuzz_consume_u8(&input) % 10;
+                    if (choice < 4) {
+                        bit_array[i] = '0';
+                    } else if (choice < 8) {
+                        bit_array[i] = '1';
+                    } else {
+                        bit_array[i] = (char)fuzz_consume_u8(&input);
+                    }
+                }
+                bit_array[bit_size] = '\0';
+
+                Bitmap64* bitmap = bitmap64_from_bit_array(bit_size, bit_array);
+                if (bitmap) {
+                    /* Only get bit array if max value is reasonable */
+                    if (!bitmap64_is_empty(bitmap)) {
+                        uint64_t max_val = bitmap64_max(bitmap);
+                        if (max_val < MAX_BIT_OFFSET_64) {
+                            uint64_t result_size;
+                            char* result = bitmap64_get_bit_array(bitmap, &result_size);
+
+                            if (result) {
+                                for (size_t i = 0; i < result_size; i++) {
+                                    if (result[i] != '0' && result[i] != '1') {
+                                        /* Invalid output */
+                                    }
+                                }
+                                bitmap_free_bit_array(result);
+                            }
+                        }
+                    }
+
+                    bitmap64_free(bitmap);
+                }
+
+                safe_free(bit_array);
+            }
+            break;
+
+        case TEST_RANGE_32:
+            {
+                uint64_t from = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+                uint64_t to = fuzz_consume_u32_in_range(&input, 0, MAX_BIT_OFFSET_32);
+
+                /* Test various range scenarios */
+                if (from > to) {
+                    /* Reversed range */
+                    Bitmap* bitmap = bitmap_from_range(to, from);
+                    if (bitmap) {
+                        uint64_t card = bitmap_get_cardinality(bitmap);
+                        /* Should be from - to */
+                        bitmap_free(bitmap);
+                    }
+                } else if (from == to) {
+                    /* Empty or single element range */
+                    Bitmap* bitmap = bitmap_from_range(from, to);
+                    if (bitmap) {
+                        bitmap_free(bitmap);
+                    }
+                } else {
+                    /* Normal range, but limit size */
+                    if (to - from > 1000000) {
+                        to = from + 1000000;
+                    }
+                    Bitmap* bitmap = bitmap_from_range(from, to);
+                    if (bitmap) {
+                        uint64_t card = bitmap_get_cardinality(bitmap);
+                        /* Cardinality should equal range size */
+                        if (to > from && card != (to - from)) {
+                            /* Invariant check */
+                        }
+                        bitmap_free(bitmap);
+                    }
+                }
+            }
+            break;
+
+        case TEST_RANGE_64:
+            {
+                uint64_t from = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+                uint64_t to = fuzz_consume_u64_in_range(&input, 0, MAX_BIT_OFFSET_64);
+
+                if (from > to) {
+                    Bitmap64* bitmap = bitmap64_from_range(to, from);
+                    if (bitmap) {
+                        bitmap64_free(bitmap);
+                    }
+                } else {
+                    if (to - from > 1000000) {
+                        to = from + 1000000;
+                    }
+                    Bitmap64* bitmap = bitmap64_from_range(from, to);
+                    if (bitmap) {
+                        uint64_t card = bitmap64_get_cardinality(bitmap);
+                        bitmap64_free(bitmap);
+                    }
+                }
+            }
+            break;
+    }
+
+    return 0;
+}
diff --git a/tests/fuzz/fuzz_common.h b/tests/fuzz/fuzz_common.h
new file mode 100644
--- /dev/null
+++ b/tests/fuzz/fuzz_common.h
@@ -0,0 +1,262 @@
+#ifndef FUZZ_COMMON_H
+#define FUZZ_COMMON_H
+
+#include <stdint.h>
+#include <stddef.h>
+#include <stdbool.h>
+#include <string.h>
+#include <stdlib.h>
+
+#include "../../src/data-structure.h"
+
+/* Maximum number of bitmaps to maintain in fuzzer state */
+#define MAX_FUZZ_BITMAPS 5
+
+/* Maximum operations per fuzzing iteration */
+#define MAX_FUZZ_OPERATIONS 1000
+
+/* Maximum array size for int/bit arrays */
+#define MAX_ARRAY_SIZE 10000
+
+/* Maximum bit offset to prevent excessive memory usage */
+#define MAX_BIT_OFFSET_32 10000000
+#define MAX_BIT_OFFSET_64 100000000
+
+/* Maximum cardinality for expensive operations */
+#define MAX_SAFE_CARDINALITY 10000000
+
+/* Bitmap operation types for 32-bit API */
+enum BitmapOperation {
+    OP_SETBIT = 0,
+    OP_GETBIT,
+    OP_SETINTARRAY,
+    OP_GETINTARRAY,
+    OP_APPENDINTARRAY,
+    OP_RANGEINTARRAY,
+    OP_SETBITARRAY,
+    OP_GETBITARRAY,
+    OP_SETRANGE,
+    OP_BITOP_AND,
+    OP_BITOP_OR,
+    OP_BITOP_XOR,
+    OP_BITOP_NOT,
+    OP_BITOP_ANDOR,
+    OP_BITOP_ANDNOT,
+    OP_BITOP_ORNOT,
+    OP_BITOP_ONE,
+    OP_MIN,
+    OP_MAX,
+    OP_OPTIMIZE,
+    OP_STATISTICS,
+    OP_CARDINALITY,
+    OP_ISEMPTY,
+    OP_GETBITS,
+    OP_CLEARBITS,
+    OP_CLEARBITS_COUNT,
+    OP_INTERSECT,
+    OP_JACCARD,
+    OP_GET_NTH_ELEMENT,
+    OP_FREE_AND_ALLOC,
+    NUM_BITMAP_OPERATIONS
+};
+
+/* Bitmap operation types for 64-bit API */
+enum Bitmap64Operation {
+    OP64_SETBIT = 0,
+    OP64_GETBIT,
+    OP64_SETINTARRAY,
+    OP64_GETINTARRAY,
+    OP64_APPENDINTARRAY,
+    OP64_RANGEINTARRAY,
+    OP64_SETBITARRAY,
+    OP64_GETBITARRAY,
+    OP64_SETRANGE,
+    OP64_BITOP_AND,
+    OP64_BITOP_OR,
+    OP64_BITOP_XOR,
+    OP64_BITOP_NOT,
+    OP64_BITOP_ANDOR,
+    OP64_BITOP_ANDNOT,
+    OP64_BITOP_ORNOT,
+    OP64_BITOP_ONE,
+    OP64_MIN,
+    OP64_MAX,
+    OP64_OPTIMIZE,
+    OP64_STATISTICS,
+    OP64_CARDINALITY,
+    OP64_ISEMPTY,
+    OP64_GETBITS,
+    OP64_CLEARBITS,
+    OP64_CLEARBITS_COUNT,
+    OP64_INTERSECT,
+    OP64_JACCARD,
+    OP64_GET_NTH_ELEMENT,
+    OP64_FREE_AND_ALLOC,
+    NUM_BITMAP64_OPERATIONS
+};
+
+/* Simple input parser for fuzzing */
+typedef struct {
+    const uint8_t* data;
+    size_t size;
+    size_t offset;
+} FuzzInput;
+
+/* Initialize fuzzer input */
+static inline void fuzz_input_init(FuzzInput* input, const uint8_t* data, size_t size) {
+    input->data = data;
+    input->size = size;
+    input->offset = 0;
+}
+
+/* Get remaining bytes */
+static inline size_t fuzz_input_remaining(const FuzzInput* input) {
+    return input->size - input->offset;
+}
+
+/* Consume a single byte */
+static inline uint8_t fuzz_consume_u8(FuzzInput* input) {
+    if (input->offset >= input->size) {
+        return 0;
+    }
+    return input->data[input->offset++];
+}
+
+/* Consume a uint16_t */
+static inline uint16_t fuzz_consume_u16(FuzzInput* input) {
+    uint16_t result = 0;
+    for (int i = 0; i < 2 && input->offset < input->size; i++) {
+        result |= ((uint16_t)input->data[input->offset++]) << (i * 8);
+    }
+    return result;
+}
+
+/* Consume a uint32_t */
+static inline uint32_t fuzz_consume_u32(FuzzInput* input) {
+    uint32_t result = 0;
+    for (int i = 0; i < 4 && input->offset < input->size; i++) {
+        result |= ((uint32_t)input->data[input->offset++]) << (i * 8);
+    }
+    return result;
+}
+
+/* Consume a uint64_t */
+static inline uint64_t fuzz_consume_u64(FuzzInput* input) {
+    uint64_t result = 0;
+    for (int i = 0; i < 8 && input->offset < input->size; i++) {
+        result |= ((uint64_t)input->data[input->offset++]) << (i * 8);
+    }
+    return result;
+}
+
+/* Consume a bool */
+static inline bool fuzz_consume_bool(FuzzInput* input) {
+    return (fuzz_consume_u8(input) & 1) != 0;
+}
+
+/* Consume an integer in range [min, max] */
+static inline uint32_t fuzz_consume_u32_in_range(FuzzInput* input, uint32_t min, uint32_t max) {
+    if (min >= max) return min;
+    uint32_t range = max - min + 1;
+    uint32_t value = fuzz_consume_u32(input);
+    return min + (value % range);
+}
+
+/* Consume an integer in range [min, max] for uint64_t */
+static inline uint64_t fuzz_consume_u64_in_range(FuzzInput* input, uint64_t min, uint64_t max) {
+    if (min >= max) return min;
+    uint64_t range = max - min + 1;
+    uint64_t value = fuzz_consume_u64(input);
+    return min + (value % range);
+}
+
+/* Consume a size_t in range [min, max] */
+static inline size_t fuzz_consume_size_in_range(FuzzInput* input, size_t min, size_t max) {
+    if (min >= max) return min;
+    size_t range = max - min + 1;
+    size_t value = (size_t)fuzz_consume_u32(input);
+    return min + (value % range);
+}
+
+/* Helper function to safely free bitmap arrays */
+static inline void safe_free(void* ptr) {
+    if (ptr) {
+        free(ptr);
+    }
+}
+
+/* Helper to generate a random uint32 array */
+static inline uint32_t* generate_uint32_array(FuzzInput* input, size_t* out_size) {
+    size_t size = fuzz_consume_size_in_range(input, 0, MAX_ARRAY_SIZE);
+    if (size == 0) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    uint32_t* array = (uint32_t*)malloc(sizeof(uint32_t) * size);
+    if (!array) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    for (size_t i = 0; i < size; i++) {
+        array[i] = fuzz_consume_u32_in_range(input, 0, MAX_BIT_OFFSET_32);
+    }
+
+    *out_size = size;
+    return array;
+}
+
+/* Helper to generate a random uint64 array */
+static inline uint64_t* generate_uint64_array(FuzzInput* input, size_t* out_size) {
+    size_t size = fuzz_consume_size_in_range(input, 0, MAX_ARRAY_SIZE);
+    if (size == 0) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    uint64_t* array = (uint64_t*)malloc(sizeof(uint64_t) * size);
+    if (!array) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    for (size_t i = 0; i < size; i++) {
+        array[i] = fuzz_consume_u64_in_range(input, 0, MAX_BIT_OFFSET_64);
+    }
+
+    *out_size = size;
+    return array;
+}
+
+/* Helper to generate a random bit array string */
+static inline char* generate_bit_array_string(FuzzInput* input, size_t* out_size) {
+    size_t size = fuzz_consume_size_in_range(input, 0, MAX_ARRAY_SIZE);
+    if (size == 0) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    char* array = (char*)malloc(size + 1);
+    if (!array) {
+        *out_size = 0;
+        return NULL;
+    }
+
+    for (size_t i = 0; i < size; i++) {
+        /* Generate '0' or '1' characters */
+        array[i] = fuzz_consume_bool(input) ? '1' : '0';
+    }
+    array[size] = '\0';
+
+    *out_size = size;
+    return array;
+}
+
+/* Helper to select a random valid bitmap index */
+static inline int select_bitmap_index(FuzzInput* input, int num_bitmaps) {
+    if (num_bitmaps <= 0) return 0;
+    return (int)fuzz_consume_u32_in_range(input, 0, num_bitmaps - 1);
+}
+
+#endif /* FUZZ_COMMON_H */
diff --git a/tests/unit/test_bitmap_and.c b/tests/unit/test_bitmap_and.c
--- a/tests/unit/test_bitmap_and.c
+++ b/tests/unit/test_bitmap_and.c
@@ -47,5 +47,36 @@ void test_bitmap_and() {
 
       roaring_bitmap_free(result);
     }
+
+    IT("Should handle result bitmap appearing in input array (regression test for memcpy-param-overlap)")
+    {
+      // This is a regression test for the memcpy-param-overlap bug found by fuzzing
+      // The bug occurred when the result bitmap pointer appeared in the input array,
+      // causing inplace operations to trigger memcpy overlap with shared containers
+
+      Bitmap* bitmap1 = bitmap_alloc();
+      bitmap_setbit(bitmap1, 1, 1);
+      bitmap_setbit(bitmap1, 10, 1);
+      bitmap_setbit(bitmap1, 100, 1);
+
+      Bitmap* bitmap2 = bitmap_alloc();
+      bitmap_setbit(bitmap2, 10, 1);
+      bitmap_setbit(bitmap2, 100, 1);
+      bitmap_setbit(bitmap2, 200, 1);
+
+      // Use bitmap1 as both the result and one of the inputs
+      const Bitmap* bitmaps[] = { bitmap1, bitmap2 };
+      bitmap_and(bitmap1, 2, bitmaps);
+
+      // Verify the result contains only common bits
+      ASSERT(bitmap_getbit(bitmap1, 1) == 0, "bitmap1 should not contain bit 1");
+      ASSERT(bitmap_getbit(bitmap1, 10) == 1, "bitmap1 should contain bit 10");
+      ASSERT(bitmap_getbit(bitmap1, 100) == 1, "bitmap1 should contain bit 100");
+      ASSERT(bitmap_getbit(bitmap1, 200) == 0, "bitmap1 should not contain bit 200");
+      ASSERT_BITMAP_SIZE(2, bitmap1);
+
+      bitmap_free(bitmap1);
+      bitmap_free(bitmap2);
+    }
   }
 }
diff --git a/tests/unit/test_bitmap_andor.c b/tests/unit/test_bitmap_andor.c
--- a/tests/unit/test_bitmap_andor.c
+++ b/tests/unit/test_bitmap_andor.c
@@ -250,5 +250,41 @@ void test_bitmap_andor() {
       roaring_bitmap_free(bitmap2_copy);
       roaring_bitmap_free(result);
     }
+
+    IT("Should handle result bitmap appearing in input array (regression test for memcpy-param-overlap)")
+    {
+      // This is a regression test for the memcpy-param-overlap bug found by fuzzing
+      // The bug occurred when the result bitmap pointer appeared in the input array,
+      // causing inplace operations to trigger memcpy overlap with shared containers
+      // This was the specific operation that triggered the fuzzer crash
+
+      uint32_t values1[] = { 1, 2, 3, 10, 20 };
+      Bitmap* bitmap1 = roaring_bitmap_of_ptr(ARRAY_LENGTH(values1), values1);
+
+      uint32_t values2[] = { 2, 3, 4, 10, 30 };
+      Bitmap* bitmap2 = roaring_bitmap_of_ptr(ARRAY_LENGTH(values2), values2);
+
+      uint32_t values3[] = { 3, 4, 5, 10, 40 };
+      Bitmap* bitmap3 = roaring_bitmap_of_ptr(ARRAY_LENGTH(values3), values3);
+
+      // Use bitmap1 as both the result and one of the inputs
+      const Bitmap* bitmaps[] = { bitmap1, bitmap2, bitmap3 };
+      bitmap_andor(bitmap1, 3, bitmaps);
+
+      // Expected: bitmap1 AND (bitmap2 OR bitmap3)
+      // bitmap2 OR bitmap3 = {2, 3, 4, 5, 10, 30, 40}
+      // bitmap1 AND {2, 3, 4, 5, 10, 30, 40} = {2, 3, 10}
+      ASSERT(bitmap_getbit(bitmap1, 1) == 0, "bitmap1 should not contain bit 1");
+      ASSERT(bitmap_getbit(bitmap1, 2) == 1, "bitmap1 should contain bit 2");
+      ASSERT(bitmap_getbit(bitmap1, 3) == 1, "bitmap1 should contain bit 3");
+      ASSERT(bitmap_getbit(bitmap1, 4) == 0, "bitmap1 should not contain bit 4");
+      ASSERT(bitmap_getbit(bitmap1, 10) == 1, "bitmap1 should contain bit 10");
+      ASSERT(bitmap_getbit(bitmap1, 20) == 0, "bitmap1 should not contain bit 20");
+      ASSERT_BITMAP_SIZE(3, bitmap1);
+
+      roaring_bitmap_free(bitmap1);
+      roaring_bitmap_free(bitmap2);
+      roaring_bitmap_free(bitmap3);
+    }
   }
 }
diff --git a/tests/unit/test_bitmap_or.c b/tests/unit/test_bitmap_or.c
--- a/tests/unit/test_bitmap_or.c
+++ b/tests/unit/test_bitmap_or.c
@@ -46,5 +46,38 @@ void test_bitmap_or() {
 
       roaring_bitmap_free(result);
     }
+
+    IT("Should handle result bitmap appearing in input array (regression test for memcpy-param-overlap)")
+    {
+      // This is a regression test for the memcpy-param-overlap bug found by fuzzing
+      // The bug occurred when the result bitmap pointer appeared in the input array,
+      // causing inplace operations to trigger memcpy overlap with shared containers
+
+      Bitmap* bitmap1 = bitmap_alloc();
+      bitmap_setbit(bitmap1, 1, 1);
+      bitmap_setbit(bitmap1, 10, 1);
+      bitmap_setbit(bitmap1, 100, 1);
+
+      Bitmap* bitmap2 = bitmap_alloc();
+      bitmap_setbit(bitmap2, 2, 1);
+      bitmap_setbit(bitmap2, 20, 1);
+      bitmap_setbit(bitmap2, 200, 1);
+
+      // Use bitmap1 as both the result and one of the inputs
+      const Bitmap* bitmaps[] = { bitmap1, bitmap2 };
+      bitmap_or(bitmap1, 2, bitmaps);
+
+      // Verify the result contains all bits from both bitmaps
+      ASSERT(bitmap_getbit(bitmap1, 1) == 1, "bitmap1 should contain bit 1");
+      ASSERT(bitmap_getbit(bitmap1, 2) == 1, "bitmap1 should contain bit 2");
+      ASSERT(bitmap_getbit(bitmap1, 10) == 1, "bitmap1 should contain bit 10");
+      ASSERT(bitmap_getbit(bitmap1, 20) == 1, "bitmap1 should contain bit 20");
+      ASSERT(bitmap_getbit(bitmap1, 100) == 1, "bitmap1 should contain bit 100");
+      ASSERT(bitmap_getbit(bitmap1, 200) == 1, "bitmap1 should contain bit 200");
+      ASSERT_BITMAP_SIZE(6, bitmap1);
+
+      bitmap_free(bitmap1);
+      bitmap_free(bitmap2);
+    }
   }
 }
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
# The test files are compiled into the ./build/unit binary
cd /testbed/build
cmake .. && make -j4

# Return to testbed root
cd /testbed

# Run unit tests with valgrind
# Note: All unit tests run together as a single binary, including our target tests:
# - test_bitmap_and() from tests/unit/test_bitmap_and.c
# - test_bitmap_andor() from tests/unit/test_bitmap_andor.c  
# - test_bitmap_or() from tests/unit/test_bitmap_or.c
echo "=== Running unit tests (including target test files) ==="
valgrind --leak-check=full --error-exitcode=1 ./build/unit
rc=$?

echo "=== Test Results ==="
echo "Unit tests exit code: $rc"

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 12288bcd72b1b264e90142af4f1efa1c3c511015 "tests/unit/test_bitmap_and.c" "tests/unit/test_bitmap_andor.c" "tests/unit/test_bitmap_or.c"