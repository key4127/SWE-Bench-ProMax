#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 4192f25e7fac1058921ced9f3fd0d15c684a81f8 "ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt b/ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt
--- a/ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt
+++ b/ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt
@@ -29,42 +29,3 @@ add_sdmmc(factory_test_metro_sd)
 
 family_configure_app(factory_test_metro_sd)
 family_add_tinyusb(factory_test_metro_sd OPT_MCU_MIMXRT1XXX)
-
-#------------------------------------
-#
-#------------------------------------
-#include(${CMAKE_CURRENT_SOURCE_DIR}/../../../hw/bsp/family_support.cmake)
-#
-## gets PROJECT name for the example (e.g. <BOARD>-<DIR_NAME>)
-#family_get_project_name(PROJECT ${CMAKE_CURRENT_LIST_DIR})
-#
-#project(${PROJECT} C CXX ASM)
-#
-## Checks this example is valid for the family and initializes the project
-#family_initialize_project(${PROJECT} ${CMAKE_CURRENT_LIST_DIR})
-#
-## Espressif has its own cmake build system
-#if(FAMILY STREQUAL "espressif")
-#  return()
-#endif()
-#
-#add_executable(${PROJECT})
-#
-## Example source
-#target_sources(${PROJECT} PUBLIC
-#  arduino.c
-#  main.c
-#  usb_descriptors.c
-#  )
-#
-## Example include
-#target_include_directories(${PROJECT} PUBLIC
-#  src
-#  )
-#
-#include(middleware-sdmmc/CMakeLists.txt)
-#add_sdmmc(${PROJECT})
-#
-## Configure compilation flags and libraries for the example... see the corresponding function
-## in hw/bsp/FAMILY/family.cmake for details.
-#family_configure_device_example(${PROJECT} noos)
EOF_114329324912

# Clean any previous build artifacts
rm -rf build

# Configure the build with CMake
# This validates the CMakeLists.txt configuration
cmake -B build \
    -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain/arm_gcc.cmake \
    -DBOARD=metro_m7_1011_sd \
    -DFAMILY=mimxrt10xx \
    -G Ninja

# Capture configuration exit code
config_rc=$?

if [ $config_rc -ne 0 ]; then
    echo "CMake configuration failed with exit code: $config_rc"
    echo "OMNIGRIL_EXIT_CODE=$config_rc"
    git checkout 4192f25e7fac1058921ced9f3fd0d15c684a81f8 "ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt"
    exit $config_rc
fi

# Build the factory_test_metro_sd target
# This validates that the build completes successfully
cmake --build build --target factory_test_metro_sd

# Capture build exit code
build_rc=$?

if [ $build_rc -ne 0 ]; then
    echo "Build failed with exit code: $build_rc"
    echo "OMNIGRIL_EXIT_CODE=$build_rc"
    git checkout 4192f25e7fac1058921ced9f3fd0d15c684a81f8 "ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt"
    exit $build_rc
fi

# Verify the output artifact was created
if [ -f "build/ports/mimxrt10xx/apps/factory_test_metro_sd/factory_test_metro_sd.elf" ]; then
    echo "Build artifact created successfully: factory_test_metro_sd.elf"
    rc=0
else
    echo "Build artifact not found: factory_test_metro_sd.elf"
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 4192f25e7fac1058921ced9f3fd0d15c684a81f8 "ports/mimxrt10xx/apps/factory_test_metro_sd/CMakeLists.txt"

exit $rc