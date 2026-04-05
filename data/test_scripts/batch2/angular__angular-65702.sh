#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless browser testing
/start-xvfb.sh

# Checkout the original test files to ensure clean state
git checkout a784995a982b97ebf16d1af7af6410872b7bb4a5 "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js" "packages/forms/signals/test/web/field_directive.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js
@@ -10,9 +10,8 @@ MyComponent.ɵcmp = /* @__PURE__ */i0.ɵɵdefineComponent({
       i0.ɵɵelementStart(1, "div");
       i0.ɵɵtext(2, "Not a form control either.");
       i0.ɵɵelementEnd();
-      i0.ɵɵelementStart(3, "input", 1);
+      i0.ɵɵelement(3, "input", 1);
       i0.ɵɵcontrolCreate();
-      i0.ɵɵelementEnd();
     }
     if (rf & 2) {
       i0.ɵɵadvance();
diff --git a/packages/forms/signals/test/web/field_directive.spec.ts b/packages/forms/signals/test/web/field_directive.spec.ts
--- a/packages/forms/signals/test/web/field_directive.spec.ts
+++ b/packages/forms/signals/test/web/field_directive.spec.ts
@@ -2527,6 +2527,47 @@ describe('field directive', () => {
       expect(customSubform.classList.contains('always')).toBe(false);
     });
   });
+
+  it('should create & bind input when a macro task is running', async () => {
+    const {promise, resolve} = promiseWithResolvers<void>();
+
+    @Component({
+      selector: 'app-form',
+      imports: [Field],
+      template: `
+        <form>
+          <select [field]="form">
+            <option value="us">United States</option>
+            <option value="ca">Canada</option>
+          </select>
+        </form>
+  `,
+    })
+    class FormComponent {
+      form = form(signal('us'));
+    }
+
+    @Component({
+      selector: 'app-root',
+      template: ``,
+    })
+    class App {
+      vcr = inject(ViewContainerRef);
+      constructor() {
+        promise.then(() => {
+          this.vcr.createComponent(FormComponent);
+        });
+      }
+    }
+
+    const fixture = act(() => TestBed.createComponent(App));
+
+    resolve();
+    await fixture.whenStable();
+
+    const select = fixture.debugElement.parent!.nativeElement.querySelector('select');
+    expect(select.value).toBe('us');
+  });
 });
 
 function setupRadioGroup() {
EOF_114329324912

# Execute the compliance test target
# This tests the control_bindings.js golden file
pnpm bazel test //packages/compiler-cli/test/compliance/full:full
rc1=$?

# Execute the forms signals test target
# This tests the field_directive.spec.ts file
pnpm bazel test //packages/forms/signals/test/web:test
rc2=$?

# Combine exit codes - if either test fails, overall result is failure
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout a784995a982b97ebf16d1af7af6410872b7bb4a5 "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/control_bindings/control_bindings.js" "packages/forms/signals/test/web/field_directive.spec.ts"