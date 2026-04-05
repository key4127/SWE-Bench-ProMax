#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9e839e34a6f4cbf53efe3c9c6d877a290acd3d79 "pkg/sources/chunker_test.go" "pkg/sources/filesystem/filesystem_test.go" "pkg/sources/jenkins/jenkins_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sources/chunker_test.go b/pkg/sources/chunker_test.go
--- a/pkg/sources/chunker_test.go
+++ b/pkg/sources/chunker_test.go
@@ -28,8 +28,8 @@ func TestNewChunkedReader(t *testing.T) {
 		{
 			name:       "Smaller data than default chunkSize and peekSize",
 			input:      "example input",
-			chunkSize:  ChunkSize,
-			peekSize:   PeekSize,
+			chunkSize:  DefaultChunkSize,
+			peekSize:   DefaultPeekSize,
 			wantChunks: []string{"example input"},
 			wantErr:    false,
 		},
@@ -142,7 +142,7 @@ func BenchmarkChunkReader(b *testing.B) {
 	var bigChunk = make([]byte, 1<<24) // 16MB
 
 	reader := bytes.NewReader(bigChunk)
-	chunkReader := NewChunkReader(WithChunkSize(ChunkSize), WithPeekSize(PeekSize))
+	chunkReader := NewChunkReader(WithChunkSize(DefaultChunkSize), WithPeekSize(DefaultPeekSize))
 
 	b.ReportAllocs()
 	b.ResetTimer()
diff --git a/pkg/sources/filesystem/filesystem_test.go b/pkg/sources/filesystem/filesystem_test.go
--- a/pkg/sources/filesystem/filesystem_test.go
+++ b/pkg/sources/filesystem/filesystem_test.go
@@ -95,7 +95,7 @@ func TestSource_Scan(t *testing.T) {
 }
 
 func TestScanFile(t *testing.T) {
-	chunkSize := sources.ChunkSize
+	chunkSize := sources.DefaultChunkSize
 	secretPart1 := "SECRET"
 	secretPart2 := "SPLIT"
 	// Split the secret into two parts and pad the rest of the chunk with A's.
diff --git a/pkg/sources/jenkins/jenkins_test.go b/pkg/sources/jenkins/jenkins_test.go
--- a/pkg/sources/jenkins/jenkins_test.go
+++ b/pkg/sources/jenkins/jenkins_test.go
@@ -93,11 +93,11 @@ func createMockJenkinsServer(jobName string, buildNumber int, logContent string)
 // logs to large CI/CD outputs.
 func TestJenkinsVariousSizes(t *testing.T) {
 	testCases := []struct {
-		name          string
-		dataSize      int
-		pattern       string
-		jobName       string
-		buildNumber   int
+		name        string
+		dataSize    int
+		pattern     string
+		jobName     string
+		buildNumber int
 	}{
 		{
 			name:        "small_60KB",
@@ -179,9 +179,9 @@ func TestJenkinsVariousSizes(t *testing.T) {
 			// Verify that large logs are actually being split into multiple chunks.
 			// This catches regressions where chunking logic might not be working.
 			// Data larger than a single chunk should result in multiple chunks.
-			if tc.dataSize > sources.ChunkSize && len(chunks) <= 1 {
+			if tc.dataSize > sources.DefaultChunkSize && len(chunks) <= 1 {
 				t.Logf("Got only %d chunk for data size %d bytes (chunk size: %d bytes), may indicate chunking not working as expected",
-					len(chunks), tc.dataSize, sources.ChunkSize)
+					len(chunks), tc.dataSize, sources.DefaultChunkSize)
 			}
 
 			// Ensure no individual chunk exceeds the maximum allowed size.
EOF_114329324912

# Set Go environment variables
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64

# Initialize exit code tracker
final_rc=0

# Run tests for each package separately and aggregate results
echo "=== Running tests in pkg/sources ==="
go test -v -timeout=5m ./pkg/sources
rc=$?
if [ $rc -ne 0 ]; then
    final_rc=$rc
fi

echo "=== Running tests in pkg/sources/filesystem ==="
go test -v -timeout=5m ./pkg/sources/filesystem
rc=$?
if [ $rc -ne 0 ]; then
    final_rc=$rc
fi

echo "=== Running tests in pkg/sources/jenkins ==="
go test -v -timeout=5m ./pkg/sources/jenkins
rc=$?
if [ $rc -ne 0 ]; then
    final_rc=$rc
fi

# Echo the final aggregated exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$final_rc"

# Restore the original test files
git checkout 9e839e34a6f4cbf53efe3c9c6d877a290acd3d79 "pkg/sources/chunker_test.go" "pkg/sources/filesystem/filesystem_test.go" "pkg/sources/jenkins/jenkins_test.go"