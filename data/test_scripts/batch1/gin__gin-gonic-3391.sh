#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset test files to original state before applying patch
git checkout 0a864884de806386e275ee096f681520799911fb "binding/json_test.go" "context_test.go" "errors_test.go" "render/render_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/binding/json_test.go b/binding/json_test.go
--- a/binding/json_test.go
+++ b/binding/json_test.go
@@ -5,8 +5,16 @@
 package binding
 
 import (
+	"io"
+	"net/http/httptest"
 	"testing"
+	"time"
+	"unsafe"
 
+	"github.com/gin-gonic/gin/codec/json"
+	"github.com/gin-gonic/gin/render"
+	jsoniter "github.com/json-iterator/go"
+	"github.com/modern-go/reflect2"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 )
@@ -28,3 +36,181 @@ func TestJSONBindingBindBodyMap(t *testing.T) {
 	assert.Equal(t, "FOO", s["foo"])
 	assert.Equal(t, "world", s["hello"])
 }
+
+func TestCustomJsonCodec(t *testing.T) {
+	// Restore json encoding configuration after testing
+	oldMarshal := json.API
+	defer func() {
+		json.API = oldMarshal
+	}()
+	// Custom json api
+	json.API = customJsonApi{}
+
+	// test decode json
+	obj := customReq{}
+	err := jsonBinding{}.BindBody([]byte(`{"time_empty":null,"time_struct": "2001-12-05 10:01:02.345","time_nil":null,"time_pointer":"2002-12-05 10:01:02.345"}`), &obj)
+	require.NoError(t, err)
+	assert.Equal(t, zeroTime, obj.TimeEmpty)
+	assert.Equal(t, time.Date(2001, 12, 5, 10, 1, 2, 345000000, time.Local), obj.TimeStruct)
+	assert.Nil(t, obj.TimeNil)
+	assert.Equal(t, time.Date(2002, 12, 5, 10, 1, 2, 345000000, time.Local), *obj.TimePointer)
+	// test encode json
+	w := httptest.NewRecorder()
+	err2 := (render.PureJSON{Data: obj}).Render(w)
+	require.NoError(t, err2)
+	assert.JSONEq(t, "{\"time_empty\":null,\"time_struct\":\"2001-12-05 10:01:02.345\",\"time_nil\":null,\"time_pointer\":\"2002-12-05 10:01:02.345\"}\n", w.Body.String())
+	assert.Equal(t, "application/json; charset=utf-8", w.Header().Get("Content-Type"))
+}
+
+type customReq struct {
+	TimeEmpty   time.Time  `json:"time_empty"`
+	TimeStruct  time.Time  `json:"time_struct"`
+	TimeNil     *time.Time `json:"time_nil"`
+	TimePointer *time.Time `json:"time_pointer"`
+}
+
+var customConfig = jsoniter.Config{
+	EscapeHTML:             true,
+	SortMapKeys:            true,
+	ValidateJsonRawMessage: true,
+}.Froze()
+
+func init() {
+	customConfig.RegisterExtension(&TimeEx{})
+	customConfig.RegisterExtension(&TimePointerEx{})
+}
+
+type customJsonApi struct{}
+
+func (j customJsonApi) Marshal(v any) ([]byte, error) {
+	return customConfig.Marshal(v)
+}
+
+func (j customJsonApi) Unmarshal(data []byte, v any) error {
+	return customConfig.Unmarshal(data, v)
+}
+
+func (j customJsonApi) MarshalIndent(v any, prefix, indent string) ([]byte, error) {
+	return customConfig.MarshalIndent(v, prefix, indent)
+}
+
+func (j customJsonApi) NewEncoder(writer io.Writer) json.Encoder {
+	return customConfig.NewEncoder(writer)
+}
+
+func (j customJsonApi) NewDecoder(reader io.Reader) json.Decoder {
+	return customConfig.NewDecoder(reader)
+}
+
+// region Time Extension
+
+var (
+	zeroTime         = time.Time{}
+	timeType         = reflect2.TypeOfPtr((*time.Time)(nil)).Elem()
+	defaultTimeCodec = &timeCodec{}
+)
+
+type TimeEx struct {
+	jsoniter.DummyExtension
+}
+
+func (te *TimeEx) CreateDecoder(typ reflect2.Type) jsoniter.ValDecoder {
+	if typ == timeType {
+		return defaultTimeCodec
+	}
+	return nil
+}
+
+func (te *TimeEx) CreateEncoder(typ reflect2.Type) jsoniter.ValEncoder {
+	if typ == timeType {
+		return defaultTimeCodec
+	}
+	return nil
+}
+
+type timeCodec struct{}
+
+func (tc timeCodec) IsEmpty(ptr unsafe.Pointer) bool {
+	t := *((*time.Time)(ptr))
+	return t.Equal(zeroTime)
+}
+
+func (tc timeCodec) Encode(ptr unsafe.Pointer, stream *jsoniter.Stream) {
+	t := *((*time.Time)(ptr))
+	if t.Equal(zeroTime) {
+		stream.WriteNil()
+		return
+	}
+	stream.WriteString(t.In(time.Local).Format("2006-01-02 15:04:05.000"))
+}
+
+func (tc timeCodec) Decode(ptr unsafe.Pointer, iter *jsoniter.Iterator) {
+	ts := iter.ReadString()
+	if len(ts) == 0 {
+		*((*time.Time)(ptr)) = zeroTime
+		return
+	}
+	t, err := time.ParseInLocation("2006-01-02 15:04:05.000", ts, time.Local)
+	if err != nil {
+		panic(err)
+	}
+	*((*time.Time)(ptr)) = t
+}
+
+// endregion
+
+// region *Time Extension
+
+var (
+	timePointerType         = reflect2.TypeOfPtr((**time.Time)(nil)).Elem()
+	defaultTimePointerCodec = &timePointerCodec{}
+)
+
+type TimePointerEx struct {
+	jsoniter.DummyExtension
+}
+
+func (tpe *TimePointerEx) CreateDecoder(typ reflect2.Type) jsoniter.ValDecoder {
+	if typ == timePointerType {
+		return defaultTimePointerCodec
+	}
+	return nil
+}
+
+func (tpe *TimePointerEx) CreateEncoder(typ reflect2.Type) jsoniter.ValEncoder {
+	if typ == timePointerType {
+		return defaultTimePointerCodec
+	}
+	return nil
+}
+
+type timePointerCodec struct{}
+
+func (tpc timePointerCodec) IsEmpty(ptr unsafe.Pointer) bool {
+	t := *((**time.Time)(ptr))
+	return t == nil || (*t).Equal(zeroTime)
+}
+
+func (tpc timePointerCodec) Encode(ptr unsafe.Pointer, stream *jsoniter.Stream) {
+	t := *((**time.Time)(ptr))
+	if t == nil || (*t).Equal(zeroTime) {
+		stream.WriteNil()
+		return
+	}
+	stream.WriteString(t.In(time.Local).Format("2006-01-02 15:04:05.000"))
+}
+
+func (tpc timePointerCodec) Decode(ptr unsafe.Pointer, iter *jsoniter.Iterator) {
+	ts := iter.ReadString()
+	if len(ts) == 0 {
+		*((**time.Time)(ptr)) = nil
+		return
+	}
+	t, err := time.ParseInLocation("2006-01-02 15:04:05.000", ts, time.Local)
+	if err != nil {
+		panic(err)
+	}
+	*((**time.Time)(ptr)) = &t
+}
+
+// endregion
diff --git a/context_test.go b/context_test.go
--- a/context_test.go
+++ b/context_test.go
@@ -28,7 +28,7 @@ import (
 
 	"github.com/gin-contrib/sse"
 	"github.com/gin-gonic/gin/binding"
-	"github.com/gin-gonic/gin/internal/json"
+	"github.com/gin-gonic/gin/codec/json"
 	testdata "github.com/gin-gonic/gin/testdata/protoexample"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
diff --git a/errors_test.go b/errors_test.go
--- a/errors_test.go
+++ b/errors_test.go
@@ -9,7 +9,7 @@ import (
 	"fmt"
 	"testing"
 
-	"github.com/gin-gonic/gin/internal/json"
+	"github.com/gin-gonic/gin/codec/json"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 )
@@ -33,7 +33,7 @@ func TestError(t *testing.T) {
 		"meta":  "some data",
 	}, err.JSON())
 
-	jsonBytes, _ := json.Marshal(err)
+	jsonBytes, _ := json.API.Marshal(err)
 	assert.JSONEq(t, "{\"error\":\"test error\",\"meta\":\"some data\"}", string(jsonBytes))
 
 	err.SetMeta(H{ //nolint: errcheck
@@ -92,13 +92,13 @@ Error #03: third
 		H{"error": "second", "meta": "some data"},
 		H{"error": "third", "status": "400"},
 	}, errs.JSON())
-	jsonBytes, _ := json.Marshal(errs)
+	jsonBytes, _ := json.API.Marshal(errs)
 	assert.JSONEq(t, "[{\"error\":\"first\"},{\"error\":\"second\",\"meta\":\"some data\"},{\"error\":\"third\",\"status\":\"400\"}]", string(jsonBytes))
 	errs = errorMsgs{
 		{Err: errors.New("first"), Type: ErrorTypePrivate},
 	}
 	assert.Equal(t, H{"error": "first"}, errs.JSON())
-	jsonBytes, _ = json.Marshal(errs)
+	jsonBytes, _ = json.API.Marshal(errs)
 	assert.JSONEq(t, "{\"error\":\"first\"}", string(jsonBytes))
 
 	errs = errorMsgs{}
diff --git a/render/render_test.go b/render/render_test.go
--- a/render/render_test.go
+++ b/render/render_test.go
@@ -15,7 +15,7 @@ import (
 	"strings"
 	"testing"
 
-	"github.com/gin-gonic/gin/internal/json"
+	"github.com/gin-gonic/gin/codec/json"
 	testdata "github.com/gin-gonic/gin/testdata/protoexample"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
@@ -173,7 +173,7 @@ func TestRenderJsonpJSONError(t *testing.T) {
 	err = jsonpJSON.Render(ew)
 	assert.Equal(t, `write "`+`(`+`" error`, err.Error())
 
-	data, _ := json.Marshal(jsonpJSON.Data) // error was returned while writing data
+	data, _ := json.API.Marshal(jsonpJSON.Data) // error was returned while writing data
 	ew.bufString = string(data)
 	err = jsonpJSON.Render(ew)
 	assert.Equal(t, `write "`+string(data)+`" error`, err.Error())
EOF_114329324912

# Execute tests using package patterns instead of individual file paths
# The root package contains context_test.go and errors_test.go
# The binding and render packages are in subdirectories
go test -v -covermode=count -coverprofile=profile.out ./ ./binding/ ./render/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore test files to original state after test execution
git checkout 0a864884de806386e275ee096f681520799911fb "binding/json_test.go" "context_test.go" "errors_test.go" "render/render_test.go"