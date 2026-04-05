#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 33824c2acc31aedb765f555540bd6e513ef7a9a4 "test/icinga-perfdata.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/icinga-perfdata.cpp b/test/icinga-perfdata.cpp
--- a/test/icinga-perfdata.cpp
+++ b/test/icinga-perfdata.cpp
@@ -285,6 +285,19 @@ BOOST_AUTO_TEST_CASE(uom)
 
 	str = pv->Format();
 	BOOST_CHECK_EQUAL(str, "test=1W");
+
+	pv = PerfdataValue::Parse("test=42c");
+	BOOST_CHECK(pv);
+	BOOST_CHECK_EQUAL(pv->GetValue(), 42);
+	BOOST_CHECK(pv->GetCounter());
+	BOOST_CHECK_EQUAL(pv->GetUnit(), "");
+	BOOST_CHECK_EQUAL(pv->GetCrit(), Empty);
+	BOOST_CHECK_EQUAL(pv->GetWarn(), Empty);
+	BOOST_CHECK_EQUAL(pv->GetMin(), Empty);
+	BOOST_CHECK_EQUAL(pv->GetMax(), Empty);
+
+	str = pv->Format();
+	BOOST_CHECK_EQUAL(str, "test=42c");
 }
 
 BOOST_AUTO_TEST_CASE(warncritminmax)
EOF_114329324912

# Reconfigure CMake with tests enabled and rebuild
cd /testbed/build
cmake -DCMAKE_BUILD_TYPE=Debug -DICINGA2_UNITY_BUILD=OFF -DICINGA2_WITH_TESTS=ON ..
make -j4

# Find the actual test binary location (could be Debug or Release)
if [ -f "./Bin/Debug/boosttest-test-base" ]; then
    TEST_BINARY="./Bin/Debug/boosttest-test-base"
elif [ -f "./Bin/Release/boosttest-test-base" ]; then
    TEST_BINARY="./Bin/Release/boosttest-test-base"
elif [ -f "./Bin/boosttest-test-base" ]; then
    TEST_BINARY="./Bin/boosttest-test-base"
elif [ -f "./test/boosttest-test-base" ]; then
    TEST_BINARY="./test/boosttest-test-base"
else
    echo "ERROR: Could not find test binary boosttest-test-base"
    find /testbed/build -name "boosttest-test-base" -type f -executable
    exit 1
fi

# Run the specific perfdata tests using Boost.Test with correct suite name
$TEST_BINARY --run_test=icinga_perfdata/* --log_level=all --report_level=detailed
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
cd /testbed
git checkout 33824c2acc31aedb765f555540bd6e513ef7a9a4 "test/icinga-perfdata.cpp"