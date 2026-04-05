#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout c9ebf01b4aa3286641eeb71e8d0337049858ccd5 "scheduler/generic_sched_test.go" "scheduler/reconciler/reconcile_cluster_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/scheduler/generic_sched_test.go b/scheduler/generic_sched_test.go
--- a/scheduler/generic_sched_test.go
+++ b/scheduler/generic_sched_test.go
@@ -2554,32 +2554,34 @@ func TestServiceSched_JobModify_CountZero(t *testing.T) {
 
 	h := tests.NewHarness(t)
 
-	// Create some nodes
 	var nodes []*structs.Node
-	for i := 0; i < 10; i++ {
+	for range 10 {
 		node := mock.Node()
 		nodes = append(nodes, node)
 		must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), node))
 	}
 
-	// Generate a fake job with allocations
 	job := mock.Job()
 	must.NoError(t, h.State.UpsertJob(structs.MsgTypeTestSetup, h.NextIndex(), nil, job))
 
+	// allocations w/ DesiredStatus=run that we expect to stop
 	var allocs []*structs.Allocation
-	for i := 0; i < 10; i++ {
+	for i := range 10 {
 		alloc := mock.Alloc()
 		alloc.Job = job
 		alloc.JobID = job.ID
 		alloc.NodeID = nodes[i].ID
 		alloc.Name = structs.AllocName(alloc.JobID, alloc.TaskGroup, uint(i))
+		if i%2 == 0 {
+			alloc.ClientStatus = structs.AllocClientStatusFailed
+		}
 		allocs = append(allocs, alloc)
 	}
 	must.NoError(t, h.State.UpsertAllocs(structs.MsgTypeTestSetup, h.NextIndex(), allocs))
 
-	// Add a few terminal status allocations, these should be ignored
+	// Add a few server-terminal status allocations, these should be ignored
 	var terminal []*structs.Allocation
-	for i := 0; i < 5; i++ {
+	for i := range 5 {
 		alloc := mock.Alloc()
 		alloc.Job = job
 		alloc.JobID = job.ID
@@ -2609,44 +2611,31 @@ func TestServiceSched_JobModify_CountZero(t *testing.T) {
 
 	// Process the evaluation
 	err := h.Process(NewServiceScheduler, eval)
-	if err != nil {
-		t.Fatalf("err: %v", err)
-	}
+	must.NoError(t, err)
 
-	// Ensure a single plan
-	if len(h.Plans) != 1 {
-		t.Fatalf("bad: %#v", h.Plans)
-	}
+	must.Len(t, 1, h.Plans)
 	plan := h.Plans[0]
 
-	// Ensure the plan evicted all allocs
+	// Ensure the plan evicted all non-server-terminal allocs
 	var update []*structs.Allocation
 	for _, updateList := range plan.NodeUpdate {
 		update = append(update, updateList...)
 	}
-	if len(update) != len(allocs) {
-		t.Fatalf("bad: %#v", plan)
-	}
+	must.Eq(t, len(allocs), len(update), must.Sprintf("expected all stopped: %#v", plan))
 
-	// Ensure the plan didn't allocated
+	// Ensure the plan didn't place any allocations
 	var planned []*structs.Allocation
 	for _, allocList := range plan.NodeAllocation {
 		planned = append(planned, allocList...)
 	}
-	if len(planned) != 0 {
-		t.Fatalf("bad: %#v", plan)
-	}
+	must.Len(t, 0, planned, must.Sprintf("expected no placements: %#v", plan))
 
-	// Lookup the allocations by JobID
 	ws := memdb.NewWatchSet()
 	out, err := h.State.AllocsByJob(ws, job.Namespace, job.ID, false)
 	must.NoError(t, err)
 
-	// Ensure all allocations placed
 	out, _ = structs.FilterTerminalAllocs(out)
-	if len(out) != 0 {
-		t.Fatalf("bad: %#v", out)
-	}
+	must.Len(t, 0, out, must.Sprintf("expected no non-terminal allocs: %#v", out))
 
 	h.AssertEvalStatus(t, structs.EvalStatusComplete)
 }
@@ -4164,22 +4153,21 @@ func TestServiceSched_NodeDrain_Canaries(t *testing.T) {
 	ci.Parallel(t)
 	h := tests.NewHarness(t)
 
-	n1 := mock.Node()
-	n2 := mock.DrainNode()
-	must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), n1))
-	must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), n2))
+	node := mock.Node()
+	drainedNode := mock.DrainNode()
+	must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), node))
+	must.NoError(t, h.State.UpsertNode(structs.MsgTypeTestSetup, h.NextIndex(), drainedNode))
 
 	job := mock.Job()
 	job.TaskGroups[0].Count = 2
+	job.TaskGroups[0].Update = &structs.UpdateStrategy{Canary: 2}
 	must.NoError(t, h.State.UpsertJob(structs.MsgTypeTestSetup, h.NextIndex(), nil, job))
 
 	// previous version allocations
 	var allocs []*structs.Allocation
-	for i := 0; i < 2; i++ {
-		alloc := mock.Alloc()
-		alloc.Job = job
-		alloc.JobID = job.ID
-		alloc.NodeID = n1.ID
+	for i := range 2 {
+		alloc := mock.MinAllocForJob(job)
+		alloc.NodeID = node.ID
 		alloc.Name = fmt.Sprintf("my-job.web[%d]", i)
 		allocs = append(allocs, alloc)
 		t.Logf("prev alloc=%q", alloc.ID)
@@ -4190,14 +4178,11 @@ func TestServiceSched_NodeDrain_Canaries(t *testing.T) {
 	job.Meta["owner"] = "changed"
 	job.Version++
 	var canaries []string
-	for i := 0; i < 2; i++ {
-		alloc := mock.Alloc()
-		alloc.Job = job
-		alloc.JobID = job.ID
-		alloc.NodeID = n2.ID
+
+	for i := range 2 {
+		alloc := mock.MinAllocForJob(job)
+		alloc.NodeID = drainedNode.ID
 		alloc.Name = fmt.Sprintf("my-job.web[%d]", i)
-		alloc.DesiredStatus = structs.AllocDesiredStatusStop
-		alloc.ClientStatus = structs.AllocClientStatusComplete
 		alloc.DeploymentStatus = &structs.AllocDeploymentStatus{
 			Healthy: pointer.Of(false),
 			Canary:  true,
@@ -4207,24 +4192,30 @@ func TestServiceSched_NodeDrain_Canaries(t *testing.T) {
 		}
 		allocs = append(allocs, alloc)
 		canaries = append(canaries, alloc.ID)
-		t.Logf("stopped canary alloc=%q", alloc.ID)
+		t.Logf("canary on draining node=%q", alloc.ID)
 	}
 
-	// first canary placed from previous drainer eval
-	alloc := mock.Alloc()
-	alloc.Job = job
-	alloc.JobID = job.ID
-	alloc.NodeID = n2.ID
-	alloc.Name = fmt.Sprintf("my-job.web[0]")
-	alloc.ClientStatus = structs.AllocClientStatusRunning
-	alloc.PreviousAllocation = canaries[0]
-	alloc.DeploymentStatus = &structs.AllocDeploymentStatus{
+	deadCanary := allocs[2]
+	deadCanary.DesiredStatus = structs.AllocDesiredStatusStop
+	deadCanary.ClientStatus = structs.AllocClientStatusComplete
+
+	canaryToDrain := allocs[3]
+	canaryToDrain.DesiredStatus = structs.AllocDesiredStatusRun
+	canaryToDrain.ClientStatus = structs.AllocClientStatusRunning
+
+	// replacement canary placed from previous eval
+	replacement := mock.MinAllocForJob(job)
+	replacement.NodeID = node.ID
+	replacement.Name = fmt.Sprintf("my-job.web[0]")
+	replacement.ClientStatus = structs.AllocClientStatusRunning
+	replacement.PreviousAllocation = canaries[0]
+	replacement.DeploymentStatus = &structs.AllocDeploymentStatus{
 		Healthy: pointer.Of(false),
 		Canary:  true,
 	}
-	allocs = append(allocs, alloc)
-	canaries = append(canaries, alloc.ID)
-	t.Logf("new canary alloc=%q", alloc.ID)
+	allocs = append(allocs, replacement)
+	canaries = append(canaries, replacement.ID)
+	t.Logf("replacement canary alloc=%q", replacement.ID)
 
 	must.NoError(t, h.State.UpsertJob(structs.MsgTypeTestSetup, h.NextIndex(), nil, job))
 	must.NoError(t, h.State.UpsertAllocs(structs.MsgTypeTestSetup, h.NextIndex(), allocs))
@@ -4248,27 +4239,29 @@ func TestServiceSched_NodeDrain_Canaries(t *testing.T) {
 	must.NoError(t, h.State.UpsertDeployment(h.NextIndex(), deployment))
 
 	eval := &structs.Evaluation{
-		Namespace:   structs.DefaultNamespace,
-		ID:          uuid.Generate(),
-		Priority:    50,
-		TriggeredBy: structs.EvalTriggerNodeUpdate,
-		JobID:       job.ID,
-		NodeID:      n2.ID,
-		Status:      structs.EvalStatusPending,
+		Namespace:    structs.DefaultNamespace,
+		ID:           uuid.Generate(),
+		Priority:     50,
+		TriggeredBy:  structs.EvalTriggerNodeUpdate,
+		JobID:        job.ID,
+		NodeID:       drainedNode.ID,
+		Status:       structs.EvalStatusPending,
+		AnnotatePlan: true,
 	}
 	must.NoError(t, h.State.UpsertEvals(structs.MsgTypeTestSetup,
 		h.NextIndex(), []*structs.Evaluation{eval}))
 
 	must.NoError(t, h.Process(NewServiceScheduler, eval))
 	must.Len(t, 1, h.Plans)
 	h.AssertEvalStatus(t, structs.EvalStatusComplete)
-	must.MapLen(t, 0, h.Plans[0].NodeAllocation)
-	must.MapLen(t, 1, h.Plans[0].NodeUpdate)
-	must.Len(t, 2, h.Plans[0].NodeUpdate[n2.ID])
 
-	for _, alloc := range h.Plans[0].NodeUpdate[n2.ID] {
-		must.SliceContains(t, canaries, alloc.ID)
-	}
+	must.MapLen(t, 1, h.Plans[0].NodeAllocation)
+	must.Len(t, 1, h.Plans[0].NodeAllocation[node.ID])
+	must.Eq(t, 1, h.Plans[0].Annotations.DesiredTGUpdates["web"].Canary)
+
+	must.MapLen(t, 1, h.Plans[0].NodeUpdate)
+	must.Len(t, 1, h.Plans[0].NodeUpdate[drainedNode.ID])
+	must.Eq(t, canaryToDrain.ID, h.Plans[0].NodeUpdate[drainedNode.ID][0].ID)
 }
 
 func TestServiceSched_NodeDrain_Queued_Allocations(t *testing.T) {
diff --git a/scheduler/reconciler/reconcile_cluster_test.go b/scheduler/reconciler/reconcile_cluster_test.go
--- a/scheduler/reconciler/reconcile_cluster_test.go
+++ b/scheduler/reconciler/reconcile_cluster_test.go
@@ -6,12 +6,13 @@ package reconciler
 import (
 	"fmt"
 	"regexp"
+	"slices"
 	"strconv"
 	"testing"
 	"time"
 
-	"github.com/hashicorp/go-set/v3"
 	"github.com/hashicorp/nomad/ci"
+	"github.com/hashicorp/nomad/helper"
 	"github.com/hashicorp/nomad/helper/pointer"
 	"github.com/hashicorp/nomad/helper/testlog"
 	"github.com/hashicorp/nomad/helper/uuid"
@@ -5415,15 +5416,19 @@ func TestReconciler_Batch_Rerun(t *testing.T) {
 
 	// Create 10 allocations from the old job and have them be complete
 	var allocs []*structs.Allocation
-	for i := 0; i < 10; i++ {
+	for i := range 10 {
 		alloc := mock.Alloc()
 		alloc.Job = job
 		alloc.JobID = job.ID
 		alloc.NodeID = uuid.Generate()
 		alloc.Name = structs.AllocName(job.ID, job.TaskGroups[0].Name, uint(i))
 		alloc.TaskGroup = job.TaskGroups[0].Name
 		alloc.ClientStatus = structs.AllocClientStatusComplete
-		alloc.DesiredStatus = structs.AllocDesiredStatusStop
+		if i%2 == 0 {
+			alloc.DesiredStatus = structs.AllocDesiredStatusStop
+		} else {
+			alloc.DesiredStatus = structs.AllocDesiredStatusRun
+		}
 		allocs = append(allocs, alloc)
 	}
 
@@ -5456,7 +5461,7 @@ func TestReconciler_Batch_Rerun(t *testing.T) {
 			job.TaskGroups[0].Name: {
 				Place:             10,
 				DestructiveUpdate: 0,
-				Ignore:            10,
+				Ignore:            5, // half are server-terminal
 			},
 		},
 	})
@@ -5992,36 +5997,42 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 	}
 
 	type testCase struct {
-		name                         string
-		allocCount                   int
-		disconnectedAllocCount       int
-		disconnectedAllocStatus      string
-		disconnectedAllocStates      []*structs.AllocState
-		isBatch                      bool
-		nodeStatusDisconnected       bool
-		replace                      bool
-		failReplacement              bool
-		taintReplacement             bool
-		disconnectReplacement        bool
-		replaceFailedReplacement     bool
-		shouldStopOnDisconnectedNode bool
-		shouldStopOnReconnect        bool
-		maxDisconnect                *time.Duration
-		expected                     *resultExpectation
-		pickResult                   string
-		reconcileStrategy            string
-		callPicker                   bool
+		name string
+
+		// job and node
+		isBatch            bool
+		disconnect         *structs.DisconnectStrategy
+		pickResult         string
+		isNodeDisconnected bool
+
+		// allocs
+		allocCount              int
+		allocDesiredStatus      string
+		disconnectedAllocCount  int
+		disconnectedAllocStatus string
+		disconnectedAllocStates []*structs.AllocState
+
+		// replacement allocs
+		createReplacements       bool
+		failReplacement          bool
+		taintReplacement         bool
+		disconnectReplacement    bool
+		replaceFailedReplacement bool
+
+		// assertions
+		expected             *resultExpectation
+		expectStopOnTestNode bool
+		expectPickerCalled   bool
 	}
 
 	testCases := []testCase{
 		{
-			name:                         "reconnect-original-no-replacement",
-			allocCount:                   2,
-			replace:                      false,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusRunning,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: false,
+			name:                    "reconnect-original-no-replacement",
+			allocCount:              2,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  2,
+			disconnectedAllocStatus: structs.AllocClientStatusRunning,
+			disconnectedAllocStates: disconnectAllocState,
 			expected: &resultExpectation{
 				reconnectUpdates: 2,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
@@ -6031,16 +6042,21 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 					},
 				},
 			},
-			callPicker: false,
+			expectPickerCalled: false,
 		},
 		{
-			name:                         "resume-original-and-stop-replacement",
-			allocCount:                   3,
-			replace:                      true,
-			disconnectedAllocCount:       1,
-			disconnectedAllocStatus:      structs.AllocClientStatusRunning,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: false,
+			name: "resume-original-and-stop-replacement",
+			disconnect: &structs.DisconnectStrategy{
+				LostAfter: 5 * time.Minute,
+				Reconcile: structs.ReconcileOptionKeepOriginal,
+			},
+			pickResult:              "original",
+			allocCount:              3,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  1,
+			disconnectedAllocStatus: structs.AllocClientStatusRunning,
+			disconnectedAllocStates: disconnectAllocState,
+			createReplacements:      true,
 			expected: &resultExpectation{
 				stop:             1,
 				reconnectUpdates: 1,
@@ -6052,19 +6068,17 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 					},
 				},
 			},
-			maxDisconnect:     pointer.Of(5 * time.Minute),
-			callPicker:        true,
-			reconcileStrategy: structs.ReconcileOptionKeepOriginal,
-			pickResult:        "original",
+			expectPickerCalled: true,
 		},
 		{
-			name:                         "stop-original-failed-on-reconnect",
-			allocCount:                   4,
-			replace:                      true,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusFailed,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: true,
+			name:                    "stop-original-failed-on-reconnect",
+			allocCount:              4,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  2,
+			disconnectedAllocStatus: structs.AllocClientStatusFailed,
+			disconnectedAllocStates: disconnectAllocState,
+			createReplacements:      true,
+			expectStopOnTestNode:    true,
 			expected: &resultExpectation{
 				stop: 2,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
@@ -6076,13 +6090,13 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 			},
 		},
 		{
-			name:                         "reschedule-original-failed-if-not-replaced",
-			allocCount:                   4,
-			replace:                      false,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusFailed,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: true,
+			name:                    "reschedule-original-failed-if-not-replaced",
+			allocCount:              4,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  2,
+			disconnectedAllocStatus: structs.AllocClientStatusFailed,
+			disconnectedAllocStates: disconnectAllocState,
+			expectStopOnTestNode:    true,
 			expected: &resultExpectation{
 				stop:  2,
 				place: 2,
@@ -6097,12 +6111,12 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 		},
 		{
 			name:                    "update-reconnect-completed",
+			isBatch:                 true,
 			allocCount:              2,
-			replace:                 false,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
 			disconnectedAllocCount:  2,
 			disconnectedAllocStatus: structs.AllocClientStatusComplete,
 			disconnectedAllocStates: disconnectAllocState,
-			isBatch:                 true,
 			expected: &resultExpectation{
 				place: 0,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
@@ -6114,57 +6128,60 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 			},
 		},
 		{
-			name:                         "stop-original-alloc-failed-replacements-replaced",
-			allocCount:                   5,
-			replace:                      true,
-			failReplacement:              true,
-			replaceFailedReplacement:     true,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusRunning,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: false,
+			name: "second-replacements-are-reconnected",
+			disconnect: &structs.DisconnectStrategy{
+				LostAfter: time.Minute * 5,
+			},
+			allocCount:               5,
+			allocDesiredStatus:       structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:   2,
+			disconnectedAllocStatus:  structs.AllocClientStatusRunning,
+			disconnectedAllocStates:  disconnectAllocState,
+			createReplacements:       true,
+			failReplacement:          true,
+			replaceFailedReplacement: true,
 			expected: &resultExpectation{
-				stop: 2,
+				stop:             2,
+				reconnectUpdates: 2,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
 					"web": {
-						Stop:   2,
-						Ignore: 7,
+						Stop:      2,
+						Ignore:    5,
+						Reconnect: 2,
 					},
 				},
 			},
-			reconcileStrategy: structs.ReconcileOptionBestScore,
-			callPicker:        true,
 		},
 		{
-			name:                         "stop-original-alloc-desired-status-stop",
-			allocCount:                   1,
-			replace:                      true,
-			failReplacement:              true,
-			replaceFailedReplacement:     true,
-			disconnectedAllocCount:       1,
-			disconnectedAllocStatus:      structs.AllocClientStatusRunning,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: false,
-			shouldStopOnReconnect:        true,
+			name:                     "stop-original-alloc-desired-status-stop",
+			allocCount:               1,
+			allocDesiredStatus:       structs.AllocDesiredStatusStop,
+			disconnectedAllocCount:   1,
+			disconnectedAllocStatus:  structs.AllocClientStatusRunning,
+			disconnectedAllocStates:  disconnectAllocState,
+			createReplacements:       true,
+			failReplacement:          true,
+			replaceFailedReplacement: true,
 			expected: &resultExpectation{
-				stop: 1,
+				stop: 0,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
 					"web": {
-						Stop:   1,
-						Ignore: 2,
+						Stop:   0,
+						Ignore: 1,
 					},
 				},
 			},
 		},
 		{
-			name:                         "stop-original-pending-alloc-for-disconnected-node",
-			allocCount:                   2,
-			replace:                      true,
-			disconnectedAllocCount:       1,
-			disconnectedAllocStatus:      structs.AllocClientStatusPending,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: true,
-			nodeStatusDisconnected:       true,
+			name:                    "stop-original-pending-alloc-for-disconnected-node",
+			isNodeDisconnected:      true,
+			allocCount:              2,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  1,
+			disconnectedAllocStatus: structs.AllocClientStatusPending,
+			disconnectedAllocStates: disconnectAllocState,
+			createReplacements:      true,
+			expectStopOnTestNode:    true,
 			expected: &resultExpectation{
 				stop: 1,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
@@ -6176,14 +6193,15 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 			},
 		},
 		{
-			name:                         "stop-failed-original-and-failed-replacements-and-place-new",
-			allocCount:                   5,
-			replace:                      true,
-			failReplacement:              true,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusFailed,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: true,
+			name:                    "stop-failed-original-and-failed-replacements-and-place-new",
+			allocCount:              5,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  2,
+			disconnectedAllocStatus: structs.AllocClientStatusFailed,
+			disconnectedAllocStates: disconnectAllocState,
+			createReplacements:      true,
+			failReplacement:         true,
+			expectStopOnTestNode:    true,
 			expected: &resultExpectation{
 				stop:  4,
 				place: 2,
@@ -6197,15 +6215,18 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 			},
 		},
 		{
-			name:                         "stop-expired-allocs",
-			allocCount:                   5,
-			replace:                      true,
-			disconnectedAllocCount:       2,
-			disconnectedAllocStatus:      structs.AllocClientStatusUnknown,
-			disconnectedAllocStates:      disconnectAllocState,
-			shouldStopOnDisconnectedNode: true,
-			nodeStatusDisconnected:       true,
-			maxDisconnect:                pointer.Of(2 * time.Second),
+			name: "stop-expired-allocs",
+			disconnect: &structs.DisconnectStrategy{
+				LostAfter: 2 * time.Second,
+			},
+			isNodeDisconnected:      true,
+			allocCount:              5,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
+			disconnectedAllocCount:  2,
+			disconnectedAllocStatus: structs.AllocClientStatusUnknown,
+			disconnectedAllocStates: disconnectAllocState,
+			createReplacements:      true,
+			expectStopOnTestNode:    true,
 			expected: &resultExpectation{
 				stop: 2,
 				desiredTGUpdates: map[string]*structs.DesiredUpdates{
@@ -6218,12 +6239,12 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 		},
 		{
 			name:                    "replace-allocs-on-disconnected-node",
+			isNodeDisconnected:      true,
 			allocCount:              5,
-			replace:                 false,
+			allocDesiredStatus:      structs.AllocDesiredStatusRun,
 			disconnectedAllocCount:  2,
 			disconnectedAllocStatus: structs.AllocClientStatusRunning,
 			disconnectedAllocStates: []*structs.AllocState{},
-			nodeStatusDisconnected:  true,
 			expected: &resultExpectation{
 				place:             2,
 				disconnectUpdates: 2,
@@ -6243,55 +6264,37 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 		t.Run(tc.name, func(t *testing.T) {
 
 			testNode := mock.Node()
-			if tc.nodeStatusDisconnected == true {
+			if tc.isNodeDisconnected == true {
 				testNode.Status = structs.NodeStatusDisconnected
 			}
 
-			// Create resumable allocs
-			job, allocs := buildResumableAllocations(tc.allocCount, structs.AllocClientStatusRunning, structs.AllocDesiredStatusRun, 2)
-
-			origAllocs := set.New[string](len(allocs))
-			for _, alloc := range allocs {
-				origAllocs.Insert(alloc.ID)
-			}
-
+			job, allocs := buildResumableAllocations(
+				tc.allocCount, structs.AllocClientStatusRunning, tc.allocDesiredStatus, 2)
 			if tc.isBatch {
 				job.Type = structs.JobTypeBatch
 			}
+			if tc.disconnect != nil {
+				job.TaskGroups[0].Disconnect = tc.disconnect
+			}
 
-			// Set alloc state
-			disconnectedAllocCount := tc.disconnectedAllocCount
-			for _, alloc := range allocs {
-				if tc.shouldStopOnReconnect {
-					alloc.DesiredStatus = structs.AllocDesiredStatusStop
-				} else {
-					alloc.DesiredStatus = structs.AllocDesiredStatusRun
-				}
-
-				if tc.maxDisconnect != nil {
-					alloc.Job.TaskGroups[0].Disconnect = &structs.DisconnectStrategy{
-						LostAfter: *tc.maxDisconnect,
-						Reconcile: tc.reconcileStrategy,
-					}
-				}
+			origAllocs := helper.ConvertSlice(
+				allocs, func(a *structs.Allocation) string { return a.ID })
 
-				if disconnectedAllocCount > 0 {
-					alloc.ClientStatus = tc.disconnectedAllocStatus
-					alloc.AllocStates = tc.disconnectedAllocStates
-					// Set the node id on all the disconnected allocs to the node under test.
-					alloc.NodeID = testNode.ID
-					alloc.NodeName = "disconnected"
-					disconnectedAllocCount--
-				}
+			// Make some of the nodes disconnected
+			for _, alloc := range allocs[:tc.disconnectedAllocCount] {
+				alloc.ClientStatus = tc.disconnectedAllocStatus
+				alloc.AllocStates = tc.disconnectedAllocStates
+				alloc.NodeID = testNode.ID
 			}
 
-			// Place the allocs on another node.
-			if tc.replace {
+			// Build replacements for disconnected allocs on another node
+			if tc.createReplacements {
 				replacements := make([]*structs.Allocation, 0)
 				for _, alloc := range allocs {
 					if alloc.NodeID != testNode.ID {
 						continue
 					}
+
 					replacement := alloc.Copy()
 					replacement.ID = uuid.Generate()
 					replacement.NodeID = uuid.Generate()
@@ -6333,8 +6336,8 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 			}
 
 			now := time.Now()
-			if tc.maxDisconnect != nil {
-				now = time.Now().Add(*tc.maxDisconnect * 20)
+			if tc.disconnect != nil {
+				now = time.Now().Add(tc.disconnect.LostAfter * 20)
 			}
 
 			reconciler := NewAllocReconciler(
@@ -6360,16 +6363,20 @@ func TestReconciler_Disconnected_Client(t *testing.T) {
 
 			assertResults(t, results, tc.expected)
 
-			must.Eq(t, tc.reconcileStrategy, mpc.strategy)
-			must.Eq(t, tc.callPicker, mpc.called)
+			if tc.disconnect != nil {
+				must.Eq(t, tc.disconnect.Reconcile, mpc.strategy)
+			} else {
+				must.Eq(t, "", mpc.strategy)
+			}
+			must.Eq(t, tc.expectPickerCalled, mpc.called)
 
 			for _, stopResult := range results.Stop {
 				// Skip replacement allocs.
-				if !origAllocs.Contains(stopResult.Alloc.ID) {
+				if !slices.Contains(origAllocs, stopResult.Alloc.ID) {
 					continue
 				}
 
-				if tc.shouldStopOnDisconnectedNode {
+				if tc.expectStopOnTestNode {
 					must.Eq(t, testNode.ID, stopResult.Alloc.NodeID)
 				}
 
@@ -6680,7 +6687,7 @@ func TestReconciler_Client_Disconnect_Canaries(t *testing.T) {
 					updatedJob.TaskGroups[0].Name: {
 						Place:         3,
 						Canary:        0,
-						Ignore:        6,
+						Ignore:        3,
 						Disconnect:    3,
 						RescheduleNow: 3,
 					},
@@ -6746,7 +6753,7 @@ func TestReconciler_Client_Disconnect_Canaries(t *testing.T) {
 					updatedJob.TaskGroups[0].Name: {
 						Place:         2,
 						Canary:        0,
-						Ignore:        7,
+						Ignore:        4,
 						Disconnect:    2,
 						RescheduleNow: 2,
 					},
@@ -6814,7 +6821,7 @@ func TestReconciler_Client_Disconnect_Canaries(t *testing.T) {
 					updatedJob.TaskGroups[0].Name: {
 						Place:  2,
 						Canary: 0,
-						Ignore: 6,
+						Ignore: 3,
 						// The 2 stops in this test are transient failures, but
 						// the deployment can still progress. We don't include
 						// them in the stop count since DesiredTGUpdates is used
EOF_114329324912

# Run the target tests using go test
# We need to test two different packages:
# 1. scheduler/generic_sched_test.go is in the scheduler package
# 2. scheduler/reconciler/reconcile_cluster_test.go is in the scheduler/reconciler package
# Running them together in one command for efficiency

go test -v -timeout=25m -count=1 \
    github.com/hashicorp/nomad/scheduler \
    github.com/hashicorp/nomad/scheduler/reconciler

# Capture exit code immediately
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout c9ebf01b4aa3286641eeb71e8d0337049858ccd5 "scheduler/generic_sched_test.go" "scheduler/reconciler/reconcile_cluster_test.go"