#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 95424b26892b005f438169d0ea426cb1a3176bf2 \
    "packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/define.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/json.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts b/packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts
--- a/packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts
+++ b/packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts
@@ -10,8 +10,8 @@ async function createAssetImportMetaurlPluginTransform() {
   const environment = new PartialEnvironment('client', config)
 
   return async (code: string) => {
-    // @ts-expect-error transform should exist
-    const result = await instance.transform.call(
+    // @ts-expect-error transform.handler should exist
+    const result = await instance.transform.handler.call(
       { environment, parse: parseAst },
       code,
       'foo.ts',
diff --git a/packages/vite/src/node/__tests__/plugins/define.spec.ts b/packages/vite/src/node/__tests__/plugins/define.spec.ts
--- a/packages/vite/src/node/__tests__/plugins/define.spec.ts
+++ b/packages/vite/src/node/__tests__/plugins/define.spec.ts
@@ -16,8 +16,8 @@ async function createDefinePluginTransform(
   const environment = new PartialEnvironment(ssr ? 'ssr' : 'client', config)
 
   return async (code: string) => {
-    // @ts-expect-error transform should exist
-    const result = await instance.transform.call(
+    // @ts-expect-error transform.handler should exist
+    const result = await instance.transform.handler.call(
       { environment },
       code,
       'foo.ts',
diff --git a/packages/vite/src/node/__tests__/plugins/json.spec.ts b/packages/vite/src/node/__tests__/plugins/json.spec.ts
--- a/packages/vite/src/node/__tests__/plugins/json.spec.ts
+++ b/packages/vite/src/node/__tests__/plugins/json.spec.ts
@@ -36,7 +36,8 @@ describe('transform', () => {
     isBuild: boolean,
   ) => {
     const plugin = jsonPlugin(opts, isBuild)
-    return (plugin.transform! as Function)(input, 'test.json').code
+    // @ts-expect-error transform.handler should exist
+    return plugin.transform.handler(input, 'test.json').code
   }
 
   test("namedExports: true, stringify: 'auto' should not transformed an array input", () => {
diff --git a/packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts b/packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts
--- a/packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts
+++ b/packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts
@@ -10,8 +10,8 @@ async function createWorkerImportMetaUrlPluginTransform() {
   const environment = new PartialEnvironment('client', config)
 
   return async (code: string) => {
-    // @ts-expect-error transform should exist
-    const result = await instance.transform.call(
+    // @ts-expect-error transform.handler should exist
+    const result = await instance.transform.handler.call(
       { environment, parse: parseAst },
       code,
       'foo.ts',
EOF_114329324912

# Execute the target test files using pnpm test-unit with specific file paths
# Running all 4 test files in a single command to optimize execution
pnpm run test-unit \
    packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts \
    packages/vite/src/node/__tests__/plugins/define.spec.ts \
    packages/vite/src/node/__tests__/plugins/json.spec.ts \
    packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts

# Capture exit code
rc=$?

# Echo exit code for test result evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 95424b26892b005f438169d0ea426cb1a3176bf2 \
    "packages/vite/src/node/__tests__/plugins/assetImportMetaUrl.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/define.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/json.spec.ts" \
    "packages/vite/src/node/__tests__/plugins/workerImportMetaUrl.spec.ts"