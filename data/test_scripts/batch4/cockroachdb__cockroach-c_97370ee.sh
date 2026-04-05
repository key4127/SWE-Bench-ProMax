#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 5172f2fe9648629ce4ac69d88e491592bd76b238 \
    "pkg/cmd/roachtest/tests/import_cancellation.go" \
    "pkg/cmd/roachtest/tests/tpchvec.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/roachtest/tests/import_cancellation.go b/pkg/cmd/roachtest/tests/import_cancellation.go
--- a/pkg/cmd/roachtest/tests/import_cancellation.go
+++ b/pkg/cmd/roachtest/tests/import_cancellation.go
@@ -9,7 +9,6 @@ import (
 	"context"
 	"fmt"
 	"math/rand"
-	"strconv"
 	"strings"
 	"sync"
 	"time"
@@ -139,29 +138,11 @@ func runImportCancellation(ctx context.Context, t test.Test, c cluster.Cluster)
 	// the TPCH workload should observe it.
 	m.Go(func(ctx context.Context) error {
 		t.WorkerStatus(`running tpch workload`)
-		// --enable-checks flag verifies the results against the expected output
-		// for Scale Factor 1, so since we're using Scale Factor 100 some TPCH
-		// queries are expected to return different results - skip those.
-		var queries string
-		var numQueries int
-		for i := 1; i <= tpch.NumQueries; i++ {
-			switch i {
-			case 11, 13, 16, 18, 20:
-				// These five queries return different results on SF1 and SF100.
-			default:
-				if len(queries) > 0 {
-					queries += ","
-				}
-				queries += strconv.Itoa(i)
-				numQueries++
-			}
-		}
 		// maxOps flag will allow us to exit the workload once all the queries
 		// were run 2 times.
-		maxOps := 2 * numQueries
+		maxOps := 2 * tpch.NumQueries
 		cmd := fmt.Sprintf(
-			"./cockroach workload run tpch --db=csv --concurrency=1 --queries=%s --max-ops=%d {pgurl%s} "+
-				"--enable-checks=true", queries, maxOps, c.All())
+			"./cockroach workload run tpch --db=csv --concurrency=1 --max-ops=%d {pgurl%s} ", maxOps, c.All())
 		if err := c.RunE(ctx, option.WithNodes(c.Node(1)), cmd); err != nil {
 			t.Fatal(err)
 		}
diff --git a/pkg/cmd/roachtest/tests/tpchvec.go b/pkg/cmd/roachtest/tests/tpchvec.go
--- a/pkg/cmd/roachtest/tests/tpchvec.go
+++ b/pkg/cmd/roachtest/tests/tpchvec.go
@@ -526,7 +526,7 @@ func getTPCHVecWorkloadCmd(numRunsPerQuery, queryNum int, sharedProcessMT bool)
 		url = fmt.Sprintf("{pgurl:1:%s}", appTenantName)
 	}
 	return fmt.Sprintf("./cockroach workload run tpch --concurrency=1 --db=tpch "+
-		"--max-ops=%d --queries=%d %s --enable-checks=true",
+		"--max-ops=%d --queries=%d %s",
 		numRunsPerQuery, queryNum, url)
 }
 
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go
export USE_BAZEL_VERSION=cockroachdb/7.6.0

# Strategy: Since these are roachtest integration test definitions that require cloud infrastructure,
# we validate them by:
# 1. Building the test definitions package to ensure compilation succeeds
# 2. Running the roachtest framework unit tests that validate test registration and correctness

# Step 1: Build the test definitions to validate compilation and syntax
echo "Building roachtest test definitions package..."
bazel build //pkg/cmd/roachtest/tests:tests --test_output=all
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc"
    echo "OMNIGRIL_EXIT_CODE=$build_rc"
    git checkout 5172f2fe9648629ce4ac69d88e491592bd76b238 \
        "pkg/cmd/roachtest/tests/import_cancellation.go" \
        "pkg/cmd/roachtest/tests/tpchvec.go"
    exit $build_rc
fi

# Step 2: Build the roachtest binary to ensure all components compile together
echo "Building roachtest binary..."
bazel build //pkg/cmd/roachtest:roachtest --test_output=all
roachtest_build_rc=$?

if [ $roachtest_build_rc -ne 0 ]; then
    echo "Roachtest binary build failed with exit code $roachtest_build_rc"
    echo "OMNIGRIL_EXIT_CODE=$roachtest_build_rc"
    git checkout 5172f2fe9648629ce4ac69d88e491592bd76b238 \
        "pkg/cmd/roachtest/tests/import_cancellation.go" \
        "pkg/cmd/roachtest/tests/tpchvec.go"
    exit $roachtest_build_rc
fi

# Step 3: Run roachtest framework unit tests that validate test definitions and registration
echo "Running roachtest framework unit tests..."
bazel test //pkg/cmd/roachtest:roachtest_test \
    --test_output=all \
    --test_timeout=600

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 5172f2fe9648629ce4ac69d88e491592bd76b238 \
    "pkg/cmd/roachtest/tests/import_cancellation.go" \
    "pkg/cmd/roachtest/tests/tpchvec.go"

exit $rc