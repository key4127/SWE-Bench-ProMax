#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless Chrome testing
/usr/local/bin/start-xvfb.sh

# Checkout the target test files to ensure clean state
git checkout 5af15a6d50e0c65536f217caccbff9555a2c9bf0 \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts
@@ -119,7 +119,7 @@ runInEachFileSystem(() => {
         ).toEqual('name');
 
         // Ensure we can go back to the original location using the shim location
-        const mapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+        const mapping = templateTypeChecker.getSourceMappingAtTcbLocation(
           symbol.bindings[0].tcbLocation,
         )!;
         expect(mapping.span.toString()).toEqual('name');
@@ -198,11 +198,11 @@ runInEachFileSystem(() => {
           expect(symbol.declaration.name).toEqual('contextFoo');
 
           // Ensure we can map the shim locations back to the template
-          const initializerMapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+          const initializerMapping = templateTypeChecker.getSourceMappingAtTcbLocation(
             symbol.initializerLocation,
           )!;
           expect(initializerMapping.span.toString()).toEqual('bar');
-          const localVarMapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+          const localVarMapping = templateTypeChecker.getSourceMappingAtTcbLocation(
             symbol.localVarLocation,
           )!;
           expect(localVarMapping.span.toString()).toEqual('contextFoo');
@@ -225,7 +225,7 @@ runInEachFileSystem(() => {
           assertDirectiveReference(symbol);
 
           // Ensure we can map the var shim location back to the template
-          const localVarMapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+          const localVarMapping = templateTypeChecker.getSourceMappingAtTcbLocation(
             symbol.referenceVarLocation,
           );
           expect(localVarMapping!.span.toString()).toEqual('ref1');
@@ -2039,11 +2039,11 @@ runInEachFileSystem(() => {
         expect(symbol.declaration.name).toEqual('message');
 
         // Ensure we can map the shim locations back to the template
-        const initializerMapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+        const initializerMapping = templateTypeChecker.getSourceMappingAtTcbLocation(
           symbol.initializerLocation,
         )!;
         expect(initializerMapping.span.toString()).toEqual(`'The value is ' + value`);
-        const localVarMapping = templateTypeChecker.getTemplateMappingAtTcbLocation(
+        const localVarMapping = templateTypeChecker.getSourceMappingAtTcbLocation(
           symbol.localVarLocation,
         )!;
         expect(localVarMapping.span.toString()).toEqual('message');
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts
@@ -35,7 +35,7 @@ import {
   TypeCheckContextImpl,
   TypeCheckingHost,
 } from '../src/context';
-import {TemplateSourceManager} from '../src/source';
+import {DirectiveSourceManager} from '../src/source';
 import {TypeCheckFile} from '../src/type_check_file';
 import {ALL_ENABLED_CONFIG} from '../testing';
 
@@ -302,15 +302,15 @@ TestClass.ngTypeCtor({value: 'test'});
 function makePendingFile(): PendingFileTypeCheckingData {
   return {
     hasInlines: false,
-    sourceManager: new TemplateSourceManager(),
+    sourceManager: new DirectiveSourceManager(),
     shimData: new Map(),
   };
 }
 
 class TestTypeCheckingHost implements TypeCheckingHost {
-  private sourceManager = new TemplateSourceManager();
+  private sourceManager = new DirectiveSourceManager();
 
-  getSourceManager(): TemplateSourceManager {
+  getSourceManager(): DirectiveSourceManager {
     return this.sourceManager;
   }
 
EOF_114329324912

# Run the unit tests for the specified typecheck test files
# Using bazelisk to ensure correct Bazel version (7.1.1 from .bazelversion)
# The tests are located in //packages/compiler-cli/src/ngtsc/typecheck/test
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/compiler-cli/src/ngtsc/typecheck/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 5af15a6d50e0c65536f217caccbff9555a2c9bf0 \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_checker__get_symbol_of_template_node_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_constructor_spec.ts"