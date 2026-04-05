#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ae9604c201b3ba44babc48e982e012b1d23b69c8 "gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java b/gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java
--- a/gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java
+++ b/gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java
@@ -31,5 +31,11 @@ public void testSupported() {
     assertThat(SqlTypesSupport.DATE_FACTORY).isNotNull();
     assertThat(SqlTypesSupport.TIME_FACTORY).isNotNull();
     assertThat(SqlTypesSupport.TIMESTAMP_FACTORY).isNotNull();
+    assertThat(SqlTypesSupport.SQL_TYPE_FACTORIES)
+        .containsExactly(
+            SqlTypesSupport.TIME_FACTORY,
+            SqlTypesSupport.DATE_FACTORY,
+            SqlTypesSupport.TIMESTAMP_FACTORY)
+        .inOrder();
   }
 }
EOF_114329324912

# Run the specific test file using Maven
# -Dtest=SqlTypesSupportTest targets only the specified test class
# -pl gson specifies the gson module (multi-module project)
# -Dmaven.test.failure.ignore=false ensures test failures are properly reported
mvn test -Dtest=SqlTypesSupportTest -pl gson -Dmaven.test.failure.ignore=false
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout ae9604c201b3ba44babc48e982e012b1d23b69c8 "gson/src/test/java/com/google/gson/internal/sql/SqlTypesSupportTest.java"