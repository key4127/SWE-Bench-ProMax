#!/bin/bash
set -uxo pipefail
cd /testbed

# Store original file content before applying patch
ORIGINAL_FILE="staging/src/k8s.io/client-go/tools/cache/reflector_test.go"
cp "$ORIGINAL_FILE" "$ORIGINAL_FILE.original"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/staging/src/k8s.io/client-go/tools/cache/reflector_test.go b/staging/src/k8s.io/client-go/tools/cache/reflector_test.go
--- a/staging/src/k8s.io/client-go/tools/cache/reflector_test.go
+++ b/staging/src/k8s.io/client-go/tools/cache/reflector_test.go
@@ -31,6 +31,8 @@ import (
 	"testing"
 	"time"
 
+	"github.com/google/go-cmp/cmp"
+	"github.com/google/go-cmp/cmp/cmpopts"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 
@@ -48,6 +50,7 @@ import (
 	"k8s.io/klog/v2/ktesting"
 	"k8s.io/utils/clock"
 	testingclock "k8s.io/utils/clock/testing"
+	"k8s.io/utils/ptr"
 )
 
 var nevererrc chan error
@@ -161,8 +164,8 @@ func TestReflectorWatchStoppedBefore(t *testing.T) {
 	require.NoError(t, err)
 }
 
-// TestReflectorWatchStoppedAfter ensures that neither the watcher is stopped if
-// the stop channel is closed after Reflector.watch has started watching.
+// TestReflectorWatchStoppedAfter ensures that Reflector.watch always stops
+// the watcher when the stop channel is closed.
 func TestReflectorWatchStoppedAfter(t *testing.T) {
 	_, ctx := ktesting.NewTestContext(t)
 	ctx, cancel := context.WithCancelCause(ctx)
@@ -206,9 +209,9 @@ func BenchmarkReflectorResyncChanMany(b *testing.B) {
 	}
 }
 
-// TestReflectorHandleWatchStoppedBefore ensures that handleWatch stops when
+// TestReflectorHandleWatchStoppedBefore ensures that handleWatch returns when
 // stopCh is already closed before handleWatch was called. It also ensures that
-// ResultChan is only called once and that Stop is called after ResultChan.
+// ResultChan and Stop are both called once.
 func TestReflectorHandleWatchStoppedBefore(t *testing.T) {
 	s := NewStore(MetaNamespaceKeyFunc)
 	g := NewReflector(&ListWatch{}, &v1.Pod{}, s, 0)
@@ -218,7 +221,7 @@ func TestReflectorHandleWatchStoppedBefore(t *testing.T) {
 	cancel(errors.New("don't run"))
 	var calls []string
 	resultCh := make(chan watch.Event)
-	fw := watch.MockWatcher{
+	fw := &watch.MockWatcher{
 		StopFunc: func() {
 			calls = append(calls, "Stop")
 			close(resultCh)
@@ -229,26 +232,22 @@ func TestReflectorHandleWatchStoppedBefore(t *testing.T) {
 		},
 	}
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, g.setLastSyncResourceVersion, g.clock, nevererrc)
-	if err == nil {
-		t.Errorf("unexpected non-error")
-	}
-	// Ensure the watcher methods are called exactly once in this exact order.
-	// TODO(karlkfi): Fix watchHandler to call Stop()
-	// assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
-	assert.Equal(t, []string{"ResultChan"}, calls)
+	require.Equal(t, err, errorStopRequested)
+	// Ensure handleWatch calls ResultChan and Stop
+	assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
 }
 
-// TestReflectorHandleWatchStoppedAfter ensures that handleWatch stops when
+// TestReflectorHandleWatchStoppedAfter ensures that handleWatch returns when
 // stopCh is closed after handleWatch was called. It also ensures that
-// ResultChan is only called once and that Stop is called after ResultChan.
+// ResultChan and Stop are both called once.
 func TestReflectorHandleWatchStoppedAfter(t *testing.T) {
 	s := NewStore(MetaNamespaceKeyFunc)
 	g := NewReflector(&ListWatch{}, &v1.Pod{}, s, 0)
 	var calls []string
 	_, ctx := ktesting.NewTestContext(t)
 	ctx, cancel := context.WithCancelCause(ctx)
 	resultCh := make(chan watch.Event)
-	fw := watch.MockWatcher{
+	fw := &watch.MockWatcher{
 		StopFunc: func() {
 			calls = append(calls, "Stop")
 			close(resultCh)
@@ -266,24 +265,21 @@ func TestReflectorHandleWatchStoppedAfter(t *testing.T) {
 		},
 	}
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, g.setLastSyncResourceVersion, g.clock, nevererrc)
-	if err == nil {
-		t.Errorf("unexpected non-error")
-	}
-	// Ensure the watcher methods are called exactly once in this exact order.
-	// TODO(karlkfi): Fix watchHandler to call Stop()
-	// assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
-	assert.Equal(t, []string{"ResultChan"}, calls)
+	require.Equal(t, err, errorStopRequested)
+	// Ensure handleWatch calls ResultChan and Stop
+	assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
 }
 
 // TestReflectorHandleWatchResultChanClosedBefore ensures that handleWatch
-// stops when the result channel is closed before handleWatch was called.
+// returns when the result channel is closed before handleWatch was called.
+// It also ensures that ResultChan and Stop are both called once.
 func TestReflectorHandleWatchResultChanClosedBefore(t *testing.T) {
 	s := NewStore(MetaNamespaceKeyFunc)
 	g := NewReflector(&ListWatch{}, &v1.Pod{}, s, 0)
 	_, ctx := ktesting.NewTestContext(t)
 	var calls []string
 	resultCh := make(chan watch.Event)
-	fw := watch.MockWatcher{
+	fw := &watch.MockWatcher{
 		StopFunc: func() {
 			calls = append(calls, "Stop")
 		},
@@ -295,24 +291,22 @@ func TestReflectorHandleWatchResultChanClosedBefore(t *testing.T) {
 	// Simulate the result channel being closed by the producer before handleWatch is called.
 	close(resultCh)
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, g.setLastSyncResourceVersion, g.clock, nevererrc)
-	if err == nil {
-		t.Errorf("unexpected non-error")
-	}
-	// Ensure the watcher methods are called exactly once in this exact order.
-	// TODO(karlkfi): Fix watchHandler to call Stop()
-	// assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
-	assert.Equal(t, []string{"ResultChan"}, calls)
+	// TODO(karlkfi): Add exact error type for "very short watch"
+	require.Error(t, err)
+	// Ensure handleWatch calls ResultChan and Stop
+	assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
 }
 
 // TestReflectorHandleWatchResultChanClosedAfter ensures that handleWatch
-// stops when the result channel is closed after handleWatch has started watching.
+// returns when the result channel is closed after handleWatch has started
+// watching. It also ensures that ResultChan and Stop are both called once.
 func TestReflectorHandleWatchResultChanClosedAfter(t *testing.T) {
 	s := NewStore(MetaNamespaceKeyFunc)
 	g := NewReflector(&ListWatch{}, &v1.Pod{}, s, 0)
 	_, ctx := ktesting.NewTestContext(t)
 	var calls []string
 	resultCh := make(chan watch.Event)
-	fw := watch.MockWatcher{
+	fw := &watch.MockWatcher{
 		StopFunc: func() {
 			calls = append(calls, "Stop")
 		},
@@ -329,22 +323,17 @@ func TestReflectorHandleWatchResultChanClosedAfter(t *testing.T) {
 		},
 	}
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, g.setLastSyncResourceVersion, g.clock, nevererrc)
-	if err == nil {
-		t.Errorf("unexpected non-error")
-	}
-	// Ensure the watcher methods are called exactly once in this exact order.
-	// TODO(karlkfi): Fix watchHandler to call Stop()
-	// assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
-	assert.Equal(t, []string{"ResultChan"}, calls)
+	// TODO(karlkfi): Add exact error type for "very short watch"
+	require.Error(t, err)
+	// Ensure handleWatch calls ResultChan and Stop
+	assert.Equal(t, []string{"ResultChan", "Stop"}, calls)
 }
 
 func TestReflectorWatchHandler(t *testing.T) {
 	s := NewStore(MetaNamespaceKeyFunc)
 	g := NewReflector(&ListWatch{}, &v1.Pod{}, s, 0)
 	// Wrap setLastSyncResourceVersion so we can tell the watchHandler to stop
-	// watching after all the events have been consumed. This avoids race
-	// conditions which can happen if the producer calls Stop(), instead of the
-	// consumer.
+	// watching after all the events have been consumed.
 	_, ctx := ktesting.NewTestContext(t)
 	ctx, cancel := context.WithCancelCause(ctx)
 	setLastSyncResourceVersion := func(rv string) {
@@ -361,13 +350,11 @@ func TestReflectorWatchHandler(t *testing.T) {
 		fw.Delete(&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo"}})
 		fw.Modify(&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "bar", ResourceVersion: "55"}})
 		fw.Add(&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "baz", ResourceVersion: "32"}})
-		fw.Stop()
+		// Stop means that the consumer is done reading events.
+		// So let handleWatch call fw.Stop, after the Context is cancelled.
 	}()
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, setLastSyncResourceVersion, g.clock, nevererrc)
-	// TODO(karlkfi): Fix FakeWatcher to avoid race condition between watcher.Stop() & close(stopCh)
-	if err != nil && !errors.Is(err, errorStopRequested) {
-		t.Errorf("unexpected error %v", err)
-	}
+	require.Equal(t, err, errorStopRequested)
 
 	mkPod := func(id string, rv string) *v1.Pod {
 		return &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: id, ResourceVersion: rv}}
@@ -410,70 +397,226 @@ func TestReflectorStopWatch(t *testing.T) {
 	ctx, cancel := context.WithCancelCause(ctx)
 	cancel(errors.New("don't run"))
 	err := handleWatch(ctx, time.Now(), fw, s, g.expectedType, g.expectedGVK, g.name, g.typeDescription, g.setLastSyncResourceVersion, g.clock, nevererrc)
-	if err != errorStopRequested {
-		t.Errorf("expected stop error, got %q", err)
-	}
+	require.Equal(t, err, errorStopRequested)
 }
 
 func TestReflectorListAndWatch(t *testing.T) {
-	_, ctx := ktesting.NewTestContext(t)
-	ctx, cancel := context.WithCancel(ctx)
-	defer cancel()
-	createdFakes := make(chan *watch.FakeWatcher)
-
-	// The ListFunc says that it's at revision 1. Therefore, we expect our WatchFunc
-	// to get called at the beginning of the watch with 1, and again with 3 when we
-	// inject an error.
-	expectedRVs := []string{"1", "3"}
-	lw := &ListWatch{
-		WatchFunc: func(options metav1.ListOptions) (watch.Interface, error) {
-			rv := options.ResourceVersion
-			fw := watch.NewFake()
-			if e, a := expectedRVs[0], rv; e != a {
-				t.Errorf("Expected rv %v, but got %v", e, a)
-			}
-			expectedRVs = expectedRVs[1:]
-			// channel is not buffered because the for loop below needs to block. But
-			// we don't want to block here, so report the new fake via a go routine.
-			go func() { createdFakes <- fw }()
-			return fw, nil
+	type listResult struct {
+		Object runtime.Object
+		Error  error
+	}
+	table := []struct {
+		name                 string
+		useWatchList         bool
+		listResults          []listResult
+		watchEvents          []watch.Event
+		expectedListOptions  []metav1.ListOptions
+		expectedWatchOptions []metav1.ListOptions
+		expectedStore        []metav1.Object
+	}{
+		{
+			name:         "UseWatchList enabled",
+			useWatchList: true,
+			watchEvents: []watch.Event{
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "1"}},
+				},
+				{
+					Type: watch.Bookmark,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{
+						Name:            "foo",
+						ResourceVersion: "1",
+						Annotations:     map[string]string{metav1.InitialEventsAnnotationKey: "true"},
+					}},
+				},
+				{
+					Type:   watch.Modified,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "2"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "bar", ResourceVersion: "3"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "baz", ResourceVersion: "4"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "qux", ResourceVersion: "5"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "zoo", ResourceVersion: "6"}},
+				},
+			},
+			expectedWatchOptions: []metav1.ListOptions{
+				{
+					AllowWatchBookmarks: true,
+					ResourceVersion:     "",
+					// ResourceVersionMatch defaults to "NotOlderThan" when
+					// ResourceVersion and Limit are empty.
+					ResourceVersionMatch: "NotOlderThan",
+					SendInitialEvents:    ptr.To(true),
+				},
+			},
+			expectedStore: []metav1.Object{
+				// Pod "foo" with rv "1" is de-duped by rv 2
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "2"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "bar", ResourceVersion: "3"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "baz", ResourceVersion: "4"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "qux", ResourceVersion: "5"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "zoo", ResourceVersion: "6"}},
+			},
 		},
-		ListFunc: func(options metav1.ListOptions) (runtime.Object, error) {
-			return &v1.PodList{ListMeta: metav1.ListMeta{ResourceVersion: "1"}}, nil
+		{
+			name:         "UseWatchList disabled",
+			useWatchList: false,
+			listResults: []listResult{
+				{
+					Object: &v1.PodList{
+						ListMeta: metav1.ListMeta{ResourceVersion: "1"},
+						Items: []v1.Pod{
+							{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "1"}},
+						},
+					},
+				},
+			},
+			watchEvents: []watch.Event{
+				{
+					Type:   watch.Modified,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "2"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "bar", ResourceVersion: "3"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "baz", ResourceVersion: "4"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "qux", ResourceVersion: "5"}},
+				},
+				{
+					Type:   watch.Added,
+					Object: &v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "zoo", ResourceVersion: "6"}},
+				},
+			},
+			expectedListOptions: []metav1.ListOptions{
+				{
+					AllowWatchBookmarks: false,
+					ResourceVersion:     "0",
+					// ResourceVersionMatch defaults to "NotOlderThan" when
+					// ResourceVersion is set and non-zero.
+					Limit:             500,
+					SendInitialEvents: nil,
+				},
+			},
+			expectedWatchOptions: []metav1.ListOptions{
+				{
+					AllowWatchBookmarks: true,
+					ResourceVersion:     "1",
+					// ResourceVersionMatch is not used by Watch calls
+					SendInitialEvents: nil,
+				},
+			},
+			expectedStore: []metav1.Object{
+				// Pod "foo" with rv "1" is de-duped by rv 2
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "foo", ResourceVersion: "2"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "bar", ResourceVersion: "3"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "baz", ResourceVersion: "4"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "qux", ResourceVersion: "5"}},
+				&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: "zoo", ResourceVersion: "6"}},
+			},
 		},
 	}
-	s := NewFIFO(MetaNamespaceKeyFunc)
-	r := NewReflector(lw, &v1.Pod{}, s, 0)
-	go func() { assert.NoError(t, r.ListAndWatchWithContext(ctx)) }()
+	for _, tc := range table {
+		t.Run(tc.name, func(t *testing.T) {
+			watcherCh := make(chan *watch.FakeWatcher)
+			var listOpts, watchOpts []metav1.ListOptions
 
-	ids := []string{"foo", "bar", "baz", "qux", "zoo"}
-	var fw *watch.FakeWatcher
-	for i, id := range ids {
-		if fw == nil {
-			fw = <-createdFakes
-		}
-		sendingRV := strconv.FormatUint(uint64(i+2), 10)
-		fw.Add(&v1.Pod{ObjectMeta: metav1.ObjectMeta{Name: id, ResourceVersion: sendingRV}})
-		if sendingRV == "3" {
-			// Inject a failure.
-			fw.Stop()
-			fw = nil
-		}
-	}
+			// The ListFunc will never be called. So we expect Watch to only be called
+			// with options.ResourceVersion="" to start the WatchList.
+			lw := &ListWatch{
+				WatchFunc: func(options metav1.ListOptions) (watch.Interface, error) {
+					watchOpts = append(watchOpts, options)
+					if len(watchOpts) > len(tc.expectedWatchOptions) {
+						return nil, fmt.Errorf("Expected ListerWatcher.Watch to only be called %d times",
+							len(tc.expectedWatchOptions))
+					}
+					w := watch.NewFake()
+					// Enqueue for event producer to use
+					go func() { watcherCh <- w }()
+					t.Log("Watcher Started")
+					return w, nil
+				},
+				ListFunc: func(options metav1.ListOptions) (runtime.Object, error) {
+					listOpts = append(listOpts, options)
+					if len(listOpts) > len(tc.listResults) {
+						return nil, fmt.Errorf("Expected ListerWatcher.List to only be called %d times",
+							len(tc.listResults))
+					}
+					listResult := tc.listResults[len(listOpts)-1]
+					return listResult.Object, listResult.Error
+				},
+			}
+			s := NewFIFO(MetaNamespaceKeyFunc)
+			r := NewReflector(lw, &v1.Pod{}, s, 0)
+			r.UseWatchList = ptr.To(tc.useWatchList)
 
-	// Verify we received the right ids with the right resource versions.
-	for i, id := range ids {
-		pod := Pop(s).(*v1.Pod)
-		if e, a := id, pod.Name; e != a {
-			t.Errorf("%v: Expected %v, got %v", i, e, a)
-		}
-		if e, a := strconv.FormatUint(uint64(i+2), 10), pod.ResourceVersion; e != a {
-			t.Errorf("%v: Expected %v, got %v", i, e, a)
-		}
-	}
+			// Start ListAndWatch in the background.
+			// When it returns, it will send an error or nil on the error
+			// channel and close the error channel.
+			_, ctx := ktesting.NewTestContext(t)
+			ctx, cancel := context.WithCancel(ctx)
+			defer cancel()
+			errCh := make(chan error)
+			go func() {
+				defer close(errCh)
+				errCh <- r.ListAndWatchWithContext(ctx)
+			}()
+			// Stop ListAndWatch and wait for the error channel to close.
+			// Validate it didn't error in Cleanup, not a defer.
+			t.Cleanup(func() {
+				cancel()
+				for err := range errCh {
+					assert.NoError(t, err)
+				}
+			})
 
-	if len(expectedRVs) != 0 {
-		t.Error("called watchStarter an unexpected number of times")
+			// Send watch events
+			var fw *watch.FakeWatcher
+			for _, event := range tc.watchEvents {
+				if fw == nil {
+					// Wait for ListerWatcher.Watch to be called
+					fw = <-watcherCh
+				}
+				obj := event.Object.(metav1.Object)
+				t.Logf("Sending %s event: name=%s, resourceVersion=%s",
+					event.Type, obj.GetName(), obj.GetResourceVersion())
+				fw.Action(event.Type, event.Object)
+			}
+
+			// Verify we received the right objects with the right resource versions.
+			for _, expectedObj := range tc.expectedStore {
+				storeObj := Pop(s).(metav1.Object)
+				assert.Equal(t, expectedObj.GetName(), storeObj.GetName())
+				assert.Equal(t, expectedObj.GetResourceVersion(), storeObj.GetResourceVersion())
+			}
+
+			// Verify we received the right number of List & Watch calls,
+			// with the expected options.
+			diffOpts := cmpopts.IgnoreFields(metav1.ListOptions{}, "TimeoutSeconds")
+			if diff := cmp.Diff(tc.expectedListOptions, listOpts, diffOpts); diff != "" {
+				t.Errorf("Unexpected List calls by ListAndWatch:\n%s", diff)
+			}
+			if diff := cmp.Diff(tc.expectedWatchOptions, watchOpts, diffOpts); diff != "" {
+				t.Errorf("Unexpected Watch calls by ListAndWatch:\n%s", diff)
+			}
+		})
 	}
 }
 
EOF_114329324912

# Run the specific test using make with WHAT targeting and readonly vendor mode
export WHAT="./staging/src/k8s.io/client-go/tools/cache/"
export GOFLAGS="-mod=readonly"
make test
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original file content
cp "$ORIGINAL_FILE.original" "$ORIGINAL_FILE"
rm -f "$ORIGINAL_FILE.original"

exit $rc