#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset test files to original state before applying patch
git checkout 13b55ffc811c3787bf6cde9c1b61f2df179911f4 "tsdb/chunkenc/float_histogram_test.go" "tsdb/chunkenc/histogram_meta_test.go" "tsdb/chunkenc/histogram_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tsdb/chunkenc/float_histogram_test.go b/tsdb/chunkenc/float_histogram_test.go
--- a/tsdb/chunkenc/float_histogram_test.go
+++ b/tsdb/chunkenc/float_histogram_test.go
@@ -195,7 +195,7 @@ func TestFloatHistogramChunkSameBuckets(t *testing.T) {
 	require.Equal(t, ValNone, it4.Seek(exp[len(exp)-1].t+1))
 }
 
-// Mimics the scenario described for expandSpansForward.
+// Mimics the scenario described for expandFloatSpansAndBuckets.
 func TestFloatHistogramChunkBucketChanges(t *testing.T) {
 	c := Chunk(NewFloatHistogramChunk())
 
@@ -1420,3 +1420,45 @@ func assertFirstFloatHistogramSampleHint(t *testing.T, chunk Chunk, expected his
 	_, v := it.AtFloatHistogram(nil)
 	require.Equal(t, expected, v.CounterResetHint)
 }
+
+func TestFloatHistogramEmptyBucketsWithGaps(t *testing.T) {
+	h1 := &histogram.FloatHistogram{
+		PositiveSpans: []histogram.Span{
+			{Offset: -19, Length: 2},
+			{Offset: 1, Length: 2},
+		},
+		PositiveBuckets: []float64{0, 0, 0, 0},
+	}
+	require.NoError(t, h1.Validate())
+
+	c := NewFloatHistogramChunk()
+	app, err := c.Appender()
+	require.NoError(t, err)
+	_, _, _, err = app.AppendFloatHistogram(nil, 1, h1, false)
+	require.NoError(t, err)
+
+	h2 := &histogram.FloatHistogram{
+		PositiveSpans: []histogram.Span{
+			{Offset: -19, Length: 1},
+			{Offset: 4, Length: 1},
+			{Offset: 3, Length: 1},
+		},
+		PositiveBuckets: []float64{0, 0, 0},
+	}
+	require.NoError(t, h2.Validate())
+
+	newC, recoded, _, err := app.AppendFloatHistogram(nil, 2, h2, false)
+	require.NoError(t, err)
+	require.True(t, recoded)
+	require.NotNil(t, newC)
+
+	it := newC.Iterator(nil)
+	require.Equal(t, ValFloatHistogram, it.Next())
+	_, h := it.AtFloatHistogram(nil)
+	require.NoError(t, h.Validate())
+	require.Equal(t, ValFloatHistogram, it.Next())
+	_, h = it.AtFloatHistogram(nil)
+	require.NoError(t, h.Validate())
+	require.Equal(t, ValNone, it.Next())
+	require.NoError(t, it.Err())
+}
diff --git a/tsdb/chunkenc/histogram_meta_test.go b/tsdb/chunkenc/histogram_meta_test.go
--- a/tsdb/chunkenc/histogram_meta_test.go
+++ b/tsdb/chunkenc/histogram_meta_test.go
@@ -78,7 +78,7 @@ func TestBucketIterator(t *testing.T) {
 			},
 			idxs: []int{100, 101, 102, 103, 112, 113, 114, 115, 116, 117, 118, 119},
 		},
-		// The below 2 sets ore the ones described in expandSpansForward's comments.
+		// The below 2 sets ore the ones described in expandFloatSpansAndBuckets's comments.
 		{
 			spans: []histogram.Span{
 				{Offset: 0, Length: 2},
@@ -111,12 +111,13 @@ func TestBucketIterator(t *testing.T) {
 	}
 }
 
-func TestCompareSpansAndInsert(t *testing.T) {
+func TestExpandSpansBothWaysAndInsert(t *testing.T) {
 	scenarios := []struct {
 		description           string
 		spansA, spansB        []histogram.Span
 		fInserts, bInserts    []Insert
 		bucketsIn, bucketsOut []int64
+		mergedSpans           []histogram.Span
 	}{
 		{
 			description: "single prepend at the beginning",
@@ -134,6 +135,9 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0},
 			bucketsOut: []int64{0, 6, -3, 0},
+			mergedSpans: []histogram.Span{
+				{Offset: -11, Length: 4},
+			},
 		},
 		{
 			description: "single append at the end",
@@ -151,6 +155,9 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0},
 			bucketsOut: []int64{6, -3, 0, -3},
+			mergedSpans: []histogram.Span{
+				{Offset: -10, Length: 4},
+			},
 		},
 		{
 			description: "double prepend at the beginning",
@@ -168,6 +175,9 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0},
 			bucketsOut: []int64{0, 0, 6, -3, 0},
+			mergedSpans: []histogram.Span{
+				{Offset: -12, Length: 5},
+			},
 		},
 		{
 			description: "double append at the end",
@@ -185,6 +195,9 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0},
 			bucketsOut: []int64{6, -3, 0, -3, 0},
+			mergedSpans: []histogram.Span{
+				{Offset: -10, Length: 5},
+			},
 		},
 		{
 			description: "double prepond at the beginning and double append at the end",
@@ -206,6 +219,9 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0},
 			bucketsOut: []int64{0, 0, 6, -3, 0, -3, 0},
+			mergedSpans: []histogram.Span{
+				{Offset: -12, Length: 7},
+			},
 		},
 		{
 			description: "single removal of bucket at the start",
@@ -218,6 +234,11 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			bInserts: []Insert{
 				{pos: 0, num: 1},
 			},
+			bucketsIn:  []int64{1, 2, -1, 2},
+			bucketsOut: []int64{1, 2, -1, 2},
+			mergedSpans: []histogram.Span{
+				{Offset: -10, Length: 4},
+			},
 		},
 		{
 			description: "single removal of bucket in the middle",
@@ -231,6 +252,11 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			bInserts: []Insert{
 				{pos: 2, num: 1},
 			},
+			bucketsIn:  []int64{1, 2, -1, 2},
+			bucketsOut: []int64{1, 2, -1, 2},
+			mergedSpans: []histogram.Span{
+				{Offset: -10, Length: 4},
+			},
 		},
 		{
 			description: "single removal of bucket at the end",
@@ -243,6 +269,11 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			bInserts: []Insert{
 				{pos: 3, num: 1},
 			},
+			mergedSpans: []histogram.Span{
+				{Offset: -10, Length: 4},
+			},
+			bucketsIn:  []int64{1, 2, -1, 2},
+			bucketsOut: []int64{1, 2, -1, 2},
 		},
 		{
 			description: "as described in doc comment",
@@ -275,6 +306,12 @@ func TestCompareSpansAndInsert(t *testing.T) {
 			},
 			bucketsIn:  []int64{6, -3, 0, -1, 2, 1, -4},
 			bucketsOut: []int64{6, -3, -3, 3, -3, 0, 2, 2, 1, -5, 1},
+			mergedSpans: []histogram.Span{
+				{Offset: 0, Length: 3},
+				{Offset: 1, Length: 1},
+				{Offset: 1, Length: 4},
+				{Offset: 3, Length: 3},
+			},
 		},
 		{
 			description: "both forward and backward inserts, complex case",
@@ -324,27 +361,51 @@ func TestCompareSpansAndInsert(t *testing.T) {
 					num: 1,
 				},
 			},
+			bucketsIn:  []int64{1, 2, -1, 2, 0, 3, 1},
+			bucketsOut: []int64{1, 2, -3, 2, -2, 0, 4, 0, 3, -7, 8},
+			mergedSpans: []histogram.Span{
+				{Offset: 0, Length: 3},
+				{Offset: 1, Length: 1},
+				{Offset: 1, Length: 4},
+				{Offset: 3, Length: 3},
+			},
+		},
+		{
+			description: "inserts with gaps",
+			spansA: []histogram.Span{
+				{Offset: -19, Length: 2},
+				{Offset: 1, Length: 2},
+			},
+			spansB: []histogram.Span{
+				{Offset: -19, Length: 1},
+				{Offset: 4, Length: 1},
+				{Offset: 3, Length: 1},
+			},
+			fInserts: []Insert{
+				{pos: 4, num: 2},
+			},
+			bInserts: []Insert{
+				{pos: 1, num: 3},
+			},
+			bucketsIn:  []int64{1, 2, -1, 1},
+			bucketsOut: []int64{1, 2, -1, 1, -3, 0},
+			mergedSpans: []histogram.Span{
+				{Offset: -19, Length: 2},
+				{Offset: 1, Length: 3},
+				{Offset: 3, Length: 1},
+			},
 		},
 	}
 
 	for _, s := range scenarios {
 		t.Run(s.description, func(t *testing.T) {
-			if len(s.bInserts) > 0 {
-				fInserts, bInserts, _ := expandSpansBothWays(s.spansA, s.spansB)
-				require.Equal(t, s.fInserts, fInserts)
-				require.Equal(t, s.bInserts, bInserts)
-			}
-
-			inserts, valid := expandSpansForward(s.spansA, s.spansB)
-			if len(s.bInserts) > 0 {
-				require.False(t, valid, "compareScan unexpectedly returned true")
-				return
-			}
-			require.True(t, valid, "compareScan unexpectedly returned false")
-			require.Equal(t, s.fInserts, inserts)
+			fInserts, bInserts, m := expandSpansBothWays(s.spansA, s.spansB)
+			require.Equal(t, s.fInserts, fInserts)
+			require.Equal(t, s.bInserts, bInserts)
+			require.Equal(t, s.mergedSpans, m)
 
 			gotBuckets := make([]int64, len(s.bucketsOut))
-			insert(s.bucketsIn, gotBuckets, inserts, true)
+			insert(s.bucketsIn, gotBuckets, fInserts, true)
 			require.Equal(t, s.bucketsOut, gotBuckets)
 
 			floatBucketsIn := make([]float64, len(s.bucketsIn))
@@ -362,7 +423,7 @@ func TestCompareSpansAndInsert(t *testing.T) {
 				floatBucketsOut[i] = float64(last)
 			}
 			gotFloatBuckets := make([]float64, len(floatBucketsOut))
-			insert(floatBucketsIn, gotFloatBuckets, inserts, false)
+			insert(floatBucketsIn, gotFloatBuckets, fInserts, false)
 			require.Equal(t, floatBucketsOut, gotFloatBuckets)
 		})
 	}
@@ -599,3 +660,259 @@ func TestSpansFromBidirectionalCompareSpans(t *testing.T) {
 		require.Equal(t, c.exp, act)
 	}
 }
+
+func TestExpandIntOrFloatSpansAndBuckets(t *testing.T) {
+	testCases := map[string]struct {
+		spansA   []histogram.Span
+		bucketsA []int64
+		spansB   []histogram.Span
+		bucketsB []int64
+
+		expectReset           bool
+		expectForwardInserts  []Insert
+		expectBackwardInserts []Insert
+		expectMergedSpans     []histogram.Span
+		expectBucketsA        []int64
+		expectBucketsB        []int64
+	}{
+		"empty": {
+			spansA:                []histogram.Span{},
+			bucketsA:              []int64{},
+			spansB:                []histogram.Span{},
+			bucketsB:              []int64{},
+			expectReset:           false,
+			expectForwardInserts:  nil,
+			expectBackwardInserts: nil,
+			expectMergedSpans:     []histogram.Span{},
+			expectBucketsA:        []int64{},
+			expectBucketsB:        []int64{},
+		},
+		"single bucket reset to none": {
+			spansA:      []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:    []int64{1},
+			spansB:      []histogram.Span{},
+			bucketsB:    []int64{},
+			expectReset: true,
+		},
+		"single bucket reset to lower": {
+			spansA:      []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:    []int64{2},
+			spansB:      []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsB:    []int64{1},
+			expectReset: true,
+		},
+		"single bucket increase": {
+			spansA:                []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:              []int64{1},
+			spansB:                []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsB:              []int64{2},
+			expectReset:           false,
+			expectForwardInserts:  nil,
+			expectBackwardInserts: nil,
+			expectMergedSpans:     []histogram.Span{{Offset: 1, Length: 1}},
+			expectBucketsA:        []int64{1},
+			expectBucketsB:        []int64{2},
+		},
+		"distinct new buckets and increase": {
+			// A:  ___1_____
+			// B:  22_22___2
+			// B': 22_22___2
+			spansA:                []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:              []int64{1},
+			spansB:                []histogram.Span{{Offset: -2, Length: 2}, {Offset: 1, Length: 2}, {Offset: 3, Length: 1}},
+			bucketsB:              []int64{2, 0, 0, 0, 0},
+			expectReset:           false,
+			expectForwardInserts:  []Insert{{pos: 0, num: 2, bucketIdx: -2}, {pos: 1, num: 1, bucketIdx: 2}, {pos: 1, num: 1, bucketIdx: 6}},
+			expectBackwardInserts: nil,
+			expectMergedSpans:     []histogram.Span{{Offset: -2, Length: 2}, {Offset: 1, Length: 2}, {Offset: 3, Length: 1}},
+			expectBucketsA:        []int64{0, 0, 1, -1, 0},
+			expectBucketsB:        []int64{2, 0, 0, 0, 0},
+		},
+		"distinct new buckets but reset": {
+			// A: ___2_____
+			// B: 11_11___1
+			spansA:      []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:    []int64{2},
+			spansB:      []histogram.Span{{Offset: -2, Length: 2}, {Offset: 1, Length: 2}, {Offset: 3, Length: 1}},
+			bucketsB:    []int64{1, 0, 0, 0, 0},
+			expectReset: true,
+		},
+		"distinct new buckets but missing": {
+			// A: ___2_____
+			// B: 11__1___1
+			spansA:      []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:    []int64{2},
+			spansB:      []histogram.Span{{Offset: -2, Length: 2}, {Offset: 2, Length: 1}, {Offset: 3, Length: 1}},
+			bucketsB:    []int64{1, 0, 0, 0},
+			expectReset: true,
+		},
+		"distinct new buckets and missing an empty bucket": {
+			// A:  _0__
+			// B:  ___1
+			// B': _0_1
+			spansA:                []histogram.Span{{Offset: 1, Length: 1}},
+			bucketsA:              []int64{0},
+			spansB:                []histogram.Span{{Offset: 3, Length: 1}},
+			bucketsB:              []int64{1},
+			expectReset:           false,
+			expectForwardInserts:  []Insert{{pos: 1, num: 1, bucketIdx: 3}},
+			expectBackwardInserts: []Insert{{pos: 0, num: 1, bucketIdx: 1}},
+			expectMergedSpans:     []histogram.Span{{Offset: 1, Length: 1}, {Offset: 1, Length: 1}},
+			expectBucketsA:        []int64{0, 0},
+			expectBucketsB:        []int64{0, 1},
+		},
+		"distinct new buckets and missing multiple empty buckets": {
+			// Idx: 01234567890123
+			// A:   _000_00__0__00
+			// B;   ________1_____
+			// B':  _000_00_10__00
+			spansA:                []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 2, Length: 1}, {Offset: 2, Length: 2}},
+			bucketsA:              []int64{0, 0, 0, 0, 0, 0, 0, 0},
+			spansB:                []histogram.Span{{Offset: 8, Length: 1}},
+			bucketsB:              []int64{1},
+			expectReset:           false,
+			expectForwardInserts:  []Insert{{pos: 5, num: 1, bucketIdx: 8}},
+			expectBackwardInserts: []Insert{{pos: 0, num: 3, bucketIdx: 1}, {pos: 0, num: 2, bucketIdx: 5}, {pos: 1, num: 1, bucketIdx: 9}, {pos: 1, num: 2, bucketIdx: 12}},
+			expectMergedSpans:     []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 1, Length: 2}, {Offset: 2, Length: 2}},
+			expectBucketsA:        []int64{0, 0, 0, 0, 0, 0, 0, 0, 0},
+			expectBucketsB:        []int64{0, 0, 0, 0, 0, 1, -1, 0, 0},
+		},
+		"overlap new buckets and missing multiple empty buckets": {
+			// Idx: 01234567890123
+			// A:   _000_00_10__00
+			// B;   ________2_____
+			// B':  _000_00_20__00
+			spansA:                []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 1, Length: 2}, {Offset: 2, Length: 2}},
+			bucketsA:              []int64{0, 0, 0, 0, 0, 1, -1, 0, 0},
+			spansB:                []histogram.Span{{Offset: 8, Length: 1}},
+			bucketsB:              []int64{2},
+			expectReset:           false,
+			expectForwardInserts:  nil,
+			expectBackwardInserts: []Insert{{pos: 0, num: 3, bucketIdx: 1}, {pos: 0, num: 2, bucketIdx: 5}, {pos: 1, num: 1, bucketIdx: 9}, {pos: 1, num: 2, bucketIdx: 12}},
+			expectMergedSpans:     []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 1, Length: 2}, {Offset: 2, Length: 2}},
+			expectBucketsA:        []int64{0, 0, 0, 0, 0, 1, -1, 0, 0},
+			expectBucketsB:        []int64{0, 0, 0, 0, 0, 2, -2, 0, 0},
+		},
+		"overlap new buckets and missing multiple empty buckets with 0 length/offset spans": {
+			// Idx: 01234567890123
+			// A:   _000_00_10__00
+			// B;   ________2_____
+			// B':  _000_00_20__00
+			spansA:                []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 1, Length: 2}, {Offset: 1, Length: 0}, {Offset: 1, Length: 2}},
+			bucketsA:              []int64{0, 0, 0, 0, 0, 1, -1, 0, 0},
+			spansB:                []histogram.Span{{Offset: 1, Length: 0}, {Offset: 7, Length: 1}},
+			bucketsB:              []int64{2},
+			expectReset:           false,
+			expectForwardInserts:  nil,
+			expectBackwardInserts: []Insert{{pos: 0, num: 3, bucketIdx: 1}, {pos: 0, num: 2, bucketIdx: 5}, {pos: 1, num: 1, bucketIdx: 9}, {pos: 1, num: 2, bucketIdx: 12}},
+			expectMergedSpans:     []histogram.Span{{Offset: 1, Length: 3}, {Offset: 1, Length: 2}, {Offset: 1, Length: 2}, {Offset: 2, Length: 2}},
+			expectBucketsA:        []int64{0, 0, 0, 0, 0, 1, -1, 0, 0},
+			expectBucketsB:        []int64{0, 0, 0, 0, 0, 2, -2, 0, 0},
+		},
+		"new empty buckets between filled buckets": {
+			// A:  11212332____1__1
+			// B:  122323321__11__1
+			// A': 112123320__01__1
+			// B': 122323321__11__1
+			spansA:               []histogram.Span{{Offset: -51, Length: 8}, {Offset: 11, Length: 1}, {Offset: 14, Length: 1}},
+			bucketsA:             []int64{1, 0, 1, -1, 1, 1, 0, -1, -1, 0},
+			spansB:               []histogram.Span{{Offset: -51, Length: 9}, {Offset: 9, Length: 2}, {Offset: 14, Length: 1}},
+			bucketsB:             []int64{1, 1, 0, 1, -1, 1, 0, -1, -1, 0, 0, 0},
+			expectReset:          false,
+			expectForwardInserts: []Insert{{pos: 8, num: 1, bucketIdx: -43}, {pos: 8, num: 1, bucketIdx: -33}},
+			expectMergedSpans:    []histogram.Span{{Offset: -51, Length: 9}, {Offset: 9, Length: 2}, {Offset: 14, Length: 1}},
+			expectBucketsA:       []int64{1, 0, 1, -1, 1, 1, 0, -1, -2, 0, 1, 0},
+			// 1 0 1 -1 1 1 0 -1 -2 -2 1 0
+
+			expectBucketsB: []int64{1, 1, 0, 1, -1, 1, 0, -1, -1, 0, 0, 0},
+		},
+		"real example 1": {
+			// I-  6543210987654321
+			// A:  0__2_______0__
+			// B:  _0130_____00_0
+			// A': 00020_____00_0
+			// B': 00130_____00_0
+			spansA:                []histogram.Span{{Offset: -16, Length: 1}, {Offset: 2, Length: 1}, {Offset: 7, Length: 1}},
+			bucketsA:              []int64{0, 2, -2},
+			spansB:                []histogram.Span{{Offset: -15, Length: 4}, {Offset: 5, Length: 2}, {Offset: 1, Length: 1}},
+			bucketsB:              []int64{0, 1, 2, -3, 0, 0, 0},
+			expectReset:           false,
+			expectForwardInserts:  []Insert{{pos: 1, num: 2, bucketIdx: -15}, {pos: 2, num: 1, bucketIdx: -12}, {pos: 2, num: 1, bucketIdx: -6}, {pos: 3, num: 1, bucketIdx: -3}},
+			expectBackwardInserts: []Insert{{pos: 0, num: 1, bucketIdx: -16}},
+			expectMergedSpans:     []histogram.Span{{Offset: -16, Length: 5}, {Offset: 5, Length: 2}, {Offset: 1, Length: 1}},
+			expectBucketsA:        []int64{0, 0, 0, 2, -2, 0, 0, 0},
+			expectBucketsB:        []int64{0, 0, 1, 2, -3, 0, 0, 0},
+		},
+	}
+
+	for name, tc := range testCases {
+		t.Run(name, func(t *testing.T) {
+			// Sanity check.
+			require.Len(t, tc.bucketsA, countSpans(tc.spansA))
+			require.Len(t, tc.bucketsB, countSpans(tc.spansB))
+			require.Len(t, tc.expectBucketsA, countSpans(tc.expectMergedSpans))
+			require.Len(t, tc.expectBucketsB, countSpans(tc.expectMergedSpans))
+
+			t.Run("integers", func(t *testing.T) {
+				fInserts, bInserts, ok := expandIntSpansAndBuckets(tc.spansA, tc.spansB, tc.bucketsA, tc.bucketsB)
+				if tc.expectReset {
+					require.False(t, ok)
+					return
+				}
+				require.Equal(t, tc.expectForwardInserts, fInserts, "forward inserts")
+				require.Equal(t, tc.expectBackwardInserts, bInserts, "backward inserts")
+
+				gotBspans := adjustForInserts(tc.spansB, bInserts)
+				require.Equal(t, tc.expectMergedSpans, gotBspans)
+
+				gotAbuckets := make([]int64, len(tc.expectBucketsA))
+				insert(tc.bucketsA, gotAbuckets, fInserts, true)
+				require.Equal(t, tc.expectBucketsA, gotAbuckets)
+
+				gotBbuckets := make([]int64, len(tc.expectBucketsB))
+				insert(tc.bucketsB, gotBbuckets, bInserts, true)
+				require.Equal(t, tc.expectBucketsB, gotBbuckets)
+			})
+
+			t.Run("floats", func(t *testing.T) {
+				aXorValues := make([]xorValue, len(tc.bucketsA))
+				absolute := float64(0)
+				for i, v := range tc.bucketsA {
+					absolute += float64(v)
+					aXorValues[i].value = absolute
+				}
+
+				makeFloatBuckets := func(in []int64) []float64 {
+					out := make([]float64, len(in))
+					absolute = float64(0)
+					for i, v := range in {
+						absolute += float64(v)
+						out[i] = absolute
+					}
+					return out
+				}
+
+				bFloatBuckets := makeFloatBuckets(tc.bucketsB)
+
+				fInserts, bInserts, ok := expandFloatSpansAndBuckets(tc.spansA, tc.spansB, aXorValues, bFloatBuckets)
+				if tc.expectReset {
+					require.False(t, ok)
+					return
+				}
+				require.Equal(t, tc.expectForwardInserts, fInserts, "forward inserts")
+				require.Equal(t, tc.expectBackwardInserts, bInserts, "backward inserts")
+
+				gotBspans := adjustForInserts(tc.spansB, bInserts)
+				require.Equal(t, tc.expectMergedSpans, gotBspans)
+
+				gotAbuckets := make([]float64, len(tc.expectBucketsA))
+				insert(makeFloatBuckets(tc.bucketsA), gotAbuckets, fInserts, false)
+				require.Equal(t, makeFloatBuckets(tc.expectBucketsA), gotAbuckets)
+
+				gotBbuckets := make([]float64, len(tc.expectBucketsB))
+				insert(makeFloatBuckets(tc.bucketsB), gotBbuckets, bInserts, false)
+				require.Equal(t, makeFloatBuckets(tc.expectBucketsB), gotBbuckets)
+			})
+		})
+	}
+}
diff --git a/tsdb/chunkenc/histogram_test.go b/tsdb/chunkenc/histogram_test.go
--- a/tsdb/chunkenc/histogram_test.go
+++ b/tsdb/chunkenc/histogram_test.go
@@ -206,7 +206,7 @@ func TestHistogramChunkSameBuckets(t *testing.T) {
 	require.Equal(t, ValNone, it4.Seek(exp[len(exp)-1].t+1))
 }
 
-// Mimics the scenario described for expandSpansForward.
+// Mimics the scenario described for expandIntSpansAndBuckets.
 func TestHistogramChunkBucketChanges(t *testing.T) {
 	c := Chunk(NewHistogramChunk())
 
@@ -1776,3 +1776,45 @@ func assertFirstIntHistogramSampleHint(t *testing.T, chunk Chunk, expected histo
 	_, v := it.AtHistogram(nil)
 	require.Equal(t, expected, v.CounterResetHint)
 }
+
+func TestIntHistogramEmptyBucketsWithGaps(t *testing.T) {
+	h1 := &histogram.Histogram{
+		PositiveSpans: []histogram.Span{
+			{Offset: -19, Length: 2},
+			{Offset: 1, Length: 2},
+		},
+		PositiveBuckets: []int64{0, 0, 0, 0},
+	}
+	require.NoError(t, h1.Validate())
+
+	c := NewHistogramChunk()
+	app, err := c.Appender()
+	require.NoError(t, err)
+	_, _, _, err = app.AppendHistogram(nil, 1, h1, false)
+	require.NoError(t, err)
+
+	h2 := &histogram.Histogram{
+		PositiveSpans: []histogram.Span{
+			{Offset: -19, Length: 1},
+			{Offset: 4, Length: 1},
+			{Offset: 3, Length: 1},
+		},
+		PositiveBuckets: []int64{0, 0, 0},
+	}
+	require.NoError(t, h2.Validate())
+
+	newC, recoded, _, err := app.AppendHistogram(nil, 2, h2, false)
+	require.NoError(t, err)
+	require.True(t, recoded)
+	require.NotNil(t, newC)
+
+	it := newC.Iterator(nil)
+	require.Equal(t, ValHistogram, it.Next())
+	_, h := it.AtFloatHistogram(nil)
+	require.NoError(t, h.Validate())
+	require.Equal(t, ValHistogram, it.Next())
+	_, h = it.AtFloatHistogram(nil)
+	require.NoError(t, h.Validate())
+	require.Equal(t, ValNone, it.Next())
+	require.NoError(t, it.Err())
+}
EOF_114329324912

# Execute the tests as part of the chunkenc package to ensure proper compilation
# with all package dependencies. The test will run all tests in the package but will focus
# on the specific test files due to the patch applied.
GO_ONLY=1 go test -v -p 1 ./tsdb/chunkenc/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore test files to original state
git checkout 13b55ffc811c3787bf6cde9c1b61f2df179911f4 "tsdb/chunkenc/float_histogram_test.go" "tsdb/chunkenc/histogram_meta_test.go" "tsdb/chunkenc/histogram_test.go"