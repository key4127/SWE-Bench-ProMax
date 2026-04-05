#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 84b372135129d5e31c6678ddf7af54d588acb7e1 \
  "packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts
@@ -21,6 +21,7 @@ import {ImportedSymbolsTracker, ReferenceEmitter} from '../../../imports';
 import {
   CompoundMetadataReader,
   DtsMetadataReader,
+  HostDirectivesResolver,
   LocalMetadataRegistry,
   ResourceRegistry,
 } from '../../../metadata';
@@ -31,7 +32,11 @@ import {
   isNamedClassDeclaration,
   TypeScriptReflectionHost,
 } from '../../../reflection';
-import {LocalModuleScopeRegistry, MetadataDtsModuleScopeResolver} from '../../../scope';
+import {
+  LocalModuleScopeRegistry,
+  MetadataDtsModuleScopeResolver,
+  TypeCheckScopeRegistry,
+} from '../../../scope';
 import {getDeclaration, makeProgram} from '../../../testing';
 import {CompilationMode} from '../../../transform';
 import {
@@ -201,6 +206,12 @@ runInEachFileSystem(() => {
     const importTracker = new ImportedSymbolsTracker();
     const jitDeclarationRegistry = new JitDeclarationRegistry();
     const resourceRegistry = new ResourceRegistry();
+    const hostDirectivesResolver = new HostDirectivesResolver(metaReader);
+    const typeCheckScopeRegistry = new TypeCheckScopeRegistry(
+      scopeRegistry,
+      metaReader,
+      hostDirectivesResolver,
+    );
 
     const handler = new DirectiveDecoratorHandler(
       reflectionHost,
@@ -218,11 +229,14 @@ runInEachFileSystem(() => {
       NOOP_PERF_RECORDER,
       importTracker,
       /*includeClassMetadata*/ true,
+      typeCheckScopeRegistry,
       /*compilationMode */ CompilationMode.FULL,
       jitDeclarationRegistry,
       resourceRegistry,
       /* strictStandalone */ false,
       /* implicitStandaloneValue */ true,
+      /* usePoisonedData */ false,
+      /* typeCheckHostBindings */ true,
     );
 
     const DirNode = getDeclaration(program, _('/entry.ts'), dirName, isNamedClassDeclaration);
EOF_114329324912

# Run the directive annotation tests using Bazel
# The test target corresponds to the BUILD.bazel file in the test directory
# Using --test_output=all to see all test output
# Using --cache_test_results=no to ensure tests run fresh
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/compiler-cli/src/ngtsc/annotations/directive/test:test \
  --test_output=all \
  --cache_test_results=no \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 84b372135129d5e31c6678ddf7af54d588acb7e1 \
  "packages/compiler-cli/src/ngtsc/annotations/directive/test/directive_spec.ts"