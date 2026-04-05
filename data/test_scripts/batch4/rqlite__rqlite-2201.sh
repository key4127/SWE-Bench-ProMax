#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test file to ensure clean state
git checkout 6aa3440c972e24228baf92d106c6a9b7e35e1387 "cdc/fifo_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cdc/fifo_test.go b/cdc/fifo_test.go
--- a/cdc/fifo_test.go
+++ b/cdc/fifo_test.go
@@ -48,7 +48,7 @@ func Test_EnqueueEvents_Simple(t *testing.T) {
 	// Enqueue a single item then receive it from events channel.
 	item1 := []byte("hello world")
 	idx1 := uint64(10)
-	if err := q.Enqueue(idx1, item1); err != nil {
+	if err := q.Enqueue(&Event{Index: idx1, Data: item1}); err != nil {
 		t.Fatalf("Enqueue failed: %v", err)
 	}
 
@@ -99,7 +99,7 @@ func Test_EnqueueEvents_Multi(t *testing.T) {
 	}
 
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -137,14 +137,14 @@ func Test_EnqueueHighest(t *testing.T) {
 	// Enqueue a single item
 	item1 := []byte("hello world")
 	idx1 := uint64(10)
-	if err := q.Enqueue(idx1, item1); err != nil {
+	if err := q.Enqueue(&Event{Index: idx1, Data: item1}); err != nil {
 		t.Fatalf("Enqueue failed: %v", err)
 	}
 
 	// Now insert an "older" item, it shouldn't actually be inserted.
 	item2 := []byte("older item")
 	idx2 := uint64(5)
-	if err := q.Enqueue(idx2, item2); err != nil {
+	if err := q.Enqueue(&Event{Index: idx2, Data: item2}); err != nil {
 		t.Fatalf("Enqueue of older item failed: %v", err)
 	}
 
@@ -181,7 +181,7 @@ func Test_DeleteRange(t *testing.T) {
 		{3, []byte("three")},
 	}
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -236,7 +236,7 @@ func Test_QueueHighestKey(t *testing.T) {
 		{3, []byte("three")},
 	}
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -315,7 +315,7 @@ func Test_QueuePersistence(t *testing.T) {
 	if err != nil {
 		t.Fatalf("Failed to create initial queue: %v", err)
 	}
-	if err := q1.Enqueue(idx, item); err != nil {
+	if err := q1.Enqueue(&Event{Index: idx, Data: item}); err != nil {
 		t.Fatalf("Failed to enqueue item: %v", err)
 	}
 	q1.Close()
@@ -414,7 +414,7 @@ func Test_Events_NoReader(t *testing.T) {
 	}
 
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -466,7 +466,7 @@ func Test_Events_ReaderAppearsLater(t *testing.T) {
 	}
 
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -502,7 +502,7 @@ func Test_Events_ReaderAppearsLater(t *testing.T) {
 	}
 
 	for _, item := range postItems {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for post-reader index %d: %v", item.idx, err)
 		}
 	}
@@ -550,7 +550,7 @@ func Test_Events_BufferedChannelBehavior(t *testing.T) {
 
 	// Enqueue all items
 	for _, item := range items {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -610,7 +610,7 @@ func Test_Events_InterruptedReader(t *testing.T) {
 	}
 
 	for _, item := range firstBatch {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -641,7 +641,7 @@ func Test_Events_InterruptedReader(t *testing.T) {
 	}
 
 	for _, item := range secondBatch {
-		if err := q.Enqueue(item.idx, item.data); err != nil {
+		if err := q.Enqueue(&Event{Index: item.idx, Data: item.data}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", item.idx, err)
 		}
 	}
@@ -698,7 +698,7 @@ func Test_Events_ConcurrentReaders(t *testing.T) {
 	const totalItems = numReaders * numItemsPerReader
 	for i := 1; i <= totalItems; i++ {
 		item := []byte(fmt.Sprintf("concurrent-item-%d", i))
-		if err := q.Enqueue(uint64(i), item); err != nil {
+		if err := q.Enqueue(&Event{Index: uint64(i), Data: item}); err != nil {
 			t.Fatalf("Enqueue failed for index %d: %v", i, err)
 		}
 	}
EOF_114329324912

# Execute tests for the CDC FIFO package
# Using -v for verbose output and -failfast to stop on first failure
# Testing only the target file as specified
go test -v -failfast ./cdc/fifo_test.go ./cdc/fifo.go
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 6aa3440c972e24228baf92d106c6a9b7e35e1387 "cdc/fifo_test.go"