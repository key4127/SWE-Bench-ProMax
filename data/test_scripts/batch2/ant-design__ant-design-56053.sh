#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout cd267f0a3e9e021f1e6a67b3885fc91b63ec0236 \
  "components/button/__tests__/delay-timer.test.tsx" \
  "components/button/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/button/__tests__/delay-timer.test.tsx b/components/button/__tests__/delay-timer.test.tsx
--- a/components/button/__tests__/delay-timer.test.tsx
+++ b/components/button/__tests__/delay-timer.test.tsx
@@ -1,7 +1,7 @@
 import React, { useState } from 'react';
 
 import { act, fireEvent, render } from '../../../tests/utils';
-import Button from '../button';
+import Button from '../Button';
 
 const specialDelay = 9529;
 const Content = () => {
diff --git a/components/button/__tests__/index.test.tsx b/components/button/__tests__/index.test.tsx
--- a/components/button/__tests__/index.test.tsx
+++ b/components/button/__tests__/index.test.tsx
@@ -10,7 +10,7 @@ import { act, fireEvent, render, waitFakeTimer } from '../../../tests/utils';
 import ConfigProvider from '../../config-provider';
 import theme from '../../theme';
 import { PresetColors } from '../../theme/interface';
-import type { BaseButtonProps } from '../button';
+import type { BaseButtonProps } from '../Button';
 
 const { resetWarned } = warning;
 
EOF_114329324912

# Run the target tests using Jest
# Using --no-cache to ensure fresh test execution
# Using --maxWorkers=1 to run in single-process mode for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/button/__tests__/delay-timer.test.tsx" \
  "components/button/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout cd267f0a3e9e021f1e6a67b3885fc91b63ec0236 \
  "components/button/__tests__/delay-timer.test.tsx" \
  "components/button/__tests__/index.test.tsx"