#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Set required environment variables
export CGO_ENABLED=1
export GO111MODULE=on
export TZ=UTC

# Checkout the target test files to ensure clean state
git checkout 993231d2133c44c5c81a3784c23c048916860cb4 \
    "pkg/executor/test/indexmergereadtest/index_merge_reader_test.go" \
    "pkg/planner/core/casetest/parallelapply/parallel_apply_test.go" \
    "pkg/planner/core/casetest/rule/BUILD.bazel" \
    "pkg/planner/core/casetest/rule/rule_outer2inner_test.go" \
    "pkg/planner/core/casetest/rule/testdata/outer2inner_out.json" \
    "pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/executor/test/indexmergereadtest/index_merge_reader_test.go b/pkg/executor/test/indexmergereadtest/index_merge_reader_test.go
--- a/pkg/executor/test/indexmergereadtest/index_merge_reader_test.go
+++ b/pkg/executor/test/indexmergereadtest/index_merge_reader_test.go
@@ -840,7 +840,7 @@ func TestIndexMergeLimitNotPushedOnPartialSideButKeepOrder(t *testing.T) {
 
 	// Use standard TiDB test approach: set analyze version and analyze
 	tk.MustExec("set @@tidb_analyze_version = 2")
-	tk.MustExec("analyze table t")
+	tk.MustExec("analyze table t all columns")
 
 	failpoint.Enable("github.com/pingcap/tidb/pkg/planner/core/forceIndexMergeKeepOrder", `return(true)`)
 	defer failpoint.Disable("github.com/pingcap/tidb/pkg/planner/core/forceIndexMergeKeepOrder")
diff --git a/pkg/planner/core/casetest/parallelapply/parallel_apply_test.go b/pkg/planner/core/casetest/parallelapply/parallel_apply_test.go
--- a/pkg/planner/core/casetest/parallelapply/parallel_apply_test.go
+++ b/pkg/planner/core/casetest/parallelapply/parallel_apply_test.go
@@ -33,12 +33,12 @@ func TestParallelApplyWarnning(t *testing.T) {
 		testKit.MustExec("create table t(a int, b int, index idx(a));")
 		testKit.MustQuery(`explain format='brief' select  t3.a from t t3 where (select /*+ inl_join(t1) */  count(*) from t t1 join t t2 on t1.a=t2.a and t1.b>t3.b);`).
 			Check(testkit.Rows(
-				"Projection 10000.00 root  test.t.a",
-				"└─Apply 10000.00 root  CARTESIAN inner join",
-				"  ├─TableReader(Build) 10000.00 root  data:TableFullScan",
-				"  │ └─TableFullScan 10000.00 cop[tikv] table:t3 keep order:false, stats:pseudo",
-				"  └─Selection(Probe) 8000.00 root  Column#10",
-				"    └─HashAgg 10000.00 root  funcs:count(1)->Column#10",
+				`Projection 10000.00 root  test.t.a`,
+				`└─Apply 10000.00 root  CARTESIAN inner join`,
+				`  ├─TableReader(Build) 10000.00 root  data:TableFullScan`,
+				`  │ └─TableFullScan 10000.00 cop[tikv] table:t3 keep order:false, stats:pseudo`,
+				`  └─Selection(Probe) 8000.00 root  Column#10`,
+				`    └─HashAgg 10000.00 root  funcs:count(1)->Column#10`,
 				"      └─IndexJoin 99900000.00 root  inner join, inner:IndexLookUp, outer key:test.t.a, inner key:test.t.a, equal cond:eq(test.t.a, test.t.a)",
 				"        ├─IndexReader(Build) 99900000.00 root  index:IndexFullScan",
 				"        │ └─IndexFullScan 99900000.00 cop[tikv] table:t2, index:idx(a) keep order:false, stats:pseudo",
diff --git a/pkg/planner/core/casetest/rule/BUILD.bazel b/pkg/planner/core/casetest/rule/BUILD.bazel
--- a/pkg/planner/core/casetest/rule/BUILD.bazel
+++ b/pkg/planner/core/casetest/rule/BUILD.bazel
@@ -16,7 +16,7 @@ go_test(
     ],
     data = glob(["testdata/**"]),
     flaky = True,
-    shard_count = 11,
+    shard_count = 12,
     deps = [
         "//pkg/domain",
         "//pkg/expression",
diff --git a/pkg/planner/core/casetest/rule/rule_outer2inner_test.go b/pkg/planner/core/casetest/rule/rule_outer2inner_test.go
--- a/pkg/planner/core/casetest/rule/rule_outer2inner_test.go
+++ b/pkg/planner/core/casetest/rule/rule_outer2inner_test.go
@@ -82,3 +82,39 @@ func TestOuter2InnerIssue55886(t *testing.T) {
 		}
 	})
 }
+
+func TestIssue58836(t *testing.T) {
+	store := testkit.CreateMockStore(t)
+	testKit := testkit.NewTestKit(t, store)
+	testKit.MustExec("use test")
+	testKit.MustExec("create table t (id int primary key, name varchar(100));")
+	testKit.MustExec("insert into t values (1, null), (2, 1);")
+	testKit.MustQuery(`with tmp as (
+select
+row_number() over() as id,
+(select '1' from dual where id in (2)) as name
+from t
+)
+select 'ok' from dual
+where ('1',1) in (select name, id from tmp);`).Check(testkit.Rows())
+	testKit.MustQuery(`explain format = 'plan_tree' with tmp as (
+select
+row_number() over() as id,
+(select '1' from dual where id in (2)) as name
+from t
+)
+select 'ok' from dual
+where ('1',1) in (select name, id from tmp);`).Check(testkit.Rows(
+		`Projection root  ok->Column#13`,
+		`└─HashJoin root  CARTESIAN inner join`,
+		`  ├─TableDual(Build) root  rows:1`,
+		`  └─HashAgg(Probe) root  group by:Column#11, Column#12, funcs:firstrow(1)->Column#18`,
+		`    └─Selection root  eq("1", Column#11), eq(1, Column#12)`,
+		`      └─Window root  row_number()->Column#12 over(rows between current row and current row)`,
+		`        └─Apply root  CARTESIAN left outer join, left side:TableReader`,
+		`          ├─TableReader(Build) root  data:TableFullScan`,
+		`          │ └─TableFullScan cop[tikv] table:t keep order:false, stats:pseudo`,
+		`          └─Projection(Probe) root  1->Column#11`,
+		`            └─Selection root  eq(test.t.id, 2)`,
+		`              └─TableDual root  rows:1`))
+}
diff --git a/pkg/planner/core/casetest/rule/testdata/outer2inner_out.json b/pkg/planner/core/casetest/rule/testdata/outer2inner_out.json
--- a/pkg/planner/core/casetest/rule/testdata/outer2inner_out.json
+++ b/pkg/planner/core/casetest/rule/testdata/outer2inner_out.json
@@ -284,13 +284,12 @@
           "  │   └─Selection 9990.00 cop[tikv]  not(isnull(test.dd.col_blob_key))",
           "  │     └─TableFullScan 10000.00 cop[tikv] table:alias2 keep order:false, stats:pseudo",
           "  └─Projection(Probe) 12487.50 root  test.d.pk, test.d.col_blob, test.d.col_blob_key, test.d.col_varchar_key, test.d.col_date, test.d.col_int_key, test.dd.pk, test.dd.col_blob, test.dd.col_blob_key, test.dd.col_date, test.dd.col_int_key, cast(test.dd.col_blob_key, datetime(6) BINARY)->Column#41",
-          "    └─HashJoin 12487.50 root  inner join, equal:[eq(test.d.col_date, test.dd.col_date)]",
+          "    └─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.d.col_date, test.dd.col_date)]",
           "      ├─TableReader(Build) 9990.00 root  data:Selection",
           "      │ └─Selection 9990.00 cop[tikv]  not(isnull(test.dd.col_date))",
           "      │   └─TableFullScan 10000.00 cop[tikv] table:outr2 keep order:false, stats:pseudo",
-          "      └─TableReader(Probe) 9990.00 root  data:Selection",
-          "        └─Selection 9990.00 cop[tikv]  not(isnull(test.d.col_date))",
-          "          └─TableFullScan 10000.00 cop[tikv] table:outr1 keep order:false, stats:pseudo"
+          "      └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "        └─TableFullScan 10000.00 cop[tikv] table:outr1 keep order:false, stats:pseudo"
         ]
       },
       {
@@ -600,24 +599,24 @@
       {
         "SQL": "select * from t0 left outer join t11 on a0=a1 where t0.b0 in ('5', t11.b1) -- some = in the in list is not null filtering",
         "Plan": [
-          "Selection 9990.00 root  in(test.t0.b0, \"5\", test.t11.b1)",
-          "└─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.t0.a0, test.t11.a1)]",
-          "  ├─TableReader(Build) 9990.00 root  data:Selection",
-          "  │ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
-          "  │   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
-          "  └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "HashJoin 12487.50 root  inner join, equal:[eq(test.t0.a0, test.t11.a1)], other cond:in(test.t0.b0, \"5\", test.t11.b1)",
+          "├─TableReader(Build) 9990.00 root  data:Selection",
+          "│ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
+          "│   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
+          "└─TableReader(Probe) 9990.00 root  data:Selection",
+          "  └─Selection 9990.00 cop[tikv]  not(isnull(test.t0.a0))",
           "    └─TableFullScan 10000.00 cop[tikv] table:t0 keep order:false, stats:pseudo"
         ]
       },
       {
         "SQL": "select * from t0 left outer join t11 on a0=a1 where '5' in (t0.b0, t11.b1) -- some = in the in list is not null filtering",
         "Plan": [
-          "Selection 9990.00 root  in(\"5\", test.t0.b0, test.t11.b1)",
-          "└─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.t0.a0, test.t11.a1)]",
-          "  ├─TableReader(Build) 9990.00 root  data:Selection",
-          "  │ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
-          "  │   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
-          "  └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "HashJoin 12487.50 root  inner join, equal:[eq(test.t0.a0, test.t11.a1)], other cond:in(\"5\", test.t0.b0, test.t11.b1)",
+          "├─TableReader(Build) 9990.00 root  data:Selection",
+          "│ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
+          "│   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
+          "└─TableReader(Probe) 9990.00 root  data:Selection",
+          "  └─Selection 9990.00 cop[tikv]  not(isnull(test.t0.a0))",
           "    └─TableFullScan 10000.00 cop[tikv] table:t0 keep order:false, stats:pseudo"
         ]
       }
diff --git a/pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json b/pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json
--- a/pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json
+++ b/pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json
@@ -284,13 +284,12 @@
           "  │   └─Selection 9990.00 cop[tikv]  not(isnull(test.dd.col_blob_key))",
           "  │     └─TableFullScan 10000.00 cop[tikv] table:alias2 keep order:false, stats:pseudo",
           "  └─Projection(Probe) 12487.50 root  test.d.pk, test.d.col_blob, test.d.col_blob_key, test.d.col_varchar_key, test.d.col_date, test.d.col_int_key, test.dd.pk, test.dd.col_blob, test.dd.col_blob_key, test.dd.col_date, test.dd.col_int_key, cast(test.dd.col_blob_key, datetime(6) BINARY)->Column#41",
-          "    └─HashJoin 12487.50 root  inner join, equal:[eq(test.d.col_date, test.dd.col_date)]",
+          "    └─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.d.col_date, test.dd.col_date)]",
           "      ├─TableReader(Build) 9990.00 root  data:Selection",
           "      │ └─Selection 9990.00 cop[tikv]  not(isnull(test.dd.col_date))",
           "      │   └─TableFullScan 10000.00 cop[tikv] table:outr2 keep order:false, stats:pseudo",
-          "      └─TableReader(Probe) 9990.00 root  data:Selection",
-          "        └─Selection 9990.00 cop[tikv]  not(isnull(test.d.col_date))",
-          "          └─TableFullScan 10000.00 cop[tikv] table:outr1 keep order:false, stats:pseudo"
+          "      └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "        └─TableFullScan 10000.00 cop[tikv] table:outr1 keep order:false, stats:pseudo"
         ]
       },
       {
@@ -600,24 +599,24 @@
       {
         "SQL": "select * from t0 left outer join t11 on a0=a1 where t0.b0 in ('5', t11.b1) -- some = in the in list is not null filtering",
         "Plan": [
-          "Selection 9990.00 root  in(test.t0.b0, \"5\", test.t11.b1)",
-          "└─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.t0.a0, test.t11.a1)]",
-          "  ├─TableReader(Build) 9990.00 root  data:Selection",
-          "  │ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
-          "  │   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
-          "  └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "HashJoin 12487.50 root  inner join, equal:[eq(test.t0.a0, test.t11.a1)], other cond:in(test.t0.b0, \"5\", test.t11.b1)",
+          "├─TableReader(Build) 9990.00 root  data:Selection",
+          "│ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
+          "│   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
+          "└─TableReader(Probe) 9990.00 root  data:Selection",
+          "  └─Selection 9990.00 cop[tikv]  not(isnull(test.t0.a0))",
           "    └─TableFullScan 10000.00 cop[tikv] table:t0 keep order:false, stats:pseudo"
         ]
       },
       {
         "SQL": "select * from t0 left outer join t11 on a0=a1 where '5' in (t0.b0, t11.b1) -- some = in the in list is not null filtering",
         "Plan": [
-          "Selection 9990.00 root  in(\"5\", test.t0.b0, test.t11.b1)",
-          "└─HashJoin 12487.50 root  left outer join, left side:TableReader, equal:[eq(test.t0.a0, test.t11.a1)]",
-          "  ├─TableReader(Build) 9990.00 root  data:Selection",
-          "  │ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
-          "  │   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
-          "  └─TableReader(Probe) 10000.00 root  data:TableFullScan",
+          "HashJoin 12487.50 root  inner join, equal:[eq(test.t0.a0, test.t11.a1)], other cond:in(\"5\", test.t0.b0, test.t11.b1)",
+          "├─TableReader(Build) 9990.00 root  data:Selection",
+          "│ └─Selection 9990.00 cop[tikv]  not(isnull(test.t11.a1))",
+          "│   └─TableFullScan 10000.00 cop[tikv] table:t11 keep order:false, stats:pseudo",
+          "└─TableReader(Probe) 9990.00 root  data:Selection",
+          "  └─Selection 9990.00 cop[tikv]  not(isnull(test.t0.a0))",
           "    └─TableFullScan 10000.00 cop[tikv] table:t0 keep order:false, stats:pseudo"
         ]
       }
EOF_114329324912

# Ensure failpoints are enabled (prerequisite for intest tag)
if [ -f "tools/bin/failpoint-ctl" ]; then
    tools/bin/failpoint-ctl enable || echo "Failpoint enable attempted"
elif command -v make &> /dev/null; then
    make failpoint-enable || echo "Failpoint enable attempted via make"
fi

# Run the target tests with required build tags
# Executing all three test packages in a single command to optimize efficiency
# Using -p 4 instead of -p 8 to ensure system stability in virtualized environment
go test -v -p 4 -tags 'deadlock,intest' \
    ./pkg/executor/test/indexmergereadtest/... \
    ./pkg/planner/core/casetest/parallelapply/... \
    ./pkg/planner/core/casetest/rule/...

rc=$?

# Capture and report exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to original state
git checkout 993231d2133c44c5c81a3784c23c048916860cb4 \
    "pkg/executor/test/indexmergereadtest/index_merge_reader_test.go" \
    "pkg/planner/core/casetest/parallelapply/parallel_apply_test.go" \
    "pkg/planner/core/casetest/rule/BUILD.bazel" \
    "pkg/planner/core/casetest/rule/rule_outer2inner_test.go" \
    "pkg/planner/core/casetest/rule/testdata/outer2inner_out.json" \
    "pkg/planner/core/casetest/rule/testdata/outer2inner_xut.json"