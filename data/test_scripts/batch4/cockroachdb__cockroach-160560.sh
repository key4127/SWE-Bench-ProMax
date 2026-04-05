#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ab117cbd0164f79e99d6e8668a1eb80cadf72b93 "pkg/sql/opt/optbuilder/testdata/udf"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sql/opt/optbuilder/testdata/udf b/pkg/sql/opt/optbuilder/testdata/udf
--- a/pkg/sql/opt/optbuilder/testdata/udf
+++ b/pkg/sql/opt/optbuilder/testdata/udf
@@ -1905,3 +1905,67 @@ values
                                └── tuple
                                     ├── variable: c:18
                                     └── variable: child.p:19
+
+# Regression test for #160473. An uncorrelated IN-subquery should not be built
+# as a complicated expression with a ConstructGroupByAny.
+exec-ddl
+CREATE TABLE t160473 (
+  a INT,
+  b INT,
+  c INT,
+  INDEX (a, b),
+  FAMILY (a, b, c)
+)
+----
+
+exec-ddl
+CREATE OR REPLACE FUNCTION f160473() RETURNS INT LANGUAGE SQL AS $$
+  SELECT c FROM t160473 WHERE a = 33 AND b IN (SELECT unnest(ARRAY[44, 55]::INT[]))
+$$
+----
+
+# The norm directive is necessary to simplify the unnest project-set into a
+# values expression, allowing the complicated ConstructGroupByAny to be avoided.
+norm format=show-scalars
+SELECT f160473()
+----
+values
+ ├── columns: f160473:8
+ └── tuple
+      └── udf: f160473
+           └── body
+                └── project
+                     ├── columns: c:3
+                     └── limit
+                          ├── columns: a:1!null b:2!null c:3
+                          ├── select
+                          │    ├── columns: a:1!null b:2!null c:3
+                          │    ├── scan t160473
+                          │    │    └── columns: a:1 b:2 c:3
+                          │    └── filters
+                          │         ├── eq
+                          │         │    ├── variable: a:1
+                          │         │    └── const: 33
+                          │         └── in
+                          │              ├── variable: b:2
+                          │              └── tuple
+                          │                   ├── const: 44
+                          │                   └── const: 55
+                          └── const: 1
+
+exec-ddl
+CREATE OR REPLACE FUNCTION f160473() RETURNS INT LANGUAGE SQL AS $$
+  SELECT c FROM t160473 WHERE a = 33 AND b IN (SELECT unnest(ARRAY[]::INT[]))
+$$
+----
+
+norm format=show-scalars
+SELECT f160473()
+----
+values
+ ├── columns: f160473:8
+ └── tuple
+      └── udf: f160473
+           └── body
+                └── values
+                     └── columns: c:3!null
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go
export BAZEL_REMOTE_CACHE_ENABLED=false
export GOTRACEBACK=all

# Run the optbuilder test target
# The test will automatically process the testdata/udf file through data-driven testing
bazel test \
    //pkg/sql/opt/optbuilder:optbuilder_test \
    --test_output=all \
    --config=test \
    --test_timeout=600 \
    --test_arg=-test.run=TestBuilder

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout ab117cbd0164f79e99d6e8668a1eb80cadf72b93 "pkg/sql/opt/optbuilder/testdata/udf"