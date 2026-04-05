#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 814e6b07ac387e89ee9a5ab3e5e7e64b396883f9 \
  "packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts" \
  "packages/compiler-cli/src/ngtsc/indexer/test/util.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts b/packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts
--- a/packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts
@@ -11,6 +11,7 @@ import {BoundTarget} from '@angular/compiler';
 import {
   AbsoluteSourceSpan,
   AttributeIdentifier,
+  DirectiveHostIdentifier,
   ElementIdentifier,
   IdentifierKind,
   LetDeclarationIdentifier,
@@ -25,10 +26,11 @@ import {getTemplateIdentifiers as getTemplateIdentifiersAndErrors} from '../src/
 
 import * as util from './util';
 
-function bind(template: string) {
+function bind(template: string, enableSelectorless = false) {
   return util.getBoundTemplate(template, {
     preserveWhitespaces: true,
     leadingTriviaChars: [],
+    enableSelectorless,
   });
 }
 
@@ -1002,4 +1004,195 @@ runInEachFileSystem(() => {
       ]);
     });
   });
+
+  describe('selectorless', () => {
+    it('should generate information about selectorless component nodes', () => {
+      const compDecl = util.getComponentDeclaration('class Comp {}', 'Comp');
+      const fooDecl = util.getComponentDeclaration('class Foo {}', 'Foo');
+      const barDecl = util.getComponentDeclaration('class Bar {}', 'Bar');
+      const template = '<Comp @Foo @Bar([input]="value")/>';
+      const boundTemplate = util.getBoundTemplate(
+        template,
+        {
+          enableSelectorless: true,
+        },
+        [
+          {selector: null, declaration: compDecl},
+          {selector: null, declaration: fooDecl},
+          {selector: null, declaration: barDecl},
+        ],
+      );
+
+      const refs = getTemplateIdentifiers(boundTemplate);
+      expect(Array.from(refs)).toEqual([
+        {
+          name: 'Comp',
+          span: new AbsoluteSourceSpan(1, 5),
+          kind: IdentifierKind.Component,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: compDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'Foo',
+          span: new AbsoluteSourceSpan(7, 10),
+          kind: IdentifierKind.Directive,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: fooDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'Bar',
+          span: new AbsoluteSourceSpan(12, 15),
+          kind: IdentifierKind.Directive,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: barDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'value',
+          span: new AbsoluteSourceSpan(25, 30),
+          kind: IdentifierKind.Property,
+          target: null,
+        },
+      ]);
+    });
+
+    it('should generate information about selectorless directives used on a plain element', () => {
+      const fooDecl = util.getComponentDeclaration('class Foo {}', 'Foo');
+      const barDecl = util.getComponentDeclaration('class Bar {}', 'Bar');
+      const template = '<div @Foo @Bar([input]="value")></div>';
+      const boundTemplate = util.getBoundTemplate(
+        template,
+        {
+          enableSelectorless: true,
+        },
+        [
+          {selector: null, declaration: fooDecl},
+          {selector: null, declaration: barDecl},
+        ],
+      );
+
+      const refs = getTemplateIdentifiers(boundTemplate);
+      expect(Array.from(refs)).toEqual([
+        {
+          name: 'div',
+          span: new AbsoluteSourceSpan(1, 4),
+          kind: IdentifierKind.Element,
+          attributes: new Set(),
+          usedDirectives: new Set(),
+        },
+        {
+          name: 'Foo',
+          span: new AbsoluteSourceSpan(6, 9),
+          kind: IdentifierKind.Directive,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: fooDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'Bar',
+          span: new AbsoluteSourceSpan(11, 14),
+          kind: IdentifierKind.Directive,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: barDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'value',
+          span: new AbsoluteSourceSpan(24, 29),
+          kind: IdentifierKind.Property,
+          target: null,
+        },
+      ]);
+    });
+
+    it('should discover references to selectorless components and directives', () => {
+      const compDecl = util.getComponentDeclaration('class Comp {}', 'Comp');
+      const fooDecl = util.getComponentDeclaration('class Foo {}', 'Foo');
+      const template = '<Comp #comp @Foo(#foo)/>';
+      const boundTemplate = util.getBoundTemplate(
+        template,
+        {
+          enableSelectorless: true,
+        },
+        [
+          {selector: null, declaration: compDecl},
+          {selector: null, declaration: fooDecl},
+        ],
+      );
+
+      const refs = Array.from(getTemplateIdentifiers(boundTemplate));
+      const [compRef, fooRef] = refs as [
+        DirectiveHostIdentifier,
+        DirectiveHostIdentifier,
+        ...unknown[],
+      ];
+
+      expect(refs).toEqual([
+        {
+          name: 'Comp',
+          span: new AbsoluteSourceSpan(1, 5),
+          kind: IdentifierKind.Component,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: compDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'Foo',
+          span: new AbsoluteSourceSpan(13, 16),
+          kind: IdentifierKind.Directive,
+          attributes: new Set(),
+          usedDirectives: new Set([
+            {
+              node: fooDecl,
+              selector: null,
+            },
+          ]),
+        },
+        {
+          name: 'foo',
+          span: new AbsoluteSourceSpan(18, 21),
+          kind: IdentifierKind.Reference,
+          target: {
+            node: fooRef,
+            directive: fooDecl,
+          },
+        },
+        {
+          name: 'comp',
+          span: new AbsoluteSourceSpan(7, 11),
+          kind: IdentifierKind.Reference,
+          target: {
+            node: compRef,
+            directive: compDecl,
+          },
+        },
+      ]);
+    });
+  });
 });
diff --git a/packages/compiler-cli/src/ngtsc/indexer/test/util.ts b/packages/compiler-cli/src/ngtsc/indexer/test/util.ts
--- a/packages/compiler-cli/src/ngtsc/indexer/test/util.ts
+++ b/packages/compiler-cli/src/ngtsc/indexer/test/util.ts
@@ -9,9 +9,11 @@
 import {
   BoundTarget,
   CssSelector,
+  DirectiveMatcher,
   parseTemplate,
   ParseTemplateOptions,
   R3TargetBinder,
+  SelectorlessMatcher,
   SelectorMatcher,
 } from '@angular/compiler';
 import ts from 'typescript';
@@ -53,26 +55,42 @@ export function getComponentDeclaration(componentStr: string, className: string)
 export function getBoundTemplate(
   template: string,
   options: ParseTemplateOptions = {},
-  components: Array<{selector: string; declaration: ClassDeclaration}> = [],
+  components: Array<{selector: string | null; declaration: ClassDeclaration}> = [],
 ): BoundTarget<ComponentMeta> {
-  const matcher = new SelectorMatcher<ComponentMeta[]>();
-  components.forEach(({selector, declaration}) => {
-    matcher.addSelectables(CssSelector.parse(selector), [
-      {
-        ref: new Reference(declaration),
-        selector,
-        name: declaration.name.getText(),
-        isComponent: true,
-        inputs: ClassPropertyMapping.fromMappedObject({}),
-        outputs: ClassPropertyMapping.fromMappedObject({}),
-        exportAs: null,
-        isStructural: false,
-        animationTriggerNames: null,
-        ngContentSelectors: null,
-        preserveWhitespaces: false,
-      },
-    ]);
-  });
+  const componentsMeta = components.map(({selector, declaration}) => ({
+    ref: new Reference(declaration),
+    selector,
+    name: declaration.name.getText(),
+    isComponent: true,
+    inputs: ClassPropertyMapping.fromMappedObject({}),
+    outputs: ClassPropertyMapping.fromMappedObject({}),
+    exportAs: null,
+    isStructural: false,
+    animationTriggerNames: null,
+    ngContentSelectors: null,
+    preserveWhitespaces: false,
+  }));
+
+  let matcher: DirectiveMatcher<ComponentMeta>;
+
+  if (options.enableSelectorless) {
+    const registry = new Map<string, ComponentMeta[]>();
+
+    for (const current of componentsMeta) {
+      registry.set(current.name, [current]);
+    }
+
+    matcher = new SelectorlessMatcher(registry);
+  } else {
+    matcher = new SelectorMatcher();
+
+    for (const current of componentsMeta) {
+      if (current.selector !== null) {
+        matcher.addSelectables(CssSelector.parse(current.selector), [current]);
+      }
+    }
+  }
+
   const binder = new R3TargetBinder(matcher);
 
   return binder.bind({template: parseTemplate(template, getTestFilePath(), options).nodes});
EOF_114329324912

# Run the target tests using Bazel
# The test target encompasses both template_spec.ts and util.ts
# Using --test_output=errors for cleaner output (only shows failures)
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/compiler-cli/src/ngtsc/indexer/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the tests
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 814e6b07ac387e89ee9a5ab3e5e7e64b396883f9 \
  "packages/compiler-cli/src/ngtsc/indexer/test/template_spec.ts" \
  "packages/compiler-cli/src/ngtsc/indexer/test/util.ts"

exit $rc