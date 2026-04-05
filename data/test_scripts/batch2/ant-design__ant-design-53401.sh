#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout f5b9795c256b50db6608968ffe73f1fc20111157 \
  "components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/statistic/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/statistic/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -414,11 +414,52 @@ exports[`renders components/statistic/demo/component-token.tsx extend context co
 
 exports[`renders components/statistic/demo/component-token.tsx extend context correctly 2`] = `[]`;
 
-exports[`renders components/statistic/demo/countdown.tsx extend context correctly 1`] = `
+exports[`renders components/statistic/demo/timer.tsx extend context correctly 1`] = `
 <div
   class="ant-row"
   style="margin-left: -8px; margin-right: -8px;"
 >
+  <div
+    class="ant-col ant-col-12"
+    style="padding-left: 8px; padding-right: 8px;"
+  >
+    <div
+      class="ant-statistic"
+    >
+      <div
+        class="ant-statistic-content"
+      >
+        <span
+          class="ant-statistic-content-value"
+        >
+          48:00:30
+        </span>
+      </div>
+    </div>
+  </div>
+  <div
+    class="ant-col ant-col-12"
+    style="padding-left: 8px; padding-right: 8px;"
+  >
+    <div
+      class="ant-statistic"
+    >
+      <div
+        class="ant-statistic-title"
+      >
+        Million Seconds
+      </div>
+      <div
+        class="ant-statistic-content"
+      >
+        <span
+          class="ant-statistic-content-value"
+        >
+          48:00:30:000
+        </span>
+      </div>
+    </div>
+  </div>
   <div
     class="ant-col ant-col-12"
     style="padding-left: 8px; padding-right: 8px;"
@@ -437,7 +478,7 @@ exports[`renders components/statistic/demo/countdown.tsx extend context correctl
         <span
           class="ant-statistic-content-value"
         >
-          48:00:30
+          00:00:10
         </span>
       </div>
     </div>
@@ -452,15 +493,15 @@ exports[`renders components/statistic/demo/countdown.tsx extend context correctl
       <div
         class="ant-statistic-title"
       >
-        Million Seconds
+        Countup
       </div>
       <div
         class="ant-statistic-content"
       >
         <span
           class="ant-statistic-content-value"
         >
-          48:00:30:000
+          47:59:30
         </span>
       </div>
     </div>
@@ -475,7 +516,7 @@ exports[`renders components/statistic/demo/countdown.tsx extend context correctl
       <div
         class="ant-statistic-title"
       >
-        Day Level
+        Day Level (Countdown)
       </div>
       <div
         class="ant-statistic-content"
@@ -489,32 +530,32 @@ exports[`renders components/statistic/demo/countdown.tsx extend context correctl
     </div>
   </div>
   <div
-    class="ant-col ant-col-12"
-    style="padding-left: 8px; padding-right: 8px;"
+    class="ant-col ant-col-24"
+    style="padding-left: 8px; padding-right: 8px; margin-top: 32px;"
   >
     <div
       class="ant-statistic"
     >
       <div
         class="ant-statistic-title"
       >
-        Countdown
+        Day Level (Countup)
       </div>
       <div
         class="ant-statistic-content"
       >
         <span
           class="ant-statistic-content-value"
         >
-          00:00:10
+          1 天 23 时 59 分 30 秒
         </span>
       </div>
     </div>
   </div>
 </div>
 `;
 
-exports[`renders components/statistic/demo/countdown.tsx extend context correctly 2`] = `[]`;
+exports[`renders components/statistic/demo/timer.tsx extend context correctly 2`] = `[]`;
 
 exports[`renders components/statistic/demo/unit.tsx extend context correctly 1`] = `
 <div
diff --git a/components/statistic/__tests__/__snapshots__/demo.test.ts.snap b/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
--- a/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
+++ b/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
@@ -402,11 +402,52 @@ exports[`renders components/statistic/demo/component-token.tsx correctly 1`] = `
 </div>
 `;
 
-exports[`renders components/statistic/demo/countdown.tsx correctly 1`] = `
+exports[`renders components/statistic/demo/timer.tsx correctly 1`] = `
 <div
   class="ant-row"
   style="margin-left:-8px;margin-right:-8px"
 >
+  <div
+    class="ant-col ant-col-12"
+    style="padding-left:8px;padding-right:8px"
+  >
+    <div
+      class="ant-statistic"
+    >
+      <div
+        class="ant-statistic-content"
+      >
+        <span
+          class="ant-statistic-content-value"
+        >
+          48:00:30
+        </span>
+      </div>
+    </div>
+  </div>
+  <div
+    class="ant-col ant-col-12"
+    style="padding-left:8px;padding-right:8px"
+  >
+    <div
+      class="ant-statistic"
+    >
+      <div
+        class="ant-statistic-title"
+      >
+        Million Seconds
+      </div>
+      <div
+        class="ant-statistic-content"
+      >
+        <span
+          class="ant-statistic-content-value"
+        >
+          48:00:30:000
+        </span>
+      </div>
+    </div>
+  </div>
   <div
     class="ant-col ant-col-12"
     style="padding-left:8px;padding-right:8px"
@@ -425,7 +466,7 @@ exports[`renders components/statistic/demo/countdown.tsx correctly 1`] = `
         <span
           class="ant-statistic-content-value"
         >
-          48:00:30
+          00:00:10
         </span>
       </div>
     </div>
@@ -440,15 +481,15 @@ exports[`renders components/statistic/demo/countdown.tsx correctly 1`] = `
       <div
         class="ant-statistic-title"
       >
-        Million Seconds
+        Countup
       </div>
       <div
         class="ant-statistic-content"
       >
         <span
           class="ant-statistic-content-value"
         >
-          48:00:30:000
+          47:59:30
         </span>
       </div>
     </div>
@@ -463,7 +504,7 @@ exports[`renders components/statistic/demo/countdown.tsx correctly 1`] = `
       <div
         class="ant-statistic-title"
       >
-        Day Level
+        Day Level (Countdown)
       </div>
       <div
         class="ant-statistic-content"
@@ -477,24 +518,24 @@ exports[`renders components/statistic/demo/countdown.tsx correctly 1`] = `
     </div>
   </div>
   <div
-    class="ant-col ant-col-12"
-    style="padding-left:8px;padding-right:8px"
+    class="ant-col ant-col-24"
+    style="padding-left:8px;padding-right:8px;margin-top:32px"
   >
     <div
       class="ant-statistic"
     >
       <div
         class="ant-statistic-title"
       >
-        Countdown
+        Day Level (Countup)
       </div>
       <div
         class="ant-statistic-content"
       >
         <span
           class="ant-statistic-content-value"
         >
-          00:00:10
+          1 天 23 时 59 分 30 秒
         </span>
       </div>
     </div>
diff --git a/components/statistic/__tests__/index.test.tsx b/components/statistic/__tests__/index.test.tsx
--- a/components/statistic/__tests__/index.test.tsx
+++ b/components/statistic/__tests__/index.test.tsx
@@ -1,25 +1,25 @@
 import React from 'react';
 import dayjs from 'dayjs';
-import MockDate from 'mockdate';
 
 import type { CountdownProps } from '..';
 import Statistic from '..';
 import mountTest from '../../../tests/shared/mountTest';
 import rtlTest from '../../../tests/shared/rtlTest';
-import { fireEvent, render, waitFakeTimer } from '../../../tests/utils';
+import { act, fireEvent, render, waitFakeTimer } from '../../../tests/utils';
 import { formatTimeStr } from '../utils';
 
 describe('Statistic', () => {
   mountTest(Statistic);
-  mountTest(Statistic.Countdown);
+  mountTest(() => <Statistic.Timer type="countdown" />);
   rtlTest(Statistic);
 
-  beforeAll(() => {
-    MockDate.set(dayjs('2018-11-28 00:00:00').valueOf());
+  beforeEach(() => {
+    jest.useFakeTimers();
   });
 
-  afterAll(() => {
-    MockDate.reset();
+  afterEach(() => {
+    jest.clearAllTimers();
+    jest.useRealTimers();
   });
 
   it('`-` is not a number', () => {
@@ -105,7 +105,104 @@ describe('Statistic', () => {
     );
   });
 
-  describe('Countdown', () => {
+  describe('Timer', () => {
+    it('countdown', async () => {
+      const onChange = jest.fn();
+      const onFinish = jest.fn();
+
+      const { container } = render(
+        <Statistic.Timer
+          type="countdown"
+          data-xyz="x"
+          aria-label="y"
+          role="contentinfo"
+          value={Date.now() + 1500}
+          onChange={onChange}
+          onFinish={onFinish}
+        />,
+      );
+
+      // Data attributes
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('data-xyz', 'x');
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('aria-label', 'y');
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('role', 'contentinfo');
+
+      // Now value
+      expect(container.querySelector('.ant-statistic-content-value')!.textContent).toEqual(
+        '00:00:01',
+      );
+
+      // Pass 0.5s
+      act(() => {
+        jest.advanceTimersByTime(500);
+      });
+      expect(onChange).toHaveBeenCalled();
+      expect(onFinish).not.toHaveBeenCalled();
+
+      // Pass time
+      act(() => {
+        jest.advanceTimersByTime(5000);
+      });
+      // Call twice to confirm `onFinish` is called only once
+      act(() => {
+        jest.advanceTimersByTime(5000);
+      });
+      expect(container.querySelector('.ant-statistic-content-value')!.textContent).toEqual(
+        '00:00:00',
+      );
+      expect(onFinish).toHaveBeenCalled();
+      expect(onFinish).toHaveBeenCalledTimes(1);
+    });
+    it('should show warning when using countdown', () => {
+      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+      render(<Statistic.Countdown />);
+      expect(errorSpy).toHaveBeenCalledWith(
+        'Warning: [antd: Countdown] `<Statistic.Countdown />` is deprecated. Please use `<Statistic.Timer type="countdown" />` instead.',
+      );
+    });
+
+    it('countup', async () => {
+      const onChange = jest.fn();
+      const onFinish = jest.fn();
+      const before = dayjs().add(-30, 'minute').valueOf();
+
+      const { container } = render(
+        <Statistic.Timer
+          type="countup"
+          data-xyz="x"
+          aria-label="y"
+          role="contentinfo"
+          value={before}
+          onChange={onChange}
+          onFinish={onFinish}
+        />,
+      );
+
+      // Data attributes
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('data-xyz', 'x');
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('aria-label', 'y');
+      expect(container.querySelector('.ant-statistic')!).toHaveAttribute('role', 'contentinfo');
+
+      // Now value
+      expect(container.querySelector('.ant-statistic-content-value')!.textContent).toEqual(
+        '00:30:00',
+      );
+
+      // Pass 1s
+      act(() => {
+        jest.advanceTimersByTime(1000);
+      });
+      expect(onChange).toHaveBeenCalled();
+      expect(onFinish).not.toHaveBeenCalled();
+
+      // Now value
+      expect(container.querySelector('.ant-statistic-content-value')!.textContent).toEqual(
+        '00:30:01',
+      );
+    });
+  });
+
+  describe('Deprecated Countdown', () => {
     it('render correctly', () => {
       const now = dayjs()
         .add(2, 'd')
EOF_114329324912

# Run the target tests using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
# The snapshot files will be automatically validated when running index.test.tsx
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/statistic/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout f5b9795c256b50db6608968ffe73f1fc20111157 \
  "components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/statistic/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/statistic/__tests__/index.test.tsx"