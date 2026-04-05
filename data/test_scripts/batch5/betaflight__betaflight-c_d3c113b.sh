#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout c513b102b6f2af9aa0390cfa7ef908ec652552fc "src/test/unit/pg_unittest.cc"

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
+        .useUnsyncedUpdate = 0,
         .useBurstDshot = 0,
         .useDshotTelemetry = 0,
         .useDshotEdt = 0,
EOF_114329324912

# Ensure compiler environment variables are set
export CC=clang
export CXX=clang++

# Navigate to the test directory as specified in the collected information
cd /testbed/src/test

# Clean any previous build artifacts to ensure fresh build
make clean || true

# Build and run the pg_unittest test
# Using the correct make target as specified in the collected information
make test_pg_unittest
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Return to testbed root and restore original test file
cd /testbed
git checkout c513b102b6f2af9aa0390cfa7ef908ec652552fc "src/test/unit/pg_unittest.cc"