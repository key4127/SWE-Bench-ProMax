#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Set required environment variables
export CGO_ENABLED=1
export GO111MODULE=on
export TZ=Asia/Shanghai
export log_level=fatal

# Checkout the target test files to ensure clean state
git checkout 920ee6e01185ef79b9728cccc400ed86412e94ce \
    "dumpling/export/writer_serial_test.go" \
    "pkg/lightning/backend/external/bench_test.go" \
    "pkg/lightning/backend/external/byte_reader_test.go" \
    "pkg/lightning/backend/external/iter_test.go" \
    "pkg/lightning/backend/external/writer_test.go" \
    "pkg/objstore/azblob_test.go" \
    "pkg/objstore/compress_test.go" \
    "pkg/objstore/local_test.go" \
    "pkg/objstore/writer_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/dumpling/export/writer_serial_test.go b/dumpling/export/writer_serial_test.go
--- a/dumpling/export/writer_serial_test.go
+++ b/dumpling/export/writer_serial_test.go
@@ -3,25 +3,62 @@
 package export
 
 import (
+	"bytes"
+	"context"
 	"database/sql/driver"
 	"fmt"
 	"strings"
 	"testing"
 
 	"github.com/pingcap/errors"
 	tcontext "github.com/pingcap/tidb/dumpling/context"
-	"github.com/pingcap/tidb/pkg/objstore"
 	"github.com/pingcap/tidb/pkg/util/promutil"
 	"github.com/stretchr/testify/require"
 )
 
+// BytesWriter is a Writer implementation on top of bytes.Buffer that is useful for testing.
+type BytesWriter struct {
+	buf *bytes.Buffer
+}
+
+// Write delegates to bytes.Buffer.
+func (u *BytesWriter) Write(_ context.Context, p []byte) (int, error) {
+	return u.buf.Write(p)
+}
+
+// Close delegates to bytes.Buffer.
+func (*BytesWriter) Close(_ context.Context) error {
+	// noop
+	return nil
+}
+
+// Bytes delegates to bytes.Buffer.
+func (u *BytesWriter) Bytes() []byte {
+	return u.buf.Bytes()
+}
+
+// String delegates to bytes.Buffer.
+func (u *BytesWriter) String() string {
+	return u.buf.String()
+}
+
+// Reset delegates to bytes.Buffer.
+func (u *BytesWriter) Reset() {
+	u.buf.Reset()
+}
+
+// NewBufferWriter creates a Writer that simply writes to a buffer (useful for testing).
+func NewBufferWriter() *BytesWriter {
+	return &BytesWriter{buf: &bytes.Buffer{}}
+}
+
 func TestWriteMeta(t *testing.T) {
 	createTableStmt := "CREATE TABLE `t1` (\n" +
 		"  `a` int(11) DEFAULT NULL\n" +
 		") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;\n"
 	specCmts := []string{"/*!40103 SET TIME_ZONE='+00:00' */;"}
 	meta := newMockMetaIR("t1", createTableStmt, specCmts)
-	writer := objstore.NewBufferWriter()
+	writer := NewBufferWriter()
 
 	err := WriteMeta(tcontext.Background(), meta, writer)
 	require.NoError(t, err)
@@ -48,7 +85,7 @@ func TestWriteInsert(t *testing.T) {
 		"/*!40014 SET FOREIGN_KEY_CHECKS=0*/;",
 	}
 	tableIR := newMockTableIR("test", "employee", data, specCmts, colTypes)
-	bf := objstore.NewBufferWriter()
+	bf := NewBufferWriter()
 
 	conf := configForWriteSQL(cfg, UnspecifiedSize, UnspecifiedSize)
 	m := newMetrics(conf.PromFactory, conf.Labels)
@@ -86,7 +123,7 @@ func TestWriteInsertReturnsError(t *testing.T) {
 	rowErr := errors.New("mock row error")
 	tableIR := newMockTableIR("test", "employee", data, specCmts, colTypes)
 	tableIR.rowErr = rowErr
-	bf := objstore.NewBufferWriter()
+	bf := NewBufferWriter()
 
 	conf := configForWriteSQL(cfg, UnspecifiedSize, UnspecifiedSize)
 	m := newMetrics(conf.PromFactory, conf.Labels)
@@ -117,7 +154,7 @@ func TestWriteInsertInCsv(t *testing.T) {
 	}
 	colTypes := []string{"INT", "SET", "VARCHAR", "VARCHAR", "TEXT"}
 	tableIR := newMockTableIR("test", "employee", data, nil, colTypes)
-	bf := objstore.NewBufferWriter()
+	bf := NewBufferWriter()
 
 	// test nullValue
 	opt := &csvOption{separator: []byte(","), delimiter: []byte{'"'}, nullValue: "\\N", lineTerminator: []byte("\r\n")}
@@ -227,7 +264,7 @@ func TestWriteInsertInCsvReturnsError(t *testing.T) {
 	rowErr := errors.New("mock row error")
 	tableIR := newMockTableIR("test", "employee", data, nil, colTypes)
 	tableIR.rowErr = rowErr
-	bf := objstore.NewBufferWriter()
+	bf := NewBufferWriter()
 
 	// test nullValue
 	opt := &csvOption{separator: []byte(","), delimiter: []byte{'"'}, nullValue: "\\N", lineTerminator: []byte("\r\n")}
@@ -263,7 +300,7 @@ func TestWriteInsertInCsvWithDialect(t *testing.T) {
 		conf.CsvOutputDialect = CSVDialectDefault
 		tableIR := newMockTableIR("test", "employee", data, nil, colTypes)
 		m := newMetrics(conf.PromFactory, conf.Labels)
-		bf := objstore.NewBufferWriter()
+		bf := NewBufferWriter()
 		n, err := WriteInsertInCsv(tcontext.Background(), conf, tableIR, tableIR, bf, m)
 		require.NoError(t, err)
 		require.Equal(t, uint64(4), n)
@@ -281,7 +318,7 @@ func TestWriteInsertInCsvWithDialect(t *testing.T) {
 		conf.CsvOutputDialect = CSVDialectRedshift
 		tableIR := newMockTableIR("test", "employee", data, nil, colTypes)
 		m := newMetrics(conf.PromFactory, conf.Labels)
-		bf := objstore.NewBufferWriter()
+		bf := NewBufferWriter()
 		n, err := WriteInsertInCsv(tcontext.Background(), conf, tableIR, tableIR, bf, m)
 		require.NoError(t, err)
 		require.Equal(t, uint64(4), n)
@@ -299,7 +336,7 @@ func TestWriteInsertInCsvWithDialect(t *testing.T) {
 		conf.CsvOutputDialect = CSVDialectBigQuery
 		tableIR := newMockTableIR("test", "employee", data, nil, colTypes)
 		m := newMetrics(conf.PromFactory, conf.Labels)
-		bf := objstore.NewBufferWriter()
+		bf := NewBufferWriter()
 		n, err := WriteInsertInCsv(tcontext.Background(), conf, tableIR, tableIR, bf, m)
 		require.NoError(t, err)
 		require.Equal(t, uint64(4), n)
@@ -329,7 +366,7 @@ func TestSQLDataTypes(t *testing.T) {
 		tableData := [][]driver.Value{{origin}}
 		colType := []string{sqlType}
 		tableIR := newMockTableIR("test", "t", tableData, nil, colType)
-		bf := objstore.NewBufferWriter()
+		bf := NewBufferWriter()
 
 		conf := configForWriteSQL(cfg, UnspecifiedSize, UnspecifiedSize)
 		m := newMetrics(conf.PromFactory, conf.Labels)
diff --git a/pkg/lightning/backend/external/bench_test.go b/pkg/lightning/backend/external/bench_test.go
--- a/pkg/lightning/backend/external/bench_test.go
+++ b/pkg/lightning/backend/external/bench_test.go
@@ -31,6 +31,7 @@ import (
 	"github.com/pingcap/tidb/pkg/kv"
 	"github.com/pingcap/tidb/pkg/lightning/membuf"
 	"github.com/pingcap/tidb/pkg/objstore"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/pingcap/tidb/pkg/resourcemanager/pool/workerpool"
 	"github.com/pingcap/tidb/pkg/util/intest"
 	"github.com/pingcap/tidb/pkg/util/size"
@@ -61,7 +62,7 @@ func writePlainFile(s *writeTestSuite) {
 	_ = s.store.DeleteFile(ctx, filePath)
 	buf := make([]byte, s.memoryLimit)
 	offset := 0
-	flush := func(w objstore.FileWriter) {
+	flush := func(w objectio.Writer) {
 		n, err := w.Write(ctx, buf[:offset])
 		intest.AssertNoError(err)
 		intest.Assert(offset == n)
diff --git a/pkg/lightning/backend/external/byte_reader_test.go b/pkg/lightning/backend/external/byte_reader_test.go
--- a/pkg/lightning/backend/external/byte_reader_test.go
+++ b/pkg/lightning/backend/external/byte_reader_test.go
@@ -33,6 +33,7 @@ import (
 	"github.com/pingcap/tidb/pkg/lightning/common"
 	"github.com/pingcap/tidb/pkg/lightning/membuf"
 	"github.com/pingcap/tidb/pkg/objstore"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/stretchr/testify/require"
 	"golang.org/x/exp/rand"
 )
@@ -73,7 +74,7 @@ func TestByteReader(t *testing.T) {
 	err := st.WriteFile(context.Background(), "testfile", []byte("abcde"))
 	require.NoError(t, err)
 
-	newRsc := func() objstore.FileReader {
+	newRsc := func() objectio.Reader {
 		rsc, err := st.Open(context.Background(), "testfile", nil)
 		require.NoError(t, err)
 		return rsc
@@ -170,7 +171,7 @@ func TestUnexpectedEOF(t *testing.T) {
 	err := st.WriteFile(context.Background(), "testfile", []byte("0123456789"))
 	require.NoError(t, err)
 
-	newRsc := func() objstore.FileReader {
+	newRsc := func() objectio.Reader {
 		rsc, err := st.Open(context.Background(), "testfile", nil)
 		require.NoError(t, err)
 		return rsc
@@ -199,7 +200,7 @@ func TestEmptyContent(t *testing.T) {
 	err = st.WriteFile(context.Background(), "testfile", []byte(""))
 	require.NoError(t, err)
 
-	newRsc := func() objstore.FileReader {
+	newRsc := func() objectio.Reader {
 		rsc, err := st.Open(context.Background(), "testfile", nil)
 		require.NoError(t, err)
 		return rsc
diff --git a/pkg/lightning/backend/external/iter_test.go b/pkg/lightning/backend/external/iter_test.go
--- a/pkg/lightning/backend/external/iter_test.go
+++ b/pkg/lightning/backend/external/iter_test.go
@@ -26,6 +26,7 @@ import (
 	"github.com/pingcap/tidb/pkg/lightning/common"
 	"github.com/pingcap/tidb/pkg/lightning/membuf"
 	"github.com/pingcap/tidb/pkg/objstore"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/pingcap/tidb/pkg/util/logutil"
 	"github.com/stretchr/testify/require"
 	"go.uber.org/atomic"
@@ -37,7 +38,7 @@ type trackOpenMemStorage struct {
 	opened atomic.Int32
 }
 
-func (s *trackOpenMemStorage) Open(ctx context.Context, path string, _ *objstore.ReaderOption) (objstore.FileReader, error) {
+func (s *trackOpenMemStorage) Open(ctx context.Context, path string, _ *objstore.ReaderOption) (objectio.Reader, error) {
 	s.opened.Inc()
 	r, err := s.MemStorage.Open(ctx, path, nil)
 	if err != nil {
@@ -47,12 +48,12 @@ func (s *trackOpenMemStorage) Open(ctx context.Context, path string, _ *objstore
 }
 
 type trackOpenFileReader struct {
-	objstore.FileReader
+	objectio.Reader
 	store *trackOpenMemStorage
 }
 
 func (r *trackOpenFileReader) Close() error {
-	err := r.FileReader.Close()
+	err := r.Reader.Close()
 	if err != nil {
 		return err
 	}
@@ -320,7 +321,7 @@ func testMergeIterSwitchMode(t *testing.T, f func([]byte, int) []byte) {
 }
 
 type eofReader struct {
-	objstore.FileReader
+	objectio.Reader
 }
 
 func (r eofReader) Seek(_ int64, _ int) (int64, error) {
@@ -651,7 +652,7 @@ func (s *slowOpenStorage) Open(
 	ctx context.Context,
 	filePath string,
 	o *objstore.ReaderOption,
-) (objstore.FileReader, error) {
+) (objectio.Reader, error) {
 	time.Sleep(s.sleep)
 	s.openCnt.Inc()
 	return s.MemStorage.Open(ctx, filePath, o)
diff --git a/pkg/lightning/backend/external/writer_test.go b/pkg/lightning/backend/external/writer_test.go
--- a/pkg/lightning/backend/external/writer_test.go
+++ b/pkg/lightning/backend/external/writer_test.go
@@ -37,6 +37,7 @@ import (
 	"github.com/pingcap/tidb/pkg/lightning/common"
 	"github.com/pingcap/tidb/pkg/lightning/log"
 	"github.com/pingcap/tidb/pkg/objstore"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/pingcap/tidb/pkg/util/logutil"
 	"github.com/pingcap/tidb/pkg/util/size"
 	"github.com/stretchr/testify/require"
@@ -495,19 +496,19 @@ func (s *writerFirstCloseFailStorage) Create(
 	ctx context.Context,
 	path string,
 	option *objstore.WriterOption,
-) (objstore.FileWriter, error) {
+) (objectio.Writer, error) {
 	w, err := s.Storage.Create(ctx, path, option)
 	if err != nil {
 		return nil, err
 	}
 	if strings.Contains(path, statSuffix) {
-		return &firstCloseFailWriter{FileWriter: w, shouldFail: &s.shouldFail}, nil
+		return &firstCloseFailWriter{Writer: w, shouldFail: &s.shouldFail}, nil
 	}
 	return w, nil
 }
 
 type firstCloseFailWriter struct {
-	objstore.FileWriter
+	objectio.Writer
 	shouldFail *bool
 }
 
@@ -516,7 +517,7 @@ func (w *firstCloseFailWriter) Close(ctx context.Context) error {
 		*w.shouldFail = false
 		return fmt.Errorf("first close fail")
 	}
-	return w.FileWriter.Close(ctx)
+	return w.Writer.Close(ctx)
 }
 
 func TestFlushKVsRetry(t *testing.T) {
diff --git a/pkg/objstore/azblob_test.go b/pkg/objstore/azblob_test.go
--- a/pkg/objstore/azblob_test.go
+++ b/pkg/objstore/azblob_test.go
@@ -30,6 +30,7 @@ import (
 	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/bloberror"
 	"github.com/pingcap/errors"
 	backuppb "github.com/pingcap/kvproto/pkg/brpb"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/stretchr/testify/require"
 )
 
@@ -464,7 +465,7 @@ func TestAzblobSeekToEndShouldNotError(t *testing.T) {
 }
 
 type wr struct {
-	w   FileWriter
+	w   objectio.Writer
 	ctx context.Context
 }
 
diff --git a/pkg/objstore/compress_test.go b/pkg/objstore/compress_test.go
--- a/pkg/objstore/compress_test.go
+++ b/pkg/objstore/compress_test.go
@@ -22,6 +22,7 @@ import (
 	"strings"
 	"testing"
 
+	"github.com/pingcap/tidb/pkg/objstore/compressedio"
 	"github.com/stretchr/testify/require"
 )
 
@@ -32,7 +33,7 @@ func TestWithCompressReadWriteFile(t *testing.T) {
 	ctx := context.Background()
 	storage, err := Create(ctx, backend, true)
 	require.NoError(t, err)
-	storage = WithCompression(storage, Gzip, DecompressConfig{})
+	storage = WithCompression(storage, compressedio.Gzip, compressedio.DecompressConfig{})
 	name := "with compress test"
 	content := "hello,world!"
 	fileName := strings.ReplaceAll(name, " ", "-") + ".txt.gz"
@@ -42,7 +43,7 @@ func TestWithCompressReadWriteFile(t *testing.T) {
 	// make sure compressed file is written correctly
 	file, err := os.Open(filepath.Join(dir, fileName))
 	require.NoError(t, err)
-	uncompressedFile, err := newCompressReader(Gzip, DecompressConfig{}, file)
+	uncompressedFile, err := compressedio.NewReader(compressedio.Gzip, compressedio.DecompressConfig{}, file)
 	require.NoError(t, err)
 	newContent, err := io.ReadAll(uncompressedFile)
 	require.NoError(t, err)
diff --git a/pkg/objstore/local_test.go b/pkg/objstore/local_test.go
--- a/pkg/objstore/local_test.go
+++ b/pkg/objstore/local_test.go
@@ -24,6 +24,7 @@ import (
 	"testing"
 
 	"github.com/pingcap/errors"
+	"github.com/pingcap/tidb/pkg/objstore/objectio"
 	"github.com/stretchr/testify/require"
 )
 
@@ -199,7 +200,7 @@ func TestLocalFileReadRange(t *testing.T) {
 	require.NoError(t, err)
 	require.NoError(t, w.Close(ctx))
 
-	checkContent := func(r FileReader, expected string) {
+	checkContent := func(r objectio.Reader, expected string) {
 		buf := make([]byte, 10)
 		n, _ := r.Read(buf)
 		require.Equal(t, expected, string(buf[:n]))
diff --git a/pkg/objstore/writer_test.go b/pkg/objstore/objectio/writer_test.go
rename from pkg/objstore/writer_test.go
rename to pkg/objstore/objectio/writer_test.go
--- a/pkg/objstore/writer_test.go
+++ b/pkg/objstore/objectio/writer_test.go
@@ -12,7 +12,7 @@
 // See the License for the specific language governing permissions and
 // limitations under the License.
 
-package objstore
+package objectio_test
 
 import (
 	"bytes"
@@ -25,9 +25,36 @@ import (
 	"testing"
 
 	"github.com/klauspost/compress/zstd"
+	"github.com/pingcap/tidb/pkg/objstore"
+	"github.com/pingcap/tidb/pkg/objstore/compressedio"
 	"github.com/stretchr/testify/require"
 )
 
+func getStore(t *testing.T, uri string, changeStoreFn func(s objstore.Storage) objstore.Storage) objstore.Storage {
+	t.Helper()
+	backend, err := objstore.ParseBackend(uri, nil)
+	require.NoError(t, err)
+	ctx := context.Background()
+	storage, err := objstore.Create(ctx, backend, true)
+	require.NoError(t, err)
+	return changeStoreFn(storage)
+}
+
+func writeFile(t *testing.T, storage objstore.Storage, fileName string, lines []string) {
+	t.Helper()
+	ctx := context.Background()
+	writer, err := storage.Create(ctx, fileName, nil)
+	require.NoError(t, err)
+	for _, str := range lines {
+		p := []byte(str)
+		written, err2 := writer.Write(ctx, p)
+		require.Nil(t, err2)
+		require.Len(t, p, written)
+	}
+	err = writer.Close(ctx)
+	require.NoError(t, err)
+}
+
 func TestExternalFileWriter(t *testing.T) {
 	dir := t.TempDir()
 
@@ -37,22 +64,11 @@ func TestExternalFileWriter(t *testing.T) {
 	}
 	testFn := func(test *testcase, t *testing.T) {
 		t.Log(test.name)
-		backend, err := ParseBackend("local://"+filepath.ToSlash(dir), nil)
-		require.NoError(t, err)
-		ctx := context.Background()
-		storage, err := Create(ctx, backend, true)
-		require.NoError(t, err)
+		storage := getStore(t, "local://"+filepath.ToSlash(dir), func(s objstore.Storage) objstore.Storage {
+			return s
+		})
 		fileName := strings.ReplaceAll(test.name, " ", "-") + ".txt"
-		writer, err := storage.Create(ctx, fileName, nil)
-		require.NoError(t, err)
-		for _, str := range test.content {
-			p := []byte(str)
-			written, err2 := writer.Write(ctx, p)
-			require.Nil(t, err2)
-			require.Len(t, p, written)
-		}
-		err = writer.Close(ctx)
-		require.NoError(t, err)
+		writeFile(t, storage, fileName, test.content)
 		content, err := os.ReadFile(filepath.Join(dir, fileName))
 		require.NoError(t, err)
 		require.Equal(t, strings.Join(test.content, ""), string(content))
@@ -107,40 +123,29 @@ func TestCompressReaderWriter(t *testing.T) {
 	type testcase struct {
 		name         string
 		content      []string
-		compressType CompressType
+		compressType compressedio.CompressType
 	}
 	testFn := func(test *testcase, t *testing.T) {
 		t.Log(test.name)
-		backend, err := ParseBackend("local://"+filepath.ToSlash(dir), nil)
-		require.NoError(t, err)
-		ctx := context.Background()
-		storage, err := Create(ctx, backend, true)
-		require.NoError(t, err)
-		storage = WithCompression(storage, test.compressType, DecompressConfig{})
-		suffix := createSuffixString(test.compressType)
+		suffix := test.compressType.FileSuffix()
 		fileName := strings.ReplaceAll(test.name, " ", "-") + suffix
-		writer, err := storage.Create(ctx, fileName, nil)
-		require.NoError(t, err)
-		for _, str := range test.content {
-			p := []byte(str)
-			written, err2 := writer.Write(ctx, p)
-			require.Nil(t, err2)
-			require.Len(t, p, written)
-		}
-		err = writer.Close(ctx)
-		require.NoError(t, err)
+		storage := getStore(t, "local://"+filepath.ToSlash(dir), func(s objstore.Storage) objstore.Storage {
+			return objstore.WithCompression(s, test.compressType, compressedio.DecompressConfig{})
+		})
+		writeFile(t, storage, fileName, test.content)
 
 		// make sure compressed file is written correctly
 		file, err := os.Open(filepath.Join(dir, fileName))
 		require.NoError(t, err)
-		r, err := newCompressReader(test.compressType, DecompressConfig{}, file)
+		r, err := compressedio.NewReader(test.compressType, compressedio.DecompressConfig{}, file)
 		require.NoError(t, err)
 		var bf bytes.Buffer
 		_, err = bf.ReadFrom(r)
 		require.NoError(t, err)
 		require.Equal(t, strings.Join(test.content, ""), bf.String())
 
 		// test withCompression Open
+		ctx := context.Background()
 		r, err = storage.Open(ctx, fileName, nil)
 		require.NoError(t, err)
 		content, err := io.ReadAll(r)
@@ -149,7 +154,7 @@ func TestCompressReaderWriter(t *testing.T) {
 
 		require.Nil(t, file.Close())
 	}
-	compressTypeArr := []CompressType{Gzip, Snappy, Zstd}
+	compressTypeArr := []compressedio.CompressType{compressedio.Gzip, compressedio.Snappy, compressedio.Zstd}
 
 	tests := []testcase{
 		{
@@ -196,7 +201,7 @@ func TestNewCompressReader(t *testing.T) {
 
 	// default cfg(decode asynchronously)
 	prevRoutineCnt := runtime.NumGoroutine()
-	r, err := newCompressReader(Zstd, DecompressConfig{}, bytes.NewReader(compressedData))
+	r, err := compressedio.NewReader(compressedio.Zstd, compressedio.DecompressConfig{}, bytes.NewReader(compressedData))
 	currRoutineCnt := runtime.NumGoroutine()
 	require.NoError(t, err)
 	require.Greater(t, currRoutineCnt, prevRoutineCnt)
@@ -206,8 +211,8 @@ func TestNewCompressReader(t *testing.T) {
 
 	// sync decode
 	prevRoutineCnt = runtime.NumGoroutine()
-	config := DecompressConfig{ZStdDecodeConcurrency: 1}
-	r, err = newCompressReader(Zstd, config, bytes.NewReader(compressedData))
+	config := compressedio.DecompressConfig{ZStdDecodeConcurrency: 1}
+	r, err = compressedio.NewReader(compressedio.Zstd, config, bytes.NewReader(compressedData))
 	require.NoError(t, err)
 	currRoutineCnt = runtime.NumGoroutine()
 	require.Equal(t, prevRoutineCnt, currRoutineCnt)
EOF_114329324912

# Ensure failpoints are enabled (prerequisite for intest tag)
echo "=========================================="
echo "Enabling failpoints..."
echo "=========================================="
make failpoint-enable || echo "Failpoint enable attempted"

# Run the target tests with required build tags
# Testing entire package directories to catch all tests including relocated files
# Using -p 4 to ensure system stability in virtualized environment
# Timeout set to 20m as per Makefile requirements
echo "=========================================="
echo "Running target tests..."
echo "=========================================="

go test -v -p 4 -timeout 20m -tags 'deadlock,intest' \
    ./dumpling/export \
    ./pkg/lightning/backend/external \
    ./pkg/objstore \
    ./pkg/objstore/objectio

rc=$?

# Disable failpoints after tests
echo "=========================================="
echo "Disabling failpoints..."
echo "=========================================="
make failpoint-disable || echo "Failpoint disable attempted"

echo "=========================================="
echo "Test execution completed"
echo "=========================================="

# Capture and report exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to original state
git checkout 920ee6e01185ef79b9728cccc400ed86412e94ce \
    "dumpling/export/writer_serial_test.go" \
    "pkg/lightning/backend/external/bench_test.go" \
    "pkg/lightning/backend/external/byte_reader_test.go" \
    "pkg/lightning/backend/external/iter_test.go" \
    "pkg/lightning/backend/external/writer_test.go" \
    "pkg/objstore/azblob_test.go" \
    "pkg/objstore/compress_test.go" \
    "pkg/objstore/local_test.go" \
    "pkg/objstore/writer_test.go"