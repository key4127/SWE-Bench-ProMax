#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 4e0ca7c2bad4ecbac68086fe2497b42f0d9cfd00 "agent/deltatracker/deltatracker_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/agent/deltatracker/deltatracker_test.go b/agent/deltatracker/deltatracker_test.go
--- a/agent/deltatracker/deltatracker_test.go
+++ b/agent/deltatracker/deltatracker_test.go
@@ -1,11 +1,28 @@
+// Package deltatracker provides a tracker for calculating differences in numeric values over time.
 package deltatracker
 
 import (
+	"fmt"
 	"testing"
 
 	"github.com/stretchr/testify/assert"
 )
 
+func ExampleDeltaTracker() {
+	tracker := NewDeltaTracker[string, int]()
+	tracker.Set("key1", 10)
+	tracker.Set("key2", 20)
+	tracker.Cycle()
+	tracker.Set("key1", 15)
+	tracker.Set("key2", 30)
+	fmt.Println(tracker.Delta("key1"))
+	fmt.Println(tracker.Delta("key2"))
+	fmt.Println(tracker.Deltas())
+	// Output: 5
+	// 10
+	// map[key1:5 key2:10]
+}
+
 func TestNewDeltaTracker(t *testing.T) {
 	tracker := NewDeltaTracker[string, int]()
 	assert.NotNil(t, tracker)
@@ -17,8 +34,8 @@ func TestSet(t *testing.T) {
 	tracker := NewDeltaTracker[string, int]()
 	tracker.Set("key1", 10)
 
-	tracker.mu.RLock()
-	defer tracker.mu.RUnlock()
+	tracker.RLock()
+	defer tracker.RUnlock()
 
 	assert.Equal(t, 10, tracker.current["key1"])
 }
@@ -55,21 +72,21 @@ func TestCycle(t *testing.T) {
 	tracker.Set("key2", 20)
 
 	// Verify current has values
-	tracker.mu.RLock()
+	tracker.RLock()
 	assert.Equal(t, 10, tracker.current["key1"])
 	assert.Equal(t, 20, tracker.current["key2"])
 	assert.Empty(t, tracker.previous)
-	tracker.mu.RUnlock()
+	tracker.RUnlock()
 
 	tracker.Cycle()
 
 	// After cycle, previous should have the old current values
 	// and current should be empty
-	tracker.mu.RLock()
+	tracker.RLock()
 	assert.Empty(t, tracker.current)
 	assert.Equal(t, 10, tracker.previous["key1"])
 	assert.Equal(t, 20, tracker.previous["key2"])
-	tracker.mu.RUnlock()
+	tracker.RUnlock()
 }
 
 func TestCompleteWorkflow(t *testing.T) {
EOF_114329324912

# Set Go environment variables as specified in the collected information
export GOEXPERIMENT=synctest
export GO111MODULE=on

# Run the specific test file with the testing build tag
# Using -v for verbose output to help with debugging
# Using -count=1 to disable test caching and ensure fresh execution
go test -v -tags=testing -count=1 ./agent/deltatracker/

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 4e0ca7c2bad4ecbac68086fe2497b42f0d9cfd00 "agent/deltatracker/deltatracker_test.go"