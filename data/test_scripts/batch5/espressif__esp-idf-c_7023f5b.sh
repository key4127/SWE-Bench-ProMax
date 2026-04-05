#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 0afcc02c4719ca6c2eb44918b9f04f5f52a6236c "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
--- a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
+++ b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
@@ -307,11 +307,11 @@ TEST_CASE("test for DPORT access performance", "[esp32]")
 static uint32_t start, end;
 
 #define BENCHMARK_START() do {                                      \
-        RSR(CCOUNT, start);                                         \
+        RSR(XT_REG_CCOUNT, start);                                         \
     } while(0)
 
 #define BENCHMARK_END(OPERATION) do {                               \
-        RSR(CCOUNT, end);                                           \
+        RSR(XT_REG_CCOUNT, end);                                           \
         printf("%s took %"PRIu32" cycles/op (%"PRIu32" cycles for %d ops)\n",     \
                OPERATION, (end - start)/REPEAT_OPS,                 \
                (end - start), REPEAT_OPS);                          \
diff --git a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S
--- a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S
+++ b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S
@@ -40,7 +40,7 @@ xt_highint5:
     wsr a0, CCOMPARE2
     esync
 
-    rsr     a0, EXCSAVE_5 // restore a0
+    rsr     a0, XT_REG_EXCSAVE_5 // restore a0
     rfi     5
 
 
@@ -74,7 +74,7 @@ xt_highint5:
     l32i    a4, a0, L5_INTR_A4_OFFSET
     rsync
 .L_xt_highint5_exit:
-    rsr     a0, EXCSAVE_5                   // restore a0
+    rsr     a0, XT_REG_EXCSAVE_5                   // restore a0
     rfi     5
 
 /* The linker has no reason to link in this file; all symbols it exports are already defined
diff --git a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c
--- a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c
+++ b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c
@@ -215,13 +215,13 @@ float IRAM_ATTR test_fp_benchmark_fp_divide(int counts, unsigned *cycles)
 {
     float f = MAXFLOAT;
     uint32_t before, after;
-    RSR(CCOUNT, before);
+    RSR(XT_REG_CCOUNT, before);
 
     for (int i = 0; i < counts; i++) {
         f /= 1.000432f;
     }
 
-    RSR(CCOUNT, after);
+    RSR(XT_REG_CCOUNT, after);
     *cycles = (after - before) / counts;
 
     return f;
@@ -254,13 +254,13 @@ float IRAM_ATTR test_fp_benchmark_fp_sqrt(int counts, unsigned *cycles)
 {
     float f = MAXFLOAT;
     uint32_t before, after;
-    RSR(CCOUNT, before);
+    RSR(XT_REG_CCOUNT, before);
 
     for (int i = 0; i < counts; i++) {
         f = sqrtf(f);
     }
 
-    RSR(CCOUNT, after);
+    RSR(XT_REG_CCOUNT, after);
     *cycles = (after - before) / counts;
 
     return f;
diff --git a/components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c b/components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c
--- a/components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c
+++ b/components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c
@@ -326,7 +326,7 @@ TEST_CASE_MULTIPLE_STAGES("reset reason ESP_RST_BROWNOUT after brownout event",
 #ifndef CONFIG_FREERTOS_UNICORE
 #if CONFIG_IDF_TARGET_ARCH_XTENSA
 #include "xt_instr_macros.h"
-#include "xtensa/config/specreg.h"
+#include "xtensa/config/xt_specreg.h"
 
 static int size_stack = 1024 * 4;
 static StackType_t *start_addr_stack;
@@ -335,8 +335,8 @@ static int fibonacci(int n, void* func(void))
 {
     int tmp1 = n, tmp2 = n;
     uint32_t base, start;
-    RSR(WINDOWBASE, base);
-    RSR(WINDOWSTART, start);
+    RSR(XT_REG_WINDOWBASE, base);
+    RSR(XT_REG_WINDOWSTART, start);
     printf("WINDOWBASE = %-2"PRIi32"   WINDOWSTART = 0x%"PRIx32"\n", base, start);
     if (n <= 1) {
         StackType_t *last_addr_stack = esp_cpu_get_sp();
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_SKIP_CHECK_SUBMODULES=1
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== Building and Testing ESP Hardware Support Unity Tests ==="

# Build esp_hw_support_unity_tests
cd /testbed/components/esp_hw_support/test_apps/esp_hw_support_unity_tests

echo "=== Cleaning previous builds for esp_hw_support_unity_tests ==="
rm -rf build sdkconfig || true

echo "=== Setting target to esp32 for esp_hw_support_unity_tests ==="
idf.py set-target esp32
target_rc=$?
if [ $target_rc -ne 0 ]; then
    echo "ERROR: Failed to set target to esp32 for esp_hw_support_unity_tests"
    rc=1
fi

if [ $rc -eq 0 ]; then
    echo "=== Building esp_hw_support_unity_tests ==="
    idf.py build
    build_rc=$?
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: esp_hw_support_unity_tests build failed"
        rc=1
    else
        echo "SUCCESS: esp_hw_support_unity_tests built successfully"
        
        # Verify ELF file was generated
        if [ -f "build/"*.elf ]; then
            echo "SUCCESS: ELF binary generated"
            ls -lh build/*.elf
        else
            echo "ERROR: ELF binary not found"
            rc=1
        fi
    fi
fi

# Validate that the patched test files compile without errors
if [ $rc -eq 0 ]; then
    echo "=== Validating esp_hw_support test file compilation ==="
    if [ -f "main/test_dport.c" ] && [ -f "main/test_dport_xt_highint5.S" ] && [ -f "main/test_fp.c" ]; then
        echo "SUCCESS: ESP hardware support test files exist and were included in build"
        
        # Check if test symbols are present in the binary
        if command -v xtensa-esp32-elf-nm &> /dev/null; then
            echo "=== Checking for test symbols in binary ==="
            xtensa-esp32-elf-nm build/*.elf | grep -i "test_" | head -20 || true
        fi
    else
        echo "ERROR: ESP hardware support test files not found"
        rc=1
    fi
fi

echo "=== Building and Testing ESP System Unity Tests ==="

# Build esp_system_unity_tests
cd /testbed/components/esp_system/test_apps/esp_system_unity_tests

echo "=== Cleaning previous builds for esp_system_unity_tests ==="
rm -rf build sdkconfig || true

echo "=== Setting target to esp32 for esp_system_unity_tests ==="
idf.py set-target esp32
target_rc=$?
if [ $target_rc -ne 0 ]; then
    echo "ERROR: Failed to set target to esp32 for esp_system_unity_tests"
    rc=1
fi

if [ $rc -eq 0 ]; then
    echo "=== Building esp_system_unity_tests ==="
    idf.py build
    build_rc=$?
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: esp_system_unity_tests build failed"
        rc=1
    else
        echo "SUCCESS: esp_system_unity_tests built successfully"
        
        # Verify ELF file was generated
        if [ -f "build/"*.elf ]; then
            echo "SUCCESS: ELF binary generated"
            ls -lh build/*.elf
        else
            echo "ERROR: ELF binary not found"
            rc=1
        fi
    fi
fi

# Validate that the patched test files compile without errors
if [ $rc -eq 0 ]; then
    echo "=== Validating esp_system test file compilation ==="
    if [ -f "main/test_reset_reason.c" ]; then
        echo "SUCCESS: ESP system test files exist and were included in build"
        
        # Check if test symbols are present in the binary
        if command -v xtensa-esp32-elf-nm &> /dev/null; then
            echo "=== Checking for test symbols in binary ==="
            xtensa-esp32-elf-nm build/*.elf | grep -i "test_" | head -20 || true
        fi
    else
        echo "ERROR: ESP system test files not found"
        rc=1
    fi
fi

# Summary
if [ $rc -eq 0 ]; then
    echo "=== All test applications validation completed successfully ==="
    echo "=== Build succeeded - patch compiles correctly ==="
    echo "=== Note: Full test execution requires physical ESP32 hardware or QEMU ==="
else
    echo "=== Test applications validation failed ==="
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 0afcc02c4719ca6c2eb44918b9f04f5f52a6236c "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport_xt_highint5.S" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_fp.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_reset_reason.c"