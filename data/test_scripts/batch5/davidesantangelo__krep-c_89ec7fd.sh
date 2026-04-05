#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 749f5085a66336fa7ce684244f98f0b5dd4c98cc "test/test_compat.h" "test/test_krep.c" "test/test_multiple_patterns.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/test_compat.h b/test/test_compat.h
--- a/test/test_compat.h
+++ b/test/test_compat.h
@@ -10,9 +10,10 @@
 #include <stdint.h>
 #include <stdbool.h>
 #include <stdlib.h>
-#include <limits.h>  // For SIZE_MAX
-#include <regex.h>   // For regex_t
-#include "../krep.h" // Include main header for the full function declarations
+#include <limits.h>          // For SIZE_MAX
+#include <regex.h>           // For regex_t
+#include "../krep.h"         // Include main header for the full function declarations
+#include "../aho_corasick.h" // Add this include
 
 #ifdef TESTING
 /*
diff --git a/test/test_krep.c b/test/test_krep.c
--- a/test/test_krep.c
+++ b/test/test_krep.c
@@ -79,6 +79,7 @@ static search_params_t create_base_params(const char *pattern,
     params.track_positions = !(count_lines && !only_match);
     params.compiled_regex = NULL;
     params.max_count = SIZE_MAX;
+    params.ac_trie = NULL; // Initialize to NULL
     // legacy single‐pattern fields
     params.pattern = params.patterns[0];
     params.pattern_len = params.pattern_lens[0];
@@ -147,6 +148,12 @@ void cleanup_params(search_params_t *params)
         free(params->pattern_lens);
         params->pattern_lens = NULL;
     }
+    // Free Aho-Corasick trie if allocated
+    if (params->ac_trie)
+    {
+        ac_trie_free(params->ac_trie);
+        params->ac_trie = NULL;
+    }
     // Note: Does not free ac_trie, handled separately
 }
 
@@ -810,7 +817,7 @@ void test_max_count_new(void)
 
     // --- Aho-Corasick Search (Multiple Patterns) ---
     printf("--- Aho-Corasick Search ---\n");
-    const char *ac_text = "apple banana apple orange apple grape apple";
+    const char *ac_text = "apple banana apple orange apple banana orange apple orange";
     size_t ac_text_len = strlen(ac_text);
     const char *ac_patterns[] = {"apple", "orange"};
     size_t ac_pattern_lens[] = {5, 6};
@@ -824,31 +831,50 @@ void test_max_count_new(void)
         .count_lines_mode = false,
         .count_matches_mode = false,
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX // Default
+        .max_count = SIZE_MAX, // Default
+        .ac_trie = NULL        // Initialize to NULL
     };
 
+    // Build trie before using it
+    params_ac.ac_trie = ac_trie_build(&params_ac);
+    if (!params_ac.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in max_count test\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
+
+    // Test with max_count = 3
     params_ac.max_count = 3;
     result = match_result_init(10);
-    TEST_ASSERT(aho_corasick_search(&params_ac, ac_text, ac_text_len, result) == 3, "Aho-Corasick finds 3 matches with limit 3");
+    TEST_ASSERT(aho_corasick_search(&params_ac, ac_text, ac_text_len, result) == 3,
+                "Aho-Corasick finds 3 matches with limit 3");
     TEST_ASSERT(result->count == 3, "Aho-Corasick result has 3 positions with limit 3");
     match_result_free(result);
     result = NULL;
 
-    params_ac.max_count = 5; // Total matches are 4 'apple' + 1 'orange' = 5
+    // Test with max_count = 5
+    params_ac.max_count = 5; // There are 7 total matches (4 apple, 3 orange)
     result = match_result_init(10);
-    TEST_ASSERT(aho_corasick_search(&params_ac, ac_text, ac_text_len, result) == 5, "Aho-Corasick finds 5 matches with limit 5");
+    TEST_ASSERT(aho_corasick_search(&params_ac, ac_text, ac_text_len, result) == 5,
+                "Aho-Corasick finds 5 matches with limit 5");
     TEST_ASSERT(result->count == 5, "Aho-Corasick result has 5 positions with limit 5");
     match_result_free(result);
     result = NULL;
 
+    // Test with max_count = 6 (should find 6 matches)
     params_ac.max_count = 6;
     result = match_result_init(10);
-    TEST_ASSERT(aho_corasick_search(&params_ac, ac_text, ac_text_len, result) == 5, "Aho-Corasick finds 5 matches with limit 6");
-    TEST_ASSERT(result->count == 5, "Aho-Corasick result has 5 positions with limit 6");
+    uint64_t matches_with_limit_6 = aho_corasick_search(&params_ac, ac_text, ac_text_len, result);
+    TEST_ASSERT(matches_with_limit_6 == 6, // Expect 6 matches
+                "Aho-Corasick finds 6 matches with limit 6");
+    TEST_ASSERT(result->count == 6, // Expect 6 positions
+                "Aho-Corasick result has 6 positions with limit 6");
     match_result_free(result);
     result = NULL;
 
-    // No cleanup_params needed for stack-allocated params_ac
+    // Free the trie
+    ac_trie_free(params_ac.ac_trie);
 }
 
 /**
@@ -927,21 +953,38 @@ void test_additional_cases(void)
 
     // --- Multiple patterns (Aho-Corasick) ---
     {
-        const char *text = "foo bar baz foo bar";
-        const char *ac_patterns[] = {"foo", "bar"};
-        size_t ac_pattern_lens[] = {3, 3};
-        search_params_t params = {
-            .patterns = ac_patterns,
-            .pattern_lens = ac_pattern_lens,
+        const char *ac_multipattern_text = "foo bar baz foo qux bar";
+        const char *multi_patterns[] = {"foo", "bar"};
+        size_t multi_lens[] = {3, 3};
+        search_params_t params_multi = {
+            .patterns = multi_patterns,
+            .pattern_lens = multi_lens,
             .num_patterns = 2,
             .case_sensitive = true,
             .use_regex = false,
             .track_positions = false,
             .count_lines_mode = false,
-            .count_matches_mode = false,
+            .count_matches_mode = true,
             .compiled_regex = NULL,
-            .max_count = SIZE_MAX};
-        TEST_ASSERT(aho_corasick_search(&params, text, strlen(text), NULL) == 4, "Aho-Corasick: finds all 'foo' and 'bar'");
+            .max_count = SIZE_MAX,
+            .ac_trie = NULL // Initialize to NULL
+        };
+
+        // Build trie before using it
+        params_multi.ac_trie = ac_trie_build(&params_multi);
+        if (!params_multi.ac_trie)
+        {
+            printf("✗ FAIL: Failed to build Aho-Corasick trie in edge case test\n");
+            tests_failed++;
+        }
+        else
+        {
+            TEST_ASSERT(
+                aho_corasick_search(&params_multi, ac_multipattern_text, strlen(ac_multipattern_text), NULL) == 4,
+                "Aho-Corasick: finds all 'foo' and 'bar'");
+            // Free the trie
+            ac_trie_free(params_multi.ac_trie);
+        }
     }
 
     // --- Binary data (should not match printable pattern) ---
diff --git a/test/test_multiple_patterns.c b/test/test_multiple_patterns.c
--- a/test/test_multiple_patterns.c
+++ b/test/test_multiple_patterns.c
@@ -8,6 +8,8 @@
 #include <stdbool.h>
 #include <time.h>
 #include <inttypes.h> // Add this include for PRIu64 macro
+#include <assert.h>
+#include <stdint.h> // For uint64_t
 
 /* Define TESTING for test builds */
 #ifndef TESTING
@@ -47,6 +49,7 @@ void test_aho_corasick_case_insensitive(void);
 void test_aho_corasick_edge_cases(void);
 void test_position_tracking_multipattern(void);
 void test_multipattern_performance(void);
+void test_multiple_patterns_performance(void);
 
 /**
  * Test basic Aho-Corasick functionality
@@ -72,7 +75,17 @@ void test_basic_aho_corasick(void)
         .count_lines_mode = false,  // Count matches
         .count_matches_mode = true, // Indicate intent
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params.ac_trie = ac_trie_build(&params);
+    if (!params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in basic test\n");
+        tests_failed++;
+        return; // Cannot proceed without trie
+    }
 
     // Call aho_corasick_search with the params struct
     uint64_t matches = aho_corasick_search(&params, text, text_len, NULL);
@@ -85,6 +98,9 @@ void test_basic_aho_corasick(void)
     size_t text2_len = strlen(text2);
     matches = aho_corasick_search(&params, text2, text2_len, NULL);
     TEST_ASSERT(matches == 0, "Aho-Corasick finds 0 matches in 'xyz'");
+
+    // Free the trie
+    ac_trie_free(params.ac_trie);
 }
 
 /**
@@ -111,14 +127,27 @@ void test_aho_corasick_case_insensitive(void)
         .count_lines_mode = false,  // Count matches
         .count_matches_mode = true, // Indicate intent
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params.ac_trie = ac_trie_build(&params);
+    if (!params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in case-insensitive test (1)\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
 
     // Call aho_corasick_search with the params struct
     uint64_t matches = aho_corasick_search(&params, text, text_len, NULL);
 
     // Expected matches: "he" (at index 1), "she" (at index 0), "hers" (at index 2)
     TEST_ASSERT(matches == 3, "Aho-Corasick finds 3 matches case-insensitively in 'UsHeRs'");
 
+    // Free the trie
+    ac_trie_free(params.ac_trie);
+
     // Test with different casing in patterns
     const char *patterns2[] = {"HE", "SHE", "HIS", "HERS"};
     search_params_t params2 = {
@@ -131,10 +160,23 @@ void test_aho_corasick_case_insensitive(void)
         .count_lines_mode = false,
         .count_matches_mode = true,
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params2.ac_trie = ac_trie_build(&params2);
+    if (!params2.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in case-insensitive test (2)\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
 
     matches = aho_corasick_search(&params2, text, text_len, NULL);
     TEST_ASSERT(matches == 3, "Aho-Corasick finds 3 matches case-insensitively with uppercase patterns");
+
+    // Free the trie
+    ac_trie_free(params2.ac_trie);
 }
 
 /**
@@ -161,7 +203,17 @@ void test_aho_corasick_edge_cases(void)
         .count_lines_mode = false,  // Count matches
         .count_matches_mode = true, // Indicate intent
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params.ac_trie = ac_trie_build(&params);
+    if (!params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in edge case test (overlapping)\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
 
     // Call aho_corasick_search with the params struct
     uint64_t matches = aho_corasick_search(&params, text, text_len, NULL);
@@ -172,6 +224,9 @@ void test_aho_corasick_edge_cases(void)
     matches = aho_corasick_search(&params, "", 0, NULL);
     TEST_ASSERT(matches == 0, "Aho-Corasick finds 0 matches in empty text");
 
+    // Free the trie
+    ac_trie_free(params.ac_trie);
+
     // Test empty patterns list
     search_params_t params_empty = {
         .patterns = NULL,
@@ -183,10 +238,18 @@ void test_aho_corasick_edge_cases(void)
         .count_lines_mode = false,
         .count_matches_mode = true,
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params_empty.ac_trie = ac_trie_build(&params_empty);
+
     matches = aho_corasick_search(&params_empty, text, text_len, NULL);
     TEST_ASSERT(matches == 0, "Aho-Corasick finds 0 matches with empty pattern list");
 
+    // Free the trie
+    ac_trie_free(params_empty.ac_trie);
+
     // Test patterns longer than text
     const char *patterns_long[] = {"abcd", "abcde"};
     size_t pattern_lens_long[] = {4, 5};
@@ -200,9 +263,23 @@ void test_aho_corasick_edge_cases(void)
         .count_lines_mode = false,
         .count_matches_mode = true,
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params_long.ac_trie = ac_trie_build(&params_long);
+    if (!params_long.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in edge case test (long patterns)\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
+
     matches = aho_corasick_search(&params_long, text, text_len, NULL);
     TEST_ASSERT(matches == 0, "Aho-Corasick finds 0 matches when patterns are longer than text");
+
+    // Free the trie
+    ac_trie_free(params_long.ac_trie);
 }
 
 /**
@@ -229,13 +306,24 @@ void test_position_tracking_multipattern(void)
         .count_lines_mode = false,
         .count_matches_mode = false,
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params.ac_trie = ac_trie_build(&params);
+    if (!params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in position tracking test\n");
+        tests_failed++;
+        return; // Cannot proceed
+    }
 
     // Create result structure to collect positions
     match_result_t *result = match_result_init(10);
     if (!result)
     {
         fprintf(stderr, "Failed to create match_result in position tracking test\n");
+        ac_trie_free(params.ac_trie);
         return;
     }
 
@@ -248,6 +336,7 @@ void test_position_tracking_multipattern(void)
 
     // Clean up
     match_result_free(result);
+    ac_trie_free(params.ac_trie);
 }
 
 /**
@@ -332,7 +421,18 @@ void test_multipattern_performance(void)
         .count_lines_mode = false,  // Don't count lines
         .count_matches_mode = true, // Indicate intent to count matches
         .compiled_regex = NULL,
-        .max_count = SIZE_MAX};
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    // Build the trie
+    params.ac_trie = ac_trie_build(&params);
+    if (!params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in performance test\n");
+        tests_failed++;
+        free(text);
+        return; // Cannot proceed
+    }
 
     // Call the actual aho_corasick_search function
     uint64_t matches_combined = aho_corasick_search(&params, text, text_size, NULL);
@@ -366,9 +466,130 @@ void test_multipattern_performance(void)
                 "Both search methods found the same number of matches");
 
     // Cleanup
+    ac_trie_free(params.ac_trie);
     free(text);
 }
 
+/**
+ * Test for performance comparison between individual searches and combined search
+ */
+void test_multiple_patterns_performance(void)
+{
+    printf("\n=== Multiple Pattern Performance Test ===\n");
+
+    // Create a large text (1 MB)
+    const size_t TEXT_SIZE = 1 * 1024 * 1024;
+    char *large_text = malloc(TEXT_SIZE + 1);
+    if (!large_text)
+    {
+        fprintf(stderr, "Failed to allocate memory for large text\n");
+        return;
+    }
+
+    // Fill with random printable ASCII
+    for (size_t i = 0; i < TEXT_SIZE; i++)
+    {
+        large_text[i] = ' ' + (rand() % 95); // ASCII 32-126
+    }
+    large_text[TEXT_SIZE] = '\0';
+
+    // Insert known patterns at random positions
+    const char *patterns[] = {
+        "pattern1", "pattern2", "pattern3", "pattern4", "pattern5"};
+    const size_t NUM_PATTERNS = sizeof(patterns) / sizeof(patterns[0]);
+    const size_t NUM_INSERTIONS = 10; // Insert each pattern 10 times
+
+    for (size_t p = 0; p < NUM_PATTERNS; p++)
+    {
+        size_t pattern_len = strlen(patterns[p]);
+        for (size_t i = 0; i < NUM_INSERTIONS; i++)
+        {
+            size_t pos = rand() % (TEXT_SIZE - pattern_len);
+            memcpy(large_text + pos, patterns[p], pattern_len);
+        }
+    }
+
+    // Measure individual search time
+    double start_time = (double)clock() / CLOCKS_PER_SEC;
+    uint64_t individual_total = 0;
+
+    for (size_t p = 0; p < NUM_PATTERNS; p++)
+    {
+        search_params_t params = {
+            .pattern = patterns[p],
+            .pattern_len = strlen(patterns[p]),
+            .case_sensitive = true,
+            .use_regex = false,
+            .track_positions = false,
+            .count_lines_mode = false,
+            .count_matches_mode = true,
+            .compiled_regex = NULL,
+            .max_count = SIZE_MAX};
+        individual_total += boyer_moore_search(&params, large_text, TEXT_SIZE, NULL);
+    }
+
+    double individual_time = (double)clock() / CLOCKS_PER_SEC - start_time;
+
+    // Create combined search params
+    search_params_t multi_params = {
+        .patterns = patterns,
+        .pattern_lens = malloc(NUM_PATTERNS * sizeof(size_t)),
+        .num_patterns = NUM_PATTERNS,
+        .case_sensitive = true,
+        .use_regex = false,
+        .track_positions = false,
+        .count_lines_mode = false,
+        .count_matches_mode = true,
+        .compiled_regex = NULL,
+        .max_count = SIZE_MAX,
+        .ac_trie = NULL};
+
+    for (size_t p = 0; p < NUM_PATTERNS; p++)
+    {
+        multi_params.pattern_lens[p] = strlen(patterns[p]);
+    }
+
+    // Build the trie
+    multi_params.ac_trie = ac_trie_build(&multi_params);
+    if (!multi_params.ac_trie)
+    {
+        printf("✗ FAIL: Failed to build Aho-Corasick trie in multiple patterns performance test\n");
+        tests_failed++;
+        free(multi_params.pattern_lens);
+        free(large_text);
+        return; // Cannot proceed
+    }
+
+    // Measure combined search time
+    start_time = (double)clock() / CLOCKS_PER_SEC;
+    uint64_t combined_total = aho_corasick_search(&multi_params, large_text, TEXT_SIZE, NULL);
+    double combined_time = (double)clock() / CLOCKS_PER_SEC - start_time;
+
+    // Report results
+    printf("Testing with 1 MB text and 5 patterns...\n");
+    printf("  Individual searches: %" PRIu64 " matches in %.6f seconds\n",
+           individual_total, individual_time);
+    printf("  Combined search: %" PRIu64 " matches in %.6f seconds\n",
+           combined_total, combined_time);
+
+    if (combined_time > 0)
+    {
+        printf("  Speed improvement: %.2fx\n", individual_time / combined_time);
+    }
+    else
+    {
+        printf("  Combined search too fast to calculate ratio.\n");
+    }
+
+    TEST_ASSERT(combined_total == individual_total,
+                "Both search methods found the same number of matches");
+
+    // Cleanup
+    ac_trie_free(multi_params.ac_trie);
+    free(multi_params.pattern_lens);
+    free(large_text);
+}
+
 /**
  * Run all multiple pattern tests
  */
@@ -381,6 +602,7 @@ void run_multiple_patterns_tests(void)
     test_aho_corasick_edge_cases();
     test_position_tracking_multipattern();
     test_multipattern_performance();
+    test_multiple_patterns_performance();
 
     printf("\n--- Completed Multiple Pattern Tests ---\n");
 }
EOF_114329324912

# Clean any previous build artifacts
make clean || true

# Run the tests using the project's test command
# The make test command compiles with -DTESTING flag and runs ./krep_test
make test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 749f5085a66336fa7ce684244f98f0b5dd4c98cc "test/test_compat.h" "test/test_krep.c" "test/test_multiple_patterns.c"

# Clean build artifacts
make clean || true