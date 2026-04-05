#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout bd50c0fb7888e37dd1665937f4e3e9be800a3c69 "pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java b/pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java
--- a/pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java
+++ b/pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java
@@ -82,6 +82,8 @@ public void taskType1ButNoInProgressTask() {
     String taskType = "taskType1";
     Mockito.when(_pinotHelixTaskResourceManager.getTaskTypes()).thenReturn(ImmutableSet.of(taskType));
     Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType)).thenReturn(ImmutableSet.of());
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of());
     _taskMetricsEmitter.runTask(null);
 
     Assert.assertEquals(metricsRegistry.allMetrics().size(), 11);
@@ -127,6 +129,8 @@ public void oneSingleTaskTypeWithTwoTables() {
     String task12 = "task12";
     Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
         .thenReturn(ImmutableSet.of(task11, task12));
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of(task11, task12));
 
     String table1 = "table1_OFFLINE";
     String table2 = "table2_OFFLINE";
@@ -242,6 +246,8 @@ private void oneTaskTypeWithOneTable(String taskType, String taskName1, String t
     Mockito.when(_pinotHelixTaskResourceManager.getTaskTypes()).thenReturn(ImmutableSet.of(taskType));
     Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
         .thenReturn(ImmutableSet.of(taskName1, taskName2));
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of(taskName1, taskName2));
 
     PinotHelixTaskResourceManager.TaskCount taskCount = new PinotHelixTaskResourceManager.TaskCount();
     taskCount.addTaskState(TaskPartitionState.COMPLETED);
@@ -336,4 +342,147 @@ public void removeOldTaskTypeAddNewTaskType() {
     oneSingleTaskTypeWithTwoTables();
     taskType2WithOneTable();
   }
+
+  /**
+   * Test for previously in-progress tasks that completed between runs:
+   * Tasks that were in-progress in the previous run but completed before the current run
+   * should still have their metrics reported in the current run.
+   *
+   * Scenario:
+   * - Run 1: Task "taskCompletedBetweenRuns" is in-progress with 1 error subtask
+   * - Run 2: Task "taskCompletedBetweenRuns" has completed and is no longer in getTasksInProgress()
+   *
+   * Expected: Metrics for "taskCompletedBetweenRuns" should still be emitted in Run 2 by detecting it via
+   * _previousInProgressTasks tracking. The emitter maintains state of tasks that were in-progress
+   * in the previous execution cycle and includes completed tasks in the current cycle's metrics.
+   */
+  @Test
+  public void testReportsPreviouslyInProgressTasksThatCompletedBetweenRuns() {
+    String taskType = "SegmentGenerationAndPushTask";
+    String taskName = "taskCompletedBetweenRuns";
+    String tableName = "testTable_OFFLINE";
+
+    Mockito.when(_pinotHelixTaskResourceManager.getTaskTypes()).thenReturn(ImmutableSet.of(taskType));
+
+    // Run 1: Task is in-progress with 1 error subtask
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
+        .thenReturn(ImmutableSet.of(taskName));
+
+    // Ensure getTasksInProgressAndRecent returns only in-progress tasks for this test
+    // (not relevant for detecting short-lived tasks in this scenario)
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(
+        Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of(taskName));
+
+    PinotHelixTaskResourceManager.TaskCount taskCount = new PinotHelixTaskResourceManager.TaskCount();
+    taskCount.addTaskState(TaskPartitionState.TASK_ERROR);
+    Mockito.when(_pinotHelixTaskResourceManager.getTableTaskCount(taskName))
+        .thenReturn(Map.of(tableName, taskCount));
+
+    _taskMetricsEmitter.runTask(null);
+
+    // Verify metrics were emitted in Run 1
+    PinotMetricsRegistry metricsRegistry = _controllerMetrics.getMetricsRegistry();
+    Assert.assertEquals(((YammerSettableGauge<?>) metricsRegistry.allMetrics().get(
+            new YammerMetricName(ControllerMetrics.class,
+                "pinot.controller.numMinionSubtasksError." + taskType))
+        .getMetric()).value(), 1L);
+
+    // Run 2: Task has completed and is no longer in-progress
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
+        .thenReturn(ImmutableSet.of());  // Empty - task completed
+
+    // getTasksInProgressAndRecent should also return empty (task completed)
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(
+        Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of());
+
+    // The emitter should detect that taskCompletedBetweenRuns was in-progress before and include it in metrics
+    // This is achieved by comparing _previousInProgressTasks with currentInProgressTasks
+    _taskMetricsEmitter.runTask(null);
+
+    // Expected: Metrics for the completed task should still be reported
+    // The emitter tracks tasks that were in-progress in the previous cycle and includes
+    // them in the current cycle even if they've completed, ensuring final metrics are captured
+    Assert.assertEquals(((YammerSettableGauge<?>) metricsRegistry.allMetrics().get(
+            new YammerMetricName(ControllerMetrics.class,
+                "pinot.controller.numMinionSubtasksError." + taskType))
+        .getMetric()).value(), 1L,
+        "Previously in-progress task that completed between runs should still be reported");
+  }
+
+  /**
+   * Test for short-lived tasks that started and completed between runs:
+   * Tasks that started AND completed between two collection runs should have their
+   * metrics reported.
+   *
+   * Scenario:
+   * - Run 1: No tasks in-progress
+   * - Between runs: Task "taskShortLived" starts and completes (very short-lived)
+   * - Run 2: No tasks in-progress (taskShortLived already completed)
+   *
+   * Expected: Metrics for "taskShortLived" should be emitted in Run 2 by detecting it via
+   * getTasksInProgressAndRecent(taskType, timestamp) which uses WorkflowContext.getJobStartTimes() to find tasks that
+   * started after the previous execution timestamp. The emitter combines in-progress tasks and
+   * short-lived tasks in a single Helix call to avoid duplicate getWorkflowConfig/getWorkflowContext calls.
+   */
+  @Test
+  public void testReportsTasksThatStartAndCompleteBetweenRuns() {
+    String taskType = "SegmentGenerationAndPushTask";
+    String taskName = "taskShortLived";
+    String tableName = "testTable_OFFLINE";
+
+    Mockito.when(_pinotHelixTaskResourceManager.getTaskTypes()).thenReturn(ImmutableSet.of(taskType));
+
+    // Run 1: No tasks in-progress
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
+        .thenReturn(ImmutableSet.of());
+
+    // Run 1: No tasks started after initial timestamp (empty on first run)
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(
+        Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of());
+
+    _taskMetricsEmitter.runTask(null);
+
+    // Verify no error metrics in Run 1
+    PinotMetricsRegistry metricsRegistry = _controllerMetrics.getMetricsRegistry();
+    Assert.assertEquals(((YammerSettableGauge<?>) metricsRegistry.allMetrics().get(
+            new YammerMetricName(ControllerMetrics.class,
+                "pinot.controller.numMinionSubtasksError." + taskType))
+        .getMetric()).value(), 0L);
+
+    // Between Run 1 and Run 2: taskShortLived starts and completes with 1 error
+    // This task has a job start time after Run 1's execution timestamp
+    // The implementation uses getTasksInProgressAndRecent(taskType, timestamp) which internally calls
+    // WorkflowContext.getJobStartTimes() to detect such tasks while avoiding duplicate Helix calls
+    PinotHelixTaskResourceManager.TaskCount taskCount = new PinotHelixTaskResourceManager.TaskCount();
+    taskCount.addTaskState(TaskPartitionState.TASK_ERROR);
+    Mockito.when(_pinotHelixTaskResourceManager.getTableTaskCount(taskName))
+        .thenReturn(Map.of(tableName, taskCount));
+
+    // Run 2: Still no tasks in-progress (taskShortLived already completed)
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgress(taskType))
+        .thenReturn(ImmutableSet.of());
+
+    // Mock getTasksInProgressAndRecent to return taskShortLived (simulating it started after Run 1's timestamp)
+    // The implementation combines in-progress tasks and tasks started after timestamp in a single call
+    // This avoids duplicate Helix calls while still capturing short-lived tasks
+    Mockito.when(_pinotHelixTaskResourceManager.getTasksInProgressAndRecent(
+        Mockito.eq(taskType), Mockito.anyLong()))
+        .thenReturn(ImmutableSet.of(taskName));
+
+    _taskMetricsEmitter.runTask(null);
+
+    // Expected: Metrics for taskShortLived should be reported by detecting it via getTasksInProgressAndRecent()
+    // The emitter:
+    // 1. Calls getTasksInProgressAndRecent(taskType, previousExecutionTimestamp) which combines
+    //    in-progress tasks and tasks started after timestamp in a single Helix call
+    // 2. Uses WorkflowContext.getJobStartTimes() internally to detect short-lived tasks
+    // 3. Includes tasks that were in-progress previously but completed between cycles
+    Assert.assertEquals(((YammerSettableGauge<?>) metricsRegistry.allMetrics().get(
+            new YammerMetricName(ControllerMetrics.class,
+                "pinot.controller.numMinionSubtasksError." + taskType))
+        .getMetric()).value(), 1L, "Short-lived task that started and completed between runs should be reported");
+  }
 }
EOF_114329324912

# Set environment variables for test execution
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export MAVEN_OPTS="-Xms4g -Xmx4g --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-exports=java.base/jdk.internal.util.random=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED -Dnet.bytebuddy.experimental=true -Xshare:off -XX:+EnableDynamicAgentLoading"

# Run the specific test file using Maven
./mvnw test -pl pinot-controller -Dtest=TaskMetricsEmitterTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout bd50c0fb7888e37dd1665937f4e3e9be800a3c69 "pinot-controller/src/test/java/org/apache/pinot/controller/helix/core/minion/TaskMetricsEmitterTest.java"