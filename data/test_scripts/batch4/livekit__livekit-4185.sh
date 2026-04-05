#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 4104b8270ba8c653f80a27737bd125f06ef0e06d "pkg/sfu/redreceiver_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sfu/redreceiver_test.go b/pkg/sfu/redreceiver_test.go
--- a/pkg/sfu/redreceiver_test.go
+++ b/pkg/sfu/redreceiver_test.go
@@ -42,18 +42,20 @@ func (dt *dummyDowntrack) WriteRTP(p *buffer.ExtPacket, _ int32) int32 {
 	return 1
 }
 
-func (dt *dummyDowntrack) TrackInfoAvailable() {}
-
 func TestRedReceiver(t *testing.T) {
 	dt := &dummyDowntrack{TrackSender: &DownTrack{}}
 
 	t.Run("normal", func(t *testing.T) {
 		w := &WebRTCReceiver{
-			isRED:  true,
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+				},
+				isRED: true,
+			},
 		}
-		require.Equal(t, w.GetRedReceiver(), w)
+		require.Equal(t, w.GetRedReceiver(), w.ReceiverBase)
 		w.isRED = false
 		red := w.GetRedReceiver().(*RedReceiver)
 		require.NotNil(t, red)
@@ -75,8 +77,12 @@ func TestRedReceiver(t *testing.T) {
 
 	t.Run("packet lost and jump", func(t *testing.T) {
 		w := &WebRTCReceiver{
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+				},
+			},
 		}
 		red := w.GetRedReceiver().(*RedReceiver)
 		require.NoError(t, red.AddDownTrack(dt))
@@ -126,8 +132,12 @@ func TestRedReceiver(t *testing.T) {
 
 	t.Run("unorder and repeat", func(t *testing.T) {
 		w := &WebRTCReceiver{
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+				},
+			},
 		}
 		red := w.GetRedReceiver().(*RedReceiver)
 		require.NoError(t, red.AddDownTrack(dt))
@@ -158,11 +168,15 @@ func TestRedReceiver(t *testing.T) {
 
 	t.Run("encoding exceed space", func(t *testing.T) {
 		w := &WebRTCReceiver{
-			isRED:  true,
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+				},
+				isRED: true,
+			},
 		}
-		require.Equal(t, w.GetRedReceiver(), w)
+		require.Equal(t, w.GetRedReceiver(), w.ReceiverBase)
 		w.isRED = false
 		red := w.GetRedReceiver().(*RedReceiver)
 		require.NotNil(t, red)
@@ -183,11 +197,15 @@ func TestRedReceiver(t *testing.T) {
 
 	t.Run("large timestamp gap", func(t *testing.T) {
 		w := &WebRTCReceiver{
-			isRED:  true,
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+				},
+				isRED: true,
+			},
 		}
-		require.Equal(t, w.GetRedReceiver(), w)
+		require.Equal(t, w.GetRedReceiver(), w.ReceiverBase)
 		w.isRED = false
 		red := w.GetRedReceiver().(*RedReceiver)
 		require.NotNil(t, red)
@@ -283,11 +301,15 @@ func generateRedPkts(t *testing.T, pkts []*rtp.Packet, redCount int) []*rtp.Pack
 func testRedRedPrimaryReceiver(t *testing.T, maxPktCount, redCount int, sendPktIdx, expectPktIdx []int) {
 	dt := &dummyDowntrack{TrackSender: &DownTrack{}}
 	w := &WebRTCReceiver{
-		kind:   webrtc.RTPCodecTypeAudio,
-		logger: logger.GetLogger(),
-		codec:  webrtc.RTPCodecParameters{PayloadType: opusREDPT, RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: "audio/red"}},
+		ReceiverBase: &ReceiverBase{
+			params: ReceiverBaseParams{
+				Kind:   webrtc.RTPCodecTypeAudio,
+				Logger: logger.GetLogger(),
+				Codec:  webrtc.RTPCodecParameters{PayloadType: opusREDPT, RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: "audio/red"}},
+			},
+		},
 	}
-	require.Equal(t, w.GetPrimaryReceiverForRed(), w)
+	require.Equal(t, w.GetPrimaryReceiverForRed(), w.ReceiverBase)
 	w.isRED = true
 	red := w.GetPrimaryReceiverForRed().(*RedPrimaryReceiver)
 	require.NotNil(t, red)
@@ -313,10 +335,14 @@ func testRedRedPrimaryReceiver(t *testing.T, maxPktCount, redCount int, sendPktI
 
 func TestRedPrimaryReceiver(t *testing.T) {
 	w := &WebRTCReceiver{
-		kind:   webrtc.RTPCodecTypeAudio,
-		logger: logger.GetLogger(),
+		ReceiverBase: &ReceiverBase{
+			params: ReceiverBaseParams{
+				Kind:   webrtc.RTPCodecTypeAudio,
+				Logger: logger.GetLogger(),
+			},
+		},
 	}
-	require.Equal(t, w.GetPrimaryReceiverForRed(), w)
+	require.Equal(t, w.GetPrimaryReceiverForRed(), w.ReceiverBase)
 	w.isRED = true
 	red := w.GetPrimaryReceiverForRed().(*RedPrimaryReceiver)
 	require.NotNil(t, red)
@@ -383,11 +409,15 @@ func TestRedPrimaryReceiver(t *testing.T) {
 	t.Run("mixed primary codec", func(t *testing.T) {
 		dt := &dummyDowntrack{TrackSender: &DownTrack{}}
 		w := &WebRTCReceiver{
-			kind:   webrtc.RTPCodecTypeAudio,
-			logger: logger.GetLogger(),
-			codec:  webrtc.RTPCodecParameters{PayloadType: opusREDPT, RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: "audio/red"}},
+			ReceiverBase: &ReceiverBase{
+				params: ReceiverBaseParams{
+					Kind:   webrtc.RTPCodecTypeAudio,
+					Logger: logger.GetLogger(),
+					Codec:  webrtc.RTPCodecParameters{PayloadType: opusREDPT, RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: "audio/red"}},
+				},
+			},
 		}
-		require.Equal(t, w.GetPrimaryReceiverForRed(), w)
+		require.Equal(t, w.GetPrimaryReceiverForRed(), w.ReceiverBase)
 		w.isRED = true
 		red := w.GetPrimaryReceiverForRed().(*RedPrimaryReceiver)
 		require.NotNil(t, red)
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
export CGO_ENABLED=0
export GOOS=linux
export GO111MODULE=on

# Run the target test file with verbose output and disabled caching
# Using the recommended test command from context retrieval agent
go test -v -count=1 -timeout=4m ./pkg/sfu -run "TestRed.*"
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 4104b8270ba8c653f80a27737bd125f06ef0e06d "pkg/sfu/redreceiver_test.go"