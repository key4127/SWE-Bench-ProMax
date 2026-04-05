#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless browser testing
/start-xvfb.sh

# Checkout the original test file to ensure clean state
git checkout c149f47ef6937bff5cdc3854c8b7bc920758043f "packages/forms/signals/test/web/field_directive.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/web/field_directive.spec.ts b/packages/forms/signals/test/web/field_directive.spec.ts
--- a/packages/forms/signals/test/web/field_directive.spec.ts
+++ b/packages/forms/signals/test/web/field_directive.spec.ts
@@ -162,6 +162,36 @@ describe('field directive', () => {
         expect(comp.dir().dirty()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly dirty = input.required<boolean>();
+        }
+
+        @Component({
+          selector: 'custom-control',
+          template: '',
+        })
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly data = signal('');
+          readonly f = form(this.data);
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const comp = act(() => TestBed.createComponent(TestCmp)).componentInstance;
+        expect(comp.dir().dirty()).toBe(false);
+        act(() => comp.f().markAsDirty());
+        expect(comp.dir().dirty()).toBe(true);
+      });
+
       it('should be reset when field changes on custom control', () => {
         @Component({selector: 'custom-control', template: ``})
         class CustomControl implements FormValueControl<string> {
@@ -292,6 +322,41 @@ describe('field directive', () => {
         expect(dir.disabled()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly disabled = input.required<boolean>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<boolean> {
+          readonly value = model(false);
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly disabled = signal(false);
+          readonly f = form(signal(false), (p) => {
+            disabled(p, this.disabled);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.disabled()).toBe(false);
+        expect(element.disabled).toBe(false);
+
+        act(() => fixture.componentInstance.disabled.set(true));
+        expect(dir.disabled()).toBe(true);
+        expect(element.disabled).toBe(true);
+      });
+
       it('should be reset when field changes on native control', () => {
         @Component({
           imports: [Field],
@@ -402,6 +467,45 @@ describe('field directive', () => {
         ]);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly disabledReasons = input.required<readonly WithOptionalField<DisabledReason>[]>();
+        }
+
+        @Component({
+          selector: 'custom-control',
+          template: '',
+        })
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly disabled = signal(false);
+          readonly f = form(signal(''), (p) => {
+            disabled(p, () => {
+              return this.disabled() ? 'b' : false;
+            });
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.disabledReasons()).toEqual([]);
+
+        act(() => fixture.componentInstance.disabled.set(true));
+        expect(dir.disabledReasons()).toEqual([
+          {message: 'b', fieldTree: fixture.componentInstance.f},
+        ]);
+      });
+
       it('should be reset when field changes on custom control', () => {
         @Component({selector: 'custom-control', template: ``})
         class CustomControl implements FormValueControl<string> {
@@ -490,6 +594,41 @@ describe('field directive', () => {
         expect(dir.errors()).toEqual([requiredError({fieldTree: fixture.componentInstance.f})]);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly errors = input.required<readonly WithOptionalField<ValidationError>[]>();
+        }
+
+        @Component({
+          selector: 'custom-control',
+          template: '',
+        })
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly required = signal(false);
+          readonly f = form(signal(''), (p) => {
+            required(p, {when: this.required});
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.errors()).toEqual([]);
+
+        act(() => fixture.componentInstance.required.set(true));
+        expect(dir.errors()).toEqual([requiredError({fieldTree: fixture.componentInstance.f})]);
+      });
+
       it('should be reset when field changes on custom control', () => {
         @Component({selector: 'custom-control', template: ``})
         class CustomControl implements FormValueControl<string> {
@@ -578,6 +717,38 @@ describe('field directive', () => {
         expect(dir.hidden()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly hidden = input.required<boolean>();
+        }
+
+        @Component({selector: 'custom-control', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly hidden = signal(false);
+          readonly f = form(signal(''), (p) => {
+            hidden(p, this.hidden);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.hidden()).toBe(false);
+
+        act(() => fixture.componentInstance.hidden.set(true));
+        expect(dir.hidden()).toBe(true);
+      });
+
       it('should be reset when field changes on custom control', () => {
         @Component({selector: 'custom-control', template: ``})
         class CustomControl implements FormValueControl<string> {
@@ -662,6 +833,38 @@ describe('field directive', () => {
         expect(dir.invalid()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly invalid = input.required<boolean>();
+        }
+
+        @Component({selector: 'custom-control', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly invalid = signal(false);
+          readonly f = form(signal(''), (p) => {
+            required(p, {when: this.invalid});
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.invalid()).toBe(false);
+
+        act(() => fixture.componentInstance.invalid.set(true));
+        expect(dir.invalid()).toBe(true);
+      });
+
       it('should be reset when field changes on custom control', () => {
         @Component({selector: 'custom-control', template: ``})
         class CustomControl implements FormValueControl<string> {
@@ -787,6 +990,34 @@ describe('field directive', () => {
 
         expect(dir.name()).toBe('root');
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly name = input.required<string>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly f = form(signal(''), {name: 'root'});
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.name()).toBe('root');
+        expect(element.name).toBe('root');
+      });
     });
 
     describe('pending', () => {
@@ -916,6 +1147,49 @@ describe('field directive', () => {
         await fixture.whenStable();
         expect(dir.pending()).toBe(false);
       });
+
+      it('should bind to directive input on custom control', async () => {
+        const {promise, resolve} = promiseWithResolvers<ValidationError[]>();
+
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly pending = input.required<boolean>();
+        }
+
+        @Component({selector: 'custom-control', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model.required<string>();
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly f = form(signal(''), (p) => {
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
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.pending()).toBe(true);
+        resolve([]);
+        await promise;
+        await fixture.whenStable();
+        expect(dir.pending()).toBe(false);
+      });
     });
 
     describe('readonly', () => {
@@ -1019,6 +1293,41 @@ describe('field directive', () => {
         expect(dir.readonly()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly readonly = input.required<boolean>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model('');
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly readonly = signal(false);
+          readonly f = form(signal(''), (p) => {
+            readonly(p, this.readonly);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.readonly()).toBe(false);
+        expect(element.readOnly).toBe(false);
+
+        act(() => fixture.componentInstance.readonly.set(true));
+        expect(dir.readonly()).toBe(true);
+        expect(element.readOnly).toBe(true);
+      });
+
       it('should be reset when field changes on native control', () => {
         @Component({
           imports: [Field],
@@ -1169,6 +1478,41 @@ describe('field directive', () => {
         expect(dir.required()).toBe(true);
       });
 
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly required = input.required<boolean>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model('');
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly required = signal(false);
+          readonly f = form(signal(''), (p) => {
+            required(p, {when: this.required});
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.required()).toBe(false);
+        expect(element.required).toBe(false);
+
+        act(() => fixture.componentInstance.required.set(true));
+        expect(dir.required()).toBe(true);
+        expect(element.required).toBe(true);
+      });
+
       it('should be reset when field changes on native control', () => {
         @Component({
           imports: [Field],
@@ -1366,6 +1710,41 @@ describe('field directive', () => {
         act(() => fixture.componentInstance.max.set(5));
         expect(dir.max()).toBe(5);
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly max = input.required<number | undefined>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<number> {
+          readonly value = model(0);
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom type="number" [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly max = signal(10);
+          readonly f = form(signal(5), (p) => {
+            max(p, this.max);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.max()).toBe(10);
+        expect(element.max).toBe('10');
+
+        act(() => fixture.componentInstance.max.set(5));
+        expect(dir.max()).toBe(5);
+        expect(element.max).toBe('5');
+      });
     });
 
     describe('min', () => {
@@ -1516,6 +1895,41 @@ describe('field directive', () => {
         act(() => fixture.componentInstance.min.set(5));
         expect(dir.min()).toBe(5);
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly min = input.required<number | undefined>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<number> {
+          readonly value = model(0);
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom type="number" [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly min = signal(10);
+          readonly f = form(signal(15), (p) => {
+            min(p, this.min);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.min()).toBe(10);
+        expect(element.min).toBe('10');
+
+        act(() => fixture.componentInstance.min.set(5));
+        expect(dir.min()).toBe(5);
+        expect(element.min).toBe('5');
+      });
     });
 
     describe('maxLength', () => {
@@ -1682,6 +2096,41 @@ describe('field directive', () => {
         act(() => fixture.componentInstance.maxLength.set(5));
         expect(dir.maxLength()).toBe(5);
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly maxLength = input.required<number | undefined>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model('');
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly maxLength = signal(10);
+          readonly f = form(signal(''), (p) => {
+            maxLength(p, this.maxLength);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.maxLength()).toBe(10);
+        expect(element.maxLength).toBe(10);
+
+        act(() => fixture.componentInstance.maxLength.set(5));
+        expect(dir.maxLength()).toBe(5);
+        expect(element.maxLength).toBe(5);
+      });
     });
 
     describe('minLength', () => {
@@ -1848,6 +2297,41 @@ describe('field directive', () => {
         act(() => fixture.componentInstance.minLength.set(5));
         expect(dir.minLength()).toBe(5);
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly minLength = input.required<number | undefined>();
+        }
+
+        @Component({selector: 'input[custom]', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model('');
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<input custom [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly minLength = signal(10);
+          readonly f = form(signal('abc'), (p) => {
+            minLength(p, this.minLength);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+        const element = fixture.nativeElement.querySelector('input') as HTMLInputElement;
+
+        expect(dir.minLength()).toBe(10);
+        expect(element.minLength).toBe(10);
+
+        act(() => fixture.componentInstance.minLength.set(5));
+        expect(dir.minLength()).toBe(5);
+        expect(element.minLength).toBe(5);
+      });
     });
 
     describe('pattern', () => {
@@ -1931,6 +2415,38 @@ describe('field directive', () => {
         act(() => fixture.componentInstance.pattern.set(/b*/));
         expect(dir.pattern()).toEqual([/b*/]);
       });
+
+      it('should bind to directive input on custom control', () => {
+        @Directive({selector: '[testDir]'})
+        class TestDir {
+          readonly pattern = input.required<readonly RegExp[]>();
+        }
+
+        @Component({selector: 'custom-control', template: ``})
+        class CustomControl implements FormValueControl<string> {
+          readonly value = model('');
+        }
+
+        @Component({
+          imports: [Field, TestDir, CustomControl],
+          template: `<custom-control [field]="f" testDir />`,
+        })
+        class TestCmp {
+          readonly pattern = signal(/a*/);
+          readonly f = form(signal('abc'), (p) => {
+            pattern(p, this.pattern);
+          });
+          readonly dir = viewChild.required(TestDir);
+        }
+
+        const fixture = act(() => TestBed.createComponent(TestCmp));
+        const dir = fixture.componentInstance.dir();
+
+        expect(dir.pattern()).toEqual([/a*/]);
+
+        act(() => fixture.componentInstance.pattern.set(/b*/));
+        expect(dir.pattern()).toEqual([/b*/]);
+      });
     });
   });
 
EOF_114329324912

# Execute the forms signals test target
# Using pnpm to run bazel test with full output
pnpm bazel test //packages/forms/signals/test/web:test --test_output=all --flaky_test_attempts=1
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout c149f47ef6937bff5cdc3854c8b7bc920758043f "packages/forms/signals/test/web/field_directive.spec.ts"