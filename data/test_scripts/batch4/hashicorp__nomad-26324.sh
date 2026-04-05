#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 61cb8f6f108c3404c31faa9e6ad787dbab6603ba "scheduler/reconciler/allocs_test.go" "scheduler/reconciler/reconcile_cluster_prop_test.go" "scheduler/reconciler/reconcile_cluster_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/scheduler/reconciler/allocs_test.go b/scheduler/reconciler/allocs_test.go
--- a/scheduler/reconciler/allocs_test.go
+++ b/scheduler/reconciler/allocs_test.go
@@ -1307,7 +1307,7 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 			for _, tc := range testCases {
 				t.Run(tc.name, func(t *testing.T) {
 					// With tainted nodes
-					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired := filterByTainted(tc.all, tc.state)
+					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired := tc.all.filterByTainted(tc.state)
 					must.Eq(t, tc.untainted, untainted, must.Sprintf("with-nodes: untainted"))
 					must.Eq(t, tc.migrate, migrate, must.Sprintf("with-nodes: migrate"))
 					must.Eq(t, tc.lost, lost, must.Sprintf("with-nodes: lost"))
@@ -1323,7 +1323,7 @@ func TestAllocSet_filterByTainted(t *testing.T) {
 					// Now again with nodes nil
 					state := tc.state
 					state.TaintedNodes = nil
-					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired = filterByTainted(tc.all, state)
+					untainted, migrate, lost, disconnecting, reconnecting, ignore, expired = tc.all.filterByTainted(state)
 					must.Eq(t, tc.untainted, untainted, must.Sprintf("with-nodes: untainted"))
 					must.Eq(t, tc.migrate, migrate, must.Sprintf("with-nodes: migrate"))
 					must.Eq(t, tc.lost, lost, must.Sprintf("with-nodes: lost"))
@@ -1497,7 +1497,7 @@ func TestReconcile_shouldFilter(t *testing.T) {
 func TestBitmapFrom(t *testing.T) {
 	ci.Parallel(t)
 
-	input := map[string]*structs.Allocation{
+	input := allocSet{
 		"8": {
 			JobID:     "foo",
 			TaskGroup: "bar",
@@ -1525,7 +1525,7 @@ func Test_allocNameIndex_Highest(t *testing.T) {
 		{
 			name: "select 1",
 			inputAllocNameIndex: newAllocNameIndex(
-				"example", "cache", 3, map[string]*structs.Allocation{
+				"example", "cache", 3, allocSet{
 					"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 						Name:      "example.cache[0]",
 						JobID:     "example",
@@ -1550,7 +1550,7 @@ func Test_allocNameIndex_Highest(t *testing.T) {
 		{
 			name: "select all",
 			inputAllocNameIndex: newAllocNameIndex(
-				"example", "cache", 3, map[string]*structs.Allocation{
+				"example", "cache", 3, allocSet{
 					"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 						Name:      "example.cache[0]",
 						JobID:     "example",
@@ -1577,7 +1577,7 @@ func Test_allocNameIndex_Highest(t *testing.T) {
 		{
 			name: "select too many",
 			inputAllocNameIndex: newAllocNameIndex(
-				"example", "cache", 3, map[string]*structs.Allocation{
+				"example", "cache", 3, allocSet{
 					"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 						Name:      "example.cache[0]",
 						JobID:     "example",
@@ -1624,7 +1624,7 @@ func Test_allocNameIndex_NextCanaries(t *testing.T) {
 		{
 			name: "single canary",
 			inputAllocNameIndex: newAllocNameIndex(
-				"example", "cache", 3, map[string]*structs.Allocation{
+				"example", "cache", 3, allocSet{
 					"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 						Name:      "example.cache[0]",
 						JobID:     "example",
@@ -1643,7 +1643,7 @@ func Test_allocNameIndex_NextCanaries(t *testing.T) {
 				}),
 			inputN:        1,
 			inputExisting: nil,
-			inputDestructive: map[string]*structs.Allocation{
+			inputDestructive: allocSet{
 				"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 					Name:      "example.cache[0]",
 					JobID:     "example",
@@ -1695,7 +1695,7 @@ func Test_allocNameIndex_Next(t *testing.T) {
 		{
 			name: "non-empty existing bitmap simple",
 			inputAllocNameIndex: newAllocNameIndex(
-				"example", "cache", 3, map[string]*structs.Allocation{
+				"example", "cache", 3, allocSet{
 					"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 						Name:      "example.cache[0]",
 						JobID:     "example",
@@ -1729,7 +1729,7 @@ func Test_allocNameIndex_Next(t *testing.T) {
 func Test_allocNameIndex_Duplicates(t *testing.T) {
 	ci.Parallel(t)
 
-	inputAllocSet := map[string]*structs.Allocation{
+	inputAllocSet := allocSet{
 		"6b255fa3-c2cb-94de-5ddd-41aac25a6851": {
 			Name:      "example.cache[0]",
 			JobID:     "example",
diff --git a/scheduler/reconciler/reconcile_cluster_prop_test.go b/scheduler/reconciler/reconcile_cluster_prop_test.go
--- a/scheduler/reconciler/reconcile_cluster_prop_test.go
+++ b/scheduler/reconciler/reconcile_cluster_prop_test.go
@@ -227,7 +227,7 @@ func TestAllocReconciler_cancelUnneededCanaries(t *testing.T) {
 		m := newAllocMatrix(job, jobState.ExistingAllocs)
 		group := job.TaskGroups[0].Name
 		all := m[group] // <-- allocset of all allocs for tg
-		all, _ = filterOldTerminalAllocs(jobState, all)
+		all, _ = all.filterOldTerminalAllocs(jobState)
 
 		// runs the method under test
 		canaries, _, stopAllocs := ar.cancelUnneededCanaries(all, new(structs.DesiredUpdates))
@@ -257,7 +257,7 @@ func TestAllocReconciler_cancelUnneededCanaries(t *testing.T) {
 			}
 		}
 		canarySet := all.fromKeys(expectedCanaries)
-		canariesOnUntaintedNodes, migrate, lost, _, _, _, _ := filterByTainted(canarySet, clusterState)
+		canariesOnUntaintedNodes, migrate, lost, _, _, _, _ := canarySet.filterByTainted(clusterState)
 
 		stopSet = stopSet.union(migrate, lost)
 
diff --git a/scheduler/reconciler/reconcile_cluster_test.go b/scheduler/reconciler/reconcile_cluster_test.go
--- a/scheduler/reconciler/reconcile_cluster_test.go
+++ b/scheduler/reconciler/reconcile_cluster_test.go
@@ -238,7 +238,7 @@ func stopResultsToNames(stop []AllocStopResult) []string {
 	return names
 }
 
-func attributeUpdatesToNames(attributeUpdates map[string]*structs.Allocation) []string {
+func attributeUpdatesToNames(attributeUpdates allocSet) []string {
 	names := make([]string, 0, len(attributeUpdates))
 	for _, a := range attributeUpdates {
 		names = append(names, a.Name)
EOF_114329324912

# Set build tags environment variable
export GO_TAGS=hashicorpmetrics

# Run the target tests
# All three test files are in the same package, so we can run them in a single command
# Using go test directly with the package path and timeout settings
go test -v -cover -timeout=25m -count=1 -tags "${GO_TAGS}" ./scheduler/reconciler/

# Capture exit code immediately
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 61cb8f6f108c3404c31faa9e6ad787dbab6603ba "scheduler/reconciler/allocs_test.go" "scheduler/reconciler/reconcile_cluster_prop_test.go" "scheduler/reconciler/reconcile_cluster_test.go"