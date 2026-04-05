#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 0bb81c5ab4e869691c3bf2e87d2f2a17c3d9e53e "packages/core/test/acceptance/profiler_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/profiler_spec.ts b/packages/core/test/acceptance/profiler_spec.ts
--- a/packages/core/test/acceptance/profiler_spec.ts
+++ b/packages/core/test/acceptance/profiler_spec.ts
@@ -13,7 +13,6 @@ import {TestBed} from '@angular/core/testing';
 import {
   AfterContentChecked,
   AfterContentInit,
-  afterRender,
   AfterViewChecked,
   AfterViewInit,
   Component,
@@ -29,14 +28,14 @@ import {
 } from '../../src/core';
 
 describe('profiler', () => {
-  class TestProfiler {
+  class Profiler {
     profile() {}
   }
 
   let profilerSpy: jasmine.Spy;
 
   beforeEach(() => {
-    const profiler = new TestProfiler();
+    const profiler = new Profiler();
     profilerSpy = spyOn(profiler, 'profile').and.callThrough();
     setProfiler(profiler.profile);
   });
@@ -401,146 +400,27 @@ describe('profiler', () => {
       expect(serviceNgOnDestroyStart).toBeTruthy();
       expect(serviceNgOnDestroyEnd).toBeTruthy();
     });
-
-    it('should call the profiler on lifecycle execution even after error', () => {
-      @Component({selector: 'my-comp', template: '', standalone: false})
-      class MyComponent implements OnInit {
-        ngOnInit() {
-          throw new Error();
-        }
-      }
-
-      TestBed.configureTestingModule({declarations: [MyComponent]});
-      const fixture = TestBed.createComponent(MyComponent);
-
-      expect(() => {
-        fixture.detectChanges();
-      }).toThrow();
-
-      const lifecycleStart = findProfilerCall(ProfilerEvent.LifecycleHookStart);
-      const lifecycleEnd = findProfilerCall(ProfilerEvent.LifecycleHookEnd);
-
-      expect(lifecycleStart).toBeTruthy();
-      expect(lifecycleEnd).toBeTruthy();
-    });
   });
 
-  describe('entry point events', () => {
-    class EventRecordingProfiler {
-      events: ProfilerEvent[] = [];
-
-      clearEvents() {
-        this.events.length = 0;
+  it('should call the profiler on lifecycle execution even after error', () => {
+    @Component({selector: 'my-comp', template: '', standalone: false})
+    class MyComponent implements OnInit {
+      ngOnInit() {
+        throw new Error();
       }
-
-      hasEvents(...events: ProfilerEvent[]): boolean {
-        for (const e of events) {
-          if (this.events.indexOf(e) === -1) {
-            return false;
-          }
-        }
-
-        return true;
-      }
-
-      profile = (
-        event: ProfilerEvent,
-        instance?: {} | null,
-        hookOrListener?: (e?: any) => any,
-      ): void => {
-        this.events.push(event);
-      };
     }
 
-    let p: EventRecordingProfiler;
+    TestBed.configureTestingModule({declarations: [MyComponent]});
+    const fixture = TestBed.createComponent(MyComponent);
 
-    beforeEach(() => {
-      p = new EventRecordingProfiler();
-      setProfiler(p.profile);
-    });
-
-    afterEach(() => {
-      setProfiler(null);
-    });
-
-    it('should capture component creation and change detection entry points', () => {
-      @Component({selector: 'my-comp', template: ''})
-      class MyComponent {}
-
-      const fixture = TestBed.createComponent(MyComponent);
-      expect(p.events).toEqual([
-        ProfilerEvent.DynamicComponentStart,
-        ProfilerEvent.ComponentStart,
-        ProfilerEvent.TemplateCreateStart,
-        ProfilerEvent.TemplateCreateEnd,
-        ProfilerEvent.ComponentEnd,
-        ProfilerEvent.DynamicComponentEnd,
-        ProfilerEvent.ChangeDetectionStart,
-        ProfilerEvent.ChangeDetectionSyncStart,
-        ProfilerEvent.ChangeDetectionSyncEnd,
-        ProfilerEvent.ChangeDetectionEnd,
-      ]);
-
-      p.clearEvents();
-      fixture.detectChanges(false);
-
-      expect(
-        p.hasEvents(ProfilerEvent.TemplateUpdateStart, ProfilerEvent.TemplateUpdateEnd),
-      ).toBeTrue();
-    });
-
-    it('should invoke a profiler when host bindings are evaluated', () => {
-      @Component({
-        selector: 'my-comp',
-        host: {
-          '[id]': '"someId"',
-        },
-        template: '',
-      })
-      class MyComponent {}
-
-      const fixture = TestBed.createComponent(MyComponent);
-      fixture.detectChanges();
-
-      expect(
-        p.hasEvents(ProfilerEvent.HostBindingsUpdateStart, ProfilerEvent.HostBindingsUpdateEnd),
-      ).toBeTrue();
-    });
-
-    it('should invoke a profiler when after render hooks are executing', () => {
-      @Component({
-        selector: 'my-comp',
-        template: '',
-      })
-      class MyComponent {
-        arRef = afterRender(() => {});
-      }
-
-      const fixture = TestBed.createComponent(MyComponent);
+    expect(() => {
       fixture.detectChanges();
+    }).toThrow();
 
-      expect(
-        p.hasEvents(ProfilerEvent.AfterRenderHooksStart, ProfilerEvent.AfterRenderHooksEnd),
-      ).toBeTrue();
-    });
+    const lifecycleStart = findProfilerCall(ProfilerEvent.LifecycleHookStart);
+    const lifecycleEnd = findProfilerCall(ProfilerEvent.LifecycleHookEnd);
 
-    it('should invoke a profiler when defer block transitions between states', () => {
-      @Component({
-        selector: 'my-comp',
-        template: `
-          @defer (on immediate) {
-            nothing to see here...
-          } 
-        `,
-      })
-      class MyComponent {}
-
-      const fixture = TestBed.createComponent(MyComponent);
-      fixture.detectChanges();
-
-      expect(
-        p.hasEvents(ProfilerEvent.DeferBlockStateStart, ProfilerEvent.DeferBlockStateEnd),
-      ).toBeTrue();
-    });
+    expect(lifecycleStart).toBeTruthy();
+    expect(lifecycleEnd).toBeTruthy();
   });
 });
EOF_114329324912

# Run the test using Bazel
# The profiler_spec.ts is part of the //packages/core/test:test target
# Using bazelisk to ensure correct Bazel version management
bazelisk test \
  //packages/core/test:test \
  --test_output=errors \
  --flaky_test_attempts=1 \
  --jobs=4 \
  --test_filter="profiler"

# Capture the exit code from the test execution
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 0bb81c5ab4e869691c3bf2e87d2f2a17c3d9e53e "packages/core/test/acceptance/profiler_spec.ts"