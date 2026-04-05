#!/bin/bash
set -uxo pipefail
cd /testbed

# Configure git to trust the /testbed directory
git config --global --add safe.directory /testbed

# Checkout the target test files to ensure clean state
git checkout 47851058f5b464b842393b403aa677029219cd98 "pkg/cmd/roachtest/tests/import.go" "pkg/sql/opt/norm/testdata/rules/comp"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/roachtest/tests/import.go b/pkg/cmd/roachtest/tests/import.go
--- a/pkg/cmd/roachtest/tests/import.go
+++ b/pkg/cmd/roachtest/tests/import.go
@@ -328,7 +328,8 @@ func registerImport(r registry.Registry) {
 			suites = registry.ManualOnly
 		}
 
-		for _, distMerge := range []bool{false, true} {
+		// TODO(#159956): unskip distMerge=true.
+		for _, distMerge := range []bool{false} {
 			for _, numNodes := range testSpec.nodes {
 				ts := testSpec
 				numNodes := numNodes
diff --git a/pkg/sql/opt/norm/testdata/rules/comp b/pkg/sql/opt/norm/testdata/rules/comp
--- a/pkg/sql/opt/norm/testdata/rules/comp
+++ b/pkg/sql/opt/norm/testdata/rules/comp
@@ -1196,3 +1196,71 @@ project
  │    └── columns: s:4
  └── projections
       └── s:4 LIKE s:4 [as="?column?":12, outer=(4)]
+
+# --------------------------------------------------
+# ConvertLevenshteinToLevenshteinLessEqual
+# --------------------------------------------------
+
+norm expect=ConvertLevenshteinToLevenshteinLessEqualLeft
+SELECT
+  levenshtein(s, j::STRING) = 5,
+  levenshtein(s, j::STRING) < 5,
+  levenshtein(s, j::STRING) > 5,
+  levenshtein(s, j::STRING) <= 5,
+  levenshtein(s, j::STRING) >= 5
+FROM a
+----
+project
+ ├── columns: "?column?":12 "?column?":13 "?column?":14 "?column?":15 "?column?":16
+ ├── immutable
+ ├── scan a
+ │    └── columns: s:4 j:5
+ └── projections
+      ├── levenshtein_less_equal(s:4, j:5::STRING, 5) = 5 [as="?column?":12, outer=(4,5), immutable]
+      ├── levenshtein_less_equal(s:4, j:5::STRING, 5) < 5 [as="?column?":13, outer=(4,5), immutable]
+      ├── levenshtein_less_equal(s:4, j:5::STRING, 5) > 5 [as="?column?":14, outer=(4,5), immutable]
+      ├── levenshtein_less_equal(s:4, j:5::STRING, 5) <= 5 [as="?column?":15, outer=(4,5), immutable]
+      └── levenshtein_less_equal(s:4, j:5::STRING, 5) >= 5 [as="?column?":16, outer=(4,5), immutable]
+
+norm expect=ConvertLevenshteinToLevenshteinLessEqualRight
+SELECT
+  levenshtein(s, j::STRING) = i,
+  levenshtein(s, j::STRING) < i,
+  levenshtein(s, j::STRING) > i,
+  levenshtein(s, j::STRING) <= i,
+  levenshtein(s, j::STRING) >= i
+FROM a
+----
+project
+ ├── columns: "?column?":12 "?column?":13 "?column?":14 "?column?":15 "?column?":16
+ ├── immutable
+ ├── scan a
+ │    └── columns: i:2 s:4 j:5
+ └── projections
+      ├── i:2 = levenshtein_less_equal(s:4, j:5::STRING, i:2) [as="?column?":12, outer=(2,4,5), immutable]
+      ├── i:2 > levenshtein_less_equal(s:4, j:5::STRING, i:2) [as="?column?":13, outer=(2,4,5), immutable]
+      ├── i:2 < levenshtein_less_equal(s:4, j:5::STRING, i:2) [as="?column?":14, outer=(2,4,5), immutable]
+      ├── i:2 >= levenshtein_less_equal(s:4, j:5::STRING, i:2) [as="?column?":15, outer=(2,4,5), immutable]
+      └── i:2 <= levenshtein_less_equal(s:4, j:5::STRING, i:2) [as="?column?":16, outer=(2,4,5), immutable]
+
+norm expect-not=(ConvertLevenshteinToLevenshteinLessEqualLeft,ConvertLevenshteinToLevenshteinLessEqualRight)
+SELECT levenshtein(s, j::STRING) < 5.1 FROM a
+----
+project
+ ├── columns: "?column?":12
+ ├── immutable
+ ├── scan a
+ │    └── columns: s:4 j:5
+ └── projections
+      └── levenshtein(s:4, j:5::STRING) < 5.1 [as="?column?":12, outer=(4,5), immutable]
+
+norm expect-not=(ConvertLevenshteinToLevenshteinLessEqualLeft,ConvertLevenshteinToLevenshteinLessEqualRight)
+SELECT levenshtein(s, j::STRING, 1, 2, 3) < 5 FROM a
+----
+project
+ ├── columns: "?column?":12
+ ├── immutable
+ ├── scan a
+ │    └── columns: s:4 j:5
+ └── projections
+      └── levenshtein(s:4, j:5::STRING, 1, 2, 3) < 5 [as="?column?":12, outer=(4,5), immutable]
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go
export HOME=/home/testuser
export GO111MODULE=on
export CGO_ENABLED=1
export GORACE=halt_on_error=1 log_path=stdout
export GO_TEST_WRAP_TESTV=1

# Switch to testuser and run the SQL optimizer normalization tests
# This will test the pkg/sql/opt/norm/testdata/rules/comp file
su - testuser -c 'cd /testbed && bazel test //pkg/sql/opt/norm:norm_test --config=test --test_output=errors --test_timeout=600'

# Capture the exit code from the primary test
rc=$?

# Additionally, verify that the roachtest import.go compiles successfully
# This ensures the import.go file is valid even though we cannot run roachtests in a container
if [ $rc -eq 0 ]; then
    su - testuser -c 'cd /testbed && bazel build //pkg/cmd/roachtest:roachtest --config=test'
    build_rc=$?
    if [ $build_rc -ne 0 ]; then
        rc=$build_rc
    fi
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 47851058f5b464b842393b403aa677029219cd98 "pkg/cmd/roachtest/tests/import.go" "pkg/sql/opt/norm/testdata/rules/comp"