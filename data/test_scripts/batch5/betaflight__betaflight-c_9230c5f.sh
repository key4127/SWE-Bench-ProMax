#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 83c3353a7a6ada2f8287f43c89e32a824504c55c "src/test/unit/pg_unittest.cc"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/unit/pg_unittest.cc b/src/test/unit/pg_unittest.cc
--- a/src/test/unit/pg_unittest.cc
+++ b/src/test/unit/pg_unittest.cc
@@ -37,9 +37,9 @@ PG_REGISTER_WITH_RESET_TEMPLATE(motorConfig_t, motorConfig, PG_MOTOR_CONFIG, 1);
 PG_RESET_TEMPLATE(motorConfig_t, motorConfig,
     .dev = {
         .motorPwmRate = 400,
-        .motorPwmProtocol = 0,
-        .motorPwmInversion = 0,
-        .useUnsyncedPwm = 0,
+        .motorProtocol = 0,
+        .motorInversion = 0,
+        .useContinuousUpdate = 0,
         .useBurstDshot = 0,
         .useDshotTelemetry = 0,
         .useDshotEdt = 0,
EOF_114329324912

# Ensure compiler environment variables are set
export CC=clang-15
export CXX=clang++-15

# Change to test directory and clean any previous build artifacts
cd src/test
make clean || true

# Build and run the target test
make test_pg_unittest
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
cd /testbed
git checkout 83c3353a7a6ada2f8287f43c89e32a824504c55c "src/test/unit/pg_unittest.cc"