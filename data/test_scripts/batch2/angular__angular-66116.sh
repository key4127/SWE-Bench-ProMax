#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9ad603fa115934568036a5fcc419e351b90ff810 "packages/forms/signals/test/web/field_directive.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/web/field_directive.spec.ts b/packages/forms/signals/test/web/field_directive.spec.ts
--- a/packages/forms/signals/test/web/field_directive.spec.ts
+++ b/packages/forms/signals/test/web/field_directive.spec.ts
@@ -545,6 +545,97 @@ describe('field directive', () => {
       });
     });
 
+    describe('pending', () => {
+      it('should bind to custom control', async () => {
+        const {promise, resolve} = promiseWithResolvers<ValidationError[]>();
+
+        @Component({
+          selector: 'custom-control',
+          template: '<input #i [value]="value()" (input)="value.set(i.value)" />',
+        })
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+          readonly pending = input.required<boolean>();
+        }
+
+        @Component({
+          template: ` <custom-control [field]="f" /> `,
+          imports: [CustomControl, Field],
+        })
+        class TestCmp {
+          readonly data = signal('test');
+          readonly f = form(this.data, (p) => {
+            validateAsync(p, {
+              params: () => [],
+              factory: (params) =>
+                resource({
+                  params,
+                  loader: () => promise,
+                }),
+              onSuccess: (results) => results,
+              onError: () => null,
+            });
+          });
+          readonly customControl = viewChild.required(CustomControl);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const comp = fixture.componentInstance;
+
+        expect(comp.customControl().pending()).toBe(true);
+
+        resolve([]);
+        await promise;
+        await fixture.whenStable();
+
+        expect(comp.customControl().pending()).toBe(false);
+      });
+
+      it('should be reset when field changes on custom control', async () => {
+        const {promise, resolve} = promiseWithResolvers<ValidationError[]>();
+
+        @Component({selector: 'custom-control', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+          readonly pending = input.required<boolean>();
+        }
+
+        @Component({
+          imports: [Field, CustomControl],
+          template: `<custom-control [field]="field()" />`,
+        })
+        class TestCmp {
+          readonly f = form(signal({x: '', y: ''}), (p) => {
+            validateAsync(p.x, {
+              params: () => [],
+              factory: (params) =>
+                resource({
+                  params,
+                  loader: () => promise,
+                }),
+              onSuccess: (results) => results,
+              onError: () => null,
+            });
+          });
+          readonly field = signal(this.f.x);
+          readonly customControl = viewChild.required(CustomControl);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const component = fixture.componentInstance;
+
+        expect(component.customControl().pending()).toBe(true);
+
+        act(() => component.field.set(component.f.y));
+        expect(component.customControl().pending()).toBe(false);
+
+        resolve([]);
+        await promise;
+        await fixture.whenStable();
+        expect(component.customControl().pending()).toBe(false);
+      });
+    });
+
     describe('readonly', () => {
       it('should bind to native control', () => {
         @Component({
@@ -2184,49 +2275,6 @@ describe('field directive', () => {
     });
   });
 
-  it('should synchronize pending status', async () => {
-    const {promise, resolve} = promiseWithResolvers<ValidationError[]>();
-
-    @Component({
-      selector: 'my-input',
-      template: '<input #i [value]="value()" (input)="value.set(i.value)" />',
-    })
-    class CustomInput implements FormValueControl<string> {
-      value = model('');
-      pending = input(false);
-    }
-
-    @Component({
-      template: ` <my-input [field]="f" /> `,
-      imports: [CustomInput, Field],
-    })
-    class PendingTestCmp {
-      myInput = viewChild.required<CustomInput>(CustomInput);
-      data = signal('test');
-      f = form(this.data, (p) => {
-        validateAsync(p, {
-          params: () => [],
-          factory: (params) =>
-            resource({
-              params,
-              loader: () => promise,
-            }),
-          onSuccess: (results) => results,
-          onError: () => null,
-        });
-      });
-    }
-
-    const fix = act(() => TestBed.createComponent(PendingTestCmp));
-
-    expect(fix.componentInstance.myInput().pending()).toBe(true);
-
-    resolve([]);
-    await promise;
-    await fix.whenStable();
-    expect(fix.componentInstance.myInput().pending()).toBe(false);
-  });
-
   it(`should mark field as touched on native control 'blur' event`, () => {
     @Component({
       imports: [Field],
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run the target test using Bazel
# Testing the specific test file: field_directive.spec.ts
# Bazel target: //packages/forms/signals/test/web:test
bazelisk test \
  //packages/forms/signals/test/web:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9ad603fa115934568036a5fcc419e351b90ff810 "packages/forms/signals/test/web/field_directive.spec.ts"