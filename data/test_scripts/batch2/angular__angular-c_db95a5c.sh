#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 10ef96adb3d989781c7ec5116a70b6518866ee27 "packages/forms/signals/test/web/control_directive.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/web/control_directive.spec.ts b/packages/forms/signals/test/web/control_directive.spec.ts
--- a/packages/forms/signals/test/web/control_directive.spec.ts
+++ b/packages/forms/signals/test/web/control_directive.spec.ts
@@ -34,6 +34,8 @@ import {
   type Field,
   type FormCheckboxControl,
   type FormValueControl,
+  type ValidationError,
+  type WithOptionalField,
 } from '../../public_api';
 
 @Component({
@@ -459,7 +461,7 @@ describe('control directive', () => {
     })
     class CustomInput implements FormValueControl<string> {
       value = model('');
-      disabledReasons = input<readonly DisabledReason[]>([]);
+      disabledReasons = input<readonly WithOptionalField<DisabledReason>[]>([]);
     }
 
     @Component({
@@ -523,6 +525,53 @@ describe('control directive', () => {
     act(() => field().reset());
     expect(myInput.touched()).toBe(false);
   });
+
+  it('should allow binding error and disabled messages through control or manually', () => {
+    @Component({
+      selector: 'my-input',
+      template: `
+        <input #i [value]="value()" (input)="value.set(i.value)" />
+        @for (reason of disabledReasons(); track $index) {
+          <p class="disabled-reason">{{reason.message}}</p>
+        }
+        @for (error of errors(); track $index) {
+          <p class="error">{{error.message}}</p>
+        }
+      `,
+    })
+    class CustomInput implements FormValueControl<string> {
+      value = model('');
+      disabledReasons = input<readonly WithOptionalField<DisabledReason>[]>([]);
+      errors = input<readonly WithOptionalField<ValidationError>[]>([]);
+    }
+
+    @Component({
+      imports: [Control, CustomInput],
+      template: `
+        <my-input [(value)]="model" [disabledReasons]="disabledReasons" [errors]="errors" />
+        <my-input [control]="f" />
+      `,
+    })
+    class TestCmp {
+      model = signal('');
+      f = form(this.model, (p) => {
+        required(p, {message: 'schema error'});
+        disabled(p, ({value}) => (value() === 'disabled' ? 'schema disabled' : false));
+      });
+      disabledReasons = [{message: 'manual disabled'}];
+      errors = [{kind: 'error', message: 'manual error'}];
+    }
+
+    const fix = act(() => TestBed.createComponent(TestCmp));
+    expect([...fix.nativeElement.querySelectorAll('.error')].map((e) => e.textContent)).toEqual([
+      'manual error',
+      'schema error',
+    ]);
+    act(() => fix.componentInstance.model.set('disabled'));
+    expect(
+      [...fix.nativeElement.querySelectorAll('.disabled-reason')].map((e) => e.textContent),
+    ).toEqual(['manual disabled', 'schema disabled']);
+  });
 });
 
 function setupRadioGroup() {
EOF_114329324912

# Execute the specific test target using Bazel
# The //packages/forms/signals/test/web:test target runs the web test suite
# This includes control_directive.spec.ts along with other web tests in that directory
# Using --test_output=streamed for verbose output to verify test execution
pnpm bazel test //packages/forms/signals/test/web:test --test_output=streamed
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 10ef96adb3d989781c7ec5116a70b6518866ee27 "packages/forms/signals/test/web/control_directive.spec.ts"