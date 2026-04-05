#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 599002f890efac0ea6852453fe194d2687b461d8 "pkg/sfu/audio/audiolevel_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sfu/audio/audiolevel_test.go b/pkg/sfu/audio/audiolevel_test.go
--- a/pkg/sfu/audio/audiolevel_test.go
+++ b/pkg/sfu/audio/audiolevel_test.go
@@ -15,6 +15,7 @@
 package audio
 
 import (
+	"math/rand"
 	"testing"
 	"time"
 
@@ -104,6 +105,24 @@ func TestAudioLevel(t *testing.T) {
 		require.Equal(t, float64(0.0), level)
 		require.False(t, noisy)
 	})
+
+	t.Run("not noisy when samples are stale - with RTP timestamp", func(t *testing.T) {
+		clock := time.Now()
+		a := createAudioLevel(defaultActiveLevel, defaultPercentile, defaultObserveDuration)
+
+		observeSamplesWithRTPTimestamp(a, 25, 100, clock)
+		clock = clock.Add(100 * 20 * time.Millisecond)
+		level, noisy := a.GetLevel(clock.UnixNano())
+		require.True(t, noisy)
+		require.Greater(t, level, ConvertAudioLevel(float64(defaultActiveLevel)))
+		require.Less(t, level, ConvertAudioLevel(float64(20)))
+
+		// let enough time pass to make the samples stale
+		clock = clock.Add(1500 * time.Millisecond)
+		level, noisy = a.GetLevel(clock.UnixNano())
+		require.Equal(t, float64(0.0), level)
+		require.False(t, noisy)
+	})
 }
 
 func createAudioLevel(activeLevel uint8, minPercentile uint8, observeDuration uint32) *AudioLevel {
@@ -113,11 +132,26 @@ func createAudioLevel(activeLevel uint8, minPercentile uint8, observeDuration ui
 			MinPercentile:  minPercentile,
 			UpdateInterval: observeDuration,
 		},
+		ClockRate: 48000,
 	})
 }
 
 func observeSamples(a *AudioLevel, level uint8, count int, baseTime time.Time) {
 	for i := range count {
-		a.Observe(level, 20, baseTime.Add(+time.Duration(i*20)*time.Millisecond).UnixNano())
+		a.Observe(level, 20, baseTime.Add(time.Duration(i*20)*time.Millisecond).UnixNano())
+	}
+}
+
+func observeSamplesWithRTPTimestamp(a *AudioLevel, level uint8, count int, baseTime time.Time) {
+	sampleTS := uint32(rand.Intn(1 << 20))
+	sampleTime := baseTime
+	for i := range count {
+		if (i % 5) == 0 {
+			// out-of-order sample
+			a.ObserveWithRTPTimestamp(level, sampleTS-1920, sampleTime.UnixNano())
+		}
+		a.ObserveWithRTPTimestamp(level, sampleTS, sampleTime.UnixNano())
+		sampleTS += 960 // 20 ms at 48 kHz
+		sampleTime = sampleTime.Add(20 * time.Millisecond)
 	}
 }
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
export CGO_ENABLED=0
export GOOS=linux
export GO111MODULE=on

# Run the target test package with verbose output and disabled caching
# Testing the entire audio package to ensure all dependencies are compiled
go test -v -count=1 -timeout=4m ./pkg/sfu/audio/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 599002f890efac0ea6852453fe194d2687b461d8 "pkg/sfu/audio/audiolevel_test.go"