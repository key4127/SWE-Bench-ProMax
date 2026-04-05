#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout d488dc56e50ee761c94acecf58940a65d34294af \
    "pkg/cmd/roachtest/tests/cancel.go" \
    "pkg/cmd/roachtest/tests/multitenant_tpch.go" \
    "pkg/cmd/roachtest/tests/schemachange.go" \
    "pkg/cmd/roachtest/tests/sqlsmith.go" \
    "pkg/cmd/roachtest/tests/tpc_utils.go" \
    "pkg/cmd/roachtest/tests/tpcdsvec.go" \
    "pkg/cmd/roachtest/tests/tpch_concurrency.go" \
    "pkg/cmd/roachtest/tests/tpchbench.go" \
    "pkg/cmd/roachtest/tests/tpchvec.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/roachtest/tests/cancel.go b/pkg/cmd/roachtest/tests/cancel.go
--- a/pkg/cmd/roachtest/tests/cancel.go
+++ b/pkg/cmd/roachtest/tests/cancel.go
@@ -49,9 +49,10 @@ func registerCancel(r registry.Registry) {
 			conn := c.Conn(ctx, t.L(), 1)
 			defer conn.Close()
 
-			t.Status("restoring TPCH dataset for Scale Factor 1")
-			if err := loadTPCHDataset(
-				ctx, t, c, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx), c.All(), false, /* disableMergeQueue */
+			t.Status("importing TPCH dataset for Scale Factor 1")
+			if err := importTPCHDataset(
+				ctx, t, c, "" /* virtualClusterName */, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx),
+				c.All(), false /* disableMergeQueue */, true, /* smallRanges */
 			); err != nil {
 				t.Fatal(err)
 			}
@@ -185,7 +186,6 @@ func registerCancel(r registry.Registry) {
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
 		Leases:           registry.MetamorphicLeases,
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runCancel(ctx, t, c, tpchQueriesToRun, true /* useDistsql */)
 		},
@@ -200,7 +200,6 @@ func registerCancel(r registry.Registry) {
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
 		Leases:           registry.MetamorphicLeases,
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runCancel(ctx, t, c, tpchQueriesToRun, false /* useDistsql */)
 		},
diff --git a/pkg/cmd/roachtest/tests/multitenant_tpch.go b/pkg/cmd/roachtest/tests/multitenant_tpch.go
--- a/pkg/cmd/roachtest/tests/multitenant_tpch.go
+++ b/pkg/cmd/roachtest/tests/multitenant_tpch.go
@@ -46,9 +46,10 @@ func runMultiTenantTPCH(
 		if _, err := conn.Exec(setting); err != nil {
 			t.Fatal(err)
 		}
-		t.Status("restoring TPCH dataset for Scale Factor 1 in ", setupNames[setupIdx])
-		if err := loadTPCHDataset(
-			ctx, t, c, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx), c.All(), false, /* disableMergeQueue */
+		t.Status("importing TPCH dataset for Scale Factor 1 in ", setupNames[setupIdx])
+		if err := importTPCHDataset(
+			ctx, t, c, virtualClusterName, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx),
+			c.All(), false /* disableMergeQueue */, true, /* smallRanges */
 		); err != nil {
 			t.Fatal(err)
 		}
@@ -155,7 +156,6 @@ func registerMultiTenantTPCH(r registry.Registry) {
 				CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 				Suites:           registry.Suites(registry.Nightly),
 				Leases:           registry.MetamorphicLeases,
-				Skip:             "153489. uses ancient tpch fixture",
 				Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 					runMultiTenantTPCH(ctx, t, c, enableDirectScans, sharedProcess)
 				},
diff --git a/pkg/cmd/roachtest/tests/schemachange.go b/pkg/cmd/roachtest/tests/schemachange.go
--- a/pkg/cmd/roachtest/tests/schemachange.go
+++ b/pkg/cmd/roachtest/tests/schemachange.go
@@ -35,22 +35,16 @@ func registerSchemaChangeDuringKV(r registry.Registry) {
 		Suites:           registry.Suites(registry.Nightly),
 		Leases:           registry.MetamorphicLeases,
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
-			const fixturePath = `gs://cockroach-fixtures-us-east1/workload/tpch/scalefactor=10?AUTH=implicit`
-
 			c.Start(ctx, t.L(), option.DefaultStartOpts(), install.MakeClusterSettings(), c.All())
 			db := c.Conn(ctx, t.L(), 1)
 			defer db.Close()
 
-			m := c.NewDeprecatedMonitor(ctx, c.All())
-			m.Go(func(ctx context.Context) error {
-				t.Status("loading fixture")
-				if _, err := db.Exec(
-					`RESTORE DATABASE tpch FROM 'backup' IN $1 WITH unsafe_restore_incompatible_version`, fixturePath); err != nil {
-					t.Fatal(err)
-				}
-				return nil
-			})
-			m.Wait()
+			if err := importTPCHDataset(
+				ctx, t, c, "" /* virtualClusterName */, db, 10 /* sf */, c.NewDeprecatedMonitor(ctx),
+				c.All(), false /* disableMergeQueue */, false, /* smallRanges */
+			); err != nil {
+				t.Fatal(err)
+			}
 
 			c.Run(ctx, option.WithNodes(c.Node(1)), `./cockroach workload init kv --drop --db=test {pgurl:1}`)
 			for node := 1; node <= c.Spec().NodeCount; node++ {
@@ -61,7 +55,7 @@ func registerSchemaChangeDuringKV(r registry.Registry) {
 				}, task.Name(fmt.Sprintf(`kv-%d`, node)))
 			}
 
-			m = c.NewDeprecatedMonitor(ctx, c.All())
+			m := c.NewDeprecatedMonitor(ctx, c.All())
 			m.Go(func(ctx context.Context) error {
 				t.Status("running schema change tests")
 				return waitForSchemaChanges(ctx, t.L(), db)
diff --git a/pkg/cmd/roachtest/tests/sqlsmith.go b/pkg/cmd/roachtest/tests/sqlsmith.go
--- a/pkg/cmd/roachtest/tests/sqlsmith.go
+++ b/pkg/cmd/roachtest/tests/sqlsmith.go
@@ -29,43 +29,21 @@ import (
 
 func registerSQLSmith(r registry.Registry) {
 	const numNodes = 4
-	const tpchName = "tpch-sf1"
-	const tpccName = "tpcc"
 	setups := map[string]sqlsmith.Setup{
 		"empty":                     sqlsmith.Setups["empty"],
 		"seed":                      sqlsmith.Setups["seed"],
 		sqlsmith.RandTableSetupName: sqlsmith.Setups[sqlsmith.RandTableSetupName],
-		tpchName: func(r *rand.Rand) []string {
+		"tpch-sf1": func(r *rand.Rand) []string {
 			return []string{`
-RESTORE TABLE tpch.* FROM '/' IN 'gs://cockroach-fixtures-us-east1/workload/tpch/scalefactor=1/backup?AUTH=implicit'
-WITH into_db = 'defaultdb', unsafe_restore_incompatible_version;
+RESTORE TABLE tpch.* FROM LATEST IN 'gs://cockroach-fixtures-us-east1/workload/tpch/scalefactor=1/backup_25_3?AUTH=implicit'
+WITH into_db = 'defaultdb';
 `}
 		},
-		tpccName: func(r *rand.Rand) []string {
-			const version = "version=2.1.0,fks=true,interleaved=false,seed=1,warehouses=1"
-			var stmts []string
-			for _, t := range []string{
-				"customer",
-				"district",
-				"history",
-				"item",
-				"new_order",
-				"order",
-				"order_line",
-				"stock",
-				"warehouse",
-			} {
-				stmts = append(
-					stmts,
-					fmt.Sprintf(`
-RESTORE TABLE tpcc.%s FROM '/' IN 'gs://cockroach-fixtures-us-east1/workload/tpcc/%[2]s/%[1]s?AUTH=implicit'
-WITH into_db = 'defaultdb', unsafe_restore_incompatible_version;
-`,
-						t, version,
-					),
-				)
-			}
-			return stmts
+		"tpcc": func(r *rand.Rand) []string {
+			return []string{`
+RESTORE TABLE tpcc.* FROM LATEST IN 'gs://cockroach-fixtures-us-east1/workload/tpcc/version=25.3,fks=true,seed=1,warehouses=1?AUTH=implicit'
+WITH into_db = 'defaultdb';
+`}
 		},
 	}
 	settings := map[string]sqlsmith.SettingFunc{
@@ -312,11 +290,6 @@ WITH into_db = 'defaultdb', unsafe_restore_incompatible_version;
 	}
 
 	register := func(setup, setting string) {
-		var skip string
-		switch setup {
-		case tpchName, tpccName:
-			skip = "153489. uses ancient fixture"
-		}
 		var clusterSpec spec.ClusterSpec
 		if strings.Contains(setting, "multi-region") {
 			clusterSpec = r.MakeClusterSpec(numNodes, spec.Geo())
@@ -335,7 +308,6 @@ WITH into_db = 'defaultdb', unsafe_restore_incompatible_version;
 			Leases:           registry.MetamorphicLeases,
 			NativeLibs:       registry.LibGEOS,
 			Timeout:          time.Minute * 20,
-			Skip:             skip,
 			// NB: sqlsmith failures should never block a release.
 			NonReleaseBlocker: true,
 			Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
diff --git a/pkg/cmd/roachtest/tests/tpc_utils.go b/pkg/cmd/roachtest/tests/tpc_utils.go
--- a/pkg/cmd/roachtest/tests/tpc_utils.go
+++ b/pkg/cmd/roachtest/tests/tpc_utils.go
@@ -19,23 +19,30 @@ import (
 	"github.com/lib/pq"
 )
 
-// loadTPCHDataset loads a TPC-H dataset for the specific benchmark spec on the
-// provided roachNodes. The function is idempotent and first checks whether a
-// compatible dataset exists (compatible is defined as a tpch dataset with a
-// scale factor at least as large as the provided scale factor), performing an
-// expensive dataset restore only if it doesn't.
+// importTPCHDataset imports a TPC-H dataset for the specific scale factor. The
+// function is idempotent and first checks whether a compatible dataset exists
+// (compatible is defined as a tpch dataset with a scale factor at least as
+// large as the provided scale factor), performing an expensive dataset IMPORT
+// only if it doesn't.
 //
 // The function disables auto stats collection and ensures that table statistics
 // are present for all TPCH tables.
-func loadTPCHDataset(
+//
+// - virtualClusterName, if set, is the name of the target secondary tenant to
+// import into.
+// - smallRanges, if true, will change the zone config to reduce range sizes to
+// be in [16MiB, 64MiB] interval.
+func importTPCHDataset(
 	ctx context.Context,
 	t test.Test,
 	c cluster.Cluster,
+	virtualClusterName string,
 	db *gosql.DB,
 	sf int,
 	m cluster.Monitor,
 	roachNodes option.NodeListOption,
 	disableMergeQueue bool,
+	smallRanges bool,
 ) (retErr error) {
 	_, err := db.Exec("SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;")
 	if err != nil {
@@ -91,20 +98,21 @@ func loadTPCHDataset(
 		return err
 	}
 
-	t.L().Printf("restoring tpch scale factor %d\n", sf)
-	// Lower the target size for the restore spans so that we get more ranges.
-	// This is useful to exercise the parallelism across ranges within a single
-	// query.
-	if _, err := db.ExecContext(ctx, "SET CLUSTER SETTING backup.restore_span.target_size = '64MiB';"); err != nil {
-		return err
+	if smallRanges {
+		// Reduce the range size so that we get more ranges. This is useful to
+		// exercise the parallelism across ranges within a single query.
+		if _, err := db.ExecContext(ctx, "ALTER RANGE default CONFIGURE ZONE USING range_min_bytes = 16777216, range_max_bytes = 67108864;"); err != nil {
+			return err
+		}
 	}
-	tpchURL := fmt.Sprintf("gs://cockroach-fixtures-us-east1/workload/tpch/scalefactor=%d/backup?AUTH=implicit", sf)
-	if _, err := db.ExecContext(ctx, `CREATE DATABASE IF NOT EXISTS tpch;`); err != nil {
-		return err
+	t.L().Printf("importing tpch scale factor %d\n", sf)
+	node := roachNodes.RandNode()
+	var tenantSuffix string
+	if virtualClusterName != "" {
+		tenantSuffix = fmt.Sprintf(":%s", virtualClusterName)
 	}
-	query := fmt.Sprintf(`RESTORE tpch.* FROM '/' IN '%s' WITH into_db = 'tpch', unsafe_restore_incompatible_version;`, tpchURL)
-	_, err = db.ExecContext(ctx, query)
-	return err
+	cmd := fmt.Sprintf("./cockroach workload fixtures import tpch --scale-factor=%d --checks=false {pgurl%s%s}", sf, node, tenantSuffix)
+	return c.RunE(ctx, option.WithNodes(node), cmd)
 }
 
 // scatterTables runs "ALTER TABLE ... SCATTER" statement for every table in
diff --git a/pkg/cmd/roachtest/tests/tpcdsvec.go b/pkg/cmd/roachtest/tests/tpcdsvec.go
--- a/pkg/cmd/roachtest/tests/tpcdsvec.go
+++ b/pkg/cmd/roachtest/tests/tpcdsvec.go
@@ -67,10 +67,7 @@ func registerTPCDSVec(r registry.Registry) {
 		}
 		t.Status("restoring TPCDS dataset for Scale Factor 1")
 		if _, err := clusterConn.Exec(
-			`
-RESTORE DATABASE tpcds FROM '/' IN 'gs://cockroach-fixtures-us-east1/workload/tpcds/scalefactor=1/backup?AUTH=implicit'
-WITH unsafe_restore_incompatible_version;
-`,
+			`RESTORE DATABASE tpcds FROM LATEST IN 'gs://cockroach-fixtures-us-east1/workload/tpcds/scalefactor=1/backup_25_3?AUTH=implicit';`,
 		); err != nil {
 			t.Fatal(err)
 		}
@@ -190,7 +187,6 @@ WITH unsafe_restore_incompatible_version;
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCDSVec(ctx, t, c)
 		},
diff --git a/pkg/cmd/roachtest/tests/tpch_concurrency.go b/pkg/cmd/roachtest/tests/tpch_concurrency.go
--- a/pkg/cmd/roachtest/tests/tpch_concurrency.go
+++ b/pkg/cmd/roachtest/tests/tpch_concurrency.go
@@ -39,9 +39,9 @@ func registerTPCHConcurrency(r registry.Registry) {
 			}
 		}
 
-		if err := loadTPCHDataset(
-			ctx, t, c, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx, c.CRDBNodes()),
-			c.CRDBNodes(), true, /* disableMergeQueue */
+		if err := importTPCHDataset(
+			ctx, t, c, "" /* virtualClusterName */, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx, c.CRDBNodes()),
+			c.CRDBNodes(), true /* disableMergeQueue */, true, /* smallRanges */
 		); err != nil {
 			t.Fatal(err)
 		}
@@ -208,7 +208,6 @@ func registerTPCHConcurrency(r registry.Registry) {
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
 		CockroachBinary:  cockroachBinary,
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHConcurrency(ctx, t, c, false /* disableStreamer */)
 		},
@@ -224,7 +223,6 @@ func registerTPCHConcurrency(r registry.Registry) {
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
 		CockroachBinary:  cockroachBinary,
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHConcurrency(ctx, t, c, true /* disableStreamer */)
 		},
diff --git a/pkg/cmd/roachtest/tests/tpchbench.go b/pkg/cmd/roachtest/tests/tpchbench.go
--- a/pkg/cmd/roachtest/tests/tpchbench.go
+++ b/pkg/cmd/roachtest/tests/tpchbench.go
@@ -60,8 +60,9 @@ func runTPCHBench(ctx context.Context, t test.Test, c cluster.Cluster, b tpchBen
 		defer conn.Close()
 
 		t.Status("setting up dataset")
-		err := loadTPCHDataset(
-			ctx, t, c, conn, b.ScaleFactor, m, c.CRDBNodes(), true, /* disableMergeQueue */
+		err := importTPCHDataset(
+			ctx, t, c, "" /* virtualClusterName */, conn, b.ScaleFactor, m,
+			c.CRDBNodes(), true /* disableMergeQueue */, true, /* smallRanges */
 		)
 		if err != nil {
 			return err
@@ -118,7 +119,6 @@ func registerTPCHBenchSpec(r registry.Registry, b tpchBenchSpec) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds:           registry.Clouds(spec.GCE, spec.Local),
 		Suites:                     registry.Suites(registry.Nightly),
-		Skip:                       "153489. uses ancient tpch fixture",
 		RequiresDeprecatedWorkload: true, // uses querybench
 		PostProcessPerfMetrics: func(test string, histograms *roachtestutil.HistogramMetric) (roachtestutil.AggregatedPerfMetrics, error) {
 
diff --git a/pkg/cmd/roachtest/tests/tpchvec.go b/pkg/cmd/roachtest/tests/tpchvec.go
--- a/pkg/cmd/roachtest/tests/tpchvec.go
+++ b/pkg/cmd/roachtest/tests/tpchvec.go
@@ -533,9 +533,11 @@ func getTPCHVecWorkloadCmd(numRunsPerQuery, queryNum int, sharedProcessMT bool)
 func runTPCHVec(ctx context.Context, t test.Test, c cluster.Cluster, testCase tpchVecTestCase) {
 	c.Start(ctx, t.L(), option.NewStartOpts(option.NoBackupSchedule), install.MakeClusterSettings())
 
+	var virtualClusterName string
 	var conn *gosql.DB
 	var disableMergeQueue bool
 	if testCase.sharedProcessMT() {
+		virtualClusterName = appTenantName
 		singleTenantConn := c.Conn(ctx, t.L(), 1)
 		// Disable merge queue in the system tenant.
 		if _, err := singleTenantConn.Exec("SET CLUSTER SETTING kv.range_merge.queue_enabled = false;"); err != nil {
@@ -549,9 +551,10 @@ func runTPCHVec(ctx context.Context, t test.Test, c cluster.Cluster, testCase tp
 		disableMergeQueue = true
 	}
 
-	t.Status("restoring TPCH dataset for Scale Factor 1")
-	if err := loadTPCHDataset(
-		ctx, t, c, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx), c.All(), disableMergeQueue,
+	t.Status("importing TPCH dataset for Scale Factor 1")
+	if err := importTPCHDataset(
+		ctx, t, c, virtualClusterName, conn, 1 /* sf */, c.NewDeprecatedMonitor(ctx),
+		c.All(), disableMergeQueue, true, /* smallRanges */
 	); err != nil {
 		t.Fatal(err)
 	}
@@ -597,7 +600,6 @@ func registerTPCHVec(r registry.Registry) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHVec(ctx, t, c, newTpchVecPerfTest(
 				"sql.defaults.vectorize", /* settingName */
@@ -615,7 +617,6 @@ func registerTPCHVec(r registry.Registry) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHVec(ctx, t, c, tpchVecDiskTest{})
 		},
@@ -630,7 +631,6 @@ func registerTPCHVec(r registry.Registry) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHVec(ctx, t, c, newTpchVecPerfTest(
 				"sql.distsql.use_streamer.enabled", /* settingName */
@@ -649,7 +649,6 @@ func registerTPCHVec(r registry.Registry) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			runTPCHVec(ctx, t, c, newTpchVecPerfTest(
 				"sql.distsql.direct_columnar_scans.enabled", /* settingName */
@@ -668,7 +667,6 @@ func registerTPCHVec(r registry.Registry) {
 		// https://github.com/cockroachdb/cockroach/issues/105968
 		CompatibleClouds: registry.Clouds(spec.GCE, spec.Local),
 		Suites:           registry.Suites(registry.Nightly),
-		Skip:             "153489. uses ancient tpch fixture",
 		Run: func(ctx context.Context, t test.Test, c cluster.Cluster) {
 			p := newTpchVecPerfTest(
 				"sql.distsql.direct_columnar_scans.enabled", /* settingName */
EOF_114329324912

# Set environment variables for test execution
export TZ=
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/root/go
export USE_BAZEL_VERSION=cockroachdb/7.6.0

# Strategy: Since these are roachtest integration test definitions that require cloud infrastructure,
# we validate them by:
# 1. Building the test definitions package to ensure compilation succeeds
# 2. Running the roachtest framework unit tests that validate test registration and correctness

# Step 1: Build the test definitions to validate compilation and syntax
echo "Building roachtest test definitions package..."
bazel build //pkg/cmd/roachtest/tests:tests --test_output=all
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code $build_rc"
    echo "OMNIGRIL_EXIT_CODE=$build_rc"
    git checkout d488dc56e50ee761c94acecf58940a65d34294af \
        "pkg/cmd/roachtest/tests/cancel.go" \
        "pkg/cmd/roachtest/tests/multitenant_tpch.go" \
        "pkg/cmd/roachtest/tests/schemachange.go" \
        "pkg/cmd/roachtest/tests/sqlsmith.go" \
        "pkg/cmd/roachtest/tests/tpc_utils.go" \
        "pkg/cmd/roachtest/tests/tpcdsvec.go" \
        "pkg/cmd/roachtest/tests/tpch_concurrency.go" \
        "pkg/cmd/roachtest/tests/tpchbench.go" \
        "pkg/cmd/roachtest/tests/tpchvec.go"
    exit $build_rc
fi

# Step 2: Build the roachtest binary to ensure all components compile together
echo "Building roachtest binary..."
bazel build //pkg/cmd/roachtest:roachtest --test_output=all
roachtest_build_rc=$?

if [ $roachtest_build_rc -ne 0 ]; then
    echo "Roachtest binary build failed with exit code $roachtest_build_rc"
    echo "OMNIGRIL_EXIT_CODE=$roachtest_build_rc"
    git checkout d488dc56e50ee761c94acecf58940a65d34294af \
        "pkg/cmd/roachtest/tests/cancel.go" \
        "pkg/cmd/roachtest/tests/multitenant_tpch.go" \
        "pkg/cmd/roachtest/tests/schemachange.go" \
        "pkg/cmd/roachtest/tests/sqlsmith.go" \
        "pkg/cmd/roachtest/tests/tpc_utils.go" \
        "pkg/cmd/roachtest/tests/tpcdsvec.go" \
        "pkg/cmd/roachtest/tests/tpch_concurrency.go" \
        "pkg/cmd/roachtest/tests/tpchbench.go" \
        "pkg/cmd/roachtest/tests/tpchvec.go"
    exit $roachtest_build_rc
fi

# Step 3: Run roachtest framework unit tests that validate test definitions and registration
echo "Running roachtest framework unit tests..."
bazel test //pkg/cmd/roachtest:roachtest_test \
    --test_output=all \
    --test_timeout=600

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout d488dc56e50ee761c94acecf58940a65d34294af \
    "pkg/cmd/roachtest/tests/cancel.go" \
    "pkg/cmd/roachtest/tests/multitenant_tpch.go" \
    "pkg/cmd/roachtest/tests/schemachange.go" \
    "pkg/cmd/roachtest/tests/sqlsmith.go" \
    "pkg/cmd/roachtest/tests/tpc_utils.go" \
    "pkg/cmd/roachtest/tests/tpcdsvec.go" \
    "pkg/cmd/roachtest/tests/tpch_concurrency.go" \
    "pkg/cmd/roachtest/tests/tpchbench.go" \
    "pkg/cmd/roachtest/tests/tpchvec.go"

exit $rc