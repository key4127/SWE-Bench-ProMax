#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout e5212875a423f3fab783e69794ee1a36f9ffce29 \
    "internal/config/config_test.go" \
    "internal/config/flags_test.go" \
    "internal/config/k9s_int_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/config/config_test.go b/internal/config/config_test.go
--- a/internal/config/config_test.go
+++ b/internal/config/config_test.go
@@ -544,7 +544,7 @@ func TestConfigLoad(t *testing.T) {
 	cfg := mock.NewMockConfig(t)
 
 	require.NoError(t, cfg.Load("testdata/configs/k9s.yaml", true))
-	assert.Equal(t, 2, cfg.K9s.RefreshRate)
+	assert.InDelta(t, 2.0, cfg.K9s.RefreshRate, 0.001)
 	assert.Equal(t, int64(200), cfg.K9s.Logger.TailCount)
 	assert.Equal(t, 2000, cfg.K9s.Logger.BufferSize)
 }
diff --git a/internal/config/flags_test.go b/internal/config/flags_test.go
--- a/internal/config/flags_test.go
+++ b/internal/config/flags_test.go
@@ -15,7 +15,7 @@ func TestNewFlags(t *testing.T) {
 	config.AppLogFile = "/tmp/k9s-test/k9s.log"
 
 	f := config.NewFlags()
-	assert.Equal(t, 2, *f.RefreshRate)
+	assert.InDelta(t, 2.0, *f.RefreshRate, 0.001)
 	assert.Equal(t, "info", *f.LogLevel)
 	assert.Equal(t, "/tmp/k9s-test/k9s.log", *f.LogFile)
 	assert.Equal(t, config.AppDumpsDir, *f.ScreenDumpDir)
diff --git a/internal/config/k9s_int_test.go b/internal/config/k9s_int_test.go
--- a/internal/config/k9s_int_test.go
+++ b/internal/config/k9s_int_test.go
@@ -19,28 +19,42 @@ func Test_k9sOverrides(t *testing.T) {
 
 	uu := map[string]struct {
 		k                  *K9s
-		rate               int
+		rate               float32
 		ro, hl, cl, sl, ll bool
 	}{
 		"plain": {
 			k: &K9s{
 				LiveViewAutoRefresh: false,
 				ScreenDumpDir:       "",
-				RefreshRate:         10,
+				RefreshRate:         10.0,
 				MaxConnRetry:        0,
 				ReadOnly:            false,
 				NoExitOnCtrlC:       false,
 				UI:                  UI{},
 				SkipLatestRevCheck:  false,
 				DisablePodCounting:  false,
 			},
-			rate: 10,
+			rate: 10.0,
+		},
+		"sub-second": {
+			k: &K9s{
+				LiveViewAutoRefresh: false,
+				ScreenDumpDir:       "",
+				RefreshRate:         0.5,
+				MaxConnRetry:        0,
+				ReadOnly:            false,
+				NoExitOnCtrlC:       false,
+				UI:                  UI{},
+				SkipLatestRevCheck:  false,
+				DisablePodCounting:  false,
+			},
+			rate: 2.0, // minimum enforced
 		},
 		"set": {
 			k: &K9s{
 				LiveViewAutoRefresh: false,
 				ScreenDumpDir:       "",
-				RefreshRate:         10,
+				RefreshRate:         10.0,
 				MaxConnRetry:        0,
 				ReadOnly:            true,
 				NoExitOnCtrlC:       false,
@@ -53,7 +67,7 @@ func Test_k9sOverrides(t *testing.T) {
 				SkipLatestRevCheck: false,
 				DisablePodCounting: false,
 			},
-			rate: 10,
+			rate: 10.0,
 			ro:   true,
 			hl:   true,
 			ll:   true,
@@ -64,7 +78,7 @@ func Test_k9sOverrides(t *testing.T) {
 			k: &K9s{
 				LiveViewAutoRefresh: false,
 				ScreenDumpDir:       "",
-				RefreshRate:         10,
+				RefreshRate:         10.0,
 				MaxConnRetry:        0,
 				ReadOnly:            false,
 				NoExitOnCtrlC:       false,
@@ -79,12 +93,12 @@ func Test_k9sOverrides(t *testing.T) {
 				},
 				SkipLatestRevCheck:  false,
 				DisablePodCounting:  false,
-				manualRefreshRate:   100,
+				manualRefreshRate:   100.0,
 				manualReadOnly:      &trueVal,
 				manualCommand:       &cmd,
 				manualScreenDumpDir: &dir,
 			},
-			rate: 100,
+			rate: 100.0,
 			ro:   true,
 			hl:   true,
 			ll:   true,
@@ -96,7 +110,7 @@ func Test_k9sOverrides(t *testing.T) {
 	for k := range uu {
 		u := uu[k]
 		t.Run(k, func(t *testing.T) {
-			assert.Equal(t, u.rate, u.k.GetRefreshRate())
+			assert.InDelta(t, u.rate, u.k.GetRefreshRate(), 0.001)
 			assert.Equal(t, u.ro, u.k.IsReadOnly())
 			assert.Equal(t, u.cl, u.k.IsCrumbsless())
 			assert.Equal(t, u.sl, u.k.IsSplashless())
diff --git a/internal/config/refresh_rate_test.go b/internal/config/refresh_rate_test.go
new file mode 100644
--- /dev/null
+++ b/internal/config/refresh_rate_test.go
@@ -0,0 +1,75 @@
+package config
+
+import (
+	"testing"
+
+	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
+	"gopkg.in/yaml.v3"
+)
+
+func TestRefreshRateBackwardCompatibility(t *testing.T) {
+	tests := map[string]struct {
+		yamlContent string
+		expected    float32
+	}{
+		"integer_value": {
+			yamlContent: `refreshRate: 2`,
+			expected:    2.0,
+		},
+		"float_value": {
+			yamlContent: `refreshRate: 2.5`,
+			expected:    2.5,
+		},
+	}
+
+	for name, test := range tests {
+		t.Run(name, func(t *testing.T) {
+			var k K9s
+			err := yaml.Unmarshal([]byte(test.yamlContent), &k)
+			require.NoError(t, err)
+			assert.InDelta(t, test.expected, k.RefreshRate, 0.001)
+		})
+	}
+}
+
+func TestGetRefreshRateMinimum(t *testing.T) {
+	tests := map[string]struct {
+		refreshRate       float32
+		manualRefreshRate float32
+		expected          float32
+	}{
+		"below_minimum": {
+			refreshRate: 0.5,
+			expected:    2.0,
+		},
+		"at_minimum": {
+			refreshRate: 2.0,
+			expected:    2.0,
+		},
+		"above_minimum": {
+			refreshRate: 3.5,
+			expected:    3.5,
+		},
+		"manual_below_minimum": {
+			refreshRate:       3.0,
+			manualRefreshRate: 0.5,
+			expected:          2.0,
+		},
+		"manual_above_minimum": {
+			refreshRate:       2.0,
+			manualRefreshRate: 4.0,
+			expected:          4.0,
+		},
+	}
+
+	for name, test := range tests {
+		t.Run(name, func(t *testing.T) {
+			k := K9s{
+				RefreshRate:       test.refreshRate,
+				manualRefreshRate: test.manualRefreshRate,
+			}
+			assert.InDelta(t, test.expected, k.GetRefreshRate(), 0.001)
+		})
+	}
+}
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests
# Running tests for the specific package with verbose output
go test -v ./internal/config/

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e5212875a423f3fab783e69794ee1a36f9ffce29 \
    "internal/config/config_test.go" \
    "internal/config/flags_test.go" \
    "internal/config/k9s_int_test.go"