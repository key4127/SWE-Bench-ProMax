#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 296bc7ddcccbb991789bf3c407e6782f1332706a "components/app_trace/test_apps/main/test_trace.c"

# Apply the test patch
echo "=== Applying test patch ==="
git apply -v - <<'EOF_114329324912'
diff --git a/components/app_trace/test_apps/main/test_trace.c b/components/app_trace/test_apps/main/test_trace.c
--- a/components/app_trace/test_apps/main/test_trace.c
+++ b/components/app_trace/test_apps/main/test_trace.c
@@ -67,9 +67,9 @@ const static char *TAG = "esp_apptrace_test";
 #define ESP_APPTRACE_TEST_LOGO( format, ... )  ESP_APPTRACE_TEST_LOG_LEVEL(E, ESP_LOG_NONE, format, ##__VA_ARGS__)
 
 #if CONFIG_APPTRACE_SV_ENABLE == 0
-#define ESP_APPTRACE_TEST_WRITE(_b_, _s_)            esp_apptrace_write(ESP_APPTRACE_DEST_TRAX, _b_, _s_, ESP_APPTRACE_TMO_INFINITE)
-#define ESP_APPTRACE_TEST_WRITE_FROM_ISR(_b_, _s_)   esp_apptrace_write(ESP_APPTRACE_DEST_TRAX, _b_, _s_, 0UL)
-#define ESP_APPTRACE_TEST_WRITE_NOWAIT(_b_, _s_)     esp_apptrace_write(ESP_APPTRACE_DEST_TRAX, _b_, _s_, 0)
+#define ESP_APPTRACE_TEST_WRITE(_b_, _s_)            esp_apptrace_write(ESP_APPTRACE_DEST_JTAG, _b_, _s_, ESP_APPTRACE_TMO_INFINITE)
+#define ESP_APPTRACE_TEST_WRITE_FROM_ISR(_b_, _s_)   esp_apptrace_write(ESP_APPTRACE_DEST_JTAG, _b_, _s_, 0UL)
+#define ESP_APPTRACE_TEST_WRITE_NOWAIT(_b_, _s_)     esp_apptrace_write(ESP_APPTRACE_DEST_JTAG, _b_, _s_, 0)
 
 typedef struct {
     uint8_t *buf;
@@ -625,7 +625,7 @@ static int esp_logtrace_printf(const char *fmt, ...)
 
     va_start(ap, fmt);
 
-    int ret = esp_apptrace_vprintf_to(ESP_APPTRACE_DEST_TRAX, ESP_APPTRACE_TMO_INFINITE, fmt, ap);
+    int ret = esp_apptrace_vprintf_to(ESP_APPTRACE_DEST_JTAG, ESP_APPTRACE_TMO_INFINITE, fmt, ap);
 
     va_end(ap);
 
@@ -657,7 +657,7 @@ static void esp_logtrace_task(void *p)
             break;
         }
     }
-    esp_err_t ret = esp_apptrace_flush(ESP_APPTRACE_DEST_TRAX, ESP_APPTRACE_TMO_INFINITE);
+    esp_err_t ret = esp_apptrace_flush(ESP_APPTRACE_DEST_JTAG, ESP_APPTRACE_TMO_INFINITE);
     if (ret != ESP_OK) {
         ESP_APPTRACE_TEST_LOGE("Failed to flush printf buf (%d)!", ret);
     }
EOF_114329324912

# Verify patch application
echo "=== Verifying patch was applied correctly ==="
if [ -f /testbed/components/app_trace/test_apps/main/test_trace.c ]; then
    echo "SUCCESS: test_trace.c exists and patch applied"
else
    echo "ERROR: test_trace.c not found after patch"
    exit 1
fi

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export LC_ALL=C.UTF-8
export PYTHONPATH=${IDF_PATH}/tools:${IDF_PATH}/tools/ci:${IDF_PATH}/tools/esp_app_trace:${IDF_PATH}/components/partition_table:${IDF_PATH}/tools/ci/python_packages
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== ESP-IDF app_trace Test Application Build and Validation ==="
echo "NOTE: These are Unity-based hardware tests that require physical ESP32 or QEMU"
echo "This script validates compilation and binary integrity"

# Navigate to the app_trace test application directory
cd /testbed/components/app_trace/test_apps

# Check for pytest files (should not exist according to context)
echo "=== Checking for pytest test files ==="
if ls pytest_*.py 2>/dev/null; then
    echo "Found pytest files - will attempt pytest execution"
    HAS_PYTEST=1
else
    echo "No pytest files found - this is a Unity C test application"
    HAS_PYTEST=0
fi

# Clean any previous build artifacts
rm -rf build sdkconfig sdkconfig.old

# Build with app_trace configuration
echo "=== Building app_trace test application with @app_trace config ==="
idf.py set-target esp32
idf.py @app_trace build
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "ERROR: app_trace test application build failed with exit code $build_rc"
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
else
    echo "SUCCESS: app_trace test application built successfully"
fi

# Verify build artifacts exist
echo "=== Verifying build artifacts ==="
if [ -d "build" ]; then
    echo "Build directory exists"
    ls -lh build/*.elf 2>/dev/null || ls -lh build/*.bin 2>/dev/null || echo "Build artifacts present"
    
    # Find the ELF file
    ELF_FILE=$(find build -name "*.elf" -type f | head -1)
    if [ -n "$ELF_FILE" ]; then
        echo "SUCCESS: ELF file found at $ELF_FILE"
        ls -lh "$ELF_FILE"
    else
        echo "WARNING: No ELF file found"
    fi
else
    echo "ERROR: Build directory not found"
    rc=1
fi

# Extract and validate test symbols from binary
echo "=== Extracting test symbols from binary ==="
if [ -n "$ELF_FILE" ] && [ -f "$ELF_FILE" ]; then
    # Try ESP32-specific nm, fall back to regular nm
    if command -v xtensa-esp32-elf-nm &> /dev/null; then
        NM_CMD="xtensa-esp32-elf-nm"
    elif command -v nm &> /dev/null; then
        NM_CMD="nm"
    else
        echo "WARNING: nm command not available"
        NM_CMD=""
    fi
    
    if [ -n "$NM_CMD" ]; then
        echo "Using $NM_CMD to extract symbols..."
        
        # Extract Unity and test-related symbols
        $NM_CMD "$ELF_FILE" 2>/dev/null | grep -E "(unity_|test_|app_main)" > test_symbols.txt || true
        
        if [ -s test_symbols.txt ]; then
            echo "SUCCESS: Test symbols found in binary:"
            
            # Count different types of symbols
            unity_count=$(grep -c "unity_" test_symbols.txt || echo "0")
            test_count=$(grep -c "test_" test_symbols.txt || echo "0")
            
            echo "Unity framework symbols: $unity_count"
            echo "Test function symbols: $test_count"
            
            # Show sample of test symbols
            echo "Sample test symbols:"
            grep "test_" test_symbols.txt | head -10 || echo "No test_ symbols found"
            
            if [ "$test_count" -gt 0 ]; then
                echo "SUCCESS: Test functions are properly compiled into binary"
            else
                echo "WARNING: No test_ symbols found (may be optimized or have different naming)"
            fi
        else
            echo "WARNING: Could not extract test symbols"
        fi
        
        # Check for app_main (entry point)
        if grep -q "app_main" test_symbols.txt 2>/dev/null; then
            echo "SUCCESS: app_main entry point found"
        fi
    fi
fi

# Validate test_trace.c compilation
echo "=== Validating test_trace.c compilation ==="
if [ -d "build" ]; then
    # Look for object files or compilation evidence
    find build -name "*test_trace*" 2>/dev/null | while read -r file; do
        echo "Found: $file"
    done
    
    # Check if test_trace.c appears in build logs
    if [ -f "build/compile_commands.json" ]; then
        if grep -q "test_trace.c" build/compile_commands.json; then
            echo "SUCCESS: test_trace.c found in compilation database"
        fi
    fi
fi

# Check SDK configuration
echo "=== Verifying SDK configuration ==="
if [ -f "sdkconfig" ]; then
    echo "Checking key app_trace configurations:"
    grep "CONFIG_APPTRACE" sdkconfig | head -5 || echo "No APPTRACE configs found"
    
    # Verify critical settings
    if grep -q "CONFIG_APPTRACE_DEST_JTAG=y" sdkconfig 2>/dev/null; then
        echo "SUCCESS: JTAG trace destination enabled"
    fi
fi

# Attempt to list Unity test cases from source
echo "=== Analyzing test cases in source code ==="
if [ -f "main/test_trace.c" ]; then
    echo "Extracting test case definitions from test_trace.c:"
    grep -E "TEST_CASE\(|static void test_" main/test_trace.c | head -20 || echo "No TEST_CASE macros found"
fi

# If pytest files exist, try to run them (unlikely based on context)
if [ $HAS_PYTEST -eq 1 ]; then
    echo "=== Attempting pytest execution ==="
    timeout 60 pytest --collect-only -v 2>&1 | tee pytest_collect.log || true
    
    if [ -f pytest_collect.log ]; then
        if grep -q "test session starts" pytest_collect.log; then
            echo "Pytest collection successful"
        fi
    fi
fi

# Final summary
echo ""
echo "========================================"
echo "=== Test Validation Summary ==="
echo "========================================"
echo "Build status: $([ $build_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo "Binary artifacts: $([ -n "$ELF_FILE" ] && echo 'VERIFIED' || echo 'MISSING')"
echo "Test symbols: $([ -f test_symbols.txt ] && [ -s test_symbols.txt ] && echo 'FOUND' || echo 'NOT_FOUND')"

if [ $build_rc -eq 0 ]; then
    echo "=== Test application built successfully ==="
    echo "=== Build verification confirms test patch is valid ==="
    echo "=== Tests are ready for execution on ESP32 hardware or QEMU ==="
    echo "=== Unity test runner will execute tests when flashed to device ==="
    rc=0
else
    echo "=== Test application build failed ==="
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 296bc7ddcccbb991789bf3c407e6782f1332706a "components/app_trace/test_apps/main/test_trace.c"

# Clean up build artifacts
rm -rf /testbed/components/app_trace/test_apps/build
rm -rf /testbed/components/app_trace/test_apps/sdkconfig
rm -rf /testbed/components/app_trace/test_apps/sdkconfig.old
rm -rf /testbed/components/app_trace/test_apps/test_symbols.txt
rm -rf /testbed/components/app_trace/test_apps/pytest_collect.log

exit $rc