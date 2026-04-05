#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9c9cb8be2885321defbbaf2379c2dd8a1dd05d0d "go/store/nbs/archive_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/go/store/nbs/archive_test.go b/go/store/nbs/archive_test.go
--- a/go/store/nbs/archive_test.go
+++ b/go/store/nbs/archive_test.go
@@ -67,13 +67,15 @@ func TestArchiveSingleChunk(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	aIdx, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+
+	aIdx, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
 	assert.Equal(t, []uint64{23}, aIdx.prefixes)
 	assert.True(t, aIdx.has(oneHash))
 
-	dict, data, err := aIdx.getRaw(oneHash)
+	dict, data, err := aIdx.getRaw(context.Background(), oneHash, &Stats{})
 	assert.NoError(t, err)
 	assert.Nil(t, dict)
 	assert.Equal(t, testBlob, data)
@@ -100,13 +102,14 @@ func TestArchiveSingleChunkWithDictionary(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	aIdx, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	aIdx, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 	assert.Equal(t, []uint64{42}, aIdx.prefixes)
 
 	assert.True(t, aIdx.has(h))
 
-	dict, data, err := aIdx.getRaw(h)
+	dict, data, err := aIdx.getRaw(context.Background(), h, &Stats{})
 	assert.NoError(t, err)
 	assert.NotNil(t, dict)
 	assert.Equal(t, testData, data)
@@ -168,7 +171,8 @@ func TestArchiverMultipleChunksMultipleDictionaries(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	aIdx, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	aIdx, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 	assert.Equal(t, []uint64{21, 42, 42, 42, 42, 81, 88}, aIdx.prefixes)
 
@@ -183,31 +187,34 @@ func TestArchiverMultipleChunksMultipleDictionaries(t *testing.T) {
 	assert.False(t, aIdx.has(hashWithPrefix(t, 42)))
 	assert.False(t, aIdx.has(hashWithPrefix(t, 55)))
 
-	dict, data, _ := aIdx.getRaw(h1)
+	c := context.Background()
+	s := &Stats{}
+
+	dict, data, _ := aIdx.getRaw(c, h1, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data1, data)
 
-	dict, data, _ = aIdx.getRaw(h2)
+	dict, data, _ = aIdx.getRaw(c, h2, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data2, data)
 
-	dict, data, _ = aIdx.getRaw(h3)
+	dict, data, _ = aIdx.getRaw(c, h3, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data3, data)
 
-	dict, data, _ = aIdx.getRaw(h4)
+	dict, data, _ = aIdx.getRaw(c, h4, s)
 	assert.Nil(t, dict)
 	assert.Equal(t, data, data)
 
-	dict, data, _ = aIdx.getRaw(h5)
+	dict, data, _ = aIdx.getRaw(c, h5, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data1, data)
 
-	dict, data, _ = aIdx.getRaw(h6)
+	dict, data, _ = aIdx.getRaw(c, h6, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data1, data)
 
-	dict, data, _ = aIdx.getRaw(h7)
+	dict, data, _ = aIdx.getRaw(c, h7, s)
 	assert.NotNil(t, dict)
 	assert.Equal(t, data3, data)
 }
@@ -252,12 +259,16 @@ func TestArchiveDictDecompression(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	aIdx, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	aIdx, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
+	c := context.Background()
+	s := &Stats{}
+
 	// Now verify that we can look up the chunks by their original addresses, and the data is the same.
 	for _, chk := range chks {
-		roundTripData, err := aIdx.get(chk.Hash())
+		roundTripData, err := aIdx.get(c, chk.Hash(), s)
 		assert.NoError(t, err)
 		assert.Equal(t, chk.Data(), roundTripData)
 	}
@@ -278,10 +289,11 @@ func TestMetadata(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	rdr, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	rdr, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
-	md, err := rdr.getMetadata()
+	md, err := rdr.getMetadata(context.Background(), &Stats{})
 	assert.NoError(t, err)
 	assert.Equal(t, []byte("All work and no play"), md)
 }
@@ -308,13 +320,14 @@ func TestArchiveChunkCorruption(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	idx, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	idx, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
 	// Corrupt the data
 	writer.buff[len(defDict)+3] = writer.buff[len(defDict)+3] + 1
 
-	data, err := idx.get(h)
+	data, err := idx.get(context.Background(), h, &Stats{})
 	assert.ErrorContains(t, err, "cannot decompress invalid src")
 	assert.Nil(t, data)
 }
@@ -341,7 +354,8 @@ func TestArchiveCheckSumValidations(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	rdr, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	rdr, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
 	err = rdr.verifyDataCheckSum()
@@ -464,7 +478,8 @@ func TestFooterVersionAndSignature(t *testing.T) {
 	theBytes := writer.buff[:writer.pos]
 	fileSize := uint64(len(theBytes))
 	readerAt := bytes.NewReader(theBytes)
-	rdr, err := newArchiveReader(readerAt, fileSize)
+	fr := newFlexibleReader(readerAt)
+	rdr, err := newArchiveReader(fr, fileSize)
 	assert.NoError(t, err)
 
 	assert.Equal(t, archiveFormatVersion, rdr.footer.formatVersion)
@@ -473,14 +488,16 @@ func TestFooterVersionAndSignature(t *testing.T) {
 	// Corrupt the version
 	theBytes[fileSize-archiveFooterSize+afrVersionOffset] = 23
 	readerAt = bytes.NewReader(theBytes)
-	_, err = newArchiveReader(readerAt, fileSize)
+	fr = newFlexibleReader(readerAt)
+	_, err = newArchiveReader(fr, fileSize)
 	assert.ErrorContains(t, err, "invalid format version")
 
 	// Corrupt the signature, but first restore the version.
 	theBytes[fileSize-archiveFooterSize+afrVersionOffset] = archiveFormatVersion
 	theBytes[fileSize-archiveFooterSize+afrSigOffset+2] = 'X'
 	readerAt = bytes.NewReader(theBytes)
-	_, err = newArchiveReader(readerAt, fileSize)
+	fr = newFlexibleReader(readerAt)
+	_, err = newArchiveReader(fr, fileSize)
 	assert.ErrorContains(t, err, "invalid file signature")
 
 }
EOF_114329324912

# Navigate to the Go module directory
cd /testbed/go

# Ensure environment variables are set
export PATH=/usr/local/go/bin:$PATH
export GOPATH=/root/go
export PATH=$GOPATH/bin:$PATH
export CGO_ENABLED=1

# Run the specific test file
# Using -v for verbose output to help with debugging
# Running tests from the store/nbs package targeting archive_test.go
go test -v ./store/nbs -run ".*" -count=1

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
cd /testbed
git checkout 9c9cb8be2885321defbbaf2379c2dd8a1dd05d0d "go/store/nbs/archive_test.go"