#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure clean state for target test files
git checkout b39672736a3002895481ad0f17acc68a21d4a759 "config/config_test.go" "storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go" "storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/config/config_test.go b/config/config_test.go
--- a/config/config_test.go
+++ b/config/config_test.go
@@ -1563,6 +1563,20 @@ func TestOTLPAllowServiceNameInTargetInfo(t *testing.T) {
 	})
 }
 
+func TestOTLPConvertHistogramsToNHCB(t *testing.T) {
+	t.Run("good config", func(t *testing.T) {
+		want, err := LoadFile(filepath.Join("testdata", "otlp_convert_histograms_to_nhcb.good.yml"), false, promslog.NewNopLogger())
+		require.NoError(t, err)
+
+		out, err := yaml.Marshal(want)
+		require.NoError(t, err)
+		var got Config
+		require.NoError(t, yaml.UnmarshalStrict(out, &got))
+
+		require.True(t, got.OTLPConfig.ConvertHistogramsToNHCB)
+	})
+}
+
 func TestOTLPAllowUTF8(t *testing.T) {
 	t.Run("good config", func(t *testing.T) {
 		fpath := filepath.Join("testdata", "otlp_allow_utf8.good.yml")
diff --git a/config/testdata/otlp_convert_histograms_to_nhcb.good.yml b/config/testdata/otlp_convert_histograms_to_nhcb.good.yml
new file mode 100644
--- /dev/null
+++ b/config/testdata/otlp_convert_histograms_to_nhcb.good.yml
@@ -0,0 +1,2 @@
+otlp:
+  convert_histograms_to_nhcb: true
diff --git a/storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go b/storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go
--- a/storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go
+++ b/storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go
@@ -379,7 +379,7 @@ func TestConvertBucketsLayout(t *testing.T) {
 	for _, tt := range tests {
 		for scaleDown, wantLayout := range tt.wantLayout {
 			t.Run(fmt.Sprintf("%s-scaleby-%d", tt.name, scaleDown), func(t *testing.T) {
-				gotSpans, gotDeltas := convertBucketsLayout(tt.buckets(), scaleDown)
+				gotSpans, gotDeltas := convertBucketsLayout(tt.buckets().BucketCounts().AsRaw(), tt.buckets().Offset(), scaleDown, true)
 				assert.Equal(t, wantLayout.wantSpans, gotSpans)
 				assert.Equal(t, wantLayout.wantDeltas, gotDeltas)
 			})
@@ -409,7 +409,7 @@ func BenchmarkConvertBucketLayout(b *testing.B) {
 		}
 		b.Run(fmt.Sprintf("gap %d", scenario.gap), func(b *testing.B) {
 			for i := 0; i < b.N; i++ {
-				convertBucketsLayout(buckets, 0)
+				convertBucketsLayout(buckets.BucketCounts().AsRaw(), buckets.Offset(), 0, true)
 			}
 		})
 	}
@@ -581,6 +581,14 @@ func TestExponentialToNativeHistogram(t *testing.T) {
 	}
 }
 
+func validateHistogramCount(t *testing.T, h pmetric.HistogramDataPoint) {
+	actualCount := uint64(0)
+	for _, bucket := range h.BucketCounts().AsRaw() {
+		actualCount += bucket
+	}
+	require.Equal(t, h.Count(), actualCount, "histogram count mismatch")
+}
+
 func validateExponentialHistogramCount(t *testing.T, h pmetric.ExponentialHistogramDataPoint) {
 	actualCount := uint64(0)
 	for _, bucket := range h.Positive().BucketCounts().AsRaw() {
@@ -771,3 +779,372 @@ func TestPrometheusConverter_addExponentialHistogramDataPoints(t *testing.T) {
 		})
 	}
 }
+
+func TestConvertExplicitHistogramBucketsToNHCBLayout(t *testing.T) {
+	tests := []struct {
+		name       string
+		buckets    []uint64
+		wantLayout expectedBucketLayout
+	}{
+		{
+			name:    "zero offset",
+			buckets: []uint64{4, 3, 2, 1},
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 0,
+						Length: 4,
+					},
+				},
+				wantDeltas: []int64{4, -1, -1, -1},
+			},
+		},
+		{
+			name:    "leading empty buckets",
+			buckets: []uint64{0, 0, 1, 1, 2, 3},
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 2,
+						Length: 4,
+					},
+				},
+				wantDeltas: []int64{1, 0, 1, 1},
+			},
+		},
+		{
+			name:    "trailing empty buckets",
+			buckets: []uint64{0, 0, 1, 1, 2, 3, 0, 0}, //TODO: add tests for 3 trailing buckets
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 2,
+						Length: 6,
+					},
+				},
+				wantDeltas: []int64{1, 0, 1, 1, -3, 0},
+			},
+		},
+		{
+			name:    "bucket gap of 2",
+			buckets: []uint64{1, 2, 0, 0, 2},
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 0,
+						Length: 5,
+					},
+				},
+				wantDeltas: []int64{1, 1, -2, 0, 2},
+			},
+		},
+		{
+			name:    "bucket gap > 2",
+			buckets: []uint64{1, 2, 0, 0, 0, 2, 4, 4},
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 0,
+						Length: 2,
+					},
+					{
+						Offset: 3,
+						Length: 3,
+					},
+				},
+				wantDeltas: []int64{1, 1, 0, 2, 0},
+			},
+		},
+		{
+			name:    "multiple bucket gaps",
+			buckets: []uint64{0, 0, 1, 2, 0, 0, 0, 2, 4, 4, 0, 0},
+			wantLayout: expectedBucketLayout{
+				wantSpans: []prompb.BucketSpan{
+					{
+						Offset: 2,
+						Length: 2,
+					},
+					{
+						Offset: 3,
+						Length: 5,
+					},
+				},
+				wantDeltas: []int64{1, 1, 0, 2, 0, -4, 0},
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			buckets := tt.buckets
+			offset := getBucketOffset(buckets)
+			bucketCounts := buckets[offset:]
+
+			gotSpans, gotDeltas := convertBucketsLayout(bucketCounts, int32(offset), 0, false)
+			assert.Equal(t, tt.wantLayout.wantSpans, gotSpans)
+			assert.Equal(t, tt.wantLayout.wantDeltas, gotDeltas)
+		})
+	}
+}
+
+func BenchmarkConvertHistogramBucketsToNHCBLayout(b *testing.B) {
+	scenarios := []struct {
+		gap int
+	}{
+		{gap: 0},
+		{gap: 1},
+		{gap: 2},
+		{gap: 3},
+	}
+
+	for _, scenario := range scenarios {
+		var buckets []uint64
+		for i := 0; i < 1000; i++ {
+			if i%(scenario.gap+1) == 0 {
+				buckets = append(buckets, uint64(10))
+			} else {
+				buckets = append(buckets, uint64(0))
+			}
+		}
+		b.Run(fmt.Sprintf("gap %d", scenario.gap), func(b *testing.B) {
+			for i := 0; i < b.N; i++ {
+				offset := getBucketOffset(buckets)
+				convertBucketsLayout(buckets, int32(offset), 0, false)
+			}
+		})
+	}
+}
+
+func TestHistogramToCustomBucketsHistogram(t *testing.T) {
+	tests := []struct {
+		name           string
+		hist           func() pmetric.HistogramDataPoint
+		wantNativeHist func() prompb.Histogram
+		wantErrMessage string
+	}{
+		{
+			name: "convert hist to custom buckets hist",
+			hist: func() pmetric.HistogramDataPoint {
+				pt := pmetric.NewHistogramDataPoint()
+				pt.SetStartTimestamp(pcommon.NewTimestampFromTime(time.UnixMilli(100)))
+				pt.SetTimestamp(pcommon.NewTimestampFromTime(time.UnixMilli(500)))
+				pt.SetCount(2)
+				pt.SetSum(10.1)
+
+				pt.BucketCounts().FromRaw([]uint64{1, 1})
+				pt.ExplicitBounds().FromRaw([]float64{0, 1})
+				return pt
+			},
+			wantNativeHist: func() prompb.Histogram {
+				return prompb.Histogram{
+					Count:          &prompb.Histogram_CountInt{CountInt: 2},
+					Sum:            10.1,
+					Schema:         -53,
+					PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 2}},
+					PositiveDeltas: []int64{1, 0},
+					CustomValues:   []float64{0, 1},
+					Timestamp:      500,
+				}
+			},
+		},
+		{
+			name: "convert hist to custom buckets hist with no sum",
+			hist: func() pmetric.HistogramDataPoint {
+				pt := pmetric.NewHistogramDataPoint()
+				pt.SetStartTimestamp(pcommon.NewTimestampFromTime(time.UnixMilli(100)))
+				pt.SetTimestamp(pcommon.NewTimestampFromTime(time.UnixMilli(500)))
+				pt.SetCount(4)
+
+				pt.BucketCounts().FromRaw([]uint64{2, 2})
+				pt.ExplicitBounds().FromRaw([]float64{0, 1})
+				return pt
+			},
+			wantNativeHist: func() prompb.Histogram {
+				return prompb.Histogram{
+					Count:          &prompb.Histogram_CountInt{CountInt: 4},
+					Schema:         -53,
+					PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 2}},
+					PositiveDeltas: []int64{2, 0},
+					CustomValues:   []float64{0, 1},
+					Timestamp:      500,
+				}
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			validateHistogramCount(t, tt.hist())
+			got, annots, err := explicitHistogramToCustomBucketsHistogram(tt.hist())
+			if tt.wantErrMessage != "" {
+				assert.ErrorContains(t, err, tt.wantErrMessage)
+				return
+			}
+
+			require.NoError(t, err)
+			require.Empty(t, annots)
+			assert.Equal(t, tt.wantNativeHist(), got)
+			validateNativeHistogramCount(t, got)
+		})
+	}
+}
+
+func TestPrometheusConverter_addCustomBucketsHistogramDataPoints(t *testing.T) {
+	tests := []struct {
+		name       string
+		metric     func() pmetric.Metric
+		wantSeries func() map[uint64]*prompb.TimeSeries
+	}{
+		{
+			name: "histogram data points with same labels",
+			metric: func() pmetric.Metric {
+				metric := pmetric.NewMetric()
+				metric.SetName("test_hist_to_nhcb")
+				metric.SetEmptyHistogram().SetAggregationTemporality(pmetric.AggregationTemporalityCumulative)
+
+				pt := metric.Histogram().DataPoints().AppendEmpty()
+				pt.SetCount(3)
+				pt.SetSum(3)
+				pt.BucketCounts().FromRaw([]uint64{2, 0, 1})
+				pt.ExplicitBounds().FromRaw([]float64{5, 10})
+				pt.Exemplars().AppendEmpty().SetDoubleValue(1)
+				pt.Attributes().PutStr("attr", "test_attr")
+
+				pt = metric.Histogram().DataPoints().AppendEmpty()
+				pt.SetCount(11)
+				pt.SetSum(5)
+				pt.BucketCounts().FromRaw([]uint64{3, 8, 0})
+				pt.ExplicitBounds().FromRaw([]float64{0, 1})
+				pt.Exemplars().AppendEmpty().SetDoubleValue(2)
+				pt.Attributes().PutStr("attr", "test_attr")
+
+				return metric
+			},
+			wantSeries: func() map[uint64]*prompb.TimeSeries {
+				labels := []prompb.Label{
+					{Name: model.MetricNameLabel, Value: "test_hist_to_nhcb"},
+					{Name: "attr", Value: "test_attr"},
+				}
+				return map[uint64]*prompb.TimeSeries{
+					timeSeriesSignature(labels): {
+						Labels: labels,
+						Histograms: []prompb.Histogram{
+							{
+								Count:          &prompb.Histogram_CountInt{CountInt: 3},
+								Sum:            3,
+								Schema:         -53,
+								PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 3}},
+								PositiveDeltas: []int64{2, -2, 1},
+								CustomValues:   []float64{5, 10},
+							},
+							{
+								Count:          &prompb.Histogram_CountInt{CountInt: 11},
+								Sum:            5,
+								Schema:         -53,
+								PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 3}},
+								PositiveDeltas: []int64{3, 5, -8},
+								CustomValues:   []float64{0, 1},
+							},
+						},
+						Exemplars: []prompb.Exemplar{
+							{Value: 1},
+							{Value: 2},
+						},
+					},
+				}
+			},
+		},
+		{
+			name: "histogram data points with different labels",
+			metric: func() pmetric.Metric {
+				metric := pmetric.NewMetric()
+				metric.SetName("test_hist_to_nhcb")
+				metric.SetEmptyHistogram().SetAggregationTemporality(pmetric.AggregationTemporalityCumulative)
+
+				pt := metric.Histogram().DataPoints().AppendEmpty()
+				pt.SetCount(6)
+				pt.SetSum(3)
+				pt.BucketCounts().FromRaw([]uint64{4, 2})
+				pt.ExplicitBounds().FromRaw([]float64{0, 1})
+				pt.Exemplars().AppendEmpty().SetDoubleValue(1)
+				pt.Attributes().PutStr("attr", "test_attr")
+
+				pt = metric.Histogram().DataPoints().AppendEmpty()
+				pt.SetCount(11)
+				pt.SetSum(5)
+				pt.BucketCounts().FromRaw([]uint64{3, 8})
+				pt.ExplicitBounds().FromRaw([]float64{0, 1})
+				pt.Exemplars().AppendEmpty().SetDoubleValue(2)
+				pt.Attributes().PutStr("attr", "test_attr_two")
+
+				return metric
+			},
+			wantSeries: func() map[uint64]*prompb.TimeSeries {
+				labels := []prompb.Label{
+					{Name: model.MetricNameLabel, Value: "test_hist_to_nhcb"},
+					{Name: "attr", Value: "test_attr"},
+				}
+				labelsAnother := []prompb.Label{
+					{Name: model.MetricNameLabel, Value: "test_hist_to_nhcb"},
+					{Name: "attr", Value: "test_attr_two"},
+				}
+
+				return map[uint64]*prompb.TimeSeries{
+					timeSeriesSignature(labels): {
+						Labels: labels,
+						Histograms: []prompb.Histogram{
+							{
+								Count:          &prompb.Histogram_CountInt{CountInt: 6},
+								Sum:            3,
+								Schema:         -53,
+								PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 2}},
+								PositiveDeltas: []int64{4, -2},
+								CustomValues:   []float64{0, 1},
+							},
+						},
+						Exemplars: []prompb.Exemplar{
+							{Value: 1},
+						},
+					},
+					timeSeriesSignature(labelsAnother): {
+						Labels: labelsAnother,
+						Histograms: []prompb.Histogram{
+							{
+								Count:          &prompb.Histogram_CountInt{CountInt: 11},
+								Sum:            5,
+								Schema:         -53,
+								PositiveSpans:  []prompb.BucketSpan{{Offset: 0, Length: 2}},
+								PositiveDeltas: []int64{3, 5},
+								CustomValues:   []float64{0, 1},
+							},
+						},
+						Exemplars: []prompb.Exemplar{
+							{Value: 2},
+						},
+					},
+				}
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			metric := tt.metric()
+
+			converter := NewPrometheusConverter()
+			annots, err := converter.addCustomBucketsHistogramDataPoints(
+				context.Background(),
+				metric.Histogram().DataPoints(),
+				pcommon.NewResource(),
+				Settings{
+					ExportCreatedMetric:     true,
+					ConvertHistogramsToNHCB: true,
+				},
+				otlptranslator.BuildCompliantMetricName(metric, "", true),
+			)
+
+			require.NoError(t, err)
+			require.Empty(t, annots)
+
+			assert.Equal(t, tt.wantSeries(), converter.unique)
+			assert.Empty(t, converter.conflicts)
+		})
+	}
+}
diff --git a/storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go b/storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go
--- a/storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go
+++ b/storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go
@@ -95,6 +95,51 @@ func TestFromMetrics(t *testing.T) {
 		})
 	}
 
+	for _, convertHistogramsToNHCB := range []bool{false, true} {
+		t.Run(fmt.Sprintf("successful/convertHistogramsToNHCB=%v", convertHistogramsToNHCB), func(t *testing.T) {
+			request := pmetricotlp.NewExportRequest()
+			rm := request.Metrics().ResourceMetrics().AppendEmpty()
+			generateAttributes(rm.Resource().Attributes(), "resource", 10)
+
+			metrics := rm.ScopeMetrics().AppendEmpty().Metrics()
+			ts := pcommon.NewTimestampFromTime(time.Now())
+
+			m := metrics.AppendEmpty()
+			m.SetEmptyHistogram()
+			m.SetName("histogram-1")
+			m.Histogram().SetAggregationTemporality(pmetric.AggregationTemporalityCumulative)
+			h := m.Histogram().DataPoints().AppendEmpty()
+			h.SetTimestamp(ts)
+
+			h.SetCount(15)
+			h.SetSum(155)
+
+			generateAttributes(h.Attributes(), "series", 1)
+
+			converter := NewPrometheusConverter()
+			annots, err := converter.FromMetrics(
+				context.Background(),
+				request.Metrics(),
+				Settings{ConvertHistogramsToNHCB: convertHistogramsToNHCB},
+			)
+			require.NoError(t, err)
+			require.Empty(t, annots)
+
+			series := converter.TimeSeries()
+
+			if convertHistogramsToNHCB {
+				require.Len(t, series[0].Histograms, 1)
+				require.Len(t, series[0].Samples, 0)
+			} else {
+				require.Len(t, series, 3)
+				for i := range series {
+					require.Len(t, series[i].Samples, 1)
+					require.Nil(t, series[i].Histograms)
+				}
+			}
+		})
+	}
+
 	t.Run("context cancellation", func(t *testing.T) {
 		converter := NewPrometheusConverter()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -151,6 +196,43 @@ func TestFromMetrics(t *testing.T) {
 			"exponential histogram data point has zero count, but non-zero sum: 155.000000",
 		}, ws)
 	})
+
+	t.Run("explicit histogram to NHCB warnings for zero count and non-zero sum", func(t *testing.T) {
+		request := pmetricotlp.NewExportRequest()
+		rm := request.Metrics().ResourceMetrics().AppendEmpty()
+		generateAttributes(rm.Resource().Attributes(), "resource", 10)
+
+		metrics := rm.ScopeMetrics().AppendEmpty().Metrics()
+		ts := pcommon.NewTimestampFromTime(time.Now())
+
+		for i := 1; i <= 10; i++ {
+			m := metrics.AppendEmpty()
+			m.SetEmptyHistogram()
+			m.SetName(fmt.Sprintf("histogram-%d", i))
+			m.Histogram().SetAggregationTemporality(pmetric.AggregationTemporalityCumulative)
+			h := m.Histogram().DataPoints().AppendEmpty()
+			h.SetTimestamp(ts)
+
+			h.SetCount(0)
+			h.SetSum(155)
+
+			generateAttributes(h.Attributes(), "series", 10)
+		}
+
+		converter := NewPrometheusConverter()
+		annots, err := converter.FromMetrics(
+			context.Background(),
+			request.Metrics(),
+			Settings{ConvertHistogramsToNHCB: true},
+		)
+		require.NoError(t, err)
+		require.NotEmpty(t, annots)
+		ws, infos := annots.AsStrings("", 0, 0)
+		require.Empty(t, infos)
+		require.Equal(t, []string{
+			"histogram data point has zero count, but non-zero sum: 155.000000",
+		}, ws)
+	})
 }
 
 func BenchmarkPrometheusConverter_FromMetrics(b *testing.B) {
EOF_114329324912

# Execute tests for each package separately to ensure all tests run
# Run config package tests
go test -v ./config/
rc1=$?

# Run storage/remote/otlptranslator/prometheusremotewrite package tests
go test -v ./storage/remote/otlptranslator/prometheusremotewrite/
rc2=$?

# Combine exit codes - if any test run fails, overall result should be failure
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout b39672736a3002895481ad0f17acc68a21d4a759 "config/config_test.go" "storage/remote/otlptranslator/prometheusremotewrite/histograms_test.go" "storage/remote/otlptranslator/prometheusremotewrite/metrics_to_prw_test.go"