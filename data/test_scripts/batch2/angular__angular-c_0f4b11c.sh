#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 3ae452e64f81b92f89b89132389ced3848b30aae \
  "packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel" \
  "packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/ngtsc/debug_transform_spec.ts" \
  "packages/compiler-cli/test/ngtsc/env.ts" \
  "packages/compiler-cli/test/ngtsc/ngtsc_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel b/packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel
--- a/packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel
+++ b/packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel
@@ -19,5 +19,6 @@ ng_package(
     package = "@angular/common",
     deps = [
         ":fake_common",
+        "//packages/compiler-cli/src/ngtsc/testing/fake_common/http:fake_http",
     ],
 )
diff --git a/packages/compiler-cli/src/ngtsc/testing/fake_common/http/BUILD.bazel b/packages/compiler-cli/src/ngtsc/testing/fake_common/http/BUILD.bazel
new file mode 100644
--- /dev/null
+++ b/packages/compiler-cli/src/ngtsc/testing/fake_common/http/BUILD.bazel
@@ -0,0 +1,8 @@
+load("//tools:defaults.bzl", "ts_project")
+
+package(default_visibility = ["//visibility:public"])
+
+ts_project(
+    name = "fake_http",
+    srcs = ["index.ts"],
+)
diff --git a/packages/compiler-cli/src/ngtsc/testing/fake_common/http/index.ts b/packages/compiler-cli/src/ngtsc/testing/fake_common/http/index.ts
new file mode 100644
--- /dev/null
+++ b/packages/compiler-cli/src/ngtsc/testing/fake_common/http/index.ts
@@ -0,0 +1,13 @@
+/**
+ * @license
+ * Copyright Google LLC All Rights Reserved.
+ *
+ * Use of this source code is governed by an MIT-style license that can be
+ * found in the LICENSE file at https://angular.dev/license
+ */
+
+// Fake Http package with partial API coverage. Modify as needed.
+
+export type HttpResourceRef<T> = any;
+
+export declare function httpResource(...args: any): HttpResourceRef<any>;
diff --git a/packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js
@@ -5,8 +5,8 @@ import { Directive, model } from '@angular/core';
 import * as i0 from "@angular/core";
 export class TestDir {
     constructor() {
-        this.counter = model(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.name = model.required(...(ngDevMode ? [{ debugName: "name" }] : []));
+        this.counter = model(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.name = model.required(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
@@ -34,8 +34,8 @@ import { Component, model } from '@angular/core';
 import * as i0 from "@angular/core";
 export class TestComp {
     constructor() {
-        this.counter = model(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.name = model.required(...(ngDevMode ? [{ debugName: "name" }] : []));
+        this.counter = model(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.name = model.required(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})));
     }
 }
 TestComp.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestComp, deps: [], target: i0.ɵɵFactoryTarget.Component });
@@ -65,8 +65,8 @@ import { Directive, EventEmitter, Input, model, Output } from '@angular/core';
 import * as i0 from "@angular/core";
 export class TestDir {
     constructor() {
-        this.counter = model(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.modelWithAlias = model(false, ...(ngDevMode ? [{ debugName: "modelWithAlias", alias: 'alias' }] : [{ alias: 'alias' }]));
+        this.counter = model(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.modelWithAlias = model(false, Object.assign(Object.assign({}, (ngDevMode ? { debugName: "modelWithAlias" } : {})), { alias: 'alias' }));
         this.decoratorInput = true;
         this.decoratorInputWithAlias = true;
         this.decoratorOutput = new EventEmitter();
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js
@@ -188,7 +188,7 @@ import { Component, signal } from '@angular/core';
 import * as i0 from "@angular/core";
 export class MyComponent {
     constructor() {
-        this.enterClass = signal('slide', ...(ngDevMode ? [{ debugName: "enterClass" }] : []));
+        this.enterClass = signal('slide', Object.assign({}, (ngDevMode ? { debugName: "enterClass" } : {})));
     }
 }
 MyComponent.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: MyComponent, deps: [], target: i0.ɵɵFactoryTarget.Component });
@@ -299,7 +299,7 @@ import { Component, signal } from '@angular/core';
 import * as i0 from "@angular/core";
 export class MyComponent {
     constructor() {
-        this.leaveClass = signal('fade', ...(ngDevMode ? [{ debugName: "leaveClass" }] : []));
+        this.leaveClass = signal('fade', Object.assign({}, (ngDevMode ? { debugName: "leaveClass" } : {})));
     }
 }
 MyComponent.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: MyComponent, deps: [], target: i0.ɵɵFactoryTarget.Component });
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js
@@ -5,7 +5,7 @@ import { Component, Directive, input } from '@angular/core';
 import * as i0 from "@angular/core";
 export class Field {
     constructor() {
-        this.field = input(...(ngDevMode ? [undefined, { debugName: "field" }] : []));
+        this.field = input(undefined, Object.assign({}, (ngDevMode ? { debugName: "field" } : {})));
     }
 }
 Field.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: Field, deps: [], target: i0.ɵɵFactoryTarget.Directive });
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js
@@ -967,7 +967,7 @@ import { Component, Directive, model, signal } from '@angular/core';
 import * as i0 from "@angular/core";
 export class NgModelDirective {
     constructor() {
-        this.ngModel = model.required(...(ngDevMode ? [{ debugName: "ngModel" }] : []));
+        this.ngModel = model.required(Object.assign({}, (ngDevMode ? { debugName: "ngModel" } : {})));
     }
 }
 NgModelDirective.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: NgModelDirective, deps: [], target: i0.ɵɵFactoryTarget.Directive });
@@ -1023,7 +1023,7 @@ import { Component, Directive, model } from '@angular/core';
 import * as i0 from "@angular/core";
 export class NgModelDirective {
     constructor() {
-        this.ngModel = model('', ...(ngDevMode ? [{ debugName: "ngModel" }] : []));
+        this.ngModel = model('', Object.assign({}, (ngDevMode ? { debugName: "ngModel" } : {})));
     }
 }
 NgModelDirective.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: NgModelDirective, deps: [], target: i0.ɵɵFactoryTarget.Directive });
diff --git a/packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js
@@ -5,8 +5,8 @@ import { Directive, input } from '@angular/core';
 import * as i0 from "@angular/core";
 export class TestDir {
     constructor() {
-        this.counter = input(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.name = input.required(...(ngDevMode ? [{ debugName: "name" }] : []));
+        this.counter = input(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.name = input.required(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
@@ -34,8 +34,8 @@ import { Component, input } from '@angular/core';
 import * as i0 from "@angular/core";
 export class TestComp {
     constructor() {
-        this.counter = input(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.name = input.required(...(ngDevMode ? [{ debugName: "name" }] : []));
+        this.counter = input(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.name = input.required(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})));
     }
 }
 TestComp.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestComp, deps: [], target: i0.ɵɵFactoryTarget.Component });
@@ -68,9 +68,9 @@ function convertToBoolean(value) {
 }
 export class TestDir {
     constructor() {
-        this.counter = input(0, ...(ngDevMode ? [{ debugName: "counter" }] : []));
-        this.signalWithTransform = input(false, ...(ngDevMode ? [{ debugName: "signalWithTransform", transform: convertToBoolean }] : [{ transform: convertToBoolean }]));
-        this.signalWithTransformAndAlias = input(false, ...(ngDevMode ? [{ debugName: "signalWithTransformAndAlias", alias: 'publicNameSignal', transform: convertToBoolean }] : [{ alias: 'publicNameSignal', transform: convertToBoolean }]));
+        this.counter = input(0, Object.assign({}, (ngDevMode ? { debugName: "counter" } : {})));
+        this.signalWithTransform = input(false, Object.assign(Object.assign({}, (ngDevMode ? { debugName: "signalWithTransform" } : {})), { transform: convertToBoolean }));
+        this.signalWithTransformAndAlias = input(false, Object.assign(Object.assign({}, (ngDevMode ? { debugName: "signalWithTransformAndAlias" } : {})), { alias: 'publicNameSignal', transform: convertToBoolean }));
         this.decoratorInput = true;
         this.decoratorInputWithAlias = true;
         this.decoratorInputWithTransformAndAlias = true;
@@ -117,9 +117,7 @@ function convertToBoolean(value) {
 }
 export class TestDir {
     constructor() {
-        this.name = input.required(...(ngDevMode ? [{ debugName: "name", transform: convertToBoolean }] : [{
-                transform: convertToBoolean,
-            }]));
+        this.name = input.required(Object.assign(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})), { transform: convertToBoolean }));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
@@ -150,12 +148,10 @@ const toBoolean = (v) => v === true || v !== '';
 const complexTransform = (defaultVal) => (v) => v || defaultVal;
 export class TestDir {
     constructor() {
-        this.name = input.required(...(ngDevMode ? [{ debugName: "name", transform: (v) => v === true || v !== '' }] : [{
-                transform: (v) => v === true || v !== '',
-            }]));
-        this.name2 = input.required(...(ngDevMode ? [{ debugName: "name2", transform: toBoolean }] : [{ transform: toBoolean }]));
-        this.genericTransform = input.required(...(ngDevMode ? [{ debugName: "genericTransform", transform: complexTransform(1) }] : [{ transform: complexTransform(1) }]));
-        this.genericTransform2 = input.required(...(ngDevMode ? [{ debugName: "genericTransform2", transform: complexTransform(null) }] : [{ transform: complexTransform(null) }]));
+        this.name = input.required(Object.assign(Object.assign({}, (ngDevMode ? { debugName: "name" } : {})), { transform: (v) => v === true || v !== '' }));
+        this.name2 = input.required(Object.assign(Object.assign({}, (ngDevMode ? { debugName: "name2" } : {})), { transform: toBoolean }));
+        this.genericTransform = input.required(Object.assign(Object.assign({}, (ngDevMode ? { debugName: "genericTransform" } : {})), { transform: complexTransform(1) }));
+        this.genericTransform2 = input.required(Object.assign(Object.assign({}, (ngDevMode ? { debugName: "genericTransform2" } : {})), { transform: complexTransform(null) }));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
diff --git a/packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js b/packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js
--- a/packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js
+++ b/packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js
@@ -8,15 +8,15 @@ export class SomeToken {
 const nonAnalyzableRefersToString = 'a, b, c';
 export class TestDir {
     constructor() {
-        this.query1 = viewChild('locatorA', ...(ngDevMode ? [{ debugName: "query1" }] : []));
-        this.query2 = viewChildren('locatorB', ...(ngDevMode ? [{ debugName: "query2" }] : []));
-        this.query3 = contentChild('locatorC', ...(ngDevMode ? [{ debugName: "query3" }] : []));
-        this.query4 = contentChildren('locatorD', ...(ngDevMode ? [{ debugName: "query4" }] : []));
-        this.query5 = viewChild(forwardRef(() => SomeToken), ...(ngDevMode ? [{ debugName: "query5" }] : []));
-        this.query6 = viewChildren(SomeToken, ...(ngDevMode ? [{ debugName: "query6" }] : []));
-        this.query7 = viewChild('locatorE', ...(ngDevMode ? [{ debugName: "query7", read: SomeToken }] : [{ read: SomeToken }]));
-        this.query8 = contentChildren('locatorF, locatorG', ...(ngDevMode ? [{ debugName: "query8", descendants: true }] : [{ descendants: true }]));
-        this.query9 = contentChildren(nonAnalyzableRefersToString, ...(ngDevMode ? [{ debugName: "query9", descendants: true }] : [{ descendants: true }]));
+        this.query1 = viewChild('locatorA', Object.assign({}, (ngDevMode ? { debugName: "query1" } : {})));
+        this.query2 = viewChildren('locatorB', Object.assign({}, (ngDevMode ? { debugName: "query2" } : {})));
+        this.query3 = contentChild('locatorC', Object.assign({}, (ngDevMode ? { debugName: "query3" } : {})));
+        this.query4 = contentChildren('locatorD', Object.assign({}, (ngDevMode ? { debugName: "query4" } : {})));
+        this.query5 = viewChild(forwardRef(() => SomeToken), Object.assign({}, (ngDevMode ? { debugName: "query5" } : {})));
+        this.query6 = viewChildren(SomeToken, Object.assign({}, (ngDevMode ? { debugName: "query6" } : {})));
+        this.query7 = viewChild('locatorE', Object.assign(Object.assign({}, (ngDevMode ? { debugName: "query7" } : {})), { read: SomeToken }));
+        this.query8 = contentChildren('locatorF, locatorG', Object.assign(Object.assign({}, (ngDevMode ? { debugName: "query8" } : {})), { descendants: true }));
+        this.query9 = contentChildren(nonAnalyzableRefersToString, Object.assign(Object.assign({}, (ngDevMode ? { debugName: "query9" } : {})), { descendants: true }));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
@@ -53,10 +53,10 @@ import { Component, contentChild, contentChildren, viewChild, viewChildren } fro
 import * as i0 from "@angular/core";
 export class TestComp {
     constructor() {
-        this.query1 = viewChild('locatorA', ...(ngDevMode ? [{ debugName: "query1" }] : []));
-        this.query2 = viewChildren('locatorB', ...(ngDevMode ? [{ debugName: "query2" }] : []));
-        this.query3 = contentChild('locatorC', ...(ngDevMode ? [{ debugName: "query3" }] : []));
-        this.query4 = contentChildren('locatorD', ...(ngDevMode ? [{ debugName: "query4" }] : []));
+        this.query1 = viewChild('locatorA', Object.assign({}, (ngDevMode ? { debugName: "query1" } : {})));
+        this.query2 = viewChildren('locatorB', Object.assign({}, (ngDevMode ? { debugName: "query2" } : {})));
+        this.query3 = contentChild('locatorC', Object.assign({}, (ngDevMode ? { debugName: "query3" } : {})));
+        this.query4 = contentChildren('locatorD', Object.assign({}, (ngDevMode ? { debugName: "query4" } : {})));
     }
 }
 TestComp.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestComp, deps: [], target: i0.ɵɵFactoryTarget.Component });
@@ -88,8 +88,8 @@ import { ContentChild, contentChild, Directive, ViewChild, viewChild } from '@an
 import * as i0 from "@angular/core";
 export class TestDir {
     constructor() {
-        this.signalViewChild = viewChild('locator1', ...(ngDevMode ? [{ debugName: "signalViewChild" }] : []));
-        this.signalContentChild = contentChild('locator2', ...(ngDevMode ? [{ debugName: "signalContentChild" }] : []));
+        this.signalViewChild = viewChild('locator1', Object.assign({}, (ngDevMode ? { debugName: "signalViewChild" } : {})));
+        this.signalContentChild = contentChild('locator2', Object.assign({}, (ngDevMode ? { debugName: "signalContentChild" } : {})));
     }
 }
 TestDir.ɵfac = i0.ɵɵngDeclareFactory({ minVersion: "12.0.0", version: "0.0.0-PLACEHOLDER", ngImport: i0, type: TestDir, deps: [], target: i0.ɵɵFactoryTarget.Directive });
diff --git a/packages/compiler-cli/test/ngtsc/debug_transform_spec.ts b/packages/compiler-cli/test/ngtsc/debug_transform_spec.ts
--- a/packages/compiler-cli/test/ngtsc/debug_transform_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/debug_transform_spec.ts
@@ -12,7 +12,9 @@ import * as esbuild from 'esbuild';
 
 import {NgtscTestEnvironment} from './env';
 
-const testFiles = loadStandardTestFiles();
+const testFiles = loadStandardTestFiles({
+  fakeCommon: true,
+});
 
 const minifiedDevBuildOptions = {
   minifySyntax: true,
@@ -28,13 +30,17 @@ const minifiedProdBuildOptions = {
   define: {ngDevMode: 'false'},
 };
 
+function cleanNewLines(contents: string) {
+  return contents.replace(/\n/g, ' ').replace(/\s+/g, ' ');
+}
+
 runInEachFileSystem(() => {
   describe('Debug Info Typescript tranformation', () => {
     let env!: NgtscTestEnvironment;
 
     beforeEach(() => {
       env = NgtscTestEnvironment.setup(testFiles);
-      env.tsconfig();
+      env.tsconfig({}, {target: 'es2018'});
     });
 
     describe('signal', () => {
@@ -64,7 +70,7 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal" }] : []))`,
+          `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}) })`,
         );
       });
 
@@ -82,7 +88,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('signal("Hello World")');
+          expect(builtContent).toContain('signal("Hello World", {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -112,7 +118,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal", equal: () => true }] : [{ equal: () => true }]))`,
+            `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}), equal: () => true })`,
           );
         });
 
@@ -154,7 +160,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal" }] : []))`,
+            `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}) })`,
           );
         });
 
@@ -177,7 +183,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('signal("Hello World")');
+          expect(builtContent).toContain('signal("Hello World", {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -219,7 +225,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal", equal: () => true }] : [{ equal: () => true }]))`,
+            `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}), equal: () => true })`,
           );
         });
 
@@ -271,7 +277,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal" }] : []))`,
+            `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}) })`,
           );
         });
 
@@ -297,7 +303,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('signal("Hello World")');
+          expect(builtContent).toContain('signal("Hello World", {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -345,7 +351,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `signal('Hello World', ...(ngDevMode ? [{ debugName: "testSignal", equal: () => true }] : [{ equal: () => true }]))`,
+            `signal('Hello World', { ...(ngDevMode ? { debugName: "testSignal" } : {}), equal: () => true })`,
           );
         });
 
@@ -405,7 +411,7 @@ runInEachFileSystem(() => {
         env.driveMain();
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `computed(() => testSignal(), ...(ngDevMode ? [{ debugName: "testComputed" }] : []))`,
+          `computed(() => testSignal(), { ...(ngDevMode ? { debugName: "testComputed" } : {}) })`,
         );
       });
 
@@ -423,7 +429,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('computed(() => testSignal())');
+          expect(builtContent).toContain('computed(() => testSignal(), {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -456,7 +462,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `computed(() => testSignal(), ...(ngDevMode ? [{ debugName: "testComputed", equal: () => true }] : [{ equal: () => true }]))`,
+            `computed(() => testSignal(), { ...(ngDevMode ? { debugName: "testComputed" } : {}), equal: () => true })`,
           );
         });
 
@@ -475,7 +481,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
-          expect(builtContent).toContain(`testComputed = computed(() => testSignal(), { equal }`);
+          expect(builtContent).toContain(`testComputed = computed(() => testSignal(), { equal })`);
           expect(builtContent).not.toContain('ngDevMode');
           expect(builtContent).not.toContain('debugName');
         });
@@ -520,7 +526,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('computed(() => this.testSignal())');
+          expect(builtContent).toContain('computed(() => this.testSignal(), {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -563,7 +569,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `computed(() => this.testSignal(), ...(ngDevMode ? [{ debugName: "testComputed", equal: () => true }] : [{ equal: () => true }]))`,
+            `computed(() => this.testSignal(), { ...(ngDevMode ? { debugName: "testComputed" } : {}), equal: () => true })`,
           );
         });
 
@@ -642,7 +648,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('computed(() => this.testSignal())');
+          expect(builtContent).toContain('computed(() => this.testSignal(), {})');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -695,7 +701,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `computed(() => this.testSignal(), ...(ngDevMode ? [{ debugName: "testComputed", equal: () => true }] : [{ equal: () => true }]))`,
+            `computed(() => this.testSignal(), { ...(ngDevMode ? { debugName: "testComputed" } : {}), equal: () => true })`,
           );
         });
 
@@ -794,10 +800,10 @@ runInEachFileSystem(() => {
         env.driveMain();
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `model('Hello World', ...(ngDevMode ? [{ debugName: "testModel" }] : []))`,
+          `model('Hello World', { ...(ngDevMode ? { debugName: "testModel" } : {}) })`,
         );
         expect(jsContents).toContain(
-          `model(...(ngDevMode ? [undefined, { debugName: "testModel2" }] : []))`,
+          `model(undefined, { ...(ngDevMode ? { debugName: "testModel2" } : {}) })`,
         );
       });
 
@@ -818,7 +824,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('model("Hello World")');
+        expect(builtContent).toContain('model("Hello World", {})');
       });
 
       describe('.required', () => {
@@ -839,7 +845,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `model.required(...(ngDevMode ? [{ debugName: "testModel" }] : []))`,
+            `model.required({ ...(ngDevMode ? { debugName: "testModel" } : {}) })`,
           );
         });
 
@@ -860,7 +866,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `model.required(...(ngDevMode ? [{ debugName: "testModel", alias: 'testModelAlias' }] : [{ alias: 'testModelAlias' }]))`,
+            `model.required({ ...(ngDevMode ? { debugName: "testModel" } : {}), alias: 'testModelAlias' })`,
           );
         });
 
@@ -881,7 +887,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('model.required();');
+          expect(builtContent).toContain('model.required({});');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -984,7 +990,7 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `input(...(ngDevMode ? [undefined, { debugName: "testInput" }] : []))`,
+          `input(undefined, { ...(ngDevMode ? { debugName: "testInput" } : {}) })`,
         );
       });
 
@@ -1006,7 +1012,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('input()');
+        expect(builtContent).toContain('input(void 0, {});');
       });
 
       describe('.required', () => {
@@ -1027,7 +1033,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `input.required(...(ngDevMode ? [{ debugName: "testInput" }] : []))`,
+            `input.required({ ...(ngDevMode ? { debugName: "testInput" } : {}) })`,
           );
         });
 
@@ -1048,7 +1054,7 @@ runInEachFileSystem(() => {
 
           const jsContents = env.getContents('test.js');
           expect(jsContents).toContain(
-            `input.required(...(ngDevMode ? [{ debugName: "testInput", alias: 'testInputAlias' }] : [{ alias: 'testInputAlias' }]))`,
+            `input.required({ ...(ngDevMode ? { debugName: "testInput" } : {}), alias: 'testInputAlias' })`,
           );
         });
 
@@ -1070,7 +1076,7 @@ runInEachFileSystem(() => {
           const jsContents = env.getContents('test.js');
           const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
           expect(builtContent).not.toContain('debugName');
-          expect(builtContent).toContain('input.required();');
+          expect(builtContent).toContain('input.required({});');
         });
 
         it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1185,10 +1191,10 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `viewChild('foo', ...(ngDevMode ? [{ debugName: "testViewChild" }] : []))`,
+          `viewChild('foo', { ...(ngDevMode ? { debugName: "testViewChild" } : {}) })`,
         );
         expect(jsContents).toContain(
-          `viewChild(ChildComponent, ...(ngDevMode ? [{ debugName: "testViewChildComponent" }] : []))`,
+          `viewChild(ChildComponent, { ...(ngDevMode ? { debugName: "testViewChildComponent" } : {}) })`,
         );
       });
 
@@ -1218,8 +1224,8 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain(`viewChild("foo")`);
-        expect(builtContent).toContain(`viewChild(ChildComponent)`);
+        expect(builtContent).toContain(`viewChild("foo", {})`);
+        expect(builtContent).toContain(`viewChild(ChildComponent, {})`);
       });
 
       it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1334,7 +1340,7 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `viewChildren('foo', ...(ngDevMode ? [{ debugName: "testViewChildren" }] : []))`,
+          `viewChildren('foo', { ...(ngDevMode ? { debugName: "testViewChildren" } : {}) })`,
         );
       });
 
@@ -1356,7 +1362,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('viewChildren("foo")');
+        expect(builtContent).toContain('viewChildren("foo", {})');
       });
 
       it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1460,7 +1466,7 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `contentChild('foo', ...(ngDevMode ? [{ debugName: "testContentChild" }] : []))`,
+          `contentChild('foo', { ...(ngDevMode ? { debugName: "testContentChild" } : {}) })`,
         );
       });
 
@@ -1482,7 +1488,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('contentChild("foo")');
+        expect(builtContent).toContain('contentChild("foo", {})');
       });
 
       it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1588,7 +1594,7 @@ runInEachFileSystem(() => {
 
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `contentChildren('foo', ...(ngDevMode ? [{ debugName: "testContentChildren" }] : []))`,
+          `contentChildren('foo', { ...(ngDevMode ? { debugName: "testContentChildren" } : {}) })`,
         );
       });
 
@@ -1610,7 +1616,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('contentChildren("foo")');
+        expect(builtContent).toContain('contentChildren("foo", {})');
       });
 
       it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1718,7 +1724,7 @@ runInEachFileSystem(() => {
         env.driveMain();
         const jsContents = env.getContents('test.js');
         expect(jsContents).toContain(
-          `effect(() => this.testSignal(), ...(ngDevMode ? [{ debugName: "testEffect" }] : []))`,
+          `effect(() => this.testSignal(), { ...(ngDevMode ? { debugName: "testEffect" } : {}) })`,
         );
       });
 
@@ -1739,7 +1745,7 @@ runInEachFileSystem(() => {
         const jsContents = env.getContents('test.js');
         const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
         expect(builtContent).not.toContain('debugName');
-        expect(builtContent).toContain('effect(() => this.testSignal())');
+        expect(builtContent).toContain('effect(() => this.testSignal(), {})');
       });
 
       it('should not tree-shake away debug info if in dev mode', async () => {
@@ -1812,5 +1818,1160 @@ runInEachFileSystem(() => {
         );
       });
     });
+
+    describe('linkedSignal', () => {
+      it('should not insert debug info into linkedSignal function if not imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            declare function linkedSignal(fn: () => any): any;
+            const testLinkedSignal = linkedSignal(() => 123);
+          `,
+        );
+        env.driveMain();
+        const jsContents = env.getContents('test.js');
+        expect(jsContents).not.toContain('debugName');
+      });
+
+      it('should insert debug info into linkedSignal function if imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            import {signal, linkedSignal} from '@angular/core';
+            const testSignal = signal(123);
+            const testLinkedSignal = linkedSignal(() => testSignal());
+          `,
+        );
+        env.driveMain();
+        const jsContents = env.getContents('test.js');
+        expect(jsContents).toContain(
+          `linkedSignal(() => testSignal(), { ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}) })`,
+        );
+      });
+
+      describe('Variable Declaration Case', () => {
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal(() => testSignal());
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).not.toContain('debugName');
+          expect(builtContent).toContain('linkedSignal(() => testSignal(), {})');
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal(() => testSignal());
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `linkedSignal(() => testSignal(), { debugName: "testLinkedSignal" })`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal function that already has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal(() => testSignal(), { equal: () => true });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          expect(jsContents).toContain(
+            `linkedSignal(() => testSignal(), { ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), equal: () => true })`,
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal function that has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              declare function equal(): boolean;
+
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal(() => testSignal(), { equal });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).toContain(
+            `testLinkedSignal = linkedSignal(() => testSignal(), { equal })`,
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              declare function equal(): boolean;
+
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal(() => testSignal(), { equal });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `testLinkedSignal = linkedSignal(() => testSignal(), { debugName: "testLinkedSignal", equal });`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal({
+                source: testSignal,
+                computation: (src, prev) => src,
+              });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            'testLinkedSignal = linkedSignal({ ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), ' +
+              'source: testSignal, ' +
+              'computation: (src, prev) => src ' +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const computation = (src: any, prev: any) => src;
+
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal({
+                source: testSignal,
+                computation,
+              });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testLinkedSignal = linkedSignal({ source: testSignal, computation })',
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal} from '@angular/core';
+              const computation = (src: any, prev: any) => src;
+
+              const testSignal = signal(123);
+              const testLinkedSignal = linkedSignal({
+                source: testSignal,
+                computation,
+              });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testLinkedSignal = linkedSignal({ ' +
+              'debugName: "testLinkedSignal", ' +
+              'source: testSignal, ' +
+              'computation ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Declaration Case', () => {
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal(() => this.testSignal());
+              }
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).not.toContain('debugName');
+          expect(builtContent).toContain('linkedSignal(() => this.testSignal(), {})');
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal(() => this.testSignal());
+              }
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `linkedSignal(() => this.testSignal(), { debugName: "testLinkedSignal" })`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal function that already has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal(() => this.testSignal(), { equal: () => true });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          expect(jsContents).toContain(
+            `linkedSignal(() => this.testSignal(), { ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), equal: () => true })`,
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal function that has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+              const equal = () => true;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal(() => this.testSignal(), { equal });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).toContain(
+            `this.testLinkedSignal = linkedSignal(() => this.testSignal(), { equal })`,
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+              const equal = () => true;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal(() => this.testSignal(), { equal });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `this.testLinkedSignal = linkedSignal(() => this.testSignal(), { debugName: "testLinkedSignal", equal });`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal({
+                  source: this.testSignal,
+                  computation: (src, prev) => src,
+                });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            'linkedSignal({ ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), ' +
+              'source: this.testSignal, ' +
+              'computation: (src, prev) => src ' +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+              const computation = (src: any, prev: any) => src;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal({
+                  source: this.testSignal,
+                  computation,
+                });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'this.testLinkedSignal = linkedSignal({ source: this.testSignal, computation })',
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component} from '@angular/core';
+              const computation = (src: any, prev: any) => src;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal = signal(123);
+                testLinkedSignal = linkedSignal({
+                  source: this.testSignal,
+                  computation,
+                });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'this.testLinkedSignal = linkedSignal({ ' +
+              'debugName: "testLinkedSignal", ' +
+              'source: this.testSignal, ' +
+              'computation ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Assignment Case', () => {
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal(() => this.testSignal());
+                }
+              }
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).not.toContain('debugName');
+          expect(builtContent).toContain('linkedSignal(() => this.testSignal(), {})');
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal(() => this.testSignal());
+                }
+              }
+            `,
+          );
+          env.driveMain();
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `linkedSignal(() => this.testSignal(), { debugName: "testLinkedSignal" })`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal function that already has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal(() => this.testSignal(), { equal: () => true });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          expect(jsContents).toContain(
+            `linkedSignal(() => this.testSignal(), { ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), equal: () => true })`,
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal function that has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+              const equal = () => true;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal(() => this.testSignal(), { equal });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          expect(builtContent).toContain(
+            `this.testLinkedSignal = linkedSignal(() => this.testSignal(), { equal })`,
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and has custom options', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+              const equal = () => true;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal(() => this.testSignal(), { equal });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          expect(builtContent).toContain(
+            `this.testLinkedSignal = linkedSignal(() => this.testSignal(), { debugName: "testLinkedSignal", equal });`,
+          );
+        });
+
+        it('should insert debug info into linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal({
+                    source: this.testSignal,
+                    computation: (src, prev) => src,
+                  });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            'linkedSignal({ ...(ngDevMode ? { debugName: "testLinkedSignal" } : {}), ' +
+              'source: this.testSignal, ' +
+              'computation: (src, prev) => src ' +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode for linkedSignal with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              const computation = (src: any, prev: any) => src;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal({
+                    source: this.testSignal,
+                    computation,
+                  });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'this.testLinkedSignal = linkedSignal({ source: this.testSignal, computation })',
+          );
+          expect(builtContent).not.toContain('ngDevMode');
+          expect(builtContent).not.toContain('debugName');
+        });
+
+        it('should not tree-shake away debug info if in dev mode and with a computation object', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {signal, linkedSignal, Component, WritableSignal, Signal} from '@angular/core';
+
+              const computation = (src: any, prev: any) => src;
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testSignal: WritableSignal<number>;
+                testLinkedSignal: Signal<number>;
+
+                constructor() {
+                  this.testSignal = signal(123);
+                  this.testLinkedSignal = linkedSignal({
+                    source: this.testSignal,
+                    computation,
+                  });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'this.testLinkedSignal = linkedSignal({ ' +
+              'debugName: "testLinkedSignal", ' +
+              'source: this.testSignal, ' +
+              'computation ' +
+              '})',
+          );
+        });
+      });
+    });
+
+    describe('resource', () => {
+      it('should not insert debug info into resource function if not imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            declare function resource(props: any): any;
+            const testResource = resource({
+              defaultValue: 'foo',
+              loader: async () => 'bar',
+            });
+          `,
+        );
+        env.driveMain();
+        const jsContents = env.getContents('test.js');
+        expect(jsContents).not.toContain('debugName');
+      });
+
+      it('should insert debug info into resource function if imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            import {resource} from '@angular/core';
+            const testResource = resource({
+              defaultValue: 'foo',
+              loader: async () => 'bar',
+            });
+          `,
+        );
+        env.driveMain();
+        const jsContents = cleanNewLines(env.getContents('test.js'));
+        expect(jsContents).toContain(
+          'resource({ ' +
+            '...(ngDevMode ? { debugName: "testResource" } : {}), ' +
+            `defaultValue: 'foo', ` +
+            `loader: async () => 'bar' ` +
+            '})',
+        );
+      });
+
+      describe('Variable Declaration Case', () => {
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource} from '@angular/core';
+              const loader = async () => 'bar';
+              const testResource = resource({
+                defaultValue: "foo",
+                loader,
+              });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(
+            `testResource = resource({ defaultValue: "foo", loader })`,
+          );
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource} from '@angular/core';
+              const loader = async () => 'bar';
+              const testResource = resource({
+                defaultValue: 'foo',
+                loader,
+              });
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testResource = resource({ ' +
+              'debugName: "testResource", ' +
+              'defaultValue: "foo", ' +
+              'loader ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Declaration Case', () => {
+        it('should insert debug info into resource function', () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testResource = resource({
+                  defaultValue: 'foo',
+                  loader: async () => 'bar',
+                });
+              }`,
+          );
+          env.driveMain();
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            'resource({ ' +
+              '...(ngDevMode ? { debugName: "testResource" } : {}), ' +
+              `defaultValue: 'foo', ` +
+              `loader: async () => 'bar' ` +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource, Component} from '@angular/core';
+              const loader = async () => 'bar';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testResource = resource({
+                  defaultValue: 'foo',
+                  loader,
+                });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(
+            `testResource = resource({ defaultValue: "foo", loader })`,
+          );
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource, Component} from '@angular/core';
+              const loader = async () => 'bar';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testResource = resource({
+                  defaultValue: 'foo',
+                  loader,
+                });
+              }
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testResource = resource({ ' +
+              'debugName: "testResource", ' +
+              'defaultValue: "foo", ' +
+              'loader ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Assignment Case', () => {
+        it('should insert debug info into resource function', () => {
+          env.write(
+            'test.ts',
+            `
+              import {resource, ResourceRef, Component} from '@angular/core';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testResource: ResourceRef<any>;
+                constructor() {
+                  this.testResource = resource({
+                    defaultValue: 'foo',
+                    loader: async () => 'bar',
+                  });
+                }
+              }
+            `,
+          );
+          env.driveMain();
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            'resource({ ' +
+              '...(ngDevMode ? { debugName: "testResource" } : {}), ' +
+              `defaultValue: 'foo', ` +
+              `loader: async () => 'bar' ` +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+            import {resource, ResourceRef, Component} from '@angular/core';
+            const loader = async () => 'bar';
+
+            @Component({
+              template: ''
+            }) class MyComponent {
+              testResource: ResourceRef<any>;
+              constructor() {
+                this.testResource = resource({
+                  defaultValue: 'foo',
+                  loader,
+                });
+              }
+            }
+          `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(
+            `testResource = resource({ defaultValue: "foo", loader })`,
+          );
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+            import {resource, ResourceRef, Component} from '@angular/core';
+            const loader = async () => 'bar';
+
+            @Component({
+              template: ''
+            }) class MyComponent {
+              testResource: ResourceRef<any>;
+              constructor() {
+                this.testResource = resource({
+                  defaultValue: 'foo',
+                  loader,
+                });
+              }
+            }
+          `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testResource = resource({ ' +
+              'debugName: "testResource", ' +
+              'defaultValue: "foo", ' +
+              'loader ' +
+              '})',
+          );
+        });
+      });
+    });
+
+    describe('httpResource', () => {
+      it('should not insert debug info into httpResource function if not imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            declare function httpResource(props: any): any;
+            const testResource = httpResource(() => '/api');
+          `,
+        );
+        env.driveMain();
+        const jsContents = env.getContents('test.js');
+        expect(jsContents).not.toContain('debugName');
+      });
+
+      it('should insert debug info into httpResource function if imported from angular core', () => {
+        env.write(
+          'test.ts',
+          `
+            import {httpResource} from '@angular/common/http';
+            const testHttpResource = httpResource(() => '/api');
+          `,
+        );
+        env.driveMain();
+        const jsContents = cleanNewLines(env.getContents('test.js'));
+        expect(jsContents).toContain(
+          `httpResource(() => '/api', { ` +
+            '...(ngDevMode ? { debugName: "testHttpResource" } : {}) ' +
+            '})',
+        );
+      });
+
+      describe('Variable Declaration Case', () => {
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {httpResource} from '@angular/common/http';
+              const testHttpResource = httpResource(() => '/api');
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(`testHttpResource = httpResource(() => "/api", {})`);
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {httpResource} from '@angular/common/http';
+              const testHttpResource = httpResource(() => '/api');
+            `,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testHttpResource = httpResource(() => "/api", { ' +
+              'debugName: "testHttpResource" ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Declaration Case', () => {
+        it('should insert debug info into httpResource function', () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource = httpResource(() => '/api');
+              }`,
+          );
+          env.driveMain();
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            `httpResource(() => '/api', { ` +
+              '...(ngDevMode ? { debugName: "testHttpResource" } : {}) ' +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource = httpResource(() => '/api');
+              }`,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(`testHttpResource = httpResource(() => "/api", {})`);
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource = httpResource(() => '/api');
+              }`,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testHttpResource = httpResource(() => "/api", { ' +
+              'debugName: "testHttpResource" ' +
+              '})',
+          );
+        });
+      });
+
+      describe('Property Assignment Case', () => {
+        it('should insert debug info into httpResource function', () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource, HttpResourceRef} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource: HttpResourceRef<any>;
+                constructor() {
+                  this.testHttpResource = httpResource(() => '/api');
+                }
+              }`,
+          );
+          env.driveMain();
+          const jsContents = cleanNewLines(env.getContents('test.js'));
+          expect(jsContents).toContain(
+            `httpResource(() => '/api', { ` +
+              '...(ngDevMode ? { debugName: "testHttpResource" } : {}) ' +
+              '})',
+          );
+        });
+
+        it('should tree-shake away debug info if in prod mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource, HttpResourceRef} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource: HttpResourceRef<any>;
+                constructor() {
+                  this.testHttpResource = httpResource(() => '/api');
+                }
+              }`,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedProdBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).not.toContain('debugName');
+          expect(contentWoNewLines).toContain(`testHttpResource = httpResource(() => "/api", {})`);
+        });
+
+        it('should not tree-shake away debug info if in dev mode', async () => {
+          env.write(
+            'test.ts',
+            `
+              import {Component} from '@angular/core';
+              import {httpResource, HttpResourceRef} from '@angular/common/http';
+
+              @Component({
+                template: ''
+              }) class MyComponent {
+                testHttpResource: HttpResourceRef<any>;
+                constructor() {
+                  this.testHttpResource = httpResource(() => '/api');
+                }
+              }`,
+          );
+          env.driveMain();
+
+          const jsContents = env.getContents('test.js');
+          const builtContent = (await esbuild.transform(jsContents, minifiedDevBuildOptions)).code;
+          const contentWoNewLines = cleanNewLines(builtContent);
+          expect(contentWoNewLines).toContain(
+            'testHttpResource = httpResource(() => "/api", { ' +
+              'debugName: "testHttpResource" ' +
+              '})',
+          );
+        });
+      });
+    });
   });
 });
diff --git a/packages/compiler-cli/test/ngtsc/env.ts b/packages/compiler-cli/test/ngtsc/env.ts
--- a/packages/compiler-cli/test/ngtsc/env.ts
+++ b/packages/compiler-cli/test/ngtsc/env.ts
@@ -41,10 +41,21 @@ type TsConfigOptionsValue =
   | null
   | TsConfigOptionsValue[]
   | {[key: string]: TsConfigOptionsValue};
+
 export type TsConfigOptions = {
   [key: string]: TsConfigOptionsValue;
 };
 
+type KnownKeys<T> = {
+  [K in keyof T as string extends K ? never : number extends K ? never : K]: T[K];
+};
+
+// We don't use ts.CompilerOptions directly since enum-based options
+// require additional mapping to be JSON-ified.
+type TsCompilerOptions = Partial<
+  Record<keyof KnownKeys<ts.CompilerOptions>, ts.CompilerOptionsValue>
+>;
+
 /**
  * Manages a temporary testing directory structure and environment for testing ngtsc by feeding it
  * TypeScript code.
@@ -213,18 +224,20 @@ export class NgtscTestEnvironment {
     }
   }
 
-  tsconfig(extraOpts: TsConfigOptions = {}, extraRootDirs?: string[], files?: string[]): void {
-    const tsconfig: {[key: string]: any} = {
+  tsconfig(
+    extraOpts: TsConfigOptions = {},
+    compilerOptions?: TsCompilerOptions,
+    files?: string[],
+  ): void {
+    let tsconfig: {[key: string]: any} = {
       extends: './tsconfig-base.json',
       angularCompilerOptions: extraOpts,
     };
     if (files !== undefined) {
       tsconfig['files'] = files;
     }
-    if (extraRootDirs !== undefined) {
-      tsconfig['compilerOptions'] = {
-        rootDirs: ['.', ...extraRootDirs],
-      };
+    if (compilerOptions !== undefined) {
+      tsconfig['compilerOptions'] = compilerOptions;
     }
     this.write('tsconfig.json', JSON.stringify(tsconfig, null, 2));
 
diff --git a/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts b/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
--- a/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
@@ -1600,7 +1600,12 @@ runInEachFileSystem((os: string) => {
     });
 
     it('should compile Components with a templateUrl in a different rootDir', () => {
-      env.tsconfig({}, ['./extraRootDir']);
+      env.tsconfig(
+        {},
+        {
+          rootDirs: ['.', './extraRootDir'],
+        },
+      );
       env.write('extraRootDir/test.html', '<p>Hello World</p>');
       env.write(
         'test.ts',
@@ -1623,7 +1628,12 @@ runInEachFileSystem((os: string) => {
     });
 
     it('should compile Components with an absolute templateUrl in a different rootDir', () => {
-      env.tsconfig({}, ['./extraRootDir']);
+      env.tsconfig(
+        {},
+        {
+          rootDirs: ['.', './extraRootDir'],
+        },
+      );
       env.write('extraRootDir/test.html', '<p>Hello World</p>');
       env.write(
         'test.ts',
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run ngtsc tests (includes debug_transform_spec.ts and ngtsc_spec.ts)
bazelisk test \
  //packages/compiler-cli/test/ngtsc:ngtsc \
  --test_output=errors \
  --jobs=4

# Capture the exit code from ngtsc tests
rc1=$?

# Run compliance tests - these tests validate the GOLDEN_PARTIAL.js files
# Using the broader compliance test suite which includes all test cases
bazelisk test \
  //packages/compiler-cli/test/compliance/... \
  --test_output=errors \
  --jobs=4

# Capture the exit code from compliance tests
rc2=$?

# Combine exit codes - if either test fails, the overall result is failure
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
  rc=1
else
  rc=0
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 3ae452e64f81b92f89b89132389ced3848b30aae \
  "packages/compiler-cli/src/ngtsc/testing/fake_common/BUILD.bazel" \
  "packages/compiler-cli/test/compliance/test_cases/model_inputs/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/animations/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_listener/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/signal_inputs/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/compliance/test_cases/signal_queries/GOLDEN_PARTIAL.js" \
  "packages/compiler-cli/test/ngtsc/debug_transform_spec.ts" \
  "packages/compiler-cli/test/ngtsc/env.ts" \
  "packages/compiler-cli/test/ngtsc/ngtsc_spec.ts"