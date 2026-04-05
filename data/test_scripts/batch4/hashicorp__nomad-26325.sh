#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout e675491eb684bd5488a6c94c3c1a6ad218a45c26 "scheduler/reconciler/reconcile_cluster_prop_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/scheduler/reconciler/reconcile_cluster_prop_test.go b/scheduler/reconciler/reconcile_cluster_prop_test.go
--- a/scheduler/reconciler/reconcile_cluster_prop_test.go
+++ b/scheduler/reconciler/reconcile_cluster_prop_test.go
@@ -228,9 +228,13 @@ func TestAllocReconciler_cancelUnneededCanaries(t *testing.T) {
 		group := job.TaskGroups[0].Name
 		all := m[group] // <-- allocset of all allocs for tg
 		all, _ = all.filterOldTerminalAllocs(jobState)
+		original := all
+
+		result := new(ReconcileResults)
+		result.DesiredTGUpdates = map[string]*structs.DesiredUpdates{group: {}}
 
 		// runs the method under test
-		canaries, _, stopAllocs := ar.cancelUnneededCanaries(all, new(structs.DesiredUpdates))
+		canaries := ar.cancelUnneededCanaries(&all, group, result)
 
 		expectedStopped := []string{}
 		if jobState.DeploymentOld != nil {
@@ -247,8 +251,8 @@ func TestAllocReconciler_cancelUnneededCanaries(t *testing.T) {
 				}
 			}
 		}
-		stopSet := all.fromKeys(expectedStopped)
-		all = all.difference(stopSet)
+		stopSet := original.fromKeys(expectedStopped)
+		all = original.difference(stopSet)
 
 		expectedCanaries := []string{}
 		if jobState.DeploymentCurrent != nil {
@@ -261,7 +265,7 @@ func TestAllocReconciler_cancelUnneededCanaries(t *testing.T) {
 
 		stopSet = stopSet.union(migrate, lost)
 
-		must.Eq(t, len(stopAllocs), len(stopSet))
+		must.Eq(t, len(result.Stop), len(stopSet))
 		must.Eq(t, len(canaries), len(canariesOnUntaintedNodes))
 	})
 }
EOF_114329324912

# Set build tags environment variable
export GO_TAGS=hashicorpmetrics
export CGO_ENABLED=1

# Run the target test file
# Using go test with the specific package path and required flags
# - timeout: 25m (as specified in test execution details)
# - count: 1 (disable test caching)
# - tags: hashicorpmetrics (required build tag)
# - v: verbose output for better debugging
go test -v -timeout=25m -count=1 -tags "${GO_TAGS}" ./scheduler/reconciler/ -run "TestAllocReconciler_PropTest|TestAllocReconciler_cancelUnneededCanaries|TestAllocReconciler_ReconnectingProps"

# Capture exit code immediately
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout e675491eb684bd5488a6c94c3c1a6ad218a45c26 "scheduler/reconciler/reconcile_cluster_prop_test.go"

# Exit with the captured return code
exit $rc