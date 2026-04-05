#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout fd3a131797a1079ade6670117a54bf05b085b0b2 "src/test/unit/rc_controls_unittest.cc"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/unit/rc_controls_unittest.cc b/src/test/unit/rc_controls_unittest.cc
--- a/src/test/unit/rc_controls_unittest.cc
+++ b/src/test/unit/rc_controls_unittest.cc
@@ -271,6 +271,7 @@ class RcControlsAdjustmentsTest : public ::testing::Test {
         .rate_limit = {0, 0, 0},
         .profileName = "default",
         .quickRatesRcExpo = 0,
+        .thrHover8 = 0,
     };
 
     channelRange_t fullRange = {
@@ -292,6 +293,7 @@ class RcControlsAdjustmentsTest : public ::testing::Test {
         controlRateConfig.rcExpo[FD_PITCH] = 0;
         controlRateConfig.thrMid8 = 0;
         controlRateConfig.thrExpo8 = 0;
+        controlRateConfig.thrHover8 = 0;
         controlRateConfig.rcExpo[FD_YAW] = 0;
         controlRateConfig.rates[0] = 0;
         controlRateConfig.rates[1] = 0;
@@ -376,6 +378,7 @@ TEST_F(RcControlsAdjustmentsTest, processRcAdjustmentsWithRcRateFunctionSwitchUp
         .rate_limit = {0, 0, 0},
         .profileName = "default",
         .quickRatesRcExpo = 0,
+        .thrHover8 = 0,
     };
 
     // and
EOF_114329324912

# Ensure compiler environment variables are set
export CC=clang-15
export CXX=clang++-15

# Clean any previous build artifacts to ensure fresh build
cd /testbed/src/test
make clean || true

# Build and run the rc_controls_unittest test
# Using the correct make target as specified in the collected information
make test_rc_controls_unittest
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
cd /testbed
git checkout fd3a131797a1079ade6670117a54bf05b085b0b2 "src/test/unit/rc_controls_unittest.cc"