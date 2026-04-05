#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 3d70185b9315d95ac82a3aa71ec794aa3f47f707 "components/cascader/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/cascader/__tests__/index.test.tsx b/components/cascader/__tests__/index.test.tsx
--- a/components/cascader/__tests__/index.test.tsx
+++ b/components/cascader/__tests__/index.test.tsx
@@ -548,13 +548,29 @@ describe('Cascader', () => {
       const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
       const { container } = render(<Cascader dropdownClassName="legacy" open />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Cascader] `dropdownClassName` is deprecated. Please use `popupClassName` instead.',
+        'Warning: [antd: Cascader] `dropdownClassName` is deprecated. Please use `classNames.popup` instead.',
       );
       expect(container.querySelector('.legacy')).toBeTruthy();
 
       errSpy.mockRestore();
     });
 
+    it('legacy dropdownStyle', () => {
+      resetWarned();
+
+      const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+      const customStyle = { background: 'red' };
+      const { container } = render(<Cascader dropdownStyle={customStyle} open />);
+      expect(errSpy).toHaveBeenCalledWith(
+        'Warning: [antd: Cascader] `dropdownStyle` is deprecated. Please use `styles.popup` instead.',
+      );
+      expect(container.querySelector('.ant-select-dropdown')?.getAttribute('style')).toContain(
+        'background: red',
+      );
+
+      errSpy.mockRestore();
+    });
+
     it('legacy dropdownRender', () => {
       resetWarned();
 
@@ -604,7 +620,7 @@ describe('Cascader', () => {
       const onDropdownVisibleChange = jest.fn();
       const { container } = render(<Cascader onDropdownVisibleChange={onDropdownVisibleChange} />);
       expect(errSpy).toHaveBeenCalledWith(
-        'Warning: [antd: Cascader] `onDropdownVisibleChange` is deprecated. Please use `onPopupVisibleChange` instead.',
+        'Warning: [antd: Cascader] `onDropdownVisibleChange` is deprecated. Please use `onOpenChange` instead.',
       );
 
       toggleOpen(container);
EOF_114329324912

# Run the target test using Jest with proper configuration
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/cascader/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 3d70185b9315d95ac82a3aa71ec794aa3f47f707 "components/cascader/__tests__/index.test.tsx"