#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 7ffcb504df2e14610cfb4fd219dbb5cfb3c30f15 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
@@ -231,7 +231,7 @@ runInEachFileSystem(() => {
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
       expect(analysis?.resources.template?.path).toBeNull();
-      expect(analysis?.resources.template?.expression.getText()).toEqual(`'${template}'`);
+      expect(analysis?.resources.template?.node.getText()).toEqual(`'${template}'`);
     });
 
     it('should keep track of external template', () => {
@@ -264,7 +264,7 @@ runInEachFileSystem(() => {
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
       expect(analysis?.resources.template?.path).toContain(templateUrl);
-      expect(analysis?.resources.template?.expression.getText()).toContain(`'${templateUrl}'`);
+      expect(analysis?.resources.template?.node.getText()).toContain(`'${templateUrl}'`);
     });
 
     it('should keep track of internal and external styles', () => {
diff --git a/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
@@ -18,7 +18,12 @@ import ts from 'typescript';
 import {absoluteFrom} from '../../../file_system';
 import {runInEachFileSystem} from '../../../file_system/testing';
 import {ImportedSymbolsTracker, ReferenceEmitter} from '../../../imports';
-import {CompoundMetadataReader, DtsMetadataReader, LocalMetadataRegistry} from '../../../metadata';
+import {
+  CompoundMetadataReader,
+  DtsMetadataReader,
+  LocalMetadataRegistry,
+  ResourceRegistry,
+} from '../../../metadata';
 import {PartialEvaluator} from '../../../partial_evaluator';
 import {NOOP_PERF_RECORDER} from '../../../perf';
 import {
@@ -195,6 +200,7 @@ runInEachFileSystem(() => {
     const injectableRegistry = new InjectableClassRegistry(reflectionHost, /* isCore */ false);
     const importTracker = new ImportedSymbolsTracker();
     const jitDeclarationRegistry = new JitDeclarationRegistry();
+    const resourceRegistry = new ResourceRegistry();
 
     const handler = new DirectiveDecoratorHandler(
       reflectionHost,
@@ -214,6 +220,7 @@ runInEachFileSystem(() => {
       /*includeClassMetadata*/ true,
       /*compilationMode */ CompilationMode.FULL,
       jitDeclarationRegistry,
+      resourceRegistry,
       /* strictStandalone */ false,
       /* implicitStandaloneValue */ true,
     );
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
@@ -648,7 +648,7 @@ export function setup(
           preserveWhitespaces: false,
         };
 
-        ctx.addDirective(classRef, binder, [], templateContext, false);
+        ctx.addDirective(classRef, binder, [], templateContext, null, false);
       }
     }
   });
EOF_114329324912

# Run the component and directive tests using Bazel
# Using bazelisk (installed globally) to automatically use the correct Bazel version (5.0.0)
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
# Running both test targets in a single command for efficiency
bazelisk test \
  //packages/compiler-cli/src/ngtsc/annotations/component/test:test \
  //packages/compiler-cli/src/ngtsc/annotations/directive/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 7ffcb504df2e14610cfb4fd219dbb5cfb3c30f15 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"