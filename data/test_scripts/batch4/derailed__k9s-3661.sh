#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 68627675207c1b64b593c44829a7f534ba7eacf4 \
    "internal/view/cm_test.go" \
    "internal/view/container_test.go" \
    "internal/view/context_test.go" \
    "internal/view/dir_test.go" \
    "internal/view/dp_test.go" \
    "internal/view/ds_test.go" \
    "internal/view/help_test.go" \
    "internal/view/ns_test.go" \
    "internal/view/pod_test.go" \
    "internal/view/priorityclass_test.go" \
    "internal/view/pvc_test.go" \
    "internal/view/reference_test.go" \
    "internal/view/screen_dump_test.go" \
    "internal/view/secret_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/view/cm_test.go b/internal/view/cm_test.go
--- a/internal/view/cm_test.go
+++ b/internal/view/cm_test.go
@@ -17,5 +17,5 @@ func TestConfigMapNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "ConfigMaps", s.Name())
-	assert.Len(t, s.Hints(), 8)
+	assert.Len(t, s.Hints(), 9)
 }
diff --git a/internal/view/container_test.go b/internal/view/container_test.go
--- a/internal/view/container_test.go
+++ b/internal/view/container_test.go
@@ -17,5 +17,5 @@ func TestContainerNew(t *testing.T) {
 
 	require.NoError(t, c.Init(makeCtx(t)))
 	assert.Equal(t, "Containers", c.Name())
-	assert.Len(t, c.Hints(), 20)
+	assert.Len(t, c.Hints(), 13)
 }
diff --git a/internal/view/context_test.go b/internal/view/context_test.go
--- a/internal/view/context_test.go
+++ b/internal/view/context_test.go
@@ -17,5 +17,5 @@ func TestContext(t *testing.T) {
 
 	require.NoError(t, ctx.Init(makeCtx(t)))
 	assert.Equal(t, "Contexts", ctx.Name())
-	assert.Len(t, ctx.Hints(), 7)
+	assert.Len(t, ctx.Hints(), 8)
 }
diff --git a/internal/view/dir_test.go b/internal/view/dir_test.go
--- a/internal/view/dir_test.go
+++ b/internal/view/dir_test.go
@@ -16,5 +16,5 @@ func TestDir(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "Directory", v.Name())
-	assert.Len(t, v.Hints(), 8)
+	assert.Len(t, v.Hints(), 9)
 }
diff --git a/internal/view/dp_test.go b/internal/view/dp_test.go
--- a/internal/view/dp_test.go
+++ b/internal/view/dp_test.go
@@ -17,5 +17,5 @@ func TestDeploy(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "Deployments", v.Name())
-	assert.Len(t, v.Hints(), 17)
+	assert.Len(t, v.Hints(), 15)
 }
diff --git a/internal/view/ds_test.go b/internal/view/ds_test.go
--- a/internal/view/ds_test.go
+++ b/internal/view/ds_test.go
@@ -17,5 +17,5 @@ func TestDaemonSet(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "DaemonSets", v.Name())
-	assert.Len(t, v.Hints(), 18)
+	assert.Len(t, v.Hints(), 14)
 }
diff --git a/internal/view/help_test.go b/internal/view/help_test.go
--- a/internal/view/help_test.go
+++ b/internal/view/help_test.go
@@ -25,7 +25,7 @@ func TestHelp(t *testing.T) {
 	v := view.NewHelp(app)
 
 	require.NoError(t, v.Init(ctx))
-	assert.Equal(t, 29, v.GetRowCount())
+	assert.Equal(t, 20, v.GetRowCount())
 	assert.Equal(t, 8, v.GetColumnCount())
 	assert.Equal(t, "<a>", strings.TrimSpace(v.GetCell(1, 0).Text))
 	assert.Equal(t, "Attach", strings.TrimSpace(v.GetCell(1, 1).Text))
diff --git a/internal/view/ns_test.go b/internal/view/ns_test.go
--- a/internal/view/ns_test.go
+++ b/internal/view/ns_test.go
@@ -17,5 +17,5 @@ func TestNSCleanser(t *testing.T) {
 
 	require.NoError(t, ns.Init(makeCtx(t)))
 	assert.Equal(t, "Namespaces", ns.Name())
-	assert.Len(t, ns.Hints(), 7)
+	assert.Len(t, ns.Hints(), 8)
 }
diff --git a/internal/view/pod_test.go b/internal/view/pod_test.go
--- a/internal/view/pod_test.go
+++ b/internal/view/pod_test.go
@@ -20,7 +20,7 @@ func TestPodNew(t *testing.T) {
 
 	require.NoError(t, po.Init(makeCtx(t)))
 	assert.Equal(t, "Pods", po.Name())
-	assert.Len(t, po.Hints(), 28)
+	assert.Len(t, po.Hints(), 19)
 }
 
 // Helpers...
diff --git a/internal/view/priorityclass_test.go b/internal/view/priorityclass_test.go
--- a/internal/view/priorityclass_test.go
+++ b/internal/view/priorityclass_test.go
@@ -17,5 +17,5 @@ func TestPriorityClassNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "PriorityClass", s.Name())
-	assert.Len(t, s.Hints(), 7)
+	assert.Len(t, s.Hints(), 8)
 }
diff --git a/internal/view/pvc_test.go b/internal/view/pvc_test.go
--- a/internal/view/pvc_test.go
+++ b/internal/view/pvc_test.go
@@ -17,5 +17,5 @@ func TestPVCNew(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "PersistentVolumeClaims", v.Name())
-	assert.Len(t, v.Hints(), 11)
+	assert.Len(t, v.Hints(), 9)
 }
diff --git a/internal/view/reference_test.go b/internal/view/reference_test.go
--- a/internal/view/reference_test.go
+++ b/internal/view/reference_test.go
@@ -17,5 +17,5 @@ func TestReferenceNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "References", s.Name())
-	assert.Len(t, s.Hints(), 5)
+	assert.Len(t, s.Hints(), 6)
 }
diff --git a/internal/view/screen_dump_test.go b/internal/view/screen_dump_test.go
--- a/internal/view/screen_dump_test.go
+++ b/internal/view/screen_dump_test.go
@@ -17,5 +17,5 @@ func TestScreenDumpNew(t *testing.T) {
 
 	require.NoError(t, po.Init(makeCtx(t)))
 	assert.Equal(t, "ScreenDumps", po.Name())
-	assert.Len(t, po.Hints(), 6)
+	assert.Len(t, po.Hints(), 7)
 }
diff --git a/internal/view/secret_test.go b/internal/view/secret_test.go
--- a/internal/view/secret_test.go
+++ b/internal/view/secret_test.go
@@ -17,5 +17,5 @@ func TestSecretNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "Secrets", s.Name())
-	assert.Len(t, s.Hints(), 9)
+	assert.Len(t, s.Hints(), 10)
 }
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests with the correct test function names
# Using the specific test function names identified by the context retrieval agent
go test -v ./internal/view/ -run "^(TestConfigMapNew|TestContainerNew|TestContext|TestDir|TestDeploy|TestDaemonSet|TestHelp|TestNSCleanser|TestPodNew|TestPriorityClassNew|TestPVCNew|TestReferenceNew|TestScreenDumpNew|TestSecretNew)$"

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 68627675207c1b64b593c44829a7f534ba7eacf4 \
    "internal/view/cm_test.go" \
    "internal/view/container_test.go" \
    "internal/view/context_test.go" \
    "internal/view/dir_test.go" \
    "internal/view/dp_test.go" \
    "internal/view/ds_test.go" \
    "internal/view/help_test.go" \
    "internal/view/ns_test.go" \
    "internal/view/pod_test.go" \
    "internal/view/priorityclass_test.go" \
    "internal/view/pvc_test.go" \
    "internal/view/reference_test.go" \
    "internal/view/screen_dump_test.go" \
    "internal/view/secret_test.go"