#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout b1467d6ec8c29f13ae894918ace83222b13d7783 \
  "components/space/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/space/__tests__/__snapshots__/demo.test.tsx.snap" \
  "components/space/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/space/__tests__/index.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/space/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/space/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/space/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/space/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -16736,6 +16736,58 @@ Array [
 
 exports[`renders components/space/demo/gap-in-line.tsx extend context correctly 2`] = `[]`;
 
+exports[`renders components/space/demo/separator.tsx extend context correctly 1`] = `
+<div
+  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-test-id"
+>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    <div
+      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
+      role="separator"
+    />
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    <div
+      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
+      role="separator"
+    />
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+</div>
+`;
+
+exports[`renders components/space/demo/separator.tsx extend context correctly 2`] = `[]`;
+
 exports[`renders components/space/demo/size.tsx extend context correctly 1`] = `
 Array [
   <div
@@ -16890,58 +16942,6 @@ Array [
 
 exports[`renders components/space/demo/size.tsx extend context correctly 2`] = `[]`;
 
-exports[`renders components/space/demo/split.tsx extend context correctly 1`] = `
-<div
-  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-test-id"
->
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    <div
-      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
-      role="separator"
-    />
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    <div
-      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
-      role="separator"
-    />
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-</div>
-`;
-
-exports[`renders components/space/demo/split.tsx extend context correctly 2`] = `[]`;
-
 exports[`renders components/space/demo/vertical.tsx extend context correctly 1`] = `
 <div
   class="ant-space ant-space-vertical ant-space-gap-row-middle ant-space-gap-col-middle css-var-test-id"
diff --git a/components/space/__tests__/__snapshots__/demo.test.tsx.snap b/components/space/__tests__/__snapshots__/demo.test.tsx.snap
--- a/components/space/__tests__/__snapshots__/demo.test.tsx.snap
+++ b/components/space/__tests__/__snapshots__/demo.test.tsx.snap
@@ -4543,6 +4543,56 @@ Array [
 ]
 `;
 
+exports[`renders components/space/demo/separator.tsx correctly 1`] = `
+<div
+  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-test-id"
+>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    <div
+      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
+      role="separator"
+    />
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    <div
+      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
+      role="separator"
+    />
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    <a
+      class="ant-typography css-var-test-id"
+    >
+      Link
+    </a>
+  </div>
+</div>
+`;
+
 exports[`renders components/space/demo/size.tsx correctly 1`] = `
 Array [
   <div
@@ -4695,56 +4745,6 @@ Array [
 ]
 `;
 
-exports[`renders components/space/demo/split.tsx correctly 1`] = `
-<div
-  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-test-id"
->
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    <div
-      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
-      role="separator"
-    />
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    <div
-      class="ant-divider css-var-test-id ant-divider-vertical ant-divider-rail"
-      role="separator"
-    />
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    <a
-      class="ant-typography css-var-test-id"
-    >
-      Link
-    </a>
-  </div>
-</div>
-`;
-
 exports[`renders components/space/demo/vertical.tsx correctly 1`] = `
 <div
   class="ant-space ant-space-vertical ant-space-gap-row-middle ant-space-gap-col-middle css-var-test-id"
diff --git a/components/space/__tests__/__snapshots__/index.test.tsx.snap b/components/space/__tests__/__snapshots__/index.test.tsx.snap
--- a/components/space/__tests__/__snapshots__/index.test.tsx.snap
+++ b/components/space/__tests__/__snapshots__/index.test.tsx.snap
@@ -2,6 +2,40 @@
 
 exports[`Space rtl render component should be rendered correctly in RTL direction 1`] = `null`;
 
+exports[`Space separator 1`] = `
+<div
+  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-root"
+>
+  <div
+    class="ant-space-item"
+  >
+    text1
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    -
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    <span>
+      text1
+    </span>
+  </div>
+  <span
+    class="ant-space-item-separator"
+  >
+    -
+  </span>
+  <div
+    class="ant-space-item"
+  >
+    text3
+  </div>
+</div>
+`;
+
 exports[`Space should render correct with children 1`] = `
 <div
   class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-root"
@@ -143,37 +177,3 @@ Array [
   </div>,
 ]
 `;
-
-exports[`Space split 1`] = `
-<div
-  class="ant-space ant-space-horizontal ant-space-align-center ant-space-gap-row-small ant-space-gap-col-small css-var-root"
->
-  <div
-    class="ant-space-item"
-  >
-    text1
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    -
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    <span>
-      text1
-    </span>
-  </div>
-  <span
-    class="ant-space-item-split"
-  >
-    -
-  </span>
-  <div
-    class="ant-space-item"
-  >
-    text3
-  </div>
-</div>
-`;
diff --git a/components/space/__tests__/index.test.tsx b/components/space/__tests__/index.test.tsx
--- a/components/space/__tests__/index.test.tsx
+++ b/components/space/__tests__/index.test.tsx
@@ -166,9 +166,9 @@ describe('Space', () => {
     expect(container.querySelector('#demo')).toHaveTextContent('2');
   });
 
-  it('split', () => {
+  it('separator', () => {
     const { container } = render(
-      <Space split="-">
+      <Space separator="-">
         text1<span>text1</span>
         <>text3</>
       </Space>,
@@ -177,6 +177,22 @@ describe('Space', () => {
     expect(container.children[0]).toMatchSnapshot();
   });
 
+  it('legacy split', () => {
+    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
+
+    render(
+      <Space split="-">
+        text1<span>text1</span>
+        <>text3</>
+      </Space>,
+    );
+    expect(errorSpy).toHaveBeenCalledWith(
+      'Warning: [antd: Space] `split` is deprecated. Please use `separator` instead.',
+    );
+
+    errorSpy.mockRestore();
+  });
+
   // https://github.com/ant-design/ant-design/issues/35305
   it('should not throw duplicated key warning', () => {
     const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
@@ -224,29 +240,34 @@ describe('Space', () => {
     const customClassNames = {
       root: 'custom-root',
       item: 'custom-item',
+      separator: 'custom-separator',
     };
 
     const customStyles = {
-      root: { backgroundColor: 'green' },
+      root: { color: 'green' },
       item: { color: 'red' },
+      separator: { color: 'blue' },
     };
     const { container } = render(
-      <Space classNames={customClassNames} styles={customStyles}>
+      <Space classNames={customClassNames} styles={customStyles} separator="-">
         <span>Text1</span>
         <span>Text2</span>
       </Space>,
     );
 
     const rootElement = container.querySelector('.ant-space') as HTMLElement;
     const itemElement = container.querySelector('.ant-space-item') as HTMLElement;
+    const separatorElement = container.querySelector('.ant-space-item-separator') as HTMLElement;
 
     // Check classNames
     expect(rootElement.classList).toContain('custom-root');
     expect(itemElement.classList).toContain('custom-item');
+    expect(separatorElement.classList).toContain('custom-separator');
 
     // Check styles
-    expect(rootElement.style.backgroundColor).toBe('green');
-    expect(itemElement.style.color).toBe('red');
+    expect(rootElement.style.color).toBe(customStyles.root.color);
+    expect(itemElement.style.color).toBe(customStyles.item.color);
+    expect(separatorElement.style.color).toBe(customStyles.separator.color);
   });
 
   // ============================= orientation =============================
EOF_114329324912

# Run the target tests using Jest
# Execute the test file with snapshot tests included
# Using --maxWorkers=1 to ensure single-process execution for stability
# The snapshot files are automatically loaded by Jest when running the test file
npx jest --config .jest.js --no-cache --maxWorkers=1 --verbose \
  "components/space/__tests__/index.test.tsx"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout b1467d6ec8c29f13ae894918ace83222b13d7783 \
  "components/space/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/space/__tests__/__snapshots__/demo.test.tsx.snap" \
  "components/space/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/space/__tests__/index.test.tsx"