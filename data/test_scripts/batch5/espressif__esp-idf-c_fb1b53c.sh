#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 7c218e6531db2f511537739b8bcf5f197ce20952 "components/esp_hw_support/test_apps/dma/main/test_gdma.c" "components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hw_support/test_apps/dma/main/test_gdma.c b/components/esp_hw_support/test_apps/dma/main/test_gdma.c
--- a/components/esp_hw_support/test_apps/dma/main/test_gdma.c
+++ b/components/esp_hw_support/test_apps/dma/main/test_gdma.c
@@ -33,26 +33,24 @@ TEST_CASE("GDMA channel allocation", "[GDMA]")
     gdma_channel_alloc_config_t channel_config = {};
     gdma_channel_handle_t tx_channels[GDMA_LL_GET(PAIRS_PER_INST)] = {};
     gdma_channel_handle_t rx_channels[GDMA_LL_GET(PAIRS_PER_INST)] = {};
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
 
 #if SOC_HAS(AHB_GDMA)
     // install TX channels
     for (int i = 0; i < GDMA_LL_AHB_PAIRS_PER_GROUP; i++) {
-        TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[i]));
+        TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[i], NULL));
     };
-    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_ahb_channel(&channel_config, &tx_channels[0]));
+    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_ahb_channel(&channel_config, &tx_channels[0], NULL));
 
     // Free interrupts before installing RX interrupts to ensure enough free interrupts
     for (int i = 0; i < GDMA_LL_AHB_PAIRS_PER_GROUP; i++) {
         TEST_ESP_OK(gdma_del_channel(tx_channels[i]));
     }
 
     // install RX channels
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_RX;
     for (int i = 0; i < GDMA_LL_AHB_PAIRS_PER_GROUP; i++) {
-        TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &rx_channels[i]));
+        TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, NULL, &rx_channels[i]));
     }
-    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_ahb_channel(&channel_config, &rx_channels[0]));
+    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_ahb_channel(&channel_config, NULL, &rx_channels[0]));
 
     for (int i = 0; i < GDMA_LL_AHB_PAIRS_PER_GROUP; i++) {
         TEST_ESP_OK(gdma_del_channel(rx_channels[i]));
@@ -62,20 +60,12 @@ TEST_CASE("GDMA channel allocation", "[GDMA]")
     // install single and paired TX/RX channels
 #if GDMA_LL_AHB_PAIRS_PER_GROUP >= 2
     // single tx channel
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
-    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[0]));
-
-    // create tx channel and reserve sibling
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
-    channel_config.flags.reserve_sibling = 1;
-    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[1]));
-    // create rx channel and specify sibling channel
-    channel_config.flags.reserve_sibling = 0;
-    channel_config.sibling_chan = tx_channels[1]; // specify sibling channel
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_RX;
-    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &rx_channels[1]));
-    channel_config.sibling_chan = NULL;
-    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &rx_channels[0]));
+    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[0], NULL));
+
+    // create tx and rx channel pair
+    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, &tx_channels[1], &rx_channels[1]));
+    // create single rx channel
+    TEST_ESP_OK(gdma_new_ahb_channel(&channel_config, NULL, &rx_channels[0]));
 
     gdma_trigger_t fake_ahb_trigger1 = {
         .periph = 1,
@@ -105,23 +95,21 @@ TEST_CASE("GDMA channel allocation", "[GDMA]")
 
 #if SOC_HAS(AXI_GDMA)
     // install TX channels
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
     for (int i = 0; i < GDMA_LL_AXI_PAIRS_PER_GROUP; i++) {
-        TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[i]));
+        TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[i], NULL));
     };
-    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_axi_channel(&channel_config, &tx_channels[0]));
+    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_axi_channel(&channel_config, &tx_channels[0], NULL));
 
     // Free interrupts before installing RX interrupts to ensure enough free interrupts
     for (int i = 0; i < GDMA_LL_AXI_PAIRS_PER_GROUP; i++) {
         TEST_ESP_OK(gdma_del_channel(tx_channels[i]));
     }
 
     // install RX channels
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_RX;
     for (int i = 0; i < GDMA_LL_AXI_PAIRS_PER_GROUP; i++) {
-        TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &rx_channels[i]));
+        TEST_ESP_OK(gdma_new_axi_channel(&channel_config, NULL, &rx_channels[i]));
     }
-    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_axi_channel(&channel_config, &rx_channels[0]));
+    TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gdma_new_axi_channel(&channel_config, NULL, &rx_channels[0]));
 
     for (int i = 0; i < GDMA_LL_AXI_PAIRS_PER_GROUP; i++) {
         TEST_ESP_OK(gdma_del_channel(rx_channels[i]));
@@ -131,20 +119,12 @@ TEST_CASE("GDMA channel allocation", "[GDMA]")
     // install single and paired TX/RX channels
 #if GDMA_LL_AXI_PAIRS_PER_GROUP >= 2
     // single tx channel
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
-    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[0]));
-
-    // create tx channel and reserve sibling
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_TX;
-    channel_config.flags.reserve_sibling = 1;
-    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[1]));
-    // create rx channel and specify sibling channel
-    channel_config.flags.reserve_sibling = 0;
-    channel_config.sibling_chan = tx_channels[1]; // specify sibling channel
-    channel_config.direction = GDMA_CHANNEL_DIRECTION_RX;
-    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &rx_channels[1]));
-    channel_config.sibling_chan = NULL;
-    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &rx_channels[0]));
+    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[0], NULL));
+
+    // create tx and rx channel pair
+    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, &tx_channels[1], &rx_channels[1]));
+    // create single rx channel
+    TEST_ESP_OK(gdma_new_axi_channel(&channel_config, NULL, &rx_channels[0]));
 
     gdma_trigger_t fake_axi_trigger1 = {
         .periph = 1,
@@ -363,20 +343,10 @@ static void test_gdma_m2m_mode(bool trig_retention_backup)
 {
     gdma_channel_handle_t tx_chan = NULL;
     gdma_channel_handle_t rx_chan = NULL;
-    gdma_channel_alloc_config_t tx_chan_alloc_config = {};
-    gdma_channel_alloc_config_t rx_chan_alloc_config = {};
+    gdma_channel_alloc_config_t chan_alloc_config = {};
 
 #if SOC_HAS(AHB_GDMA)
-    tx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
-        .flags.reserve_sibling = true,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&tx_chan_alloc_config, &tx_chan));
-    rx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_RX,
-        .sibling_chan = tx_chan,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&rx_chan_alloc_config, &rx_chan));
+    TEST_ESP_OK(gdma_new_ahb_channel(&chan_alloc_config, &tx_chan, &rx_chan));
 
     test_gdma_m2m_transaction(tx_chan, rx_chan, false, trig_retention_backup);
 
@@ -385,16 +355,7 @@ static void test_gdma_m2m_mode(bool trig_retention_backup)
 #endif // SOC_HAS(AHB_GDMA)
 
 #if SOC_HAS(AXI_GDMA)
-    tx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
-        .flags.reserve_sibling = true,
-    };
-    TEST_ESP_OK(gdma_new_axi_channel(&tx_chan_alloc_config, &tx_chan));
-    rx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_RX,
-        .sibling_chan = tx_chan,
-    };
-    TEST_ESP_OK(gdma_new_axi_channel(&rx_chan_alloc_config, &rx_chan));
+    TEST_ESP_OK(gdma_new_axi_channel(&chan_alloc_config, &tx_chan, &rx_chan));
 
     // the AXI GDMA allows to put the DMA link list in the external memory
     test_gdma_m2m_transaction(tx_chan, rx_chan, true, trig_retention_backup);
@@ -435,18 +396,8 @@ static void test_gdma_m2m_unaligned_buffer_test(uint8_t *dst_data, uint8_t *src_
     memset(dst_data, 0, data_length + offset_len);
     gdma_channel_handle_t tx_chan = NULL;
     gdma_channel_handle_t rx_chan = NULL;
-    gdma_channel_alloc_config_t tx_chan_alloc_config = {};
-    gdma_channel_alloc_config_t rx_chan_alloc_config = {};
-    tx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
-        .flags.reserve_sibling = true,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&tx_chan_alloc_config, &tx_chan));
-    rx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_RX,
-        .sibling_chan = tx_chan,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&rx_chan_alloc_config, &rx_chan));
+    gdma_channel_alloc_config_t chan_alloc_config = {};
+    TEST_ESP_OK(gdma_new_ahb_channel(&chan_alloc_config, &tx_chan, &rx_chan));
     size_t sram_alignment = cache_hal_get_cache_line_size(CACHE_LL_LEVEL_INT_MEM, CACHE_TYPE_DATA);
 
     gdma_link_list_handle_t tx_link_list = NULL;
@@ -701,22 +652,12 @@ TEST_CASE("GDMA memory copy SRAM->PSRAM->SRAM", "[GDMA][M2M]")
 {
     [[maybe_unused]] gdma_channel_handle_t tx_chan = NULL;
     [[maybe_unused]] gdma_channel_handle_t rx_chan = NULL;
-    [[maybe_unused]] gdma_channel_alloc_config_t tx_chan_alloc_config = {};
-    [[maybe_unused]] gdma_channel_alloc_config_t rx_chan_alloc_config = {};
+    [[maybe_unused]] gdma_channel_alloc_config_t chan_alloc_config = {};
 
 #if SOC_HAS(AHB_GDMA)
 #if GDMA_LL_GET(AHB_PSRAM_CAPABLE)
     printf("Testing AHB-GDMA memory copy SRAM->PSRAM->SRAM\n");
-    tx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
-        .flags.reserve_sibling = true,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&tx_chan_alloc_config, &tx_chan));
-    rx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_RX,
-        .sibling_chan = tx_chan,
-    };
-    TEST_ESP_OK(gdma_new_ahb_channel(&rx_chan_alloc_config, &rx_chan));
+    TEST_ESP_OK(gdma_new_ahb_channel(&chan_alloc_config, &tx_chan, &rx_chan));
 
     test_gdma_memcpy_from_to_psram(tx_chan, rx_chan);
 
@@ -728,16 +669,7 @@ TEST_CASE("GDMA memory copy SRAM->PSRAM->SRAM", "[GDMA][M2M]")
 #if SOC_HAS(AXI_GDMA)
 #if GDMA_LL_GET(AXI_PSRAM_CAPABLE)
     printf("Testing AXI-GDMA memory copy SRAM->PSRAM->SRAM\n");
-    tx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
-        .flags.reserve_sibling = true,
-    };
-    TEST_ESP_OK(gdma_new_axi_channel(&tx_chan_alloc_config, &tx_chan));
-    rx_chan_alloc_config = (gdma_channel_alloc_config_t) {
-        .direction = GDMA_CHANNEL_DIRECTION_RX,
-        .sibling_chan = tx_chan,
-    };
-    TEST_ESP_OK(gdma_new_axi_channel(&rx_chan_alloc_config, &rx_chan));
+    TEST_ESP_OK(gdma_new_axi_channel(&chan_alloc_config, &tx_chan, &rx_chan));
 
     test_gdma_memcpy_from_to_psram(tx_chan, rx_chan);
 
diff --git a/components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c b/components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c
--- a/components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c
+++ b/components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c
@@ -127,18 +127,17 @@ TEST_CASE("GDMA CRC Calculation", "[GDMA][CRC]")
 {
     gdma_channel_handle_t tx_chan = NULL;
     gdma_channel_alloc_config_t tx_chan_alloc_config = {
-        .direction = GDMA_CHANNEL_DIRECTION_TX,
     };
 #if SOC_HAS(AHB_GDMA)
     printf("Test CRC calculation for AHB GDMA\r\n");
-    TEST_ESP_OK(gdma_new_ahb_channel(&tx_chan_alloc_config, &tx_chan));
+    TEST_ESP_OK(gdma_new_ahb_channel(&tx_chan_alloc_config, &tx_chan, NULL));
     test_gdma_crc_calculation(tx_chan, 4);
     TEST_ESP_OK(gdma_del_channel(tx_chan));
 #endif // SOC_HAS(AHB_GDMA)
 
 #if SOC_HAS(AXI_GDMA)
     printf("Test CRC calculation for AXI GDMA\r\n");
-    TEST_ESP_OK(gdma_new_axi_channel(&tx_chan_alloc_config, &tx_chan));
+    TEST_ESP_OK(gdma_new_axi_channel(&tx_chan_alloc_config, &tx_chan, NULL));
     test_gdma_crc_calculation(tx_chan, 3);
     TEST_ESP_OK(gdma_del_channel(tx_chan));
 #endif // SOC_HAS(AXI_GDMA)
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_CCACHE_ENABLE=1
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export CI_PIPELINE_ID=test-pipeline
export IDF_CI_BUILD=1
export IDF_SKIP_CHECK_SUBMODULES=1

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --user -r ${IDF_PATH}/tools/requirements/requirements.core.txt

# Install pytest-embedded suite if not already installed
python3 -m pip install --break-system-packages --user pytest>=7.0 pytest-embedded>=1.10.3 pytest-embedded-idf pytest-embedded-serial pexpect

# Initialize return code
rc=0

# Navigate to DMA test application directory
cd /testbed/components/esp_hw_support/test_apps/dma

# Build for multiple supported targets to validate test compilation
# According to collected info, supported targets are: esp32s2, esp32s3, esp32c2, esp32c3, esp32c5, esp32c6, esp32c61, esp32h2, esp32p4
# We'll test with a representative subset to validate compilation

declare -a targets=("esp32s3" "esp32c6" "esp32p4")

for target in "${targets[@]}"; do
    echo "=========================================="
    echo "Building DMA test application for ${target}"
    echo "=========================================="
    
    # Clean previous build artifacts
    rm -rf build sdkconfig sdkconfig.old
    
    # Set target and build
    idf.py set-target ${target}
    target_rc=$?
    
    if [ $target_rc -ne 0 ]; then
        echo "ERROR: Failed to set target ${target}"
        rc=1
        continue
    fi
    
    idf.py build
    build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: DMA test application build failed for ${target}"
        rc=1
    else
        echo "✓ DMA test application built successfully for ${target}"
        
        # Verify build artifacts exist
        if [ -f build/*.elf ]; then
            echo "✓ Build artifacts found for ${target}"
        else
            echo "✗ Build artifacts missing for ${target}"
            rc=1
        fi
        
        # Validate that test source files were compiled
        if [ -f build/compile_commands.json ]; then
            if grep -q "test_gdma.c" build/compile_commands.json 2>/dev/null; then
                echo "✓ test_gdma.c compiled for ${target}"
            else
                echo "⚠ test_gdma.c not found in build for ${target}"
            fi
            
            if grep -q "test_gdma_crc.c" build/compile_commands.json 2>/dev/null; then
                echo "✓ test_gdma_crc.c compiled for ${target}"
            else
                echo "⚠ test_gdma_crc.c not found in build for ${target}"
            fi
        fi
    fi
    
    echo ""
done

# Check for pytest runner and collect tests if available
if [ -f pytest_dma.py ]; then
    echo "=========================================="
    echo "Running pytest collection for DMA tests"
    echo "=========================================="
    pytest --no-header -rA --tb=short -p no:cacheprovider --collect-only pytest_dma.py
    pytest_rc=$?
    if [ $pytest_rc -ne 0 ]; then
        echo "WARNING: DMA pytest collection failed (may require hardware markers)"
        # Don't fail overall if collection fails, as it might require hardware
    fi
fi

# Summary
echo "=========================================="
echo "Test Validation Summary"
echo "=========================================="
echo "Overall result: $([ $rc -eq 0 ] && echo 'SUCCESS - Tests validated through successful compilation' || echo 'FAILED')"
echo ""
echo "Note: These are embedded hardware tests for ESP32 GDMA functionality."
echo "Actual test execution requires physical hardware with GDMA support, which is not available in Docker."
echo "This evaluation validates that the test code compiles correctly and is ready for hardware testing."

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 7c218e6531db2f511537739b8bcf5f197ce20952 "components/esp_hw_support/test_apps/dma/main/test_gdma.c" "components/esp_hw_support/test_apps/dma/main/test_gdma_crc.c"