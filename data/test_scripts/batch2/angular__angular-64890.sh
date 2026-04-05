#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 058377ed5547e58f4b9f058397fda22e5d347f38 "packages/router/test/recognize.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/router/test/recognize.spec.ts b/packages/router/test/recognize.spec.ts
--- a/packages/router/test/recognize.spec.ts
+++ b/packages/router/test/recognize.spec.ts
@@ -650,14 +650,49 @@ describe('recognize', () => {
         const s = await recognizer('foo/a/b/c/bar');
         checkActivatedRoute(s.root.firstChild!, 'foo/a/b/c/bar', {}, ComponentA);
       });
-      it('does not match a url with no segments for the wildcard', async () => {
-        await expectAsync(recognizer('foo/bar')).toBeRejected();
+      it('matches a url with no segments for the wildcard', async () => {
+        const s = await recognizer('foo/bar');
+        checkActivatedRoute(s.root.firstChild!, 'foo/bar', {}, ComponentA);
       });
 
       it('does not match a url with a wrong suffix', async () => {
         await expectAsync(recognizer('foo/a/b/baz')).toBeRejected();
       });
     });
+
+    describe('with prefix', () => {
+      const recognizer = (url: string) => {
+        const config = [{path: 'foo/**', component: ComponentA}];
+        return recognize(config, url);
+      };
+
+      it('matches a url with segments after the prefix', async () => {
+        const s = await recognizer('foo/a/b');
+        checkActivatedRoute(s.root.firstChild!, 'foo/a/b', {}, ComponentA);
+      });
+
+      it('matches a url with no segments after the prefix', async () => {
+        const s = await recognizer('foo');
+        checkActivatedRoute(s.root.firstChild!, 'foo', {}, ComponentA);
+      });
+    });
+
+    describe('with suffix', () => {
+      const recognizer = (url: string) => {
+        const config = [{path: '**/bar', component: ComponentA}];
+        return recognize(config, url);
+      };
+
+      it('matches a url with segments before the suffix', async () => {
+        const s = await recognizer('a/b/bar');
+        checkActivatedRoute(s.root.firstChild!, 'a/b/bar', {}, ComponentA);
+      });
+
+      it('matches a url with no segments before the suffix', async () => {
+        const s = await recognizer('bar');
+        checkActivatedRoute(s.root.firstChild!, 'bar', {}, ComponentA);
+      });
+    });
   });
 
   describe('componentless routes', () => {
@@ -877,6 +912,52 @@ describe('recognize', () => {
       expect(s.root.firstChild!.data['id']).toEqual('b');
     });
   });
+
+  describe('with required param before wildcard', () => {
+    const recognizer = (url: string) => {
+      const config = [
+        {
+          path: 'foo/:anyRequired/**/bar',
+          component: ComponentA,
+        },
+      ];
+      return recognize(config, url);
+    };
+
+    it('matches with one segment for wildcard', async () => {
+      const s = await recognizer('foo/required/a/bar');
+      checkActivatedRoute(
+        s.root.firstChild!,
+        'foo/required/a/bar',
+        {anyRequired: 'required'},
+        ComponentA,
+      );
+    });
+
+    it('matches with multiple segments for wildcard', async () => {
+      const s = await recognizer('foo/required/a/b/c/bar');
+      checkActivatedRoute(
+        s.root.firstChild!,
+        'foo/required/a/b/c/bar',
+        {anyRequired: 'required'},
+        ComponentA,
+      );
+    });
+
+    it('matches with no segments for wildcard', async () => {
+      const s = await recognizer('foo/required/bar');
+      checkActivatedRoute(
+        s.root.firstChild!,
+        'foo/required/bar',
+        {anyRequired: 'required'},
+        ComponentA,
+      );
+    });
+
+    it('does not match without the required segment', async () => {
+      await expectAsync(recognizer('foo/bar')).toBeRejected();
+    });
+  });
 });
 
 async function recognize(
EOF_114329324912

# Execute the specific test target using Bazel
# Using the primary Bazel target as identified in the context retrieval
bazel test //packages/router/test:test_web --test_output=all
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 058377ed5547e58f4b9f058397fda22e5d347f38 "packages/router/test/recognize.spec.ts"