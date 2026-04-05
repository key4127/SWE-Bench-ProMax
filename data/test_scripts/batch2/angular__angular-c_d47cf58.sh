#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 765ba1e181442079c25387bb869ed576388e839c \
  "packages/core/test/acceptance/discover_utils_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/discover_utils_spec.ts b/packages/core/test/acceptance/discover_utils_spec.ts
--- a/packages/core/test/acceptance/discover_utils_spec.ts
+++ b/packages/core/test/acceptance/discover_utils_spec.ts
@@ -24,7 +24,7 @@ import {ComponentFixture, TestBed} from '../../testing';
 import {getLContext} from '../../src/render3/context_discovery';
 import {getHostElement} from '../../src/render3/index';
 import {
-  ComponentDebugMetadata,
+  AngularComponentDebugMetadata,
   getComponent,
   getComponentLView,
   getContext,
@@ -383,13 +383,11 @@ describe('discovery utils', () => {
 
   describe('getDirectiveMetadata', () => {
     it('should work with components', () => {
-      const metadata = getDirectiveMetadata(myApp);
-      expect(metadata!.inputs).toEqual({a: 'b'});
-      expect(metadata!.outputs).toEqual({c: 'd'});
-      expect((metadata as ComponentDebugMetadata).changeDetection).toBe(
-        ChangeDetectionStrategy.Default,
-      );
-      expect((metadata as ComponentDebugMetadata).encapsulation).toBe(ViewEncapsulation.None);
+      const metadata = getDirectiveMetadata(myApp)! as AngularComponentDebugMetadata;
+      expect(metadata.inputs).toEqual({a: 'b'});
+      expect(metadata.outputs).toEqual({c: 'd'});
+      expect(metadata.changeDetection).toBe(ChangeDetectionStrategy.Default);
+      expect(metadata.encapsulation).toBe(ViewEncapsulation.None);
     });
 
     it('should work with directives', () => {
EOF_114329324912

# Run the acceptance test target which includes discover_utils_spec.ts
# Using bazelisk which will automatically use the correct Bazel version from .bazelversion
# The correct target is //packages/core/test/acceptance:acceptance (jasmine_node_test)
# Limiting jobs to 4 for stability in the virtualized environment
bazelisk test \
  //packages/core/test/acceptance:acceptance \
  --test_output=errors \
  --test_summary=detailed \
  --verbose_failures \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 765ba1e181442079c25387bb869ed576388e839c \
  "packages/core/test/acceptance/discover_utils_spec.ts"