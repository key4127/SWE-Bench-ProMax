#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 444c38fba0753d84448a39a72ce2fc01102d49b4 "pkg/bindinfo/global_handle_test.go" "pkg/bindinfo/session_handle_test.go" "pkg/bindinfo/tests/bind_test.go" "pkg/session/bootstrap_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/bindinfo/global_handle_test.go b/pkg/bindinfo/global_handle_test.go
--- a/pkg/bindinfo/global_handle_test.go
+++ b/pkg/bindinfo/global_handle_test.go
@@ -98,7 +98,7 @@ func TestBindingLastUpdateTimeWithInvalidBind(t *testing.T) {
 	require.Equal(t, updateTime0, "0000-00-00 00:00:00")
 
 	tk.MustExec("insert into mysql.bind_info values('select * from `test` . `t`', 'invalid_binding', 'test', 'enabled', '2000-01-01 09:00:00', '2000-01-01 09:00:00', '', '','" +
-		bindinfo.Manual + "', '', '')")
+		bindinfo.SourceManual + "', '', '')")
 	tk.MustExec("use test")
 	tk.MustExec("drop table if exists t")
 	tk.MustExec("admin reload bindings;")
@@ -123,10 +123,10 @@ func TestBindParse(t *testing.T) {
 	originSQL := "select * from `test` . `t`"
 	bindSQL := "select * from `test` . `t` use index(index_t)"
 	defaultDb := "test"
-	status := bindinfo.Enabled
+	status := bindinfo.StatusEnabled
 	charset := "utf8mb4"
 	collation := "utf8mb4_bin"
-	source := bindinfo.Manual
+	source := bindinfo.SourceManual
 	_, digest := parser.NormalizeDigestForBinding(originSQL)
 	mockDigest := digest.String()
 	sql := fmt.Sprintf(`INSERT INTO mysql.bind_info(original_sql,bind_sql,default_db,status,create_time,update_time,charset,collation,source, sql_digest, plan_digest) VALUES ('%s', '%s', '%s', '%s', NOW(), NOW(),'%s', '%s', '%s', '%s', '%s')`,
@@ -145,7 +145,7 @@ func TestBindParse(t *testing.T) {
 	require.Equal(t, "select * from `test` . `t`", binding.OriginalSQL)
 	require.Equal(t, "select * from `test` . `t` use index(index_t)", binding.BindSQL)
 	require.Equal(t, "test", binding.Db)
-	require.Equal(t, bindinfo.Enabled, binding.Status)
+	require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 	require.Equal(t, "utf8mb4", binding.Charset)
 	require.Equal(t, "utf8mb4_bin", binding.Collation)
 	require.NotNil(t, binding.CreateTime)
@@ -210,41 +210,41 @@ func TestSetBindingStatus(t *testing.T) {
 	tk.MustExec("create global binding for select * from t where a > 10 using select /*+ USE_INDEX(t, idx_a) */ * from t where a > 10")
 	rows := tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 	tk.MustExec("select * from t where a > 10")
 	tk.MustQuery("select @@last_plan_from_binding").Check(testkit.Rows("1"))
 
 	tk.MustExec("set binding disabled for select * from t where a > 10")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Disabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusDisabled, rows[0][3])
 	tk.MustExec("select * from t where a > 10")
 	tk.MustQuery("select @@last_plan_from_binding").Check(testkit.Rows("0"))
 
 	tk.MustExec("set binding enabled for select * from t where a > 10")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 
 	tk.MustExec("set binding disabled for select * from t where a > 10")
 	tk.MustExec("create global binding for select * from t where a > 10 using select * from t where a > 10")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 	tk.MustExec("select * from t where a > 10")
 	tk.MustQuery("select @@last_plan_from_binding").Check(testkit.Rows("1"))
 
 	tk.MustExec("set binding disabled for select * from t where a > 10 using select * from t where a > 10")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Disabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusDisabled, rows[0][3])
 	tk.MustExec("select * from t where a > 10")
 	tk.MustQuery("select @@last_plan_from_binding").Check(testkit.Rows("0"))
 
 	tk.MustExec("set binding enabled for select * from t where a > 10 using select * from t where a > 10")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 
 	tk.MustExec("set binding disabled for select * from t where a > 10 using select * from t where a > 10")
 	tk.MustExec("drop global binding for select * from t where a > 10 using select * from t where a > 10")
@@ -266,28 +266,28 @@ func TestSetBindingStatusWithoutBindingInCache(t *testing.T) {
 	// Simulate creating bindings on other machines
 	_, sqlDigest := parser.NormalizeDigestForBinding("select * from `test` . `t` where `a` > ?")
 	tk.MustExec("insert into mysql.bind_info values('select * from `test` . `t` where `a` > ?', 'SELECT /*+ USE_INDEX(`t` `idx_a`)*/ * FROM `test`.`t` WHERE `a` > 10', 'test', 'deleted', '2000-01-01 09:00:00', '2000-01-01 09:00:00', '', '','" +
-		bindinfo.Manual + "', '" + sqlDigest.String() + "', '')")
+		bindinfo.SourceManual + "', '" + sqlDigest.String() + "', '')")
 	tk.MustExec("insert into mysql.bind_info values('select * from `test` . `t` where `a` > ?', 'SELECT /*+ USE_INDEX(`t` `idx_a`)*/ * FROM `test`.`t` WHERE `a` > 10', 'test', 'enabled', '2000-01-02 09:00:00', '2000-01-02 09:00:00', '', '','" +
-		bindinfo.Manual + "', '" + sqlDigest.String() + "', '')")
+		bindinfo.SourceManual + "', '" + sqlDigest.String() + "', '')")
 	tk.MustExec("set binding disabled for select * from t where a > 10")
 	tk.MustExec("admin reload bindings")
 	rows := tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Disabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusDisabled, rows[0][3])
 
 	// clear the mysql.bind_info
 	utilCleanBindingEnv(tk)
 
 	// Simulate creating bindings on other machines
 	tk.MustExec("insert into mysql.bind_info values('select * from `test` . `t` where `a` > ?', 'SELECT * FROM `test`.`t` WHERE `a` > 10', 'test', 'deleted', '2000-01-01 09:00:00', '2000-01-01 09:00:00', '', '','" +
-		bindinfo.Manual + "', '" + sqlDigest.String() + "', '')")
+		bindinfo.SourceManual + "', '" + sqlDigest.String() + "', '')")
 	tk.MustExec("insert into mysql.bind_info values('select * from `test` . `t` where `a` > ?', 'SELECT * FROM `test`.`t` WHERE `a` > 10', 'test', 'disabled', '2000-01-02 09:00:00', '2000-01-02 09:00:00', '', '','" +
-		bindinfo.Manual + "', '" + sqlDigest.String() + "', '')")
+		bindinfo.SourceManual + "', '" + sqlDigest.String() + "', '')")
 	tk.MustExec("set binding enabled for select * from t where a > 10")
 	tk.MustExec("admin reload bindings")
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 
 	utilCleanBindingEnv(tk)
 }
@@ -441,7 +441,7 @@ func TestGlobalBinding(t *testing.T) {
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
 		require.Equal(t, testSQL.bindSQL, binding.BindSQL)
 		require.Equal(t, "test", binding.Db)
-		require.Equal(t, bindinfo.Enabled, binding.Status)
+		require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 		require.NotNil(t, binding.Charset)
 		require.NotNil(t, binding.Collation)
 		require.NotNil(t, binding.CreateTime)
@@ -457,7 +457,7 @@ func TestGlobalBinding(t *testing.T) {
 		require.Equal(t, testSQL.originSQL, row.GetString(0))
 		require.Equal(t, testSQL.bindSQL, row.GetString(1))
 		require.Equal(t, "test", row.GetString(2))
-		require.Equal(t, bindinfo.Enabled, row.GetString(3))
+		require.Equal(t, bindinfo.StatusEnabled, row.GetString(3))
 		require.NotNil(t, row.GetTime(4))
 		require.NotNil(t, row.GetTime(5))
 		require.NotNil(t, row.GetString(6))
@@ -474,7 +474,7 @@ func TestGlobalBinding(t *testing.T) {
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
 		require.Equal(t, testSQL.bindSQL, binding.BindSQL)
 		require.Equal(t, "test", binding.Db)
-		require.Equal(t, bindinfo.Enabled, binding.Status)
+		require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 		require.NotNil(t, binding.Charset)
 		require.NotNil(t, binding.Collation)
 		require.NotNil(t, binding.CreateTime)
@@ -575,7 +575,7 @@ func TestRemoveDuplicatedPseudoBinding(t *testing.T) {
 	insertPseudoBinding := func() {
 		tk.MustExec(fmt.Sprintf(`INSERT INTO mysql.bind_info(original_sql, bind_sql, default_db, status, create_time, update_time, charset, collation, source)
             VALUES ('%v', '%v', "mysql", '%v', "2000-01-01 00:00:00", "2000-01-01 00:00:00", "", "", '%v')`,
-			bindinfo.BuiltinPseudoSQL4BindLock, bindinfo.BuiltinPseudoSQL4BindLock, bindinfo.Builtin, bindinfo.Builtin))
+			bindinfo.BuiltinPseudoSQL4BindLock, bindinfo.BuiltinPseudoSQL4BindLock, bindinfo.StatusBuiltin, bindinfo.StatusBuiltin))
 	}
 	removeDuplicated := func() {
 		tk.MustExec(bindinfo.StmtRemoveDuplicatedPseudoBinding)
@@ -765,7 +765,7 @@ func TestErrorBind(t *testing.T) {
 	require.Equal(t, "select * from `test` . `t` where `i` > ?", binding.OriginalSQL)
 	require.Equal(t, "SELECT * FROM `test`.`t` USE INDEX (`index_t`) WHERE `i` > 100", binding.BindSQL)
 	require.Equal(t, "test", binding.Db)
-	require.Equal(t, bindinfo.Enabled, binding.Status)
+	require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 	require.NotNil(t, binding.Charset)
 	require.NotNil(t, binding.Collation)
 	require.NotNil(t, binding.CreateTime)
@@ -805,7 +805,7 @@ func TestBestPlanInBaselines(t *testing.T) {
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` = ? limit ...", binding.OriginalSQL)
 	require.Equal(t, "SELECT /*+ use_index(@`sel_1` `test`.`t` `ia`)*/ `a`,`b` FROM `test`.`t` WHERE `a` = 1 LIMIT 0,1", binding.BindSQL)
 	require.Equal(t, "test", binding.Db)
-	require.Equal(t, bindinfo.Enabled, binding.Status)
+	require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 
 	tk.MustQuery("select a, b from t where a = 3 limit 1, 10")
 	require.Equal(t, "t:ia", tk.Session().GetSessionVars().StmtCtx.IndexNames[0])
@@ -848,7 +848,7 @@ func TestBindingSymbolList(t *testing.T) {
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` = ? limit ...", binding.OriginalSQL)
 	require.Equal(t, "SELECT `a`,`b` FROM `test`.`t` USE INDEX (`ib`) WHERE `a` = 1 LIMIT 0,1", binding.BindSQL)
 	require.Equal(t, "test", binding.Db)
-	require.Equal(t, bindinfo.Enabled, binding.Status)
+	require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 	require.NotNil(t, binding.Charset)
 	require.NotNil(t, binding.Collation)
 	require.NotNil(t, binding.CreateTime)
@@ -893,7 +893,7 @@ func TestBindingInListWithSingleLiteral(t *testing.T) {
 	require.Equal(t, "select `a` , `b` from `test` . `t` where `a` in ( ... )", binding.OriginalSQL)
 	require.Equal(t, "SELECT `a`,`b` FROM `test`.`t` USE INDEX (`ib`) WHERE `a` IN (1,2,3)", binding.BindSQL)
 	require.Equal(t, "test", binding.Db)
-	require.Equal(t, bindinfo.Enabled, binding.Status)
+	require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 	require.NotNil(t, binding.Charset)
 	require.NotNil(t, binding.Collation)
 	require.NotNil(t, binding.CreateTime)
diff --git a/pkg/bindinfo/session_handle_test.go b/pkg/bindinfo/session_handle_test.go
--- a/pkg/bindinfo/session_handle_test.go
+++ b/pkg/bindinfo/session_handle_test.go
@@ -98,7 +98,7 @@ func TestSessionBinding(t *testing.T) {
 		require.Equal(t, testSQL.originSQL, binding.OriginalSQL)
 		require.Equal(t, testSQL.bindSQL, binding.BindSQL)
 		require.Equal(t, "test", binding.Db)
-		require.Equal(t, bindinfo.Enabled, binding.Status)
+		require.Equal(t, bindinfo.StatusEnabled, binding.Status)
 		require.NotNil(t, binding.Charset)
 		require.NotNil(t, binding.Collation)
 		require.NotNil(t, binding.CreateTime)
@@ -121,7 +121,7 @@ func TestSessionBinding(t *testing.T) {
 		require.Equal(t, testSQL.originSQL, row.GetString(0))
 		require.Equal(t, testSQL.bindSQL, row.GetString(1))
 		require.Equal(t, "test", row.GetString(2))
-		require.Equal(t, bindinfo.Enabled, row.GetString(3))
+		require.Equal(t, bindinfo.StatusEnabled, row.GetString(3))
 		require.NotNil(t, row.GetTime(4))
 		require.NotNil(t, row.GetTime(5))
 		require.NotNil(t, row.GetString(6))
diff --git a/pkg/bindinfo/tests/bind_test.go b/pkg/bindinfo/tests/bind_test.go
--- a/pkg/bindinfo/tests/bind_test.go
+++ b/pkg/bindinfo/tests/bind_test.go
@@ -393,9 +393,9 @@ func TestGCBindRecord(t *testing.T) {
 	rows := tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
 	require.Equal(t, "select * from `test` . `t` where `a` = ?", rows[0][0])
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 	tk.MustQuery("select status from mysql.bind_info where original_sql = 'select * from `test` . `t` where `a` = ?'").Check(testkit.Rows(
-		bindinfo.Enabled,
+		bindinfo.StatusEnabled,
 	))
 
 	h := dom.BindHandle()
@@ -404,9 +404,9 @@ func TestGCBindRecord(t *testing.T) {
 	rows = tk.MustQuery("show global bindings").Rows()
 	require.Len(t, rows, 1)
 	require.Equal(t, "select * from `test` . `t` where `a` = ?", rows[0][0])
-	require.Equal(t, bindinfo.Enabled, rows[0][3])
+	require.Equal(t, bindinfo.StatusEnabled, rows[0][3])
 	tk.MustQuery("select status from mysql.bind_info where original_sql = 'select * from `test` . `t` where `a` = ?'").Check(testkit.Rows(
-		bindinfo.Enabled,
+		bindinfo.StatusEnabled,
 	))
 
 	tk.MustExec("drop global binding for select * from t where a = 1")
diff --git a/pkg/session/bootstrap_test.go b/pkg/session/bootstrap_test.go
--- a/pkg/session/bootstrap_test.go
+++ b/pkg/session/bootstrap_test.go
@@ -614,19 +614,19 @@ func TestUpdateDuplicateBindInfo(t *testing.T) {
 	require.Equal(t, "select * from `test` . `t`", row.GetString(0))
 	require.Equal(t, "SELECT /*+ use_index(`t` `idx_b`)*/ * FROM `test`.`t`", row.GetString(1))
 	require.Equal(t, "", row.GetString(2))
-	require.Equal(t, bindinfo.Enabled, row.GetString(3))
+	require.Equal(t, bindinfo.StatusEnabled, row.GetString(3))
 	require.Equal(t, "2021-01-04 14:50:58.257", row.GetTime(4).String())
 	row = req.GetRow(1)
 	require.Equal(t, "select * from `test` . `t` where `a` < ?", row.GetString(0))
 	require.Equal(t, "SELECT * FROM `test`.`t` IGNORE INDEX (`idx`) WHERE `a` < 1", row.GetString(1))
 	require.Equal(t, "", row.GetString(2))
-	require.Equal(t, bindinfo.Enabled, row.GetString(3))
+	require.Equal(t, bindinfo.StatusEnabled, row.GetString(3))
 	require.Equal(t, "2021-06-04 17:04:43.335", row.GetTime(4).String())
 	row = req.GetRow(2)
 	require.Equal(t, "select * from `test` . `t` where `a` <= ?", row.GetString(0))
 	require.Equal(t, "SELECT * FROM `test`.`t` IGNORE INDEX (`idx`) WHERE `a` <= 1", row.GetString(1))
 	require.Equal(t, "", row.GetString(2))
-	require.Equal(t, bindinfo.Enabled, row.GetString(3))
+	require.Equal(t, bindinfo.StatusEnabled, row.GetString(3))
 	require.Equal(t, "2021-06-04 17:04:45.334", row.GetTime(4).String())
 
 	require.NoError(t, r.Close())
EOF_114329324912

# Set required environment variables
export CGO_ENABLED=1
export GO111MODULE=on
export TZ=Asia/Shanghai
export log_level=fatal

# Inspect test function names after patch is applied
echo "=========================================="
echo "Inspecting test function names in pkg/bindinfo..."
echo "=========================================="
grep -E '^func Test' pkg/bindinfo/global_handle_test.go pkg/bindinfo/session_handle_test.go || echo "No test functions found with grep"

# Enable failpoints before running tests (required for TiDB tests)
make failpoint-enable

# Run the target test files
# For pkg/bindinfo: Run all tests in the package (global_handle_test.go and session_handle_test.go)
echo "=========================================="
echo "Running pkg/bindinfo tests (all tests in package)..."
echo "=========================================="
go test -v -cover -covermode=count -tags=intest -p 1 -parallel 1 \
    ./pkg/bindinfo
bindinfo_rc=$?

echo "=========================================="
echo "Running pkg/bindinfo/tests (bind_test.go)..."
echo "=========================================="
go test -v -cover -covermode=count -tags=intest -p 1 -parallel 1 \
    ./pkg/bindinfo/tests
bindinfo_tests_rc=$?

echo "=========================================="
echo "Running session package bootstrap test..."
echo "=========================================="
go test -v -cover -covermode=count -tags=intest -p 1 -parallel 1 \
    ./pkg/session -run "TestBootstrap"
session_rc=$?

# Disable failpoints after tests
make failpoint-disable

# Determine overall exit code (fail if any test failed)
if [ $bindinfo_rc -ne 0 ] || [ $bindinfo_tests_rc -ne 0 ] || [ $session_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

echo "=========================================="
echo "Test execution completed"
echo "pkg/bindinfo tests exit code: $bindinfo_rc"
echo "pkg/bindinfo/tests exit code: $bindinfo_tests_rc"
echo "pkg/session tests exit code: $session_rc"
echo "=========================================="

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 444c38fba0753d84448a39a72ce2fc01102d49b4 "pkg/bindinfo/global_handle_test.go" "pkg/bindinfo/session_handle_test.go" "pkg/bindinfo/tests/bind_test.go" "pkg/session/bootstrap_test.go"