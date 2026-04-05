#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 0c80d6c5fcea68a391777aead400b7785f5b13b8 \
  "components/card/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/card/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/card/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/config-provider/__tests__/__snapshots__/components.test.tsx.snap" \
  "components/config-provider/__tests__/style.test.tsx" \
  "components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap" \
  "components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap" \
  "components/list/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/list/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap" \
  "components/skeleton/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/skeleton/__tests__/index.test.tsx" \
  "components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/statistic/__tests__/__snapshots__/demo.test.ts.snap"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/card/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/card/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/card/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/card/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -736,7 +736,7 @@ exports[`renders components/card/demo/loading.tsx extend context correctly 1`] =
         class="ant-skeleton ant-skeleton-active"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <ul
             class="ant-skeleton-paragraph"
@@ -842,7 +842,7 @@ exports[`renders components/card/demo/loading.tsx extend context correctly 1`] =
         class="ant-skeleton ant-skeleton-active"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <ul
             class="ant-skeleton-paragraph"
diff --git a/components/card/__tests__/__snapshots__/demo.test.ts.snap b/components/card/__tests__/__snapshots__/demo.test.ts.snap
--- a/components/card/__tests__/__snapshots__/demo.test.ts.snap
+++ b/components/card/__tests__/__snapshots__/demo.test.ts.snap
@@ -699,7 +699,7 @@ exports[`renders components/card/demo/loading.tsx correctly 1`] = `
         class="ant-skeleton ant-skeleton-active"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <ul
             class="ant-skeleton-paragraph"
@@ -805,7 +805,7 @@ exports[`renders components/card/demo/loading.tsx correctly 1`] = `
         class="ant-skeleton ant-skeleton-active"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <ul
             class="ant-skeleton-paragraph"
diff --git a/components/card/__tests__/__snapshots__/index.test.tsx.snap b/components/card/__tests__/__snapshots__/index.test.tsx.snap
--- a/components/card/__tests__/__snapshots__/index.test.tsx.snap
+++ b/components/card/__tests__/__snapshots__/index.test.tsx.snap
@@ -282,7 +282,7 @@ exports[`Card should still have padding when card which set padding to 0 is load
       class="ant-skeleton ant-skeleton-active"
     >
       <div
-        class="ant-skeleton-content"
+        class="ant-skeleton-section"
       >
         <ul
           class="ant-skeleton-paragraph"
diff --git a/components/config-provider/__tests__/__snapshots__/components.test.tsx.snap b/components/config-provider/__tests__/__snapshots__/components.test.tsx.snap
--- a/components/config-provider/__tests__/__snapshots__/components.test.tsx.snap
+++ b/components/config-provider/__tests__/__snapshots__/components.test.tsx.snap
@@ -25405,7 +25405,7 @@ exports[`ConfigProvider components Skeleton configProvider 1`] = `
     />
   </div>
   <div
-    class="config-skeleton-content"
+    class="config-skeleton-section"
   >
     <h3
       class="config-skeleton-title"
@@ -25433,7 +25433,7 @@ exports[`ConfigProvider components Skeleton configProvider componentDisabled 1`]
     />
   </div>
   <div
-    class="config-skeleton-content"
+    class="config-skeleton-section"
   >
     <h3
       class="config-skeleton-title"
@@ -25461,7 +25461,7 @@ exports[`ConfigProvider components Skeleton configProvider componentSize large 1
     />
   </div>
   <div
-    class="config-skeleton-content"
+    class="config-skeleton-section"
   >
     <h3
       class="config-skeleton-title"
@@ -25489,7 +25489,7 @@ exports[`ConfigProvider components Skeleton configProvider componentSize middle
     />
   </div>
   <div
-    class="config-skeleton-content"
+    class="config-skeleton-section"
   >
     <h3
       class="config-skeleton-title"
@@ -25517,7 +25517,7 @@ exports[`ConfigProvider components Skeleton configProvider componentSize small 1
     />
   </div>
   <div
-    class="config-skeleton-content"
+    class="config-skeleton-section"
   >
     <h3
       class="config-skeleton-title"
@@ -25545,7 +25545,7 @@ exports[`ConfigProvider components Skeleton normal 1`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -25573,7 +25573,7 @@ exports[`ConfigProvider components Skeleton prefixCls 1`] = `
     />
   </div>
   <div
-    class="prefix-Skeleton-content"
+    class="prefix-Skeleton-section"
   >
     <h3
       class="prefix-Skeleton-title"
diff --git a/components/config-provider/__tests__/style.test.tsx b/components/config-provider/__tests__/style.test.tsx
--- a/components/config-provider/__tests__/style.test.tsx
+++ b/components/config-provider/__tests__/style.test.tsx
@@ -42,6 +42,7 @@ import Result from '../../result';
 import Segmented from '../../segmented';
 import Select from '../../select';
 import Skeleton from '../../skeleton';
+import type { SemanticName as SkeletonSemanticName } from '../../skeleton/Skeleton';
 import Slider from '../../slider';
 import Space from '../../space';
 import Spin from '../../spin';
@@ -381,6 +382,63 @@ describe('ConfigProvider support style and className props', () => {
     expect(container.querySelector('.ant-skeleton')).toHaveStyle('color: red; font-size: 16px;');
   });
 
+  it('Should Skeleton classNames & styles works', () => {
+    const rootStyle = { background: 'pink' };
+    const headerStyle = { background: 'green' };
+    const sectionStyle = { background: 'yellow' };
+    const avatarStyle = { background: 'blue' };
+    const titleStyle = { background: 'red' };
+    const paragraphStyle = { background: 'orange' };
+
+    const customStyles: Record<SkeletonSemanticName, React.CSSProperties> = {
+      root: rootStyle,
+      header: headerStyle,
+      section: sectionStyle,
+      avatar: avatarStyle,
+      title: titleStyle,
+      paragraph: paragraphStyle,
+    };
+
+    const customClassNames: Record<SkeletonSemanticName, string> = {
+      root: 'custom-root',
+      header: 'custom-header',
+      section: 'custom-section',
+      avatar: 'custom-avatar',
+      title: 'custom-title',
+      paragraph: 'custom-paragraph',
+    };
+
+    const { container } = render(
+      <ConfigProvider skeleton={{ styles: customStyles, classNames: customClassNames }}>
+        <Skeleton avatar />
+      </ConfigProvider>,
+    );
+
+    const rootElement = container.querySelector('.ant-skeleton');
+    expect(rootElement).toHaveStyle(rootStyle);
+    expect(rootElement).toHaveClass(customClassNames.root);
+
+    const headerElement = container.querySelector('.ant-skeleton-header');
+    expect(headerElement).toHaveStyle(headerStyle);
+    expect(headerElement).toHaveClass(customClassNames.header);
+
+    const sectionElement = container.querySelector('.ant-skeleton-section');
+    expect(sectionElement).toHaveStyle(sectionStyle);
+    expect(sectionElement).toHaveClass(customClassNames.section);
+
+    const avatarElement = container.querySelector('.ant-skeleton-avatar');
+    expect(avatarElement).toHaveStyle(avatarStyle);
+    expect(avatarElement).toHaveClass(customClassNames.avatar);
+
+    const titleElement = container.querySelector('.ant-skeleton-title');
+    expect(titleElement).toHaveStyle(titleStyle);
+    expect(titleElement).toHaveClass(customClassNames.title);
+
+    const paragraphElement = container.querySelector('.ant-skeleton-paragraph');
+    expect(paragraphElement).toHaveStyle(paragraphStyle);
+    expect(paragraphElement).toHaveClass(customClassNames.paragraph);
+  });
+
   it('Should Spin className & style works', () => {
     const { container } = render(
       <ConfigProvider
diff --git a/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap b/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
--- a/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
+++ b/components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap
@@ -64,7 +64,7 @@ exports[`Drawer Drawer loading have a spinner 1`] = `
           class="ant-skeleton ant-skeleton-active ant-drawer-body-skeleton"
         >
           <div
-            class="ant-skeleton-content"
+            class="ant-skeleton-section"
           >
             <ul
               class="ant-skeleton-paragraph"
diff --git a/components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap b/components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap
--- a/components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap
+++ b/components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap
@@ -2897,7 +2897,7 @@ Array [
             class="ant-skeleton ant-skeleton-active ant-drawer-body-skeleton"
           >
             <div
-              class="ant-skeleton-content"
+              class="ant-skeleton-section"
             >
               <ul
                 class="ant-skeleton-paragraph"
diff --git a/components/list/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/list/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/list/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/list/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -1771,7 +1771,7 @@ exports[`renders components/list/demo/infinite-load.tsx extend context correctly
           />
         </div>
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
diff --git a/components/list/__tests__/__snapshots__/demo.test.ts.snap b/components/list/__tests__/__snapshots__/demo.test.ts.snap
--- a/components/list/__tests__/__snapshots__/demo.test.ts.snap
+++ b/components/list/__tests__/__snapshots__/demo.test.ts.snap
@@ -1768,7 +1768,7 @@ exports[`renders components/list/demo/infinite-load.tsx correctly 1`] = `
           />
         </div>
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
diff --git a/components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -5,7 +5,7 @@ exports[`renders components/skeleton/demo/active.tsx extend context correctly 1`
   class="ant-skeleton ant-skeleton-active"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -31,7 +31,7 @@ exports[`renders components/skeleton/demo/basic.tsx extend context correctly 1`]
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -98,7 +98,7 @@ exports[`renders components/skeleton/demo/complex.tsx extend context correctly 1
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -123,7 +123,7 @@ exports[`renders components/skeleton/demo/componentToken.tsx extend context corr
   class="ant-skeleton ant-skeleton-active"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -234,7 +234,7 @@ exports[`renders components/skeleton/demo/element.tsx extend context correctly 1
         class="ant-skeleton ant-skeleton-element"
       >
         <div
-          class="ant-skeleton-image"
+          class="ant-skeleton-node"
           style="width: 160px;"
         />
       </div>
@@ -246,7 +246,7 @@ exports[`renders components/skeleton/demo/element.tsx extend context correctly 1
         class="ant-skeleton ant-skeleton-element"
       >
         <div
-          class="ant-skeleton-image"
+          class="ant-skeleton-node"
         >
           <span
             aria-label="dot-chart"
@@ -763,7 +763,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
@@ -792,7 +792,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
@@ -821,7 +821,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
diff --git a/components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap b/components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap
--- a/components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap
+++ b/components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap
@@ -5,7 +5,7 @@ exports[`renders components/skeleton/demo/active.tsx correctly 1`] = `
   class="ant-skeleton ant-skeleton-active"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -29,7 +29,7 @@ exports[`renders components/skeleton/demo/basic.tsx correctly 1`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -92,7 +92,7 @@ exports[`renders components/skeleton/demo/complex.tsx correctly 1`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -115,7 +115,7 @@ exports[`renders components/skeleton/demo/componentToken.tsx correctly 1`] = `
   class="ant-skeleton ant-skeleton-active"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -224,7 +224,7 @@ exports[`renders components/skeleton/demo/element.tsx correctly 1`] = `
         class="ant-skeleton ant-skeleton-element"
       >
         <div
-          class="ant-skeleton-image"
+          class="ant-skeleton-node"
           style="width:160px"
         />
       </div>
@@ -236,7 +236,7 @@ exports[`renders components/skeleton/demo/element.tsx correctly 1`] = `
         class="ant-skeleton ant-skeleton-element"
       >
         <div
-          class="ant-skeleton-image"
+          class="ant-skeleton-node"
         >
           <span
             aria-label="dot-chart"
@@ -751,7 +751,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
@@ -780,7 +780,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
@@ -809,7 +809,7 @@ Array [
                 />
               </div>
               <div
-                class="ant-skeleton-content"
+                class="ant-skeleton-section"
               >
                 <h3
                   class="ant-skeleton-title"
diff --git a/components/skeleton/__tests__/__snapshots__/index.test.tsx.snap b/components/skeleton/__tests__/__snapshots__/index.test.tsx.snap
--- a/components/skeleton/__tests__/__snapshots__/index.test.tsx.snap
+++ b/components/skeleton/__tests__/__snapshots__/index.test.tsx.snap
@@ -83,7 +83,7 @@ exports[`Skeleton avatar shape 1`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -111,7 +111,7 @@ exports[`Skeleton avatar shape 2`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -139,7 +139,7 @@ exports[`Skeleton avatar size 1`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -167,7 +167,7 @@ exports[`Skeleton avatar size 2`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -195,7 +195,7 @@ exports[`Skeleton avatar size 3`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -224,7 +224,7 @@ exports[`Skeleton avatar size 4`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -325,7 +325,7 @@ exports[`Skeleton custom node element should render normal 1`] = `
   class="ant-skeleton ant-skeleton-element"
 >
   <div
-    class="ant-skeleton-image"
+    class="ant-skeleton-node"
   />
 </div>
 `;
@@ -335,7 +335,7 @@ exports[`Skeleton custom node element should render normal 2`] = `
   class="ant-skeleton ant-skeleton-element"
 >
   <div
-    class="ant-skeleton-image"
+    class="ant-skeleton-node"
   >
     <span>
       Custom Content Node
@@ -413,7 +413,7 @@ exports[`Skeleton paragraph rows 1`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -439,7 +439,7 @@ exports[`Skeleton paragraph width 1`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -463,7 +463,7 @@ exports[`Skeleton paragraph width 2`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -489,7 +489,7 @@ exports[`Skeleton rtl render component should be rendered correctly in RTL direc
   class="ant-skeleton ant-skeleton-rtl"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -515,7 +515,7 @@ exports[`Skeleton should round title and paragraph 1`] = `
   class="ant-skeleton ant-skeleton-round"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -546,7 +546,7 @@ exports[`Skeleton should square avatar 1`] = `
     />
   </div>
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -561,7 +561,7 @@ exports[`Skeleton should support style 1`] = `
   style="background: blue;"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -585,7 +585,7 @@ exports[`Skeleton should without avatar and paragraph 1`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
@@ -599,7 +599,7 @@ exports[`Skeleton title width 1`] = `
   class="ant-skeleton"
 >
   <div
-    class="ant-skeleton-content"
+    class="ant-skeleton-section"
   >
     <h3
       class="ant-skeleton-title"
diff --git a/components/skeleton/__tests__/index.test.tsx b/components/skeleton/__tests__/index.test.tsx
--- a/components/skeleton/__tests__/index.test.tsx
+++ b/components/skeleton/__tests__/index.test.tsx
@@ -6,10 +6,11 @@ import rtlTest from '../../../tests/shared/rtlTest';
 import { render } from '../../../tests/utils';
 import type { AvatarProps } from '../Avatar';
 import type { SkeletonButtonProps } from '../Button';
+import { ElementSemanticName } from '../Element';
 import type { SkeletonImageProps } from '../Image';
 import type { SkeletonInputProps } from '../Input';
 import type { SkeletonNodeProps } from '../Node';
-import type { SkeletonProps } from '../Skeleton';
+import type { SemanticName, SkeletonProps } from '../Skeleton';
 
 describe('Skeleton', () => {
   const genSkeleton = (props: SkeletonProps) =>
@@ -186,4 +187,157 @@ describe('Skeleton', () => {
     const { asFragment } = genSkeleton({ style: { background: 'blue' } });
     expect(asFragment().firstChild).toMatchSnapshot();
   });
+
+  it('Skeleton should apply custom styles to semantic elements', () => {
+    const rootStyle = { background: 'pink' };
+    const headerStyle = { background: 'green' };
+    const sectionStyle = { background: 'yellow' };
+    const avatarStyle = { background: 'blue' };
+    const titleStyle = { background: 'red' };
+    const paragraphStyle = { background: 'orange' };
+
+    const customStyles: Record<SemanticName, React.CSSProperties> = {
+      root: rootStyle,
+      header: headerStyle,
+      section: sectionStyle,
+      avatar: avatarStyle,
+      title: titleStyle,
+      paragraph: paragraphStyle,
+    };
+
+    const customClassNames: Record<SemanticName, string> = {
+      root: 'custom-root',
+      header: 'custom-header',
+      section: 'custom-section',
+      avatar: 'custom-avatar',
+      title: 'custom-title',
+      paragraph: 'custom-paragraph',
+    };
+
+    const { container } = genSkeleton({
+      styles: customStyles,
+      classNames: customClassNames,
+      avatar: true,
+    });
+
+    const rootElement = container.querySelector('.ant-skeleton');
+    expect(rootElement).toHaveStyle(rootStyle);
+    expect(rootElement).toHaveClass(customClassNames.root);
+
+    const headerElement = container.querySelector('.ant-skeleton-header');
+    expect(headerElement).toHaveStyle(headerStyle);
+    expect(headerElement).toHaveClass(customClassNames.header);
+
+    const sectionElement = container.querySelector('.ant-skeleton-section');
+    expect(sectionElement).toHaveStyle(sectionStyle);
+    expect(sectionElement).toHaveClass(customClassNames.section);
+
+    const avatarElement = container.querySelector('.ant-skeleton-avatar');
+    expect(avatarElement).toHaveStyle(avatarStyle);
+    expect(avatarElement).toHaveClass(customClassNames.avatar);
+
+    const titleElement = container.querySelector('.ant-skeleton-title');
+    expect(titleElement).toHaveStyle(titleStyle);
+    expect(titleElement).toHaveClass(customClassNames.title);
+
+    const paragraphElement = container.querySelector('.ant-skeleton-paragraph');
+    expect(paragraphElement).toHaveStyle(paragraphStyle);
+    expect(paragraphElement).toHaveClass(customClassNames.paragraph);
+  });
+
+  it('Elements should apply custom styles to semantic elements', () => {
+    const elements = ['avatar', 'button', 'input', 'node', 'image'] as const;
+    const rootStyle = { background: 'pink' };
+    const elementStyle = { background: 'green' };
+
+    type Elements = (typeof elements)[number];
+    type SemanticRecord<T> = Partial<Record<Elements, Record<ElementSemanticName, T>>>;
+
+    const customStyles: SemanticRecord<React.CSSProperties> = elements.reduce(
+      (prev, cur) => ({
+        ...prev,
+        [cur]: {
+          root: rootStyle,
+          content: elementStyle,
+        },
+      }),
+      {},
+    );
+
+    const customClassNames: SemanticRecord<string> = elements.reduce(
+      (prev, cur) => ({
+        ...prev,
+        [cur]: {
+          root: 'custom-root',
+          content: `custom-${cur}`,
+        },
+      }),
+      {},
+    );
+
+    const { container: avatarContainer } = genSkeletonAvatar({
+      styles: customStyles.avatar,
+      classNames: customClassNames.avatar,
+    });
+
+    const avatarRootElement = avatarContainer.querySelector('.ant-skeleton');
+    expect(avatarRootElement).toHaveStyle(rootStyle);
+    expect(avatarRootElement).toHaveClass(customClassNames.avatar!.root);
+
+    const avatarElement = avatarContainer.querySelector('.ant-skeleton-avatar');
+    expect(avatarElement).toHaveStyle(elementStyle);
+    expect(avatarElement).toHaveClass(customClassNames.avatar!.content);
+
+    const { container: buttonContainer } = genSkeletonButton({
+      styles: customStyles.button,
+      classNames: customClassNames.button,
+    });
+
+    const buttonRootElement = buttonContainer.querySelector('.ant-skeleton');
+    expect(buttonRootElement).toHaveStyle(rootStyle);
+    expect(buttonRootElement).toHaveClass(customClassNames.button!.root);
+
+    const buttonElement = buttonContainer.querySelector('.ant-skeleton-button');
+    expect(buttonElement).toHaveStyle(elementStyle);
+    expect(buttonElement).toHaveClass(customClassNames.button!.content);
+
+    const { container: inputContainer } = genSkeletonInput({
+      styles: customStyles.input,
+      classNames: customClassNames.input,
+    });
+
+    const inputRootElement = inputContainer.querySelector('.ant-skeleton');
+    expect(inputRootElement).toHaveStyle(rootStyle);
+    expect(inputRootElement).toHaveClass(customClassNames.input!.root);
+
+    const inputElement = inputContainer.querySelector('.ant-skeleton-input');
+    expect(inputElement).toHaveStyle(elementStyle);
+    expect(inputElement).toHaveClass(customClassNames.input!.content);
+
+    const { container: nodeContainer } = genSkeletonNode({
+      styles: customStyles.node,
+      classNames: customClassNames.node,
+    });
+
+    const nodeRootElement = nodeContainer.querySelector('.ant-skeleton');
+    expect(nodeRootElement).toHaveStyle(rootStyle);
+    expect(nodeRootElement).toHaveClass(customClassNames.node!.root);
+
+    const nodeElement = nodeContainer.querySelector('.ant-skeleton-node');
+    expect(nodeElement).toHaveStyle(elementStyle);
+    expect(nodeElement).toHaveClass(customClassNames.node!.content);
+
+    const { container: imageContainer } = genSkeletonImage({
+      styles: customStyles.image,
+      classNames: customClassNames.image,
+    });
+
+    const imageRootElement = imageContainer.querySelector('.ant-skeleton');
+    expect(imageRootElement).toHaveStyle(rootStyle);
+    expect(imageRootElement).toHaveClass(customClassNames.image!.root);
+
+    const imageElement = imageContainer.querySelector('.ant-skeleton-image');
+    expect(imageElement).toHaveStyle(elementStyle);
+    expect(imageElement).toHaveClass(customClassNames.image!.content);
+  });
 });
diff --git a/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap b/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
--- a/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
+++ b/components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap
@@ -169,7 +169,7 @@ exports[`renders components/statistic/demo/basic.tsx extend context correctly 1`
         class="ant-skeleton ant-statistic-skeleton"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
@@ -440,7 +440,7 @@ exports[`renders components/statistic/demo/component-token.tsx extend context co
         class="ant-skeleton ant-statistic-skeleton"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
diff --git a/components/statistic/__tests__/__snapshots__/demo.test.ts.snap b/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
--- a/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
+++ b/components/statistic/__tests__/__snapshots__/demo.test.ts.snap
@@ -163,7 +163,7 @@ exports[`renders components/statistic/demo/basic.tsx correctly 1`] = `
         class="ant-skeleton ant-statistic-skeleton"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
@@ -430,7 +430,7 @@ exports[`renders components/statistic/demo/component-token.tsx correctly 1`] = `
         class="ant-skeleton ant-statistic-skeleton"
       >
         <div
-          class="ant-skeleton-content"
+          class="ant-skeleton-section"
         >
           <h3
             class="ant-skeleton-title"
EOF_114329324912

# Run the target tests using Jest
# Execute all target test files in a single command for efficiency
# Using --maxWorkers=1 to ensure single-process execution for stability
npx jest --config .jest.js --no-cache --maxWorkers=1 \
  "components/card/__tests__/demo-extend.test.ts" \
  "components/card/__tests__/demo.test.ts" \
  "components/card/__tests__/index.test.tsx" \
  "components/config-provider/__tests__/components.test.tsx" \
  "components/config-provider/__tests__/style.test.tsx" \
  "components/drawer/__tests__/Drawer.test.tsx" \
  "components/drawer/__tests__/demo-extend.test.tsx" \
  "components/list/__tests__/demo-extend.test.ts" \
  "components/list/__tests__/demo.test.ts" \
  "components/skeleton/__tests__/demo-extend.test.ts" \
  "components/skeleton/__tests__/demo.test.tsx" \
  "components/skeleton/__tests__/index.test.tsx" \
  "components/statistic/__tests__/demo-extend.test.ts" \
  "components/statistic/__tests__/demo.test.ts"

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 0c80d6c5fcea68a391777aead400b7785f5b13b8 \
  "components/card/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/card/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/card/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/config-provider/__tests__/__snapshots__/components.test.tsx.snap" \
  "components/config-provider/__tests__/style.test.tsx" \
  "components/drawer/__tests__/__snapshots__/Drawer.test.tsx.snap" \
  "components/drawer/__tests__/__snapshots__/demo-extend.test.tsx.snap" \
  "components/list/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/list/__tests__/__snapshots__/demo.test.ts.snap" \
  "components/skeleton/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/skeleton/__tests__/__snapshots__/demo.test.tsx.snap" \
  "components/skeleton/__tests__/__snapshots__/index.test.tsx.snap" \
  "components/skeleton/__tests__/index.test.tsx" \
  "components/statistic/__tests__/__snapshots__/demo-extend.test.ts.snap" \
  "components/statistic/__tests__/__snapshots__/demo.test.ts.snap"