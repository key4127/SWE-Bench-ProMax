#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e9ca6ed6db318bf227d270f92f7894368f8f4b63 "tests/utests/extensions/test_schema_mount.c" "tests/utests/types/yang_types.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utests/extensions/test_schema_mount.c b/tests/utests/extensions/test_schema_mount.c
--- a/tests/utests/extensions/test_schema_mount.c
+++ b/tests/utests/extensions/test_schema_mount.c
@@ -1859,7 +1859,7 @@ test_xpath(void **state)
             "  </root>\n"
             "</root>\n";
     CHECK_PARSE_LYD_PARAM(xml, LYD_XML, LYD_PARSE_STRICT, LYD_VALIDATE_PRESENT, LY_EVALID, data);
-    CHECK_LOG_CTX("Ext plugin \"ly2 schema mount v1\": "
+    CHECK_LOG_CTX("Ext plugin \"ly2 schema mount\": "
             "Must condition \"/m:root/l1 = 'valid'\" not satisfied.",
             "/mount:root/l1", 0);
 
diff --git a/tests/utests/types/yang_types.c b/tests/utests/types/yang_types.c
--- a/tests/utests/types/yang_types.c
+++ b/tests/utests/types/yang_types.c
@@ -111,9 +111,8 @@ test_data_xml(void **state)
     TEST_SUCCESS_XML("a", "l", "2017-02-01T00:00:00-00:00", STRING, "2017-02-01T00:00:00-00:00");
     TEST_SUCCESS_XML("a", "l", "2021-02-29T00:00:00-00:00", STRING, "2021-03-01T00:00:00-00:00");
 
-    TEST_ERROR_XML("a", "l", "2005-05-31T23:15:15.-08:00", LY_EVALID);
-    CHECK_LOG_CTX("Unsatisfied pattern - \"2005-05-31T23:15:15.-08:00\" does not conform to "
-            "\"\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?(Z|[\\+\\-]\\d{2}:\\d{2})\".",
+    TEST_ERROR_XML("a", "l", "2005-05-31T23:15:15.-08:00", LY_EINVAL);
+    CHECK_LOG_CTX("Missing date-and-time fractions after '.'.",
             "/a:l", 1);
 
     TEST_ERROR_XML("a", "l", "2023-16-15T20:13:01+01:00", LY_EINVAL);
EOF_114329324912

# Rebuild the tests to incorporate any changes from the patch
cd /testbed/build
make -j$(nproc)

# Run the specific target tests using ctest
# Based on the CMake test framework, test executables are named with 'utest_' prefix
# The test names are derived from the source file names:
# - tests/utests/extensions/test_schema_mount.c -> utest_schema_mount
# - tests/utests/types/yang_types.c -> utest_yang_types
cd /testbed/build

ctest --output-on-failure -R "^(utest_schema_mount|utest_yang_types)$"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
cd /testbed
git checkout e9ca6ed6db318bf227d270f92f7894368f8f4b63 "tests/utests/extensions/test_schema_mount.c" "tests/utests/types/yang_types.c"