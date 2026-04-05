#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target commit and specific test file
git checkout 073c922c2064f4840b10cdb34a3450e3c80b927e "pkg/engine/engine_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/engine/engine_test.go b/pkg/engine/engine_test.go
--- a/pkg/engine/engine_test.go
+++ b/pkg/engine/engine_test.go
@@ -559,21 +559,18 @@ func TestProcessResult_SourceSupportsLineNumbers_LinkUpdated(t *testing.T) {
 	// Arrange: Create an engine
 	e := Engine{results: make(chan detectors.ResultWithMetadata, 1)}
 
-	// Arrange: Create a detectableChunk
-	data := detectableChunk{
-		chunk: sources.Chunk{
-			Data: []byte("abcde\nswordfish"),
-			SourceMetadata: &source_metadatapb.MetaData{
-				Data: &source_metadatapb.MetaData_Github{
-					Github: &source_metadatapb.Github{
-						Line: 1,
-						Link: "https://github.com/org/repo/blob/abcdef/file.txt#L1",
-					},
+	// Arrange: Create a Chunk
+	chunk := sources.Chunk{
+		Data: []byte("abcde\nswordfish"),
+		SourceMetadata: &source_metadatapb.MetaData{
+			Data: &source_metadatapb.MetaData_Github{
+				Github: &source_metadatapb.Github{
+					Line: 1,
+					Link: "https://github.com/org/repo/blob/abcdef/file.txt#L1",
 				},
 			},
-			SourceType: sourcespb.SourceType_SOURCE_TYPE_GIT,
 		},
-		detector: &ahocorasick.DetectorMatch{Detector: fakeDetectorV1{}},
+		SourceType: sourcespb.SourceType_SOURCE_TYPE_GIT,
 	}
 
 	// Arrange: Create a Result
@@ -583,7 +580,7 @@ func TestProcessResult_SourceSupportsLineNumbers_LinkUpdated(t *testing.T) {
 	}
 
 	// Act
-	e.processResult(context.AddLogger(t.Context()), data, result, nil)
+	e.processResult(context.AddLogger(t.Context()), result, chunk, 0, "", nil)
 
 	// Assert that the link has been correctly updated
 	require.Len(t, e.results, 1)
@@ -595,20 +592,17 @@ func TestProcessResult_IgnoreLinePresent_NothingGenerated(t *testing.T) {
 	// Arrange: Create an engine
 	e := Engine{results: make(chan detectors.ResultWithMetadata, 1)}
 
-	// Arrange: Create a detectableChunk
-	data := detectableChunk{
-		chunk: sources.Chunk{
-			Data: []byte("swordfish trufflehog:ignore"),
-			SourceMetadata: &source_metadatapb.MetaData{
-				Data: &source_metadatapb.MetaData_Git{
-					Git: &source_metadatapb.Git{
-						Line: 1,
-					},
+	// Arrange: Create a Chunk
+	chunk := sources.Chunk{
+		Data: []byte("swordfish trufflehog:ignore"),
+		SourceMetadata: &source_metadatapb.MetaData{
+			Data: &source_metadatapb.MetaData_Git{
+				Git: &source_metadatapb.Git{
+					Line: 1,
 				},
 			},
-			SourceType: sourcespb.SourceType_SOURCE_TYPE_GIT,
 		},
-		detector: &ahocorasick.DetectorMatch{Detector: fakeDetectorV1{}},
+		SourceType: sourcespb.SourceType_SOURCE_TYPE_GIT,
 	}
 
 	// Arrange: Create a Result
@@ -618,7 +612,7 @@ func TestProcessResult_IgnoreLinePresent_NothingGenerated(t *testing.T) {
 	}
 
 	// Act
-	e.processResult(context.AddLogger(t.Context()), data, result, nil)
+	e.processResult(context.AddLogger(t.Context()), result, chunk, 0, "", nil)
 
 	// Assert that no results were generated
 	assert.Empty(t, e.results)
@@ -628,27 +622,23 @@ func TestProcessResult_AllFieldsCopied(t *testing.T) {
 	// Arrange: Create an engine
 	e := Engine{results: make(chan detectors.ResultWithMetadata, 1)}
 
-	// Arrange: Create a detectableChunk
-	data := detectableChunk{
-		chunk: sources.Chunk{
-			SourceName: "test source",
-			SourceID:   1,
-			JobID:      2,
-			SecretID:   3,
-			SourceMetadata: &source_metadatapb.MetaData{
-				Data: &source_metadatapb.MetaData_Docker{
-					Docker: &source_metadatapb.Docker{
-						File:  "file",
-						Image: "image",
-						Layer: "layer",
-						Tag:   "tag",
-					},
+	// Arrange: Create a Chunk
+	chunk := sources.Chunk{
+		SourceName: "test source",
+		SourceID:   1,
+		JobID:      2,
+		SecretID:   3,
+		SourceMetadata: &source_metadatapb.MetaData{
+			Data: &source_metadatapb.MetaData_Docker{
+				Docker: &source_metadatapb.Docker{
+					File:  "file",
+					Image: "image",
+					Layer: "layer",
+					Tag:   "tag",
 				},
 			},
-			SourceType: sourcespb.SourceType_SOURCE_TYPE_DOCKER,
 		},
-		decoder:  detectorspb.DecoderType_PLAIN,
-		detector: &ahocorasick.DetectorMatch{Detector: fakeDetectorV1{}},
+		SourceType: sourcespb.SourceType_SOURCE_TYPE_DOCKER,
 	}
 
 	// Arrange: Create a Result
@@ -662,12 +652,12 @@ func TestProcessResult_AllFieldsCopied(t *testing.T) {
 	}
 
 	// Act
-	e.processResult(context.AddLogger(t.Context()), data, result, nil)
+	e.processResult(context.AddLogger(t.Context()), result, chunk, detectorspb.DecoderType_PLAIN, "a detector that detects", nil)
 
 	// Assert that the single generated result has the correct fields
 	require.Len(t, e.results, 1)
 	r := <-e.results
-	if diff := cmp.Diff(data.chunk.SourceMetadata, r.SourceMetadata, protocmp.Transform()); diff != "" {
+	if diff := cmp.Diff(chunk.SourceMetadata, r.SourceMetadata, protocmp.Transform()); diff != "" {
 		t.Errorf("metadata mismatch (-want +got):\n%s", diff)
 	}
 	assert.Equal(t, map[string]string{"key": "value"}, r.ExtraData)
@@ -682,6 +672,7 @@ func TestProcessResult_AllFieldsCopied(t *testing.T) {
 	assert.Equal(t, "test source", r.SourceName)
 	assert.Equal(t, sourcespb.SourceType_SOURCE_TYPE_DOCKER, r.SourceType)
 	assert.Equal(t, detectorspb.DecoderType_PLAIN, r.DecoderType)
+	assert.Equal(t, "a detector that detects", r.DetectorDescription)
 }
 
 func TestProcessResult_FalsePositiveFlagSetCorrectly(t *testing.T) {
@@ -722,10 +713,6 @@ func TestProcessResult_FalsePositiveFlagSetCorrectly(t *testing.T) {
 			// Arrange: Create an Engine
 			e := Engine{results: make(chan detectors.ResultWithMetadata, 1)}
 
-			// Arrange: Create a detectableChunk
-			// (It needs a DetectorMatch to avoid a panic.)
-			data := detectableChunk{detector: &ahocorasick.DetectorMatch{Detector: fakeDetectorV1{}}}
-
 			// Arrange: Create a Result
 			res := detectors.Result{
 				Raw:      []byte("something not nil"), // The false positive check is not run when Raw is nil
@@ -736,7 +723,7 @@ func TestProcessResult_FalsePositiveFlagSetCorrectly(t *testing.T) {
 			isFalsePositive := func(_ detectors.Result) (bool, string) { return tt.isFalsePositive, "" }
 
 			// Act
-			e.processResult(context.AddLogger(t.Context()), data, res, isFalsePositive)
+			e.processResult(context.AddLogger(t.Context()), res, sources.Chunk{}, 0, "", isFalsePositive)
 
 			// Assert that the single generated result has the correct false positive flag
 			require.Len(t, e.results, 1)
EOF_114329324912

# Set environment variables for Go testing
export CGO_ENABLED=0
export GO111MODULE=on
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Run the target test file
# Using -timeout=5m as specified in the Makefile
# Using -v for verbose output to help with debugging
go test -timeout=5m -v ./pkg/engine/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 073c922c2064f4840b10cdb34a3450e3c80b927e "pkg/engine/engine_test.go"