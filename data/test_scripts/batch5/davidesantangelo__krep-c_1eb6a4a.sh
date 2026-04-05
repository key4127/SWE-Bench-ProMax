#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9036d0534beb02aafe2315f2ac95a32d328bc9e4 "test/test_krep.c" "test/test_krep.h" "test/test_regex.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/test_compat.h b/test/test_compat.h
new file mode 100644
--- /dev/null
+++ b/test/test_compat.h
@@ -0,0 +1,105 @@
+/**
+ * Compatibility layer for krep tests
+ * Provides 6-parameter wrappers around 8-parameter search functions
+ */
+
+#ifndef TEST_COMPAT_H
+#define TEST_COMPAT_H
+
+#include <stdint.h>
+#include <stdbool.h>
+#include <stdlib.h>
+#include "../krep.h"
+
+#ifdef TESTING
+/* Wrapper functions with 6 parameters that call the 8-parameter versions */
+
+/* Boyer-Moore-Horspool compatibility wrapper */
+static inline uint64_t boyer_moore_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return boyer_moore_search(text, text_len, pattern, pattern_len, 
+                             case_sensitive, report_limit_offset,
+                             false, NULL);
+}
+
+/* Knuth-Morris-Pratt compatibility wrapper */
+static inline uint64_t kmp_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return kmp_search(text, text_len, pattern, pattern_len, 
+                     case_sensitive, report_limit_offset,
+                     false, NULL);
+}
+
+/* Rabin-Karp compatibility wrapper */
+static inline uint64_t rabin_karp_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return rabin_karp_search(text, text_len, pattern, pattern_len, 
+                            case_sensitive, report_limit_offset,
+                            false, NULL);
+}
+
+/* SIMD SSE4.2 compatibility wrapper */
+#ifdef __SSE4_2__
+static inline uint64_t simd_sse42_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return simd_sse42_search(text, text_len, pattern, pattern_len, 
+                            case_sensitive, report_limit_offset,
+                            false, NULL);
+}
+#endif
+
+/* AVX2 compatibility wrapper */
+#ifdef __AVX2__
+static inline uint64_t simd_avx2_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return simd_avx2_search(text, text_len, pattern, pattern_len, 
+                           case_sensitive, report_limit_offset,
+                           false, NULL);
+}
+#endif
+
+/* NEON compatibility wrapper */
+#ifdef __ARM_NEON
+static inline uint64_t neon_search_compat(
+    const char *text, size_t text_len,
+    const char *pattern, size_t pattern_len,
+    bool case_sensitive, size_t report_limit_offset)
+{
+    return neon_search(text, text_len, pattern, pattern_len, 
+                      case_sensitive, report_limit_offset,
+                      false, NULL);
+}
+#endif
+
+/* Redefine the function names to use the compatibility versions */
+#define boyer_moore_search boyer_moore_search_compat
+#define kmp_search kmp_search_compat
+#define rabin_karp_search rabin_karp_search_compat
+#ifdef __SSE4_2__
+#define simd_sse42_search simd_sse42_search_compat
+#endif
+#ifdef __AVX2__
+#define simd_avx2_search simd_avx2_search_compat
+#endif
+#ifdef __ARM_NEON
+#define neon_search neon_search_compat
+#endif
+
+#endif /* TESTING */
+
+#endif /* TEST_COMPAT_H */
diff --git a/test/test_krep.c b/test/test_krep.c
--- a/test/test_krep.c
+++ b/test/test_krep.c
@@ -15,8 +15,9 @@
 
 /* Include main krep functions for testing */
 // TESTING is defined by the Makefile when building krep_test.o
-#include "../krep.h"   // Assuming krep.h is in the parent directory
-#include "test_krep.h" // Include test header for consistency (if needed)
+#include "../krep.h"     // Assuming krep.h is in the parent directory
+#include "test_krep.h"   // Include test header for consistency (if needed)
+#include "test_compat.h" // Add this include to get the compatibility wrappers
 
 void run_regex_tests(void);
 
diff --git a/test/test_krep.h b/test/test_krep.h
--- a/test/test_krep.h
+++ b/test/test_krep.h
@@ -10,34 +10,17 @@
 #include <stdlib.h>
 #include <limits.h> // For SIZE_MAX
 
-/* Function declarations from krep.c that we need for testing */
-uint64_t boyer_moore_search(const char *text, size_t text_len,
-                            const char *pattern, size_t pattern_len,
-                            bool case_sensitive, size_t report_limit_offset);
-uint64_t kmp_search(const char *text, size_t text_len,
-                    const char *pattern, size_t pattern_len,
-                    bool case_sensitive, size_t report_limit_offset);
-uint64_t rabin_karp_search(const char *text, size_t text_len,
-                           const char *pattern, size_t pattern_len,
-                           bool case_sensitive, size_t report_limit_offset);
-
-#ifdef __SSE4_2__
-uint64_t simd_sse42_search(const char *text, size_t text_len,
-                           const char *pattern, size_t pattern_len,
-                           bool case_sensitive, size_t report_limit_offset);
-#endif
-
-#ifdef __AVX2__
-uint64_t avx2_search(const char *text, size_t text_len,
-                     const char *pattern, size_t pattern_len,
-                     bool case_sensitive, size_t report_limit_offset);
+/* Define TESTING to enable the compatibility wrappers */
+#ifndef TESTING
+#define TESTING
 #endif
 
-#ifdef __ARM_NEON
-uint64_t neon_search(const char *text, size_t text_len,
-                     const char *pattern, size_t pattern_len,
-                     bool case_sensitive, size_t report_limit_offset);
-#endif
+/*
+ * Note: We're NOT redefining the search functions here to avoid conflicts.
+ * Instead, we'll use the compatibility wrappers defined in krep.c via the
+ * TESTING define above, which will map the 6-parameter calls to the full
+ * 8-parameter implementations.
+ */
 
 /**
  * @brief Regex-based search using POSIX regular expressions.
diff --git a/test/test_regex.c b/test/test_regex.c
--- a/test/test_regex.c
+++ b/test/test_regex.c
@@ -11,6 +11,7 @@
 #include <regex.h>
 #include <inttypes.h> // Add this include for PRIu64 format specifier
 #include "../krep.h"
+#include "test_compat.h" // Add this include to get the compatibility wrappers
 
 /* External test counter references */
 extern int tests_passed;
@@ -296,9 +297,7 @@ void test_regex_report_limit(void)
                 "Regex counts 0 'apple' with limit at first match");
 }
 
-/**
- * Test regex vs literal string search performance
- */
+/* Test regex vs literal string search performance */
 void test_regex_vs_literal_performance(void)
 {
     printf("\n=== Regex vs. Literal Performance Tests ===\n");
EOF_114329324912

# Clean any previous build artifacts
make clean || true

# Run the tests using the project's test command
# The make test command compiles with -DTESTING flag and runs ./test_krep
make test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 9036d0534beb02aafe2315f2ac95a32d328bc9e4 "test/test_krep.c" "test/test_krep.h" "test/test_regex.c"

# Clean build artifacts
make clean || true