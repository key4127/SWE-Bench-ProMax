#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test file to ensure clean state
git checkout 7a513806416aa64ab272b6f448bd94c45d66c8ae "cdc/fifo_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cdc/fifo_test.go b/cdc/fifo_test.go
--- a/cdc/fifo_test.go
+++ b/cdc/fifo_test.go
@@ -43,7 +43,7 @@ func Test_EnqueueEvents_Simple(t *testing.T) {
 	defer cleanup()
 
 	// Get the events channel
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Enqueue a single item then receive it from events channel.
 	item1 := []byte("hello world")
@@ -86,7 +86,7 @@ func Test_EnqueueEvents_Multi(t *testing.T) {
 	defer cleanup()
 
 	// Get the events channel
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Enqueue multiple items
 	items := []struct {
@@ -169,7 +169,7 @@ func Test_DeleteRange(t *testing.T) {
 	}
 
 	// Get the events channel before enqueuing
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Enqueue a few items.
 	items := []struct {
@@ -286,7 +286,7 @@ func Test_Events_ChannelCloseOnQueueClose(t *testing.T) {
 	q, _, _ := newTestQueue(t) // Don't call cleanup automatically
 
 	// Get the events channel
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Close the queue
 	q.Close()
@@ -327,7 +327,7 @@ func Test_QueuePersistence(t *testing.T) {
 	}
 
 	// Get the events channel and receive the item to verify it's the one we saved.
-	eventsCh := q2.Events()
+	eventsCh := q2.C
 	select {
 	case event := <-eventsCh:
 		if !bytes.Equal(event.Data, item) {
@@ -352,7 +352,7 @@ func Test_QueuePersistence(t *testing.T) {
 	// Receive the item again from events channel, ensuring it's still available after reopening. This
 	// tests that the queue's state is persistent across closures because no deletion
 	// has occurred.
-	eventsCh = q3.Events()
+	eventsCh = q3.C
 	select {
 	case event := <-eventsCh:
 		if !bytes.Equal(event.Data, item) {
@@ -396,19 +396,6 @@ func Test_QueuePersistence(t *testing.T) {
 	q4.Close()
 }
 
-// Test_Events_SameChannelReturned tests that calling Events() multiple times returns the same channel.
-func Test_Events_SameChannelReturned(t *testing.T) {
-	q, _, cleanup := newTestQueue(t)
-	defer cleanup()
-
-	ch1 := q.Events()
-	ch2 := q.Events()
-
-	if ch1 != ch2 {
-		t.Error("Events() should return the same channel when called multiple times")
-	}
-}
-
 // Test_Events_NoReader tests that events can be enqueued when no one is reading from the Events channel.
 func Test_Events_NoReader(t *testing.T) {
 	q, _, cleanup := newTestQueue(t)
@@ -447,7 +434,7 @@ func Test_Events_NoReader(t *testing.T) {
 	}
 
 	// Now get the events channel and verify all events are available
-	eventsCh := q.Events()
+	eventsCh := q.C
 	for i, expectedItem := range items {
 		select {
 		case event := <-eventsCh:
@@ -488,7 +475,7 @@ func Test_Events_ReaderAppearsLater(t *testing.T) {
 	time.Sleep(50 * time.Millisecond)
 
 	// Now get the events channel - this should make all queued events available
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Receive all pre-queued events
 	for i, expectedItem := range items {
@@ -542,7 +529,7 @@ func Test_Events_BufferedChannelBehavior(t *testing.T) {
 	defer cleanup()
 
 	// Get events channel but don't read from it initially
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Enqueue items up to and beyond the buffer size (which is 10)
 	const numItems = 15
@@ -611,7 +598,7 @@ func Test_Events_InterruptedReader(t *testing.T) {
 	q, _, cleanup := newTestQueue(t)
 	defer cleanup()
 
-	eventsCh := q.Events()
+	eventsCh := q.C
 
 	// Enqueue first batch of items
 	firstBatch := []struct {
@@ -683,7 +670,7 @@ func Test_Events_ConcurrentReaders(t *testing.T) {
 	q, _, cleanup := newTestQueue(t)
 	defer cleanup()
 
-	eventsCh := q.Events()
+	eventsCh := q.C
 	const numReaders = 3
 	const numItemsPerReader = 5
 
EOF_114329324912

# Execute tests for the CDC package
# Running the entire cdc package to ensure all type definitions are available
# Using -v for verbose output and -timeout to prevent hanging tests
go test -v -timeout 10m ./cdc
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 7a513806416aa64ab272b6f448bd94c45d66c8ae "cdc/fifo_test.go"