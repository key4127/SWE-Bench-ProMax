#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9e043decaf01dc622236814a2a2db73ec2bffe28 \
  "packages/forms/signals/test/node/api/hidden.spec.ts" \
  "packages/forms/signals/test/node/api/validators/email.spec.ts" \
  "packages/forms/signals/test/node/api/validators/max.spec.ts" \
  "packages/forms/signals/test/node/api/validators/max_length.spec.ts" \
  "packages/forms/signals/test/node/api/validators/min.spec.ts" \
  "packages/forms/signals/test/node/api/validators/min_length.spec.ts" \
  "packages/forms/signals/test/node/api/validators/pattern.spec.ts" \
  "packages/forms/signals/test/node/api/validators/required.spec.ts" \
  "packages/forms/signals/test/node/api/validators/util.spec.ts" \
  "packages/forms/signals/test/node/api/validators/validation_errors.spec.ts" \
  "packages/forms/signals/test/node/api/when.spec.ts" \
  "packages/forms/signals/test/node/compat/compat.spec.ts" \
  "packages/forms/signals/test/node/field_node.spec.ts" \
  "packages/forms/signals/test/node/logic_node.spec.ts" \
  "packages/forms/signals/test/node/path.spec.ts" \
  "packages/forms/signals/test/node/recursive_logic.spec.ts" \
  "packages/forms/signals/test/node/resource.spec.ts" \
  "packages/forms/signals/test/node/submit.spec.ts" \
  "packages/forms/signals/test/node/validation_status.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/node/api/hidden.spec.ts b/packages/forms/signals/test/node/api/hidden.spec.ts
--- a/packages/forms/signals/test/node/api/hidden.spec.ts
+++ b/packages/forms/signals/test/node/api/hidden.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, hidden, validate} from '@angular/forms/signals';
+import {form, hidden, validate} from '@angular/forms/signals';
 
 describe('hidden', () => {
   it('should initially be false', () => {
@@ -70,7 +70,7 @@ describe('hidden', () => {
         });
 
         validate(p.name, () => {
-          return customError({kind: 'dog'});
+          return {kind: 'dog'};
         });
       },
       {injector: TestBed.inject(Injector)},
diff --git a/packages/forms/signals/test/node/api/validators/email.spec.ts b/packages/forms/signals/test/node/api/validators/email.spec.ts
--- a/packages/forms/signals/test/node/api/validators/email.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/email.spec.ts
@@ -9,7 +9,7 @@
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
 import {email, form} from '../../../../public_api';
-import {customError, emailError} from '../../../../src/api/rules/validation/validation_errors';
+import {emailError} from '../../../../src/api/rules/validation/validation_errors';
 
 describe('email validator', () => {
   it('returns requiredTrue error when the value is false', () => {
@@ -35,7 +35,7 @@ describe('email validator', () => {
       cat,
       (p) => {
         email(p.email, {
-          error: (ctx) => customError({kind: `special-email-${ctx.valueOf(p.name)}`}),
+          error: (ctx) => ({kind: `special-email-${ctx.valueOf(p.name)}`}),
         });
       },
       {
@@ -44,10 +44,10 @@ describe('email validator', () => {
     );
 
     expect(f.email().errors()).toEqual([
-      customError({
+      {
         kind: 'special-email-pirojok-the-cat',
         fieldTree: f.email,
-      }),
+      },
     ]);
   });
 
diff --git a/packages/forms/signals/test/node/api/validators/max.spec.ts b/packages/forms/signals/test/node/api/validators/max.spec.ts
--- a/packages/forms/signals/test/node/api/validators/max.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/max.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, max, maxError} from '../../../../public_api';
+import {form, max, maxError} from '../../../../public_api';
 
 describe('max validator', () => {
   it('returns max error when the value is larger', () => {
@@ -58,19 +58,19 @@ describe('max validator', () => {
         (p) => {
           max(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-max', message: value()?.toString()});
+              return {kind: 'special-max', message: value()?.toString()};
             },
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
       expect(f.age().errors()).toEqual([
-        customError({
+        {
           kind: 'special-max',
           message: '6',
           fieldTree: f.age,
-        }),
+        },
       ]);
     });
 
@@ -103,16 +103,14 @@ describe('max validator', () => {
             error: ({value, valueOf}) => {
               return valueOf(p.name) === 'disabled'
                 ? []
-                : customError({kind: 'special-max', message: value()?.toString()});
+                : {kind: 'special-max', message: value()?.toString()};
             },
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
-      expect(f.age().errors()).toEqual([
-        customError({kind: 'special-max', message: '6', fieldTree: f.age}),
-      ]);
+      expect(f.age().errors()).toEqual([{kind: 'special-max', message: '6', fieldTree: f.age}]);
       f.name().value.set('disabled');
       expect(f.age().errors()).toEqual([]);
     });
@@ -154,7 +152,7 @@ describe('max validator', () => {
         (p) => {
           max(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-max', message: value()?.toString()});
+              return {kind: 'special-max', message: value()?.toString()};
             },
           });
         },
diff --git a/packages/forms/signals/test/node/api/validators/max_length.spec.ts b/packages/forms/signals/test/node/api/validators/max_length.spec.ts
--- a/packages/forms/signals/test/node/api/validators/max_length.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/max_length.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, maxLength, maxLengthError} from '../../../../public_api';
+import {form, maxLength, maxLengthError} from '../../../../public_api';
 
 describe('maxLength validator', () => {
   it('returns maxLength error when the length is larger for strings', () => {
@@ -70,22 +70,22 @@ describe('maxLength validator', () => {
       (p) => {
         maxLength(p.text, 5, {
           error: ({value}) => {
-            return customError({
+            return {
               kind: 'special-maxLength',
               message: `Length is ${value().length}`,
-            });
+            };
           },
         });
       },
       {injector: TestBed.inject(Injector)},
     );
 
     expect(f.text().errors()).toEqual([
-      customError({
+      {
         kind: 'special-maxLength',
         message: 'Length is 6',
         fieldTree: f.text,
-      }),
+      },
     ]);
   });
 
@@ -145,10 +145,10 @@ describe('maxLength validator', () => {
         (p) => {
           maxLength(p.text, 5, {
             error: ({value}) => {
-              return customError({
+              return {
                 kind: 'special-maxLength',
                 message: `Length is ${value().length}`,
-              });
+              };
             },
           });
         },
diff --git a/packages/forms/signals/test/node/api/validators/min.spec.ts b/packages/forms/signals/test/node/api/validators/min.spec.ts
--- a/packages/forms/signals/test/node/api/validators/min.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/min.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, min, minError} from '../../../../public_api';
+import {form, min, minError} from '../../../../public_api';
 
 describe('min validator', () => {
   it('returns min error when the value is smaller', () => {
@@ -58,19 +58,19 @@ describe('min validator', () => {
         (p) => {
           min(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-min', message: value().toString()});
+              return {kind: 'special-min', message: value().toString()};
             },
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
       expect(f.age().errors()).toEqual([
-        customError({
+        {
           kind: 'special-min',
           message: '3',
           fieldTree: f.age,
-        }),
+        },
       ]);
     });
 
@@ -92,11 +92,11 @@ describe('min validator', () => {
       );
 
       expect(f.age().errors()).toEqual([
-        customError({
+        {
           kind: 'special-min',
           message: '3',
           fieldTree: f.age,
-        }),
+        },
       ]);
     });
 
@@ -129,16 +129,14 @@ describe('min validator', () => {
             error: ({value, valueOf}) => {
               return valueOf(p.name) === 'disabled'
                 ? []
-                : customError({kind: 'special-min', message: value().toString()});
+                : {kind: 'special-min', message: value().toString()};
             },
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
-      expect(f.age().errors()).toEqual([
-        customError({kind: 'special-min', message: '3', fieldTree: f.age}),
-      ]);
+      expect(f.age().errors()).toEqual([{kind: 'special-min', message: '3', fieldTree: f.age}]);
       f.name().value.set('disabled');
       expect(f.age().errors()).toEqual([]);
     });
diff --git a/packages/forms/signals/test/node/api/validators/min_length.spec.ts b/packages/forms/signals/test/node/api/validators/min_length.spec.ts
--- a/packages/forms/signals/test/node/api/validators/min_length.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/min_length.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, minLength, minLengthError} from '../../../../public_api';
+import {form, minLength, minLengthError} from '../../../../public_api';
 
 describe('minLength validator', () => {
   it('returns minLength error when the length is smaller for strings', () => {
@@ -70,22 +70,22 @@ describe('minLength validator', () => {
       (p) => {
         minLength(p.text, 5, {
           error: ({value}) => {
-            return customError({
+            return {
               kind: 'special-minLength',
               message: `Length is ${value().length}`,
-            });
+            };
           },
         });
       },
       {injector: TestBed.inject(Injector)},
     );
 
     expect(f.text().errors()).toEqual([
-      customError({
+      {
         kind: 'special-minLength',
         message: 'Length is 2',
         fieldTree: f.text,
-      }),
+      },
     ]);
   });
 
@@ -145,10 +145,10 @@ describe('minLength validator', () => {
         (p) => {
           minLength(p.text, 5, {
             error: ({value}) => {
-              return customError({
+              return {
                 kind: 'special-minLength',
                 message: `Length is ${value().length}`,
-              });
+              };
             },
           });
         },
diff --git a/packages/forms/signals/test/node/api/validators/pattern.spec.ts b/packages/forms/signals/test/node/api/validators/pattern.spec.ts
--- a/packages/forms/signals/test/node/api/validators/pattern.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/pattern.spec.ts
@@ -8,7 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError, form, pattern, patternError} from '../../../../public_api';
+import {form, pattern, patternError} from '../../../../public_api';
 
 describe('pattern validator', () => {
   it('validates whether a value matches the pattern', () => {
@@ -29,12 +29,12 @@ describe('pattern validator', () => {
     const f = form(
       cat,
       (p) => {
-        pattern(p.name, /pir.*jok/, {error: customError()});
+        pattern(p.name, /pir.*jok/, {error: {kind: 'invalid-pattern'}});
       },
       {injector: TestBed.inject(Injector)},
     );
 
-    expect(f.name().errors()).toEqual([customError({fieldTree: f.name})]);
+    expect(f.name().errors()).toEqual([{kind: 'invalid-pattern', fieldTree: f.name}]);
   });
 
   it('supports custom error message', () => {
diff --git a/packages/forms/signals/test/node/api/validators/required.spec.ts b/packages/forms/signals/test/node/api/validators/required.spec.ts
--- a/packages/forms/signals/test/node/api/validators/required.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/required.spec.ts
@@ -9,7 +9,7 @@
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
 import {form, required} from '../../../../public_api';
-import {customError, requiredError} from '../../../../src/api/rules/validation/validation_errors';
+import {requiredError} from '../../../../src/api/rules/validation/validation_errors';
 
 describe('required validator', () => {
   it('returns required Error when the value is not present', () => {
@@ -35,15 +35,15 @@ describe('required validator', () => {
       cat,
       (p) => {
         required(p.name, {
-          error: (ctx) => customError({kind: `required-${ctx.valueOf(p.age)}`}),
+          error: (ctx) => ({kind: `required-${ctx.valueOf(p.age)}`}),
         });
       },
       {
         injector: TestBed.inject(Injector),
       },
     );
 
-    expect(f.name().errors()).toEqual([customError({kind: 'required-5', fieldTree: f.name})]);
+    expect(f.name().errors()).toEqual([{kind: 'required-5', fieldTree: f.name}]);
     f.name().value.set('pirojok-the-cat');
     expect(f.name().errors()).toEqual([]);
   });
@@ -108,8 +108,6 @@ describe('required validator', () => {
 
     expect(f.name().errors()).toEqual([]);
     f.name().value.set('');
-    expect(f.name().errors()).toEqual([
-      customError({kind: 'pirojok-the-error', fieldTree: f.name}),
-    ]);
+    expect(f.name().errors()).toEqual([{kind: 'pirojok-the-error', fieldTree: f.name}]);
   });
 });
diff --git a/packages/forms/signals/test/node/api/validators/util.spec.ts b/packages/forms/signals/test/node/api/validators/util.spec.ts
deleted file mode 100644
--- a/packages/forms/signals/test/node/api/validators/util.spec.ts
+++ /dev/null
@@ -1,82 +0,0 @@
-/**
- * @license
- * Copyright Google LLC All Rights Reserved.
- *
- * Use of this source code is governed by an MIT-style license that can be
- * found in the LICENSE file at https://angular.dev/license
- */
-
-import {ensureCustomValidationResult} from '../../../../src/api/rules/validation/util';
-import {
-  customError,
-  minError,
-  ValidationError,
-} from '../../../../src/api/rules/validation/validation_errors';
-import {FieldTree} from '../../../../src/api/types';
-import {addDefaultField} from '../../../../src/field/validation';
-
-describe('validators utils', () => {
-  describe('ensureCustomValidationResult', () => {
-    it('should return null as is', () => {
-      expect(ensureCustomValidationResult(null)).toBe(null);
-    });
-
-    it('should return undefined as is', () => {
-      expect(ensureCustomValidationResult(undefined)).toBe(undefined);
-    });
-
-    it('should wrap a plain error object with customError', () => {
-      const error: ValidationError.WithField = {kind: 'meow', fieldTree: {} as FieldTree<unknown>};
-      const result = ensureCustomValidationResult(error);
-      expect(result).toEqual(customError(error));
-    });
-
-    it('should not wrap an error with the same shape', () => {
-      class WeirdError {
-        readonly kind = 'pirojok-the-weird-error';
-      }
-
-      const weirdError = addDefaultField(new WeirdError(), {} as FieldTree<unknown>);
-      const result = ensureCustomValidationResult(weirdError);
-      expect(result).toBe(weirdError);
-    });
-
-    it('should not wrap a custom user error', () => {
-      class PirojokError implements ValidationError {
-        readonly kind = 'pirojok-the-error';
-
-        constructor(readonly flavor: string) {}
-      }
-
-      const pirojokError = addDefaultField(new PirojokError('jam'), {} as FieldTree<unknown>);
-      const result = ensureCustomValidationResult(pirojokError);
-      expect(result).toBe(pirojokError);
-    });
-
-    it('should not wrap a min error', () => {
-      const min = minError(27);
-      const result = ensureCustomValidationResult(min);
-      expect(result).toBe(min);
-    });
-
-    it('should not wrap an error that is not a plain object', () => {
-      const custom = customError({kind: 'meow'});
-      const result = ensureCustomValidationResult(custom);
-      expect(result).toBe(custom);
-    });
-
-    describe('arrays', () => {
-      it('should process a mixed array of validation errors', () => {
-        const plainError: ValidationError.WithField = {
-          kind: 'plain',
-          fieldTree: {} as FieldTree<unknown>,
-        };
-        const custom = customError({kind: 'custom'});
-
-        const result = ensureCustomValidationResult([plainError, custom]);
-
-        expect(result).toEqual([customError(plainError), custom]);
-      });
-    });
-  });
-});
diff --git a/packages/forms/signals/test/node/api/validators/validation_errors.spec.ts b/packages/forms/signals/test/node/api/validators/validation_errors.spec.ts
--- a/packages/forms/signals/test/node/api/validators/validation_errors.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/validation_errors.spec.ts
@@ -11,14 +11,8 @@ import {form} from '../../../../src/api/structure';
 
 import {TestBed} from '@angular/core/testing';
 import {validate} from '../../../../src/api/rules';
-import {
-  customError,
-  CustomValidationError,
-  minError,
-  MinValidationError,
-  ValidationError,
-} from '../../../../src/api/rules/validation/validation_errors';
-import {FieldTree, FieldValidator, PathKind} from '../../../../src/api/types';
+import {minError, ValidationError} from '../../../../public_api';
+import {FieldValidator, PathKind} from '../../../../src/api/types';
 import Root = PathKind.Root;
 
 describe('validation errors', () => {
@@ -35,7 +29,7 @@ describe('validation errors', () => {
       {injector: TestBed.inject(Injector)},
     );
 
-    expect(f().errors()[0]).toBeInstanceOf(CustomValidationError);
+    expect(f().errors()[0]).toEqual({kind: 'i am a custom error', fieldTree: f});
   });
 
   it('supports returning a list of errors', () => {
@@ -49,17 +43,17 @@ describe('validation errors', () => {
             {
               kind: 'pirojok-the-error',
             },
-            customError({kind: 'meow'}),
+            {kind: 'meow'},
             minError(4),
           ];
         });
       },
       {injector: TestBed.inject(Injector)},
     );
 
-    expect(f().errors()[0]).toBeInstanceOf(CustomValidationError);
-    expect(f().errors()[1]).toBeInstanceOf(CustomValidationError);
-    expect(f().errors()[2]).toBeInstanceOf(MinValidationError);
+    expect(f().errors()[0]).toEqual({kind: 'pirojok-the-error', fieldTree: f});
+    expect(f().errors()[1]).toEqual({kind: 'meow', fieldTree: f});
+    expect(f().errors()[2]).toEqual(jasmine.objectContaining({kind: 'min'}));
   });
 
   it('supports creating dynamic list of errors with explicit type', () => {
@@ -83,8 +77,8 @@ describe('validation errors', () => {
       {injector: TestBed.inject(Injector)},
     );
 
-    expect(f().errors()[0]).toBeInstanceOf(CustomValidationError);
-    expect(f().errors()[1]).toBeInstanceOf(MinValidationError);
+    expect(f().errors()[0]).toEqual({kind: 'custom', fieldTree: f});
+    expect(f().errors()[1]).toEqual(jasmine.objectContaining({kind: 'min'}));
   });
 
   it('supports custom errors', () => {
@@ -121,12 +115,12 @@ describe('validation errors', () => {
 
   describe('type tests', () => {
     it('field on a validation result is not allowed', () => {
-      //  field on a validation result is not allowed
+      //  fieldTree on a validation result is not allowed
       const TBD: FieldValidator<string, Root> = () => ({
         kind: '3',
         dsdsd: 4,
         // @ts-expect-error
-        field: 3,
+        fieldTree: 3,
       });
     });
 
@@ -138,13 +132,13 @@ describe('validation errors', () => {
         (p) => {
           // @ts-expect-error
           validate(p, () => {
-            return {kind: 'i am a custom error', field: {} as FieldTree<unknown>};
+            return {kind: 'i am a custom error', fieldTree: {}};
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
-      expect(f().errors()[0]).toBeInstanceOf(CustomValidationError);
+      expect(f().errors()).toEqual([{kind: 'i am a custom error', fieldTree: {}}]);
     });
 
     it('allows returning ValidationError from a validator', () => {
@@ -154,16 +148,16 @@ describe('validation errors', () => {
         cat,
         (p) => {
           validate(p, () => {
-            return {} as ValidationError;
+            return {kind: 'custom'};
           });
         },
         {injector: TestBed.inject(Injector)},
       );
 
-      expect(f().errors()[0]).toBeInstanceOf(CustomValidationError);
+      expect(f().errors()[0]).toEqual({kind: 'custom', fieldTree: f});
     });
 
-    it('disallows pushin an error containing a field to a list of ValidationErrors', () => {
+    it('disallows pushing an error containing a field to a list of ValidationErrors', () => {
       const cat = signal('meow');
 
       form(
@@ -175,7 +169,7 @@ describe('validation errors', () => {
             array.push({
               kind: 'custom',
               // @ts-expect-error
-              field: {} as FieldTree<unknown>,
+              fieldTree: {},
             });
 
             return array;
diff --git a/packages/forms/signals/test/node/api/when.spec.ts b/packages/forms/signals/test/node/api/when.spec.ts
--- a/packages/forms/signals/test/node/api/when.spec.ts
+++ b/packages/forms/signals/test/node/api/when.spec.ts
@@ -16,7 +16,7 @@ import {
   form,
   validate,
 } from '../../../public_api';
-import {customError, requiredError} from '../../../src/api/rules/validation/validation_errors';
+import {requiredError} from '../../../src/api/rules/validation/validation_errors';
 
 export interface User {
   first: string;
@@ -67,13 +67,13 @@ describe('when', () => {
 
     const s: SchemaOrSchemaFn<User> = (namePath) => {
       validate(namePath.last, ({value}) => {
-        return value().length > 0 ? undefined : customError({kind: 'required1'});
+        return value().length > 0 ? undefined : {kind: 'required1'};
       });
     };
 
     const s2: SchemaOrSchemaFn<User> = (namePath) => {
       validate(namePath.last, ({value}) => {
-        return value.length > 0 ? undefined : customError({kind: 'required2'});
+        return value.length > 0 ? undefined : {kind: 'required2'};
       });
     };
 
@@ -89,13 +89,11 @@ describe('when', () => {
     );
     f.needLastName().value.set(true);
     expect(f.items[0].last().errors()).toEqual([
-      customError({kind: 'required1', fieldTree: f.items[0].last}),
-      customError({kind: 'required2', fieldTree: f.items[0].last}),
+      {kind: 'required1', fieldTree: f.items[0].last},
+      {kind: 'required2', fieldTree: f.items[0].last},
     ]);
     f.needLastName().value.set(false);
-    expect(f.items[0].last().errors()).toEqual([
-      customError({kind: 'required1', fieldTree: f.items[0].last}),
-    ]);
+    expect(f.items[0].last().errors()).toEqual([{kind: 'required1', fieldTree: f.items[0].last}]);
   });
 
   it('accepts a schema', () => {
@@ -123,9 +121,7 @@ describe('when', () => {
     const f = form(
       data,
       (path) => {
-        validate(path.last, ({value}) =>
-          value().length > 4 ? undefined : customError({kind: 'short'}),
-        );
+        validate(path.last, ({value}) => (value().length > 4 ? undefined : {kind: 'short'}));
 
         applyWhen(path, needsLastNamePredicate, (namePath /* Path */) => {
           validate(namePath.last, ({value}) => (value().length > 0 ? undefined : requiredError()));
@@ -135,10 +131,10 @@ describe('when', () => {
     );
 
     f().value.set({first: 'meow', needLastName: false, last: ''});
-    expect(f.last().errors()).toEqual([customError({kind: 'short', fieldTree: f.last})]);
+    expect(f.last().errors()).toEqual([{kind: 'short', fieldTree: f.last}]);
     f().value.set({first: 'meow', needLastName: true, last: ''});
     expect(f.last().errors()).toEqual([
-      customError({kind: 'short', fieldTree: f.last}),
+      {kind: 'short', fieldTree: f.last},
       requiredError({fieldTree: f.last}),
     ]);
   });
@@ -177,26 +173,18 @@ describe('applyWhenValue', () => {
           path.numOrNull,
           (value) => value === null || value > 0,
           (num) => {
-            validate(num, ({value}) =>
-              (value() ?? 0) < 10 ? customError({kind: 'too-small'}) : undefined,
-            );
+            validate(num, ({value}) => ((value() ?? 0) < 10 ? {kind: 'too-small'} : undefined));
           },
         );
       },
       {injector: TestBed.inject(Injector)},
     );
 
-    expect(f.numOrNull().errors()).toEqual([
-      customError({kind: 'too-small', fieldTree: f.numOrNull}),
-    ]);
+    expect(f.numOrNull().errors()).toEqual([{kind: 'too-small', fieldTree: f.numOrNull}]);
     f.numOrNull().value.set(5);
-    expect(f.numOrNull().errors()).toEqual([
-      customError({kind: 'too-small', fieldTree: f.numOrNull}),
-    ]);
+    expect(f.numOrNull().errors()).toEqual([{kind: 'too-small', fieldTree: f.numOrNull}]);
     f.numOrNull().value.set(null);
-    expect(f.numOrNull().errors()).toEqual([
-      customError({kind: 'too-small', fieldTree: f.numOrNull}),
-    ]);
+    expect(f.numOrNull().errors()).toEqual([{kind: 'too-small', fieldTree: f.numOrNull}]);
     f.numOrNull().value.set(15);
     expect(f.numOrNull().errors()).toEqual([]);
   });
@@ -210,9 +198,7 @@ describe('applyWhenValue', () => {
           path.numOrNull,
           (value) => value !== null,
           (num) => {
-            validate(num, ({value}) =>
-              value() < 10 ? customError({kind: 'too-small'}) : undefined,
-            );
+            validate(num, ({value}) => (value() < 10 ? {kind: 'too-small'} : undefined));
           },
         );
       },
@@ -221,9 +207,7 @@ describe('applyWhenValue', () => {
 
     expect(f.numOrNull().errors()).toEqual([]);
     f.numOrNull().value.set(5);
-    expect(f.numOrNull().errors()).toEqual([
-      customError({kind: 'too-small', fieldTree: f.numOrNull}),
-    ]);
+    expect(f.numOrNull().errors()).toEqual([{kind: 'too-small', fieldTree: f.numOrNull}]);
     f.numOrNull().value.set(null);
     expect(f.numOrNull().errors()).toEqual([]);
     f.numOrNull().value.set(15);
diff --git a/packages/forms/signals/test/node/compat/compat.spec.ts b/packages/forms/signals/test/node/compat/compat.spec.ts
--- a/packages/forms/signals/test/node/compat/compat.spec.ts
+++ b/packages/forms/signals/test/node/compat/compat.spec.ts
@@ -11,7 +11,6 @@ import {TestBed} from '@angular/core/testing';
 import {FormControl, FormGroup, Validators} from '@angular/forms';
 import {compatForm, CompatValidationError} from '../../../compat/public_api';
 import {
-  customError,
   disabled,
   email,
   FieldState,
@@ -457,7 +456,7 @@ describe('Forms compat', () => {
         },
       );
 
-      expect(f().errors()).toEqual([customError({kind: 'too small', fieldTree: f})]);
+      expect(f().errors()).toEqual([{kind: 'too small', fieldTree: f}]);
     });
 
     it('supports getting control from fieldTreeOf', () => {
@@ -484,7 +483,7 @@ describe('Forms compat', () => {
         },
       );
 
-      expect(f().errors()).toEqual([customError({kind: 'too small', fieldTree: f})]);
+      expect(f().errors()).toEqual([{kind: 'too small', fieldTree: f}]);
     });
 
     it('fails for regular values', () => {
@@ -538,7 +537,7 @@ describe('Forms compat', () => {
         required(path.name);
 
         validate(path.name, ({valueOf}) => {
-          return valueOf(path.age) < 8 ? customError({kind: 'too small'}) : undefined;
+          return valueOf(path.age) < 8 ? {kind: 'too small'} : undefined;
         });
       },
       {
@@ -548,10 +547,10 @@ describe('Forms compat', () => {
 
     expect(f.name().valid()).toBe(false);
     expect(f.name().errors()).toEqual([
-      customError({
+      {
         kind: 'too small',
         fieldTree: f.name,
-      }),
+      },
     ]);
 
     control.setValue(10);
@@ -703,7 +702,7 @@ describe('Forms compat', () => {
           required(path.name);
 
           validate(path.name, ({valueOf}) => {
-            return valueOf(path.age) < 8 ? customError({kind: 'too small'}) : undefined;
+            return valueOf(path.age) < 8 ? {kind: 'too small'} : undefined;
           });
           required(path.name, {
             when: ({valueOf}) => {
diff --git a/packages/forms/signals/test/node/field_node.spec.ts b/packages/forms/signals/test/node/field_node.spec.ts
--- a/packages/forms/signals/test/node/field_node.spec.ts
+++ b/packages/forms/signals/test/node/field_node.spec.ts
@@ -11,7 +11,6 @@ import {TestBed} from '@angular/core/testing';
 import {
   apply,
   applyEach,
-  customError,
   disabled,
   form,
   hidden,
@@ -921,7 +920,7 @@ describe('FieldNode', () => {
         (p) => {
           validate(p.a, ({value}) => {
             if (value() > 10) {
-              return customError({kind: 'too-damn-high'});
+              return {kind: 'too-damn-high'};
             }
             return undefined;
           });
@@ -935,7 +934,7 @@ describe('FieldNode', () => {
       expect(f().valid()).toBe(true);
 
       f.a().value.set(11);
-      expect(f.a().errors()).toEqual([customError({kind: 'too-damn-high', fieldTree: f.a})]);
+      expect(f.a().errors()).toEqual([{kind: 'too-damn-high', fieldTree: f.a}]);
       expect(f.a().valid()).toBe(false);
       expect(f().errors()).toEqual([]);
       expect(f().valid()).toBe(false);
@@ -947,7 +946,7 @@ describe('FieldNode', () => {
         (p) => {
           validate(p.a, ({value}) => {
             if (value() > 10) {
-              return [customError({kind: 'too-damn-high'}), customError({kind: 'bad'})];
+              return [{kind: 'too-damn-high'}, {kind: 'bad'}];
             }
             return undefined;
           });
@@ -960,8 +959,8 @@ describe('FieldNode', () => {
 
       f.a().value.set(11);
       expect(f.a().errors()).toEqual([
-        customError({kind: 'too-damn-high', fieldTree: f.a}),
-        customError({kind: 'bad', fieldTree: f.a}),
+        {kind: 'too-damn-high', fieldTree: f.a},
+        {kind: 'bad', fieldTree: f.a},
       ]);
       expect(f.a().valid()).toBe(false);
     });
@@ -1072,7 +1071,7 @@ describe('FieldNode', () => {
       const f = form(
         signal({a: 1, b: 2}),
         (p) => {
-          validate(p.a, ({value}) => (value() > 1 ? customError() : null));
+          validate(p.a, ({value}) => (value() > 1 ? {kind: 'error'} : null));
         },
         {injector: TestBed.inject(Injector)},
       );
@@ -1081,7 +1080,7 @@ describe('FieldNode', () => {
       expect(f.a().valid()).toBe(true);
 
       f.a().value.set(2);
-      expect(f.a().errors()).toEqual([customError({fieldTree: f.a})]);
+      expect(f.a().errors()).toEqual([{kind: 'error', fieldTree: f.a}]);
       expect(f.a().valid()).toBe(false);
     });
 
@@ -1092,12 +1091,12 @@ describe('FieldNode', () => {
           cat,
           (p) => {
             validateTree(p, ({value, fieldTreeOf}) => {
-              const errors: ValidationError[] = [];
+              const errors: ValidationError.WithOptionalField[] = [];
               if (value().name.length > 8) {
-                errors.push(customError({kind: 'long_name', fieldTree: fieldTreeOf(p.name)}));
+                errors.push({kind: 'long_name', fieldTree: fieldTreeOf(p.name)});
               }
               if (value().age < 0) {
-                errors.push(customError({kind: 'temporal_anomaly', fieldTree: fieldTreeOf(p.age)}));
+                errors.push({kind: 'temporal_anomaly', fieldTree: fieldTreeOf(p.age)});
               }
               return errors;
             });
@@ -1111,12 +1110,10 @@ describe('FieldNode', () => {
         f.age().value.set(-10);
 
         expect(f.name().errors()).toEqual([]);
-        expect(f.age().errors()).toEqual([
-          customError({kind: 'temporal_anomaly', fieldTree: f.age}),
-        ]);
+        expect(f.age().errors()).toEqual([{kind: 'temporal_anomaly', fieldTree: f.age}]);
 
         cat.set({name: 'Fluffy McFluffington', age: 10});
-        expect(f.name().errors()).toEqual([customError({kind: 'long_name', fieldTree: f.name})]);
+        expect(f.name().errors()).toEqual([{kind: 'long_name', fieldTree: f.name}]);
         expect(f.age().errors()).toEqual([]);
       });
 
@@ -1126,12 +1123,12 @@ describe('FieldNode', () => {
           cat,
           (p) => {
             validateTree(p, ({value, fieldTreeOf}) => {
-              const errors: ValidationError[] = [];
+              const errors: ValidationError.WithOptionalField[] = [];
               if (value().name.length > 8) {
-                errors.push(customError({kind: 'long_name', fieldTree: fieldTreeOf(p.name)}));
+                errors.push({kind: 'long_name', fieldTree: fieldTreeOf(p.name)});
               }
               if (value().age < 0) {
-                errors.push(customError({kind: 'temporal_anomaly', fieldTree: fieldTreeOf(p.age)}));
+                errors.push({kind: 'temporal_anomaly', fieldTree: fieldTreeOf(p.age)});
               }
               return errors;
             });
@@ -1145,12 +1142,10 @@ describe('FieldNode', () => {
         f.age().value.set(-10);
 
         expect(f.name().errors()).toEqual([]);
-        expect(f.age().errors()).toEqual([
-          customError({kind: 'temporal_anomaly', fieldTree: f.age}),
-        ]);
+        expect(f.age().errors()).toEqual([{kind: 'temporal_anomaly', fieldTree: f.age}]);
 
         cat.set({name: 'Fluffy McFluffington', age: 10});
-        expect(f.name().errors()).toEqual([customError({kind: 'long_name', fieldTree: f.name})]);
+        expect(f.name().errors()).toEqual([{kind: 'long_name', fieldTree: f.name}]);
         expect(f.age().errors()).toEqual([]);
       });
     });
@@ -1203,24 +1198,24 @@ describe('FieldNode', () => {
       const f = form(
         data,
         (p) => {
-          validate(p, () => customError({kind: 'root'}));
-          validate(p.child, () => customError({kind: 'child'}));
-          validate(p.child.child, () => customError({kind: 'grandchild'}));
+          validate(p, () => ({kind: 'root'}));
+          validate(p.child, () => ({kind: 'child'}));
+          validate(p.child.child, () => ({kind: 'grandchild'}));
         },
         {injector: TestBed.inject(Injector)},
       );
 
       expect(f.child.child().errorSummary()).toEqual([
-        customError({kind: 'grandchild', fieldTree: f.child.child}),
+        {kind: 'grandchild', fieldTree: f.child.child},
       ]);
       expect(f.child().errorSummary()).toEqual([
-        customError({kind: 'child', fieldTree: f.child}),
-        customError({kind: 'grandchild', fieldTree: f.child.child}),
+        {kind: 'child', fieldTree: f.child},
+        {kind: 'grandchild', fieldTree: f.child.child},
       ]);
       expect(f().errorSummary()).toEqual([
-        customError({kind: 'root', fieldTree: f}),
-        customError({kind: 'child', fieldTree: f.child}),
-        customError({kind: 'grandchild', fieldTree: f.child.child}),
+        {kind: 'root', fieldTree: f},
+        {kind: 'child', fieldTree: f.child},
+        {kind: 'grandchild', fieldTree: f.child.child},
       ]);
     });
   });
diff --git a/packages/forms/signals/test/node/logic_node.spec.ts b/packages/forms/signals/test/node/logic_node.spec.ts
--- a/packages/forms/signals/test/node/logic_node.spec.ts
+++ b/packages/forms/signals/test/node/logic_node.spec.ts
@@ -7,7 +7,7 @@
  */
 
 import {computed, signal} from '@angular/core';
-import {customError, FieldContext} from '../../public_api';
+import {FieldContext} from '../../public_api';
 import {DYNAMIC} from '../../src/schema/logic';
 import {LogicNodeBuilder} from '../../src/schema/logic_node';
 
@@ -32,11 +32,11 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.addSyncErrorRule(() => [customError({kind: 'root-err'})]);
+    builder.addSyncErrorRule(() => [{kind: 'root-err', fieldTree: undefined as any}]);
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'root-err'}),
+      {kind: 'root-err', fieldTree: undefined as any},
     ]);
   });
 
@@ -46,11 +46,11 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.getChild('a').addSyncErrorRule(() => [customError({kind: 'root-err'})]);
+    builder.getChild('a').addSyncErrorRule(() => [{kind: 'root-err', fieldTree: undefined as any}]);
 
     const logicNode = builder.build();
     expect(logicNode.getChild('a').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'root-err'}),
+      {kind: 'root-err', fieldTree: undefined as any},
     ]);
   });
 
@@ -61,16 +61,16 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     const builder2 = LogicNodeBuilder.newRoot();
-    builder2.addSyncErrorRule(() => [customError({kind: 'err-2'})]);
+    builder2.addSyncErrorRule(() => [{kind: 'err-2', fieldTree: undefined as any}]);
     builder.mergeIn(builder2);
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
-      customError({kind: 'err-2'}),
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
     ]);
   });
 
@@ -81,16 +81,16 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.getChild('a').addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     const builder2 = LogicNodeBuilder.newRoot();
-    builder2.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-2'})]);
+    builder2.getChild('a').addSyncErrorRule(() => [{kind: 'err-2', fieldTree: undefined as any}]);
     builder.mergeIn(builder2);
 
     const logicNode = builder.build();
     expect(logicNode.getChild('a').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
-      customError({kind: 'err-2'}),
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
     ]);
   });
 
@@ -105,12 +105,12 @@ describe('LogicNodeBuilder', () => {
 
     const pred = signal(true);
     const builder2 = LogicNodeBuilder.newRoot();
-    builder2.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder2.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
 
     pred.set(false);
@@ -132,14 +132,14 @@ describe('LogicNodeBuilder', () => {
     const builder2 = LogicNodeBuilder.newRoot();
 
     const builder3 = LogicNodeBuilder.newRoot();
-    builder3.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder3.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     builder2.mergeIn(builder3);
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
 
     pred.set(false);
@@ -161,14 +161,14 @@ describe('LogicNodeBuilder', () => {
     const builder2 = LogicNodeBuilder.newRoot();
 
     const builder3 = LogicNodeBuilder.newRoot();
-    builder3.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder3.getChild('a').addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     builder2.mergeIn(builder3);
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
 
     const logicNode = builder.build();
     expect(logicNode.getChild('a').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
 
     pred.set(false);
@@ -191,14 +191,14 @@ describe('LogicNodeBuilder', () => {
 
     const pred2 = signal(true);
     const builder3 = LogicNodeBuilder.newRoot();
-    builder3.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder3.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     builder2.getChild('a').mergeIn(builder3, {fn: () => pred2(), path: undefined!});
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
 
     const logicNode = builder.build();
     expect(logicNode.getChild('a').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
 
     pred.set(false);
@@ -230,15 +230,15 @@ describe('LogicNodeBuilder', () => {
     builder2
       .getChild('a')
       .getChild('b')
-      .addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+      .addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     const pred2 = signal(true);
     const builder3 = LogicNodeBuilder.newRoot();
-    builder3.getChild('b').addSyncErrorRule(() => [customError({kind: 'err-2'})]);
+    builder3.getChild('b').addSyncErrorRule(() => [{kind: 'err-2', fieldTree: undefined as any}]);
 
     const pred3 = signal(true);
     const builder4 = LogicNodeBuilder.newRoot();
-    builder4.addSyncErrorRule(() => [customError({kind: 'err-3'})]);
+    builder4.addSyncErrorRule(() => [{kind: 'err-3', fieldTree: undefined as any}]);
     builder3.getChild('b').mergeIn(builder4, {fn: () => pred3(), path: undefined!});
     builder2.getChild('a').mergeIn(builder3, {fn: () => pred2(), path: undefined!});
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
@@ -247,24 +247,27 @@ describe('LogicNodeBuilder', () => {
     expect(
       logicNode.getChild('a').getChild('b').logic.syncErrors.compute(fakeFieldContext),
     ).toEqual([
-      customError({kind: 'err-1'}),
-      customError({kind: 'err-2'}),
-      customError({kind: 'err-3'}),
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
+      {kind: 'err-3', fieldTree: undefined as any},
     ]);
 
     pred.set(true);
     pred2.set(true);
     pred3.set(false);
     expect(
       logicNode.getChild('a').getChild('b').logic.syncErrors.compute(fakeFieldContext),
-    ).toEqual([customError({kind: 'err-1'}), customError({kind: 'err-2'})]);
+    ).toEqual([
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
+    ]);
 
     pred.set(true);
     pred2.set(false);
     pred3.set(true);
     expect(
       logicNode.getChild('a').getChild('b').logic.syncErrors.compute(fakeFieldContext),
-    ).toEqual([customError({kind: 'err-1'})]);
+    ).toEqual([{kind: 'err-1', fieldTree: undefined as any}]);
 
     pred.set(false);
     pred2.set(true);
@@ -289,7 +292,9 @@ describe('LogicNodeBuilder', () => {
     const builder2 = LogicNodeBuilder.newRoot();
 
     const builder3 = LogicNodeBuilder.newRoot();
-    builder3.getChild('last').addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder3
+      .getChild('last')
+      .addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     builder2.getChild('items').getChild(DYNAMIC).mergeIn(builder3);
     builder.mergeIn(builder2, {fn: () => pred(), path: undefined!});
@@ -301,7 +306,7 @@ describe('LogicNodeBuilder', () => {
         .getChild(DYNAMIC)
         .getChild('last')
         .logic.syncErrors.compute(fakeFieldContext),
-    ).toEqual([customError({kind: 'err-1'})]);
+    ).toEqual([{kind: 'err-1', fieldTree: undefined as any}]);
 
     pred.set(false);
     expect(
@@ -323,19 +328,19 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     const builder2 = LogicNodeBuilder.newRoot();
-    builder2.addSyncErrorRule(() => [customError({kind: 'err-2'})]);
+    builder2.addSyncErrorRule(() => [{kind: 'err-2', fieldTree: undefined as any}]);
     builder.mergeIn(builder2);
 
-    builder.addSyncErrorRule(() => [customError({kind: 'err-3'})]);
+    builder.addSyncErrorRule(() => [{kind: 'err-3', fieldTree: undefined as any}]);
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
-      customError({kind: 'err-2'}),
-      customError({kind: 'err-3'}),
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
+      {kind: 'err-3', fieldTree: undefined as any},
     ]);
   });
 
@@ -349,19 +354,19 @@ describe('LogicNodeBuilder', () => {
     // };
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.getChild('a').addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
 
     const builder2 = LogicNodeBuilder.newRoot();
-    builder2.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-2'})]);
+    builder2.getChild('a').addSyncErrorRule(() => [{kind: 'err-2', fieldTree: undefined as any}]);
     builder.mergeIn(builder2);
 
-    builder.getChild('a').addSyncErrorRule(() => [customError({kind: 'err-3'})]);
+    builder.getChild('a').addSyncErrorRule(() => [{kind: 'err-3', fieldTree: undefined as any}]);
 
     const logicNode = builder.build();
     expect(logicNode.getChild('a').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
-      customError({kind: 'err-2'}),
-      customError({kind: 'err-3'}),
+      {kind: 'err-1', fieldTree: undefined as any},
+      {kind: 'err-2', fieldTree: undefined as any},
+      {kind: 'err-3', fieldTree: undefined as any},
     ]);
   });
 
@@ -372,19 +377,19 @@ describe('LogicNodeBuilder', () => {
     // }));
 
     const builder = LogicNodeBuilder.newRoot();
-    builder.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
     builder.getChild('next').mergeIn(builder);
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
     expect(logicNode.getChild('next').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
     expect(
       logicNode.getChild('next').getChild('next').logic.syncErrors.compute(fakeFieldContext),
-    ).toEqual([customError({kind: 'err-1'})]);
+    ).toEqual([{kind: 'err-1', fieldTree: undefined as any}]);
   });
 
   it('should support circular logic structures with predicate', () => {
@@ -395,25 +400,25 @@ describe('LogicNodeBuilder', () => {
 
     const pred = signal(true);
     const builder = LogicNodeBuilder.newRoot();
-    builder.addSyncErrorRule(() => [customError({kind: 'err-1'})]);
+    builder.addSyncErrorRule(() => [{kind: 'err-1', fieldTree: undefined as any}]);
     builder.getChild('next').mergeIn(builder, {fn: () => pred(), path: undefined!});
 
     const logicNode = builder.build();
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
     expect(logicNode.getChild('next').logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
     expect(
       logicNode.getChild('next').getChild('next').logic.syncErrors.compute(fakeFieldContext),
-    ).toEqual([customError({kind: 'err-1'})]);
+    ).toEqual([{kind: 'err-1', fieldTree: undefined as any}]);
 
     // TODO: test that verifies that the same predicate can resolve with a different field context
     // on `.next` vs on `.next.next`
     pred.set(false);
     expect(logicNode.logic.syncErrors.compute(fakeFieldContext)).toEqual([
-      customError({kind: 'err-1'}),
+      {kind: 'err-1', fieldTree: undefined as any},
     ]);
     expect(logicNode.getChild('next').logic.syncErrors.compute(fakeFieldContext)).toEqual([]);
     expect(
diff --git a/packages/forms/signals/test/node/path.spec.ts b/packages/forms/signals/test/node/path.spec.ts
--- a/packages/forms/signals/test/node/path.spec.ts
+++ b/packages/forms/signals/test/node/path.spec.ts
@@ -8,15 +8,7 @@
 
 import {Injector, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {
-  apply,
-  applyEach,
-  applyWhen,
-  customError,
-  form,
-  requiredError,
-  validate,
-} from '../../public_api';
+import {apply, applyEach, applyWhen, form, requiredError, validate} from '../../public_api';
 
 describe('path', () => {
   describe('Active path', () => {
@@ -51,7 +43,7 @@ describe('path', () => {
           apply(path, () => {
             expect(() => {
               validate(path.last, () => {
-                return customError();
+                return {kind: 'custom'};
               });
             }).toThrowError();
           });
@@ -69,7 +61,7 @@ describe('path', () => {
           apply(path, () => {
             expect(() => {
               validate(path, () => {
-                return customError();
+                return {kind: 'custom'};
               });
             }).toThrowError();
           });
@@ -90,7 +82,7 @@ describe('path', () => {
           applyEach(path.items, () => {
             expect(() => {
               validate(path.needLastName, () => {
-                return customError();
+                return {kind: 'custom'};
               });
             }).toThrowError();
           });
diff --git a/packages/forms/signals/test/node/recursive_logic.spec.ts b/packages/forms/signals/test/node/recursive_logic.spec.ts
--- a/packages/forms/signals/test/node/recursive_logic.spec.ts
+++ b/packages/forms/signals/test/node/recursive_logic.spec.ts
@@ -8,7 +8,6 @@
 
 import {computed, Injector, signal, type Signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
-import {customError} from '../../public_api';
 import {disabled, validate} from '../../src/api/rules';
 import {applyEach, applyWhen, applyWhenValue, form, schema} from '../../src/api/structure';
 import type {FieldTree, Schema} from '../../src/api/types';
@@ -99,9 +98,7 @@ describe('recursive schema logic', () => {
         ({valueOf}) => valueOf(p.tag) === 'table',
         (children) => {
           applyEach(children, (c) => {
-            validate(c.tag, ({value}) =>
-              value() !== 'tr' ? customError({kind: 'invalid-child'}) : undefined,
-            );
+            validate(c.tag, ({value}) => (value() !== 'tr' ? {kind: 'invalid-child'} : undefined));
           });
         },
       );
@@ -110,9 +107,7 @@ describe('recursive schema logic', () => {
         ({valueOf}) => valueOf(p.tag) === 'tr',
         (children) => {
           applyEach(children, (c) => {
-            validate(c.tag, ({value}) =>
-              value() !== 'td' ? customError({kind: 'invalid-child'}) : undefined,
-            );
+            validate(c.tag, ({value}) => (value() !== 'td' ? {kind: 'invalid-child'} : undefined));
           });
         },
       );
diff --git a/packages/forms/signals/test/node/resource.spec.ts b/packages/forms/signals/test/node/resource.spec.ts
--- a/packages/forms/signals/test/node/resource.spec.ts
+++ b/packages/forms/signals/test/node/resource.spec.ts
@@ -15,7 +15,6 @@ import {
   applyEach,
   applyWhen,
   createManagedMetadataKey,
-  customError,
   form,
   metadata,
   required,
@@ -69,7 +68,7 @@ describe('resources', () => {
       validate(p.name, ({state}) => {
         const remote = state.metadata(RES)!;
         if (remote.hasValue()) {
-          return customError({message: remote.value()});
+          return {message: remote.value(), kind: 'custom'};
         } else {
           return undefined;
         }
@@ -82,19 +81,21 @@ describe('resources', () => {
 
     await appRef.whenStable();
     expect(f.name().errors()).toEqual([
-      customError({
+      {
         message: 'got: cat',
         fieldTree: f.name,
-      }),
+        kind: 'custom',
+      },
     ]);
 
     f.name().value.set('dog');
     await appRef.whenStable();
     expect(f.name().errors()).toEqual([
-      customError({
+      {
         message: 'got: dog',
         fieldTree: f.name,
-      }),
+        kind: 'custom',
+      },
     ]);
   });
 
@@ -112,7 +113,7 @@ describe('resources', () => {
         validate(p.name, ({state}) => {
           const remote = state.metadata(RES)!;
           if (remote.hasValue()) {
-            return customError({message: remote.value()});
+            return {message: remote.value(), kind: 'custom'};
           } else {
             return undefined;
           }
@@ -126,31 +127,35 @@ describe('resources', () => {
 
     await appRef.whenStable();
     expect(f[0].name().errors()).toEqual([
-      customError({
+      {
         message: 'got: cat',
         fieldTree: f[0].name,
-      }),
+        kind: 'custom',
+      },
     ]);
     expect(f[1].name().errors()).toEqual([
-      customError({
+      {
         message: 'got: dog',
         fieldTree: f[1].name,
-      }),
+        kind: 'custom',
+      },
     ]);
 
     f[0].name().value.set('bunny');
     await appRef.whenStable();
     expect(f[0].name().errors()).toEqual([
-      customError({
+      {
         message: 'got: bunny',
         fieldTree: f[0].name,
-      }),
+        kind: 'custom',
+      },
     ]);
     expect(f[1].name().errors()).toEqual([
-      customError({
+      {
         message: 'got: dog',
         fieldTree: f[1].name,
-      }),
+        kind: 'custom',
+      },
     ]);
   });
 
@@ -166,13 +171,11 @@ describe('resources', () => {
             },
           }),
         onSuccess: (cats, {fieldTreeOf}) => {
-          return cats.map((cat, index) =>
-            customError({
-              kind: 'meows_too_much',
-              name: cat.name,
-              fieldTree: fieldTreeOf(p)[index],
-            }),
-          );
+          return cats.map((cat, index) => ({
+            kind: 'meows_too_much',
+            name: cat.name,
+            fieldTree: fieldTreeOf(p)[index],
+          }));
         },
         onError: () => null,
       });
@@ -183,10 +186,14 @@ describe('resources', () => {
 
     await appRef.whenStable();
     expect(f[0]().errors()).toEqual([
-      customError({kind: 'meows_too_much', name: 'Fluffy', fieldTree: f[0]}),
+      jasmine.objectContaining({
+        kind: 'meows_too_much',
+        name: 'Fluffy',
+        fieldTree: f[0],
+      }),
     ]);
     expect(f[1]().errors()).toEqual([
-      customError({kind: 'meows_too_much', name: 'Ziggy', fieldTree: f[1]}),
+      jasmine.objectContaining({kind: 'meows_too_much', name: 'Ziggy', fieldTree: f[1]}),
     ]);
   });
 
@@ -202,11 +209,11 @@ describe('resources', () => {
             },
           }),
         onSuccess: (cats, {fieldTreeOf}) => {
-          return customError({
+          return {
             kind: 'meows_too_much',
             name: cats[0].name,
             fieldTree: fieldTreeOf(p)[0],
-          });
+          };
         },
         onError: () => null,
       });
@@ -217,7 +224,7 @@ describe('resources', () => {
 
     await appRef.whenStable();
     expect(f[0]().errors()).toEqual([
-      customError({kind: 'meows_too_much', name: 'Fluffy', fieldTree: f[0]}),
+      {kind: 'meows_too_much', name: 'Fluffy', fieldTree: f[0]} as any,
     ]);
     expect(f[1]().errors()).toEqual([]);
   });
@@ -228,8 +235,7 @@ describe('resources', () => {
       (p) => {
         validateHttp(p, {
           request: ({value}) => `/api/check?username=${value()}`,
-          onSuccess: (available: boolean) =>
-            available ? undefined : customError({kind: 'username-taken'}),
+          onSuccess: (available: boolean) => (available ? undefined : {kind: 'username-taken'}),
           onError: () => null,
         });
       },
@@ -273,8 +279,11 @@ describe('resources', () => {
       required(address.street);
       validateHttp(address, {
         request: ({value}) => ({url: '/checkaddress', params: {...value()}}),
-        onSuccess: (message: string, {fieldTreeOf}) =>
-          customError({message, fieldTree: fieldTreeOf(address.street)}),
+        onSuccess: (message: string, {fieldTreeOf}) => ({
+          message,
+          fieldTree: fieldTreeOf(address.street),
+          kind: '',
+        }),
         onError: () => null,
       });
     });
@@ -291,7 +300,7 @@ describe('resources', () => {
     await appRef.whenStable();
 
     expect(addressForm.street().errors()).toEqual([
-      customError({message: 'Invalid!', fieldTree: addressForm.street}),
+      {message: 'Invalid!', fieldTree: addressForm.street, kind: ''},
     ]);
   });
 
@@ -303,7 +312,7 @@ describe('resources', () => {
         request: ({value}) => ({url: '/checkaddress', params: {...value()}}),
         onSuccess: () => undefined,
         onError: () => [
-          customError({kind: 'address-api-failed', message: 'API is down', fieldTree: addressForm}),
+          {kind: 'address-api-failed', message: 'API is down', fieldTree: addressForm},
         ],
       });
     });
@@ -319,11 +328,11 @@ describe('resources', () => {
     expect(addressForm().pending()).toBe(false);
     expect(addressForm().invalid()).toBe(true);
     expect(addressForm().errors()).toEqual([
-      customError({
+      {
         kind: 'address-api-failed',
         message: 'API is down',
         fieldTree: addressForm,
-      }),
+      },
     ]);
   });
 
@@ -332,8 +341,7 @@ describe('resources', () => {
     const s = schema((p) => {
       validateHttp(p, {
         request: ({value}) => `/api/check?username=${value()}`,
-        onSuccess: (available: boolean) =>
-          available ? undefined : customError({kind: 'username-taken'}),
+        onSuccess: (available: boolean) => (available ? undefined : {kind: 'username-taken'}),
         onError: () => null,
       });
     });
diff --git a/packages/forms/signals/test/node/submit.spec.ts b/packages/forms/signals/test/node/submit.spec.ts
--- a/packages/forms/signals/test/node/submit.spec.ts
+++ b/packages/forms/signals/test/node/submit.spec.ts
@@ -9,7 +9,6 @@
 import {Injector, resource, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
 import {
-  customError,
   form,
   required,
   requiredError,
@@ -77,15 +76,13 @@ describe('submit', () => {
     );
 
     await submit(f, (form) => {
-      return Promise.resolve(
-        customError({
-          kind: 'lastName',
-          fieldTree: form.last,
-        }),
-      );
+      return Promise.resolve({
+        kind: 'lastName',
+        fieldTree: form.last,
+      });
     });
 
-    expect(f.last().errors()).toEqual([customError({kind: 'lastName', fieldTree: f.last})]);
+    expect(f.last().errors()).toEqual([{kind: 'lastName', fieldTree: f.last}]);
   });
 
   it('maps errors to multiple fields', async () => {
@@ -94,25 +91,25 @@ describe('submit', () => {
 
     await submit(f, (form) => {
       return Promise.resolve([
-        customError({
+        {
           kind: 'firstName',
           fieldTree: form.first,
-        }),
-        customError({
+        },
+        {
           kind: 'lastName',
           fieldTree: form.last,
-        }),
-        customError({
+        },
+        {
           kind: 'lastName2',
           fieldTree: form.last,
-        }),
+        },
       ]);
     });
 
-    expect(f.first().errors()).toEqual([customError({kind: 'firstName', fieldTree: f.first})]);
+    expect(f.first().errors()).toEqual([{kind: 'firstName', fieldTree: f.first}]);
     expect(f.last().errors()).toEqual([
-      customError({kind: 'lastName', fieldTree: f.last}),
-      customError({kind: 'lastName2', fieldTree: f.last}),
+      {kind: 'lastName', fieldTree: f.last},
+      {kind: 'lastName2', fieldTree: f.last},
     ]);
   });
 
@@ -150,10 +147,10 @@ describe('submit', () => {
     );
 
     await submit(f, () => {
-      return Promise.resolve(customError());
+      return Promise.resolve({kind: 'custom'});
     });
 
-    expect(f().errors()).toEqual([customError({fieldTree: f})]);
+    expect(f().errors()).toEqual([{kind: 'custom', fieldTree: f}]);
   });
 
   it('marks the form as submitting', async () => {
@@ -233,7 +230,7 @@ describe('submit', () => {
 
     await submit(f.first, (form) => {
       submitSpy(form().value());
-      return Promise.resolve(customError({kind: 'lastName'}));
+      return Promise.resolve({kind: 'lastName'});
     });
 
     expect(submitSpy).toHaveBeenCalledWith('meow');
@@ -259,18 +256,18 @@ describe('submit', () => {
 
     await submit(f, async (form) => {
       return [
-        customError({kind: 'submit', fieldTree: f.first}),
-        customError({kind: 'submit', fieldTree: f.last}),
+        {kind: 'submit', fieldTree: f.first},
+        {kind: 'submit', fieldTree: f.last},
       ];
     });
 
-    expect(f.first().errors()).toEqual([customError({kind: 'submit', fieldTree: f.first})]);
-    expect(f.last().errors()).toEqual([customError({kind: 'submit', fieldTree: f.last})]);
+    expect(f.first().errors()).toEqual([{kind: 'submit', fieldTree: f.first}]);
+    expect(f.last().errors()).toEqual([{kind: 'submit', fieldTree: f.last}]);
 
     f.first().value.set('Hello');
 
     expect(f.first().errors()).toEqual([]);
-    expect(f.last().errors()).toEqual([customError({kind: 'submit', fieldTree: f.last})]);
+    expect(f.last().errors()).toEqual([{kind: 'submit', fieldTree: f.last}]);
   });
 });
 
diff --git a/packages/forms/signals/test/node/validation_status.spec.ts b/packages/forms/signals/test/node/validation_status.spec.ts
--- a/packages/forms/signals/test/node/validation_status.spec.ts
+++ b/packages/forms/signals/test/node/validation_status.spec.ts
@@ -9,7 +9,6 @@
 import {ApplicationRef, Injector, Resource, resource, signal} from '@angular/core';
 import {TestBed} from '@angular/core/testing';
 import {
-  customError,
   FieldTree,
   form,
   NgValidationError,
@@ -22,14 +21,14 @@ import {
 } from '../../public_api';
 
 function validateValue(value: string): ValidationError[] {
-  return value === 'INVALID' ? [customError()] : [];
+  return value === 'INVALID' ? [{kind: 'custom'}] : [];
 }
 
 function validateValueForChild(
   value: string,
   fieldTree: FieldTree<unknown> | undefined,
-): ValidationError.WithField[] {
-  return value === 'INVALID' ? [customError({fieldTree})] : [];
+): ValidationError.WithOptionalField[] {
+  return value === 'INVALID' ? [{kind: 'custom', fieldTree: fieldTree}] : [];
 }
 
 describe('validation status', () => {
@@ -423,7 +422,7 @@ describe('validation status', () => {
         signal('MIXED'),
         (p) => {
           validate(p, () => []);
-          validate(p, () => [customError()]);
+          validate(p, () => [{kind: 'custom'}]);
         },
         {injector},
       );
@@ -463,7 +462,7 @@ describe('validation status', () => {
       let res!: Resource<unknown>;
       let res2!: Resource<unknown>;
 
-      const promise = Promise.resolve<ValidationError[]>([customError()]);
+      const promise = Promise.resolve<ValidationError[]>([{kind: 'custom'}]);
       const promise2 = new Promise<ValidationError[]>(() => {});
       const f = form(
         signal('MIXED'),
@@ -506,7 +505,7 @@ describe('validation status', () => {
       let res: Resource<unknown>;
       let res2: Resource<unknown>;
 
-      const invalidPromise = Promise.resolve<ValidationError[]>([customError()]);
+      const invalidPromise = Promise.resolve<ValidationError[]>([{kind: 'custom'}]);
       const validPromise = Promise.resolve<ValidationError[]>([]);
       const pendingPromise = new Promise<ValidationError[]>(() => {});
 
@@ -564,7 +563,7 @@ describe('validation status', () => {
     it('instanceof should check if structure matches a standard error type', () => {
       const e1 = requiredError();
       expect(e1 instanceof NgValidationError).toBe(true);
-      const e2 = customError({kind: 'min', min: 'two'});
+      const e2 = {kind: 'min', min: 'two'};
       expect(e2 instanceof NgValidationError).toBe(false);
       const e3 = patternError(/.*@.*\.com/);
       expect(e3 instanceof NgValidationError).toBe(true);
EOF_114329324912

# Ensure environment variables are set for headless Chrome (if needed by Bazel)
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run the target tests using Bazel
# Testing all Node.js test files in packages/forms/signals/test/node/
# Bazel target: //packages/forms/signals/test/node:test
bazelisk test \
  //packages/forms/signals/test/node:test \
  --test_output=all \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 9e043decaf01dc622236814a2a2db73ec2bffe28 \
  "packages/forms/signals/test/node/api/hidden.spec.ts" \
  "packages/forms/signals/test/node/api/validators/email.spec.ts" \
  "packages/forms/signals/test/node/api/validators/max.spec.ts" \
  "packages/forms/signals/test/node/api/validators/max_length.spec.ts" \
  "packages/forms/signals/test/node/api/validators/min.spec.ts" \
  "packages/forms/signals/test/node/api/validators/min_length.spec.ts" \
  "packages/forms/signals/test/node/api/validators/pattern.spec.ts" \
  "packages/forms/signals/test/node/api/validators/required.spec.ts" \
  "packages/forms/signals/test/node/api/validators/util.spec.ts" \
  "packages/forms/signals/test/node/api/validators/validation_errors.spec.ts" \
  "packages/forms/signals/test/node/api/when.spec.ts" \
  "packages/forms/signals/test/node/compat/compat.spec.ts" \
  "packages/forms/signals/test/node/field_node.spec.ts" \
  "packages/forms/signals/test/node/logic_node.spec.ts" \
  "packages/forms/signals/test/node/path.spec.ts" \
  "packages/forms/signals/test/node/recursive_logic.spec.ts" \
  "packages/forms/signals/test/node/resource.spec.ts" \
  "packages/forms/signals/test/node/submit.spec.ts" \
  "packages/forms/signals/test/node/validation_status.spec.ts"