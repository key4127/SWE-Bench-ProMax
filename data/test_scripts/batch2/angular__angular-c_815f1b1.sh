#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9c835e89fea7267bb03313234016c1043bc7cfad \
  "packages/core/test/acceptance/profiler_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/profiler_spec.ts b/packages/core/test/acceptance/profiler_spec.ts
--- a/packages/core/test/acceptance/profiler_spec.ts
+++ b/packages/core/test/acceptance/profiler_spec.ts
@@ -13,6 +13,7 @@ import {TestBed} from '@angular/core/testing';
 import {
   AfterContentChecked,
   AfterContentInit,
+  afterRender,
   AfterViewChecked,
   AfterViewInit,
   Component,
@@ -28,14 +29,14 @@ import {
 } from '../../src/core';
 
 describe('profiler', () => {
-  class Profiler {
+  class TestProfiler {
     profile() {}
   }
 
   let profilerSpy: jasmine.Spy;
 
   beforeEach(() => {
-    const profiler = new Profiler();
+    const profiler = new TestProfiler();
     profilerSpy = spyOn(profiler, 'profile').and.callThrough();
     setProfiler(profiler.profile);
   });
@@ -400,27 +401,146 @@ describe('profiler', () => {
       expect(serviceNgOnDestroyStart).toBeTruthy();
       expect(serviceNgOnDestroyEnd).toBeTruthy();
     });
+
+    it('should call the profiler on lifecycle execution even after error', () => {
+      @Component({selector: 'my-comp', template: '', standalone: false})
+      class MyComponent implements OnInit {
+        ngOnInit() {
+          throw new Error();
+        }
+      }
+
+      TestBed.configureTestingModule({declarations: [MyComponent]});
+      const fixture = TestBed.createComponent(MyComponent);
+
+      expect(() => {
+        fixture.detectChanges();
+      }).toThrow();
+
+      const lifecycleStart = findProfilerCall(ProfilerEvent.LifecycleHookStart);
+      const lifecycleEnd = findProfilerCall(ProfilerEvent.LifecycleHookEnd);
+
+      expect(lifecycleStart).toBeTruthy();
+      expect(lifecycleEnd).toBeTruthy();
+    });
   });
 
-  it('should call the profiler on lifecycle execution even after error', () => {
-    @Component({selector: 'my-comp', template: '', standalone: false})
-    class MyComponent implements OnInit {
-      ngOnInit() {
-        throw new Error();
+  describe('entry point events', () => {
+    class EventRecordingProfiler {
+      events: ProfilerEvent[] = [];
+
+      clearEvents() {
+        this.events.length = 0;
       }
+
+      hasEvents(...events: ProfilerEvent[]): boolean {
+        for (const e of events) {
+          if (this.events.indexOf(e) === -1) {
+            return false;
+          }
+        }
+
+        return true;
+      }
+
+      profile = (
+        event: ProfilerEvent,
+        instance?: {} | null,
+        hookOrListener?: (e?: any) => any,
+      ): void => {
+        this.events.push(event);
+      };
     }
 
-    TestBed.configureTestingModule({declarations: [MyComponent]});
-    const fixture = TestBed.createComponent(MyComponent);
+    let p: EventRecordingProfiler;
 
-    expect(() => {
+    beforeEach(() => {
+      p = new EventRecordingProfiler();
+      setProfiler(p.profile);
+    });
+
+    afterEach(() => {
+      setProfiler(null);
+    });
+
+    it('should capture component creation and change detection entry points', () => {
+      @Component({selector: 'my-comp', template: ''})
+      class MyComponent {}
+
+      const fixture = TestBed.createComponent(MyComponent);
+      expect(p.events).toEqual([
+        ProfilerEvent.DynamicComponentStart,
+        ProfilerEvent.ComponentStart,
+        ProfilerEvent.TemplateCreateStart,
+        ProfilerEvent.TemplateCreateEnd,
+        ProfilerEvent.ComponentEnd,
+        ProfilerEvent.DynamicComponentEnd,
+        ProfilerEvent.ChangeDetectionStart,
+        ProfilerEvent.ChangeDetectionSyncStart,
+        ProfilerEvent.ChangeDetectionSyncEnd,
+        ProfilerEvent.ChangeDetectionEnd,
+      ]);
+
+      p.clearEvents();
+      fixture.detectChanges(false);
+
+      expect(
+        p.hasEvents(ProfilerEvent.TemplateUpdateStart, ProfilerEvent.TemplateUpdateEnd),
+      ).toBeTrue();
+    });
+
+    it('should invoke a profiler when host bindings are evaluated', () => {
+      @Component({
+        selector: 'my-comp',
+        host: {
+          '[id]': '"someId"',
+        },
+        template: '',
+      })
+      class MyComponent {}
+
+      const fixture = TestBed.createComponent(MyComponent);
+      fixture.detectChanges();
+
+      expect(
+        p.hasEvents(ProfilerEvent.HostBindingsUpdateStart, ProfilerEvent.HostBindingsUpdateEnd),
+      ).toBeTrue();
+    });
+
+    it('should invoke a profiler when after render hooks are executing', () => {
+      @Component({
+        selector: 'my-comp',
+        template: '',
+      })
+      class MyComponent {
+        arRef = afterRender(() => {});
+      }
+
+      const fixture = TestBed.createComponent(MyComponent);
       fixture.detectChanges();
-    }).toThrow();
 
-    const lifecycleStart = findProfilerCall(ProfilerEvent.LifecycleHookStart);
-    const lifecycleEnd = findProfilerCall(ProfilerEvent.LifecycleHookEnd);
+      expect(
+        p.hasEvents(ProfilerEvent.AfterRenderHooksStart, ProfilerEvent.AfterRenderHooksEnd),
+      ).toBeTrue();
+    });
 
-    expect(lifecycleStart).toBeTruthy();
-    expect(lifecycleEnd).toBeTruthy();
+    it('should invoke a profiler when defer block transitions between states', () => {
+      @Component({
+        selector: 'my-comp',
+        template: `
+          @defer (on immediate) {
+            nothing to see here...
+          } 
+        `,
+      })
+      class MyComponent {}
+
+      const fixture = TestBed.createComponent(MyComponent);
+      fixture.detectChanges();
+
+      expect(
+        p.hasEvents(ProfilerEvent.DeferBlockStateStart, ProfilerEvent.DeferBlockStateEnd),
+      ).toBeTrue();
+    });
   });
 });
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export NODE_OPTIONS=--max-old-space-size=4096

# Run the acceptance test suite using Bazel
# Note: profiler_spec.ts is part of the acceptance test suite
# There is no separate target for profiler tests, so we run the full acceptance suite
# The test patch is applied to profiler_spec.ts, so if tests pass, the patch is validated
bazelisk test \
  //packages/core/test/acceptance:acceptance \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9c835e89fea7267bb03313234016c1043bc7cfad \
  "packages/core/test/acceptance/profiler_spec.ts"