#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout c8dcd3c2dbee57543e5f30667a99085fd35653e7 "scheduler/reconciler/allocs_test.go" "scheduler/reconciler/reconcile_cluster_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/scheduler/reconciler/allocs_test.go b/scheduler/reconciler/allocs_test.go
--- a/scheduler/reconciler/allocs_test.go
+++ b/scheduler/reconciler/allocs_test.go
@@ -124,12 +124,10 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 
 		t.Run(jd.name, func(t *testing.T) {
 			testCases := []struct {
-				name                        string
-				all                         allocSet
-				taintedNodes                map[string]*structs.Node
-				supportsDisconnectedClients bool
-				skipNilNodeTest             bool
-				now                         time.Time
+				name            string
+				all             allocSet
+				state           ClusterState
+				skipNilNodeTest bool
 				// expected results
 				untainted     allocSet
 				migrate       allocSet
@@ -140,11 +138,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 				expiring      allocSet
 			}{ // These two cases test that we maintain parity with pre-disconnected-clients behavior.
 				{
-					name:                        "lost-client",
-					supportsDisconnectedClients: false,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "lost-client",
+					state:           ClusterState{nodes, false, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"untainted1": {
 							ID:           "untainted1",
@@ -244,10 +240,8 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring:      allocSet{},
 				},
 				{
-					name:                        "lost-client-only-tainted-nodes",
-					supportsDisconnectedClients: false,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
+					name:  "lost-client-only-tainted-nodes",
+					state: ClusterState{nodes, false, time.Now()},
 					// The logic associated with this test case can only trigger if there
 					// is a tainted node. Therefore, testing with a nil node set produces
 					// false failures, so don't perform that test if in this case.
@@ -292,11 +286,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-disconnect-unset-max-disconnect",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             true,
+					name:            "disco-client-disconnect-unset-max-disconnect",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: true,
 					all: allocSet{
 						// Non-terminal allocs on disconnected nodes w/o max-disconnect are lost
 						"lost-running": {
@@ -329,11 +321,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 				},
 				// Everything below this line tests the disconnected client mode.
 				{
-					name:                        "disco-client-untainted-reconnect-failed-and-replaced",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-untainted-reconnect-failed-and-replaced",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-replacement": {
 							ID:                 "running-replacement",
@@ -390,11 +380,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-reconnecting-running-no-replacement",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-reconnecting-running-no-replacement",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						// Running allocs on reconnected nodes with no replacement are reconnecting.
 						// Node.UpdateStatus has already handled syncing client state so this
@@ -430,11 +418,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-terminal",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-terminal",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						// Allocs on reconnected nodes that are complete need to be updated to stop
 						"untainted-reconnect-complete": {
@@ -580,11 +566,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-disconnect",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             true,
+					name:            "disco-client-disconnect",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: true,
 					all: allocSet{
 						// Non-terminal allocs on disconnected nodes are disconnecting
 						"disconnect-running": {
@@ -724,11 +708,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					},
 				},
 				{
-					name:                        "disco-client-reconnect",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-reconnect",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						// Expired allocs on reconnected clients are lost
 						"expired-reconnect": {
@@ -762,11 +744,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					},
 				},
 				{
-					name:                        "disco-client-running-reconnecting-and-replacement-untainted",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-running-reconnecting-and-replacement-untainted",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-replacement": {
 							ID:                 "running-replacement",
@@ -824,11 +804,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					// After an alloc is reconnected, it should be considered
 					// "untainted" instead of "reconnecting" to allow changes such as
 					// job updates to be applied properly.
-					name:                        "disco-client-reconnected-alloc-untainted",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-reconnected-alloc-untainted",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-reconnected": {
 							ID:            "running-reconnected",
@@ -862,11 +840,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 				},
 				// Everything below this line tests the single instance on lost mode.
 				{
-					name:                        "lost-client-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "lost-client-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"untainted1": {
 							ID:           "untainted1",
@@ -966,10 +942,8 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring:      allocSet{},
 				},
 				{
-					name:                        "lost-client-only-tainted-nodes-single-instance-on",
-					supportsDisconnectedClients: false,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
+					name:  "lost-client-only-tainted-nodes-single-instance-on",
+					state: ClusterState{nodes, false, time.Now()},
 					// The logic associated with this test case can only trigger if there
 					// is a tainted node. Therefore, testing with a nil node set produces
 					// false failures, so don't perform that test if in this case.
@@ -1014,11 +988,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-disconnect-unset-max-disconnect-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             true,
+					name:            "disco-client-disconnect-unset-max-disconnect-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: true,
 					all: allocSet{
 						// Non-terminal allocs on disconnected nodes w/o max-disconnect are lost
 						"disconnecting-running": {
@@ -1048,11 +1020,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring:     allocSet{},
 				},
 				{
-					name:                        "disco-client-untainted-reconnect-failed-and-replaced-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-untainted-reconnect-failed-and-replaced-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-replacement": {
 							ID:                 "running-replacement",
@@ -1109,11 +1079,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring: allocSet{},
 				},
 				{
-					name:                        "disco-client-reconnect-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-reconnect-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						// Expired allocs on reconnected clients are lost
 						"expired-reconnect": {
@@ -1147,11 +1115,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					},
 				},
 				{
-					name:                        "disco-client-running-reconnecting-and-replacement-untainted-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-running-reconnecting-and-replacement-untainted-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-replacement": {
 							ID:                 "running-replacement",
@@ -1209,11 +1175,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					// After an alloc is reconnected, it should be considered
 					// "untainted" instead of "reconnecting" to allow changes such as
 					// job updates to be applied properly.
-					name:                        "disco-client-reconnected-alloc-untainted",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             false,
+					name:            "disco-client-reconnected-alloc-untainted",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: false,
 					all: allocSet{
 						"running-reconnected": {
 							ID:            "running-reconnected",
@@ -1246,11 +1210,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					expiring:      allocSet{},
 				},
 				{
-					name:                        "disco-client-reconnected-alloc-untainted-single-instance-on",
-					supportsDisconnectedClients: true,
-					now:                         time.Now(),
-					taintedNodes:                nodes,
-					skipNilNodeTest:             true,
+					name:            "disco-client-reconnected-alloc-untainted-single-instance-on",
+					state:           ClusterState{nodes, true, time.Now()},
+					skipNilNodeTest: true,
 					all: allocSet{
 						"untainted-unknown": {
 							ID:            "untainted-unknown",
@@ -1345,7 +1307,7 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 			for _, tc := range testCases {
 				t.Run(tc.name, func(t *testing.T) {
 					// With tainted nodes
-					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired := tc.all.filterByTainted(tc.taintedNodes, tc.supportsDisconnectedClients, tc.now)
+					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired := filterByTainted(tc.all, tc.state)
 					must.Eq(t, tc.untainted, untainted, must.Sprintf("with-nodes: untainted"))
 					must.Eq(t, tc.migrate, migrate, must.Sprintf("with-nodes: migrate"))
 					must.Eq(t, tc.lost, lost, must.Sprintf("with-nodes: lost"))
@@ -1359,7 +1321,9 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					}
 
 					// Now again with nodes nil
-					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired = tc.all.filterByTainted(nil, tc.supportsDisconnectedClients, tc.now)
+					state := tc.state
+					state.TaintedNodes = nil
+					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired = filterByTainted(tc.all, state)
 					must.Eq(t, tc.untainted, untainted, must.Sprintf("with-nodes: untainted"))
 					must.Eq(t, tc.migrate, migrate, must.Sprintf("with-nodes: migrate"))
 					must.Eq(t, tc.lost, lost, must.Sprintf("with-nodes: lost"))
diff --git a/scheduler/reconciler/reconcile_cluster_test.go b/scheduler/reconciler/reconcile_cluster_test.go
--- a/scheduler/reconciler/reconcile_cluster_test.go
+++ b/scheduler/reconciler/reconcile_cluster_test.go
@@ -351,9 +351,8 @@ func TestReconciler_Place_NoExisting(t *testing.T) {
 	job := mock.Job()
 	reconciler := NewAllocReconciler(
 		testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, nil, nil, "", job.Priority, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, nil, "", job.Priority, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -391,9 +390,8 @@ func TestReconciler_Place_Existing(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -433,9 +431,8 @@ func TestReconciler_ScaleDown_Partial(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -476,9 +473,8 @@ func TestReconciler_ScaleDown_Zero(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -520,9 +516,8 @@ func TestReconciler_ScaleDown_Zero_DuplicateNames(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -559,9 +554,8 @@ func TestReconciler_Inplace(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnInplace, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -601,9 +595,8 @@ func TestReconciler_Inplace_ScaleUp(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnInplace, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -645,9 +638,8 @@ func TestReconciler_Inplace_ScaleDown(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnInplace, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -710,9 +702,8 @@ func TestReconciler_Inplace_Rollback(t *testing.T) {
 	}, allocUpdateFnDestructive)
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFn,
-		false, job.ID, job, nil, allocs, nil, uuid.Generate(), 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		false, job.ID, job, nil, allocs, uuid.Generate(), 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -757,9 +748,8 @@ func TestReconciler_Destructive(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -794,9 +784,8 @@ func TestReconciler_DestructiveMaxParallel(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -834,9 +823,8 @@ func TestReconciler_Destructive_ScaleUp(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -877,9 +865,8 @@ func TestReconciler_Destructive_ScaleDown(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -926,9 +913,8 @@ func TestReconciler_LostNode(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -980,9 +966,8 @@ func TestReconciler_LostNode_ScaleUp(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1034,9 +1019,8 @@ func TestReconciler_LostNode_ScaleDown(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1083,9 +1067,8 @@ func TestReconciler_DrainNode(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1139,9 +1122,8 @@ func TestReconciler_DrainNode_ScaleUp(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1196,9 +1178,8 @@ func TestReconciler_DrainNode_ScaleDown(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1245,9 +1226,8 @@ func TestReconciler_RemovedTG(t *testing.T) {
 	job.TaskGroups[0].Name = newName
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1311,9 +1291,8 @@ func TestReconciler_JobStopped(t *testing.T) {
 			}
 
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, c.jobID, c.job,
-				nil, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -1381,9 +1360,9 @@ func TestReconciler_JobStopped_TerminalAllocs(t *testing.T) {
 			}
 
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, c.jobID, c.job,
-				nil, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
+
 			must.SliceEmpty(t, r.Stop)
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -1421,9 +1400,8 @@ func TestReconciler_MultiTG(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1477,9 +1455,8 @@ func TestReconciler_MultiTG_SingleUpdateBlock(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -1555,9 +1532,8 @@ func TestReconciler_RescheduleLater_Batch(t *testing.T) {
 	allocs[5].ClientStatus = structs.AllocClientStatusComplete
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, true, job.ID, job,
-		nil, allocs, nil, uuid.Generate(), 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, uuid.Generate(), 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Two reschedule attempts were already made, one more can be made at a future time
 	// Verify that the follow up eval has the expected waitUntil time
@@ -1637,9 +1613,8 @@ func TestReconciler_RescheduleLaterWithBatchedEvals_Batch(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, true, job.ID, job,
-		nil, allocs, nil, uuid.Generate(), 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, uuid.Generate(), 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Verify that two follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -1734,10 +1709,8 @@ func TestReconciler_RescheduleNow_Batch(t *testing.T) {
 	allocs[5].ClientStatus = structs.AllocClientStatusComplete
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, true, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.now = now
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -1811,9 +1784,8 @@ func TestReconciler_RescheduleLater_Service(t *testing.T) {
 	allocs[4].DesiredStatus = structs.AllocDesiredStatusStop
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, uuid.Generate(), 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, uuid.Generate(), 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Should place a new placement and create a follow up eval for the delayed reschedule
 	// Verify that the follow up eval has the expected waitUntil time
@@ -1884,9 +1856,8 @@ func TestReconciler_Service_ClientStatusComplete(t *testing.T) {
 	allocs[4].ClientStatus = structs.AllocClientStatusComplete
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Should place a new placement for the alloc that was marked complete
 	assertResults(t, r, &resultExpectation{
@@ -1944,9 +1915,8 @@ func TestReconciler_Service_DesiredStop_ClientStatusComplete(t *testing.T) {
 	allocs[4].DesiredStatus = structs.AllocDesiredStatusStop
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Should place a new placement for the alloc that was marked stopped
 	assertResults(t, r, &resultExpectation{
@@ -2022,9 +1992,8 @@ func TestReconciler_RescheduleNow_Service(t *testing.T) {
 	allocs[4].DesiredStatus = structs.AllocDesiredStatusStop
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2102,10 +2071,8 @@ func TestReconciler_RescheduleNow_WithinAllowedTimeWindow(t *testing.T) {
 	allocs[1].ClientStatus = structs.AllocClientStatusFailed
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.now = now
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2184,11 +2151,10 @@ func TestReconciler_RescheduleNow_EvalIDMatch(t *testing.T) {
 	allocs[1].ClientStatus = structs.AllocClientStatusFailed
 	allocs[1].FollowupEvalID = evalID
 
+	now = now.Add(-30 * time.Second)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, evalID, 50, true)
-	reconciler.now = now.Add(-30 * time.Second)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, evalID, 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2296,9 +2262,8 @@ func TestReconciler_RescheduleNow_Service_WithCanaries(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job2,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2421,10 +2386,8 @@ func TestReconciler_RescheduleNow_Service_Canaries(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job2,
-		d, allocs, nil, "", 50, true)
-	reconciler.now = now
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2550,10 +2513,8 @@ func TestReconciler_RescheduleNow_Service_Canaries_Limit(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job2,
-		d, allocs, nil, "", 50, true)
-	reconciler.now = now
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -2619,9 +2580,8 @@ func TestReconciler_DontReschedule_PreviouslyRescheduled(t *testing.T) {
 	allocs[4].DesiredStatus = structs.AllocDesiredStatusStop
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Should place 1 - one is a new placement to make up the desired count of 5
 	// failing allocs are not rescheduled
@@ -2710,9 +2670,8 @@ func TestReconciler_CancelDeployment_JobStop(t *testing.T) {
 			}
 
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, c.jobID, c.job,
-				c.deployment, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				c.deployment, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			var updates []*structs.DeploymentStatusUpdate
 			if c.cancel {
@@ -2791,9 +2750,8 @@ func TestReconciler_CancelDeployment_JobUpdate(t *testing.T) {
 			}
 
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-				c.deployment, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				c.deployment, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			var updates []*structs.DeploymentStatusUpdate
 			if c.cancel {
@@ -2844,9 +2802,8 @@ func TestReconciler_CreateDeployment_RollingUpgrade_Destructive(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -2893,9 +2850,8 @@ func TestReconciler_CreateDeployment_RollingUpgrade_Inplace(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnInplace, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -2941,9 +2897,8 @@ func TestReconciler_CreateDeployment_NewerCreateIndex(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -2991,9 +2946,8 @@ func TestReconciler_DontCreateDeployment_NoChanges(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -3073,9 +3027,8 @@ func TestReconciler_PausedOrFailedDeployment_NoMoreCanaries(t *testing.T) {
 
 			mockUpdateFn := allocUpdateFnMock(map[string]AllocUpdateType{canary.ID: allocUpdateFnIgnore}, allocUpdateFnDestructive)
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-				d, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -3142,9 +3095,8 @@ func TestReconciler_PausedOrFailedDeployment_NoMorePlacements(t *testing.T) {
 			}
 
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-				d, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -3220,9 +3172,8 @@ func TestReconciler_PausedOrFailedDeployment_NoMoreDestructiveUpdates(t *testing
 
 			mockUpdateFn := allocUpdateFnMock(map[string]AllocUpdateType{newAlloc.ID: allocUpdateFnIgnore}, allocUpdateFnDestructive)
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-				d, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -3298,9 +3249,8 @@ func TestReconciler_DrainNode_Canary(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -3374,9 +3324,8 @@ func TestReconciler_LostNode_Canary(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -3444,9 +3393,8 @@ func TestReconciler_StopOldCanaries(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job, d,
-		allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3503,9 +3451,8 @@ func TestReconciler_NewCanaries(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3557,9 +3504,8 @@ func TestReconciler_NewCanaries_CountGreater(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3614,9 +3560,8 @@ func TestReconciler_NewCanaries_MultiTG(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3673,9 +3618,8 @@ func TestReconciler_NewCanaries_ScaleUp(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3727,9 +3671,8 @@ func TestReconciler_NewCanaries_ScaleDown(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -3810,9 +3753,8 @@ func TestReconciler_NewCanaries_FillNames(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -3883,9 +3825,8 @@ func TestReconciler_PromoteCanaries_Unblock(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -3961,9 +3902,8 @@ func TestReconciler_PromoteCanaries_CanariesEqualCount(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	updates := []*structs.DeploymentStatusUpdate{
 		{
@@ -4064,9 +4004,8 @@ func TestReconciler_DeploymentLimit_HealthAccounting(t *testing.T) {
 
 			mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-				d, allocs, nil, "", 50, true)
-			reconciler.Compute()
-			r := reconciler.Result
+				d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+			r := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, r, &resultExpectation{
@@ -4149,9 +4088,8 @@ func TestReconciler_TaintedNode_RollingUpgrade(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4238,9 +4176,8 @@ func TestReconciler_FailedDeployment_TaintedNodes(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, tainted, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4298,9 +4235,8 @@ func TestReconciler_CompleteDeployment(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4357,9 +4293,8 @@ func TestReconciler_MarkDeploymentComplete_FailedAllocations(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID,
-		job, d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		job, d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	updates := []*structs.DeploymentStatusUpdate{
 		{
@@ -4456,9 +4391,8 @@ func TestReconciler_FailedDeployment_CancelCanaries(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4529,9 +4463,8 @@ func TestReconciler_FailedDeployment_NewJob(t *testing.T) {
 	jobNew.Version += 100
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, jobNew,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// reconciler sets the creation time automatically so we have to copy here,
 	// otherwise there will be a discrepancy
@@ -4588,9 +4521,8 @@ func TestReconciler_MarkDeploymentComplete(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	updates := []*structs.DeploymentStatusUpdate{
 		{
@@ -4661,9 +4593,8 @@ func TestReconciler_JobChange_ScaleUp_SecondEval(t *testing.T) {
 
 	mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4700,9 +4631,8 @@ func TestReconciler_RollingUpgrade_MissingAllocs(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	d := structs.NewDeployment(job, 50, r.Deployment.CreateTime)
 	d.TaskGroups[job.TaskGroups[0].Name] = &structs.DeploymentState{
@@ -4756,9 +4686,8 @@ func TestReconciler_Batch_Rerun(t *testing.T) {
 	job2.CreateIndex++
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, true, job2.ID, job2,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert the correct results
 	assertResults(t, r, &resultExpectation{
@@ -4821,9 +4750,8 @@ func TestReconciler_FailedDeployment_DontReschedule(t *testing.T) {
 		FinishedAt: now.Add(-10 * time.Second)}}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert that no rescheduled placements were created
 	assertResults(t, r, &resultExpectation{
@@ -4880,9 +4808,8 @@ func TestReconciler_DeploymentWithFailedAllocs_DontReschedule(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert that no rescheduled placements were created
 	assertResults(t, r, &resultExpectation{
@@ -4969,9 +4896,8 @@ func TestReconciler_FailedDeployment_AutoRevert_CancelCanaries(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, jobv2,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	updates := []*structs.DeploymentStatusUpdate{
 		{
@@ -5035,9 +4961,8 @@ func TestReconciler_SuccessfulDeploymentWithFailedAllocs_Reschedule(t *testing.T
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnDestructive, false, job.ID, job,
-		d, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		d, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Assert that rescheduled placements were created
 	assertResults(t, r, &resultExpectation{
@@ -5101,9 +5026,8 @@ func TestReconciler_ForceReschedule_Service(t *testing.T) {
 	allocs[0].DesiredTransition = structs.DesiredTransition{ForceReschedule: pointer.Of(true)}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -5185,9 +5109,8 @@ func TestReconciler_RescheduleNot_Service(t *testing.T) {
 	allocs[4].DesiredStatus = structs.AllocDesiredStatusStop
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -5582,22 +5505,20 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 				allocs = append(allocs, replacements...)
 			}
 
-			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, tc.isBatch, job.ID, job,
-				nil, allocs, map[string]*structs.Node{testNode.ID: testNode}, "", 50, true)
-
-			reconciler.now = time.Now()
+			now := time.Now()
 			if tc.maxDisconnect != nil {
-				reconciler.now = time.Now().Add(*tc.maxDisconnect * 20)
+				now = time.Now().Add(*tc.maxDisconnect * 20)
 			}
+			reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, tc.isBatch, job.ID, job,
+				nil, allocs, "", 50, ClusterState{map[string]*structs.Node{testNode.ID: testNode}, true, now})
 
 			mpc := &mockPicker{
 				result: tc.pickResult,
 			}
 
 			reconciler.reconnectingPicker = mpc
-			reconciler.Compute()
+			results := reconciler.Compute()
 
-			results := reconciler.Result
 			assertResults(t, results, tc.expected)
 
 			must.Eq(t, tc.reconcileStrategy, mpc.strategy)
@@ -5677,10 +5598,8 @@ func TestReconciler_RescheduleNot_Batch(t *testing.T) {
 	allocs[5].ClientStatus = structs.AllocClientStatusComplete
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, true, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.now = now
-	reconciler.Compute()
-	r := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, now})
+	r := reconciler.Compute()
 
 	// Verify that no follow up evals were created
 	evals := r.DesiredFollowupEvals[tgName]
@@ -5709,16 +5628,15 @@ func TestReconciler_Node_Disconnect_Updates_Alloc_To_Unknown(t *testing.T) {
 	// Build a map of disconnected nodes
 	nodes := buildDisconnectedNodes(allocs, 2)
 
+	now := time.Now().UTC()
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job,
-		nil, allocs, nodes, "", 50, true)
-	reconciler.now = time.Now().UTC()
-	reconciler.Compute()
-	results := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nodes, true, now})
+	results := reconciler.Compute()
 
 	// Verify that 1 follow up eval was created with the values we expect.
 	evals := results.DesiredFollowupEvals[job.TaskGroups[0].Name]
 	must.SliceLen(t, 1, evals)
-	expectedTime := reconciler.now.Add(5 * time.Minute)
+	expectedTime := now.Add(5 * time.Minute)
 
 	eval := evals[0]
 	must.NotNil(t, eval.WaitUntil)
@@ -5773,9 +5691,8 @@ func TestReconciler_Disconnect_UpdateJobAfterReconnect(t *testing.T) {
 	}
 
 	reconciler := NewAllocReconciler(testlog.HCLogger(t), allocUpdateFnInplace, false, job.ID, job,
-		nil, allocs, nil, "", 50, true)
-	reconciler.Compute()
-	results := reconciler.Result
+		nil, allocs, "", 50, ClusterState{nil, true, time.Now().UTC()})
+	results := reconciler.Compute()
 
 	// Assert both allocations will be updated.
 	assertResults(t, results, &resultExpectation{
@@ -6124,9 +6041,8 @@ func TestReconciler_Client_Disconnect_Canaries(t *testing.T) {
 
 			mockUpdateFn := allocUpdateFnMock(handled, allocUpdateFnDestructive)
 			reconciler := NewAllocReconciler(testlog.HCLogger(t), mockUpdateFn, false, updatedJob.ID, updatedJob,
-				deployment, allocs, tainted, "", 50, true)
-			reconciler.Compute()
-			result := reconciler.Result
+				deployment, allocs, "", 50, ClusterState{tainted, true, time.Now().UTC()})
+			result := reconciler.Compute()
 
 			// Assert the correct results
 			assertResults(t, result, tc.expectedResult)
@@ -6275,7 +6191,7 @@ func TestReconciler_ComputeDeploymentPaused(t *testing.T) {
 
 			reconciler := NewAllocReconciler(
 				testlog.HCLogger(t), allocUpdateFnIgnore, false, job.ID, job, deployment,
-				nil, nil, "", job.Priority, true)
+				nil, "", job.Priority, ClusterState{nil, true, time.Now().UTC()})
 
 			reconciler.Compute()
 
EOF_114329324912

# Set build tags environment variable
export GO_TAGS=hashicorpmetrics

# Run the target tests using gotestsum
# Combining both test files into a single test run for efficiency
# Using the package path since both files are in the same package
gotestsum --format=testname --packages="github.com/hashicorp/nomad/scheduler/reconciler" -- \
    -cover \
    -timeout=25m \
    -count=1 \
    -tags "${GO_TAGS}" \
    -run="" \
    github.com/hashicorp/nomad/scheduler/reconciler

# Capture exit code immediately
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout c8dcd3c2dbee57543e5f30667a99085fd35653e7 "scheduler/reconciler/allocs_test.go" "scheduler/reconciler/reconcile_cluster_test.go"