#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 06f84d323d5fc1d15dfe00e65ee2c0d0070a992c \
    "components/hal/test_apps/hal_i2c/README.md" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h" \
    "components/hal/test_apps/hal_i2c/main/CMakeLists.txt" \
    "components/hal/test_apps/hal_i2c/main/Kconfig.projbuild" \
    "components/hal/test_apps/hal_i2c/main/hal_i2c_main.c" \
    "components/hal/.build-test-rules.yml" \
    "components/hal/test_apps/hal_i2c/CMakeLists.txt" \
    "tools/test_apps/system/g1_components/CMakeLists.txt" \
    "tools/test_apps/system/g1_components/check_dependencies.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hal_i2c/test_apps/.build-test-rules.yml b/components/esp_hal_i2c/test_apps/.build-test-rules.yml
new file mode 100644
--- /dev/null
+++ b/components/esp_hal_i2c/test_apps/.build-test-rules.yml
@@ -0,0 +1,3 @@
+components/esp_hal_i2c/test_apps/hal_i2c:
+  disable:
+    - if: SOC_I2C_SUPPORTED != 1
diff --git a/components/esp_hal_i2c/test_apps/hal_i2c/CMakeLists.txt b/components/esp_hal_i2c/test_apps/hal_i2c/CMakeLists.txt
new file mode 100644
--- /dev/null
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/CMakeLists.txt
@@ -0,0 +1,26 @@
+# The following lines of boilerplate have to be in your project's CMakeLists
+# in this exact order for cmake to work correctly
+cmake_minimum_required(VERSION 3.22)
+
+set(COMPONENTS main)
+
+include($ENV{IDF_PATH}/tools/cmake/project.cmake)
+# Check G1 component dependencies using tools/cmake template
+idf_build_set_property(__BUILD_COMPONENT_DEPGRAPH_ENABLED 1)
+
+project(hal_i2c)
+
+set(comp_deps_dot "${CMAKE_BINARY_DIR}/component_deps.dot")
+idf_build_get_property(target IDF_TARGET)
+
+execute_process(
+    COMMAND ${CMAKE_COMMAND} -E echo "Checking esp_hal_i2c dependency violations"
+    COMMAND python "${IDF_PATH}/tools/test_apps/system/g1_components/check_dependencies.py"
+            --component_deps_file ${comp_deps_dot}
+            --target ${target}
+    RESULT_VARIABLE result
+)
+
+if(NOT result EQUAL 0)
+    message(WARNING "Found esp_hal_i2c dependency violations. Please check G1 component dependencies.")
+endif()
diff --git a/components/hal/test_apps/hal_i2c/README.md b/components/esp_hal_i2c/test_apps/hal_i2c/README.md
rename from components/hal/test_apps/hal_i2c/README.md
rename to components/esp_hal_i2c/test_apps/hal_i2c/README.md
--- a/components/hal/test_apps/hal_i2c/README.md
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/README.md

diff --git a/components/hal/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt
rename from components/hal/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt
rename to components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt
--- a/components/hal/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt
@@ -1,2 +1,3 @@
 idf_component_register(SRCS "hal_i2c.c"
+                    PRIV_REQUIRES esp_hal_i2c
                     INCLUDE_DIRS ".")
diff --git a/components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c
rename from components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c
rename to components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c
--- a/components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c
@@ -28,7 +28,7 @@
 
 static inline uint32_t time_get_us_by_ccount(uint32_t counter)
 {
-    return counter/CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ;
+    return counter / CONFIG_ESP_DEFAULT_CPU_FREQ_MHZ;
 }
 
 #define ACK_VALUE            (0)
diff --git a/components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h
rename from components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h
rename to components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h
--- a/components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h

diff --git a/components/hal/test_apps/hal_i2c/main/CMakeLists.txt b/components/esp_hal_i2c/test_apps/hal_i2c/main/CMakeLists.txt
rename from components/hal/test_apps/hal_i2c/main/CMakeLists.txt
rename to components/esp_hal_i2c/test_apps/hal_i2c/main/CMakeLists.txt
--- a/components/hal/test_apps/hal_i2c/main/CMakeLists.txt
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/main/CMakeLists.txt
@@ -2,4 +2,4 @@ set(srcs "hal_i2c_main.c")
 
 idf_component_register(SRCS ${srcs}
                     INCLUDE_DIRS "."
-                    PRIV_REQUIRES hal_i2c)
+                    PRIV_REQUIRES hal_i2c esp_hal_i2c)
diff --git a/components/hal/test_apps/hal_i2c/main/Kconfig.projbuild b/components/esp_hal_i2c/test_apps/hal_i2c/main/Kconfig.projbuild
rename from components/hal/test_apps/hal_i2c/main/Kconfig.projbuild
rename to components/esp_hal_i2c/test_apps/hal_i2c/main/Kconfig.projbuild
--- a/components/hal/test_apps/hal_i2c/main/Kconfig.projbuild
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/main/Kconfig.projbuild

diff --git a/components/hal/test_apps/hal_i2c/main/hal_i2c_main.c b/components/esp_hal_i2c/test_apps/hal_i2c/main/hal_i2c_main.c
rename from components/hal/test_apps/hal_i2c/main/hal_i2c_main.c
rename to components/esp_hal_i2c/test_apps/hal_i2c/main/hal_i2c_main.c
--- a/components/hal/test_apps/hal_i2c/main/hal_i2c_main.c
+++ b/components/esp_hal_i2c/test_apps/hal_i2c/main/hal_i2c_main.c

diff --git a/components/hal/.build-test-rules.yml b/components/hal/.build-test-rules.yml
--- a/components/hal/.build-test-rules.yml
+++ b/components/hal/.build-test-rules.yml
@@ -4,10 +4,6 @@ components/hal/test_apps/crypto:
     - mbedtls
     - esp_security
 
-components/hal/test_apps/hal_i2c:
-  disable:
-    - if: SOC_I2C_SUPPORTED != 1
-
 components/hal/test_apps/hal_utils:
   enable:
     - if: IDF_TARGET == "linux"
diff --git a/components/hal/test_apps/hal_i2c/CMakeLists.txt b/components/hal/test_apps/hal_i2c/CMakeLists.txt
deleted file mode 100644
--- a/components/hal/test_apps/hal_i2c/CMakeLists.txt
+++ /dev/null
@@ -1,8 +0,0 @@
-# The following lines of boilerplate have to be in your project's CMakeLists
-# in this exact order for cmake to work correctly
-cmake_minimum_required(VERSION 3.22)
-
-set(COMPONENTS main)
-
-include($ENV{IDF_PATH}/tools/cmake/project.cmake)
-project(hal_i2c)
diff --git a/tools/test_apps/system/g1_components/CMakeLists.txt b/tools/test_apps/system/g1_components/CMakeLists.txt
--- a/tools/test_apps/system/g1_components/CMakeLists.txt
+++ b/tools/test_apps/system/g1_components/CMakeLists.txt
@@ -18,6 +18,17 @@ set(extra_allowed_components
     ${CONFIG_IDF_TARGET_ARCH}
 )
 
+# Since esp_hal_* components are split from original hal component, so we can allow they are g1 components.
+# But in the future, esp_hal_* components should be removed from common build. IDF-13980
+file(GLOB esp_hal_component_dirs "${idf_path}/components/esp_hal_*")
+set(esp_hal_components "")
+foreach(hal_dir ${esp_hal_component_dirs})
+    if(IS_DIRECTORY ${hal_dir} AND EXISTS "${hal_dir}/CMakeLists.txt")
+        get_filename_component(hal_name ${hal_dir} NAME)
+        list(APPEND esp_hal_components ${hal_name})
+    endif()
+endforeach()
+
 # These components are currently included into "G1" build, but shouldn't.
 # After removing the extra dependencies, remove the components from this list as well.
 set(extra_components_which_shouldnt_be_included
@@ -104,6 +115,7 @@ set(expected_components
     ${COMPONENTS}
     ${extra_allowed_components}
     ${extra_components_which_shouldnt_be_included}
+    ${esp_hal_components}
 )
 
 list(SORT expected_components)
diff --git a/tools/test_apps/system/g1_components/check_dependencies.py b/tools/test_apps/system/g1_components/check_dependencies.py
--- a/tools/test_apps/system/g1_components/check_dependencies.py
+++ b/tools/test_apps/system/g1_components/check_dependencies.py
@@ -1,9 +1,12 @@
 # SPDX-FileCopyrightText: 2024-2025 Espressif Systems (Shanghai) CO LTD
 # SPDX-License-Identifier: Unlicense OR CC0-1.0
 import argparse
+import glob
 import logging
+import os
 
-g1_g0_components = [
+# Base G1/G0 components (static list)
+g1_g0_components_base = [
     'hal',
     'cxx',
     'esp_libc',
@@ -21,6 +24,33 @@
     'esp_mm',
 ]
 
+
+def get_all_esp_hal_components() -> list[str]:
+    """Dynamically discover all esp_hal_* components"""
+    esp_hal_components = []
+
+    # Try to get IDF_PATH from environment
+    idf_path = os.environ.get('IDF_PATH')
+    if idf_path is None:
+        # Fallback: assume script is in IDF_PATH/tools/test_apps/system/g1_components/
+        script_dir = os.path.dirname(os.path.abspath(__file__))
+        idf_path = os.path.join(script_dir, '../../../../..')
+
+    components_dir = os.path.join(idf_path, 'components')
+    if os.path.exists(components_dir):
+        # Find all esp_hal_* directories
+        esp_hal_dirs = glob.glob(os.path.join(components_dir, 'esp_hal_*'))
+        for hal_dir in esp_hal_dirs:
+            if os.path.isdir(hal_dir):
+                component_name = os.path.basename(hal_dir)
+                esp_hal_components.append(component_name)
+
+    return sorted(esp_hal_components)
+
+
+# Build complete G1/G0 components list (base + dynamic esp_hal_* components)
+g1_g0_components = g1_g0_components_base + get_all_esp_hal_components()
+
 # Global expected dependency violations that apply to all targets
 expected_dep_violations = {
     'esp_system': ['esp_timer', 'bootloader_support', 'esp_pm', 'esp_usb_cdc_rom_console'],
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_CI_BUILD=1
export LDGEN_CHECK_MAPPING=1
export EXTRA_CFLAGS="-Werror -Werror=deprecated-declarations -Werror=unused-variable -Werror=unused-but-set-variable -Werror=unused-function -Wstrict-prototypes"
export EXTRA_CXXFLAGS="-Werror -Werror=deprecated-declarations -Werror=unused-variable -Werror=unused-but-set-variable -Werror=unused-function"
source /testbed/export.sh

# Initialize return code
rc=0

# Function to build test app for a specific target
build_test_app() {
    local test_dir=$1
    local target=$2
    local test_name=$3
    
    echo "=== Building $test_name for $target ==="
    cd /testbed/$test_dir
    
    # Clean previous builds
    rm -rf build sdkconfig || true
    
    # Set target and build
    idf.py set-target $target
    local set_target_rc=$?
    
    if [ $set_target_rc -ne 0 ]; then
        echo "ERROR: $test_name set-target failed for $target with exit code $set_target_rc"
        rc=1
        return $set_target_rc
    fi
    
    idf.py build
    local build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: $test_name build failed for $target with exit code $build_rc"
        rc=1
    else
        echo "SUCCESS: $test_name built successfully for $target"
    fi
    
    # Clean up for next build
    idf.py fullclean || true
    
    return $build_rc
}

# Function to run dependency check for g1_components
run_dependency_check() {
    local test_dir=$1
    local target=$2
    
    echo "=== Running dependency check for g1_components on $target ==="
    cd /testbed/$test_dir
    
    # Clean previous builds
    rm -rf build sdkconfig || true
    
    # Build first
    idf.py set-target $target
    local set_target_rc=$?
    
    if [ $set_target_rc -ne 0 ]; then
        echo "ERROR: g1_components set-target failed for $target"
        rc=1
        return $set_target_rc
    fi
    
    idf.py build
    local build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: g1_components build failed for $target"
        rc=1
        return $build_rc
    fi
    
    # Run dependency check
    python check_dependencies.py --component_deps_file build/component_deps.dot --target $target
    local check_rc=$?
    
    if [ $check_rc -ne 0 ]; then
        echo "ERROR: g1_components dependency check failed for $target with exit code $check_rc"
        rc=1
    else
        echo "SUCCESS: g1_components dependency check passed for $target"
    fi
    
    # Clean up
    idf.py fullclean || true
    
    return $check_rc
}

# Test HAL I2C for multiple targets (testing a representative subset)
# NOTE: After applying the patch, the test files are moved to components/esp_hal_i2c/test_apps/hal_i2c/
build_test_app "components/esp_hal_i2c/test_apps/hal_i2c" "esp32" "hal_i2c"
build_test_app "components/esp_hal_i2c/test_apps/hal_i2c" "esp32s2" "hal_i2c"
build_test_app "components/esp_hal_i2c/test_apps/hal_i2c" "esp32c3" "hal_i2c"
build_test_app "components/esp_hal_i2c/test_apps/hal_i2c" "esp32c6" "hal_i2c"

# Test G1 Components with dependency validation
run_dependency_check "tools/test_apps/system/g1_components" "esp32"
run_dependency_check "tools/test_apps/system/g1_components" "esp32s2"
run_dependency_check "tools/test_apps/system/g1_components" "esp32c3"

# Summary
if [ $rc -eq 0 ]; then
    echo "=== All test applications built and validated successfully ==="
    echo "=== Build verification confirms patches are valid ==="
else
    echo "=== One or more test applications failed to build or validate ==="
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 06f84d323d5fc1d15dfe00e65ee2c0d0070a992c \
    "components/hal/test_apps/hal_i2c/README.md" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/CMakeLists.txt" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.c" \
    "components/hal/test_apps/hal_i2c/components/hal_i2c/hal_i2c.h" \
    "components/hal/test_apps/hal_i2c/main/CMakeLists.txt" \
    "components/hal/test_apps/hal_i2c/main/Kconfig.projbuild" \
    "components/hal/test_apps/hal_i2c/main/hal_i2c_main.c" \
    "components/hal/.build-test-rules.yml" \
    "components/hal/test_apps/hal_i2c/CMakeLists.txt" \
    "tools/test_apps/system/g1_components/CMakeLists.txt" \
    "tools/test_apps/system/g1_components/check_dependencies.py"