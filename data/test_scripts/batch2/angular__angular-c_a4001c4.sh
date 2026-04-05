#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb directly for headless browser testing
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
sleep 2

# Checkout the original test file to ensure clean state
git checkout 464bff95ef56239361db1e54bdb54d9b937281c9 "packages/core/test/acceptance/animation_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/animation_spec.ts b/packages/core/test/acceptance/animation_spec.ts
--- a/packages/core/test/acceptance/animation_spec.ts
+++ b/packages/core/test/acceptance/animation_spec.ts
@@ -11,6 +11,7 @@ import {ViewEncapsulation} from '@angular/compiler';
 import {
   AnimationCallbackEvent,
   Component,
+  computed,
   Directive,
   ElementRef,
   NgModule,
@@ -1539,5 +1540,66 @@ describe('Animation', () => {
       expect(fixture.debugElement.queryAll(By.css('p.slide-in')).length).toBe(1);
       expect(fixture.debugElement.queryAll(By.css('p')).length).toBe(4);
     }));
+
+    it('should only remove one element in reactive `@for` loops when removing the second to last item', fakeAsync(() => {
+      const animateStyles = `
+        .fade {
+          animation: fade-out 500ms;
+        }
+        @keyframes fade-out {
+          from {
+            opacity: 1;
+          }
+          to {
+            opacity: 0;
+          }
+        }
+      `;
+
+      @Component({
+        selector: 'test-cmp',
+        styles: animateStyles,
+        template: `
+          <div>
+            @for (item of shown(); track item) {
+              <p animate.leave="fade" #el>I should slide in {{item}}.</p>
+            }
+          </div>
+        `,
+        encapsulation: ViewEncapsulation.None,
+      })
+      class TestComponent {
+        items = signal([1, 2, 3, 4, 5, 6]);
+        shown = computed(() => this.items().slice(0, 3));
+        @ViewChild('el', {read: ElementRef}) el!: ElementRef<HTMLParagraphElement>;
+        max = 6;
+
+        removeSecondToLast() {
+          this.items.update((old) => {
+            const newList = [...old];
+            newList.splice(1, 1);
+            return newList;
+          });
+        }
+      }
+      TestBed.configureTestingModule({animationsEnabled: true});
+
+      const fixture = TestBed.createComponent(TestComponent);
+      const cmp = fixture.componentInstance;
+      fixture.detectChanges();
+      cmp.removeSecondToLast();
+      fixture.detectChanges();
+      tickAnimationFrames(1);
+
+      expect(fixture.debugElement.queryAll(By.css('p.fade')).length).toBe(1);
+      expect(fixture.debugElement.queryAll(By.css('p')).length).toBe(4);
+      fixture.debugElement
+        .query(By.css('p.fade'))
+        .nativeElement.dispatchEvent(
+          new AnimationEvent('animationend', {animationName: 'fade-out'}),
+        );
+      tick();
+      expect(fixture.debugElement.queryAll(By.css('p')).length).toBe(3);
+    }));
   });
 });
EOF_114329324912

# Execute the test target using Bazel
# Run the acceptance_web tests which include animation_spec.ts in a browser environment
# Using --test_output=errors to show only failures for cleaner output
pnpm bazel test //packages/core/test/acceptance:acceptance_web --test_output=errors

rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 464bff95ef56239361db1e54bdb54d9b937281c9 "packages/core/test/acceptance/animation_spec.ts"