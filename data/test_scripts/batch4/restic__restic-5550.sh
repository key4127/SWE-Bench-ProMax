#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 718b97f37f7f1c5949384309c417a2179f5aa1d8 "internal/checker/checker_test.go" "internal/checker/testing.go" "internal/repository/testing.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/checker/checker_test.go b/internal/checker/checker_test.go
--- a/internal/checker/checker_test.go
+++ b/internal/checker/checker_test.go
@@ -60,7 +60,9 @@ func checkData(chkr *checker.Checker) []error {
 	return collectErrors(
 		context.TODO(),
 		func(ctx context.Context, errCh chan<- error) {
-			chkr.ReadData(ctx, errCh)
+			chkr.ReadPacks(ctx, func(packs map[restic.ID]int64) map[restic.ID]int64 {
+				return packs
+			}, nil, errCh)
 		},
 	)
 }
diff --git a/internal/checker/testing.go b/internal/checker/testing.go
--- a/internal/checker/testing.go
+++ b/internal/checker/testing.go
@@ -3,6 +3,8 @@ package checker
 import (
 	"context"
 	"testing"
+
+	"github.com/restic/restic/internal/restic"
 )
 
 // TestCheckRepo runs the checker on repo.
@@ -50,7 +52,9 @@ func TestCheckRepo(t testing.TB, repo checkerRepository) {
 
 	// read data
 	errChan = make(chan error)
-	go chkr.ReadData(context.TODO(), errChan)
+	go chkr.ReadPacks(context.TODO(), func(packs map[restic.ID]int64) map[restic.ID]int64 {
+		return packs
+	}, nil, errChan)
 
 	for err := range errChan {
 		t.Error(err)
diff --git a/internal/repository/testing.go b/internal/repository/testing.go
--- a/internal/repository/testing.go
+++ b/internal/repository/testing.go
@@ -186,7 +186,9 @@ func TestCheckRepo(t testing.TB, repo *Repository) {
 
 	// read data
 	errChan = make(chan error)
-	go chkr.ReadData(context.TODO(), errChan)
+	go chkr.ReadPacks(context.TODO(), func(packs map[restic.ID]int64) map[restic.ID]int64 {
+		return packs
+	}, nil, errChan)
 
 	for err := range errChan {
 		t.Error(err)
EOF_114329324912

# Verify Go environment is properly configured
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export CGO_ENABLED=0

# Run the target test files
# Using -v for verbose output, -timeout 30m for sufficient execution time
# Using -p 1 to run tests sequentially for stability in virtualized environment
# Using -count 1 to disable test caching
# Running both test packages in a single command for efficiency
go test -v -timeout 30m -p 1 -count 1 ./internal/checker ./internal/repository
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 718b97f37f7f1c5949384309c417a2179f5aa1d8 "internal/checker/checker_test.go" "internal/checker/testing.go" "internal/repository/testing.go"