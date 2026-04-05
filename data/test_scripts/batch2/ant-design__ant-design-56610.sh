#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2e51288638e6a4815ee010a1ac74f9130bc98f9c \
  "components/switch/__tests__/semantic.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/switch/__tests__/semantic.test.tsx b/components/switch/__tests__/semantic.test.tsx
--- a/components/switch/__tests__/semantic.test.tsx
+++ b/components/switch/__tests__/semantic.test.tsx
@@ -2,9 +2,9 @@ import React from 'react';
 import { render } from '@testing-library/react';
 import { Flex, Space, Switch } from 'antd';
 import type { SwitchProps } from 'antd';
-import { createStyles } from 'antd-style';
+import { createStaticStyles } from 'antd-style';
 
-const useStyle = createStyles(({ css }) => ({
+const classNames = createStaticStyles(({ css }) => ({
   root: css`
     border-color: red;
   `,
@@ -19,13 +19,11 @@ const stylesObject: SwitchProps['styles'] = {
 
 // 创建一个自定义 Hook 来获取 classNames 函数
 const useClassNames = () => {
-  const { styles } = useStyle();
-
   const classNamesFn: SwitchProps['classNames'] = (info) => {
     if (info.props.size === 'small') {
       return {
-        root: styles.root,
-        content: styles.content,
+        root: classNames.root,
+        content: classNames.content,
       };
     }
 
EOF_114329324912

# Run the target test using Jest with single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/switch/__tests__/semantic.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 2e51288638e6a4815ee010a1ac74f9130bc98f9c \
  "components/switch/__tests__/semantic.test.tsx"