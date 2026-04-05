#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target snapshot files to ensure clean state
git checkout e26f10fb2a36a1955c72a9b2ac9a6071a112f098 \
  "components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/calendar/__tests__/__snapshots__/demo.test.ts.snap"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -1,4 +1,4 @@
-// Jest Snapshot v1, https://goo.gl/fbAQLP
+// Jest Snapshot v1, https://jestjs.io/docs/snapshot-testing
 
 exports[`renders components/calendar/demo/basic.tsx extend context correctly 1`] = `
 <div
@@ -6402,860 +6402,845 @@ exports[`renders components/calendar/demo/customize-header.tsx extend context co
         Custom header
       </h4>
       <div
-        class="ant-row"
-        style="margin-left: -4px; margin-right: -4px;"
+        class="ant-flex"
+        style="gap: 8px;"
       >
         <div
-          class="ant-col"
-          style="padding-left: 4px; padding-right: 4px;"
+          class="ant-radio-group ant-radio-group-outline ant-radio-group-small"
         >
-          <div
-            class="ant-radio-group ant-radio-group-outline ant-radio-group-small"
+          <label
+            class="ant-radio-button-wrapper ant-radio-button-wrapper-checked"
           >
-            <label
-              class="ant-radio-button-wrapper ant-radio-button-wrapper-checked"
+            <span
+              class="ant-radio-button ant-radio-button-checked"
             >
+              <input
+                checked=""
+                class="ant-radio-button-input"
+                name="test-id"
+                type="radio"
+                value="month"
+              />
               <span
-                class="ant-radio-button ant-radio-button-checked"
-              >
-                <input
-                  checked=""
-                  class="ant-radio-button-input"
-                  name="test-id"
-                  type="radio"
-                  value="month"
-                />
-                <span
-                  class="ant-radio-button-inner"
-                />
-              </span>
+                class="ant-radio-button-inner"
+              />
+            </span>
+            <span
+              class="ant-radio-button-label"
+            >
+              Month
+            </span>
+          </label>
+          <label
+            class="ant-radio-button-wrapper"
+          >
+            <span
+              class="ant-radio-button"
+            >
+              <input
+                class="ant-radio-button-input"
+                name="test-id"
+                type="radio"
+                value="year"
+              />
               <span
-                class="ant-radio-button-label"
-              >
-                Month
-              </span>
-            </label>
-            <label
-              class="ant-radio-button-wrapper"
+                class="ant-radio-button-inner"
+              />
+            </span>
+            <span
+              class="ant-radio-button-label"
+            >
+              Year
+            </span>
+          </label>
+        </div>
+        <div
+          class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
+        >
+          <div
+            class="ant-select-selector"
+          >
+            <span
+              class="ant-select-selection-wrap"
             >
               <span
-                class="ant-radio-button"
+                class="ant-select-selection-search"
               >
                 <input
-                  class="ant-radio-button-input"
-                  name="test-id"
-                  type="radio"
-                  value="year"
-                />
-                <span
-                  class="ant-radio-button-inner"
+                  aria-autocomplete="list"
+                  aria-controls="rc_select_TEST_OR_SSR_list"
+                  aria-expanded="false"
+                  aria-haspopup="listbox"
+                  aria-owns="rc_select_TEST_OR_SSR_list"
+                  autocomplete="off"
+                  class="ant-select-selection-search-input"
+                  id="rc_select_TEST_OR_SSR"
+                  readonly=""
+                  role="combobox"
+                  style="opacity: 0;"
+                  type="search"
+                  unselectable="on"
+                  value=""
                 />
               </span>
               <span
-                class="ant-radio-button-label"
+                class="ant-select-selection-item"
+                title="2016"
               >
-                Year
+                2016
               </span>
-            </label>
+            </span>
           </div>
-        </div>
-        <div
-          class="ant-col"
-          style="padding-left: 4px; padding-right: 4px;"
-        >
           <div
-            class="ant-select ant-select-sm ant-select-outlined my-year-select ant-select-single ant-select-show-arrow"
+            class="ant-select-dropdown ant-slide-up-appear ant-slide-up-appear-prepare ant-slide-up ant-select-dropdown-placement-bottomLeft"
+            style="--arrow-x: 0px; --arrow-y: 0px; left: -1000vw; top: -1000vh; box-sizing: border-box;"
           >
-            <div
-              class="ant-select-selector"
-            >
-              <span
-                class="ant-select-selection-wrap"
-              >
-                <span
-                  class="ant-select-selection-search"
-                >
-                  <input
-                    aria-autocomplete="list"
-                    aria-controls="rc_select_TEST_OR_SSR_list"
-                    aria-expanded="false"
-                    aria-haspopup="listbox"
-                    aria-owns="rc_select_TEST_OR_SSR_list"
-                    autocomplete="off"
-                    class="ant-select-selection-search-input"
-                    id="rc_select_TEST_OR_SSR"
-                    readonly=""
-                    role="combobox"
-                    style="opacity: 0;"
-                    type="search"
-                    unselectable="on"
-                    value=""
-                  />
-                </span>
-                <span
-                  class="ant-select-selection-item"
-                  title="2016"
-                >
-                  2016
-                </span>
-              </span>
-            </div>
-            <div
-              class="ant-select-dropdown ant-slide-up-appear ant-slide-up-appear-prepare ant-slide-up ant-select-dropdown-placement-bottomLeft"
-              style="--arrow-x: 0px; --arrow-y: 0px; left: -1000vw; top: -1000vh; box-sizing: border-box;"
-            >
-              <div>
+            <div>
+              <div
+                class="rc-virtual-list"
+                style="position: relative;"
+              >
                 <div
-                  class="rc-virtual-list"
-                  style="position: relative;"
+                  class="rc-virtual-list-holder"
+                  style="max-height: 256px; overflow-y: auto;"
                 >
-                  <div
-                    class="rc-virtual-list-holder"
-                    style="max-height: 256px; overflow-y: auto;"
-                  >
-                    <div>
+                  <div>
+                    <div
+                      class="rc-virtual-list-holder-inner"
+                      id="rc_select_TEST_OR_SSR_list"
+                      role="listbox"
+                      style="display: flex; flex-direction: column;"
+                    >
                       <div
-                        class="rc-virtual-list-holder-inner"
-                        id="rc_select_TEST_OR_SSR_list"
-                        role="listbox"
-                        style="display: flex; flex-direction: column;"
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option ant-select-item-option-active"
+                        id="rc_select_TEST_OR_SSR_list_0"
+                        role="option"
+                        title="2006"
                       >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item ant-select-item-option-active"
-                          id="rc_select_TEST_OR_SSR_list_0"
-                          role="option"
-                          title="2006"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2006
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2006
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_1"
+                        role="option"
+                        title="2007"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_1"
-                          role="option"
-                          title="2007"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2007
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2007
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_2"
+                        role="option"
+                        title="2008"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_2"
-                          role="option"
-                          title="2008"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2008
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2008
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_3"
+                        role="option"
+                        title="2009"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_3"
-                          role="option"
-                          title="2009"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2009
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2009
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_4"
+                        role="option"
+                        title="2010"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_4"
-                          role="option"
-                          title="2010"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2010
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2010
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_5"
+                        role="option"
+                        title="2011"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_5"
-                          role="option"
-                          title="2011"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2011
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2011
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_6"
+                        role="option"
+                        title="2012"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_6"
-                          role="option"
-                          title="2012"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2012
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2012
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_7"
+                        role="option"
+                        title="2013"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_7"
-                          role="option"
-                          title="2013"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2013
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2013
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_8"
+                        role="option"
+                        title="2014"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_8"
-                          role="option"
-                          title="2014"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2014
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2014
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_9"
+                        role="option"
+                        title="2015"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_9"
-                          role="option"
-                          title="2015"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2015
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2015
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="true"
+                        class="ant-select-item ant-select-item-option ant-select-item-option-selected"
+                        id="rc_select_TEST_OR_SSR_list_10"
+                        role="option"
+                        title="2016"
+                      >
                         <div
-                          aria-selected="true"
-                          class="ant-select-item ant-select-item-option year-item ant-select-item-option-selected"
-                          id="rc_select_TEST_OR_SSR_list_10"
-                          role="option"
-                          title="2016"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2016
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2016
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_11"
+                        role="option"
+                        title="2017"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_11"
-                          role="option"
-                          title="2017"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2017
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2017
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_12"
+                        role="option"
+                        title="2018"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_12"
-                          role="option"
-                          title="2018"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2018
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2018
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_13"
+                        role="option"
+                        title="2019"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_13"
-                          role="option"
-                          title="2019"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2019
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2019
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_14"
+                        role="option"
+                        title="2020"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_14"
-                          role="option"
-                          title="2020"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2020
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2020
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_15"
+                        role="option"
+                        title="2021"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_15"
-                          role="option"
-                          title="2021"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2021
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2021
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_16"
+                        role="option"
+                        title="2022"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_16"
-                          role="option"
-                          title="2022"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2022
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2022
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_17"
+                        role="option"
+                        title="2023"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_17"
-                          role="option"
-                          title="2023"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2023
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2023
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_18"
+                        role="option"
+                        title="2024"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_18"
-                          role="option"
-                          title="2024"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2024
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2024
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_19"
+                        role="option"
+                        title="2025"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option year-item"
-                          id="rc_select_TEST_OR_SSR_list_19"
-                          role="option"
-                          title="2025"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            2025
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          2025
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
                       </div>
                     </div>
                   </div>
                 </div>
               </div>
             </div>
+          </div>
+          <span
+            aria-hidden="true"
+            class="ant-select-arrow"
+            style="user-select: none;"
+            unselectable="on"
+          >
             <span
-              aria-hidden="true"
-              class="ant-select-arrow"
-              style="user-select: none;"
-              unselectable="on"
+              aria-label="down"
+              class="anticon anticon-down ant-select-suffix"
+              role="img"
             >
-              <span
-                aria-label="down"
-                class="anticon anticon-down ant-select-suffix"
-                role="img"
-              >
-                <svg
-                  aria-hidden="true"
-                  data-icon="down"
-                  fill="currentColor"
-                  focusable="false"
-                  height="1em"
-                  viewBox="64 64 896 896"
-                  width="1em"
-                >
-                  <path
-                    d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
-                  />
-                </svg>
-              </span>
+              <svg
+                aria-hidden="true"
+                data-icon="down"
+                fill="currentColor"
+                focusable="false"
+                height="1em"
+                viewBox="64 64 896 896"
+                width="1em"
+              >
+                <path
+                  d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
+                />
+              </svg>
             </span>
-          </div>
+          </span>
         </div>
         <div
-          class="ant-col"
-          style="padding-left: 4px; padding-right: 4px;"
+          class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
         >
           <div
-            class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
+            class="ant-select-selector"
           >
-            <div
-              class="ant-select-selector"
+            <span
+              class="ant-select-selection-wrap"
             >
               <span
-                class="ant-select-selection-wrap"
-              >
-                <span
-                  class="ant-select-selection-search"
-                >
-                  <input
-                    aria-autocomplete="list"
-                    aria-controls="rc_select_TEST_OR_SSR_list"
-                    aria-expanded="false"
-                    aria-haspopup="listbox"
-                    aria-owns="rc_select_TEST_OR_SSR_list"
-                    autocomplete="off"
-                    class="ant-select-selection-search-input"
-                    id="rc_select_TEST_OR_SSR"
-                    readonly=""
-                    role="combobox"
-                    style="opacity: 0;"
-                    type="search"
-                    unselectable="on"
-                    value=""
-                  />
-                </span>
-                <span
-                  class="ant-select-selection-item"
-                  title="Nov"
-                >
-                  Nov
-                </span>
+                class="ant-select-selection-search"
+              >
+                <input
+                  aria-autocomplete="list"
+                  aria-controls="rc_select_TEST_OR_SSR_list"
+                  aria-expanded="false"
+                  aria-haspopup="listbox"
+                  aria-owns="rc_select_TEST_OR_SSR_list"
+                  autocomplete="off"
+                  class="ant-select-selection-search-input"
+                  id="rc_select_TEST_OR_SSR"
+                  readonly=""
+                  role="combobox"
+                  style="opacity: 0;"
+                  type="search"
+                  unselectable="on"
+                  value=""
+                />
               </span>
-            </div>
-            <div
-              class="ant-select-dropdown ant-slide-up-appear ant-slide-up-appear-prepare ant-slide-up ant-select-dropdown-placement-bottomLeft"
-              style="--arrow-x: 0px; --arrow-y: 0px; left: -1000vw; top: -1000vh; box-sizing: border-box;"
-            >
-              <div>
+              <span
+                class="ant-select-selection-item"
+                title="Nov"
+              >
+                Nov
+              </span>
+            </span>
+          </div>
+          <div
+            class="ant-select-dropdown ant-slide-up-appear ant-slide-up-appear-prepare ant-slide-up ant-select-dropdown-placement-bottomLeft"
+            style="--arrow-x: 0px; --arrow-y: 0px; left: -1000vw; top: -1000vh; box-sizing: border-box;"
+          >
+            <div>
+              <div
+                class="rc-virtual-list"
+                style="position: relative;"
+              >
                 <div
-                  class="rc-virtual-list"
-                  style="position: relative;"
+                  class="rc-virtual-list-holder"
+                  style="max-height: 256px; overflow-y: auto;"
                 >
-                  <div
-                    class="rc-virtual-list-holder"
-                    style="max-height: 256px; overflow-y: auto;"
-                  >
-                    <div>
+                  <div>
+                    <div
+                      class="rc-virtual-list-holder-inner"
+                      id="rc_select_TEST_OR_SSR_list"
+                      role="listbox"
+                      style="display: flex; flex-direction: column;"
+                    >
                       <div
-                        class="rc-virtual-list-holder-inner"
-                        id="rc_select_TEST_OR_SSR_list"
-                        role="listbox"
-                        style="display: flex; flex-direction: column;"
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option ant-select-item-option-active"
+                        id="rc_select_TEST_OR_SSR_list_0"
+                        role="option"
+                        title="Jan"
                       >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item ant-select-item-option-active"
-                          id="rc_select_TEST_OR_SSR_list_0"
-                          role="option"
-                          title="Jan"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Jan
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Jan
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_1"
+                        role="option"
+                        title="Feb"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_1"
-                          role="option"
-                          title="Feb"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Feb
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Feb
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_2"
+                        role="option"
+                        title="Mar"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_2"
-                          role="option"
-                          title="Mar"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Mar
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Mar
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_3"
+                        role="option"
+                        title="Apr"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_3"
-                          role="option"
-                          title="Apr"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Apr
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Apr
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_4"
+                        role="option"
+                        title="May"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_4"
-                          role="option"
-                          title="May"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            May
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          May
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_5"
+                        role="option"
+                        title="Jun"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_5"
-                          role="option"
-                          title="Jun"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Jun
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Jun
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_6"
+                        role="option"
+                        title="Jul"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_6"
-                          role="option"
-                          title="Jul"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Jul
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Jul
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_7"
+                        role="option"
+                        title="Aug"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_7"
-                          role="option"
-                          title="Aug"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Aug
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Aug
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_8"
+                        role="option"
+                        title="Sep"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_8"
-                          role="option"
-                          title="Sep"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Sep
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Sep
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_9"
+                        role="option"
+                        title="Oct"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_9"
-                          role="option"
-                          title="Oct"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Oct
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Oct
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="true"
+                        class="ant-select-item ant-select-item-option ant-select-item-option-selected"
+                        id="rc_select_TEST_OR_SSR_list_10"
+                        role="option"
+                        title="Nov"
+                      >
                         <div
-                          aria-selected="true"
-                          class="ant-select-item ant-select-item-option month-item ant-select-item-option-selected"
-                          id="rc_select_TEST_OR_SSR_list_10"
-                          role="option"
-                          title="Nov"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Nov
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Nov
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
+                      </div>
+                      <div
+                        aria-selected="false"
+                        class="ant-select-item ant-select-item-option"
+                        id="rc_select_TEST_OR_SSR_list_11"
+                        role="option"
+                        title="Dec"
+                      >
                         <div
-                          aria-selected="false"
-                          class="ant-select-item ant-select-item-option month-item"
-                          id="rc_select_TEST_OR_SSR_list_11"
-                          role="option"
-                          title="Dec"
+                          class="ant-select-item-option-content"
                         >
-                          <div
-                            class="ant-select-item-option-content"
-                          >
-                            Dec
-                          </div>
-                          <span
-                            aria-hidden="true"
-                            class="ant-select-item-option-state"
-                            style="user-select: none;"
-                            unselectable="on"
-                          />
+                          Dec
                         </div>
+                        <span
+                          aria-hidden="true"
+                          class="ant-select-item-option-state"
+                          style="user-select: none;"
+                          unselectable="on"
+                        />
                       </div>
                     </div>
                   </div>
                 </div>
               </div>
             </div>
+          </div>
+          <span
+            aria-hidden="true"
+            class="ant-select-arrow"
+            style="user-select: none;"
+            unselectable="on"
+          >
             <span
-              aria-hidden="true"
-              class="ant-select-arrow"
-              style="user-select: none;"
-              unselectable="on"
+              aria-label="down"
+              class="anticon anticon-down ant-select-suffix"
+              role="img"
             >
-              <span
-                aria-label="down"
-                class="anticon anticon-down ant-select-suffix"
-                role="img"
-              >
-                <svg
-                  aria-hidden="true"
-                  data-icon="down"
-                  fill="currentColor"
-                  focusable="false"
-                  height="1em"
-                  viewBox="64 64 896 896"
-                  width="1em"
-                >
-                  <path
-                    d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
-                  />
-                </svg>
-              </span>
+              <svg
+                aria-hidden="true"
+                data-icon="down"
+                fill="currentColor"
+                focusable="false"
+                height="1em"
+                viewBox="64 64 896 896"
+                width="1em"
+              >
+                <path
+                  d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
+                />
+              </svg>
             </span>
-          </div>
+          </span>
         </div>
       </div>
     </div>
diff --git a/components/calendar/__tests__/__snapshots__/demo.test.ts.snap b/components/calendar/__tests__/__snapshots__/demo.test.ts.snap
--- a/components/calendar/__tests__/__snapshots__/demo.test.ts.snap
+++ b/components/calendar/__tests__/__snapshots__/demo.test.ts.snap
@@ -1,4 +1,4 @@
-// Jest Snapshot v1, https://goo.gl/fbAQLP
+// Jest Snapshot v1, https://jestjs.io/docs/snapshot-testing
 
 exports[`renders components/calendar/demo/basic.tsx correctly 1`] = `
 <div
@@ -3844,198 +3844,183 @@ exports[`renders components/calendar/demo/customize-header.tsx correctly 1`] = `
         Custom header
       </h4>
       <div
-        class="ant-row"
-        style="margin-left:-4px;margin-right:-4px"
+        class="ant-flex"
+        style="gap:8px"
       >
         <div
-          class="ant-col"
-          style="padding-left:4px;padding-right:4px"
+          class="ant-radio-group ant-radio-group-outline ant-radio-group-small"
         >
-          <div
-            class="ant-radio-group ant-radio-group-outline ant-radio-group-small"
+          <label
+            class="ant-radio-button-wrapper ant-radio-button-wrapper-checked"
           >
-            <label
-              class="ant-radio-button-wrapper ant-radio-button-wrapper-checked"
+            <span
+              class="ant-radio-button ant-radio-button-checked"
             >
+              <input
+                checked=""
+                class="ant-radio-button-input"
+                name="test-id"
+                type="radio"
+                value="month"
+              />
               <span
-                class="ant-radio-button ant-radio-button-checked"
-              >
-                <input
-                  checked=""
-                  class="ant-radio-button-input"
-                  name="test-id"
-                  type="radio"
-                  value="month"
-                />
-                <span
-                  class="ant-radio-button-inner"
-                />
-              </span>
-              <span
-                class="ant-radio-button-label"
-              >
-                Month
-              </span>
-            </label>
-            <label
-              class="ant-radio-button-wrapper"
+                class="ant-radio-button-inner"
+              />
+            </span>
+            <span
+              class="ant-radio-button-label"
             >
+              Month
+            </span>
+          </label>
+          <label
+            class="ant-radio-button-wrapper"
+          >
+            <span
+              class="ant-radio-button"
+            >
+              <input
+                class="ant-radio-button-input"
+                name="test-id"
+                type="radio"
+                value="year"
+              />
               <span
-                class="ant-radio-button"
-              >
-                <input
-                  class="ant-radio-button-input"
-                  name="test-id"
-                  type="radio"
-                  value="year"
-                />
-                <span
-                  class="ant-radio-button-inner"
-                />
-              </span>
-              <span
-                class="ant-radio-button-label"
-              >
-                Year
-              </span>
-            </label>
-          </div>
+                class="ant-radio-button-inner"
+              />
+            </span>
+            <span
+              class="ant-radio-button-label"
+            >
+              Year
+            </span>
+          </label>
         </div>
         <div
-          class="ant-col"
-          style="padding-left:4px;padding-right:4px"
+          class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
         >
           <div
-            class="ant-select ant-select-sm ant-select-outlined my-year-select ant-select-single ant-select-show-arrow"
+            class="ant-select-selector"
           >
-            <div
-              class="ant-select-selector"
+            <span
+              class="ant-select-selection-wrap"
             >
               <span
-                class="ant-select-selection-wrap"
+                class="ant-select-selection-search"
               >
-                <span
-                  class="ant-select-selection-search"
-                >
-                  <input
-                    aria-autocomplete="list"
-                    aria-controls="undefined_list"
-                    aria-expanded="false"
-                    aria-haspopup="listbox"
-                    aria-owns="undefined_list"
-                    autocomplete="off"
-                    class="ant-select-selection-search-input"
-                    readonly=""
-                    role="combobox"
-                    style="opacity:0"
-                    type="search"
-                    unselectable="on"
-                    value=""
-                  />
-                </span>
-                <span
-                  class="ant-select-selection-item"
-                  title="2016"
-                >
-                  2016
-                </span>
+                <input
+                  aria-autocomplete="list"
+                  aria-controls="undefined_list"
+                  aria-expanded="false"
+                  aria-haspopup="listbox"
+                  aria-owns="undefined_list"
+                  autocomplete="off"
+                  class="ant-select-selection-search-input"
+                  readonly=""
+                  role="combobox"
+                  style="opacity:0"
+                  type="search"
+                  unselectable="on"
+                  value=""
+                />
               </span>
-            </div>
-            <span
-              aria-hidden="true"
-              class="ant-select-arrow"
-              style="user-select:none;-webkit-user-select:none"
-              unselectable="on"
-            >
               <span
-                aria-label="down"
-                class="anticon anticon-down ant-select-suffix"
-                role="img"
+                class="ant-select-selection-item"
+                title="2016"
               >
-                <svg
-                  aria-hidden="true"
-                  data-icon="down"
-                  fill="currentColor"
-                  focusable="false"
-                  height="1em"
-                  viewBox="64 64 896 896"
-                  width="1em"
-                >
-                  <path
-                    d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
-                  />
-                </svg>
+                2016
               </span>
             </span>
           </div>
+          <span
+            aria-hidden="true"
+            class="ant-select-arrow"
+            style="user-select:none;-webkit-user-select:none"
+            unselectable="on"
+          >
+            <span
+              aria-label="down"
+              class="anticon anticon-down ant-select-suffix"
+              role="img"
+            >
+              <svg
+                aria-hidden="true"
+                data-icon="down"
+                fill="currentColor"
+                focusable="false"
+                height="1em"
+                viewBox="64 64 896 896"
+                width="1em"
+              >
+                <path
+                  d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
+                />
+              </svg>
+            </span>
+          </span>
         </div>
         <div
-          class="ant-col"
-          style="padding-left:4px;padding-right:4px"
+          class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
         >
           <div
-            class="ant-select ant-select-sm ant-select-outlined ant-select-single ant-select-show-arrow"
+            class="ant-select-selector"
           >
-            <div
-              class="ant-select-selector"
+            <span
+              class="ant-select-selection-wrap"
             >
               <span
-                class="ant-select-selection-wrap"
+                class="ant-select-selection-search"
               >
-                <span
-                  class="ant-select-selection-search"
-                >
-                  <input
-                    aria-autocomplete="list"
-                    aria-controls="undefined_list"
-                    aria-expanded="false"
-                    aria-haspopup="listbox"
-                    aria-owns="undefined_list"
-                    autocomplete="off"
-                    class="ant-select-selection-search-input"
-                    readonly=""
-                    role="combobox"
-                    style="opacity:0"
-                    type="search"
-                    unselectable="on"
-                    value=""
-                  />
-                </span>
-                <span
-                  class="ant-select-selection-item"
-                  title="Nov"
-                >
-                  Nov
-                </span>
+                <input
+                  aria-autocomplete="list"
+                  aria-controls="undefined_list"
+                  aria-expanded="false"
+                  aria-haspopup="listbox"
+                  aria-owns="undefined_list"
+                  autocomplete="off"
+                  class="ant-select-selection-search-input"
+                  readonly=""
+                  role="combobox"
+                  style="opacity:0"
+                  type="search"
+                  unselectable="on"
+                  value=""
+                />
               </span>
-            </div>
-            <span
-              aria-hidden="true"
-              class="ant-select-arrow"
-              style="user-select:none;-webkit-user-select:none"
-              unselectable="on"
-            >
               <span
-                aria-label="down"
-                class="anticon anticon-down ant-select-suffix"
-                role="img"
+                class="ant-select-selection-item"
+                title="Nov"
               >
-                <svg
-                  aria-hidden="true"
-                  data-icon="down"
-                  fill="currentColor"
-                  focusable="false"
-                  height="1em"
-                  viewBox="64 64 896 896"
-                  width="1em"
-                >
-                  <path
-                    d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
-                  />
-                </svg>
+                Nov
               </span>
             </span>
           </div>
+          <span
+            aria-hidden="true"
+            class="ant-select-arrow"
+            style="user-select:none;-webkit-user-select:none"
+            unselectable="on"
+          >
+            <span
+              aria-label="down"
+              class="anticon anticon-down ant-select-suffix"
+              role="img"
+            >
+              <svg
+                aria-hidden="true"
+                data-icon="down"
+                fill="currentColor"
+                focusable="false"
+                height="1em"
+                viewBox="64 64 896 896"
+                width="1em"
+              >
+                <path
+                  d="M884 256h-75c-5.1 0-9.9 2.5-12.9 6.6L512 654.2 227.9 262.6c-3-4.1-7.8-6.6-12.9-6.6h-75c-6.5 0-10.3 7.4-6.5 12.7l352.6 486.1c12.8 17.6 39 17.6 51.7 0l352.6-486.1c3.9-5.3.1-12.7-6.4-12.7z"
+                />
+              </svg>
+            </span>
+          </span>
         </div>
       </div>
     </div>
EOF_114329324912

# Run the target tests using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
# Running both test files in a single command for efficiency
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/calendar/__tests__/demo.test.ts" \
  "components/calendar/__tests__/demo-extend.test.ts"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original snapshot files
git checkout e26f10fb2a36a1955c72a9b2ac9a6071a112f098 \
  "components/calendar/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/calendar/__tests__/__snapshots__/demo.test.ts.snap"