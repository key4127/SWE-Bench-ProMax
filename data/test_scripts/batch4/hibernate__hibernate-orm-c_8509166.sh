#!/bin/bash
set -uxo pipefail

# Set environment variables - Fixed JAVA_HOME for eclipse-temurin image
export JAVA_HOME=/opt/java/openjdk
export PATH=$JAVA_HOME/bin:$PATH
export GRADLE_OPTS="-Dlog4j2.disableJmx=true -Xmx2g -XX:MaxMetaspaceSize=256m -XX:+HeapDumpOnOutOfMemoryError -Duser.language=en -Duser.country=US -Duser.timezone=UTC -Dfile.encoding=UTF-8"

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 5bde39f29ca8a6e777c8a921ebc5188b5a3a9e4b "hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java"

echo "=========================================="
echo "Verifying original test file before patch"
echo "=========================================="
cat hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java | grep -A 3 '@Test' || echo "No @Test methods found in original"

# Apply the test patch
echo "=========================================="
echo "Applying test patch"
echo "=========================================="
git apply -v - <<'EOF_114329324912'
diff --git a/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java b/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java
--- a/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java
+++ b/hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java
@@ -14,14 +14,15 @@
 
 public class EntityGraphsTest extends AbstractEntityGraphTest {
 
-	private final <T> void checkMerge(Class<T> rootType, EntityGraph<T> expected, @SuppressWarnings("unchecked") EntityGraph<T>... graphs) {
+	@SafeVarargs
+	private <T> void checkMerge(Class<T> rootType, EntityGraph<T> expected, EntityGraph<T>... graphs) {
 		EntityManager entityManager = getOrCreateEntityManager();
 		EntityGraph<T> actual = EntityGraphs.merge( entityManager, rootType, graphs );
 		Assert.assertTrue( EntityGraphs.areEqual( expected, actual ) );
 	}
 
 	@SafeVarargs
-	private final void checkMerge(EntityGraph<GraphParsingTestEntity> expected, EntityGraph<GraphParsingTestEntity>... graphs) {
+	private void checkMerge(EntityGraph<GraphParsingTestEntity> expected, EntityGraph<GraphParsingTestEntity>... graphs) {
 		checkMerge( GraphParsingTestEntity.class, expected, graphs );
 	}
 
EOF_114329324912

echo "=========================================="
echo "Verifying test file after patch"
echo "=========================================="
cat hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java | grep -A 3 '@Test' || echo "No @Test methods found after patch"

echo "=========================================="
echo "Compiling test classes"
echo "=========================================="
./gradlew --no-daemon --no-build-cache -x spotlessCheck hibernate-core:compileTestJava --console=plain

echo "=========================================="
echo "Running tests with verbose output"
echo "=========================================="
./gradlew --no-daemon --no-build-cache -x spotlessCheck --info hibernate-core:test --tests "org.hibernate.orm.test.entitygraph.parser.EntityGraphsTest" 2>&1 | tee /tmp/test_output.log

# Capture exit code
rc=$?

echo "=========================================="
echo "Test Execution Summary"
echo "=========================================="

# Check for test execution in the log
echo "Checking if tests were discovered and executed:"
grep -i "EntityGraphsTest" /tmp/test_output.log | grep -i "test" | head -20 || echo "No test execution found in logs"

# Determine the correct test results directory (check both build/ and target/)
TEST_RESULTS_DIR=""
if [ -d "/testbed/hibernate-core/target/test-results/test" ]; then
    TEST_RESULTS_DIR="/testbed/hibernate-core/target/test-results/test"
    echo "Found test results in target/ directory"
elif [ -d "/testbed/hibernate-core/build/test-results/test" ]; then
    TEST_RESULTS_DIR="/testbed/hibernate-core/build/test-results/test"
    echo "Found test results in build/ directory"
fi

# Check test results directory
echo "=========================================="
echo "Checking test results:"
if [ -n "$TEST_RESULTS_DIR" ]; then
    echo "Test result files in $TEST_RESULTS_DIR:"
    ls -la "$TEST_RESULTS_DIR/"
    
    # Display XML test results
    for xml_file in "$TEST_RESULTS_DIR"/*.xml; do
        if [ -f "$xml_file" ]; then
            echo "=========================================="
            echo "Content of $xml_file:"
            cat "$xml_file"
            echo ""
            
            # Parse and display test summary
            echo "Test Summary from XML:"
            grep -E 'testsuite|testcase' "$xml_file" | head -20 || true
        fi
    done
else
    echo "No test results directory found in either build/ or target/"
    # Search for test results anywhere
    echo "Searching for test results files:"
    find /testbed/hibernate-core -name "TEST-*.xml" -type f 2>/dev/null || echo "No XML test results found"
fi

# Check HTML reports (both locations)
HTML_REPORT=""
if [ -f "/testbed/hibernate-core/target/reports/tests/test/index.html" ]; then
    HTML_REPORT="/testbed/hibernate-core/target/reports/tests/test/index.html"
elif [ -f "/testbed/hibernate-core/build/reports/tests/test/index.html" ]; then
    HTML_REPORT="/testbed/hibernate-core/build/reports/tests/test/index.html"
fi

if [ -n "$HTML_REPORT" ]; then
    echo "=========================================="
    echo "Test HTML report exists at: $HTML_REPORT"
else
    echo "No HTML test report found in either build/ or target/"
fi

# Echo exit code for judge
echo "=========================================="
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 5bde39f29ca8a6e777c8a921ebc5188b5a3a9e4b "hibernate-core/src/test/java/org/hibernate/orm/test/entitygraph/parser/EntityGraphsTest.java"