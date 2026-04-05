#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure we're on the correct commit
git checkout 8c244a984d063b5198946b68e79fbce22882a061

# Apply test patch if provided
git apply -v - <<'EOF_114329324912'
diff --git a/internal/stream/stream_test.go b/internal/stream/stream_test.go
new file mode 100644
--- /dev/null
+++ b/internal/stream/stream_test.go
@@ -0,0 +1,86 @@
+package stream
+
+import (
+	"bytes"
+	"errors"
+	"fmt"
+	"io"
+	"testing"
+
+	"github.com/OpenListTeam/OpenList/v4/internal/model"
+	"github.com/OpenListTeam/OpenList/v4/pkg/http_range"
+)
+
+func TestFileStream_RangeRead(t *testing.T) {
+	type args struct {
+		httpRange http_range.Range
+	}
+	buf := []byte("github.com/OpenListTeam/OpenList")
+	f := &FileStream{
+		Obj: &model.Object{
+			Size: int64(len(buf)),
+		},
+		Reader: io.NopCloser(bytes.NewReader(buf)),
+	}
+	tests := []struct {
+		name string
+		f    *FileStream
+		args args
+		want func(f *FileStream, got io.Reader, err error) error
+	}{
+		{
+			name: "range 11-12",
+			f:    f,
+			args: args{
+				httpRange: http_range.Range{Start: 11, Length: 12},
+			},
+			want: func(f *FileStream, got io.Reader, err error) error {
+				if f.GetFile() != nil {
+					return errors.New("cached")
+				}
+				b, _ := io.ReadAll(got)
+				if !bytes.Equal(buf[11:11+12], b) {
+					return fmt.Errorf("=%s ,want =%s", b, buf[11:11+12])
+				}
+				return nil
+			},
+		},
+		{
+			name: "range 11-21",
+			f:    f,
+			args: args{
+				httpRange: http_range.Range{Start: 11, Length: 21},
+			},
+			want: func(f *FileStream, got io.Reader, err error) error {
+				if f.GetFile() == nil {
+					return errors.New("not cached")
+				}
+				b, _ := io.ReadAll(got)
+				if !bytes.Equal(buf[11:11+21], b) {
+					return fmt.Errorf("=%s ,want =%s", b, buf[11:11+21])
+				}
+				return nil
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			got, err := tt.f.RangeRead(tt.args.httpRange)
+			if err := tt.want(tt.f, got, err); err != nil {
+				t.Errorf("FileStream.RangeRead() %v", err)
+			}
+		})
+	}
+	t.Run("after check", func(t *testing.T) {
+		if f.GetFile() == nil {
+			t.Error("not cached")
+		}
+		buf2 := make([]byte, len(buf))
+		if _, err := io.ReadFull(f, buf2); err != nil {
+			t.Errorf("FileStream.Read() error = %v", err)
+		}
+		if !bytes.Equal(buf, buf2) {
+			t.Errorf("FileStream.Read() = %s, want %s", buf2, buf)
+		}
+	})
+}
diff --git a/pkg/buffer/bytes_test.go b/pkg/buffer/bytes_test.go
new file mode 100644
--- /dev/null
+++ b/pkg/buffer/bytes_test.go
@@ -0,0 +1,95 @@
+package buffer
+
+import (
+	"errors"
+	"io"
+	"testing"
+)
+
+func TestReader_ReadAt(t *testing.T) {
+	type args struct {
+		p   []byte
+		off int64
+	}
+	bs := &Reader{}
+	bs.Append([]byte("github.com"))
+	bs.Append([]byte("/"))
+	bs.Append([]byte("OpenList"))
+	bs.Append([]byte("Team/"))
+	bs.Append([]byte("OpenList"))
+	tests := []struct {
+		name string
+		b    *Reader
+		args args
+		want func(a args, n int, err error) error
+	}{
+		{
+			name: "readAt len 10 offset 0",
+			b:    bs,
+			args: args{
+				p:   make([]byte, 10),
+				off: 0,
+			},
+			want: func(a args, n int, err error) error {
+				if n != len(a.p) {
+					return errors.New("read length not match")
+				}
+				if string(a.p) != "github.com" {
+					return errors.New("read content not match")
+				}
+				if err != nil {
+					return err
+				}
+				return nil
+			},
+		},
+		{
+			name: "readAt len 12 offset 11",
+			b:    bs,
+			args: args{
+				p:   make([]byte, 12),
+				off: 11,
+			},
+			want: func(a args, n int, err error) error {
+				if n != len(a.p) {
+					return errors.New("read length not match")
+				}
+				if string(a.p) != "OpenListTeam" {
+					return errors.New("read content not match")
+				}
+				if err != nil {
+					return err
+				}
+				return nil
+			},
+		},
+		{
+			name: "readAt len 50 offset 24",
+			b:    bs,
+			args: args{
+				p:   make([]byte, 50),
+				off: 24,
+			},
+			want: func(a args, n int, err error) error {
+				if n != bs.Len()-int(a.off) {
+					return errors.New("read length not match")
+				}
+				if string(a.p[:n]) != "OpenList" {
+					return errors.New("read content not match")
+				}
+				if err != io.EOF {
+					return errors.New("expect eof")
+				}
+				return nil
+			},
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			got, err := tt.b.ReadAt(tt.args.p, tt.args.off)
+			if err := tt.want(tt.args, got, err); err != nil {
+				t.Errorf("Bytes.ReadAt() error = %v", err)
+			}
+		})
+	}
+}
EOF_114329324912

# Verify Go environment is properly configured
export CGO_ENABLED=1
export GOPATH=/go
export PATH=$GOPATH/bin:$PATH

# Run only the specific target test files that were patched
# Excluding the problematic internal/fuse package
# Running tests in the packages that were modified by the patch
go test -v -count=1 github.com/OpenListTeam/OpenList/v4/internal/stream github.com/OpenListTeam/OpenList/v4/pkg/buffer

# Capture exit code
rc=$?

# Required: Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Reset to original commit state
git checkout 8c244a984d063b5198946b68e79fbce22882a061