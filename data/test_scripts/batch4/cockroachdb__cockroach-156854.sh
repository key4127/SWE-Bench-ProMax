#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout eb2dbf6dfa94282185a2ac4ddd42633fe9b5c60c \
    "pkg/kv/kvserver/logstore/sideload_test.go" \
    "pkg/kv/kvserver/replica_raftlog_test.go" \
    "pkg/server/api_v2_databases_metadata_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/kv/kvserver/logstore/sideload_test.go b/pkg/kv/kvserver/logstore/sideload_test.go
--- a/pkg/kv/kvserver/logstore/sideload_test.go
+++ b/pkg/kv/kvserver/logstore/sideload_test.go
@@ -86,7 +86,7 @@ func newTestingSideloadStorage(eng storage.Engine) *DiskSideloadStorage {
 	return NewDiskSideloadStorage(
 		cluster.MakeTestingClusterSettings(), 1,
 		filepath.Join(eng.GetAuxiliaryDir(), "fake", "testing", "dir"),
-		rate.NewLimiter(rate.Inf, math.MaxInt64), eng)
+		rate.NewLimiter(rate.Inf, math.MaxInt64), eng.Env())
 }
 
 // TODO(pavelkalinnikov): give these tests a good refactor.
@@ -96,7 +96,7 @@ func testSideloadingSideloadedStorage(t *testing.T, eng storage.Engine) {
 
 	assertExists := func(exists bool) {
 		t.Helper()
-		_, err := ss.eng.Env().Stat(ss.dir)
+		_, err := ss.fs.Stat(ss.dir)
 		if !exists {
 			require.True(t, oserror.IsNotExist(err), err)
 		} else {
@@ -537,7 +537,7 @@ func TestRaftSSTableSideloadingSideload(t *testing.T) {
 			if test.size != stats.SideloadedBytes {
 				t.Fatalf("expected %d sideloadedSize, but found %d", test.size, stats.SideloadedBytes)
 			}
-			actKeys, err := sideloaded.eng.Env().List(sideloaded.Dir())
+			actKeys, err := sideloaded.fs.List(sideloaded.Dir())
 			if oserror.IsNotExist(err) {
 				t.Log("swallowing IsNotExist")
 				err = nil
diff --git a/pkg/kv/kvserver/replica_raftlog_test.go b/pkg/kv/kvserver/replica_raftlog_test.go
--- a/pkg/kv/kvserver/replica_raftlog_test.go
+++ b/pkg/kv/kvserver/replica_raftlog_test.go
@@ -102,7 +102,7 @@ func newReplicaLogStorageTest(t *testing.T) *replicaLogStorageTest {
 	st := cluster.MakeTestingClusterSettings()
 	eng := storage.NewDefaultInMemForTesting()
 	sideloaded := logstore.NewDiskSideloadStorage(st, rangeID,
-		eng.GetAuxiliaryDir(), nil /* limiter: unused */, eng)
+		eng.GetAuxiliaryDir(), nil /* limiter: unused */, eng.Env())
 
 	rt.ls = &replicaLogStorage{
 		ctx:     context.Background(),
diff --git a/pkg/server/api_v2_databases_metadata_test.go b/pkg/server/api_v2_databases_metadata_test.go
--- a/pkg/server/api_v2_databases_metadata_test.go
+++ b/pkg/server/api_v2_databases_metadata_test.go
@@ -388,6 +388,23 @@ func TestGetTableMetadataWithDetails(t *testing.T) {
 			t, userClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
 		require.NotEmpty(t, resp.Metadata)
 		require.Contains(t, resp.CreateStatement, table.tableName)
+
+		// Test with dedicated admin user (user named 'admin').
+		adminUsername := username.AdminRoleName()
+		adminClient, _, err := ts.GetAuthenticatedHTTPClientAndCookie(adminUsername, false, 1)
+		require.NoError(t, err)
+
+		// Admin user should be able to access the table even without explicit CONNECT grants.
+		resp = makeApiRequest[tableMetadataWithDetailsResponse](
+			t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		require.NotEmpty(t, resp.Metadata)
+		require.Contains(t, resp.CreateStatement, table.tableName)
+
+		// Admin user should still have access even after revoking public access was already done above.
+		resp = makeApiRequest[tableMetadataWithDetailsResponse](
+			t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		require.NotEmpty(t, resp.Metadata)
+		require.Contains(t, resp.CreateStatement, table.tableName)
 	})
 
 	t.Run("non GET method 405 error", func(t *testing.T) {
@@ -508,14 +525,14 @@ func TestGetDbMetadata(t *testing.T) {
 
 		// All databases grant CONNECT to public by default, so the user should see all databases.
 		// There should be 4: defaultdb, postgres, new_test_db_1, and new_test_db_2.
-		// The system db should not be included, since it doe snot have CONNECT granted to public.
+		// The system db should not be included, since it does not have CONNECT granted to public.
 		uri := "/api/v2/database_metadata/?sortBy=name"
 		mdResp := makeApiRequest[PaginatedResponse[[]dbMetadata]](t, userClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
 		verifyDatabases([]string{"defaultdb", "new_test_db_1", "new_test_db_2", "postgres"}, mdResp.Results)
 
 		// Revoke connect access for public from db1.
 		conn.Exec(t, fmt.Sprintf("REVOKE CONNECT ON DATABASE %s FROM %s", db1Name, "public"))
-		// Asser that user no longer sees db1.
+		// Assert that user no longer sees db1.
 		mdResp = makeApiRequest[PaginatedResponse[[]dbMetadata]](t, userClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
 		verifyDatabases([]string{"defaultdb", "new_test_db_2", "postgres"}, mdResp.Results)
 
@@ -535,6 +552,23 @@ func TestGetDbMetadata(t *testing.T) {
 		conn.Exec(t, fmt.Sprintf("GRANT admin TO %s", sessionUsername.Normalized()))
 		mdResp = makeApiRequest[PaginatedResponse[[]dbMetadata]](t, userClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
 		verifyDatabases([]string{"defaultdb", "new_test_db_1", "new_test_db_2", "postgres", "system"}, mdResp.Results)
+
+		// Test with dedicated admin user (user named 'admin').
+		adminUsername := username.AdminRoleName()
+		adminClient, _, err := ts.GetAuthenticatedHTTPClientAndCookie(adminUsername, false, 1)
+		require.NoError(t, err)
+
+		// The admin user should see all databases even without explicit CONNECT grants.
+		// There should be 5: defaultdb, postgres, new_test_db_1, and new_test_db_2, system.
+		mdResp = makeApiRequest[PaginatedResponse[[]dbMetadata]](t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		verifyDatabases([]string{"defaultdb", "new_test_db_1", "new_test_db_2", "postgres", "system"}, mdResp.Results)
+
+		// Revoke CONNECT on public from both test databases to ensure the admin user
+		// can still see them.
+		conn.Exec(t, fmt.Sprintf("REVOKE CONNECT ON DATABASE %s FROM %s", db1Name, "public"))
+		conn.Exec(t, fmt.Sprintf("REVOKE CONNECT ON DATABASE %s FROM %s", db2Name, "public"))
+		mdResp = makeApiRequest[PaginatedResponse[[]dbMetadata]](t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		verifyDatabases([]string{"defaultdb", "new_test_db_1", "new_test_db_2", "postgres", "system"}, mdResp.Results)
 	})
 
 	t.Run("pagination", func(t *testing.T) {
@@ -700,6 +734,26 @@ func TestGetDbMetadataWithDetails(t *testing.T) {
 		// Assert that user can see system db.
 		resp = makeApiRequest[dbMetadataWithDetailsResponse](t, userClient, ts.AdminURL().WithPath(systemUri).String(), http.MethodGet)
 		require.Equal(t, int64(1), resp.Metadata.DbId)
+
+		// Test with dedicated admin user (user named 'admin').
+		adminUsername := username.AdminRoleName()
+		adminClient, _, err := ts.GetAuthenticatedHTTPClientAndCookie(adminUsername, false, 1)
+		require.NoError(t, err)
+
+		// Admin user should be able to access the database even without explicit CONNECT grants.
+		resp = makeApiRequest[dbMetadataWithDetailsResponse](
+			t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		require.Equal(t, int64(db1Id), resp.Metadata.DbId)
+
+		// Admin user should also see the system database.
+		resp = makeApiRequest[dbMetadataWithDetailsResponse](
+			t, adminClient, ts.AdminURL().WithPath(systemUri).String(), http.MethodGet)
+		require.Equal(t, int64(1), resp.Metadata.DbId)
+
+		// Admin user should still have access even after public access was already revoked above.
+		resp = makeApiRequest[dbMetadataWithDetailsResponse](
+			t, adminClient, ts.AdminURL().WithPath(uri).String(), http.MethodGet)
+		require.Equal(t, int64(db1Id), resp.Metadata.DbId)
 	})
 
 	t.Run("non GET method 405 error", func(t *testing.T) {
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go
export USE_BAZEL_VERSION=cockroachdb/7.6.0

# Run the three Bazel test targets sequentially
# Test 1: logstore_test (normal size, 1 shard)
echo "Running logstore_test..."
bazel test //pkg/kv/kvserver/logstore:logstore_test --test_output=errors
test1_rc=$?

if [ $test1_rc -ne 0 ]; then
    echo "logstore_test failed with exit code $test1_rc"
    echo "OMNIGRIL_EXIT_CODE=$test1_rc"
    git checkout eb2dbf6dfa94282185a2ac4ddd42633fe9b5c60c \
        "pkg/kv/kvserver/logstore/sideload_test.go" \
        "pkg/kv/kvserver/replica_raftlog_test.go" \
        "pkg/server/api_v2_databases_metadata_test.go"
    exit $test1_rc
fi

# Test 2: kvserver_test (enormous size, 48 shards)
echo "Running kvserver_test..."
bazel test //pkg/kv/kvserver:kvserver_test --test_output=errors
test2_rc=$?

if [ $test2_rc -ne 0 ]; then
    echo "kvserver_test failed with exit code $test2_rc"
    echo "OMNIGRIL_EXIT_CODE=$test2_rc"
    git checkout eb2dbf6dfa94282185a2ac4ddd42633fe9b5c60c \
        "pkg/kv/kvserver/logstore/sideload_test.go" \
        "pkg/kv/kvserver/replica_raftlog_test.go" \
        "pkg/server/api_v2_databases_metadata_test.go"
    exit $test2_rc
fi

# Test 3: server_test (enormous size, 16 shards)
echo "Running server_test..."
bazel test //pkg/server:server_test --test_output=errors
test3_rc=$?

if [ $test3_rc -ne 0 ]; then
    echo "server_test failed with exit code $test3_rc"
    echo "OMNIGRIL_EXIT_CODE=$test3_rc"
    git checkout eb2dbf6dfa94282185a2ac4ddd42633fe9b5c60c \
        "pkg/kv/kvserver/logstore/sideload_test.go" \
        "pkg/kv/kvserver/replica_raftlog_test.go" \
        "pkg/server/api_v2_databases_metadata_test.go"
    exit $test3_rc
fi

# All tests passed
rc=0
echo "All tests passed successfully"
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout eb2dbf6dfa94282185a2ac4ddd42633fe9b5c60c \
    "pkg/kv/kvserver/logstore/sideload_test.go" \
    "pkg/kv/kvserver/replica_raftlog_test.go" \
    "pkg/server/api_v2_databases_metadata_test.go"

exit $rc