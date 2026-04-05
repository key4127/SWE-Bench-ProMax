#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e0401ec1f0f856a7caf8aa93762bf9c369f3f871 \
  "packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hello_world/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/injection/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts b/packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts
--- a/packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts
+++ b/packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts
@@ -158,6 +158,33 @@ describe('ngInjectableDef Bazel Integration', () => {
     expect(() => TestBed.inject(ChildService).value).toThrowError(/ChildService/);
   });
 
+  it('uses legacy `ngInjectable` property even if it inherits from a class that has `ɵprov` property', () => {
+    @Injectable({
+      providedIn: 'root',
+      useValue: new ParentService('parent'),
+    })
+    class ParentService {
+      constructor(public value: string) {}
+    }
+
+    // ChildServices extends ParentService but does not have @Injectable
+    class ChildService extends ParentService {
+      constructor(value: string) {
+        super(value);
+      }
+      static ngInjectableDef = {
+        providedIn: 'root',
+        factory: () => new ChildService('child'),
+        token: ChildService,
+      };
+    }
+
+    TestBed.configureTestingModule({});
+    // We are asserting that system throws an error, rather than taking the inherited
+    // annotation.
+    expect(TestBed.inject(ChildService).value).toEqual('child');
+  });
+
   it('NgModule injector understands requests for INJECTABLE', () => {
     TestBed.configureTestingModule({
       providers: [{provide: 'foo', useValue: 'bar'}],
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -103,6 +103,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_PIPE_DEF",
   "NG_PROV_DEF",
@@ -323,6 +325,7 @@
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
   "getOrSetDefaultValue",
+  "getOwnDefinition",
   "getParentElement",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -110,6 +110,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PIPE_DEF",
@@ -346,6 +348,7 @@
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
   "getOrSetDefaultValue",
+  "getOwnDefinition",
   "getParentElement",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -79,6 +79,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PIPE_DEF",
@@ -273,6 +275,7 @@
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -105,6 +105,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_PIPE_DEF",
   "NG_PROV_DEF",
@@ -328,6 +330,7 @@
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -112,6 +112,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MODEL_WITH_FORM_CONTROL_WARNING",
   "NG_MOD_DEF",
@@ -391,6 +393,7 @@
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
   "getOrCreateViewRefs",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -105,6 +105,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PIPE_DEF",
@@ -377,6 +379,7 @@
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
   "getOrCreateViewRefs",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -53,6 +53,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PROV_DEF",
@@ -213,6 +215,7 @@
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -85,6 +85,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_PIPE_DEF",
   "NG_PROV_DEF",
@@ -280,6 +282,7 @@
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/injection/bundle.golden_symbols.json b/packages/core/test/bundling/injection/bundle.golden_symbols.json
--- a/packages/core/test/bundling/injection/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/injection/bundle.golden_symbols.json
@@ -12,6 +12,8 @@
   "NG_COMP_DEF",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_PROV_DEF",
   "NOT_YET",
@@ -45,6 +47,7 @@
   "getInjectableDef",
   "getInjectorDef",
   "getNullInjector",
+  "getOwnDefinition",
   "importProvidersFrom",
   "injectArgs",
   "injectInjectorOnly",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -119,6 +119,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PIPE_DEF",
@@ -465,6 +467,7 @@
   "getOrCreateTViewCleanup",
   "getOrCreateViewRefs",
   "getOutlet",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -73,6 +73,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_PIPE_DEF",
   "NG_PROV_DEF",
@@ -242,6 +244,7 @@
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -81,6 +81,8 @@
   "NG_ELEMENT_ID",
   "NG_ENV_ID",
   "NG_FACTORY_DEF",
+  "NG_INJECTABLE_DEF",
+  "NG_INJECTOR_DEF",
   "NG_INJ_DEF",
   "NG_MOD_DEF",
   "NG_PIPE_DEF",
@@ -321,6 +323,7 @@
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
   "getOrCreateViewRefs",
+  "getOwnDefinition",
   "getParentInjectorIndex",
   "getParentInjectorLocation",
   "getParentInjectorView",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Run all target tests using Bazel in a single command for efficiency
# This includes the injectable_def integration test and all symbol tests
bazelisk test \
  //packages/compiler-cli/integrationtest/bazel/injectable_def/app/test:test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/animations:symbol_test \
  //packages/core/test/bundling/cyclic_import:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/hello_world:symbol_test \
  //packages/core/test/bundling/hydration:symbol_test \
  //packages/core/test/bundling/injection:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/standalone_bootstrap:symbol_test \
  //packages/core/test/bundling/todo:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e0401ec1f0f856a7caf8aa93762bf9c369f3f871 \
  "packages/compiler-cli/integrationtest/bazel/injectable_def/app/test/app_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hello_world/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/injection/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"