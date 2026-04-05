#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 10e93e5c6eab9b815777a706b53d2de65a5746d9 \
  "components/date-picker/__tests__/DatePicker.test.tsx" \
  "components/date-picker/__tests__/RangePicker.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/date-picker/__tests__/DatePicker.test.tsx b/components/date-picker/__tests__/DatePicker.test.tsx
--- a/components/date-picker/__tests__/DatePicker.test.tsx
+++ b/components/date-picker/__tests__/DatePicker.test.tsx
@@ -400,16 +400,35 @@ describe('DatePicker', () => {
     expect(triggerProps?.popupPlacement).toEqual('bottomRight');
   });
 
-  it('legacy dropdownClassName', () => {
+  it('legacy dropdownClassName & popupClassName', () => {
     resetWarned();
 
     const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
-    const { container } = render(<DatePicker dropdownClassName="legacy" open />);
+    const { container, rerender } = render(<DatePicker dropdownClassName="legacy" open />);
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: DatePicker] `dropdownClassName` is deprecated. Please use `popupClassName` instead.',
+      'Warning: [antd: DatePicker] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
+    rerender(<DatePicker popupClassName="legacy" open />);
+    expect(errSpy).toHaveBeenCalledWith(
+      'Warning: [antd: DatePicker] `popupClassName` is deprecated. Please use `classNames.popup.root` instead.',
+    );
+    expect(container.querySelector('.legacy')).toBeTruthy();
+
+    errSpy.mockRestore();
+  });
+
+  it('legacy popupStyle', () => {
+    resetWarned();
+
+    const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+    const { container } = render(<DatePicker popupStyle={{ backgroundColor: 'red' }} open />);
+    expect(errSpy).toHaveBeenCalledWith(
+      'Warning: [antd: DatePicker] `popupStyle` is deprecated. Please use `styles.popup.root` instead.',
+    );
+    expect(container.querySelector('.ant-picker-dropdown')).toHaveStyle('background-color: red');
+
     errSpy.mockRestore();
   });
 
diff --git a/components/date-picker/__tests__/RangePicker.test.tsx b/components/date-picker/__tests__/RangePicker.test.tsx
--- a/components/date-picker/__tests__/RangePicker.test.tsx
+++ b/components/date-picker/__tests__/RangePicker.test.tsx
@@ -148,19 +148,42 @@ describe('RangePicker', () => {
     expect(container.querySelectorAll('input')[1]?.placeholder).toEqual('End quarter');
   });
 
-  it('legacy dropdownClassName', () => {
+  it('legacy dropdownClassName & popupClassName', () => {
     resetWarned();
 
     const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
-    const { container } = render(<DatePicker.RangePicker dropdownClassName="legacy" open />);
+    const { container, rerender } = render(
+      <DatePicker.RangePicker dropdownClassName="legacy" open />,
+    );
+    expect(errSpy).toHaveBeenCalledWith(
+      'Warning: [antd: DatePicker.RangePicker] `dropdownClassName` is deprecated. Please use `classNames.popup.root` instead.',
+    );
+    expect(container.querySelector('.legacy')).toBeTruthy();
+
+    rerender(<DatePicker.RangePicker popupClassName="legacy" open />);
     expect(errSpy).toHaveBeenCalledWith(
-      'Warning: [antd: DatePicker.RangePicker] `dropdownClassName` is deprecated. Please use `popupClassName` instead.',
+      'Warning: [antd: DatePicker.RangePicker] `popupClassName` is deprecated. Please use `classNames.popup.root` instead.',
     );
     expect(container.querySelector('.legacy')).toBeTruthy();
 
     errSpy.mockRestore();
   });
 
+  it('legacy popupStyle', () => {
+    resetWarned();
+
+    const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+    const { container } = render(
+      <DatePicker.RangePicker popupStyle={{ backgroundColor: 'red' }} open />,
+    );
+    expect(errSpy).toHaveBeenCalledWith(
+      'Warning: [antd: DatePicker.RangePicker] `popupStyle` is deprecated. Please use `styles.popup.root` instead.',
+    );
+    expect(container.querySelector('.ant-picker-dropdown')).toHaveStyle('background-color: red');
+
+    errSpy.mockRestore();
+  });
+
   it('allows or prohibits clearing as applicable', async () => {
     const somePoint = dayjs('2023-08-01');
     const { rerender, container } = render(
diff --git a/components/date-picker/__tests__/semantic.test.tsx b/components/date-picker/__tests__/semantic.test.tsx
new file mode 100644
--- /dev/null
+++ b/components/date-picker/__tests__/semantic.test.tsx
@@ -0,0 +1,84 @@
+import React from 'react';
+
+import type { DatePickerProps } from '..';
+import DatePicker from '..';
+import { render } from '../../../tests/utils';
+
+describe('DatePicker.Semantic', () => {
+  describe('inline', () => {
+    function test(name: string, renderFn: (props: any) => React.ReactElement) {
+      it(name, () => {
+        const classNames: Required<NonNullable<DatePickerProps['classNames']>> = {
+          root: 'my-root',
+          popup: { root: 'my-popup' },
+        };
+
+        const styles = {
+          root: { backgroundColor: 'red' },
+          popup: { root: { backgroundColor: 'purple' } },
+        };
+
+        render(renderFn({ classNames, styles, open: true }));
+
+        expect(document.body.querySelector(`.ant-picker`)).toHaveClass(classNames.root);
+        expect(document.body.querySelector(`.ant-picker-dropdown`)).toHaveClass(
+          classNames.popup?.root!,
+        );
+
+        expect(document.body.querySelector(`.${classNames.root}`)).toHaveStyle(styles.root);
+        expect(document.body.querySelector(`.${classNames.popup?.root!}`)).toHaveStyle(
+          styles.popup.root,
+        );
+      });
+    }
+
+    test('DatePicker - Single', (props) => <DatePicker {...props} />);
+    test('DatePicker - Multiple', (props) => <DatePicker.RangePicker {...props} />);
+    test('TimePicker - Single', (props) => <DatePicker {...props} picker="time" />);
+    test('TimePicker - Multiple', (props) => <DatePicker.RangePicker {...props} picker="time" />);
+
+    it('DatePicker - Single - with popup className as string', () => {
+      const classNamesConfig = {
+        root: 'my-custom-root-str-popup',
+        popup: 'my-custom-popup-flat-string',
+      } as any;
+      const stylesConfig = {
+        root: { color: 'rgb(255, 0, 0)' },
+        popup: { root: { color: 'rgb(0, 0, 255)' } },
+      };
+
+      render(<DatePicker classNames={classNamesConfig} styles={stylesConfig} open />);
+
+      const pickerElement = document.body.querySelector('.ant-picker');
+      const dropdownElement = document.body.querySelector('.ant-picker-dropdown');
+
+      expect(pickerElement).toHaveClass(classNamesConfig.root);
+      expect(dropdownElement).toHaveClass(classNamesConfig.popup);
+
+      expect(pickerElement).toHaveStyle(stylesConfig.root);
+      expect(dropdownElement).toHaveStyle(stylesConfig.popup.root);
+    });
+
+    it('DatePicker.RangePicker - with popup className as string', () => {
+      const classNamesConfig = {
+        root: 'my-custom-range-root-str-popup',
+        popup: 'my-custom-range-popup-flat-string',
+      } as any;
+      const stylesConfig = {
+        root: { borderColor: 'rgb(0, 255, 0)' }, // green
+        popup: { root: { borderColor: 'rgb(255, 255, 0)' } }, // yellow
+      };
+
+      render(<DatePicker.RangePicker classNames={classNamesConfig} styles={stylesConfig} open />);
+
+      const pickerElement = document.body.querySelector('.ant-picker');
+      const dropdownElement = document.body.querySelector('.ant-picker-dropdown');
+
+      expect(pickerElement).toHaveClass(classNamesConfig.root);
+      expect(dropdownElement).toHaveClass(classNamesConfig.popup);
+
+      expect(pickerElement).toHaveStyle(stylesConfig.root);
+      expect(dropdownElement).toHaveStyle(stylesConfig.popup.root);
+    });
+  });
+});
EOF_114329324912

# Run the target tests using Jest via Bun
# Using --maxWorkers=1 to ensure single-process execution for stability in virtualized environment
# Running both test files in a single command for efficiency
bun run test -- --maxWorkers=1 \
  "components/date-picker/__tests__/DatePicker.test.tsx" \
  "components/date-picker/__tests__/RangePicker.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 10e93e5c6eab9b815777a706b53d2de65a5746d9 \
  "components/date-picker/__tests__/DatePicker.test.tsx" \
  "components/date-picker/__tests__/RangePicker.test.tsx"