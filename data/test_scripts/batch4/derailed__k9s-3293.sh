#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout c2694ee3e59876a584a9c0ad0a7d7cc7a3793f44 \
    "internal/client/config_test.go" \
    "internal/config/config_test.go" \
    "internal/config/testdata/configs/default.yaml" \
    "internal/config/testdata/configs/expected.yaml" \
    "internal/config/testdata/configs/k9s.yaml" \
    "internal/model/stack_test.go" \
    "internal/ui/crumbs_test.go" \
    "internal/ui/table_helper_test.go" \
    "internal/ui/table_test.go" \
    "internal/view/alias_test.go" \
    "internal/view/table_int_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/client/config_test.go b/internal/client/config_test.go
--- a/internal/client/config_test.go
+++ b/internal/client/config_test.go
@@ -32,7 +32,7 @@ func TestCallTimeout(t *testing.T) {
 			e: 1 * time.Minute,
 		},
 		"default": {
-			e: 10 * time.Second,
+			e: 15 * time.Second,
 		},
 	}
 
diff --git a/internal/config/config_test.go b/internal/config/config_test.go
--- a/internal/config/config_test.go
+++ b/internal/config/config_test.go
@@ -49,9 +49,8 @@ func TestConfigSave(t *testing.T) {
 		},
 	}
 
-	for k := range uu {
+	for k, u := range uu {
 		xdg.Reload()
-		u := uu[k]
 		t.Run(k, func(t *testing.T) {
 			c := mock.NewMockConfig(t)
 			_, err := c.K9s.ActivateContext(u.ct)
@@ -562,6 +561,7 @@ func TestConfigSaveFile(t *testing.T) {
 	require.NoError(t, cfg.Load("testdata/configs/k9s.yaml", true))
 
 	cfg.K9s.RefreshRate = 100
+	cfg.K9s.APIServerTimeout = "30s"
 	cfg.K9s.ReadOnly = true
 	cfg.K9s.Logger.TailCount = 500
 	cfg.K9s.Logger.BufferSize = 800
diff --git a/internal/config/testdata/configs/default.yaml b/internal/config/testdata/configs/default.yaml
--- a/internal/config/testdata/configs/default.yaml
+++ b/internal/config/testdata/configs/default.yaml
@@ -2,6 +2,7 @@ k9s:
   liveViewAutoRefresh: false
   screenDumpDir: /tmp/k9s-test/screen-dumps
   refreshRate: 2
+  apiServerTimeout: 15s
   maxConnRetry: 5
   readOnly: false
   noExitOnCtrlC: false
diff --git a/internal/config/testdata/configs/expected.yaml b/internal/config/testdata/configs/expected.yaml
--- a/internal/config/testdata/configs/expected.yaml
+++ b/internal/config/testdata/configs/expected.yaml
@@ -2,6 +2,7 @@ k9s:
   liveViewAutoRefresh: true
   screenDumpDir: /tmp/k9s-test/screen-dumps
   refreshRate: 100
+  apiServerTimeout: 30s
   maxConnRetry: 5
   readOnly: true
   noExitOnCtrlC: false
diff --git a/internal/config/testdata/configs/k9s.yaml b/internal/config/testdata/configs/k9s.yaml
--- a/internal/config/testdata/configs/k9s.yaml
+++ b/internal/config/testdata/configs/k9s.yaml
@@ -2,6 +2,7 @@ k9s:
   liveViewAutoRefresh: true
   screenDumpDir: /tmp/k9s-test/screen-dumps
   refreshRate: 2
+  apiServerTimeout: 10s
   maxConnRetry: 5
   readOnly: false
   noExitOnCtrlC: false
diff --git a/internal/model/stack_test.go b/internal/model/stack_test.go
--- a/internal/model/stack_test.go
+++ b/internal/model/stack_test.go
@@ -13,6 +13,7 @@ import (
 	"github.com/derailed/tcell/v2"
 	"github.com/derailed/tview"
 	"github.com/stretchr/testify/assert"
+	"k8s.io/apimachinery/pkg/labels"
 )
 
 func init() {
@@ -313,4 +314,4 @@ func (c) Start()                           {}
 func (c) Stop()                            {}
 func (c) Init(context.Context) error       { return nil }
 func (c) SetFilter(string)                 {}
-func (c) SetLabelFilter(map[string]string) {}
+func (c) SetLabelSelector(labels.Selector) {}
diff --git a/internal/ui/crumbs_test.go b/internal/ui/crumbs_test.go
--- a/internal/ui/crumbs_test.go
+++ b/internal/ui/crumbs_test.go
@@ -15,6 +15,7 @@ import (
 	"github.com/derailed/tcell/v2"
 	"github.com/derailed/tview"
 	"github.com/stretchr/testify/assert"
+	"k8s.io/apimachinery/pkg/labels"
 )
 
 func init() {
@@ -60,4 +61,4 @@ func (c) Start()                           {}
 func (c) Stop()                            {}
 func (c) Init(context.Context) error       { return nil }
 func (c) SetFilter(string)                 {}
-func (c) SetLabelFilter(map[string]string) {}
+func (c) SetLabelSelector(labels.Selector) {}
diff --git a/internal/ui/table_helper_test.go b/internal/ui/table_helper_test.go
--- a/internal/ui/table_helper_test.go
+++ b/internal/ui/table_helper_test.go
@@ -8,6 +8,7 @@ import (
 
 	"github.com/derailed/k9s/internal/render"
 	"github.com/stretchr/testify/assert"
+	"k8s.io/apimachinery/pkg/labels"
 )
 
 func TestTruncate(t *testing.T) {
@@ -34,17 +35,29 @@ func TestTruncate(t *testing.T) {
 }
 
 func TestTrimLabelSelector(t *testing.T) {
+	sel, _ := labels.Parse("app=fred,env=blee")
 	uu := map[string]struct {
-		sel, e string
+		sel string
+		err error
+		e   labels.Selector
 	}{
-		"cool":    {"-l app=fred,env=blee", "app=fred,env=blee"},
-		"noSpace": {"-lapp=fred,env=blee", "app=fred,env=blee"},
+		"cool": {
+			sel: "-l app=fred,env=blee",
+			e:   sel,
+		},
+
+		"no-space": {
+			sel: "-lapp=fred,env=blee",
+			e:   sel,
+		},
 	}
 
 	for k := range uu {
 		u := uu[k]
 		t.Run(k, func(t *testing.T) {
-			assert.Equal(t, u.e, TrimLabelSelector(u.sel))
+			sel, err := TrimLabelSelector(u.sel)
+			assert.Equal(t, u.err, err)
+			assert.Equal(t, u.e, sel)
 		})
 	}
 }
diff --git a/internal/ui/table_test.go b/internal/ui/table_test.go
--- a/internal/ui/table_test.go
+++ b/internal/ui/table_test.go
@@ -17,6 +17,7 @@ import (
 	"github.com/derailed/k9s/internal/ui"
 	"github.com/stretchr/testify/assert"
 	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
+	"k8s.io/apimachinery/pkg/labels"
 	"k8s.io/apimachinery/pkg/runtime"
 )
 
@@ -42,7 +43,7 @@ func TestTableUpdate(t *testing.T) {
 func TestTableSelection(t *testing.T) {
 	v := ui.NewTable(client.NewGVR("fred"))
 	v.Init(makeContext())
-	m := &mockModel{}
+	m := new(mockModel)
 	v.SetModel(m)
 	data := m.Peek()
 	cdata := v.Update(data, false)
@@ -72,8 +73,8 @@ var _ ui.Tabular = &mockModel{}
 
 func (*mockModel) SetViewSetting(context.Context, *config.ViewSetting) {}
 func (*mockModel) SetInstance(string)                                  {}
-func (*mockModel) SetLabelFilter(string)                               {}
-func (*mockModel) GetLabelFilter() string                              { return "" }
+func (*mockModel) SetLabelSelector(labels.Selector)                    {}
+func (*mockModel) GetLabelSelector() labels.Selector                   { return nil }
 func (*mockModel) Empty() bool                                         { return false }
 func (*mockModel) RowCount() int                                       { return 1 }
 func (*mockModel) HasMetrics() bool                                    { return true }
diff --git a/internal/view/alias_test.go b/internal/view/alias_test.go
--- a/internal/view/alias_test.go
+++ b/internal/view/alias_test.go
@@ -21,6 +21,7 @@ import (
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
+	"k8s.io/apimachinery/pkg/labels"
 	"k8s.io/apimachinery/pkg/runtime"
 )
 
@@ -35,7 +36,7 @@ func TestAliasNew(t *testing.T) {
 func TestAliasSearch(t *testing.T) {
 	v := view.NewAlias(client.AliGVR)
 	require.NoError(t, v.Init(makeContext(t)))
-	v.GetTable().SetModel(&mockModel{})
+	v.GetTable().SetModel(new(mockModel))
 	v.GetTable().Refresh()
 	v.App().Prompt().SetModel(v.GetTable().CmdBuff())
 	v.App().Prompt().SendStrokes("blee")
@@ -93,8 +94,8 @@ func (*mockModel) NextSuggestion() (string, bool)                      { return
 func (*mockModel) PrevSuggestion() (string, bool)                      { return "", false }
 func (*mockModel) ClearSuggestions()                                   {}
 func (*mockModel) SetInstance(string)                                  {}
-func (*mockModel) SetLabelFilter(string)                               {}
-func (*mockModel) GetLabelFilter() string                              { return "" }
+func (*mockModel) SetLabelSelector(labels.Selector)                    {}
+func (*mockModel) GetLabelSelector() labels.Selector                   { return nil }
 func (*mockModel) Empty() bool                                         { return false }
 func (*mockModel) RowCount() int                                       { return 1 }
 func (*mockModel) HasMetrics() bool                                    { return true }
diff --git a/internal/view/table_int_test.go b/internal/view/table_int_test.go
--- a/internal/view/table_int_test.go
+++ b/internal/view/table_int_test.go
@@ -24,6 +24,7 @@ import (
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
+	"k8s.io/apimachinery/pkg/labels"
 	"k8s.io/apimachinery/pkg/runtime"
 )
 
@@ -135,8 +136,8 @@ var _ ui.Tabular = (*mockTableModel)(nil)
 
 func (*mockTableModel) SetViewSetting(context.Context, *config.ViewSetting) {}
 func (*mockTableModel) SetInstance(string)                                  {}
-func (*mockTableModel) SetLabelFilter(string)                               {}
-func (*mockTableModel) GetLabelFilter() string                              { return "" }
+func (*mockTableModel) SetLabelSelector(labels.Selector)                    {}
+func (*mockTableModel) GetLabelSelector() labels.Selector                   { return nil }
 func (*mockTableModel) Empty() bool                                         { return false }
 func (*mockTableModel) RowCount() int                                       { return 1 }
 func (*mockTableModel) HasMetrics() bool                                    { return true }
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests
# Running tests for all specified packages in a single command for efficiency
# Using -v for verbose output to help with debugging
go test -v \
    ./internal/client \
    ./internal/config \
    ./internal/model \
    ./internal/ui \
    ./internal/view

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout c2694ee3e59876a584a9c0ad0a7d7cc7a3793f44 \
    "internal/client/config_test.go" \
    "internal/config/config_test.go" \
    "internal/config/testdata/configs/default.yaml" \
    "internal/config/testdata/configs/expected.yaml" \
    "internal/config/testdata/configs/k9s.yaml" \
    "internal/model/stack_test.go" \
    "internal/ui/crumbs_test.go" \
    "internal/ui/table_helper_test.go" \
    "internal/ui/table_test.go" \
    "internal/view/alias_test.go" \
    "internal/view/table_int_test.go"