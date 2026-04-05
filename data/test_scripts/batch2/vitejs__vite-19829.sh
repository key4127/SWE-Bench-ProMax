#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout bf8b07da3e64dc4de446a9b24a33d5822a7736b9 \
    "packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts b/packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts
--- a/packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts
+++ b/packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts
@@ -16,7 +16,10 @@ test('default import', async () => {
   expect(
     await ssrTransformSimpleCode(`import foo from 'vue';console.log(foo.bar)`),
   ).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["default"]});console.log(__vite_ssr_import_0__.default.bar)"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["default"]});
+    console.log(__vite_ssr_import_0__.default.bar)"
+  `,
   )
 })
 
@@ -26,7 +29,10 @@ test('named import', async () => {
       `import { ref } from 'vue';function foo() { return ref(0) }`,
     ),
   ).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["ref"]});function foo() { return (0,__vite_ssr_import_0__.ref)(0) }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["ref"]});
+    function foo() { return (0,__vite_ssr_import_0__.ref)(0) }"
+  `,
   )
 })
 
@@ -36,7 +42,10 @@ test('named import: arbitrary module namespace specifier', async () => {
       `import { "some thing" as ref } from 'vue';function foo() { return ref(0) }`,
     ),
   ).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["some thing"]});function foo() { return (0,__vite_ssr_import_0__["some thing"])(0) }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["some thing"]});
+    function foo() { return (0,__vite_ssr_import_0__["some thing"])(0) }"
+  `,
   )
 })
 
@@ -46,7 +55,10 @@ test('namespace import', async () => {
       `import * as vue from 'vue';function foo() { return vue.ref(0) }`,
     ),
   ).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");function foo() { return __vite_ssr_import_0__.ref(0) }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");
+    function foo() { return __vite_ssr_import_0__.ref(0) }"
+  `,
   )
 })
 
@@ -103,7 +115,8 @@ test('export named from', async () => {
     `
     "Object.defineProperty(__vite_ssr_exports__, "ref", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__.ref } catch {} }});
     Object.defineProperty(__vite_ssr_exports__, "c", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__.computed } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["ref","computed"]});"
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["ref","computed"]});
+    "
   `,
   )
 })
@@ -116,7 +129,8 @@ test('named exports of imported binding', async () => {
   ).toMatchInlineSnapshot(
     `
     "Object.defineProperty(__vite_ssr_exports__, "createApp", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__.createApp } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["createApp"]});"
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["createApp"]});
+    "
   `,
   )
 })
@@ -127,9 +141,11 @@ test('export * from', async () => {
       `export * from 'vue'\n` + `export * from 'react'`,
     ),
   ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");__vite_ssr_exportAll__(__vite_ssr_import_0__);
-    ;
-    const __vite_ssr_import_1__ = await __vite_ssr_import__("react");__vite_ssr_exportAll__(__vite_ssr_import_1__);
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");
+    __vite_ssr_exportAll__(__vite_ssr_import_0__);
+    ;const __vite_ssr_import_1__ = await __vite_ssr_import__("react");
+    __vite_ssr_exportAll__(__vite_ssr_import_1__);
+
     "
   `)
 })
@@ -140,7 +156,8 @@ test('export * as from', async () => {
   ).toMatchInlineSnapshot(
     `
     "Object.defineProperty(__vite_ssr_exports__, "foo", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__ } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");"
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");
+    "
   `,
   )
 })
@@ -155,6 +172,8 @@ export * as foo from 'foo'
     "Object.defineProperty(__vite_ssr_exports__, "foo", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_1__ } catch {} }});
     const __vite_ssr_import_0__ = await __vite_ssr_import__("foo");
     const __vite_ssr_import_1__ = await __vite_ssr_import__("foo");
+
+
     "
   `)
 
@@ -167,6 +186,8 @@ export { foo } from 'foo'
     "Object.defineProperty(__vite_ssr_exports__, "foo", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_1__.foo } catch {} }});
     const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["foo"]});
     const __vite_ssr_import_1__ = await __vite_ssr_import__("foo", {"importedNames":["foo"]});
+
+
     "
   `)
 
@@ -179,6 +200,8 @@ export { foo as foo } from 'foo'
     "Object.defineProperty(__vite_ssr_exports__, "foo", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_1__.foo } catch {} }});
     const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["foo"]});
     const __vite_ssr_import_1__ = await __vite_ssr_import__("foo", {"importedNames":["foo"]});
+
+
     "
   `)
 })
@@ -189,7 +212,8 @@ test('export * as from arbitrary module namespace identifier', async () => {
   ).toMatchInlineSnapshot(
     `
     "Object.defineProperty(__vite_ssr_exports__, "arbitrary string", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__ } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");"
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");
+    "
   `,
   )
 })
@@ -215,7 +239,8 @@ test('export as from arbitrary module namespace identifier', async () => {
   ).toMatchInlineSnapshot(
     `
     "Object.defineProperty(__vite_ssr_exports__, "arbitrary string", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_0__["arbitrary string2"] } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["arbitrary string2"]});"
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["arbitrary string2"]});
+    "
   `,
   )
 })
@@ -234,8 +259,10 @@ test('export then import minified', async () => {
       `export * from 'vue';import {createApp} from 'vue';`,
     ),
   ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");__vite_ssr_exportAll__(__vite_ssr_import_0__);
-    const __vite_ssr_import_1__ = await __vite_ssr_import__("vue", {"importedNames":["createApp"]});"
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue");
+    __vite_ssr_exportAll__(__vite_ssr_import_0__);
+    const __vite_ssr_import_1__ = await __vite_ssr_import__("vue", {"importedNames":["createApp"]});
+    "
   `)
 })
 
@@ -245,7 +272,10 @@ test('hoist import to top', async () => {
       `path.resolve('server.js');import path from 'node:path';`,
     ),
   ).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("node:path", {"importedNames":["default"]});__vite_ssr_import_0__.default.resolve('server.js');"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("node:path", {"importedNames":["default"]});
+    __vite_ssr_import_0__.default.resolve('server.js');"
+  `,
   )
 })
 
@@ -256,82 +286,11 @@ test('whitespace between imports does not trigger hoisting', async () => {
     ),
   ).toMatchInlineSnapshot(`
     "const __vite_ssr_import_0__ = await __vite_ssr_import__("node:path", {"importedNames":["dirname"]});
+    const __vite_ssr_import_1__ = await __vite_ssr_import__("node:fs", {"importedNames":["default"]});
 
 
-    const __vite_ssr_import_1__ = await __vite_ssr_import__("node:fs", {"importedNames":["default"]});"
-  `)
-})
-
-test('preserve line offset when rewriting imports', async () => {
-  // The line number of each non-import statement must not change.
-  const inputLines = [
-    `debugger;`,
-    ``,
-    `import {`,
-    `  dirname,`,
-    `  join,`,
-    `} from 'node:path';`,
-    ``,
-    `debugger;`,
-    ``,
-    `import fs from 'node:fs';`,
-    ``,
-    `debugger;`,
-    ``,
-    `import {`,
-    `  red,`,
-    `  green,`,
-    `} from 'kleur/colors';`,
-    ``,
-    `debugger;`,
-  ]
-
-  const output = await ssrTransformSimpleCode(inputLines.join('\n'))
-  expect(output).toBeDefined()
-
-  const outputLines = output!.split('\n')
-  expect(
-    outputLines
-      .map((line, i) => `${String(i + 1).padStart(2)} | ${line}`.trimEnd())
-      .join('\n'),
-  ).toMatchInlineSnapshot(`
-    " 1 | const __vite_ssr_import_0__ = await __vite_ssr_import__("node:path", {"importedNames":["dirname","join"]});const __vite_ssr_import_1__ = await __vite_ssr_import__("node:fs", {"importedNames":["default"]});const __vite_ssr_import_2__ = await __vite_ssr_import__("kleur/colors", {"importedNames":["red","green"]});debugger;
-     2 |
-     3 |
-     4 |
-     5 |
-     6 |
-     7 |
-     8 | debugger;
-     9 |
-    10 |
-    11 |
-    12 | debugger;
-    13 |
-    14 |
-    15 |
-    16 |
-    17 |
-    18 |
-    19 | debugger;"
-  `)
-
-  // Ensure the debugger statements are still on the same lines.
-  expect(outputLines[0].endsWith(inputLines[0])).toBe(true)
-  expect(outputLines[7]).toBe(inputLines[7])
-  expect(outputLines[11]).toBe(inputLines[11])
-  expect(outputLines[18]).toBe(inputLines[18])
-})
 
-// not implemented
-test.skip('comments between imports do not trigger hoisting', async () => {
-  expect(
-    await ssrTransformSimpleCode(
-      `import { dirname } from 'node:path';// comment\nimport fs from 'node:fs';`,
-    ),
-  ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("node:path", {"importedNames":["dirname"]});// comment
-    const __vite_ssr_import_1__ = await __vite_ssr_import__("node:fs", {"importedNames":["default"]});"
+    "
   `)
 })
 
@@ -360,7 +319,10 @@ test('do not rewrite method definition', async () => {
     `import { fn } from 'vue';class A { fn() { fn() } }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});class A { fn() { (0,__vite_ssr_import_0__.fn)() } }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    class A { fn() { (0,__vite_ssr_import_0__.fn)() } }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -370,7 +332,10 @@ test('do not rewrite when variable is in scope', async () => {
     `import { fn } from 'vue';function A(){ const fn = () => {}; return { fn }; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A(){ const fn = () => {}; return { fn }; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A(){ const fn = () => {}; return { fn }; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -381,7 +346,10 @@ test('do not rewrite when variable is in scope with object destructuring', async
     `import { fn } from 'vue';function A(){ let {fn, test} = {fn: 'foo', test: 'bar'}; return { fn }; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A(){ let {fn, test} = {fn: 'foo', test: 'bar'}; return { fn }; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A(){ let {fn, test} = {fn: 'foo', test: 'bar'}; return { fn }; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -392,7 +360,10 @@ test('do not rewrite when variable is in scope with array destructuring', async
     `import { fn } from 'vue';function A(){ let [fn, test] = ['foo', 'bar']; return { fn }; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A(){ let [fn, test] = ['foo', 'bar']; return { fn }; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A(){ let [fn, test] = ['foo', 'bar']; return { fn }; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -403,7 +374,10 @@ test('rewrite variable in string interpolation in function nested arguments', as
     `import { fn } from 'vue';function A({foo = \`test\${fn}\`} = {}){ return {}; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A({foo = \`test\${__vite_ssr_import_0__.fn}\`} = {}){ return {}; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A({foo = \`test\${__vite_ssr_import_0__.fn}\`} = {}){ return {}; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -414,7 +388,10 @@ test('rewrite variables in default value of destructuring params', async () => {
     `import { fn } from 'vue';function A({foo = fn}){ return {}; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A({foo = __vite_ssr_import_0__.fn}){ return {}; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A({foo = __vite_ssr_import_0__.fn}){ return {}; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -424,7 +401,10 @@ test('do not rewrite when function declaration is in scope', async () => {
     `import { fn } from 'vue';function A(){ function fn() {}; return { fn }; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});function A(){ function fn() {}; return { fn }; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["fn"]});
+    function A(){ function fn() {}; return { fn }; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -435,7 +415,10 @@ test('do not rewrite when function expression is in scope', async () => {
     `import {fn} from './vue';var a = function() { return function fn() { console.log(fn) } }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["fn"]});var a = function() { return function fn() { console.log(fn) } }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["fn"]});
+    var a = function() { return function fn() { console.log(fn) } }"
+  `,
   )
 })
 
@@ -445,7 +428,10 @@ test('do not rewrite when function expression is in global scope', async () => {
     `import {fn} from './vue';foo(function fn(a = fn) { console.log(fn) })`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["fn"]});foo(function fn(a = fn) { console.log(fn) })"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["fn"]});
+    foo(function fn(a = fn) { console.log(fn) })"
+  `,
   )
 })
 
@@ -454,7 +440,10 @@ test('do not rewrite when class declaration is in scope', async () => {
     `import { cls } from 'vue';function A(){ class cls {} return { cls }; }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["cls"]});function A(){ class cls {} return { cls }; }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["cls"]});
+    function A(){ class cls {} return { cls }; }"
+  `,
   )
   expect(result?.deps).toEqual(['vue'])
 })
@@ -464,7 +453,10 @@ test('do not rewrite when class expression is in scope', async () => {
     `import { cls } from './vue';var a = function() { return class cls { constructor() { console.log(cls) } } }`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["cls"]});var a = function() { return class cls { constructor() { console.log(cls) } } }"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["cls"]});
+    var a = function() { return class cls { constructor() { console.log(cls) } } }"
+  `,
   )
 })
 
@@ -473,7 +465,10 @@ test('do not rewrite when class expression is in global scope', async () => {
     `import { cls } from './vue';foo(class cls { constructor() { console.log(cls) } })`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["cls"]});foo(class cls { constructor() { console.log(cls) } })"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./vue", {"importedNames":["cls"]});
+    foo(class cls { constructor() { console.log(cls) } })"
+  `,
   )
 })
 
@@ -482,7 +477,10 @@ test('do not rewrite catch clause', async () => {
     `import {error} from './dependency';try {} catch(error) {}`,
   )
   expect(result?.code).toMatchInlineSnapshot(
-    `"const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["error"]});try {} catch(error) {}"`,
+    `
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["error"]});
+    try {} catch(error) {}"
+  `,
   )
   expect(result?.deps).toEqual(['./dependency'])
 })
@@ -494,7 +492,8 @@ test('should declare variable for imported super class', async () => {
       `import { Foo } from './dependency';` + `class A extends Foo {}`,
     ),
   ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["Foo"]});const Foo = __vite_ssr_import_0__.Foo;
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["Foo"]});
+    const Foo = __vite_ssr_import_0__.Foo;
     class A extends Foo {}"
   `)
 
@@ -509,7 +508,8 @@ test('should declare variable for imported super class', async () => {
   ).toMatchInlineSnapshot(`
     "Object.defineProperty(__vite_ssr_exports__, "default", { enumerable: true, configurable: true, get(){ try { return A } catch {} }});
     Object.defineProperty(__vite_ssr_exports__, "B", { enumerable: true, configurable: true, get(){ try { return B } catch {} }});
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["Foo"]});const Foo = __vite_ssr_import_0__.Foo;
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("./dependency", {"importedNames":["Foo"]});
+    const Foo = __vite_ssr_import_0__.Foo;
     class A extends Foo {};
     class B extends Foo {}"
   `)
@@ -574,7 +574,9 @@ test('sourcemap is correct for hoisted imports', async () => {
   const result = (await ssrTransform(code, null, 'input.js', code))!
 
   expect(result.code).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["foo"]});const __vite_ssr_import_1__ = await __vite_ssr_import__("vue2", {"importedNames":["bar"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["foo"]});
+    const __vite_ssr_import_1__ = await __vite_ssr_import__("vue2", {"importedNames":["bar"]});
+
 
 
     console.log((0,__vite_ssr_import_0__.foo), (0,__vite_ssr_import_1__.bar));
@@ -589,7 +591,7 @@ test('sourcemap is correct for hoisted imports', async () => {
     column: 0,
     name: null,
   })
-  expect(originalPositionFor(traceMap, { line: 1, column: 90 })).toStrictEqual({
+  expect(originalPositionFor(traceMap, { line: 2, column: 0 })).toStrictEqual({
     source: 'input.js',
     line: 6,
     column: 0,
@@ -656,7 +658,8 @@ test('overwrite bindings', async () => {
         `function g() { const f = () => { const inject = true }; console.log(inject) }\n`,
     ),
   ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["inject"]});const a = { inject: __vite_ssr_import_0__.inject };
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["inject"]});
+    const a = { inject: __vite_ssr_import_0__.inject };
     const b = { test: __vite_ssr_import_0__.inject };
     function c() { const { test: inject } = { test: true }; console.log(inject) }
     const d = __vite_ssr_import_0__.inject;
@@ -684,8 +687,9 @@ function c({ _ = bar() + foo() }) {}
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["foo","bar"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["foo","bar"]});
+
+
     const a = ({ _ = (0,__vite_ssr_import_0__.foo)() }) => {};
     function b({ _ = (0,__vite_ssr_import_0__.bar)() }) {}
     function c({ _ = (0,__vite_ssr_import_0__.bar)() + (0,__vite_ssr_import_0__.foo)() }) {}
@@ -705,8 +709,9 @@ const a = () => {
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["n"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["n"]});
+
+
     const a = () => {
       const { type: n = 'bar' } = {};
       console.log(n)
@@ -727,8 +732,9 @@ const foo = {}
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["n","m"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["n","m"]});
+
+
     const foo = {};
 
     {
@@ -769,8 +775,9 @@ objRest()
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["remove","add","get","set","rest","objRest"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["remove","add","get","set","rest","objRest"]});
+
+
 
     function a() {
       const {
@@ -818,8 +825,9 @@ const obj = {
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});
+
+
 
     const bar = 'bar';
 
@@ -849,8 +857,9 @@ class A {
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["remove","add"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["remove","add"]});
+
+
 
     const add = __vite_ssr_import_0__.add;
     const remove = __vite_ssr_import_0__.remove;
@@ -880,8 +889,9 @@ class A {
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});
+
+
 
     const bar = 'bar';
 
@@ -925,8 +935,9 @@ bbb()
 `,
     ),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["aaa","bbb","ccc","ddd"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("vue", {"importedNames":["aaa","bbb","ccc","ddd"]});
+
+
 
     function foobar() {
       ddd();
@@ -971,6 +982,8 @@ test('jsx', async () => {
     .toMatchInlineSnapshot(`
       "const __vite_ssr_import_0__ = await __vite_ssr_import__("react", {"importedNames":["default"]});
       const __vite_ssr_import_1__ = await __vite_ssr_import__("foo", {"importedNames":["Foo","Slot"]});
+
+
       function Bar({ Slot: Slot2 = /* @__PURE__ */ __vite_ssr_import_0__.default.createElement((0,__vite_ssr_import_1__.Foo), null) }) {
         return /* @__PURE__ */ __vite_ssr_import_0__.default.createElement(__vite_ssr_import_0__.default.Fragment, null, /* @__PURE__ */ __vite_ssr_import_0__.default.createElement(Slot2, null));
       }
@@ -1046,7 +1059,8 @@ import foo from "foo"`,
     ),
   ).toMatchInlineSnapshot(`
     "#!/usr/bin/env node
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});console.log((0,__vite_ssr_import_0__.default));
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["default"]});
+    console.log((0,__vite_ssr_import_0__.default));
     "
   `)
 })
@@ -1061,6 +1075,7 @@ foo()`,
   ).toMatchInlineSnapshot(`
     "#!/usr/bin/env node
     const __vite_ssr_import_0__ = await __vite_ssr_import__("foo", {"importedNames":["foo"]});
+
     (0,__vite_ssr_import_0__.foo)()"
   `)
 })
@@ -1097,6 +1112,7 @@ export class Test {
   expect(await ssrTransformSimpleCode(code)).toMatchInlineSnapshot(`
     "Object.defineProperty(__vite_ssr_exports__, "Test", { enumerable: true, configurable: true, get(){ try { return Test } catch {} }});
     const __vite_ssr_import_0__ = await __vite_ssr_import__("foobar", {"importedNames":["foo","bar"]});
+
     if (false) {
       const foo = 'foo';
       console.log(foo)
@@ -1136,8 +1152,9 @@ function test() {
   return [foo, bar]
 }`),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foobar", {"importedNames":["foo","bar"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foobar", {"importedNames":["foo","bar"]});
+
+
     function test() {
       if (true) {
         var foo = () => { var why = 'would' }, bar = 'someone'
@@ -1162,8 +1179,9 @@ function test() {
   return bar;
 }`),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("foobar", {"importedNames":["foo","bar","baz"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("foobar", {"importedNames":["foo","bar","baz"]});
+
+
     function test() {
       [__vite_ssr_import_0__.foo];
       {
@@ -1193,8 +1211,9 @@ for (const test in tests) {
   console.log(test)
 }`),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("./test.js", {"importedNames":["test"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./test.js", {"importedNames":["test"]});
+
+
 
     for (const test of tests) {
       console.log(test)
@@ -1224,8 +1243,9 @@ const Baz = class extends Foo {}
 `,
   )
   expect(result?.code).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo", {"importedNames":["default","Bar"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo", {"importedNames":["default","Bar"]});
+
+
 
     console.log((0,__vite_ssr_import_0__.default), (0,__vite_ssr_import_0__.Bar));
     const obj = {
@@ -1240,14 +1260,15 @@ const Baz = class extends Foo {}
 test('import assertion attribute', async () => {
   expect(
     await ssrTransformSimpleCode(`
-  import * as foo from './foo.json' with { type: 'json' };
-  import('./bar.json', { with: { type: 'json' } });
-  `),
+import * as foo from './foo.json' with { type: 'json' };
+import('./bar.json', { with: { type: 'json' } });
+`),
   ).toMatchInlineSnapshot(`
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo.json");
+
+
+    __vite_ssr_dynamic_import__('./bar.json', { with: { type: 'json' } });
     "
-      const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo.json");
-      __vite_ssr_dynamic_import__('./bar.json', { with: { type: 'json' } });
-      "
   `)
 })
 
@@ -1264,8 +1285,11 @@ export * from './b'
 console.log(foo + 2)
   `),
   ).toMatchInlineSnapshot(`
-    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./a");__vite_ssr_exportAll__(__vite_ssr_import_0__);
-    ;const __vite_ssr_import_1__ = await __vite_ssr_import__("./foo", {"importedNames":["foo"]});const __vite_ssr_import_2__ = await __vite_ssr_import__("./b");__vite_ssr_exportAll__(__vite_ssr_import_2__);
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./a");
+    __vite_ssr_exportAll__(__vite_ssr_import_0__);
+    ;const __vite_ssr_import_1__ = await __vite_ssr_import__("./foo", {"importedNames":["foo"]});
+    const __vite_ssr_import_2__ = await __vite_ssr_import__("./b");
+    __vite_ssr_exportAll__(__vite_ssr_import_2__);
     ;
     console.log(__vite_ssr_import_1__.foo + 1);
 
@@ -1287,15 +1311,32 @@ console.log(bar)
   ).toMatchInlineSnapshot(`
     "Object.defineProperty(__vite_ssr_exports__, "default", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_export_default__ } catch {} }});
     Object.defineProperty(__vite_ssr_exports__, "bar", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_1__ } catch {} }});
+    const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo", {"importedNames":["foo"]});
+    const __vite_ssr_import_1__ = await __vite_ssr_import__("./bar");
+    ;
 
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("./foo", {"importedNames":["foo"]});const __vite_ssr_import_1__ = await __vite_ssr_import__("./bar");;
     const __vite_ssr_export_default__ = (0,__vite_ssr_import_0__.foo)();
 
     console.log(bar)
       "
   `)
 })
 
+test('repro', async () => {
+  expect(
+    await ssrTransformSimpleCode(`\
+import 'x'
+import 'y'
+  `),
+  ).toMatchInlineSnapshot(`
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("x");
+    const __vite_ssr_import_1__ = await __vite_ssr_import__("y");
+
+
+      "
+  `)
+})
+
 test('inject semicolon for (0, ...) wrapper', async () => {
   expect(
     await ssrTransformSimpleCode(`
@@ -1368,8 +1409,9 @@ switch(1){}f()
 {}f(1)
 `),
   ).toMatchInlineSnapshot(`
-    "
-    const __vite_ssr_import_0__ = await __vite_ssr_import__("./f", {"importedNames":["f"]});
+    "const __vite_ssr_import_0__ = await __vite_ssr_import__("./f", {"importedNames":["f"]});
+
+
 
     let x = 0;
 
@@ -1452,6 +1494,7 @@ const c = () => {
   ).toMatchInlineSnapshot(
     `
     "const __vite_ssr_import_0__ = await __vite_ssr_import__("a", {"importedNames":["default"]});
+
     const c = () => {
       if(true){return};(0,__vite_ssr_import_0__.default)(1,{})
     }"
@@ -1547,9 +1590,14 @@ export * as A from "a";
     Object.defineProperty(__vite_ssr_exports__, "A", { enumerable: true, configurable: true, get(){ try { return __vite_ssr_import_4__ } catch {} }});
     const __vite_ssr_import_0__ = await __vite_ssr_import__("a", {"importedNames":["default"]});
     const __vite_ssr_import_1__ = await __vite_ssr_import__("b", {"importedNames":["b"]});
-    const __vite_ssr_import_2__ = await __vite_ssr_import__("c");__vite_ssr_exportAll__(__vite_ssr_import_2__);
+    const __vite_ssr_import_2__ = await __vite_ssr_import__("c");
+    __vite_ssr_exportAll__(__vite_ssr_import_2__);
+    const __vite_ssr_import_3__ = await __vite_ssr_import__("d");
+    const __vite_ssr_import_4__ = await __vite_ssr_import__("a");
+
+
+
 
-    const __vite_ssr_import_3__ = await __vite_ssr_import__("d");const __vite_ssr_import_4__ = await __vite_ssr_import__("a");
     __vite_ssr_dynamic_import__("e");
 
     "
EOF_114329324912

# Execute the target test file using pnpm test-unit
# Running the specific test file as identified in the requirements
pnpm run test-unit packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts

# Capture exit code
rc=$?

# Echo exit code for test result evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout bf8b07da3e64dc4de446a9b24a33d5822a7736b9 \
    "packages/vite/src/node/ssr/__tests__/ssrTransform.spec.ts"