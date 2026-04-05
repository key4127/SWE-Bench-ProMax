#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 6ad5b43aa46369e140794605e0f61cd363f80f6f "pkg/sql/opt/exec/execbuilder/testdata/unique"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sql/opt/exec/execbuilder/testdata/unique b/pkg/sql/opt/exec/execbuilder/testdata/unique
--- a/pkg/sql/opt/exec/execbuilder/testdata/unique
+++ b/pkg/sql/opt/exec/execbuilder/testdata/unique
@@ -2679,7 +2679,7 @@ quality of service: regular
 │       ├── • update
 │       │   │ sql nodes: <hidden>
 │       │   │ regions: <hidden>
-│       │   │ actual row count: 1
+│       │   │ actual row count: 2
 │       │   │ execution time: 0µs
 │       │   │ table: uniq_fk_child
 │       │   │ set: b, c
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go

# Run the test target without any test filter
# The test framework will automatically process all testdata files including the modified 'unique' file
bazel test //pkg/sql/opt/exec/execbuilder:execbuilder_test \
    --test_output=all \
    --test_timeout=600

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 6ad5b43aa46369e140794605e0f61cd363f80f6f "pkg/sql/opt/exec/execbuilder/testdata/unique"