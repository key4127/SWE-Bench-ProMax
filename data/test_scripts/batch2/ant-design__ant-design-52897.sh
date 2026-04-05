#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout ea2989831a6a00707a2f90af480104542016ea18 \
  "components/watermark/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/watermark/__tests__/index.test.tsx b/components/watermark/__tests__/index.test.tsx
--- a/components/watermark/__tests__/index.test.tsx
+++ b/components/watermark/__tests__/index.test.tsx
@@ -1,4 +1,5 @@
 import React from 'react';
+import { spyElementPrototypes } from 'rc-util/lib/test/domHook';
 
 import Watermark from '..';
 import mountTest from '../../../tests/shared/mountTest';
@@ -89,12 +90,25 @@ describe('Watermark', () => {
   });
 
   it('MutationObserver should work properly', async () => {
+    let counter = 0;
+    const spyCanvas = spyElementPrototypes(HTMLCanvasElement, {
+      toDataURL(originDescriptor: any) {
+        counter += 1;
+        return originDescriptor.value.call(this);
+      },
+    });
     const { container } = render(<Watermark className="watermark" content="MutationObserver" />);
     const target = container.querySelector<HTMLDivElement>('.watermark div');
     await waitFakeTimer();
+    expect(counter).toBe(1);
+
     target?.remove();
     await waitFakeTimer();
+    expect(counter).toBe(1);
+
     expect(container).toMatchSnapshot();
+
+    spyCanvas.mockRestore();
   });
 
   describe('Observe the modification of style', () => {
EOF_114329324912

# Run the target test using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/watermark/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout ea2989831a6a00707a2f90af480104542016ea18 \
  "components/watermark/__tests__/index.test.tsx"