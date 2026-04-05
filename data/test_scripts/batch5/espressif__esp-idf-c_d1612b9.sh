#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 74d5a120c3c7a6b6bb3b7c45c745ebea487fa658 "components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt b/components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt
@@ -9,9 +9,15 @@ project(mcpwm_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    set(MCPWM_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_mcpwm
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_mcpwm
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+    )
+    string(JOIN "," MCPWM_RTL_DIRS_JOINED ${MCPWM_RTL_DIRS})
     add_custom_target(check_test_app_sections ALL
                       COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_mcpwm/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                      --rtl-dirs ${MCPWM_RTL_DIRS_JOINED}
                       --elf-file ${CMAKE_BINARY_DIR}/mcpwm_test.elf
                       find-refs
                       --from-sections=.iram0.text
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c
@@ -9,7 +9,7 @@
 #include "freertos/task.h"
 #include "freertos/event_groups.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "esp_private/esp_clk.h"
 #include "driver/mcpwm_cap.h"
 #include "driver/mcpwm_sync.h"
@@ -22,12 +22,12 @@ TEST_CASE("mcpwm_capture_install_uninstall", "[mcpwm]")
     mcpwm_capture_timer_config_t cap_timer_config = {
         .clk_src = MCPWM_CAPTURE_CLK_SRC_DEFAULT,
     };
-    int total_cap_timers = SOC_MCPWM_GROUPS * SOC_MCPWM_CAPTURE_TIMERS_PER_GROUP;
+    int total_cap_timers = MCPWM_LL_GET(GROUP_NUM) * MCPWM_LL_GET(CAPTURE_TIMERS_PER_GROUP);
     mcpwm_cap_timer_handle_t cap_timers[total_cap_timers];
     int k = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         cap_timer_config.group_id = i;
-        for (int j = 0; j < SOC_MCPWM_CAPTURE_TIMERS_PER_GROUP; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(CAPTURE_TIMERS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_new_capture_timer(&cap_timer_config, &cap_timers[k++]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_capture_timer(&cap_timer_config, &cap_timers[0]));
@@ -39,17 +39,17 @@ TEST_CASE("mcpwm_capture_install_uninstall", "[mcpwm]")
         .prescale = 2,
         .flags.pos_edge = true,
     };
-    mcpwm_cap_channel_handle_t cap_channels[total_cap_timers][SOC_MCPWM_CAPTURE_CHANNELS_PER_TIMER];
+    mcpwm_cap_channel_handle_t cap_channels[total_cap_timers][MCPWM_LL_GET(CAPTURE_CHANNELS_PER_TIMER)];
     for (int i = 0; i < total_cap_timers; i++) {
-        for (int j = 0; j < SOC_MCPWM_CAPTURE_CHANNELS_PER_TIMER; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(CAPTURE_CHANNELS_PER_TIMER); j++) {
             TEST_ESP_OK(mcpwm_new_capture_channel(cap_timers[i], &cap_chan_config, &cap_channels[i][j]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_capture_channel(cap_timers[i], &cap_chan_config, &cap_channels[i][0]));
     }
 
     printf("uninstall mcpwm capture channels and timers\r\n");
     for (int i = 0; i < total_cap_timers; i++) {
-        for (int j = 0; j < SOC_MCPWM_CAPTURE_CHANNELS_PER_TIMER; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(CAPTURE_CHANNELS_PER_TIMER); j++) {
             TEST_ESP_OK(mcpwm_del_capture_channel(cap_channels[i][j]));
         }
         TEST_ESP_OK(mcpwm_del_capture_timer(cap_timers[i]));
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c
@@ -1,13 +1,13 @@
 /*
- * SPDX-FileCopyrightText: 2022-2023 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include <inttypes.h>
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_timer.h"
 #include "driver/mcpwm_oper.h"
 #include "driver/mcpwm_cmpr.h"
@@ -16,7 +16,7 @@ TEST_CASE("mcpwm_comparator_install_uninstall", "[mcpwm]")
 {
     mcpwm_timer_handle_t timer;
     mcpwm_oper_handle_t oper;
-    mcpwm_cmpr_handle_t comparators[SOC_MCPWM_COMPARATORS_PER_OPERATOR];
+    mcpwm_cmpr_handle_t comparators[MCPWM_LL_GET(COMPARATORS_PER_OPERATOR)];
 
     mcpwm_timer_config_t timer_config = {
         .group_id = 0,
@@ -34,7 +34,7 @@ TEST_CASE("mcpwm_comparator_install_uninstall", "[mcpwm]")
 
     printf("install comparator\r\n");
     mcpwm_comparator_config_t comparator_config = {};
-    for (int i = 0; i < SOC_MCPWM_COMPARATORS_PER_OPERATOR; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(COMPARATORS_PER_OPERATOR); i++) {
         TEST_ESP_OK(mcpwm_new_comparator(oper, &comparator_config, &comparators[i]));
     }
     TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_comparator(oper, &comparator_config, &comparators[0]));
@@ -45,7 +45,7 @@ TEST_CASE("mcpwm_comparator_install_uninstall", "[mcpwm]")
     printf("uninstall timer, operator and comparators\r\n");
     // can't delete operator if the comparators are still in working
     TEST_ESP_ERR(ESP_ERR_INVALID_STATE, mcpwm_del_operator(oper));
-    for (int i = 0; i < SOC_MCPWM_COMPARATORS_PER_OPERATOR; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(COMPARATORS_PER_OPERATOR); i++) {
         TEST_ESP_OK(mcpwm_del_comparator(comparators[i]));
     }
     TEST_ESP_OK(mcpwm_del_operator(oper));
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c
@@ -1,11 +1,12 @@
 /*
- * SPDX-FileCopyrightText: 2022-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_fault.h"
 #include "driver/mcpwm_oper.h"
 #include "driver/gpio.h"
@@ -17,12 +18,12 @@ TEST_CASE("mcpwm_fault_install_uninstall", "[mcpwm]")
     mcpwm_gpio_fault_config_t gpio_fault_config = {
         .gpio_num = TEST_FAULT_GPIO,
     };
-    int total_gpio_faults = SOC_MCPWM_GPIO_FAULTS_PER_GROUP * SOC_MCPWM_GROUPS;
+    int total_gpio_faults = MCPWM_LL_GET(GPIO_FAULTS_PER_GROUP) * MCPWM_LL_GET(GROUP_NUM);
     mcpwm_fault_handle_t gpio_faults[total_gpio_faults];
     int fault_itor = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         gpio_fault_config.group_id = i;
-        for (int j = 0; j < SOC_MCPWM_GPIO_FAULTS_PER_GROUP; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(GPIO_FAULTS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_new_gpio_fault(&gpio_fault_config, &gpio_faults[fault_itor++]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_gpio_fault(&gpio_fault_config, &gpio_faults[0]));
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c
@@ -1,12 +1,12 @@
 /*
- * SPDX-FileCopyrightText: 2022-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_cap.h"
 #include "driver/mcpwm_timer.h"
 #include "driver/mcpwm_oper.h"
@@ -28,19 +28,19 @@ TEST_CASE("mcpwm_generator_install_uninstall", "[mcpwm]")
     TEST_ESP_OK(mcpwm_new_operator(&oper_config, &oper));
 
     printf("create MCPWM generators from that operator\r\n");
-    mcpwm_gen_handle_t gens[SOC_MCPWM_GENERATORS_PER_OPERATOR];
+    mcpwm_gen_handle_t gens[MCPWM_LL_GET(GENERATORS_PER_OPERATOR)];
     mcpwm_generator_config_t gen_config = {
         .gen_gpio_num = TEST_PWMA_GPIO,
     };
-    for (int i = 0; i < SOC_MCPWM_GENERATORS_PER_OPERATOR; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GENERATORS_PER_OPERATOR); i++) {
         TEST_ESP_OK(mcpwm_new_generator(oper, &gen_config, &gens[i]));
     }
     TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_generator(oper, &gen_config, &gens[0]));
 
     printf("delete generators and operator\r\n");
     // can't delete operator if the generator is till in working
     TEST_ESP_ERR(ESP_ERR_INVALID_STATE, mcpwm_del_operator(oper));
-    for (int i = 0; i < SOC_MCPWM_GENERATORS_PER_OPERATOR; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GENERATORS_PER_OPERATOR); i++) {
         TEST_ESP_OK(mcpwm_del_generator(gens[i]));
     }
     TEST_ESP_OK(mcpwm_del_operator(oper));
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c
@@ -10,7 +10,6 @@
 #include "freertos/event_groups.h"
 #include "unity.h"
 #include "unity_test_utils.h"
-#include "soc/soc_caps.h"
 #include "esp_private/esp_clk.h"
 #include "driver/mcpwm_prelude.h"
 #include "driver/gpio.h"
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c
@@ -1,12 +1,12 @@
 /*
- * SPDX-FileCopyrightText: 2022-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_oper.h"
 #include "driver/mcpwm_timer.h"
 #include "driver/mcpwm_gen.h"
@@ -16,8 +16,8 @@
 
 TEST_CASE("mcpwm_operator_install_uninstall", "[mcpwm]")
 {
-    const int total_operators = SOC_MCPWM_OPERATORS_PER_GROUP * SOC_MCPWM_GROUPS;
-    mcpwm_timer_handle_t timers[SOC_MCPWM_GROUPS];
+    const int total_operators = MCPWM_LL_GET(OPERATORS_PER_GROUP) * MCPWM_LL_GET(GROUP_NUM);
+    mcpwm_timer_handle_t timers[MCPWM_LL_GET(GROUP_NUM)];
     mcpwm_oper_handle_t operators[total_operators];
 
     mcpwm_timer_config_t timer_config = {
@@ -29,36 +29,36 @@ TEST_CASE("mcpwm_operator_install_uninstall", "[mcpwm]")
     mcpwm_operator_config_t operator_config = {
     };
     printf("install one MCPWM timer for each group\r\n");
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         timer_config.group_id = i;
         TEST_ESP_OK(mcpwm_new_timer(&timer_config, &timers[i]));
     }
     printf("install MCPWM operators for each group\r\n");
     int k = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         operator_config.group_id = i;
-        for (int j = 0; j < SOC_MCPWM_OPERATORS_PER_GROUP; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(OPERATORS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_new_operator(&operator_config, &operators[k++]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_operator(&operator_config, &operators[0]));
     }
     printf("connect MCPWM timer and operators\r\n");
     k = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
-        for (int j = 0; j < SOC_MCPWM_OPERATORS_PER_GROUP; j++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
+        for (int j = 0; j < MCPWM_LL_GET(OPERATORS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_operator_connect_timer(operators[k++], timers[i]));
         }
     }
 
-#if SOC_MCPWM_GROUPS > 1
+#if MCPWM_LL_GET(GROUP_NUM) > 1
     TEST_ESP_ERR(ESP_ERR_INVALID_ARG, mcpwm_operator_connect_timer(operators[0], timers[1]));
 #endif
 
     printf("uninstall operators and timers\r\n");
     for (int i = 0; i < total_operators; i++) {
         TEST_ESP_OK(mcpwm_del_operator(operators[i]));
     }
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         TEST_ESP_OK(mcpwm_del_timer(timers[i]));
     }
 }
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c
@@ -1,12 +1,12 @@
 /*
- * SPDX-FileCopyrightText: 2022-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_timer.h"
 #include "driver/mcpwm_sync.h"
 #include "driver/gpio.h"
@@ -22,12 +22,12 @@ TEST_CASE("mcpwm_sync_source_install_uninstall", "[mcpwm]")
         .period_ticks = 200,
         .count_mode = MCPWM_TIMER_COUNT_MODE_UP,
     };
-    const int total_timers = SOC_MCPWM_TIMERS_PER_GROUP * SOC_MCPWM_GROUPS;
+    const int total_timers = MCPWM_LL_GET(TIMERS_PER_GROUP) * MCPWM_LL_GET(GROUP_NUM);
     mcpwm_timer_handle_t timers[total_timers];
     int k = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         timer_config.group_id = i;
-        for (int j = 0; j < SOC_MCPWM_TIMERS_PER_GROUP; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(TIMERS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_new_timer(&timer_config, &timers[k++]));
         }
     }
@@ -44,12 +44,12 @@ TEST_CASE("mcpwm_sync_source_install_uninstall", "[mcpwm]")
     mcpwm_gpio_sync_src_config_t gpio_sync_config = {
         .gpio_num = TEST_SYNC_GPIO,
     };
-    const int total_gpio_sync_srcs = SOC_MCPWM_GROUPS * SOC_MCPWM_GPIO_SYNCHROS_PER_GROUP;
+    const int total_gpio_sync_srcs = MCPWM_LL_GET(GROUP_NUM) * MCPWM_LL_GET(GPIO_SYNCHROS_PER_GROUP);
     mcpwm_sync_handle_t gpio_sync_srcs[total_gpio_sync_srcs];
     k = 0;
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
         gpio_sync_config.group_id = i;
-        for (int j = 0; j < SOC_MCPWM_GPIO_SYNCHROS_PER_GROUP; j++) {
+        for (int j = 0; j < MCPWM_LL_GET(GPIO_SYNCHROS_PER_GROUP); j++) {
             TEST_ESP_OK(mcpwm_new_gpio_sync_src(&gpio_sync_config, &gpio_sync_srcs[k++]));
         }
     }
@@ -123,9 +123,9 @@ TEST_CASE("mcpwm_gpio_sync_timer_phase_lock", "[mcpwm]")
     mcpwm_timer_sync_src_config_t sync_config = {
         .flags.propagate_input_sync = 1, // reuse the input sync source as the output sync trigger
     };
-    mcpwm_timer_handle_t timers[SOC_MCPWM_TIMERS_PER_GROUP];
-    mcpwm_sync_handle_t sync_srcs[SOC_MCPWM_TIMERS_PER_GROUP];
-    for (int i = 0; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    mcpwm_timer_handle_t timers[MCPWM_LL_GET(TIMERS_PER_GROUP)];
+    mcpwm_sync_handle_t sync_srcs[MCPWM_LL_GET(TIMERS_PER_GROUP)];
+    for (int i = 0; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         TEST_ESP_OK(mcpwm_new_timer(&timer_config, &timers[i]));
         TEST_ESP_OK(mcpwm_new_timer_sync_src(timers[i], &sync_config, &sync_srcs[i]));
     }
@@ -141,7 +141,7 @@ TEST_CASE("mcpwm_gpio_sync_timer_phase_lock", "[mcpwm]")
     TEST_ESP_OK(mcpwm_new_gpio_sync_src(&gpio_sync_config, &gpio_sync_src));
     // put the GPIO into initial state
     gpio_set_level(gpio_num, 0);
-    for (int i = 1; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    for (int i = 1; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         sync_phase_config.sync_src = sync_srcs[i - 1];
         TEST_ESP_OK(mcpwm_timer_set_phase_on_sync(timers[i], &sync_phase_config));
     }
@@ -151,10 +151,10 @@ TEST_CASE("mcpwm_gpio_sync_timer_phase_lock", "[mcpwm]")
     // simulate an GPIO sync signal
     gpio_set_level(gpio_num, 1);
     gpio_set_level(gpio_num, 0);
-    check_mcpwm_timer_phase(timers, SOC_MCPWM_CAPTURE_TIMERS_PER_GROUP, 100, MCPWM_TIMER_DIRECTION_UP);
+    check_mcpwm_timer_phase(timers, MCPWM_LL_GET(CAPTURE_TIMERS_PER_GROUP), 100, MCPWM_TIMER_DIRECTION_UP);
 
     TEST_ESP_OK(mcpwm_del_sync_src(gpio_sync_src));
-    for (int i = 0; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         TEST_ESP_OK(mcpwm_del_sync_src(sync_srcs[i]));
         TEST_ESP_OK(mcpwm_del_timer(timers[i]));
     }
@@ -175,8 +175,8 @@ TEST_CASE("mcpwm_timer_sync_timer_phase_lock", "[mcpwm]")
         .period_ticks = 500,
         .count_mode = MCPWM_TIMER_COUNT_MODE_UP_DOWN,
     };
-    mcpwm_timer_handle_t timers[SOC_MCPWM_TIMERS_PER_GROUP];
-    for (int i = 0; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    mcpwm_timer_handle_t timers[MCPWM_LL_GET(TIMERS_PER_GROUP)];
+    for (int i = 0; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         TEST_ESP_OK(mcpwm_new_timer(&timer_config, &timers[i]));
     }
 
@@ -191,7 +191,7 @@ TEST_CASE("mcpwm_timer_sync_timer_phase_lock", "[mcpwm]")
         .direction = MCPWM_TIMER_DIRECTION_DOWN,
         .sync_src = sync_src,
     };
-    for (int i = 1; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    for (int i = 1; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         TEST_ESP_OK(mcpwm_timer_set_phase_on_sync(timers[i], &sync_phase_config));
     }
 
@@ -203,7 +203,7 @@ TEST_CASE("mcpwm_timer_sync_timer_phase_lock", "[mcpwm]")
 
     TEST_ESP_OK(mcpwm_timer_disable(timers[0]));
     TEST_ESP_OK(mcpwm_del_sync_src(sync_src));
-    for (int i = 0; i < SOC_MCPWM_TIMERS_PER_GROUP; i++) {
+    for (int i = 0; i < MCPWM_LL_GET(TIMERS_PER_GROUP); i++) {
         TEST_ESP_OK(mcpwm_del_timer(timers[i]));
     }
 }
diff --git a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c
--- a/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c
+++ b/components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c
@@ -1,13 +1,13 @@
 /*
- * SPDX-FileCopyrightText: 2022-2023 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2022-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "freertos/event_groups.h"
 #include "unity.h"
-#include "soc/soc_caps.h"
+#include "hal/mcpwm_ll.h"
 #include "driver/mcpwm_timer.h"
 #include "esp_private/mcpwm.h"
 #include "test_mcpwm_utils.h"
@@ -20,14 +20,14 @@ TEST_CASE("mcpwm_timer_start_stop", "[mcpwm]")
         .period_ticks = 400,
         .count_mode = MCPWM_TIMER_COUNT_MODE_UP_DOWN,
     };
-    const int num_timers = SOC_MCPWM_TIMERS_PER_GROUP * SOC_MCPWM_GROUPS;
+    const int num_timers = MCPWM_LL_GET(TIMERS_PER_GROUP) * MCPWM_LL_GET(GROUP_NUM);
 
     printf("create mcpwm timer instances\r\n");
     mcpwm_timer_handle_t timers[num_timers];
-    for (int i = 0; i < SOC_MCPWM_GROUPS; i++) {
-        for (int j = 0; j < SOC_MCPWM_TIMERS_PER_GROUP; j++) {
+    for (int i = 0; i < MCPWM_LL_GET(GROUP_NUM); i++) {
+        for (int j = 0; j < MCPWM_LL_GET(TIMERS_PER_GROUP); j++) {
             config.group_id = i;
-            TEST_ESP_OK(mcpwm_new_timer(&config, &timers[i * SOC_MCPWM_TIMERS_PER_GROUP + j]));
+            TEST_ESP_OK(mcpwm_new_timer(&config, &timers[i * MCPWM_LL_GET(TIMERS_PER_GROUP) + j]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, mcpwm_new_timer(&config, &timers[0]));
     }
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up tools)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export CI_PIPELINE_ID=test-pipeline
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export IDF_SKIP_CHECK_SUBMODULES=1

# Initialize return code
rc=0

# Note: The MCPWM tests are hardware-in-the-loop (HIL) tests that require actual
# ESP32 hardware connected via serial port. These cannot run in a Docker container
# without physical devices. Instead, we validate the build process for supported
# targets to ensure the code compiles correctly and dependencies are properly configured.

# Test 1: Build mcpwm test app for esp32
echo "=== Testing mcpwm test app for esp32 ==="
cd /testbed/components/esp_driver_mcpwm/test_apps/mcpwm
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: mcpwm test app build failed for esp32"
fi

# Test 2: Build mcpwm test app for esp32s3
echo "=== Testing mcpwm test app for esp32s3 ==="
cd /testbed/components/esp_driver_mcpwm/test_apps/mcpwm
rm -rf build sdkconfig
idf.py set-target esp32s3
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: mcpwm test app build failed for esp32s3"
fi

# Test 3: Build mcpwm test app for esp32c6
echo "=== Testing mcpwm test app for esp32c6 ==="
cd /testbed/components/esp_driver_mcpwm/test_apps/mcpwm
rm -rf build sdkconfig
idf.py set-target esp32c6
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: mcpwm test app build failed for esp32c6"
fi

# Test 4: Build mcpwm test app for esp32p4
echo "=== Testing mcpwm test app for esp32p4 ==="
cd /testbed/components/esp_driver_mcpwm/test_apps/mcpwm
rm -rf build sdkconfig
idf.py set-target esp32p4
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: mcpwm test app build failed for esp32p4"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 74d5a120c3c7a6b6bb3b7c45c745ebea487fa658 "components/esp_driver_mcpwm/test_apps/mcpwm/CMakeLists.txt" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cap.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_cmpr.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_fault.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_gen.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_iram.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_oper.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_sync.c" "components/esp_driver_mcpwm/test_apps/mcpwm/main/test_mcpwm_timer.c"