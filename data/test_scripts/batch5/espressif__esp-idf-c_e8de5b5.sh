#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 56c3dc4755810a7d86800bed6794fb369da94e1a "components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c" "components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c" "components/spi_flash/test_apps/mspi_test/main/test_read_write.c" "tools/test_apps/system/memprot/main/esp32c3/test_panic.c" "tools/test_apps/system/memprot/main/esp32s2/test_panic.c" "tools/test_apps/system/memprot/main/esp32s3/test_panic.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c b/components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c
--- a/components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c
+++ b/components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c
@@ -10,7 +10,7 @@
 #include "freertos/task.h"
 #include "unity.h"
 #include "driver/gptimer.h"
-#include "soc/soc_caps_full.h"
+#include "hal/timer_periph.h"
 #include "esp_attr.h"
 
 #if CONFIG_GPTIMER_ISR_CACHE_SAFE
@@ -26,41 +26,41 @@ TEST_CASE("gptimer_set_get_raw_count", "[gptimer]")
         .direction = GPTIMER_COUNT_UP,
         .resolution_hz = 1 * 1000 * 1000,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&config, &timers[i]));
     }
 
     TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, gptimer_new_timer(&config, &timers[0]));
     unsigned long long get_value = 0;
     printf("check gptimer initial count value\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_get_raw_count(timers[i], &get_value));
         TEST_ASSERT_EQUAL(0, get_value);
     }
     unsigned long long set_values[] = {100, 500, 666};
     for (size_t j = 0; j < sizeof(set_values) / sizeof(set_values[0]); j++) {
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             printf("set raw count to %llu for gptimer %d\r\n", set_values[j], i);
             TEST_ESP_OK(gptimer_set_raw_count(timers[i], set_values[j]));
         }
         vTaskDelay(pdMS_TO_TICKS(10));
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_get_raw_count(timers[i], &get_value));
             printf("get raw count of gptimer %d: %llu\r\n", i, get_value);
             TEST_ASSERT_EQUAL(set_values[j], get_value);
         }
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
 }
 
 TEST_CASE("gptimer_wallclock_with_various_clock_sources", "[gptimer]")
 {
     gptimer_clock_source_t test_clk_srcs[] = SOC_GPTIMER_CLKS;
-    uint32_t timer_resolution_hz[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
+    uint32_t timer_resolution_hz[TIMER_LL_GPTIMERS_TOTAL];
 
     // test with various clock sources
     for (size_t i = 0; i < sizeof(test_clk_srcs) / sizeof(test_clk_srcs[0]); i++) {
@@ -69,66 +69,66 @@ TEST_CASE("gptimer_wallclock_with_various_clock_sources", "[gptimer]")
             .direction = GPTIMER_COUNT_UP,
             .resolution_hz = 1 * 1000 * 1000,
         };
-        gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
             TEST_ESP_OK(gptimer_get_resolution(timers[i], &timer_resolution_hz[i]));
         }
         // start timer before enable should fail
         TEST_ESP_ERR(ESP_ERR_INVALID_STATE, gptimer_start(timers[0]));
         printf("enable timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_enable(timers[i]));
         }
         printf("start timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_start(timers[i]));
         }
         esp_rom_delay_us(20 * 1000); // 20ms = 20_000 ticks
         uint64_t value = 0;
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_get_raw_count(timers[i], &value));
             // convert the raw count to us
             value = value * 1000000 / timer_resolution_hz[i];
             TEST_ASSERT_UINT_WITHIN(200, 20000, value);
         }
         printf("stop timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_stop(timers[i]));
         }
         printf("check whether timers have stopped\r\n");
         esp_rom_delay_us(20 * 1000);
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_get_raw_count(timers[i], &value));
             printf("get raw count of gptimer %d: %llu\r\n", i, value);
             // convert the raw count to us
             value = value * 1000000 / timer_resolution_hz[i];
             TEST_ASSERT_UINT_WITHIN(400, 20000, value);     //200 more threshold for cpu on stop process
         }
         printf("restart timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_start(timers[i]));
         }
         esp_rom_delay_us(20 * 1000);
         printf("stop timers again\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_stop(timers[i]));
         }
         printf("check whether timers have stopped\r\n");
         esp_rom_delay_us(20 * 1000);
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_get_raw_count(timers[i], &value));
             printf("get raw count of gptimer %d: %llu\r\n", i, value);
             // convert the raw count to us
             value = value * 1000000 / timer_resolution_hz[i];
             TEST_ASSERT_UINT_WITHIN(600, 40000, value);     //same 200 for cpu time
         }
         printf("disable timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_disable(timers[i]));
         }
         printf("delete timers\r\n");
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ESP_OK(gptimer_del_timer(timers[i]));
         }
     }
@@ -163,8 +163,8 @@ TEST_CASE("gptimer_stop_on_alarm", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
     }
 
@@ -174,46 +174,46 @@ TEST_CASE("gptimer_stop_on_alarm", "[gptimer]")
     gptimer_alarm_config_t alarm_config = {};
 
     printf("start timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         alarm_config.alarm_count = 100000 * (i + 1);
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         TEST_ESP_OK(gptimer_enable(timers[i]));
         TEST_ESP_OK(gptimer_start(timers[i]));
         printf("alarm value for gptimer %d: %llu\r\n", i, alarm_config.alarm_count);
     }
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(1000)));
     }
 
     printf("check whether the timers have stopped in the ISR\r\n");
     vTaskDelay(pdMS_TO_TICKS(20));
     unsigned long long value = 0;
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_get_raw_count(timers[i], &value));
         printf("get raw count of gptimer %d: %llu\r\n", i, value);
         TEST_ASSERT_UINT_WITHIN(GPTIMER_STOP_ON_ALARM_COUNT_DELTA, 100000 * (i + 1), value);
     }
 
     printf("restart timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         alarm_config.alarm_count = 100000 * (i + 1);
         // reset counter value to zero
         TEST_ESP_OK(gptimer_set_raw_count(timers[i], 0));
         TEST_ESP_OK(gptimer_start(timers[i]));
     }
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(1000)));
     }
     printf("check whether the timers have stopped in the ISR\r\n");
     vTaskDelay(pdMS_TO_TICKS(20));
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_get_raw_count(timers[i], &value));
         printf("get raw count of gptimer %d: %llu\r\n", i, value);
         TEST_ASSERT_UINT_WITHIN(GPTIMER_STOP_ON_ALARM_COUNT_DELTA, 100000 * (i + 1), value);
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
@@ -249,8 +249,8 @@ TEST_CASE("gptimer_auto_reload_on_alarm", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
     }
 
@@ -264,7 +264,7 @@ TEST_CASE("gptimer_auto_reload_on_alarm", "[gptimer]")
     };
 
     printf("start timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         TEST_ESP_OK(gptimer_enable(timers[i]));
@@ -277,7 +277,7 @@ TEST_CASE("gptimer_auto_reload_on_alarm", "[gptimer]")
         TEST_ESP_OK(gptimer_stop(timers[i]));
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
@@ -313,8 +313,8 @@ TEST_CASE("gptimer_one_shot_alarm", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         timer_config.intr_priority = i % 3 + 1; // test different priorities
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
     }
@@ -328,7 +328,7 @@ TEST_CASE("gptimer_one_shot_alarm", "[gptimer]")
     };
 
     printf("start timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         TEST_ESP_OK(gptimer_enable(timers[i]));
@@ -344,14 +344,14 @@ TEST_CASE("gptimer_one_shot_alarm", "[gptimer]")
     }
 
     printf("restart timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_start(timers[i]));
         // alarm should be triggered immediately as the counter value has across the target alarm value already
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, 0));
         TEST_ESP_OK(gptimer_stop(timers[i]));
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
@@ -379,8 +379,8 @@ TEST_CASE("gptimer_update_alarm_dynamically", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
     }
 
@@ -391,7 +391,7 @@ TEST_CASE("gptimer_update_alarm_dynamically", "[gptimer]")
         .alarm_count = 100000, // initial alarm count, 100ms
     };
     printf("start timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         TEST_ESP_OK(gptimer_enable(timers[i]));
@@ -406,7 +406,7 @@ TEST_CASE("gptimer_update_alarm_dynamically", "[gptimer]")
     }
 
     printf("restart timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_start(timers[i]));
         // check the alarm event for multiple times
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(500)));
@@ -417,7 +417,7 @@ TEST_CASE("gptimer_update_alarm_dynamically", "[gptimer]")
         TEST_ASSERT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(500)));
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
@@ -453,8 +453,8 @@ TEST_CASE("gptimer_count_down_reload", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_DOWN,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
         TEST_ESP_OK(gptimer_set_raw_count(timers[i], 200000));
     }
@@ -468,7 +468,7 @@ TEST_CASE("gptimer_count_down_reload", "[gptimer]")
         .flags.auto_reload_on_alarm = true,
     };
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         TEST_ESP_OK(gptimer_enable(timers[i]));
@@ -480,15 +480,15 @@ TEST_CASE("gptimer_count_down_reload", "[gptimer]")
     }
 
     printf("restart gptimer with previous configuration\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_start(timers[i]));
         // check twice, as it's a period event
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(1000)));
         TEST_ASSERT_NOT_EQUAL(0, ulTaskNotifyTake(pdFALSE, pdMS_TO_TICKS(1000)));
         TEST_ESP_OK(gptimer_stop(timers[i]));
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
@@ -513,14 +513,14 @@ TEST_CASE("gptimer_overflow", "[gptimer]")
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
     };
-    gptimer_handle_t timers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    gptimer_handle_t timers[TIMER_LL_GPTIMERS_TOTAL];
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&timer_config, &timers[i]));
     }
-#if SOC_MODULE_ATTR(GPTIMER, COUNTER_BIT_WIDTH) == 64
+#if TIMER_LL_COUNTER_BIT_WIDTH == 64
     uint64_t reload_at = UINT64_MAX - 100000;
 #else
-    uint64_t reload_at = (1ULL << SOC_MODULE_ATTR(GPTIMER, COUNTER_BIT_WIDTH)) - 100000;
+    uint64_t reload_at = (1ULL << TIMER_LL_COUNTER_BIT_WIDTH) - 100000;
 #endif
     gptimer_event_callbacks_t cbs = {
         .on_alarm = test_gptimer_overflow_reload_callback,
@@ -533,7 +533,7 @@ TEST_CASE("gptimer_overflow", "[gptimer]")
     // The counter should start from [COUNTER_MAX-100000] and overflows to [0] and continue, then reached to alarm value [100000], reloaded to [COUNTER_MAX-100000] automatically
     // thus the period should be 200ms
     printf("start timers\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_set_alarm_action(timers[i], &alarm_config));
         TEST_ESP_OK(gptimer_register_event_callbacks(timers[i], &cbs, task_handle));
         // we start from the reload value
@@ -544,7 +544,7 @@ TEST_CASE("gptimer_overflow", "[gptimer]")
         TEST_ESP_OK(gptimer_stop(timers[i]));
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_disable(timers[i]));
         TEST_ESP_OK(gptimer_del_timer(timers[i]));
     }
diff --git a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c
--- a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c
+++ b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c
@@ -18,7 +18,7 @@
 #include "unity.h"
 #include "esp_intr_alloc.h"
 #include "driver/gptimer.h"
-#include "soc/soc_caps_full.h"
+#include "hal/timer_periph.h"
 #include "soc/system_intr.h"
 #if SOC_GPSPI_SUPPORTED
 #include "soc/spi_periph.h"
@@ -38,17 +38,17 @@ static bool on_timer_alarm(gptimer_handle_t timer, const gptimer_alarm_event_dat
 
 static void timer_test(int flags)
 {
-    static int count[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)] = {0};
-    gptimer_handle_t gptimers[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
-    intr_handle_t inth[SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL)];
+    static int count[TIMER_LL_GPTIMERS_TOTAL] = {0};
+    gptimer_handle_t gptimers[TIMER_LL_GPTIMERS_TOTAL];
+    intr_handle_t inth[TIMER_LL_GPTIMERS_TOTAL];
 
     gptimer_config_t config = {
         .clk_src = GPTIMER_CLK_SRC_DEFAULT,
         .direction = GPTIMER_COUNT_UP,
         .resolution_hz = 1000000,
         .flags.intr_shared = (flags & ESP_INTR_FLAG_SHARED) == ESP_INTR_FLAG_SHARED,
     };
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_new_timer(&config, &gptimers[i]));
     }
     gptimer_alarm_config_t alarm_config = {
@@ -60,7 +60,7 @@ static void timer_test(int flags)
         .on_alarm = on_timer_alarm,
     };
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_register_event_callbacks(gptimers[i], &cbs, &count[i]));
         alarm_config.alarm_count += 10000 * i;
         TEST_ESP_OK(gptimer_set_alarm_action(gptimers[i], &alarm_config));
@@ -73,39 +73,39 @@ static void timer_test(int flags)
     if ((flags & ESP_INTR_FLAG_SHARED)) {
         /* Check that the allocated interrupts are actually shared */
         int intr_num = esp_intr_get_intno(inth[0]);
-        for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+        for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
             TEST_ASSERT_EQUAL(intr_num, esp_intr_get_intno(inth[i]));
         }
     }
 
     vTaskDelay(1000 / portTICK_PERIOD_MS);
     printf("Timer values after 1 sec:");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         printf(" %d", count[i]);
     }
     printf("\r\n");
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ASSERT_NOT_EQUAL(0, count[i]);
     }
 
     printf("Disabling timers' interrupt...\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         esp_intr_disable(inth[i]);
         count[i] = 0;
     }
 
     vTaskDelay(1000 / portTICK_PERIOD_MS);
     printf("Timer values after 1 sec:");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         printf(" %d", count[i]);
     }
     printf("\r\n");
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ASSERT_EQUAL(0, count[i]);
     }
 
-    for (int i = 0; i < SOC_MODULE_ATTR(GPTIMER, TIMERS_TOTAL); i++) {
+    for (int i = 0; i < TIMER_LL_GPTIMERS_TOTAL; i++) {
         TEST_ESP_OK(gptimer_stop(gptimers[i]));
         TEST_ESP_OK(gptimer_disable(gptimers[i]));
         TEST_ESP_OK(gptimer_del_timer(gptimers[i]));
@@ -256,7 +256,7 @@ void IRAM_ATTR int_handler1(void *arg)
 {
     intr_alloc_test_ctx_t *ctx = (intr_alloc_test_ctx_t *)arg;
     esp_rom_printf("handler 1 called.\n");
-    if ( ctx->flag1 ) {
+    if (ctx->flag1) {
         ctx->flag3 = true;
     } else {
         ctx->flag1 = true;
@@ -273,7 +273,7 @@ void IRAM_ATTR int_handler2(void *arg)
 {
     intr_alloc_test_ctx_t *ctx = (intr_alloc_test_ctx_t *)arg;
     esp_rom_printf("handler 2 called.\n");
-    if ( ctx->flag2 ) {
+    if (ctx->flag2) {
         ctx->flag4 = true;
     } else {
         ctx->flag2 = true;
@@ -321,7 +321,7 @@ TEST_CASE("allocate 2 handlers for a same source and remove the later one", "[in
 #endif
 
     vTaskDelay(100);
-    TEST_ASSERT( ctx.flag1 && ctx.flag2 );
+    TEST_ASSERT(ctx.flag1 && ctx.flag2);
 
     printf("remove intr 1.\n");
     r = esp_intr_free(handle2);
@@ -335,7 +335,7 @@ TEST_CASE("allocate 2 handlers for a same source and remove the later one", "[in
 #endif
 
     vTaskDelay(500);
-    TEST_ASSERT( ctx.flag3 && !ctx.flag4 );
+    TEST_ASSERT(ctx.flag3 && !ctx.flag4);
     printf("test passed.\n");
     esp_intr_free(handle1);
 }
diff --git a/components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c b/components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c
--- a/components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c
+++ b/components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c
@@ -17,7 +17,6 @@
 #include "esp_log.h"
 #include "esp_rom_spiflash.h"
 #include "esp_private/cache_utils.h"
-#include "soc/timer_periph.h"
 #include "esp_flash.h"
 #include "esp_partition.h"
 
diff --git a/components/spi_flash/test_apps/mspi_test/main/test_read_write.c b/components/spi_flash/test_apps/mspi_test/main/test_read_write.c
--- a/components/spi_flash/test_apps/mspi_test/main/test_read_write.c
+++ b/components/spi_flash/test_apps/mspi_test/main/test_read_write.c
@@ -15,12 +15,12 @@
 #include "unity.h"
 #include "spi_flash_mmap.h"
 #include "esp_private/cache_utils.h"
-#include "soc/timer_periph.h"
 #include "esp_attr.h"
 #include "esp_heap_caps.h"
 #include "esp_rom_spiflash.h"
 #include "esp_flash.h"
 #include "esp_partition.h"
+#include "soc/soc.h"
 
 #if CONFIG_IDF_TARGET_ESP32
 // Used for rom_fix function
diff --git a/tools/test_apps/system/memprot/main/esp32c3/test_panic.c b/tools/test_apps/system/memprot/main/esp32c3/test_panic.c
--- a/tools/test_apps/system/memprot/main/esp32c3/test_panic.c
+++ b/tools/test_apps/system/memprot/main/esp32c3/test_panic.c
@@ -22,7 +22,7 @@ void __real_esp_cpu_stall(int core_id);
 static void disable_all_wdts(void)
 {
     wdt_hal_context_t wdt0_context = {.inst = WDT_MWDT0, .mwdt_dev = &TIMERG0};
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     wdt_hal_context_t wdt1_context = {.inst = WDT_MWDT1, .mwdt_dev = &TIMERG1};
 #endif
 
@@ -32,7 +32,7 @@ static void disable_all_wdts(void)
     wdt_hal_disable(&wdt0_context);
     wdt_hal_write_protect_enable(&wdt0_context);
 
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     //Interrupt WDT is the Main Watchdog Timer of Timer Group 1
     wdt_hal_write_protect_disable(&wdt1_context);
     wdt_hal_disable(&wdt1_context);
diff --git a/tools/test_apps/system/memprot/main/esp32s2/test_panic.c b/tools/test_apps/system/memprot/main/esp32s2/test_panic.c
--- a/tools/test_apps/system/memprot/main/esp32s2/test_panic.c
+++ b/tools/test_apps/system/memprot/main/esp32s2/test_panic.c
@@ -20,7 +20,7 @@ void __real_esp_cpu_stall(int core_id);
 static void disable_all_wdts(void)
 {
     wdt_hal_context_t wdt0_context = {.inst = WDT_MWDT0, .mwdt_dev = &TIMERG0};
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     wdt_hal_context_t wdt1_context = {.inst = WDT_MWDT1, .mwdt_dev = &TIMERG1};
 #endif
 
@@ -30,7 +30,7 @@ static void disable_all_wdts(void)
     wdt_hal_disable(&wdt0_context);
     wdt_hal_write_protect_enable(&wdt0_context);
 
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     //Interrupt WDT is the Main Watchdog Timer of Timer Group 1
     wdt_hal_write_protect_disable(&wdt1_context);
     wdt_hal_disable(&wdt1_context);
diff --git a/tools/test_apps/system/memprot/main/esp32s3/test_panic.c b/tools/test_apps/system/memprot/main/esp32s3/test_panic.c
--- a/tools/test_apps/system/memprot/main/esp32s3/test_panic.c
+++ b/tools/test_apps/system/memprot/main/esp32s3/test_panic.c
@@ -20,7 +20,7 @@ void __real_esp_cpu_stall(int core_id);
 static void disable_all_wdts(void)
 {
     wdt_hal_context_t wdt0_context = {.inst = WDT_MWDT0, .mwdt_dev = &TIMERG0};
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     wdt_hal_context_t wdt1_context = {.inst = WDT_MWDT1, .mwdt_dev = &TIMERG1};
 #endif
 
@@ -30,7 +30,7 @@ static void disable_all_wdts(void)
     wdt_hal_disable(&wdt0_context);
     wdt_hal_write_protect_enable(&wdt0_context);
 
-#if SOC_MODULE_ATTR(TIMG, INST_NUM) >= 2
+#if TIMG_LL_GET(INST_NUM) >= 2
     //Interrupt WDT is the Main Watchdog Timer of Timer Group 1
     wdt_hal_write_protect_disable(&wdt1_context);
     wdt_hal_disable(&wdt1_context);
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
source /testbed/export.sh

# Initialize return code
rc=0

# Test 1: GPTIMER component
echo "=== Testing GPTIMER component ==="
cd /testbed/components/esp_driver_gptimer/test_apps/gptimer

echo "=== Building GPTIMER for ESP32 ==="
idf.py set-target esp32
idf.py build
gptimer_esp32_rc=$?
if [ $gptimer_esp32_rc -ne 0 ]; then
    echo "ERROR: GPTIMER ESP32 build failed with exit code $gptimer_esp32_rc"
    rc=1
else
    echo "SUCCESS: GPTIMER ESP32 build successful"
fi
idf.py fullclean

echo "=== Building GPTIMER for ESP32-C3 ==="
idf.py set-target esp32c3
idf.py build
gptimer_esp32c3_rc=$?
if [ $gptimer_esp32c3_rc -ne 0 ]; then
    echo "ERROR: GPTIMER ESP32-C3 build failed with exit code $gptimer_esp32c3_rc"
    rc=1
else
    echo "SUCCESS: GPTIMER ESP32-C3 build successful"
fi
idf.py fullclean

# Test 2: ESP HW Support component (intr_alloc)
echo "=== Testing ESP HW Support component ==="
cd /testbed/components/esp_hw_support/test_apps/esp_hw_support_unity_tests

echo "=== Building ESP HW Support for ESP32 ==="
idf.py set-target esp32
idf.py build
hw_support_esp32_rc=$?
if [ $hw_support_esp32_rc -ne 0 ]; then
    echo "ERROR: ESP HW Support ESP32 build failed with exit code $hw_support_esp32_rc"
    rc=1
else
    echo "SUCCESS: ESP HW Support ESP32 build successful"
fi
idf.py fullclean

echo "=== Building ESP HW Support for ESP32-S3 ==="
idf.py set-target esp32s3
idf.py build
hw_support_esp32s3_rc=$?
if [ $hw_support_esp32s3_rc -ne 0 ]; then
    echo "ERROR: ESP HW Support ESP32-S3 build failed with exit code $hw_support_esp32s3_rc"
    rc=1
else
    echo "SUCCESS: ESP HW Support ESP32-S3 build successful"
fi
idf.py fullclean

# Test 3: SPI Flash MSPI test component
echo "=== Testing SPI Flash MSPI component ==="
cd /testbed/components/spi_flash/test_apps/mspi_test

echo "=== Building MSPI test for ESP32 ==="
idf.py set-target esp32
idf.py build
mspi_esp32_rc=$?
if [ $mspi_esp32_rc -ne 0 ]; then
    echo "ERROR: MSPI ESP32 build failed with exit code $mspi_esp32_rc"
    rc=1
else
    echo "SUCCESS: MSPI ESP32 build successful"
fi
idf.py fullclean

echo "=== Building MSPI test for ESP32-C3 ==="
idf.py set-target esp32c3
idf.py build
mspi_esp32c3_rc=$?
if [ $mspi_esp32c3_rc -ne 0 ]; then
    echo "ERROR: MSPI ESP32-C3 build failed with exit code $mspi_esp32c3_rc"
    rc=1
else
    echo "SUCCESS: MSPI ESP32-C3 build successful"
fi
idf.py fullclean

# Test 4: Memprot test component (requires separate builds for each target)
echo "=== Testing Memprot component ==="
cd /testbed/tools/test_apps/system/memprot

echo "=== Building Memprot for ESP32-C3 ==="
idf.py set-target esp32c3
idf.py build
memprot_esp32c3_rc=$?
if [ $memprot_esp32c3_rc -ne 0 ]; then
    echo "ERROR: Memprot ESP32-C3 build failed with exit code $memprot_esp32c3_rc"
    rc=1
else
    echo "SUCCESS: Memprot ESP32-C3 build successful"
fi
idf.py fullclean

echo "=== Building Memprot for ESP32-S2 ==="
idf.py set-target esp32s2
idf.py build
memprot_esp32s2_rc=$?
if [ $memprot_esp32s2_rc -ne 0 ]; then
    echo "ERROR: Memprot ESP32-S2 build failed with exit code $memprot_esp32s2_rc"
    rc=1
else
    echo "SUCCESS: Memprot ESP32-S2 build successful"
fi
idf.py fullclean

echo "=== Building Memprot for ESP32-S3 ==="
idf.py set-target esp32s3
idf.py build
memprot_esp32s3_rc=$?
if [ $memprot_esp32s3_rc -ne 0 ]; then
    echo "ERROR: Memprot ESP32-S3 build failed with exit code $memprot_esp32s3_rc"
    rc=1
else
    echo "SUCCESS: Memprot ESP32-S3 build successful"
fi
idf.py fullclean

# Determine overall exit code
if [ $rc -eq 0 ]; then
    echo "=== All test applications built successfully ==="
    echo "=== Build verification confirms patches are valid ==="
else
    echo "=== One or more test applications failed to build ==="
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 56c3dc4755810a7d86800bed6794fb369da94e1a "components/esp_driver_gptimer/test_apps/gptimer/main/test_gptimer.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_intr_alloc.c" "components/spi_flash/test_apps/mspi_test/main/test_large_flash_writes.c" "components/spi_flash/test_apps/mspi_test/main/test_read_write.c" "tools/test_apps/system/memprot/main/esp32c3/test_panic.c" "tools/test_apps/system/memprot/main/esp32s2/test_panic.c" "tools/test_apps/system/memprot/main/esp32s3/test_panic.c"