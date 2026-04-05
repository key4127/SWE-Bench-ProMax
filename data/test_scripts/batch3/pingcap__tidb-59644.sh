#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9b8296bd612c6c85e170a5bd91fccb759d6aecff "pkg/bindinfo/binding_cache_test.go" "pkg/bindinfo/global_handle_test.go" "pkg/bindinfo/session_handle_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/bindinfo/binding_cache_test.go b/pkg/bindinfo/binding_cache_test.go
--- a/pkg/bindinfo/binding_cache_test.go
+++ b/pkg/bindinfo/binding_cache_test.go
@@ -30,7 +30,7 @@ func bindingNoDBDigest(t *testing.T, b *Binding) string {
 	p := parser.New()
 	stmt, err := p.ParseOneStmt(b.BindSQL, b.Charset, b.Collation)
 	require.NoError(t, err)
-	_, noDBDigest := NormalizeStmtForBinding(stmt, WithoutDB(true))
+	_, noDBDigest := NormalizeStmtForBinding(stmt, "", true)
 	return noDBDigest
 }
 
diff --git a/pkg/bindinfo/global_handle_test.go b/pkg/bindinfo/global_handle_test.go
--- a/pkg/bindinfo/global_handle_test.go
+++ b/pkg/bindinfo/global_handle_test.go
@@ -73,7 +73,7 @@ func TestBindingLastUpdateTime(t *testing.T) {
 	stmt, err := parser.New().ParseOneStmt("select * from test . t0", "", "")
 	require.NoError(t, err)
 
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := bindHandle.MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	updateTime := binding.UpdateTime.String()
@@ -139,7 +139,7 @@ func TestBindParse(t *testing.T) {
 
 	stmt, err := parser.New().ParseOneStmt("select * from test . t", "", "")
 	require.NoError(t, err)
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := bindHandle.MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t`", binding.OriginalSQL)
@@ -435,7 +435,7 @@ func TestGlobalBinding(t *testing.T) {
 
 		stmt, _, _ := utilNormalizeWithDefaultDB(t, testSQL.querySQL)
 
-		_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.True(t, matched)
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
@@ -468,7 +468,7 @@ func TestGlobalBinding(t *testing.T) {
 		require.NoError(t, err)
 		require.Equal(t, 1, len(bindHandle.GetAllGlobalBindings()))
 
-		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.True(t, matched)
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
@@ -483,15 +483,15 @@ func TestGlobalBinding(t *testing.T) {
 		_, err = tk.Exec("drop global " + testSQL.dropSQL)
 		require.Equal(t, uint64(1), tk.Session().AffectedRows())
 		require.NoError(t, err)
-		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		_, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.False(t, matched) // dropped
 		bindHandle = bindinfo.NewGlobalBindingHandle(&mockSessionPool{tk.Session()})
 		err = bindHandle.LoadFromStorageToCache(true)
 		require.NoError(t, err)
 		require.Equal(t, 0, len(bindHandle.GetAllGlobalBindings()))
 
-		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		_, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.False(t, matched) // dropped
 
@@ -679,7 +679,7 @@ func TestNormalizeStmtForBinding(t *testing.T) {
 	}
 	for _, test := range tests {
 		stmt, _, _ := utilNormalizeWithDefaultDB(t, test.sql)
-		n, digest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		n, digest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		require.Equal(t, test.normalized, n)
 		require.Equal(t, test.digest, digest)
 	}
@@ -696,39 +696,39 @@ func TestHintsSetID(t *testing.T) {
 	// Verify the added Binding contains ID with restored query block.
 	stmt, err := parser.New().ParseOneStmt("select * from t where a > ?", "", "")
 	require.NoError(t, err)
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
 	require.Equal(t, "use_index(@`sel_1` `test`.`t` `idx_a`)", binding.ID)
 
 	utilCleanBindingEnv(tk)
 	tk.MustExec("create global binding for select * from t where a > 10 using select /*+ use_index(t, idx_a) */ * from t where a > 10")
-	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
 	require.Equal(t, "use_index(@`sel_1` `test`.`t` `idx_a`)", binding.ID)
 
 	utilCleanBindingEnv(tk)
 	tk.MustExec("create global binding for select * from t where a > 10 using select /*+ use_index(@sel_1 t, idx_a) */ * from t where a > 10")
-	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
 	require.Equal(t, "use_index(@`sel_1` `test`.`t` `idx_a`)", binding.ID)
 
 	utilCleanBindingEnv(tk)
 	tk.MustExec("create global binding for select * from t where a > 10 using select /*+ use_index(@qb1 t, idx_a) qb_name(qb1) */ * from t where a > 10")
-	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
 	require.Equal(t, "use_index(@`sel_1` `test`.`t` `idx_a`)", binding.ID)
 
 	utilCleanBindingEnv(tk)
 	tk.MustExec("create global binding for select * from t where a > 10 using select /*+ use_index(T, IDX_A) */ * from t where a > 10")
-	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
@@ -738,7 +738,7 @@ func TestHintsSetID(t *testing.T) {
 	err = tk.ExecToErr("create global binding for select * from t using select /*+ non_exist_hint() */ * from t")
 	require.True(t, terror.ErrorEqual(err, parser.ErrParse))
 	tk.MustExec("create global binding for select * from t where a > 10 using select * from t where a > 10")
-	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched = dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `a` > ?", binding.OriginalSQL)
@@ -761,7 +761,7 @@ func TestErrorBind(t *testing.T) {
 
 	stmt, err := parser.New().ParseOneStmt("select * from test . t where i > ?", "", "")
 	require.NoError(t, err)
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select * from `test` . `t` where `i` > ?", binding.OriginalSQL)
@@ -801,7 +801,7 @@ func TestBestPlanInBaselines(t *testing.T) {
 
 	stmt, _, _ := utilNormalizeWithDefaultDB(t, "select a, b from t where a = 1 limit 0, 1")
 
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` = ? limit ...", binding.OriginalSQL)
@@ -844,7 +844,7 @@ func TestBindingSymbolList(t *testing.T) {
 	stmt, err := parser.New().ParseOneStmt("select a, b from test . t where a = 1 limit 0, 1", "", "")
 	require.NoError(t, err)
 
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` = ? limit ...", binding.OriginalSQL)
@@ -889,7 +889,7 @@ func TestBindingInListWithSingleLiteral(t *testing.T) {
 	stmt, err := parser.New().ParseOneStmt("select a, b from test . t where a in (1)", "", "")
 	require.NoError(t, err)
 
-	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+	_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 	binding, matched := dom.BindHandle().MatchGlobalBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 	require.True(t, matched)
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` in ( ... )", binding.OriginalSQL)
diff --git a/pkg/bindinfo/session_handle_test.go b/pkg/bindinfo/session_handle_test.go
--- a/pkg/bindinfo/session_handle_test.go
+++ b/pkg/bindinfo/session_handle_test.go
@@ -92,7 +92,7 @@ func TestSessionBinding(t *testing.T) {
 		stmt, err := parser.New().ParseOneStmt(testSQL.originSQL, "", "")
 		require.NoError(t, err)
 
-		_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest := bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		binding, matched := handle.MatchSessionBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.True(t, matched)
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
@@ -129,7 +129,7 @@ func TestSessionBinding(t *testing.T) {
 
 		_, err = tk.Exec("drop session " + testSQL.dropSQL)
 		require.NoError(t, err)
-		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, bindinfo.WithoutDB(true))
+		_, noDBDigest = bindinfo.NormalizeStmtForBinding(stmt, "", true)
 		_, matched = handle.MatchSessionBinding(tk.Session(), noDBDigest, bindinfo.CollectTableNames(stmt))
 		require.False(t, matched) // dropped
 	}
EOF_114329324912

# Set required environment variables
export TZ=Asia/Shanghai
export GO111MODULE=on

# Enable failpoints (critical for TiDB tests)
/testbed/tools/bin/failpoint-ctl enable

# Run the target tests with required flags
# Using -tags 'intest' as required by TiDB build system
# Running at package level since all test files are in pkg/bindinfo
go test -tags 'intest' -v ./pkg/bindinfo -run 'Test.*' 2>&1
rc=$?

# Disable failpoints (cleanup, even if tests failed)
/testbed/tools/bin/failpoint-ctl disable

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 9b8296bd612c6c85e170a5bd91fccb759d6aecff "pkg/bindinfo/binding_cache_test.go" "pkg/bindinfo/global_handle_test.go" "pkg/bindinfo/session_handle_test.go"