#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 11b08bc22eba2e1800fb2b58aef4a75680082af5 \
  "components/auto-complete/__tests__/index.test.tsx" \
  "components/cascader/__tests__/index.test.tsx" \
  "components/select/__tests__/index.test.tsx" \
  "components/tree-select/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/auto-complete/__tests__/index.test.tsx b/components/auto-complete/__tests__/index.test.tsx
--- a/components/auto-complete/__tests__/index.test.tsx
+++ b/components/auto-complete/__tests__/index.test.tsx
@@ -111,7 +111,7 @@ describe('AutoComplete', () => {
       />,
     );
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: AutoComplete] `dropdownClassName` is deprecated. Please use `classNames.popup` instead.',
+      'Warning: [antd: AutoComplete] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -131,7 +131,7 @@ describe('AutoComplete', () => {
       />,
     );
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: AutoComplete] `popupClassName` is deprecated. Please use `classNames.popup` instead.',
+      'Warning: [antd: AutoComplete] `popupClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -168,7 +168,7 @@ describe('AutoComplete', () => {
       />,
     );
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: AutoComplete] `dropdownStyle` is deprecated. Please use `styles.popup` instead.',
+      'Warning: [antd: AutoComplete] `dropdownStyle` is deprecated. Please use `styles.popup.root` instead.',
     );
 
     errSpy.mockRestore();
diff --git a/components/cascader/__tests__/index.test.tsx b/components/cascader/__tests__/index.test.tsx
--- a/components/cascader/__tests__/index.test.tsx
+++ b/components/cascader/__tests__/index.test.tsx
@@ -546,7 +546,7 @@ describe('Cascader', () => {
       const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
       const { container } = render(<Cascader dropdownClassName="legacy" open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Cascader] `dropdownClassName` is deprecated. Please use `classNames.popup` instead.',
+        'Warning: [antd: Cascader] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
       );
       expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -560,7 +560,7 @@ describe('Cascader', () => {
       const customStyle = { background: 'red' };
       const { container } = render(<Cascader dropdownStyle={customStyle} open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Cascader] `dropdownStyle` is deprecated. Please use `styles.popup` instead.',
+        'Warning: [antd: Cascader] `dropdownStyle` is deprecated. Please use `styles.popup.root` instead.',
       );
       expect(container.querySelector('.ant-select-dropdown')?.getAttribute('style')).toContain(
         'background: red',
diff --git a/components/select/__tests__/index.test.tsx b/components/select/__tests__/index.test.tsx
--- a/components/select/__tests__/index.test.tsx
+++ b/components/select/__tests__/index.test.tsx
@@ -180,7 +180,7 @@ describe('Select', () => {
       const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
       const { container } = render(<Select popupClassName="legacy" open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Select] `popupClassName` is deprecated. Please use `classNames.popup` instead.',
+        'Warning: [antd: Select] `popupClassName` is deprecated. Please use `classNames.popup.root` instead.',
       );
       expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -193,7 +193,7 @@ describe('Select', () => {
       const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
       const { container } = render(<Select dropdownClassName="legacy" open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Select] `dropdownClassName` is deprecated. Please use `classNames.popup` instead.',
+        'Warning: [antd: Select] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
       );
       expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -205,7 +205,7 @@ describe('Select', () => {
       const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
       const { container } = render(<Select dropdownStyle={{ background: 'red' }} open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Select] `dropdownStyle` is deprecated. Please use `styles.popup` instead.',
+        'Warning: [antd: Select] `dropdownStyle` is deprecated. Please use `styles.popup.root` instead.',
       );
       const dropdown = container.querySelector('.ant-select-dropdown');
       expect(dropdown?.getAttribute('style')).toMatch(/background:\s*red/);
diff --git a/components/tree-select/__tests__/index.test.tsx b/components/tree-select/__tests__/index.test.tsx
--- a/components/tree-select/__tests__/index.test.tsx
+++ b/components/tree-select/__tests__/index.test.tsx
@@ -60,7 +60,7 @@ describe('TreeSelect', () => {
     const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
     const { container } = render(<TreeSelect popupClassName="legacy" open />);
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: TreeSelect] `popupClassName` is deprecated. Please use `classNames.popup` instead.',
+      'Warning: [antd: TreeSelect] `popupClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -73,7 +73,7 @@ describe('TreeSelect', () => {
     const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
     const { container } = render(<TreeSelect dropdownClassName="legacy" open />);
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: TreeSelect] `dropdownClassName` is deprecated. Please use `classNames.popup` instead.',
+      'Warning: [antd: TreeSelect] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
@@ -98,7 +98,7 @@ describe('TreeSelect', () => {
     const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
     const { container } = render(<TreeSelect dropdownStyle={{ color: 'red' }} open />);
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: TreeSelect] `dropdownStyle` is deprecated. Please use `styles.popup` instead.',
+      'Warning: [antd: TreeSelect] `dropdownStyle` is deprecated. Please use `styles.popup.root` instead.',
     );
     expect(container.querySelector('.ant-select-dropdown')).toBeTruthy();
 
EOF_114329324912

# Run the target tests using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/auto-complete/__tests__/index.test.tsx" \
  "components/cascader/__tests__/index.test.tsx" \
  "components/select/__tests__/index.test.tsx" \
  "components/tree-select/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 11b08bc22eba2e1800fb2b58aef4a75680082af5 \
  "components/auto-complete/__tests__/index.test.tsx" \
  "components/cascader/__tests__/index.test.tsx" \
  "components/select/__tests__/index.test.tsx" \
  "components/tree-select/__tests__/index.test.tsx"