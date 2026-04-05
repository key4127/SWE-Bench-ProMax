#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test files to ensure clean state
git checkout e166d34719e4dbc1c8befe6e358d64c67a549feb "cdc/config_test.go" "cdc/service_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cdc/config_test.go b/cdc/config_test.go
--- a/cdc/config_test.go
+++ b/cdc/config_test.go
@@ -52,17 +52,16 @@ func Test_NewConfig_InvalidURL_ValidFile(t *testing.T) {
 
 	// Create a test config
 	testConfig := &Config{
-		LogOnly:                  true,
-		Endpoint:                 "https://test.example.com/cdc",
-		MaxBatchSz:               50,
-		MaxBatchDelay:            5 * time.Second,
-		HighWatermarkingDisabled: true,
-		HighWatermarkInterval:    30 * time.Second,
-		TransmitTimeout:          10 * time.Second,
-		TransmitMaxRetries:       3,
-		TransmitRetryPolicy:      ExponentialRetryPolicy,
-		TransmitMinBackoff:       2 * time.Second,
-		TransmitMaxBackoff:       2 * time.Minute,
+		LogOnly:               true,
+		Endpoint:              "https://test.example.com/cdc",
+		MaxBatchSz:            50,
+		MaxBatchDelay:         5 * time.Second,
+		HighWatermarkInterval: 30 * time.Second,
+		TransmitTimeout:       10 * time.Second,
+		TransmitMaxRetries:    3,
+		TransmitRetryPolicy:   ExponentialRetryPolicy,
+		TransmitMinBackoff:    2 * time.Second,
+		TransmitMaxBackoff:    2 * time.Minute,
 	}
 
 	// Marshall to JSON
@@ -99,9 +98,6 @@ func Test_NewConfig_InvalidURL_ValidFile(t *testing.T) {
 	if config.MaxBatchDelay != testConfig.MaxBatchDelay {
 		t.Fatalf("Expected MaxBatchDelay %v, got %v", testConfig.MaxBatchDelay, config.MaxBatchDelay)
 	}
-	if config.HighWatermarkingDisabled != testConfig.HighWatermarkingDisabled {
-		t.Fatalf("Expected HighWatermarkingDisabled %v, got %v", testConfig.HighWatermarkingDisabled, config.HighWatermarkingDisabled)
-	}
 	if config.HighWatermarkInterval != testConfig.HighWatermarkInterval {
 		t.Fatalf("Expected HighWatermarkInterval %v, got %v", testConfig.HighWatermarkInterval, config.HighWatermarkInterval)
 	}
diff --git a/cdc/service_test.go b/cdc/service_test.go
--- a/cdc/service_test.go
+++ b/cdc/service_test.go
@@ -1,7 +1,6 @@
 package cdc
 
 import (
-	"expvar"
 	"io"
 	"net/http"
 	"net/http/httptest"
@@ -512,7 +511,7 @@ func Test_ServiceMultiEvent_Batch(t *testing.T) {
 	}, 2*time.Second)
 }
 
-func Test_ServiceHWMUpdate(t *testing.T) {
+func Test_ServiceHWMUpdate_Leader(t *testing.T) {
 	ResetStats()
 
 	// Channel to send events to the CDC Service.
@@ -586,76 +585,9 @@ func Test_ServiceHWMUpdate(t *testing.T) {
 	testPoll(t, func() bool {
 		return svc.HighWatermark() == 30
 	}, 2*time.Second)
-
-	// Check that FIFO has all 3 events
-	if svc.fifo.Len() != 3 {
-		t.Fatalf("expected FIFO to contain 3 events, got %d", svc.fifo.Len())
-	}
-
-	// Get the highest key from FIFO before HWM update to verify events are there
-	highestKeyBefore, err := svc.fifo.HighestKey()
-	if err != nil {
-		t.Fatalf("failed to get highest key from FIFO: %v", err)
-	}
-	if highestKeyBefore != 30 {
-		t.Fatalf("expected highest key to be 30, got %d", highestKeyBefore)
-	}
-
-	// Send a high-water mark update that should prune events with index <= 20
-	cl.SignalHWMUpdate(20)
-
-	// Wait for HWM update to be processed (should be ignored since 20 < 30)
-	initialCount := svc.hwmUpdated.Load()
-	testPoll(t, func() bool {
-		return svc.hwmUpdated.Load() > initialCount
-	}, 2*time.Second)
-
-	// Verify that the service's high watermark is NOT updated (because 20 < 30)
-	// The service should ignore HWM updates that are <= current HWM
-	if svc.HighWatermark() != 30 {
-		t.Fatalf("expected high watermark to remain 30, got %d", svc.HighWatermark())
-	}
-
-	// Verify that the FIFO has NOT been pruned (since HWM update was ignored)
-	if svc.fifo.Len() != 3 {
-		t.Fatalf("expected FIFO to still contain 3 events after ignored HWM update, got %d", svc.fifo.Len())
-	}
-
-	// Send a high-water mark update that should update the HWM and prune older events
-	cl.SignalHWMUpdate(35)
-
-	// Wait for HWM update to be processed
-	initialCount2 := svc.hwmUpdated.Load()
-	testPoll(t, func() bool {
-		return svc.hwmUpdated.Load() > initialCount2
-	}, 2*time.Second)
-
-	// Verify that the service's high watermark is updated
-	testPoll(t, func() bool {
-		return svc.HighWatermark() == 35
-	}, 2*time.Second)
-
-	// Verify that the FIFO has been emptied (all events <= 35 should be deleted)
-	isEmpty, err := svc.fifo.Empty()
-	if err != nil {
-		t.Fatalf("failed to check if FIFO is empty: %v", err)
-	}
-	if !isEmpty {
-		t.Fatalf("expected FIFO to be empty after HWM update to 35, but it contains %d events", svc.fifo.Len())
-	}
-
-	// The highest key should still be 30 since that's the highest event ever added,
-	// but events <= 35 should have been deleted via DeleteRange (which includes all our events)
-	highestKeyAfter, err := svc.fifo.HighestKey()
-	if err != nil {
-		t.Fatalf("failed to get highest key from FIFO after HWM update: %v", err)
-	}
-	if highestKeyAfter != 30 {
-		t.Fatalf("expected highest key to still be 30 after HWM update, got %d", highestKeyAfter)
-	}
 }
 
-func Test_ServiceHWMUpdate_BoundaryConditions(t *testing.T) {
+func Test_ServiceHWMUpdate_Follow(t *testing.T) {
 	ResetStats()
 
 	// Channel to send events to the CDC Service.
@@ -666,7 +598,7 @@ func Test_ServiceHWMUpdate_BoundaryConditions(t *testing.T) {
 	cfg := DefaultConfig()
 	cfg.MaxBatchSz = 1
 	cfg.MaxBatchDelay = 50 * time.Millisecond
-	cfg.LogOnly = true
+	cfg.LogOnly = true // Use log-only mode to avoid HTTP complexity
 	svc, err := NewService(
 		"node1",
 		t.TempDir(),
@@ -683,71 +615,39 @@ func Test_ServiceHWMUpdate_BoundaryConditions(t *testing.T) {
 	defer svc.Stop()
 
 	// Make it the leader.
-	cl.SignalLeaderChange(true)
-	testPoll(t, func() bool { return svc.IsLeader() }, 2*time.Second)
+	testPoll(t, func() bool { return !svc.IsLeader() }, 2*time.Second)
 
-	// Add an event
-	event := &proto.CDCIndexedEventGroup{
-		Index: 50,
-		Events: []*proto.CDCEvent{
-			{
-				Op:       proto.CDCEvent_INSERT,
-				Table:    "foo",
-				NewRowId: 1,
+	// Add some events to the FIFO queue
+	events := []*proto.CDCIndexedEventGroup{
+		{
+			Index: 10,
+			Events: []*proto.CDCEvent{
+				{
+					Op:       proto.CDCEvent_INSERT,
+					Table:    "foo",
+					NewRowId: 1,
+				},
 			},
 		},
 	}
-	eventsCh <- event
-
-	// Wait for event to be processed
-	testPoll(t, func() bool {
-		return svc.HighWatermark() == 50
-	}, 2*time.Second)
-
-	// Check that FIFO has 1 event
-	if svc.fifo.Len() != 1 {
-		t.Fatalf("expected FIFO to contain 1 event, got %d", svc.fifo.Len())
-	}
 
-	// Test HWM update with value higher than current HWM
-	cl.SignalHWMUpdate(60)
-	testPoll(t, func() bool {
-		return svc.HighWatermark() == 60
-	}, 2*time.Second)
-
-	// Check that FIFO has been emptied (event with index 50 should be deleted since 50 <= 60)
-	if svc.fifo.Len() != 0 {
-		t.Fatalf("expected FIFO to be empty after HWM update to 60, got %d events", svc.fifo.Len())
+	// Send events to the service
+	for _, ev := range events {
+		eventsCh <- ev
 	}
 
-	// Test HWM update with value less than current HWM
-	cl.SignalHWMUpdate(40)
-
-	// Wait for HWM update to be processed (should be ignored since 40 < 60)
-	initialCount := svc.hwmUpdated.Load()
+	// Confirm FIFO has the events
 	testPoll(t, func() bool {
-		return svc.hwmUpdated.Load() > initialCount
+		return svc.fifo.Len() == 1
 	}, 2*time.Second)
 
-	if svc.HighWatermark() != 60 {
-		t.Fatalf("expected high watermark to remain 60 when HWM update is less than current, got %d", svc.HighWatermark())
-	}
-
-	// Check that FIFO remains empty (no change since HWM update was ignored)
-	if svc.fifo.Len() != 0 {
-		t.Fatalf("expected FIFO to remain empty after ignored HWM update, got %d events", svc.fifo.Len())
-	}
-
-	// Test HWM update when service is not leader - should still work
-	cl.SignalLeaderChange(false)
-	testPoll(t, func() bool { return !svc.IsLeader() }, 2*time.Second)
-
-	// Send HWM update greater than current
-	cl.SignalHWMUpdate(70)
+	// Simulate a high watermark update from the cluster, which should
+	// prune FIFO.
+	cl.BroadcastHighWatermark(10)
 
-	// Verify that HWM is updated even when not leader
+	// Wait for events to be processed and high watermark updated
 	testPoll(t, func() bool {
-		return svc.HighWatermark() == 70
+		return svc.hwmFollowerUpdated.Load() == 1 && svc.fifo.Len() == 0 && svc.HighWatermark() == 10
 	}, 2*time.Second)
 }
 
@@ -776,32 +676,12 @@ func (m *mockCluster) SignalHWMUpdate(hwm uint64) {
 	}
 }
 
-func (m *mockCluster) SetHighWatermark(value uint64) error {
-	// Mock implementation does nothing.
-	return nil
-}
-
-func pollExpvarUntil(t *testing.T, name string, expected int64, timeout time.Duration) {
-	t.Helper()
-	ticker := time.NewTicker(10 * time.Millisecond)
-	defer ticker.Stop()
-	timer := time.NewTimer(timeout)
-	defer timer.Stop()
-	for {
-		select {
-		case <-ticker.C:
-			val := stats.Get(name)
-			if val == nil {
-				t.Fatalf("expvar %s not found", name)
-			}
-			if i, ok := val.(*expvar.Int); ok && i.Value() == expected {
-				return
-			}
-		case <-timer.C:
-			t.Fatalf("timed out waiting for expvar %s to reach %d", name, expected)
-		}
-
+func (m *mockCluster) BroadcastHighWatermark(value uint64) error {
+	if m.hwmObCh != nil {
+		m.hwmObCh <- value
+		return nil
 	}
+	return nil // No observer, nothing to do.
 }
 
 func testPoll(t *testing.T, condition func() bool, timeout time.Duration) {
@@ -821,65 +701,3 @@ func testPoll(t *testing.T, condition func() bool, timeout time.Duration) {
 		}
 	}
 }
-
-// Test_ServiceHWMPersistence tests that the high watermark persists across service restarts.
-func Test_ServiceHWMPersistence(t *testing.T) {
-	ResetStats()
-
-	// Use a temp directory for this test
-	dir := t.TempDir()
-
-	// Channel for the service to receive events
-	eventsCh := make(chan *proto.CDCIndexedEventGroup, 1)
-
-	cl := &mockCluster{}
-
-	cfg := DefaultConfig()
-	cfg.LogOnly = true // Use log-only mode to avoid HTTP server setup
-	cfg.MaxBatchSz = 1
-	cfg.MaxBatchDelay = 50 * time.Millisecond
-
-	// Create the first service
-	svc1, err := NewService("node1", dir, cl, eventsCh, cfg)
-	if err != nil {
-		t.Fatalf("failed to create first service: %v", err)
-	}
-	if err := svc1.Start(); err != nil {
-		t.Fatalf("failed to start first service: %v", err)
-	}
-
-	// Make it the leader
-	cl.SignalLeaderChange(true)
-
-	// Send an HWM update
-	testHWM := uint64(12345)
-	cl.SignalHWMUpdate(testHWM)
-
-	// Wait for HWM update to be processed
-	initialCount := svc1.hwmUpdated.Load()
-	testPoll(t, func() bool {
-		return svc1.hwmUpdated.Load() > initialCount
-	}, 2*time.Second)
-
-	// Verify that the HWM was updated
-	if svc1.HighWatermark() != testHWM {
-		t.Fatalf("expected high watermark to be %d, got %d", testHWM, svc1.HighWatermark())
-	}
-
-	// Stop the first service
-	svc1.Stop()
-
-	// Create a new service using the same directory
-	svc2, err := NewService("node1", dir, cl, eventsCh, cfg)
-	if err != nil {
-		t.Fatalf("failed to create second service: %v", err)
-	}
-
-	// Verify that the new service has the correct HWM value from the file
-	if svc2.HighWatermark() != testHWM {
-		t.Fatalf("expected new service to have high watermark %d, got %d", testHWM, svc2.HighWatermark())
-	}
-
-	// Clean up
-	svc2.Stop()
-}
EOF_114329324912

# Execute tests for the CDC package
# Using -v for verbose output and -failfast to stop on first failure
# Running at package level to ensure all source files are compiled together
go test -v -failfast ./cdc/
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e166d34719e4dbc1c8befe6e358d64c67a549feb "cdc/config_test.go" "cdc/service_test.go"