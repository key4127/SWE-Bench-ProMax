#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a4293b1c3f0b4cf6e0ea2c799df1ac979317bd17 "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt" "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c" "examples/system/.build-test-rules.yml" "tools/test_apps/system/g1_components/CMakeLists.txt"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
--- a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
+++ b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
@@ -243,7 +243,7 @@ static void start_freq(soc_rtc_slow_clk_src_t required_src, uint32_t start_delay
             printf("PASS. Time measurement...");
         }
         uint32_t fail_measure = 0;
-#if SOC_LP_TIMER_SUPPORTED
+#if SOC_RTC_TIMER_V2_SUPPORTED
         uint64_t clk_rtc_time;
         for (int j = 0; j < 3; ++j) {
             clk_rtc_time = esp_clk_rtc_time();
@@ -334,7 +334,7 @@ TEST_CASE("Test starting 'External 32kHz XTAL' on the board without it.", "[rtc_
 #endif // !defined(CONFIG_IDF_CI_BUILD) || !CONFIG_SPIRAM_BANKSWITCH_ENABLE
 #endif // SOC_CLK_XTAL32K_SUPPORTED
 
-#if SOC_LP_TIMER_SUPPORTED
+#if SOC_RTC_TIMER_V2_SUPPORTED
 TEST_CASE("Test rtc clk calibration compensation", "[rtc_clk]")
 {
     int64_t t1 = esp_rtc_get_time_us();
diff --git a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt
--- a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt
+++ b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt
@@ -30,7 +30,7 @@ list(APPEND app_sources "test_lp_core_prefix.c")
 set(lp_core_sources         "lp_core/test_main.c")
 set(lp_core_sources_counter "lp_core/test_main_counter.c")
 
-if(CONFIG_SOC_LP_TIMER_SUPPORTED)
+if(CONFIG_SOC_RTC_TIMER_V2_SUPPORTED)
     set(lp_core_sources_set_timer_wakeup "lp_core/test_main_set_timer_wakeup.c")
 endif()
 
@@ -71,7 +71,7 @@ ulp_embed_binary(lp_core_test_app "${lp_core_sources}" "${lp_core_exp_dep_srcs}"
 ulp_embed_binary(lp_core_test_app_counter "${lp_core_sources_counter}" "${lp_core_exp_dep_srcs}")
 ulp_embed_binary(lp_core_test_app_isr "lp_core/test_main_isr.c"  "${lp_core_exp_dep_srcs}")
 
-if(CONFIG_SOC_LP_TIMER_SUPPORTED)
+if(CONFIG_SOC_RTC_TIMER_V2_SUPPORTED)
     ulp_embed_binary(lp_core_test_app_set_timer_wakeup "${lp_core_sources_set_timer_wakeup}" "${lp_core_exp_dep_srcs}")
 endif()
 
diff --git a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c
--- a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c
+++ b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c
@@ -13,7 +13,7 @@
 #include "lp_core_test_app_counter.h"
 #include "lp_core_test_app_isr.h"
 
-#if SOC_LP_TIMER_SUPPORTED
+#if SOC_RTC_TIMER_V2_SUPPORTED
 #include "lp_core_test_app_set_timer_wakeup.h"
 #endif
 
@@ -295,7 +295,7 @@ TEST_CASE("LP core can be stopped and and started again from main CPU", "[ulp]")
     }
 }
 
-#if SOC_LP_TIMER_SUPPORTED
+#if SOC_RTC_TIMER_V2_SUPPORTED
 TEST_CASE("LP core can schedule next wake-up time by itself", "[ulp]")
 {
     int64_t start, test_duration;
@@ -342,7 +342,7 @@ TEST_CASE("LP core gpio tests", "[ulp]")
 }
 #endif //SOC_RTCIO_PIN_COUNT > 0
 
-#endif //SOC_LP_TIMER_SUPPORTED
+#endif // SOC_RTC_TIMER_V2_SUPPORTED
 
 #define ISR_TEST_ITERATIONS 100
 #define IO_TEST_PIN 0
diff --git a/examples/system/.build-test-rules.yml b/examples/system/.build-test-rules.yml
--- a/examples/system/.build-test-rules.yml
+++ b/examples/system/.build-test-rules.yml
@@ -373,7 +373,7 @@ examples/system/ulp/lp_core/lp_spi:
 
 examples/system/ulp/lp_core/lp_timer_interrupt:
   disable:
-    - if: (SOC_LP_CORE_SUPPORTED != 1) or (SOC_LP_TIMER_SUPPORTED != 1)
+    - if: (SOC_LP_CORE_SUPPORTED != 1) or (SOC_RTC_TIMER_V2_SUPPORTED != 1)
   depends_components:
     - ulp
 
diff --git a/tools/test_apps/system/g1_components/CMakeLists.txt b/tools/test_apps/system/g1_components/CMakeLists.txt
--- a/tools/test_apps/system/g1_components/CMakeLists.txt
+++ b/tools/test_apps/system/g1_components/CMakeLists.txt
@@ -22,6 +22,7 @@ set(esp_hal_components
     esp_hal_usb
     esp_hal_wdt
     esp_hal_pmu
+    esp_hal_rtc_timer
 )
 set(COMPONENTS ${g0_components} ${g1_components} ${esp_hal_components} main)
 
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export CI_PIPELINE_ID=test-pipeline

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --upgrade pip
python3 -m pip install --break-system-packages pyyaml

# Initialize overall return code
overall_rc=0

# Test 1: Build test_rtc_clk for esp32
echo "=========================================="
echo "Building test_rtc_clk for esp32..."
echo "=========================================="
cd /testbed/components/esp_hw_support/test_apps/rtc_clk
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: test_rtc_clk build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 2: Build test_lp_core for esp32c6
echo "=========================================="
echo "Building test_lp_core for esp32c6..."
echo "=========================================="
cd /testbed/components/ulp/test_apps/lp_core/lp_core_basic_tests
rm -rf build sdkconfig
idf.py set-target esp32c6
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: test_lp_core build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 3: Build g1_components test app for esp32
echo "=========================================="
echo "Building g1_components test app for esp32..."
echo "=========================================="
cd /testbed/tools/test_apps/system/g1_components
rm -rf build sdkconfig

if [ -f "CMakeLists.txt" ]; then
    idf.py set-target esp32
    idf.py build
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: g1_components test app build failed with exit code $rc"
        overall_rc=$rc
    else
        # Run the dependency check script with the generated component_deps.dot file
        echo "=========================================="
        echo "Running check_dependencies.py..."
        echo "=========================================="
        if [ -f "build/component_deps.dot" ]; then
            python3 check_dependencies.py --component_deps_file build/component_deps.dot --target esp32
            rc=$?
            if [ $rc -ne 0 ]; then
                echo "ERROR: check_dependencies.py failed with exit code $rc"
                overall_rc=$rc
            fi
        else
            echo "WARNING: component_deps.dot not found, skipping check_dependencies.py"
        fi
    fi
else
    echo "ERROR: No CMakeLists.txt found in g1_components directory"
    overall_rc=1
fi

# Test 4: Validate YAML syntax in .build-test-rules.yml
echo "=========================================="
echo "Validating YAML syntax in .build-test-rules.yml..."
echo "=========================================="
cd /testbed
python3 -c "import yaml; yaml.safe_load(open('examples/system/.build-test-rules.yml'))"
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: YAML validation failed with exit code $rc"
    overall_rc=$rc
else
    echo "YAML validation passed"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$overall_rc"

# Cleanup: restore original files
cd /testbed
git checkout a4293b1c3f0b4cf6e0ea2c799df1ac979317bd17 "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/CMakeLists.txt" "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core.c" "examples/system/.build-test-rules.yml" "tools/test_apps/system/g1_components/CMakeLists.txt"