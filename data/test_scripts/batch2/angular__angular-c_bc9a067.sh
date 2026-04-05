#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout c2987d8402b7b03333b0081a7f97750cdf612e99 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
@@ -161,6 +161,7 @@ function setup(
     /* enableHmr */ false,
     /* implicitStandaloneValue */ true,
     /* typeCheckHostBindings */ true,
+    /* enableSelectorless */ false,
   );
   return {reflectionHost, handler, resourceLoader, metaRegistry};
 }
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
@@ -15,6 +15,7 @@ import {
   PropertyRead,
   PropertyWrite,
   R3TargetBinder,
+  SelectorlessMatcher,
   SelectorMatcher,
   TmplAstElement,
   TmplAstLetDeclaration,
@@ -279,6 +280,7 @@ export const ALL_ENABLED_CONFIG: Readonly<TypeCheckingConfig> = {
   unusedStandaloneImports: 'warning',
   allowSignalsInTwoWayBindings: true,
   checkTwoWayBoundEvents: true,
+  selectorlessEnabled: false,
 };
 
 // Remove 'ref' from TypeCheckableDirectiveMeta and add a 'selector' instead.
@@ -299,7 +301,7 @@ export interface TestDirective
       >
     >
   > {
-  selector: string;
+  selector: string | null;
   name: string;
   file?: AbsoluteFsPath;
   type: 'directive';
@@ -369,6 +371,7 @@ export function tcb(
   const clazz = getClass(sf, 'Test');
   const templateUrl = 'synthetic.html';
   const {nodes, errors} = parseTemplate(template, templateUrl, templateParserOptions);
+  const selectorlessEnabled = templateParserOptions?.enableSelectorless ?? false;
 
   if (errors !== null) {
     throw new Error('Template parse errors: \n' + errors.join('\n'));
@@ -378,6 +381,7 @@ export function tcb(
     declarations,
     (decl) => getClass(sf, decl.name),
     new Map(),
+    selectorlessEnabled,
   );
   const binder = new R3TargetBinder<DirectiveMeta>(matcher);
   const boundTarget = binder.bind({template: nodes});
@@ -419,6 +423,7 @@ export function tcb(
     suggestionsForSuboptimalTypeInference: false,
     allowSignalsInTwoWayBindings: true,
     checkTwoWayBoundEvents: true,
+    selectorlessEnabled,
     ...config,
   };
   options = options || {emitSpans: false};
@@ -608,6 +613,7 @@ export function setup(
             return getClass(declFile, decl.name);
           },
           fakeMetadataRegistry,
+          overrides.parseOptions?.enableSelectorless ?? false,
         );
         const binder = new R3TargetBinder<DirectiveMeta>(matcher);
         const classRef = new Reference(classDecl);
@@ -776,8 +782,8 @@ function prepareDeclarations(
   declarations: TestDeclaration[],
   resolveDeclaration: DeclarationResolver,
   metadataRegistry: Map<string, TypeCheckableDirectiveMeta>,
+  selectorlessEnabled: boolean,
 ) {
-  const matcher = new SelectorMatcher<DirectiveMeta[]>();
   const pipes = new Map<string, PipeMeta>();
   const hostDirectiveResolder = new HostDirectivesResolver(
     getFakeMetadataReader(metadataRegistry as Map<string, DirectiveMeta>),
@@ -809,13 +815,23 @@ function prepareDeclarations(
 
   // We need to make two passes over the directives so that all declarations
   // have been registered by the time we resolve the host directives.
-  for (const meta of directives) {
-    const selector = CssSelector.parse(meta.selector || '');
-    const matches = [...hostDirectiveResolder.resolve(meta), meta] as DirectiveMeta[];
-    matcher.addSelectables(selector, matches);
-  }
 
-  return {matcher, pipes};
+  if (selectorlessEnabled) {
+    const registry = new Map<string, DirectiveMeta[]>();
+    for (const meta of directives) {
+      registry.set(meta.name, [meta, ...hostDirectiveResolder.resolve(meta)]);
+    }
+    return {matcher: new SelectorlessMatcher<DirectiveMeta[]>(registry), pipes};
+  } else {
+    const matcher = new SelectorMatcher<DirectiveMeta[]>();
+    for (const meta of directives) {
+      const selector = CssSelector.parse(meta.selector || '');
+      const matches = [...hostDirectiveResolder.resolve(meta), meta] as DirectiveMeta[];
+      matcher.addSelectables(selector, matches);
+    }
+
+    return {matcher, pipes};
+  }
 }
 
 export function getClass(sf: ts.SourceFile, name: string): ClassDeclaration<ts.ClassDeclaration> {
EOF_114329324912

# Run the specified test using Bazel
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# The test target //packages/compiler-cli/src/ngtsc/annotations/component/test:test covers the component_spec.ts test file
# Limiting parallelism with --jobs=4 for stability in virtualized environment
# Using --test_output=errors to show only failures for cleaner output
bazelisk test \
  //packages/compiler-cli/src/ngtsc/annotations/component/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout c2987d8402b7b03333b0081a7f97750cdf612e99 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"