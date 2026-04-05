#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 01af6d13bf216a5d96f106c22edfec0688fea439 "src/test/unit/baro_bmp280_unittest.cc" "src/test/unit/baro_bmp388_unittest.cc" "src/test/unit/baro_ms5611_unittest.cc"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/unit/baro_bmp280_unittest.cc b/src/test/unit/baro_bmp280_unittest.cc
--- a/src/test/unit/baro_bmp280_unittest.cc
+++ b/src/test/unit/baro_bmp280_unittest.cc
@@ -163,7 +163,7 @@ void spiSetClkDivisor()
 {
 }
 
-void spiPreinitByIO()
+void ioPreinitByIO()
 {
 }
 
diff --git a/src/test/unit/baro_bmp388_unittest.cc b/src/test/unit/baro_bmp388_unittest.cc
--- a/src/test/unit/baro_bmp388_unittest.cc
+++ b/src/test/unit/baro_bmp388_unittest.cc
@@ -160,7 +160,7 @@ void spiSetClkDivisor()
 {
 }
 
-void spiPreinitByIO(IO_t)
+void ioPreinitByIO()
 {
 }
 
diff --git a/src/test/unit/baro_ms5611_unittest.cc b/src/test/unit/baro_ms5611_unittest.cc
--- a/src/test/unit/baro_ms5611_unittest.cc
+++ b/src/test/unit/baro_ms5611_unittest.cc
@@ -162,7 +162,7 @@ void spiSetClkDivisor()
 {
 }
 
-void spiPreinitByIO()
+void ioPreinitByIO()
 {
 }
 
EOF_114329324912

# Ensure compiler environment variables are set
export CC=clang-15
export CXX=clang++-15

# Clean any previous build artifacts to ensure fresh build
make clean || true

# Build and run the three target tests
# Using individual make commands as specified in the collected information
make test_baro_bmp280_unittest
rc1=$?

make test_baro_bmp388_unittest
rc2=$?

make test_baro_ms5611_unittest
rc3=$?

# Combine exit codes - if any test fails, the overall result is failure
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ] || [ $rc3 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 01af6d13bf216a5d96f106c22edfec0688fea439 "src/test/unit/baro_bmp280_unittest.cc" "src/test/unit/baro_bmp388_unittest.cc" "src/test/unit/baro_ms5611_unittest.cc"