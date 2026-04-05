#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 0b07780323a6e57e1f7b039cd6e7031011267f17 "packages/common/test/pipes/file/file-type.validator.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/common/test/pipes/file/file-type.validator.spec.ts b/packages/common/test/pipes/file/file-type.validator.spec.ts
--- a/packages/common/test/pipes/file/file-type.validator.spec.ts
+++ b/packages/common/test/pipes/file/file-type.validator.spec.ts
@@ -4,7 +4,7 @@ import { FileTypeValidator } from '../../../pipes';
 
 describe('FileTypeValidator', () => {
   describe('isValid', () => {
-    it('should return true when the file buffer matches the specified type', async () => {
+    it('should return true when the file buffer matches the specified type', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
@@ -17,10 +17,10 @@ describe('FileTypeValidator', () => {
         buffer: jpegBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should return true when the file buffer matches the specified file extension', async () => {
+    it('should return true when the file buffer matches the specified file extension', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'jpeg',
       });
@@ -32,10 +32,10 @@ describe('FileTypeValidator', () => {
         mimetype: 'image/jpeg',
         buffer: jpegBuffer,
       } as IFile;
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should return true when the file buffer matches the specified regexp', async () => {
+    it('should return true when the file buffer matches the specified regexp', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: /^image\//,
       });
@@ -48,10 +48,10 @@ describe('FileTypeValidator', () => {
         buffer: jpegBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should return false when the file buffer does not match the specified type', async () => {
+    it('should return false when the file buffer does not match the specified type', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
@@ -64,10 +64,10 @@ describe('FileTypeValidator', () => {
         buffer: pngBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
 
-    it('should return false when the file buffer does not match the specified file extension', async () => {
+    it('should return false when the file buffer does not match the specified file extension', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'jpeg',
       });
@@ -80,10 +80,10 @@ describe('FileTypeValidator', () => {
         buffer: pngBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
 
-    it('should return false when no buffer is provided', async () => {
+    it('should return false when no buffer is provided', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
@@ -92,18 +92,18 @@ describe('FileTypeValidator', () => {
         mimetype: 'image/jpeg',
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
 
-    it('should return false when no file is provided', async () => {
+    it('should return false when no file is provided', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
 
-      expect(await fileTypeValidator.isValid()).to.equal(false);
+      expect(fileTypeValidator.isValid()).to.equal(false);
     });
 
-    it('should return false when no buffer is provided', async () => {
+    it('should return false when no buffer is provided', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
@@ -112,10 +112,10 @@ describe('FileTypeValidator', () => {
         mimetype: 'image/jpeg',
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
 
-    it('should return true when the file buffer matches the specified regexp', async () => {
+    it('should return true when the file buffer matches the specified regexp', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: /^image\//,
       });
@@ -128,10 +128,10 @@ describe('FileTypeValidator', () => {
         buffer: jpegBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should return true when no validation options are provided', async () => {
+    it('should return true when no validation options are provided', () => {
       const fileTypeValidator = new FileTypeValidator({} as any);
       const jpegBuffer = Buffer.from([
         0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46,
@@ -141,10 +141,10 @@ describe('FileTypeValidator', () => {
         buffer: jpegBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should skip magic numbers validation when the skipMagicNumbersValidation is true', async () => {
+    it('should skip magic numbers validation when the skipMagicNumbersValidation is true', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
         skipMagicNumbersValidation: true,
@@ -154,10 +154,10 @@ describe('FileTypeValidator', () => {
         mimetype: 'image/jpeg',
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(true);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(true);
     });
 
-    it('should return false when the file buffer does not match any known type', async () => {
+    it('should return false when the file buffer does not match any known type', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'unknown/type',
       });
@@ -170,10 +170,10 @@ describe('FileTypeValidator', () => {
         buffer: unknownBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
 
-    it('should return false when the buffer is empty', async () => {
+    it('should return false when the buffer is empty', () => {
       const fileTypeValidator = new FileTypeValidator({
         fileType: 'image/jpeg',
       });
@@ -184,7 +184,7 @@ describe('FileTypeValidator', () => {
         buffer: emptyBuffer,
       } as IFile;
 
-      expect(await fileTypeValidator.isValid(requestFile)).to.equal(false);
+      expect(fileTypeValidator.isValid(requestFile)).to.equal(false);
     });
   });
 
EOF_114329324912

# Execute the target test file using Mocha with required configurations
# Using the exact command structure identified by the context retrieval agent
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

# Restore the original test file
git checkout 0b07780323a6e57e1f7b039cd6e7031011267f17 "packages/common/test/pipes/file/file-type.validator.spec.ts"