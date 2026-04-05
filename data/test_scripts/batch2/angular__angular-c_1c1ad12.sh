#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ad5fbd944dc1fdcf3721fd1bc45ba2929d264bd2 \
  "packages/core/test/application_ref_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/testing/src/application_error_handler.ts" \
  "packages/core/testing/src/test_bed_compiler.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/application_ref_spec.ts b/packages/core/test/application_ref_spec.ts
--- a/packages/core/test/application_ref_spec.ts
+++ b/packages/core/test/application_ref_spec.ts
@@ -15,6 +15,7 @@ import {
   Compiler,
   CompilerFactory,
   Component,
+  effect,
   EnvironmentInjector,
   InjectionToken,
   Injector,
@@ -812,195 +813,197 @@ describe('bootstrap', () => {
 });
 
 describe('AppRef', () => {
-  @Component({
-    selector: 'sync-comp',
-    template: `<span>{{text}}</span>`,
-    standalone: false,
-  })
-  class SyncComp {
-    text: string = '1';
-  }
-
-  @Component({
-    selector: 'click-comp',
-    template: `<span (click)="onClick()">{{text}}</span>`,
-    standalone: false,
-  })
-  class ClickComp {
-    text: string = '1';
-
-    onClick() {
-      this.text += '1';
+  describe('stability', () => {
+    @Component({
+      selector: 'sync-comp',
+      template: `<span>{{text}}</span>`,
+      standalone: false,
+    })
+    class SyncComp {
+      text: string = '1';
     }
-  }
 
-  @Component({
-    selector: 'micro-task-comp',
-    template: `<span>{{text}}</span>`,
-    standalone: false,
-  })
-  class MicroTaskComp {
-    text: string = '1';
+    @Component({
+      selector: 'click-comp',
+      template: `<span (click)="onClick()">{{text}}</span>`,
+      standalone: false,
+    })
+    class ClickComp {
+      text: string = '1';
 
-    ngOnInit() {
-      Promise.resolve(null).then((_) => {
+      onClick() {
         this.text += '1';
-      });
+      }
     }
-  }
 
-  @Component({
-    selector: 'macro-task-comp',
-    template: `<span>{{text}}</span>`,
-    standalone: false,
-  })
-  class MacroTaskComp {
-    text: string = '1';
+    @Component({
+      selector: 'micro-task-comp',
+      template: `<span>{{text}}</span>`,
+      standalone: false,
+    })
+    class MicroTaskComp {
+      text: string = '1';
 
-    ngOnInit() {
-      setTimeout(() => {
-        this.text += '1';
-      }, 10);
+      ngOnInit() {
+        Promise.resolve(null).then((_) => {
+          this.text += '1';
+        });
+      }
     }
-  }
 
-  @Component({
-    selector: 'micro-macro-task-comp',
-    template: `<span>{{text}}</span>`,
-    standalone: false,
-  })
-  class MicroMacroTaskComp {
-    text: string = '1';
+    @Component({
+      selector: 'macro-task-comp',
+      template: `<span>{{text}}</span>`,
+      standalone: false,
+    })
+    class MacroTaskComp {
+      text: string = '1';
 
-    ngOnInit() {
-      Promise.resolve(null).then((_) => {
-        this.text += '1';
+      ngOnInit() {
         setTimeout(() => {
           this.text += '1';
         }, 10);
-      });
+      }
     }
-  }
 
-  @Component({
-    selector: 'macro-micro-task-comp',
-    template: `<span>{{text}}</span>`,
-    standalone: false,
-  })
-  class MacroMicroTaskComp {
-    text: string = '1';
+    @Component({
+      selector: 'micro-macro-task-comp',
+      template: `<span>{{text}}</span>`,
+      standalone: false,
+    })
+    class MicroMacroTaskComp {
+      text: string = '1';
 
-    ngOnInit() {
-      setTimeout(() => {
-        this.text += '1';
-        Promise.resolve(null).then((_: any) => {
+      ngOnInit() {
+        Promise.resolve(null).then((_) => {
           this.text += '1';
+          setTimeout(() => {
+            this.text += '1';
+          }, 10);
         });
-      }, 10);
+      }
     }
-  }
 
-  let stableCalled = false;
+    @Component({
+      selector: 'macro-micro-task-comp',
+      template: `<span>{{text}}</span>`,
+      standalone: false,
+    })
+    class MacroMicroTaskComp {
+      text: string = '1';
 
-  beforeEach(() => {
-    stableCalled = false;
-    TestBed.configureTestingModule({
-      providers: [provideZoneChangeDetection({ignoreChangesOutsideZone: true})],
-      declarations: [
-        SyncComp,
-        MicroTaskComp,
-        MacroTaskComp,
-        MicroMacroTaskComp,
-        MacroMicroTaskComp,
-        ClickComp,
-      ],
-    });
-  });
+      ngOnInit() {
+        setTimeout(() => {
+          this.text += '1';
+          Promise.resolve(null).then((_: any) => {
+            this.text += '1';
+          });
+        }, 10);
+      }
+    }
 
-  afterEach(() => {
-    expect(stableCalled).toBe(true, 'isStable did not emit true on stable');
-  });
+    let stableCalled = false;
 
-  function expectStableTexts(component: Type<any>, expected: string[]) {
-    const fixture = TestBed.createComponent(component);
-    const appRef: ApplicationRef = TestBed.inject(ApplicationRef);
-    const zone: NgZone = TestBed.inject(NgZone);
-    appRef.attachView(fixture.componentRef.hostView);
-    zone.run(() => appRef.tick());
-
-    let i = 0;
-    appRef.isStable.subscribe({
-      next: (stable: boolean) => {
-        if (stable) {
-          expect(i).toBeLessThan(expected.length);
-          expect(fixture.nativeElement).toHaveText(expected[i++]);
-          stableCalled = true;
-        }
-      },
+    beforeEach(() => {
+      stableCalled = false;
+      TestBed.configureTestingModule({
+        providers: [provideZoneChangeDetection({ignoreChangesOutsideZone: true})],
+        declarations: [
+          SyncComp,
+          MicroTaskComp,
+          MacroTaskComp,
+          MicroMacroTaskComp,
+          MacroMicroTaskComp,
+          ClickComp,
+        ],
+      });
     });
-  }
-
-  it('isStable should fire on synchronous component loading', waitForAsync(() => {
-    expectStableTexts(SyncComp, ['1']);
-  }));
-
-  it('isStable should fire after a microtask on init is completed', waitForAsync(() => {
-    expectStableTexts(MicroTaskComp, ['11']);
-  }));
-
-  it('isStable should fire after a macrotask on init is completed', waitForAsync(() => {
-    expectStableTexts(MacroTaskComp, ['11']);
-  }));
-
-  it('isStable should fire only after chain of micro and macrotasks on init are completed', waitForAsync(() => {
-    expectStableTexts(MicroMacroTaskComp, ['111']);
-  }));
-
-  it('isStable should fire only after chain of macro and microtasks on init are completed', waitForAsync(() => {
-    expectStableTexts(MacroMicroTaskComp, ['111']);
-  }));
-
-  it('isStable can be subscribed to many times', async () => {
-    const appRef: ApplicationRef = TestBed.inject(ApplicationRef);
-    // Create stable subscription but do not unsubscribe before the second subscription is made
-    appRef.isStable.subscribe();
-    await expectAsync(appRef.isStable.pipe(take(1)).toPromise()).toBeResolved();
-    stableCalled = true;
-  });
-
-  describe('unstable', () => {
-    let unstableCalled = false;
 
     afterEach(() => {
-      expect(unstableCalled).toBe(true, 'isStable did not emit false on unstable');
+      expect(stableCalled).toBe(true, 'isStable did not emit true on stable');
     });
 
-    function expectUnstable(appRef: ApplicationRef) {
+    function expectStableTexts(component: Type<any>, expected: string[]) {
+      const fixture = TestBed.createComponent(component);
+      const appRef: ApplicationRef = TestBed.inject(ApplicationRef);
+      const zone: NgZone = TestBed.inject(NgZone);
+      appRef.attachView(fixture.componentRef.hostView);
+      zone.run(() => appRef.tick());
+
+      let i = 0;
       appRef.isStable.subscribe({
         next: (stable: boolean) => {
           if (stable) {
+            expect(i).toBeLessThan(expected.length);
+            expect(fixture.nativeElement).toHaveText(expected[i++]);
             stableCalled = true;
           }
-          if (!stable) {
-            unstableCalled = true;
-          }
         },
       });
     }
 
-    it('should be fired after app becomes unstable', waitForAsync(() => {
-      const fixture = TestBed.createComponent(ClickComp);
+    it('isStable should fire on synchronous component loading', waitForAsync(() => {
+      expectStableTexts(SyncComp, ['1']);
+    }));
+
+    it('isStable should fire after a microtask on init is completed', waitForAsync(() => {
+      expectStableTexts(MicroTaskComp, ['11']);
+    }));
+
+    it('isStable should fire after a macrotask on init is completed', waitForAsync(() => {
+      expectStableTexts(MacroTaskComp, ['11']);
+    }));
+
+    it('isStable should fire only after chain of micro and macrotasks on init are completed', waitForAsync(() => {
+      expectStableTexts(MicroMacroTaskComp, ['111']);
+    }));
+
+    it('isStable should fire only after chain of macro and microtasks on init are completed', waitForAsync(() => {
+      expectStableTexts(MacroMicroTaskComp, ['111']);
+    }));
+
+    it('isStable can be subscribed to many times', async () => {
       const appRef: ApplicationRef = TestBed.inject(ApplicationRef);
-      const zone: NgZone = TestBed.inject(NgZone);
-      appRef.attachView(fixture.componentRef.hostView);
-      zone.run(() => appRef.tick());
+      // Create stable subscription but do not unsubscribe before the second subscription is made
+      appRef.isStable.subscribe();
+      await expectAsync(appRef.isStable.pipe(take(1)).toPromise()).toBeResolved();
+      stableCalled = true;
+    });
 
-      fixture.whenStable().then(() => {
-        expectUnstable(appRef);
-        const element = fixture.debugElement.children[0];
-        dispatchEvent(element.nativeElement, 'click');
+    describe('unstable', () => {
+      let unstableCalled = false;
+
+      afterEach(() => {
+        expect(unstableCalled).toBe(true, 'isStable did not emit false on unstable');
       });
-    }));
+
+      function expectUnstable(appRef: ApplicationRef) {
+        appRef.isStable.subscribe({
+          next: (stable: boolean) => {
+            if (stable) {
+              stableCalled = true;
+            }
+            if (!stable) {
+              unstableCalled = true;
+            }
+          },
+        });
+      }
+
+      it('should be fired after app becomes unstable', waitForAsync(() => {
+        const fixture = TestBed.createComponent(ClickComp);
+        const appRef: ApplicationRef = TestBed.inject(ApplicationRef);
+        const zone: NgZone = TestBed.inject(NgZone);
+        appRef.attachView(fixture.componentRef.hostView);
+        zone.run(() => appRef.tick());
+
+        fixture.whenStable().then(() => {
+          expectUnstable(appRef);
+          const element = fixture.debugElement.children[0];
+          dispatchEvent(element.nativeElement, 'click');
+        });
+      }));
+    });
   });
 });
 
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -282,6 +282,7 @@
   "enterView",
   "eraseStyles",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeContentQueries",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -282,6 +282,7 @@
   "enterView",
   "epoch",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeContentQueries",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -334,6 +334,7 @@
   "enterView",
   "epoch",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeContentQueries",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -323,6 +323,7 @@
   "enterView",
   "epoch",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeContentQueries",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -241,6 +241,7 @@
   "enterDI",
   "enterView",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeInitAndCheckHooks",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -399,6 +399,7 @@
   "equalParamsAndUrlSegments",
   "equalPath",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "exactMatchOptions",
   "execFinalizer",
   "executeCheckHooks",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -210,6 +210,7 @@
   "enterDI",
   "enterView",
   "errorContext",
+  "errorHandlerEnvironmentInitializer",
   "execFinalizer",
   "executeCheckHooks",
   "executeInitAndCheckHooks",
diff --git a/packages/core/testing/src/application_error_handler.ts b/packages/core/testing/src/application_error_handler.ts
--- a/packages/core/testing/src/application_error_handler.ts
+++ b/packages/core/testing/src/application_error_handler.ts
@@ -6,19 +6,23 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {ErrorHandler, inject, NgZone, Injectable} from '../../src/core';
+import {ErrorHandler, inject, NgZone, Injectable, EnvironmentInjector} from '../../src/core';
 
 export const RETHROW_APPLICATION_ERRORS_DEFAULT = true;
 
 @Injectable()
 export class TestBedApplicationErrorHandler {
   private readonly zone = inject(NgZone);
-  private readonly userErrorHandler = inject(ErrorHandler);
+  private readonly injector = inject(EnvironmentInjector);
+  private userErrorHandler?: ErrorHandler;
   readonly whenStableRejectFunctions: Set<(e: unknown) => void> = new Set();
 
   handleError(e: unknown) {
     try {
-      this.zone.runOutsideAngular(() => this.userErrorHandler.handleError(e));
+      this.zone.runOutsideAngular(() => {
+        this.userErrorHandler ??= this.injector.get(ErrorHandler);
+        this.userErrorHandler.handleError(e);
+      });
     } catch (userError: unknown) {
       e = userError;
     }
diff --git a/packages/core/testing/src/test_bed_compiler.ts b/packages/core/testing/src/test_bed_compiler.ts
--- a/packages/core/testing/src/test_bed_compiler.ts
+++ b/packages/core/testing/src/test_bed_compiler.ts
@@ -65,6 +65,7 @@ import {
   ɵɵInjectableDeclaration as InjectableDeclaration,
   NgZone,
   ErrorHandler,
+  ENVIRONMENT_INITIALIZER,
 } from '../../src/core';
 
 import {ComponentDef, ComponentType} from '../../src/render3';
@@ -943,6 +944,13 @@ export class TestBedCompiler {
         internalProvideZoneChangeDetection({}),
         TestBedApplicationErrorHandler,
         {provide: ChangeDetectionScheduler, useExisting: ChangeDetectionSchedulerImpl},
+        {
+          provide: ENVIRONMENT_INITIALIZER,
+          multi: true,
+          useValue: () => {
+            inject(ErrorHandler);
+          },
+        },
       ],
     });
 
EOF_114329324912

# Run the unit test and all symbol extractor tests
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# Target for application_ref_spec.ts is //packages/core/test:test (jasmine_node_test)
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/core/test:test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/hydration:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/standalone_bootstrap:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout ad5fbd944dc1fdcf3721fd1bc45ba2929d264bd2 \
  "packages/core/test/application_ref_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/testing/src/application_error_handler.ts" \
  "packages/core/testing/src/test_bed_compiler.ts"