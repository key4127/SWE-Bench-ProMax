#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 365a824786a822872e6d32cdb2ad269b83c08571 "pkg/planner/core/find_best_task_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/planner/core/find_best_task_test.go b/pkg/planner/core/find_best_task_test.go
--- a/pkg/planner/core/find_best_task_test.go
+++ b/pkg/planner/core/find_best_task_test.go
@@ -15,7 +15,6 @@
 package core
 
 import (
-	"fmt"
 	"testing"
 
 	"github.com/pingcap/tidb/pkg/domain"
@@ -49,97 +48,6 @@ func (ds *mockDataSource) FindBestTask(prop *property.PhysicalProperty, planCoun
 	return task, 1, nil
 }
 
-// mockLogicalPlan4Test is a LogicalPlan which is used for unit test.
-// The basic assumption:
-//  1. mockLogicalPlan4Test can generate tow kinds of physical plan: physicalPlan1 and
-//     physicalPlan2. physicalPlan1 can pass the property only when they are the same
-//     order; while physicalPlan2 cannot match any of the property(in other words, we can
-//     generate it only when then property is empty).
-//  2. We have a hint for physicalPlan2.
-//  3. If the property is empty, we still need to check `canGeneratePlan2` to decide
-//     whether it can generate physicalPlan2.
-type mockLogicalPlan4Test struct {
-	logicalop.BaseLogicalPlan
-	// hasHintForPlan2 indicates whether this mockPlan contains hint.
-	// This hint is used to generate physicalPlan2. See the implementation
-	// of ExhaustPhysicalPlans().
-	hasHintForPlan2 bool
-	// canGeneratePlan2 indicates whether this plan can generate physicalPlan2.
-	canGeneratePlan2 bool
-	// costOverflow indicates whether this plan will generate physical plan whose cost is overflowed.
-	costOverflow bool
-}
-
-func (p mockLogicalPlan4Test) Init(ctx base.PlanContext) *mockLogicalPlan4Test {
-	p.BaseLogicalPlan = logicalop.NewBaseLogicalPlan(ctx, "mockPlan", &p, 0)
-	return &p
-}
-
-func (p *mockLogicalPlan4Test) getPhysicalPlan1(prop *property.PhysicalProperty) base.PhysicalPlan {
-	physicalPlan1 := mockPhysicalPlan4Test{planType: 1}.Init(p.SCtx())
-	physicalPlan1.SetStats(&property.StatsInfo{RowCount: 1})
-	physicalPlan1.SetChildrenReqProps(make([]*property.PhysicalProperty, 1))
-	physicalPlan1.SetXthChildReqProps(0, prop.CloneEssentialFields())
-	return physicalPlan1
-}
-
-func (p *mockLogicalPlan4Test) getPhysicalPlan2(prop *property.PhysicalProperty) base.PhysicalPlan {
-	physicalPlan2 := mockPhysicalPlan4Test{planType: 2}.Init(p.SCtx())
-	physicalPlan2.SetStats(&property.StatsInfo{RowCount: 1})
-	physicalPlan2.SetChildrenReqProps(make([]*property.PhysicalProperty, 1))
-	physicalPlan2.SetXthChildReqProps(0, property.NewPhysicalProperty(prop.TaskTp, nil, false, prop.ExpectedCnt, false))
-	return physicalPlan2
-}
-
-// ExhaustPhysicalPlans implements LogicalPlan interface.
-func (p *mockLogicalPlan4Test) ExhaustPhysicalPlans(prop *property.PhysicalProperty) ([]base.PhysicalPlan, bool, error) {
-	plan1 := make([]base.PhysicalPlan, 0, 1)
-	plan2 := make([]base.PhysicalPlan, 0, 1)
-	if prop.IsSortItemEmpty() && p.canGeneratePlan2 {
-		// Generate PhysicalPlan2 when the property is empty.
-		plan2 = append(plan2, p.getPhysicalPlan2(prop))
-		if p.hasHintForPlan2 {
-			return plan2, true, nil
-		}
-	}
-	if all, _ := prop.AllSameOrder(); all {
-		// Generate PhysicalPlan1 when properties are the same order.
-		plan1 = append(plan1, p.getPhysicalPlan1(prop))
-	}
-	if p.hasHintForPlan2 {
-		// The hint cannot work.
-		if prop.IsSortItemEmpty() {
-			p.SCtx().GetSessionVars().StmtCtx.AppendWarning(fmt.Errorf("the hint is inapplicable for plan2"))
-		}
-		return plan1, false, nil
-	}
-	return append(plan1, plan2...), true, nil
-}
-
-type mockPhysicalPlan4Test struct {
-	physicalop.BasePhysicalPlan
-	// 1 or 2 for physicalPlan1 or physicalPlan2.
-	// See the comment of mockLogicalPlan4Test.
-	planType int
-}
-
-func (p mockPhysicalPlan4Test) Init(ctx base.PlanContext) *mockPhysicalPlan4Test {
-	p.BasePhysicalPlan = physicalop.NewBasePhysicalPlan(ctx, "mockPlan", &p, 0)
-	return &p
-}
-
-// Attach2Task implements the PhysicalPlan interface.
-func (p *mockPhysicalPlan4Test) Attach2Task(tasks ...base.Task) base.Task {
-	t := tasks[0].Copy()
-	attachPlan2Task(p, t)
-	return t
-}
-
-// MemoryUsage of mockPhysicalPlan4Test is only for testing
-func (p *mockPhysicalPlan4Test) MemoryUsage() (sum int64) {
-	return
-}
-
 func TestCostOverflow(t *testing.T) {
 	ctx := coretestsdk.MockContext()
 	defer func() {
EOF_114329324912

# Set required environment variables
export TZ=Asia/Shanghai
export GO111MODULE=on
export CGO_ENABLED=1

# Enable failpoints (critical for TiDB tests)
/testbed/tools/bin/failpoint-ctl enable

# Run the target test file with required flags
# Using -tags 'intest' as required by TiDB build system
# Running the specific test file in the pkg/planner/core package
go test -tags 'intest' -v ./pkg/planner/core -run 'Test.*' 2>&1
rc=$?

# Disable failpoints (cleanup, even if tests failed)
/testbed/tools/bin/failpoint-ctl disable

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 365a824786a822872e6d32cdb2ad269b83c08571 "pkg/planner/core/find_best_task_test.go"