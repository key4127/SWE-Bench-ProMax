#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 35973fd3369b79b9e189887d29b0f739ec5b40ea \
    "pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config b/pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config
--- a/pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config
+++ b/pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config
@@ -609,8 +609,6 @@ output:
 
 # Replicas are not constrained. The voter constraints are promoted to replica
 # constraints.
-#
-# TODO(sumeer): investigate why the normalization also threw an error.
 normalize num-replicas=5 num-voters=3
 constraint num-replicas=5
 voter-constraint num-replicas=1 +region=a +zone=a1
@@ -623,7 +621,6 @@ input:
  voter-constraints:
    +region=a,+zone=a1:1
    +region=a,+zone=a2:1
-err=could not satisfy all voter constraints due to non-intersecting conjunctions in voter and all replica constraints
 output:
  num-replicas=5 num-voters=3
  constraints:
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go
export GOCACHE=/go/cache
export CGO_ENABLED=1
export USE_BAZEL_VERSION=7.3.2
export GO_TEST_WRAP_TESTV=1
export BAZEL_HOME=/root/.cache/bazel

# Run the mmaprototype tests using Bazel
# This will execute all tests in the package, including those that use the normalize_config testdata file
echo "Running mmaprototype tests..."
bazel test //pkg/kv/kvserver/allocator/mmaprototype:mmaprototype_test \
    --test_output=all \
    --test_timeout=600

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 35973fd3369b79b9e189887d29b0f739ec5b40ea \
    "pkg/kv/kvserver/allocator/mmaprototype/testdata/normalize_config"

exit $rc