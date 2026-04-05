#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 8bccd8671cc9dbb222dbf0181c6d376e92aee734 "packages/router/test/with_platform_navigation.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/router/test/with_platform_navigation.spec.ts b/packages/router/test/with_platform_navigation.spec.ts
--- a/packages/router/test/with_platform_navigation.spec.ts
+++ b/packages/router/test/with_platform_navigation.spec.ts
@@ -8,7 +8,7 @@
 
 import {TestBed} from '@angular/core/testing';
 import {provideRouter, Router} from '../src';
-import {withPlatformNavigation} from '../src/provide_router';
+import {withPlatformNavigation, withRouterConfig} from '../src/provide_router';
 import {withBody} from '@angular/private/testing';
 import {
   PlatformLocation,
@@ -21,7 +21,7 @@ import {
   ɵFakeNavigationPlatformLocation as FakeNavigationPlatformLocation,
   provideLocationMocks,
 } from '@angular/common/testing';
-import {EnvironmentInjector} from '@angular/core';
+import {timeout, useAutoTick} from './helpers';
 
 /// <reference types="dom-navigation" />
 
@@ -86,6 +86,74 @@ describe('withPlatformNavigation feature', () => {
       expect(changed).toBeTrue();
     });
   });
+
+  describe('NavigateEvent and NavigationTransition', () => {
+    useAutoTick();
+
+    let router: Router;
+    beforeEach(() => {
+      router = TestBed.inject(Router);
+      router.initialNavigation();
+    });
+
+    it('should keep non-router triggered navigation unfinished while waiting for guards', async () => {
+      router.resetConfig([
+        {
+          path: '**',
+          canActivate: [
+            () => new Promise<boolean>((resolve) => setTimeout(() => resolve(true), 10)),
+          ],
+          children: [],
+        },
+      ]);
+      const {finished} = TestBed.inject(PlatformNavigation).navigate('/somepath');
+      await timeout(5);
+      // note that this finished promise will be rejected because the Router will create a separate 'replace' navigate
+      // since we cannot redirect the original navigation without precommit handler support
+      await expectAsync(finished).not.toBeResolved();
+      expect(TestBed.inject(PlatformNavigation).transition).not.toBeNull();
+      await timeout(10);
+      expect(TestBed.inject(PlatformNavigation).transition).toBeNull();
+    });
+  });
+
+  describe('eager url update', () => {
+    useAutoTick();
+    let router: Router;
+
+    beforeEach(() => {
+      TestBed.configureTestingModule({
+        providers: [
+          provideRouter(
+            [{path: '**', children: []}],
+            withPlatformNavigation(),
+            withRouterConfig({urlUpdateStrategy: 'eager'}),
+          ),
+        ],
+      });
+      router = TestBed.inject(Router);
+    });
+
+    it('should keep router triggered navigation unfinished while waiting for guards', async () => {
+      router.resetConfig([
+        {
+          path: '**',
+          canActivate: [
+            () => new Promise<boolean>((resolve) => setTimeout(() => resolve(true), 10)),
+          ],
+          children: [],
+        },
+      ]);
+      router.navigateByUrl('/somepath');
+      await timeout(5);
+      const navigation = TestBed.inject(PlatformNavigation);
+      const {finished} = navigation.transition!;
+      expect(navigation.transition).not.toBeNull();
+      await timeout(10);
+      expect(navigation.transition).toBeNull();
+      await expectAsync(finished).toBeResolved();
+    });
+  });
 });
 
 describe('configuration error', () => {
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# The //packages/router/test:test target runs Node.js zoneless tests
# This includes with_platform_navigation.spec.ts along with other router tests
# Using --test_output=streamed for verbose output to verify our test executes
pnpm bazel test //packages/router/test:test --test_output=streamed
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 8bccd8671cc9dbb222dbf0181c6d376e92aee734 "packages/router/test/with_platform_navigation.spec.ts"