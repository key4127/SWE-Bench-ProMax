#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 10f013fb19862f6c3b3882a60a4d0ecfb34c0d10 "components/float-button/__tests__/semantic.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/float-button/__tests__/semantic.test.tsx b/components/float-button/__tests__/semantic.test.tsx
--- a/components/float-button/__tests__/semantic.test.tsx
+++ b/components/float-button/__tests__/semantic.test.tsx
@@ -45,11 +45,9 @@ describe('FloatButton.Semantic', () => {
     const classNames: Required<GetProp<FloatButtonGroupProps, 'classNames'>> = {
       root: 'custom-root',
       list: 'custom-list',
-      item: {
-        root: 'custom-item-root',
-        icon: 'custom-item-icon',
-        content: 'custom-item-content',
-      },
+      item: 'custom-item',
+      itemIcon: 'custom-item-icon',
+      itemContent: 'custom-item-content',
       trigger: {
         root: 'custom-trigger-root',
         icon: 'custom-trigger-icon',
@@ -60,9 +58,9 @@ describe('FloatButton.Semantic', () => {
     const classNamesTargets = {
       root: '.ant-float-btn-group',
       list: '.ant-float-btn-group-list',
-      'item.root': '.ant-float-btn-group-list .ant-float-btn',
-      'item.icon': '.ant-float-btn-group-list .ant-float-btn-icon',
-      'item.content': '.ant-float-btn-group-list .ant-float-btn-content',
+      item: '.ant-float-btn-group-list .ant-float-btn',
+      itemIcon: '.ant-float-btn-group-list .ant-float-btn-icon',
+      itemContent: '.ant-float-btn-group-list .ant-float-btn-content',
 
       'trigger.root': '.ant-float-btn-group-trigger',
       'trigger.icon': '.ant-float-btn-group-trigger .ant-float-btn-icon',
@@ -72,11 +70,9 @@ describe('FloatButton.Semantic', () => {
     const styles: Required<GetProp<FloatButtonGroupProps, 'styles'>> = {
       root: { color: 'red' },
       list: { color: 'blue' },
-      item: {
-        root: { color: 'green' },
-        icon: { color: 'yellow' },
-        content: { color: 'purple' },
-      },
+      item: { color: 'green' },
+      itemIcon: { color: 'yellow' },
+      itemContent: { color: 'purple' },
       trigger: {
         root: { color: 'orange' },
         icon: { color: 'pink' },
EOF_114329324912

# Run the target test using Jest
# Using --no-cache to ensure fresh test run
# Using --maxWorkers=1 to run in single-process mode for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/float-button/__tests__/semantic.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 10f013fb19862f6c3b3882a60a4d0ecfb34c0d10 "components/float-button/__tests__/semantic.test.tsx"