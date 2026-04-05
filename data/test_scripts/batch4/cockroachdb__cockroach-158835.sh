#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 0af99ab6796187d567dc32ce64e25431cf9a88f5 "pkg/sql/opt/exec/execbuilder/testdata/system" "pkg/sql/stats/create_stats_job_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/sql/opt/exec/execbuilder/testdata/system b/pkg/sql/opt/exec/execbuilder/testdata/system
--- a/pkg/sql/opt/exec/execbuilder/testdata/system
+++ b/pkg/sql/opt/exec/execbuilder/testdata/system
@@ -153,3 +153,24 @@ scan statement_hints@hash_idx
  ├── key: ()
  ├── fd: ()-->(2)
  └── distribution: test
+
+# Query used to enforce the global concurrency limit of auto full stats
+# collections.
+query T
+EXPLAIN
+SELECT array_cat_agg(job_ids)
+FROM system.table_statistics_locks
+WHERE table_id = 0
+AND kind = 1
+FOR UPDATE OF table_statistics_locks
+----
+distribution: local
+vectorized: true
+·
+• group (scalar)
+│
+└── • scan
+      missing stats
+      table: table_statistics_locks@primary
+      spans: [/0/1 - /0/1]
+      locking strength: for update
diff --git a/pkg/sql/stats/create_stats_job_test.go b/pkg/sql/stats/create_stats_job_test.go
--- a/pkg/sql/stats/create_stats_job_test.go
+++ b/pkg/sql/stats/create_stats_job_test.go
@@ -33,7 +33,6 @@ import (
 	"github.com/cockroachdb/cockroach/pkg/util/leaktest"
 	"github.com/cockroachdb/cockroach/pkg/util/log"
 	"github.com/cockroachdb/cockroach/pkg/util/randutil"
-	"github.com/cockroachdb/cockroach/pkg/util/retry"
 	"github.com/cockroachdb/errors"
 	"github.com/stretchr/testify/require"
 )
@@ -218,17 +217,17 @@ func TestCreateStatisticsCanBeCancelled(t *testing.T) {
 }
 
 // TestAtMostOneRunningCreateStats tests that auto stat jobs (full or partial)
-// don't run when a full stats job is running. It also tests that manual stat
-// jobs (full or partial) are always allowed to run.
+// don't run when an auto full stats job is running. It also tests that manual
+// stat jobs (full or partial) are always allowed to run.
 func TestAtMostOneRunningCreateStats(t *testing.T) {
-	testAtMostOneRunningCreateStatsImpl(t, true /* errorOnConcurrentCreateStats */)
+	testAtMostOneRunningCreateStatsImpl(t, false /* shouldError */)
 }
 
 func TestAtMostOneRunningCreateStatsWithErrorOnConcurrentCreateStats(t *testing.T) {
-	testAtMostOneRunningCreateStatsImpl(t, false /* errorOnConcurrentCreateStats */)
+	testAtMostOneRunningCreateStatsImpl(t, true /* shouldError */)
 }
 
-func testAtMostOneRunningCreateStatsImpl(t *testing.T, errorOnConcurrentCreateStats bool) {
+func testAtMostOneRunningCreateStatsImpl(t *testing.T, shouldError bool) {
 	defer leaktest.AfterTest(t)()
 	defer log.Scope(t).Close(t)
 
@@ -257,64 +256,56 @@ func testAtMostOneRunningCreateStatsImpl(t *testing.T, errorOnConcurrentCreateSt
 	conn := tc.ApplicationLayer(0).SQLConn(t)
 	sqlDB := sqlutils.MakeSQLRunner(conn)
 
-	sqlDB.Exec(t, fmt.Sprintf("SET CLUSTER SETTING sql.stats.error_on_concurrent_create_stats.enabled = %t", errorOnConcurrentCreateStats))
+	// Disable automatic cleanup of completed jobs since we might block on a job
+	// until it succeeds.
+	sqlDB.Exec(t, `SET CLUSTER SETTING sql.stats.automatic_stats_job_auto_cleanup.enabled = false`)
+	sqlDB.Exec(t, fmt.Sprintf("SET CLUSTER SETTING sql.stats.error_on_concurrent_create_stats.enabled = %t", shouldError))
 	sqlDB.Exec(t, `CREATE DATABASE d`)
 	sqlDB.Exec(t, `CREATE TABLE d.t (x INT PRIMARY KEY)`)
+	sqlDB.Exec(t, `CREATE TABLE d.t2 (x INT PRIMARY KEY)`)
 	sqlDB.Exec(t, `INSERT INTO d.t SELECT generate_series(1,1000)`)
+	sqlDB.Exec(t, `INSERT INTO d.t2 SELECT generate_series(1,1000)`)
+
+	// Collect full stats so that future partial stats can be collected.
+	sqlDB.Exec(t, `ANALYZE d.t`)
+
+	// Block the next stats collection on the table.
 	var tID descpb.ID
 	sqlDB.QueryRow(t, `SELECT 'd.t'::regclass::int`).Scan(&tID)
 	setTableID(tID)
 
-	// Start a full stat run and let it complete so that future partial stats can
-	// be collected
-	allowRequest = make(chan struct{})
-	allowRequestOpen = true
-	initialFullStatErrCh := make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS full_statistic FROM d.t`)
-		initialFullStatErrCh <- err
-	}()
-	close(allowRequest)
-	allowRequestOpen = false
-	if err := <-initialFullStatErrCh; err != nil {
-		t.Fatalf("create stats job should have completed: %s", err)
-	}
-
-	// Start a manual full stat run and wait until it's done one scan. This will
+	// Start an auto full stat job and wait until it's done one scan. This will
 	// be the stat job that runs in the background as we test the behavior of new
 	// stat jobs.
 	allowRequest = make(chan struct{})
 	allowRequestOpen = true
-	runningManualFullStatErrCh := make(chan error)
+	backgroundAutoFullStatErrCh := make(chan error)
 	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS s1 FROM d.t`)
-		runningManualFullStatErrCh <- err
+		_, err := conn.Exec(`CREATE STATISTICS __auto__ FROM d.t`)
+		backgroundAutoFullStatErrCh <- err
 	}()
 	select {
 	case allowRequest <- struct{}{}:
-	case err := <-runningManualFullStatErrCh:
+	case err := <-backgroundAutoFullStatErrCh:
 		t.Fatal(err)
 	}
 
-	// Don't block on autostats jobs.
+	// Don't block the other stats jobs.
 	setTableID(descpb.InvalidID)
 
 	// Attempt to start automatic full and partial stats runs.
-	runAutoStatsJob(t, sqlDB, "d.t", false /* partial */, errorOnConcurrentCreateStats)
-	runAutoStatsJob(t, sqlDB, "d.t", true /* partial */, errorOnConcurrentCreateStats)
+	runAutoStatsJob(t, sqlDB, "d.t", false /* partial */, shouldError, false /* shouldSucceed */)
+	runAutoStatsJob(t, sqlDB, "d.t", true /* partial */, shouldError, false /* shouldSucceed */)
 
-	jobID := getLastRunningCreateStatsJobID(t, sqlDB)
+	var jobID jobspb.JobID
+	sqlDB.QueryRow(t, "SELECT id FROM system.jobs WHERE status = 'running' AND "+
+		"job_type = 'AUTO CREATE STATS' ORDER BY created DESC LIMIT 1").Scan(&jobID)
 	pauseJob := rng.Float64() < 0.5
 	if pauseJob {
 		// PAUSE JOB does not block until the job is paused but only requests it.
 		// Wait until the job is set to paused.
-		opts := retry.Options{
-			InitialBackoff: 1 * time.Millisecond,
-			MaxBackoff:     time.Second,
-			Multiplier:     2,
-		}
-		if err := retry.WithMaxAttempts(context.Background(), opts, 10, func() error {
-			_, err := sqlDB.DB.ExecContext(context.Background(), `PAUSE JOB $1`, jobID)
+		testutils.SucceedsSoon(t, func() error {
+			_, err := sqlDB.DB.ExecContext(ctx, `PAUSE JOB $1`, jobID)
 			if err != nil {
 				t.Fatal(err)
 			}
@@ -323,57 +314,53 @@ func testAtMostOneRunningCreateStatsImpl(t *testing.T, errorOnConcurrentCreateSt
 			if status != "paused" {
 				return errors.New("could not pause job")
 			}
-			return err
-		}); err != nil {
-			t.Fatal(err)
-		}
+			return nil
+		})
 	}
 
 	// Starting automatic full and partial stats run should still fail.
-	runAutoStatsJob(t, sqlDB, "d.t", false /* partial */, errorOnConcurrentCreateStats)
-	runAutoStatsJob(t, sqlDB, "d.t", true /* partial */, errorOnConcurrentCreateStats)
+	runAutoStatsJob(t, sqlDB, "d.t", false /* partial */, shouldError, false /* shouldSucceed */)
+	runAutoStatsJob(t, sqlDB, "d.t", true /* partial */, shouldError, false /* shouldSucceed */)
 
 	// Attempt to start manual full and partial stat runs. Both should succeed.
-	manualFullStatErrCh := make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS s2 FROM d.t`)
-		manualFullStatErrCh <- err
-	}()
-	manualPartialStatErrCh := make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS ps1 FROM d.t USING EXTREMES`)
-		manualPartialStatErrCh <- err
-	}()
+	_, err := conn.Exec(`CREATE STATISTICS s1 FROM d.t`)
+	require.NoError(t, err)
+	_, err = conn.Exec(`CREATE STATISTICS ps1 FROM d.t USING EXTREMES`)
+	require.NoError(t, err)
 
-	// Verify that the manual full and partial stat jobs completed successfully.
-	if err := <-manualFullStatErrCh; err != nil {
-		t.Fatalf("create stats job should have completed: %s", err)
-	}
-	if err := <-manualPartialStatErrCh; err != nil {
-		t.Fatalf("create partial stats job should have completed: %s", err)
-	}
+	// Starting auto full on a different table should still fail.
+	runAutoStatsJob(t, sqlDB, "d.t2", false /* partial */, shouldError, false /* shouldSucceed */)
 
-	beforeCount := getNumberOfTableStats(t, sqlDB, "d.t", "s1")
-	sqlDB.Exec(t, fmt.Sprintf("RESUME JOB %d", jobID))
+	// Increase the global concurrency limit and ensure that the auto full
+	// collection on a different table succeeds while it still fails on the same
+	// table.
+	sqlDB.Exec(t, `SET CLUSTER SETTING sql.stats.automatic_full_concurrency_limit = 2`)
+	runAutoStatsJob(t, sqlDB, "d.t", false /* partial */, shouldError, false /* shouldSucceed */)
+	runAutoStatsJob(t, sqlDB, "d.t2", false /* partial */, false /* shouldError */, true /* shouldSucceed */)
+
+	beforeCount := getNumberOfTableStats(t, sqlDB, "d.t", "__auto__")
+	if pauseJob {
+		sqlDB.Exec(t, fmt.Sprintf("RESUME JOB %d", jobID))
+	}
 	close(allowRequest)
 	allowRequestOpen = false
 
-	// Verify that the running full stat job completed successfully.
+	// Verify that the background auto full stat job completed successfully.
 	jobutils.WaitForJobToSucceed(t, sqlDB, jobID)
 	if pauseJob {
 		// If the job was paused, then we expect an error to be returned to us
 		// even though the stats were collected.
-		if err := <-runningManualFullStatErrCh; !testutils.IsError(err, "node liveness error: restarting in background") {
+		if err := <-backgroundAutoFullStatErrCh; !testutils.IsError(err, "node liveness error: restarting in background") {
 			t.Fatalf("expected 'node liveness error: restarting in background' error, found %v", err)
 		}
 	} else {
 		// If the job wasn't paused, then we expect no error.
-		if err := <-runningManualFullStatErrCh; err != nil {
+		if err := <-backgroundAutoFullStatErrCh; err != nil {
 			t.Fatalf("expected no error, found %v", err)
 		}
 	}
 	// Now ensure that the new statistic is present.
-	afterCount := getNumberOfTableStats(t, sqlDB, "d.t", "s1")
+	afterCount := getNumberOfTableStats(t, sqlDB, "d.t", "__auto__")
 	if beforeCount == afterCount {
 		t.Fatal("expected new statistic to have been collected")
 	}
@@ -383,14 +370,14 @@ func testAtMostOneRunningCreateStatsImpl(t *testing.T, errorOnConcurrentCreateSt
 // doesn't prevent any new full or partial stat jobs from running, except for
 // auto partial stat jobs on the same table.
 func TestBackgroundAutoPartialStats(t *testing.T) {
-	testBackgroundAutoPartialStatsImpl(t, true /* errorOnConcurrentCreateStats */)
+	testBackgroundAutoPartialStatsImpl(t, false /* shouldError */)
 }
 
 func TestBackgroundAutoPartialStatsWithErrorOnConcurrentCreateStats(t *testing.T) {
-	testBackgroundAutoPartialStatsImpl(t, false /* errorOnConcurrentCreateStats */)
+	testBackgroundAutoPartialStatsImpl(t, true /* shouldError */)
 }
 
-func testBackgroundAutoPartialStatsImpl(t *testing.T, errorOnConcurrentCreateStats bool) {
+func testBackgroundAutoPartialStatsImpl(t *testing.T, shouldError bool) {
 	defer leaktest.AfterTest(t)()
 	defer log.Scope(t).Close(t)
 
@@ -418,111 +405,60 @@ func testBackgroundAutoPartialStatsImpl(t *testing.T, errorOnConcurrentCreateSta
 	conn := tc.ApplicationLayer(0).SQLConn(t)
 	sqlDB := sqlutils.MakeSQLRunner(conn)
 
-	sqlDB.Exec(t, fmt.Sprintf("SET CLUSTER SETTING sql.stats.error_on_concurrent_create_stats.enabled = %t", errorOnConcurrentCreateStats))
+	sqlDB.Exec(t, fmt.Sprintf("SET CLUSTER SETTING sql.stats.error_on_concurrent_create_stats.enabled = %t", shouldError))
 	sqlDB.Exec(t, `CREATE DATABASE d`)
 	sqlDB.Exec(t, `CREATE TABLE d.t1 (x INT PRIMARY KEY)`)
 	sqlDB.Exec(t, `CREATE TABLE d.t2 (x INT PRIMARY KEY)`)
 	sqlDB.Exec(t, `INSERT INTO d.t1 SELECT generate_series(1,1000)`)
 	sqlDB.Exec(t, `INSERT INTO d.t2 SELECT generate_series(1,1000)`)
-	var t1ID descpb.ID
-	sqlDB.QueryRow(t, `SELECT 'd.t1'::regclass::int`).Scan(&t1ID)
-	setTableID(t1ID)
-
 	// Collect full stats on both tables so that future partial stats can be
-	// collected
-	allowRequest = make(chan struct{})
-	close(allowRequest)
-	if _, err := conn.Exec(`CREATE STATISTICS full_statistic FROM d.t1`); err != nil {
-		t.Fatalf("create stats job should have completed: %s", err)
-	}
-	if _, err := conn.Exec(`CREATE STATISTICS full_statistic FROM d.t2`); err != nil {
-		t.Fatalf("create stats job should have completed: %s", err)
-	}
+	// collected.
+	sqlDB.Exec(t, `ANALYZE d.t1`)
+	sqlDB.Exec(t, `ANALYZE d.t2`)
+
+	// Block the next stats collection on the table.
+	var tID descpb.ID
+	sqlDB.QueryRow(t, `SELECT 'd.t1'::regclass::int`).Scan(&tID)
+	setTableID(tID)
 
 	// Start an auto partial stat run on t1 and wait until it's done one scan.
 	// This will be the stat job that runs in the background as we test the
 	// behavior of new stat jobs.
 	allowRequest = make(chan struct{})
 	allowRequestOpen = true
-	runningAutoPartialStatErrCh := make(chan error)
+	backgroundAutoPartialStatErrCh := make(chan error)
 	go func() {
 		_, err := conn.Exec(`CREATE STATISTICS __auto_partial__ FROM d.t1 USING EXTREMES`)
-		runningAutoPartialStatErrCh <- err
+		backgroundAutoPartialStatErrCh <- err
 	}()
 	select {
 	case allowRequest <- struct{}{}:
-	case err := <-runningAutoPartialStatErrCh:
-		t.Fatal(err)
-	}
-
-	// Attempt to start a simultaneous auto full stat run. It should succeed.
-	autoFullStatErrCh := make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS __auto__ FROM d.t1`)
-		autoFullStatErrCh <- err
-	}()
-
-	select {
-	case allowRequest <- struct{}{}:
-	case err := <-runningAutoPartialStatErrCh:
-		t.Fatal(err)
-	case err := <-autoFullStatErrCh:
+	case err := <-backgroundAutoPartialStatErrCh:
 		t.Fatal(err)
 	}
 
-	// Allow both auto stat jobs to complete.
-	close(allowRequest)
-	allowRequestOpen = false
-
-	// Verify that both jobs completed successfully.
-	if err := <-autoFullStatErrCh; err != nil {
-		t.Fatalf("create auto full stats job should have completed: %s", err)
-	}
-	if err := <-runningAutoPartialStatErrCh; err != nil {
-		t.Fatalf("create auto partial stats job should have completed: %s", err)
-	}
+	// Don't block the other stats jobs.
+	setTableID(descpb.InvalidID)
 
-	// Start another auto partial stat run and wait until it's done one scan.
-	allowRequest = make(chan struct{})
-	allowRequestOpen = true
-	runningAutoPartialStatErrCh = make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS __auto_partial__ FROM d.t1 USING EXTREMES`)
-		runningAutoPartialStatErrCh <- err
-	}()
-	select {
-	case allowRequest <- struct{}{}:
-	case err := <-runningAutoPartialStatErrCh:
-		t.Fatal(err)
-	}
+	// Attempt to start a simultaneous auto full stat run. It should succeed.
+	runAutoStatsJob(t, sqlDB, "d.t1", false /* partial */, false /* shouldError */, true /* shouldSucceed */)
 
 	// Attempt to start a simultaneous auto partial stat run on the same table.
-	runAutoStatsJob(t, sqlDB, "d.t1", true /* partial */, errorOnConcurrentCreateStats)
+	runAutoStatsJob(t, sqlDB, "d.t1", true /* partial */, shouldError, false /* shouldSucceed */)
 
-	// Attempt to start a simultaneous auto partial stat run on a different table.
-	// It should succeed.
-	autoPartialStatErrCh := make(chan error)
-	go func() {
-		_, err := conn.Exec(`CREATE STATISTICS __auto_partial__ FROM d.t2 USING EXTREMES`)
-		autoPartialStatErrCh <- err
-	}()
+	// Start a simultaneous auto partial stat run on a different table. It
+	// should succeed.
+	runAutoStatsJob(t, sqlDB, "d.t2", true /* partial */, false /* shouldError */, true /* shouldSucceed */)
 
-	select {
-	case allowRequest <- struct{}{}:
-	case err := <-runningAutoPartialStatErrCh:
-		t.Fatal(err)
-	case err := <-autoPartialStatErrCh:
-		t.Fatal(err)
-	}
+	// Reduce the global concurrency limit and try collecting auto partial stats
+	// on a different table - it should fail now.
+	sqlDB.Exec(t, `SET CLUSTER SETTING sql.stats.automatic_extremes_concurrency_limit = 1`)
+	runAutoStatsJob(t, sqlDB, "d.t2", true /* partial */, shouldError, false /* shouldSucceed */)
 
+	// Unblock the background job and verify that it completed successfully.
 	close(allowRequest)
 	allowRequestOpen = false
-
-	// Verify that both jobs completed successfully.
-	if err := <-autoPartialStatErrCh; err != nil {
-		t.Fatalf("create auto partial stats job should have completed: %s", err)
-	}
-	if err := <-runningAutoPartialStatErrCh; err != nil {
+	if err := <-backgroundAutoPartialStatErrCh; err != nil {
 		t.Fatalf("create auto partial stats job should have completed: %s", err)
 	}
 }
@@ -972,8 +908,18 @@ func getNumberOfTableStats(
 	return count
 }
 
+// runAutoStatsJob simulates running an auto stats job on the given table.
+// - shouldError indicates whether we expect an error to be returned in case of
+// a failure (if false, we silently ignore the failure).
+// - shouldSucceed indicates whether the auto stats job should succeed and write
+// a new statistics.
 func runAutoStatsJob(
-	t *testing.T, sqlDB *sqlutils.SQLRunner, tableName string, partial bool, shouldFail bool,
+	t *testing.T,
+	sqlDB *sqlutils.SQLRunner,
+	tableName string,
+	partial bool,
+	shouldError bool,
+	shouldSucceed bool,
 ) {
 	var statsName string
 	if partial {
@@ -989,14 +935,20 @@ func runAutoStatsJob(
 	query := fmt.Sprintf("CREATE STATISTICS %s FROM %s%s", statsName, tableName, queryPostfix)
 	beforeCount := getNumberOfTableStats(t, sqlDB, tableName, statsName)
 
-	if shouldFail {
+	if shouldError {
 		sqlDB.ExpectErr(t, "another CREATE STATISTICS job is already running", query)
 		return
 	}
 
 	sqlDB.Exec(t, query)
 	afterCount := getNumberOfTableStats(t, sqlDB, tableName, statsName)
-	if beforeCount != afterCount {
-		t.Fatalf("auto stats job should have failed, but it didn't (beforeCount: %d, afterCount: %d)", beforeCount, afterCount)
+	if shouldSucceed {
+		if beforeCount+1 != afterCount {
+			t.Fatalf("auto stats job should have succeded, but it didn't (beforeCount: %d, afterCount: %d)", beforeCount, afterCount)
+		}
+	} else {
+		if beforeCount != afterCount {
+			t.Fatalf("auto stats job should have failed, but it didn't (beforeCount: %d, afterCount: %d)", beforeCount, afterCount)
+		}
 	}
 }
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go
export BAZEL_REMOTE_CACHE_ENABLED=false
export GOTRACEBACK=all

# Run both test targets in a single Bazel command
# The execbuilder test will automatically process the testdata/system file
# The stats test will run the Go unit tests
bazel test \
    //pkg/sql/opt/exec/execbuilder:execbuilder_test \
    //pkg/sql/stats:stats_test \
    --test_output=all \
    --config=test \
    --test_timeout=600

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 0af99ab6796187d567dc32ce64e25431cf9a88f5 "pkg/sql/opt/exec/execbuilder/testdata/system" "pkg/sql/stats/create_stats_job_test.go"