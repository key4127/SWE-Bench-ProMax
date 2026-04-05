#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9f78366ca9298de655ad29f1add9fc9438c00a0f \
  "components/dropdown/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/dropdown/__tests__/index.test.tsx b/components/dropdown/__tests__/index.test.tsx
--- a/components/dropdown/__tests__/index.test.tsx
+++ b/components/dropdown/__tests__/index.test.tsx
@@ -259,7 +259,7 @@ describe('Dropdown', () => {
     errorSpy.mockRestore();
   });
 
-  it('legacy dropdownRender', () => {
+  it('legacy dropdownRender & legacy destroyPopupOnHide', () => {
     resetWarned();
     const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
     const dropdownRender = jest.fn((menu) => (
@@ -272,6 +272,7 @@ describe('Dropdown', () => {
     const { container } = render(
       <Dropdown
         open
+        destroyPopupOnHide
         dropdownRender={dropdownRender}
         menu={{
           items: [
@@ -289,6 +290,9 @@ describe('Dropdown', () => {
     expect(errorSpy).toHaveBeenCalledWith(
       'Warning: [antd: Dropdown] `dropdownRender` is deprecated. Please use `popupRender` instead.',
     );
+    expect(errorSpy).toHaveBeenCalledWith(
+      'Warning: [antd: Dropdown] `destroyPopupOnHide` is deprecated. Please use `destroyOnClose` instead.',
+    );
 
     expect(dropdownRender).toHaveBeenCalled();
     expect(container.querySelector('.custom-dropdown')).toBeTruthy();
EOF_114329324912

# Run the target test using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
# Using --no-cache to avoid potential cache issues
# Using --verbose for detailed output
npx jest --config .jest.js --no-cache --maxWorkers=1 --verbose \
  "components/dropdown/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9f78366ca9298de655ad29f1add9fc9438c00a0f \
  "components/dropdown/__tests__/index.test.tsx"