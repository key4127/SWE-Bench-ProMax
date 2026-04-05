#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test result file to ensure clean state
git checkout 7711694c259a41c7b23494f91fdefab44042e2a1 "src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java"

# Apply the test patch (which updates the expected results in TestResult file)
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java b/src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java
--- a/src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java
+++ b/src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java
@@ -164,14 +164,14 @@ public class TeozTimelineIssues_0009_TestResult {
   pt2: [ 116.1416 ; 553.0000 ]
   stroke: 0.0-0.0-2.0
   shadow: 0
-  color: ff181818
+  color: ffa80036
 
 LINE:
   pt1: [ 98.1416 ; 553.0000 ]
   pt2: [ 116.1416 ; 535.0000 ]
   stroke: 0.0-0.0-2.0
   shadow: 0
-  color: ff181818
+  color: ffa80036
 
 RECTANGLE:
   pt1: [ 102.1416 ; 601.0000 ]
@@ -275,14 +275,14 @@ public class TeozTimelineIssues_0009_TestResult {
   pt2: [ 330.4061 ; 482.0000 ]
   stroke: 0.0-0.0-2.0
   shadow: 0
-  color: ff181818
+  color: ffa80036
 
 LINE:
   pt1: [ 312.4061 ; 482.0000 ]
   pt2: [ 330.4061 ; 464.0000 ]
   stroke: 0.0-0.0-2.0
   shadow: 0
-  color: ff181818
+  color: ffa80036
 
 RECTANGLE:
   pt1: [ 316.4061 ; 530.0000 ]
EOF_114329324912

# Verify the test result file exists after patch
echo "=== Verifying test result file after patch ==="
ls -la src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java || echo "Test result file not found"

# Also check if the actual test file exists
echo "=== Verifying actual test file exists ==="
ls -la src/test/java/nonreg/simple/TeozTimelineIssues_0009_Test.java || echo "Test file not found"

# Clean previous test results to ensure fresh execution
./gradlew cleanTest --no-daemon || true

# Run the specific test class (not TestResult, but Test)
# The TestResult file contains the expected output, while Test file contains the actual test
./gradlew test --tests "nonreg.simple.TeozTimelineIssues_0009_Test" --no-daemon --console=plain --info --rerun-tasks

# Capture the exit code
rc=$?

# Display test results from XML report
echo "=== Test Results from XML Report ==="
if [ -f build/test-results/test/TEST-nonreg.simple.TeozTimelineIssues_0009_Test.xml ]; then
    cat build/test-results/test/TEST-nonreg.simple.TeozTimelineIssues_0009_Test.xml
else
    echo "Test result XML file not found"
    ls -la build/test-results/test/ || echo "Test results directory not found"
fi

# Display test report summary
echo "=== Test Report Summary ==="
if [ -d build/reports/tests/test ]; then
    find build/reports/tests/test -name "*.html" -type f | head -5
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test result file
git checkout 7711694c259a41c7b23494f91fdefab44042e2a1 "src/test/java/nonreg/simple/TeozTimelineIssues_0009_TestResult.java"