#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 77f0f1a9feb05f01a52edd873768b3f9cbacca80 \
  "components/date-picker/__tests__/DatePicker.test.tsx" \
  "components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/date-picker/__tests__/DatePicker.test.tsx b/components/date-picker/__tests__/DatePicker.test.tsx
--- a/components/date-picker/__tests__/DatePicker.test.tsx
+++ b/components/date-picker/__tests__/DatePicker.test.tsx
@@ -491,10 +491,10 @@ describe('DatePicker', () => {
     expect(container.querySelector('.ant-picker-suffix')!.children.length).toBeTruthy();
 
     rerender(<DatePicker suffixIcon={false} />);
-    expect(container.querySelector('.ant-picker-suffix')!.children.length).toBeFalsy();
+    expect(container.querySelector('.ant-picker-suffix')).toBeFalsy();
 
     rerender(<DatePicker suffixIcon={null} />);
-    expect(container.querySelector('.ant-picker-suffix')!.children.length).toBeFalsy();
+    expect(container.querySelector('.ant-picker-suffix')).toBeFalsy();
 
     rerender(<DatePicker suffixIcon={'123'} />);
     expect(container.querySelector('.ant-picker-suffix')?.textContent).toBe('123');
diff --git a/components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -85686,9 +85686,6 @@ exports[`renders components/date-picker/demo/suffixIcon-debug.tsx extend context
           size="12"
           value=""
         />
-        <span
-          class="ant-picker-suffix"
-        />
       </div>
     </div>
     <div
@@ -86900,9 +86897,6 @@ exports[`renders components/date-picker/demo/suffixIcon-debug.tsx extend context
           size="12"
           value=""
         />
-        <span
-          class="ant-picker-suffix"
-        />
       </div>
     </div>
     <div
diff --git a/components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap b/components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap
--- a/components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap
+++ b/components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap
@@ -7564,9 +7564,6 @@ exports[`renders components/date-picker/demo/suffixIcon-debug.tsx correctly 1`]
           size="12"
           value=""
         />
-        <span
-          class="ant-picker-suffix"
-        />
       </div>
     </div>
   </div>
@@ -7628,9 +7625,6 @@ exports[`renders components/date-picker/demo/suffixIcon-debug.tsx correctly 1`]
           size="12"
           value=""
         />
-        <span
-          class="ant-picker-suffix"
-        />
       </div>
     </div>
   </div>
EOF_114329324912

# Run the target test using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
# Running only the main test file (DatePicker.test.tsx) as snapshot files are dependencies
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/date-picker/__tests__/DatePicker.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 77f0f1a9feb05f01a52edd873768b3f9cbacca80 \
  "components/date-picker/__tests__/DatePicker.test.tsx" \
  "components/date-picker/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/date-picker/__tests__/__snapshots__/demo.test.tsx.snap"