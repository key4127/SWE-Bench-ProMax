#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 15cf94ff1805c567d991091d1bcc25dcc0bb7c6c \
  "components/cascader/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/cascader/__tests__/index.test.tsx b/components/cascader/__tests__/index.test.tsx
--- a/components/cascader/__tests__/index.test.tsx
+++ b/components/cascader/__tests__/index.test.tsx
@@ -555,6 +555,64 @@ describe('Cascader', () => {
       errSpy.mockRestore();
     });
 
+    it('legacy dropdownRender', () => {
+      resetWarned();
+
+      const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+      const customContent = <div className="custom-dropdown-content">Custom Content</div>;
+      const dropdownRender = (menu: React.ReactElement) => (
+        <>
+          {menu}
+          {customContent}
+        </>
+      );
+
+      const { container } = render(<Cascader dropdownRender={dropdownRender} open />);
+      expect(errSpy).toHaveBeenCalledWith(
+        'Warning: [antd: Cascader] `dropdownRender` is deprecated. Please use `popupRender` instead.',
+      );
+      expect(container.querySelector('.custom-dropdown-content')).toBeTruthy();
+
+      errSpy.mockRestore();
+    });
+
+    it('legacy dropdownMenuColumnStyle', () => {
+      resetWarned();
+
+      const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+      const columnStyle = { background: 'red' };
+      const { getByRole } = render(
+        <Cascader
+          options={[{ label: 'test', value: 1 }]}
+          dropdownMenuColumnStyle={columnStyle}
+          open
+        />,
+      );
+      expect(errSpy).toHaveBeenCalledWith(
+        'Warning: [antd: Cascader] `dropdownMenuColumnStyle` is deprecated. Please use `popupMenuColumnStyle` instead.',
+      );
+      const menuColumn = getByRole('menuitemcheckbox');
+      expect(menuColumn.style.background).toBe('red');
+
+      errSpy.mockRestore();
+    });
+
+    it('legacy onDropdownVisibleChange', () => {
+      resetWarned();
+
+      const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+      const onDropdownVisibleChange = jest.fn();
+      const { container } = render(<Cascader onDropdownVisibleChange={onDropdownVisibleChange} />);
+      expect(errSpy).toHaveBeenCalledWith(
+        'Warning: [antd: Cascader] `onDropdownVisibleChange` is deprecated. Please use `onPopupVisibleChange` instead.',
+      );
+
+      toggleOpen(container);
+      expect(onDropdownVisibleChange).toHaveBeenCalledWith(true);
+
+      errSpy.mockRestore();
+    });
+
     it('should support showCheckedStrategy child', () => {
       const multipleOptions = [
         {
EOF_114329324912

# Run the target test using Jest
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/cascader/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 15cf94ff1805c567d991091d1bcc25dcc0bb7c6c \
  "components/cascader/__tests__/index.test.tsx"