#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 80a1f695886a70a313c5326403f31a41d4ec0dd3 \
  "components/_util/__tests__/hooks.test.tsx" \
  "components/_util/__tests__/useSyncState.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/_util/__tests__/hooks.test.tsx b/components/_util/__tests__/hooks.test.tsx
--- a/components/_util/__tests__/hooks.test.tsx
+++ b/components/_util/__tests__/hooks.test.tsx
@@ -2,8 +2,8 @@ import React, { useEffect } from 'react';
 import { CloseOutlined } from '@ant-design/icons';
 import { render } from '@testing-library/react';
 
+import { useClosable } from '../hooks';
 import type { UseClosableParams } from '../hooks/useClosable';
-import useClosable from '../hooks/useClosable';
 
 type ParamsOfUseClosable = [
   closable: UseClosableParams['closable'],
diff --git a/components/_util/__tests__/useSyncState.test.tsx b/components/_util/__tests__/useSyncState.test.tsx
--- a/components/_util/__tests__/useSyncState.test.tsx
+++ b/components/_util/__tests__/useSyncState.test.tsx
@@ -1,7 +1,7 @@
 import React from 'react';
 
 import { fireEvent, render } from '../../../tests/utils';
-import useSyncState from '../hooks/useSyncState';
+import { useSyncState } from '../hooks';
 
 describe('Table', () => {
   it('useSyncState', () => {
EOF_114329324912

# Run the target tests using Jest
# Execute both target test files in a single command for efficiency
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/_util/__tests__/hooks.test.tsx" \
  "components/_util/__tests__/useSyncState.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 80a1f695886a70a313c5326403f31a41d4ec0dd3 \
  "components/_util/__tests__/hooks.test.tsx" \
  "components/_util/__tests__/useSyncState.test.tsx"