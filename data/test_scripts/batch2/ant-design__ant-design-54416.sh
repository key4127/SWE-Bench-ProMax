#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout f842163a70bc6121afe59593b46e4e3e2784025e \
  "components/transfer/__tests__/semantic.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/transfer/__tests__/semantic.test.tsx b/components/transfer/__tests__/semantic.test.tsx
--- a/components/transfer/__tests__/semantic.test.tsx
+++ b/components/transfer/__tests__/semantic.test.tsx
@@ -17,7 +17,9 @@ describe('Transfer.Semantic', () => {
       title: 'custom-title',
       body: 'custom-body',
       list: 'custom-list',
-      listItem: 'custom-list-item',
+      item: 'custom-item',
+      itemIcon: 'custom-item-icon',
+      itemContent: 'custom-item-content',
       footer: 'custom-footer',
       actions: 'custom-actions',
     };
@@ -29,7 +31,9 @@ describe('Transfer.Semantic', () => {
       title: ['.ant-transfer-list-title', 2],
       body: ['.ant-transfer-list-body', 2],
       list: ['.ant-transfer-list-content', 2],
-      listItem: ['.ant-transfer-list-item', mockData.length],
+      item: ['.ant-transfer-list-item', mockData.length],
+      itemIcon: ['.ant-transfer-list-item-icon', mockData.length],
+      itemContent: ['.ant-transfer-list-item-content', mockData.length],
       footer: ['.ant-transfer-list-footer', 2],
       actions: ['.ant-transfer-action', 1],
     };
@@ -53,9 +57,15 @@ describe('Transfer.Semantic', () => {
       list: {
         backgroundColor: 'purple',
       },
-      listItem: {
+      item: {
         backgroundColor: 'orange',
       },
+      itemIcon: {
+        backgroundColor: 'lightblue',
+      },
+      itemContent: {
+        backgroundColor: 'lightgreen',
+      },
       footer: {
         backgroundColor: 'pink',
       },
EOF_114329324912

# Run the target test using Jest
# Using --no-cache to ensure fresh test execution
# Using --maxWorkers=1 for single-process execution (safety in virtualized environment)
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/transfer/__tests__/semantic.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout f842163a70bc6121afe59593b46e4e3e2784025e \
  "components/transfer/__tests__/semantic.test.tsx"