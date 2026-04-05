#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 2bf2f481ef9ae46b4ba8faca98652a0c7844f26d \
    "internal/view/alias_test.go" \
    "internal/view/cm_test.go" \
    "internal/view/container_test.go" \
    "internal/view/context_test.go" \
    "internal/view/dir_test.go" \
    "internal/view/dp_test.go" \
    "internal/view/ds_test.go" \
    "internal/view/pf_test.go" \
    "internal/view/priorityclass_test.go" \
    "internal/view/rbac_test.go" \
    "internal/view/reference_test.go" \
    "internal/view/screen_dump_test.go" \
    "internal/view/secret_test.go" \
    "internal/view/sts_test.go" \
    "internal/view/svc_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/view/alias_test.go b/internal/view/alias_test.go
--- a/internal/view/alias_test.go
+++ b/internal/view/alias_test.go
@@ -30,7 +30,7 @@ func TestAliasNew(t *testing.T) {
 
 	require.NoError(t, v.Init(makeContext(t)))
 	assert.Equal(t, "Aliases", v.Name())
-	assert.Len(t, v.Hints(), 6)
+	assert.Len(t, v.Hints(), 7)
 }
 
 func TestAliasSearch(t *testing.T) {
diff --git a/internal/view/cm_test.go b/internal/view/cm_test.go
--- a/internal/view/cm_test.go
+++ b/internal/view/cm_test.go
@@ -17,5 +17,5 @@ func TestConfigMapNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "ConfigMaps", s.Name())
-	assert.Len(t, s.Hints(), 7)
+	assert.Len(t, s.Hints(), 8)
 }
diff --git a/internal/view/container_test.go b/internal/view/container_test.go
--- a/internal/view/container_test.go
+++ b/internal/view/container_test.go
@@ -17,5 +17,5 @@ func TestContainerNew(t *testing.T) {
 
 	require.NoError(t, c.Init(makeCtx(t)))
 	assert.Equal(t, "Containers", c.Name())
-	assert.Len(t, c.Hints(), 19)
+	assert.Len(t, c.Hints(), 20)
 }
diff --git a/internal/view/context_test.go b/internal/view/context_test.go
--- a/internal/view/context_test.go
+++ b/internal/view/context_test.go
@@ -17,5 +17,5 @@ func TestContext(t *testing.T) {
 
 	require.NoError(t, ctx.Init(makeCtx(t)))
 	assert.Equal(t, "Contexts", ctx.Name())
-	assert.Len(t, ctx.Hints(), 6)
+	assert.Len(t, ctx.Hints(), 7)
 }
diff --git a/internal/view/dir_test.go b/internal/view/dir_test.go
--- a/internal/view/dir_test.go
+++ b/internal/view/dir_test.go
@@ -16,5 +16,5 @@ func TestDir(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "Directory", v.Name())
-	assert.Len(t, v.Hints(), 7)
+	assert.Len(t, v.Hints(), 8)
 }
diff --git a/internal/view/dp_test.go b/internal/view/dp_test.go
--- a/internal/view/dp_test.go
+++ b/internal/view/dp_test.go
@@ -17,5 +17,5 @@ func TestDeploy(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "Deployments", v.Name())
-	assert.Len(t, v.Hints(), 17)
+	assert.Len(t, v.Hints(), 18)
 }
diff --git a/internal/view/ds_test.go b/internal/view/ds_test.go
--- a/internal/view/ds_test.go
+++ b/internal/view/ds_test.go
@@ -17,5 +17,5 @@ func TestDaemonSet(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "DaemonSets", v.Name())
-	assert.Len(t, v.Hints(), 17)
+	assert.Len(t, v.Hints(), 18)
 }
diff --git a/internal/view/pf_test.go b/internal/view/pf_test.go
--- a/internal/view/pf_test.go
+++ b/internal/view/pf_test.go
@@ -17,5 +17,5 @@ func TestPortForwardNew(t *testing.T) {
 
 	require.NoError(t, pf.Init(makeCtx(t)))
 	assert.Equal(t, "PortForwards", pf.Name())
-	assert.Len(t, pf.Hints(), 10)
+	assert.Len(t, pf.Hints(), 11)
 }
diff --git a/internal/view/priorityclass_test.go b/internal/view/priorityclass_test.go
--- a/internal/view/priorityclass_test.go
+++ b/internal/view/priorityclass_test.go
@@ -17,5 +17,5 @@ func TestPriorityClassNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "PriorityClass", s.Name())
-	assert.Len(t, s.Hints(), 6)
+	assert.Len(t, s.Hints(), 7)
 }
diff --git a/internal/view/rbac_test.go b/internal/view/rbac_test.go
--- a/internal/view/rbac_test.go
+++ b/internal/view/rbac_test.go
@@ -17,5 +17,5 @@ func TestRbacNew(t *testing.T) {
 
 	require.NoError(t, v.Init(makeCtx(t)))
 	assert.Equal(t, "Rbac", v.Name())
-	assert.Len(t, v.Hints(), 5)
+	assert.Len(t, v.Hints(), 6)
 }
diff --git a/internal/view/reference_test.go b/internal/view/reference_test.go
--- a/internal/view/reference_test.go
+++ b/internal/view/reference_test.go
@@ -17,5 +17,5 @@ func TestReferenceNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "References", s.Name())
-	assert.Len(t, s.Hints(), 4)
+	assert.Len(t, s.Hints(), 5)
 }
diff --git a/internal/view/screen_dump_test.go b/internal/view/screen_dump_test.go
--- a/internal/view/screen_dump_test.go
+++ b/internal/view/screen_dump_test.go
@@ -17,5 +17,5 @@ func TestScreenDumpNew(t *testing.T) {
 
 	require.NoError(t, po.Init(makeCtx(t)))
 	assert.Equal(t, "ScreenDumps", po.Name())
-	assert.Len(t, po.Hints(), 5)
+	assert.Len(t, po.Hints(), 6)
 }
diff --git a/internal/view/secret_test.go b/internal/view/secret_test.go
--- a/internal/view/secret_test.go
+++ b/internal/view/secret_test.go
@@ -17,5 +17,5 @@ func TestSecretNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "Secrets", s.Name())
-	assert.Len(t, s.Hints(), 8)
+	assert.Len(t, s.Hints(), 9)
 }
diff --git a/internal/view/sts_test.go b/internal/view/sts_test.go
--- a/internal/view/sts_test.go
+++ b/internal/view/sts_test.go
@@ -17,5 +17,5 @@ func TestStatefulSetNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "StatefulSets", s.Name())
-	assert.Len(t, s.Hints(), 14)
+	assert.Len(t, s.Hints(), 15)
 }
diff --git a/internal/view/svc_test.go b/internal/view/svc_test.go
--- a/internal/view/svc_test.go
+++ b/internal/view/svc_test.go
@@ -174,5 +174,5 @@ func TestServiceNew(t *testing.T) {
 
 	require.NoError(t, s.Init(makeCtx(t)))
 	assert.Equal(t, "Services", s.Name())
-	assert.Len(t, s.Hints(), 12)
+	assert.Len(t, s.Hints(), 13)
 }
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests
# Running tests only for the specified test files in internal/view package
# Using -v for verbose output to help with debugging
go test -v ./internal/view \
    -run "Test"

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 2bf2f481ef9ae46b4ba8faca98652a0c7844f26d \
    "internal/view/alias_test.go" \
    "internal/view/cm_test.go" \
    "internal/view/container_test.go" \
    "internal/view/context_test.go" \
    "internal/view/dir_test.go" \
    "internal/view/dp_test.go" \
    "internal/view/ds_test.go" \
    "internal/view/pf_test.go" \
    "internal/view/priorityclass_test.go" \
    "internal/view/rbac_test.go" \
    "internal/view/reference_test.go" \
    "internal/view/screen_dump_test.go" \
    "internal/view/secret_test.go" \
    "internal/view/sts_test.go" \
    "internal/view/svc_test.go"