#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 848e1cdd0d1525ce0a99b7e6a2a1cf0d84d76156 "context_test.go" "logger_test.go"

# Apply the test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/context_test.go b/context_test.go
--- a/context_test.go
+++ b/context_test.go
@@ -257,7 +257,46 @@ func TestContextSetGet(t *testing.T) {
 	assert.False(t, err)
 
 	assert.Equal(t, "bar", c.MustGet("foo"))
-	assert.Panics(t, func() { c.MustGet("no_exist") })
+	assert.Panicsf(t, func() {
+		c.MustGet("no_exist")
+	}, "key no_exist does not exist")
+}
+
+func TestContextSetGetAnyKey(t *testing.T) {
+	c, _ := CreateTestContext(httptest.NewRecorder())
+
+	type key struct{}
+
+	tests := []struct {
+		key any
+	}{
+		{1},
+		{int32(1)},
+		{int64(1)},
+		{uint(1)},
+		{float32(1)},
+		{key{}},
+		{&key{}},
+	}
+
+	for _, tt := range tests {
+		t.Run(reflect.TypeOf(tt.key).String(), func(t *testing.T) {
+			c.Set(tt.key, 1)
+			value, ok := c.Get(tt.key)
+			assert.True(t, ok)
+			assert.Equal(t, 1, value)
+		})
+	}
+}
+
+func TestContextSetGetPanicsWhenKeyNotComparable(t *testing.T) {
+	c, _ := CreateTestContext(httptest.NewRecorder())
+
+	assert.Panics(t, func() {
+		c.Set([]int{1}, 1)
+		c.Set(func() {}, 1)
+		c.Set(make(chan int), 1)
+	})
 }
 
 func TestContextSetGetValues(t *testing.T) {
diff --git a/logger_test.go b/logger_test.go
--- a/logger_test.go
+++ b/logger_test.go
@@ -181,7 +181,7 @@ func TestLoggerWithFormatter(t *testing.T) {
 
 func TestLoggerWithConfigFormatting(t *testing.T) {
 	var gotParam LogFormatterParams
-	var gotKeys map[string]any
+	var gotKeys map[any]any
 	buffer := new(strings.Builder)
 
 	router := New()
EOF_114329324912

# Ensure Go modules are properly initialized
go mod download
go mod verify

# Execute the tests in the package context
# Using -v for verbose output and running tests from context_test.go and logger_test.go
# by running the entire package (.) which includes all necessary dependencies
go test -v -run 'TestContext|TestLogger' .
rc=$?

# Required: echo test status for the judge to determine pass/fail
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test files
git checkout 848e1cdd0d1525ce0a99b7e6a2a1cf0d84d76156 "context_test.go" "logger_test.go"