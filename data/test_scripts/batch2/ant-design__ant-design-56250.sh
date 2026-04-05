#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 886a1d19cdea9c5d5985acf428407a78d4907f44 \
  "components/breadcrumb/__tests__/Breadcrumb.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/breadcrumb/__tests__/Breadcrumb.test.tsx b/components/breadcrumb/__tests__/Breadcrumb.test.tsx
--- a/components/breadcrumb/__tests__/Breadcrumb.test.tsx
+++ b/components/breadcrumb/__tests__/Breadcrumb.test.tsx
@@ -3,7 +3,7 @@ import React from 'react';
 import { accessibilityTest } from '../../../tests/shared/accessibilityTest';
 import mountTest from '../../../tests/shared/mountTest';
 import rtlTest from '../../../tests/shared/rtlTest';
-import { render } from '../../../tests/utils';
+import { render, screen } from '../../../tests/utils';
 import ConfigProvider from '../../config-provider';
 import type { ItemType } from '../Breadcrumb';
 import Breadcrumb from '../index';
@@ -311,6 +311,75 @@ describe('Breadcrumb', () => {
     expect(document.querySelector('.ant-dropdown')).toBeTruthy();
   });
 
+  it('should support custom dropdownIcon', () => {
+    render(
+      <Breadcrumb
+        items={[
+          {
+            title: 'test',
+            menu: {
+              items: [
+                {
+                  key: '1',
+                  label: 'label',
+                },
+              ],
+            },
+          },
+        ]}
+        dropdownIcon={<span>foobar</span>}
+      />,
+    );
+    expect(screen.getByText('foobar')).toBeTruthy();
+  });
+
+  it('should support custom dropdownIcon in ConfigProvider', () => {
+    render(
+      <ConfigProvider breadcrumb={{ dropdownIcon: <span>foobar</span> }}>
+        <Breadcrumb
+          items={[
+            {
+              title: 'test',
+              menu: {
+                items: [
+                  {
+                    key: '1',
+                    label: 'label',
+                  },
+                ],
+              },
+            },
+          ]}
+        />
+      </ConfigProvider>,
+    );
+    expect(screen.getByText('foobar')).toBeTruthy();
+  });
+
+  it('should prefer custom dropdownIcon prop than ConfigProvider', () => {
+    render(
+      <ConfigProvider breadcrumb={{ dropdownIcon: <span>foobar</span> }}>
+        <Breadcrumb
+          items={[
+            {
+              title: 'test',
+              menu: {
+                items: [
+                  {
+                    key: '1',
+                    label: 'label',
+                  },
+                ],
+              },
+            },
+          ]}
+          dropdownIcon={<span>bamboo</span>}
+        />
+      </ConfigProvider>,
+    );
+    expect(screen.getByText('bamboo')).toBeTruthy();
+  });
+
   it('Breadcrumb params type test', () => {
     interface Params {
       key1?: number;
EOF_114329324912

# Run the target test using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
# Using --no-cache to avoid potential cache issues
# Using --verbose for detailed output
npx jest --config .jest.js --no-cache --maxWorkers=1 --verbose \
  "components/breadcrumb/__tests__/Breadcrumb.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 886a1d19cdea9c5d5985acf428407a78d4907f44 \
  "components/breadcrumb/__tests__/Breadcrumb.test.tsx"