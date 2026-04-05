#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout d0640272f6129c66250bc6b4fc7980510b3e57d6 \
  "components/float-button/__tests__/semantic.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/float-button/__tests__/semantic.test.tsx b/components/float-button/__tests__/semantic.test.tsx
--- a/components/float-button/__tests__/semantic.test.tsx
+++ b/components/float-button/__tests__/semantic.test.tsx
@@ -48,11 +48,9 @@ describe('FloatButton.Semantic', () => {
       item: 'custom-item',
       itemIcon: 'custom-item-icon',
       itemContent: 'custom-item-content',
-      trigger: {
-        root: 'custom-trigger-root',
-        icon: 'custom-trigger-icon',
-        content: 'custom-trigger-content',
-      },
+      trigger: 'custom-trigger-root',
+      triggerIcon: 'custom-trigger-icon',
+      triggerContent: 'custom-trigger-content',
     };
 
     const classNamesTargets = {
@@ -62,9 +60,9 @@ describe('FloatButton.Semantic', () => {
       itemIcon: '.ant-float-btn-group-list .ant-float-btn-icon',
       itemContent: '.ant-float-btn-group-list .ant-float-btn-content',
 
-      'trigger.root': '.ant-float-btn-group-trigger',
-      'trigger.icon': '.ant-float-btn-group-trigger .ant-float-btn-icon',
-      'trigger.content': '.ant-float-btn-group-trigger .ant-float-btn-content',
+      trigger: '.ant-float-btn-group-trigger',
+      triggerIcon: '.ant-float-btn-group-trigger .ant-float-btn-icon',
+      triggerContent: '.ant-float-btn-group-trigger .ant-float-btn-content',
     };
 
     const styles: Required<GetProp<FloatButtonGroupProps, 'styles'>> = {
@@ -73,11 +71,9 @@ describe('FloatButton.Semantic', () => {
       item: { color: 'green' },
       itemIcon: { color: 'yellow' },
       itemContent: { color: 'purple' },
-      trigger: {
-        root: { color: 'orange' },
-        icon: { color: 'pink' },
-        content: { color: 'cyan' },
-      },
+      trigger: { color: 'orange' },
+      triggerIcon: { color: 'pink' },
+      triggerContent: { color: 'cyan' },
     };
 
     const { container } = render(
EOF_114329324912

# Run the target test using Jest
# Using --no-cache to ensure fresh test execution
# Using --maxWorkers=1 to run in single-process mode for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/float-button/__tests__/semantic.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout d0640272f6129c66250bc6b4fc7980510b3e57d6 \
  "components/float-button/__tests__/semantic.test.tsx"