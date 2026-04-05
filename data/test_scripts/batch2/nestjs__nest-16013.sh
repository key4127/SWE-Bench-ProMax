#!/bin/bash
set -uxo pipefail
cd /testbed

# Apply the test patch - it will modify all necessary files (test + implementation)
git apply -v - <<'EOF_114329324912'
diff --git a/packages/common/test/pipes/file/file-type.validator.spec.ts b/packages/common/test/pipes/file/file-type.validator.spec.ts
--- a/packages/common/test/pipes/file/file-type.validator.spec.ts
+++ b/packages/common/test/pipes/file/file-type.validator.spec.ts
@@ -233,6 +233,32 @@ describe('FileTypeValidator', () => {
 
       expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
+
+    it('should return true when no buffer is provided but fallbackToMimetype is enabled and mimetype matches', async () => {
+      const fileTypeValidator = new FileTypeValidator({
+        fileType: 'image/jpeg',
+        fallbackToMimetype: true,
+      });
+
+      const requestFile = {
+        mimetype: 'image/jpeg', // matches
+      } as IFile;
+
+      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+    });
+
+    it('should return false when no buffer is provided and fallbackToMimetype is enabled but mimetype does not match', async () => {
+      const fileTypeValidator = new FileTypeValidator({
+        fileType: 'image/jpeg',
+        fallbackToMimetype: true,
+      });
+
+      const requestFile = {
+        mimetype: 'image/png',
+      } as IFile;
+
+      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+    });
   });
 
   describe('buildErrorMessage', () => {
EOF_114329324912

# Rebuild the project since source code has changed
# This is critical because TypeScript needs to recompile with the new changes
npm run build

# Execute the target test file using Mocha with required configurations
npx mocha \
  --require ts-node/register \
  --require tsconfig-paths/register \
  --require reflect-metadata/Reflect.js \
  --require hooks/mocha-init-hook.ts \
  --exit \
  packages/common/test/pipes/file/file-type.validator.spec.ts

# Capture the exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore all modified files to original state
git reset --hard 46183524c8b7687de3ce02864f23554df2d30585