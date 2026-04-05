#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 4c780b64883d925018d55e6d4a2bb316d949bdd1 \
  "components/_util/__tests__/responsiveObserve.test.tsx" \
  "components/grid/__tests__/index.test.tsx" \
  "tests/setup.ts" \
  "tests/shared/imageTest.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/_util/__tests__/responsiveObserve.test.tsx b/components/_util/__tests__/responsiveObserve.test.tsx
--- a/components/_util/__tests__/responsiveObserve.test.tsx
+++ b/components/_util/__tests__/responsiveObserve.test.tsx
@@ -5,20 +5,23 @@ import useResponsiveObserver from '../responsiveObserver';
 
 describe('Test ResponsiveObserve', () => {
   it('test ResponsiveObserve subscribe and unsubscribe', () => {
-    let responsiveRef: any = null;
-    const Demo: React.FC = () => {
+    let responsiveObserveRef: any;
+    const Demo = () => {
       const responsiveObserver = useResponsiveObserver();
-      responsiveRef = responsiveObserver;
+      responsiveObserveRef = responsiveObserver;
       return null;
     };
     render(<Demo />);
     const subscribeFunc = jest.fn();
-    const token = responsiveRef.subscribe(subscribeFunc);
-    expect(responsiveRef.matchHandlers[responsiveRef.responsiveMap.xs].mql.matches).toBeTruthy();
+    const token = responsiveObserveRef.subscribe(subscribeFunc);
+    expect(
+      responsiveObserveRef.matchHandlers[responsiveObserveRef.responsiveMap.xs].mql.matches,
+    ).toBeTruthy();
     expect(subscribeFunc).toHaveBeenCalledTimes(1);
-    responsiveRef.unsubscribe(token);
+
+    responsiveObserveRef.unsubscribe(token);
     expect(
-      responsiveRef.matchHandlers[responsiveRef.responsiveMap.xs].mql?.removeEventListener,
+      responsiveObserveRef.matchHandlers[responsiveObserveRef.responsiveMap.xs].mql.removeListener,
     ).toHaveBeenCalled();
   });
 });
diff --git a/components/grid/__tests__/index.test.tsx b/components/grid/__tests__/index.test.tsx
--- a/components/grid/__tests__/index.test.tsx
+++ b/components/grid/__tests__/index.test.tsx
@@ -78,12 +78,10 @@ describe('Grid', () => {
     jest.spyOn(window, 'matchMedia').mockImplementation(
       (query) =>
         ({
-          addEventListener: (type: string, callback: (e: { matches: boolean }) => void) => {
-            if (type === 'change') {
-              callback({ matches: query === '(min-width: 1200px)' });
-            }
+          addListener: (cb: (e: { matches: boolean }) => void) => {
+            cb({ matches: query === '(min-width: 1200px)' });
           },
-          removeEventListener: jest.fn(),
+          removeListener: jest.fn(),
           matches: query === '(min-width: 1200px)',
         }) as any,
     );
@@ -147,12 +145,10 @@ describe('Grid', () => {
     matchMediaSpy.mockImplementation(
       (query) =>
         ({
-          addEventListener: (type: string, callback: (e: { matches: boolean }) => void) => {
-            if (type === 'change') {
-              callback({ matches: query === '(max-width: 575px)' });
-            }
+          addListener: (cb: (e: { matches: boolean }) => void) => {
+            cb({ matches: query === '(max-width: 575px)' });
           },
-          removeEventListener: jest.fn(),
+          removeListener: jest.fn(),
           matches: query === '(max-width: 575px)',
         }) as any,
     );
@@ -180,12 +176,10 @@ describe('Grid', () => {
     matchMediaSpy.mockImplementation(
       (query) =>
         ({
-          addEventListener: (type: string, callback: (e: { matches: boolean }) => void) => {
-            if (type === 'change') {
-              callback({ matches: query === '(max-width: 575px)' });
-            }
+          addListener: (cb: (e: { matches: boolean }) => void) => {
+            cb({ matches: query === '(max-width: 575px)' });
           },
-          removeEventListener: jest.fn(),
+          removeListener: jest.fn(),
           matches: query === '(max-width: 575px)',
         }) as any,
     );
@@ -202,12 +196,10 @@ describe('Grid', () => {
     matchMediaSpy.mockImplementation(
       (query) =>
         ({
-          addEventListener: (type: string, callback: (e: { matches: boolean }) => void) => {
-            if (type === 'change') {
-              callback({ matches: query === '(max-width: 575px)' });
-            }
+          addListener: (cb: (e: { matches: boolean }) => void) => {
+            cb({ matches: query === '(max-width: 575px)' });
           },
-          removeEventListener: jest.fn(),
+          removeListener: jest.fn(),
           matches: query === '(max-width: 575px)',
         }) as any,
     );
diff --git a/tests/setup.ts b/tests/setup.ts
--- a/tests/setup.ts
+++ b/tests/setup.ts
@@ -40,8 +40,8 @@ export function fillWindowEnv(window: Window | DOMWindow) {
       configurable: true,
       value: jest.fn((query) => ({
         matches: query.includes('max-width'),
-        addEventListener: jest.fn(),
-        removeEventListener: jest.fn(),
+        addListener: jest.fn(),
+        removeListener: jest.fn(),
       })),
     });
   }
diff --git a/tests/shared/imageTest.tsx b/tests/shared/imageTest.tsx
--- a/tests/shared/imageTest.tsx
+++ b/tests/shared/imageTest.tsx
@@ -8,8 +8,8 @@ import fse from 'fs-extra';
 import { globSync } from 'glob';
 import { JSDOM } from 'jsdom';
 import MockDate from 'mockdate';
-import type { HTTPRequest } from 'puppeteer';
 import rcWarning from 'rc-util/lib/warning';
+import type { HTTPRequest } from 'puppeteer';
 import ReactDOMServer from 'react-dom/server';
 
 import { App, ConfigProvider, theme } from '../../components';
@@ -94,12 +94,13 @@ export default function imageTest(
     // Fake matchMedia
     win.matchMedia = (() => ({
       matches: false,
-      addEventListener: jest.fn(),
-      removeEventListener: jest.fn(),
+      addListener: jest.fn(),
+      removeListener: jest.fn(),
     })) as unknown as typeof matchMedia;
 
     // Fill window
     fillWindowEnv(win);
+
     await page.setRequestInterception(true);
   });
 
EOF_114329324912

# Run the target tests using Jest
# Execute the test files in a single command for efficiency
# Using --maxWorkers=1 to ensure single-process execution for stability
# Note: tests/setup.ts and tests/shared/imageTest.tsx are utility files
# that are automatically loaded/imported, so we only execute the actual test files
npx jest --config .jest.js --no-cache --maxWorkers=1 --verbose \
  "components/_util/__tests__/responsiveObserve.test.tsx" \
  "components/grid/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 4c780b64883d925018d55e6d4a2bb316d949bdd1 \
  "components/_util/__tests__/responsiveObserve.test.tsx" \
  "components/grid/__tests__/index.test.tsx" \
  "tests/setup.ts" \
  "tests/shared/imageTest.tsx"