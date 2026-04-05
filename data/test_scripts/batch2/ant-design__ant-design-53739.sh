#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 482cfd94ec8a5123522eb96faefa4cf5671b544d \
  "components/drawer/__tests__/Drawer.test.tsx" \
  "components/drawer/__tests__/DrawerEvent.test.tsx" \
  "components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap" \
  "components/dropdown/__tests__/dropdown-button.test.tsx" \
  "components/dropdown/__tests__/index.test.tsx" \
  "components/tooltip/__tests__/tooltip.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/drawer/__tests__/Drawer.test.tsx b/components/drawer/__tests__/Drawer.test.tsx
--- a/components/drawer/__tests__/Drawer.test.tsx
+++ b/components/drawer/__tests__/Drawer.test.tsx
@@ -105,9 +105,9 @@ describe('Drawer', () => {
     expect(wrapper.firstChild).toMatchSnapshot();
   });
 
-  it('destroyOnClose is true', () => {
+  it('destroyOnHidden is true', () => {
     const { container: wrapper } = render(
-      <Drawer destroyOnClose open={false} getContainer={false}>
+      <Drawer destroyOnHidden open={false} getContainer={false}>
         Here is content of Drawer
       </Drawer>,
     );
@@ -118,7 +118,7 @@ describe('Drawer', () => {
 
   it('className is test_drawer', () => {
     const { container: wrapper } = render(
-      <Drawer destroyOnClose open rootClassName="test_drawer" getContainer={false}>
+      <Drawer destroyOnHidden open rootClassName="test_drawer" getContainer={false}>
         Here is content of Drawer
       </Drawer>,
     );
diff --git a/components/drawer/__tests__/DrawerEvent.test.tsx b/components/drawer/__tests__/DrawerEvent.test.tsx
--- a/components/drawer/__tests__/DrawerEvent.test.tsx
+++ b/components/drawer/__tests__/DrawerEvent.test.tsx
@@ -56,19 +56,19 @@ describe('Drawer', () => {
     expect(onClose).not.toHaveBeenCalled();
   });
 
-  it('dom should be removed after close when destroyOnClose is true', () => {
-    const { container, rerender } = render(<DrawerTest destroyOnClose />);
+  it('dom should be removed after close when destroyOnHidden is true', () => {
+    const { container, rerender } = render(<DrawerTest destroyOnHidden />);
     expect(container.querySelector('.ant-drawer')).toBeTruthy();
 
-    rerender(<DrawerTest destroyOnClose open={false} />);
+    rerender(<DrawerTest destroyOnHidden open={false} />);
     act(() => {
       jest.runAllTimers();
     });
 
     expect(container.querySelector('.ant-drawer')).toBeFalsy();
   });
 
-  it('dom should be existed after close when destroyOnClose is false', () => {
+  it('dom should be existed after close when destroyOnHidden is false', () => {
     const { container, rerender } = render(<DrawerTest />);
     expect(container.querySelector('.ant-drawer')).toBeTruthy();
 
diff --git a/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap b/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
--- a/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
+++ b/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
@@ -203,7 +203,7 @@ exports[`Drawer closable is false 1`] = `
 </div>
 `;
 
-exports[`Drawer destroyOnClose is true 1`] = `null`;
+exports[`Drawer destroyOnHidden is true 1`] = `null`;
 
 exports[`Drawer getContainer return undefined 1`] = `<div />`;
 
diff --git a/components/dropdown/__tests__/dropdown-button.test.tsx b/components/dropdown/__tests__/dropdown-button.test.tsx
--- a/components/dropdown/__tests__/dropdown-button.test.tsx
+++ b/components/dropdown/__tests__/dropdown-button.test.tsx
@@ -181,7 +181,7 @@ describe('DropdownButton', () => {
       </DropdownButton>,
     );
     expect(errorSpy).toHaveBeenCalledWith(
-      'Warning: [antd: Dropdown] `destroyPopupOnHide` is deprecated. Please use `destroyOnClose` instead.',
+      'Warning: [antd: Dropdown] `destroyPopupOnHide` is deprecated. Please use `destroyOnHidden` instead.',
     );
     errorSpy.mockRestore();
   });
diff --git a/components/dropdown/__tests__/index.test.tsx b/components/dropdown/__tests__/index.test.tsx
--- a/components/dropdown/__tests__/index.test.tsx
+++ b/components/dropdown/__tests__/index.test.tsx
@@ -291,7 +291,7 @@ describe('Dropdown', () => {
       'Warning: [antd: Dropdown] `dropdownRender` is deprecated. Please use `popupRender` instead.',
     );
     expect(errorSpy).toHaveBeenCalledWith(
-      'Warning: [antd: Dropdown] `destroyPopupOnHide` is deprecated. Please use `destroyOnClose` instead.',
+      'Warning: [antd: Dropdown] `destroyPopupOnHide` is deprecated. Please use `destroyOnHidden` instead.',
     );
 
     expect(dropdownRender).toHaveBeenCalled();
diff --git a/components/tooltip/__tests__/tooltip.test.tsx b/components/tooltip/__tests__/tooltip.test.tsx
--- a/components/tooltip/__tests__/tooltip.test.tsx
+++ b/components/tooltip/__tests__/tooltip.test.tsx
@@ -544,7 +544,7 @@ describe('Tooltip', () => {
       </Tooltip>,
     );
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: Tooltip] `destroyTooltipOnHide` is deprecated. Please use `destroyOnClose` instead.',
+      'Warning: [antd: Tooltip] `destroyTooltipOnHide` is deprecated. Please use `destroyOnHidden` instead.',
     );
 
     // Event Trigger
EOF_114329324912

# Run the target tests using Jest
# Using --no-cache to ensure fresh test execution
# Using --maxWorkers=1 for single-process execution (safety in virtualized environment)
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/drawer/__tests__/Drawer.test.tsx" \
  "components/drawer/__tests__/DrawerEvent.test.tsx" \
  "components/dropdown/__tests__/dropdown-button.test.tsx" \
  "components/dropdown/__tests__/index.test.tsx" \
  "components/tooltip/__tests__/tooltip.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 482cfd94ec8a5123522eb96faefa4cf5671b544d \
  "components/drawer/__tests__/Drawer.test.tsx" \
  "components/drawer/__tests__/DrawerEvent.test.tsx" \
  "components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap" \
  "components/dropdown/__tests__/dropdown-button.test.tsx" \
  "components/dropdown/__tests__/index.test.tsx" \
  "components/tooltip/__tests__/tooltip.test.tsx"