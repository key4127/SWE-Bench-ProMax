#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ef37ecf444aff5e3a2f9cb6d2206ed7957b64ab4 "packages/forms/signals/test/node/resource.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/node/resource.spec.ts b/packages/forms/signals/test/node/resource.spec.ts
--- a/packages/forms/signals/test/node/resource.spec.ts
+++ b/packages/forms/signals/test/node/resource.spec.ts
@@ -15,7 +15,7 @@ import {
   applyEach,
   customError,
   form,
-  property,
+  metadata,
   required,
   schema,
   SchemaOrSchemaFn,
@@ -56,7 +56,7 @@ describe('resources', () => {
 
   it('Takes a simple resource which reacts to data changes', async () => {
     const s: SchemaOrSchemaFn<Cat> = function (p) {
-      const RES = property(p.name, ({value}) => {
+      const RES = metadata(p.name, ({value}) => {
         return resource({
           params: () => ({x: value()}),
           loader: async ({params}) => `got: ${params.x}`,
@@ -98,7 +98,7 @@ describe('resources', () => {
   it('should create a resource per entry in an array', async () => {
     const s: SchemaOrSchemaFn<Cat[]> = function (p) {
       applyEach(p, (p) => {
-        const RES = property(p.name, ({value}) => {
+        const RES = metadata(p.name, ({value}) => {
           return resource({
             params: () => ({x: value()}),
             loader: async ({params}) => `got: ${params.x}`,
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# The //packages/forms/signals/test/node:test target runs the Node.js-based resource tests
# Using --test_output=streamed for verbose output to verify test execution
pnpm bazel test //packages/forms/signals/test/node:test --test_output=streamed
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout ef37ecf444aff5e3a2f9cb6d2206ed7957b64ab4 "packages/forms/signals/test/node/resource.spec.ts"