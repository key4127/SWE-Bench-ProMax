#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 911b6258b47ffeefc5853f54a9f8d3e612a29d7a "scheduler/scheduler_system_test.go" "scheduler/util_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/scheduler/scheduler_system_test.go b/scheduler/scheduler_system_test.go
--- a/scheduler/scheduler_system_test.go
+++ b/scheduler/scheduler_system_test.go
@@ -3417,7 +3417,9 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 		expectStop   map[string]int // plan NodeUpdates group -> count
 		expectDState map[string]*structs.DeploymentState
 
-		ineligibleNodes int // number of nodes to mark as ineligible
+		nodesModify      func([]*structs.Node) // make custom modifications to nodes
+		initialJobModify func(*structs.Job)    // make custom modifications to initial job definition
+		updateJobModify  func(*structs.Job)    // make custom modifications to updated job definition
 	}{
 		{
 			name:         "legacy upgrade non-deployment",
@@ -3568,7 +3570,7 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 			expectDState: map[string]*structs.DeploymentState{
 				tg1: {
 					DesiredTotal:    10,
-					DesiredCanaries: 3,
+					DesiredCanaries: 2,
 					PlacedCanaries:  []string{"0", "1"},
 					PlacedAllocs:    2, // want 3 canaries, limited by max_parallel
 				},
@@ -3582,7 +3584,7 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 		{
 			name: "canaries failed",
 			tg1UpdateBlock: &structs.UpdateStrategy{
-				MaxParallel: 2,
+				MaxParallel: 3,
 				Canary:      30,
 			},
 			tg2UpdateBlock: &structs.UpdateStrategy{
@@ -3597,31 +3599,37 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 				tg2: {5, 6, 7, 8, 9},
 			},
 			existingFailed: map[string][]int{
-				tg1: {8, 9},
+				tg1: {8},
 			},
 			existingCanary: map[string][]int{
-				tg1: {7, 8, 9},
+				tg1: {7, 8},
 			},
 			existingCurrentDState: map[string]*structs.DeploymentState{
 				tg1: {
 					Promoted:        false,
-					PlacedCanaries:  []string{"7", "8", "9"},
+					PlacedCanaries:  []string{"7", "8"},
 					DesiredCanaries: 3,
 					DesiredTotal:    10,
-					PlacedAllocs:    3,
+					PlacedAllocs:    2,
 					HealthyAllocs:   1,
-					UnhealthyAllocs: 2,
+					UnhealthyAllocs: 1,
 				},
 				tg2: {DesiredTotal: 10, PlacedAllocs: 5, HealthyAllocs: 5},
 			},
-			expectAllocs: map[string]int{tg1: 2, tg2: 5}, // only 2 replacements
-			expectStop:   map[string]int{tg2: 5},
+			expectAllocs: map[string]int{
+				tg1: 3, // replace 1 canary, add 2 missing allocs
+				tg2: 5, // add remaning 5 allocs
+			},
+			expectStop: map[string]int{
+				tg1: 1, // failed canary alloc being replaced
+				tg2: 5, // stop remaining 5 allocs
+			},
 			expectDState: map[string]*structs.DeploymentState{
 				tg1: {
 					DesiredTotal:    10,
 					DesiredCanaries: 3,
-					PlacedCanaries:  []string{"7", "8", "9"},
-					PlacedAllocs:    5, // 2 failed + 2 replacements + 1 new
+					PlacedCanaries:  []string{"7", "8"},
+					PlacedAllocs:    5,
 				},
 				tg2: {DesiredTotal: 10, PlacedAllocs: 10},
 			},
@@ -3651,22 +3659,22 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 				tg1: {
 					Promoted:        false,
 					PlacedCanaries:  []string{"7"},
-					DesiredCanaries: 3,
+					DesiredCanaries: 2,
 					DesiredTotal:    10,
 					PlacedAllocs:    1,
 					HealthyAllocs:   1,
 					UnhealthyAllocs: 0,
 				},
 				tg2: {DesiredTotal: 10, PlacedAllocs: 5, HealthyAllocs: 5},
 			},
-			expectAllocs: map[string]int{tg1: 2, tg2: 5},
-			expectStop:   map[string]int{tg1: 2, tg2: 5},
+			expectAllocs: map[string]int{tg1: 1, tg2: 5},
+			expectStop:   map[string]int{tg1: 1, tg2: 5},
 			expectDState: map[string]*structs.DeploymentState{
 				tg1: {
 					DesiredTotal:    10,
-					DesiredCanaries: 3,
-					PlacedCanaries:  []string{"7", "8", "9"},
-					PlacedAllocs:    3, // 1 existing canary + 2 new canaries
+					DesiredCanaries: 2,
+					PlacedCanaries:  []string{"7", "8"},
+					PlacedAllocs:    2, // 1 existing canary + 1 new canary
 				},
 				tg2: {DesiredTotal: 10, PlacedAllocs: 10},
 			},
@@ -3675,7 +3683,7 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 		{
 			name: "canaries awaiting promotion",
 			tg1UpdateBlock: &structs.UpdateStrategy{
-				MaxParallel: 2,
+				MaxParallel: 3,
 				Canary:      30,
 				AutoPromote: false,
 			},
@@ -3798,11 +3806,102 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 					PlacedAllocs:    8,
 				},
 				tg2: {
-					DesiredTotal: 8,  // 10 nodes minus 2 ineligble nodes
+					DesiredTotal: 10, // 10 nodes minus 2 ineligble nodes
 					PlacedAllocs: 10, // New allocations were already placed
 				},
 			},
-			ineligibleNodes: 2,
+			nodesModify: func(nodes []*structs.Node) {
+				// Mark the first two nodes as ineligible
+				nodes[0].SchedulingEligibility = structs.NodeSchedulingIneligible
+				nodes[1].SchedulingEligibility = structs.NodeSchedulingIneligible
+			},
+		},
+
+		{
+			name: "deployment previous no placements",
+			tg1UpdateBlock: &structs.UpdateStrategy{
+				MaxParallel: 10,
+				Canary:      30,
+			},
+			existingCurrentDState: map[string]*structs.DeploymentState{
+				tg1: {},
+				tg2: {},
+			},
+			expectAllocs: map[string]int{
+				tg1: 10, // all allocations
+				tg2: 10, // all allocations
+			},
+			expectDState: map[string]*structs.DeploymentState{
+				tg1: {
+					DesiredTotal: 10, // no canaries because there are no destructive updates
+					PlacedAllocs: 10,
+				},
+				tg2: {
+					DesiredTotal: 10,
+					PlacedAllocs: 10,
+				},
+			},
+		},
+
+		{
+			name: "deployment with changing constriants",
+			tg1UpdateBlock: &structs.UpdateStrategy{
+				MaxParallel: 10,
+				Canary:      30,
+			},
+			existingPrevious: map[string][]int{
+				tg1: {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
+			},
+			existingRunning: map[string][]int{
+				tg1: {},
+				tg2: {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
+			},
+			existingCurrentDState: map[string]*structs.DeploymentState{
+				tg1: {},
+				tg2: {DesiredTotal: 10, PlacedAllocs: 10, HealthyAllocs: 10},
+			},
+			expectAllocs: map[string]int{
+				tg1: 3, // 3 canaries
+			},
+			expectStop: map[string]int{
+				tg1: 4, // 3 for canaries, 1 for infeasible
+			},
+			expectDState: map[string]*structs.DeploymentState{
+				tg1: {
+					DesiredTotal:    9, // one node will not match constraint
+					DesiredCanaries: 3,
+					PlacedCanaries:  []string{"1", "2", "3"},
+					PlacedAllocs:    3,
+				},
+				tg2: {
+					DesiredTotal: 10, // already deployed, constraint doesn't matter
+					PlacedAllocs: 10,
+				},
+			},
+			initialJobModify: func(job *structs.Job) {
+				job.Constraints = []*structs.Constraint{
+					{
+						LTarget: "${meta.testing}",
+						RTarget: "one",
+						Operand: "=",
+					},
+				}
+			},
+			updateJobModify: func(job *structs.Job) {
+				job.Constraints = []*structs.Constraint{
+					{
+						LTarget: "${meta.testing}",
+						RTarget: "two",
+						Operand: "=",
+					},
+				}
+			},
+			nodesModify: func(nodes []*structs.Node) {
+				for _, node := range nodes {
+					node.Meta["testing"] = "two"
+				}
+				nodes[0].Meta["testing"] = "one"
+			},
 		},
 	}
 
@@ -3812,8 +3911,11 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 			h := tests.NewHarness(t)
 			nodes := createNodes(t, h, 10)
 
-			for i := range tc.ineligibleNodes {
-				nodes[i].SchedulingEligibility = structs.NodeSchedulingIneligible
+			if tc.nodesModify != nil {
+				tc.nodesModify(nodes)
+				for _, node := range nodes {
+					must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), node))
+				}
 			}
 
 			oldJob := mock.SystemJob()
@@ -3833,6 +3935,10 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 					Label: "http", Value: 9876, HostNetwork: "default"}},
 			}}
 
+			if tc.initialJobModify != nil {
+				tc.initialJobModify(oldJob)
+			}
+
 			must.NoError(t, h.State.UpsertJob(
 				structs.MsgTypeTestSetup, h.NextIndex(), nil, oldJob))
 
@@ -3843,6 +3949,11 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 			idx := h.NextIndex()
 			job.CreateIndex = idx
 			job.JobModifyIndex = idx
+
+			if tc.updateJobModify != nil {
+				tc.updateJobModify(job)
+			}
+
 			must.NoError(t, h.State.UpsertJob(
 				structs.MsgTypeTestSetup, idx, nil, job))
 
@@ -3872,7 +3983,7 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 						alloc.TaskResources["web"].Networks = nil
 					}
 					alloc.Job = oldJob
-					alloc.JobID = job.ID
+					alloc.JobID = oldJob.ID
 					alloc.TaskGroup = tg
 					alloc.Name = fmt.Sprintf("my-job.%s[0]", tg)
 					alloc.ClientStatus = structs.AllocClientStatusRunning
@@ -3946,8 +4057,10 @@ func TestSystemSched_UpdateBlock(t *testing.T) {
 				}
 			}
 
-			must.NoError(t, h.State.UpsertAllocs(structs.MsgTypeTestSetup, h.NextIndex(),
-				existAllocs))
+			if len(existAllocs) > 0 {
+				must.NoError(t, h.State.UpsertAllocs(structs.MsgTypeTestSetup, h.NextIndex(),
+					existAllocs))
+			}
 
 			if len(tc.existingCurrentDState) > 0 {
 				d := mock.Deployment()
@@ -4099,6 +4212,7 @@ func TestSystemSched_evictUnneededCanaries(t *testing.T) {
 			for _, a := range s.plan.NodeAllocation {
 				allocsOnNodes = append(allocsOnNodes, a...)
 			}
+			// TODO: this test is flaky since it depends on map ordering which is not supported
 			must.SliceContainsAllFunc(t, allocsOnNodes, tt.expectedNodeAllocation,
 				func(a *structs.Allocation, id string) bool {
 					return a.ID == id
@@ -4166,7 +4280,8 @@ func TestSystemSched_NoOpEvalWithInfeasibleNodes(t *testing.T) {
 	must.NoError(t, err)
 	must.Len(t, 1, h.Plans)
 	plan := h.Plans[0]
-	must.Nil(t, plan.Deployment, must.Sprintf("expected no new deployment"))
+	must.NotNil(t, plan.Deployment, must.Sprintf("expected a deployment"))
+	must.Eq(t, d.ID, plan.Deployment.ID, must.Sprintf("expected deployment to not be a new deployment"))
 	must.Eq(t, 2, plan.Annotations.DesiredTGUpdates["web"].InPlaceUpdate)
 	must.MapLen(t, 0, plan.NodeUpdate, must.Sprintf("expected no stops"))
 	must.MapLen(t, 2, plan.NodeAllocation)
@@ -4252,3 +4367,87 @@ func TestSystemSched_CanariesWithInfeasibleNodes(t *testing.T) {
 	must.Eq(t, 2, plan.Annotations.DesiredTGUpdates["web"].Canary,
 		must.Sprintf("expected canaries: %#v", plan.Annotations.DesiredTGUpdates))
 }
+
+func TestSystemSched_CanariesWithInfeasibleNodesLimit(t *testing.T) {
+	ci.Parallel(t)
+	h := tests.NewHarness(t)
+
+	nodes := make([]*structs.Node, 2)
+	feasible := []string{}
+	for i := range 2 {
+		node := mock.Node()
+		feasible = append(feasible, node.ID)
+		nodes[i] = node
+		must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), node))
+	}
+
+	job := mock.SystemJob()
+	job.TaskGroups[0].Update = &structs.UpdateStrategy{
+		MaxParallel: 1,
+		Canary:      50, // blue-green
+	}
+	must.NoError(t, h.State.UpsertJob(structs.MsgTypeTestSetup, h.NextIndex(), nil, job))
+
+	existingAllocIDs := []string{}
+	allocs := []*structs.Allocation{}
+	for _, feasibleNode := range feasible {
+		alloc := mock.MinAllocForJob(job)
+		alloc.ClientStatus = structs.AllocClientStatusRunning
+		alloc.NodeID = feasibleNode
+		alloc.Name = structs.AllocName(job.Name, job.TaskGroups[0].Name, 0)
+		existingAllocIDs = append(existingAllocIDs, alloc.ID)
+		allocs = append(allocs, alloc)
+	}
+	must.NoError(t, h.State.UpsertAllocs(structs.MsgTypeTestSetup, h.NextIndex(), allocs))
+
+	d := mock.Deployment()
+	d.JobID = job.ID
+	d.JobVersion = job.Version
+	d.Status = structs.DeploymentStatusSuccessful
+	must.NoError(t, h.State.UpsertDeployment(h.NextIndex(), d))
+
+	// make one node infeasible
+	node := nodes[1].Copy()
+	node.Attributes["kernel.name"] = "not-linux"
+	must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), node))
+
+	// destructively update the job
+
+	job = job.Copy()
+	job.TaskGroups[0].Tasks[0].Resources.CPU++
+	must.NoError(t, h.State.UpsertJob(structs.MsgTypeTestSetup, h.NextIndex(), nil, job))
+
+	eval := &structs.Evaluation{
+		Namespace:    job.Namespace,
+		ID:           uuid.Generate(),
+		Priority:     job.Priority,
+		TriggeredBy:  structs.EvalTriggerJobRegister,
+		JobID:        job.ID,
+		Status:       structs.EvalStatusPending,
+		AnnotatePlan: true,
+	}
+	must.NoError(t, h.State.UpsertEvals(
+		structs.MsgTypeTestSetup, h.NextIndex(), []*structs.Evaluation{eval}))
+
+	err := h.Process(NewSystemScheduler, eval)
+	must.NoError(t, err)
+	must.Len(t, 1, h.Plans)
+	plan := h.Plans[0]
+	must.NotNil(t, plan.Deployment, must.Sprintf("expected a new deployment"))
+
+	dstate := plan.Deployment.TaskGroups["web"]
+	test.Len(t, 1, dstate.PlacedCanaries, test.Sprint("placed canaries"))
+	test.Eq(t, 1, dstate.DesiredCanaries, test.Sprint("desired canaries"))
+	test.Eq(t, 1, dstate.DesiredTotal, test.Sprint("desired total"))
+
+	// feasible node should get canary
+	test.Len(t, 1, plan.NodeAllocation[nodes[0].ID], test.Sprint("placed on feasible node"))
+	test.Len(t, 1, plan.NodeUpdate[nodes[0].ID], test.Sprint("stopped on feasible node"))
+
+	// infeasible node should have its alloc stopped
+	test.Len(t, 0, plan.NodeAllocation[nodes[1].ID], test.Sprint("placed on infeasible node"))
+	test.Len(t, 1, plan.NodeUpdate[nodes[1].ID], test.Sprint("stopped on infeasible node"))
+
+	must.Eq(t, 1, plan.Annotations.DesiredTGUpdates["web"].Canary,
+		must.Sprintf("expected canaries: %#v", plan.Annotations.DesiredTGUpdates))
+}
diff --git a/scheduler/util_test.go b/scheduler/util_test.go
--- a/scheduler/util_test.go
+++ b/scheduler/util_test.go
@@ -728,7 +728,7 @@ func TestInplaceUpdate_ChangedTaskGroup(t *testing.T) {
 	stack := feasible.NewGenericStack(false, ctx)
 
 	// Do the inplace update.
-	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.True(t, len(unplaced) == 1 && len(inplace) == 0, must.Sprint("inplaceUpdate incorrectly did an inplace update"))
 	must.MapEmpty(t, ctx.Plan().NodeAllocation, must.Sprint("inplaceUpdate incorrectly did an inplace update"))
@@ -782,7 +782,7 @@ func TestInplaceUpdate_AllocatedResources(t *testing.T) {
 	stack := feasible.NewGenericStack(false, ctx)
 
 	// Do the inplace update.
-	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.True(t, len(unplaced) == 0 && len(inplace) == 1, must.Sprint("inplaceUpdate incorrectly did not perform an inplace update"))
 	must.MapNotEmpty(t, ctx.Plan().NodeAllocation, must.Sprint("inplaceUpdate incorrectly did an inplace update"))
@@ -840,7 +840,7 @@ func TestInplaceUpdate_NoMatch(t *testing.T) {
 	stack := feasible.NewGenericStack(false, ctx)
 
 	// Do the inplace update.
-	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.True(t, len(unplaced) == 1 && len(inplace) == 0, must.Sprint("inplaceUpdate incorrectly did an inplace update"))
 	must.MapEmpty(t, ctx.Plan().NodeAllocation, must.Sprint("inplaceUpdate incorrectly did an inplace update"))
@@ -910,7 +910,7 @@ func TestInplaceUpdate_Success(t *testing.T) {
 	stack.SetJob(job)
 
 	// Do the inplace update.
-	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.True(t, len(unplaced) == 0 && len(inplace) == 1, must.Sprint("inplaceUpdate did not do an inplace update"))
 	must.Eq(t, 1, len(ctx.Plan().NodeAllocation), must.Sprint("inplaceUpdate did not do an inplace update"))
@@ -957,7 +957,7 @@ func TestInplaceUpdate_WildcardDatacenters(t *testing.T) {
 
 	updates := []reconciler.AllocTuple{{Alloc: alloc, TaskGroup: job.TaskGroups[0]}}
 	stack := feasible.NewGenericStack(false, ctx)
-	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	unplaced, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.Len(t, 1, inplace,
 		must.Sprintf("inplaceUpdate should have an inplace update"))
@@ -1002,7 +1002,7 @@ func TestInplaceUpdate_NodePools(t *testing.T) {
 		{Alloc: alloc2, TaskGroup: job.TaskGroups[0]},
 	}
 	stack := feasible.NewGenericStack(false, ctx)
-	destructive, inplace := inplaceUpdate(ctx, eval, job, stack, updates)
+	destructive, inplace := inplaceUpdate(ctx, eval, job, stack, updates, "")
 
 	must.Len(t, 1, inplace, must.Sprint("should have an inplace update"))
 	must.Eq(t, alloc1.ID, inplace[0].Alloc.ID)
EOF_114329324912

# Ensure Go environment variables are set
export CGO_ENABLED=1
export GO111MODULE=on
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Set build tags environment variable
export GO_TAGS=hashicorpmetrics

# Run the target tests by package (recommended approach)
# This will run all tests in the scheduler package including both target test files
echo "=== Running scheduler package tests ==="
go test -v -cover -timeout=25m -count=1 -tags "${GO_TAGS}" ./scheduler/

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to determine test results
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 911b6258b47ffeefc5853f54a9f8d3e612a29d7a "scheduler/scheduler_system_test.go" "scheduler/util_test.go"

# Exit with the captured return code
exit $rc