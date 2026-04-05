#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 5ddda7f5e9895f48e0303ada14d4a2ec1ba68dd7 "internal/backend/retry/backend_retry_test.go" "internal/backend/sema/backend_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/backend/retry/backend_retry_test.go b/internal/backend/retry/backend_retry_test.go
--- a/internal/backend/retry/backend_retry_test.go
+++ b/internal/backend/retry/backend_retry_test.go
@@ -69,7 +69,12 @@ func TestBackendSaveRetryAtomic(t *testing.T) {
 			calledRemove = true
 			return nil
 		},
-		HasAtomicReplaceFn: func() bool { return true },
+		PropertiesFn: func() backend.Properties {
+			return backend.Properties{
+				Connections:      2,
+				HasAtomicReplace: true,
+			}
+		},
 	}
 
 	TestFastRetries(t)
diff --git a/internal/backend/sema/backend_test.go b/internal/backend/sema/backend_test.go
--- a/internal/backend/sema/backend_test.go
+++ b/internal/backend/sema/backend_test.go
@@ -106,7 +106,12 @@ func concurrencyTester(t *testing.T, setup func(m *mock.Backend), handler func(b
 
 	m := mock.NewBackend()
 	setup(m)
-	m.ConnectionsFn = func() uint { return uint(expectBlocked) }
+	m.PropertiesFn = func() backend.Properties {
+		return backend.Properties{
+			Connections:      uint(expectBlocked),
+			HasAtomicReplace: false,
+		}
+	}
 	be := sema.NewBackend(m)
 
 	var wg errgroup.Group
@@ -206,7 +211,12 @@ func TestFreeze(t *testing.T) {
 		atomic.AddInt64(&counter, 1)
 		return nil
 	}
-	m.ConnectionsFn = func() uint { return 2 }
+	m.PropertiesFn = func() backend.Properties {
+		return backend.Properties{
+			Connections:      2,
+			HasAtomicReplace: false,
+		}
+	}
 	be := sema.NewBackend(m)
 	fb := be.(backend.FreezeBackend)
 
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
go test -v -timeout 30m -p 1 -count 1 ./internal/backend/retry ./internal/backend/sema
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 5ddda7f5e9895f48e0303ada14d4a2ec1ba68dd7 "internal/backend/retry/backend_retry_test.go" "internal/backend/sema/backend_test.go"