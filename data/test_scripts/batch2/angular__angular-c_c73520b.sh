#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e3afa240892d7384de566a19e8c77033a21cbf5f \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js" \
  "packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js" \
  "packages/compiler-cli/test/ngtsc/template_mapping_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js
@@ -11,7 +11,7 @@ function MyComponent_div_3_span_2_Template(rf, ctx) {
 	  const $foo$ = $r3$.ɵɵreference(1);
 	  const $baz$ = $r3$.ɵɵreference(5);
 	  $r3$.ɵɵadvance();
-	  $r3$.ɵɵtextInterpolate3("", $foo$, "-", $bar$, "-", $baz$, "");
+	  $r3$.ɵɵtextInterpolate3("", $foo$, "-", $bar$, "-", $baz$);
 	}
   }
   function MyComponent_div_3_Template(rf, ctx) {
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js
@@ -20,8 +20,7 @@ MyApp.ɵcmp = /*@__PURE__*/ $r3$.ɵɵdefineComponent({
         "1:", i0.ɵɵpipeBind2(2, 7, ctx.name, 1),
         "2:", i0.ɵɵpipeBind3(3, 10, ctx.name, 1, 2),
         "3:", i0.ɵɵpipeBind4(4, 14, ctx.name, 1, 2, 3),
-        "4:", i0.ɵɵpipeBindV(5, 19, $r3$.ɵɵpureFunction1(25, $c0$, ctx.name)),
-        ""
+        "4:", i0.ɵɵpipeBindV(5, 19, $r3$.ɵɵpureFunction1(25, $c0$, ctx.name))
       );
     }
   },
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js
@@ -20,7 +20,7 @@ MyApp.ɵcmp = /*@__PURE__*/ $r3$.ɵɵdefineComponent({
     if (rf & 2) {
       $r3$.ɵɵtextInterpolate($r3$.ɵɵpipeBind2(2, 6, $r3$.ɵɵpipeBind2(1, 3, ctx.name, ctx.size), ctx.size));
       $r3$.ɵɵadvance(4);
-      $r3$.ɵɵtextInterpolate2("", $r3$.ɵɵpipeBindV(5, 9, $r3$.ɵɵpureFunction1(18, $c0$, ctx.name)), " ", ctx.name ? 1 : $r3$.ɵɵpipeBind1(6, 16, 2), "");
+      $r3$.ɵɵtextInterpolate2("", $r3$.ɵɵpipeBindV(5, 9, $r3$.ɵɵpureFunction1(18, $c0$, ctx.name)), " ", ctx.name ? 1 : $r3$.ɵɵpipeBind1(6, 16, 2));
     }
   },
   dependencies: [MyPipe, MyPurePipe],
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js
@@ -2,8 +2,8 @@ template:  function MyApp_Template(rf, ctx) {
   // ...
   if (rf & 2) {
     $r3$.ɵɵadvance();
-    $r3$.ɵɵtextInterpolate1("Total: $", 1000000 * ctx.multiplier, "");
+    $r3$.ɵɵtextInterpolate1("Total: $", 1000000 * ctx.multiplier);
     $r3$.ɵɵadvance(2);
-    $r3$.ɵɵtextInterpolate1("Remaining: $", 123456.789 / 2, "");
+    $r3$.ɵɵtextInterpolate1("Remaining: $", 123456.789 / 2);
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js
@@ -8,7 +8,7 @@ function MyComponent_li_2_Template(rf, ctx) {
     const $myComp$ = $r3$.ɵɵnextContext();
     const $foo$ = $r3$.ɵɵreference(1);
     $r3$.ɵɵadvance();
-    $r3$.ɵɵtextInterpolate2("", $myComp$.salutation, " ", $foo$, "");
+    $r3$.ɵɵtextInterpolate2("", $myComp$.salutation, " ", $foo$);
   }
 }
 // ...
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js
@@ -1,8 +1,8 @@
 if (rf & 2) {
   $r3$.ɵɵadvance();
-  $r3$.ɵɵtextInterpolate1("No interpolations: ", ctx.tag `hello world `, "");
+  $r3$.ɵɵtextInterpolate1("No interpolations: ", ctx.tag `hello world `);
   $r3$.ɵɵadvance(2);
-  $r3$.ɵɵtextInterpolate1("With interpolations: ", ctx.tag `hello ${ctx.name}, it is currently ${ctx.timeOfDay}!`, "");
+  $r3$.ɵɵtextInterpolate1("With interpolations: ", ctx.tag `hello ${ctx.name}, it is currently ${ctx.timeOfDay}!`);
   $r3$.ɵɵadvance(2);
-  $r3$.ɵɵtextInterpolate1("With pipe: ", $r3$.ɵɵpipeBind1(6, 3, ctx.tag `hello ${ctx.name}`), "");
+  $r3$.ɵɵtextInterpolate1("With pipe: ", $r3$.ɵɵpipeBind1(6, 3, ctx.tag `hello ${ctx.name}`));
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js
@@ -1,8 +1,8 @@
 if (rf & 2) {
   $r3$.ɵɵadvance();
-  $r3$.ɵɵtextInterpolate1("No interpolations: ", `hello world `, "");
+  $r3$.ɵɵtextInterpolate1("No interpolations: ", `hello world `);
   $r3$.ɵɵadvance(2);
-  $r3$.ɵɵtextInterpolate1("With interpolations: ", `hello ${ctx.name}, it is currently ${ctx.timeOfDay}!`, "");
+  $r3$.ɵɵtextInterpolate1("With interpolations: ", `hello ${ctx.name}, it is currently ${ctx.timeOfDay}!`);
   $r3$.ɵɵadvance(2);
-  $r3$.ɵɵtextInterpolate1("With pipe: ", $r3$.ɵɵpipeBind1(6, 3, `hello ${ctx.name}`), "");
+  $r3$.ɵɵtextInterpolate1("With pipe: ", $r3$.ɵɵpipeBind1(6, 3, `hello ${ctx.name}`));
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js
@@ -11,6 +11,6 @@ template: function MyApp_Template(rf, ctx) {
     i0.ɵɵadvance();
     i0.ɵɵtextInterpolate1("Hello, ", ctx.firstName ?? "Frodo", "!");
     i0.ɵɵadvance(2);
-    i0.ɵɵtextInterpolate1("Your last name is ", ctx.lastName ?? ctx.lastNameFallback ?? "unknown", "");
+    i0.ɵɵtextInterpolate1("Your last name is ", ctx.lastName ?? ctx.lastNameFallback ?? "unknown");
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js
@@ -1,10 +1,10 @@
 } if (rf & 2) {
   i0.ɵɵadvance();
-  i0.ɵɵtextInterpolate1("Safe Property: ", ctx.p == null ? null : ctx.p.a == null ? null : ctx.p.a.b == null ? null : ctx.p.a.b.c == null ? null : ctx.p.a.b.c.d, "");
+  i0.ɵɵtextInterpolate1("Safe Property: ", ctx.p == null ? null : ctx.p.a == null ? null : ctx.p.a.b == null ? null : ctx.p.a.b.c == null ? null : ctx.p.a.b.c.d);
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Safe Keyed: ", ctx.p == null ? null : ctx.p["a"] == null ? null : ctx.p["a"]["b"] == null ? null : ctx.p["a"]["b"]["c"] == null ? null : ctx.p["a"]["b"]["c"]["d"], "");
+  i0.ɵɵtextInterpolate1("Safe Keyed: ", ctx.p == null ? null : ctx.p["a"] == null ? null : ctx.p["a"]["b"] == null ? null : ctx.p["a"]["b"]["c"] == null ? null : ctx.p["a"]["b"]["c"]["d"]);
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Mixed Property: ", ctx.p == null ? null : ctx.p.a == null ? null : ctx.p.a.b.c.d == null ? null : ctx.p.a.b.c.d.e == null ? null : ctx.p.a.b.c.d.e.f == null ? null : ctx.p.a.b.c.d.e.f.g.h, "");
+  i0.ɵɵtextInterpolate1("Mixed Property: ", ctx.p == null ? null : ctx.p.a == null ? null : ctx.p.a.b.c.d == null ? null : ctx.p.a.b.c.d.e == null ? null : ctx.p.a.b.c.d.e.f == null ? null : ctx.p.a.b.c.d.e.f.g.h);
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Mixed Property and Keyed: ", ctx.p.a["b"].c.d == null ? null : ctx.p.a["b"].c.d["e"] == null ? null : ctx.p.a["b"].c.d["e"]["f"] == null ? null : ctx.p.a["b"].c.d["e"]["f"].g["h"]["i"] == null ? null : ctx.p.a["b"].c.d["e"]["f"].g["h"]["i"].j.k, "");
+  i0.ɵɵtextInterpolate1("Mixed Property and Keyed: ", ctx.p.a["b"].c.d == null ? null : ctx.p.a["b"].c.d["e"] == null ? null : ctx.p.a["b"].c.d["e"]["f"] == null ? null : ctx.p.a["b"].c.d["e"]["f"].g["h"]["i"] == null ? null : ctx.p.a["b"].c.d["e"]["f"].g["h"]["i"].j.k);
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js
@@ -8,11 +8,11 @@
   let $tmp_3_2$;
   let $tmp_3_3$;
   i0.ɵɵadvance();
-  i0.ɵɵtextInterpolate1("Safe Property with Calls: ", ($tmp_0_0$ = ctx.p()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.a()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.b()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.c()) == null ? null : $tmp_0_0$.d(), "");
+  i0.ɵɵtextInterpolate1("Safe Property with Calls: ", ($tmp_0_0$ = ctx.p()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.a()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.b()) == null ? null : ($tmp_0_0$ = $tmp_0_0$.c()) == null ? null : $tmp_0_0$.d());
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Safe and Unsafe Property with Calls: ", ctx.p == null ? null : ($tmp_1_0$ = ctx.p.a()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.b().c().d()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.e()) == null ? null : $tmp_1_0$.f == null ? null : $tmp_1_0$.f.g.h == null ? null : ($tmp_1_0$ = $tmp_1_0$.f.g.h.i()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.j()) == null ? null : $tmp_1_0$.k().l, "");
+  i0.ɵɵtextInterpolate1("Safe and Unsafe Property with Calls: ", ctx.p == null ? null : ($tmp_1_0$ = ctx.p.a()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.b().c().d()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.e()) == null ? null : $tmp_1_0$.f == null ? null : $tmp_1_0$.f.g.h == null ? null : ($tmp_1_0$ = $tmp_1_0$.f.g.h.i()) == null ? null : ($tmp_1_0$ = $tmp_1_0$.j()) == null ? null : $tmp_1_0$.k().l);
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Nested Safe with Calls: ", ($tmp_2_0$ = ctx.f1()) == null ? null : $tmp_2_0$[($tmp_2_1$ = ctx.f2()) == null ? null : $tmp_2_1$.a] == null ? null : $tmp_2_0$[($tmp_2_1$ = $tmp_2_1$) == null ? null : $tmp_2_1$.a].b, "");
+  i0.ɵɵtextInterpolate1("Nested Safe with Calls: ", ($tmp_2_0$ = ctx.f1()) == null ? null : $tmp_2_0$[($tmp_2_1$ = ctx.f2()) == null ? null : $tmp_2_1$.a] == null ? null : $tmp_2_0$[($tmp_2_1$ = $tmp_2_1$) == null ? null : $tmp_2_1$.a].b);
   i0.ɵɵadvance(2);
-  i0.ɵɵtextInterpolate1("Deep Nested Safe with Calls: ", ($tmp_3_0$ = ctx.f1()) == null ? null : $tmp_3_0$[($tmp_3_1$ = ctx.f2()) == null ? null : ($tmp_3_2$ = $tmp_3_1$.f3()) == null ? null : $tmp_3_2$[($tmp_3_3$ = ctx.f4()) == null ? null : $tmp_3_3$.f5()]] == null ? null : $tmp_3_0$[($tmp_3_1$ = $tmp_3_1$) == null ? null : ($tmp_3_2$ = $tmp_3_2$) == null ? null : $tmp_3_2$[($tmp_3_3$ = $tmp_3_3$) == null ? null : $tmp_3_3$.f5()]].f6(), "");
+  i0.ɵɵtextInterpolate1("Deep Nested Safe with Calls: ", ($tmp_3_0$ = ctx.f1()) == null ? null : $tmp_3_0$[($tmp_3_1$ = ctx.f2()) == null ? null : ($tmp_3_2$ = $tmp_3_1$.f3()) == null ? null : $tmp_3_2$[($tmp_3_3$ = ctx.f4()) == null ? null : $tmp_3_3$.f5()]] == null ? null : $tmp_3_0$[($tmp_3_1$ = $tmp_3_1$) == null ? null : ($tmp_3_2$ = $tmp_3_2$) == null ? null : $tmp_3_2$[($tmp_3_3$ = $tmp_3_3$) == null ? null : $tmp_3_3$.f5()]].f6());
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js
@@ -1,8 +1,8 @@
 template: function MyComponent_Template(rf, ctx) {
   …
   if (rf & 2) {
-    $r3$.ɵɵattributeInterpolate1("tabindex", "prefix-", 0 + 3, "");
-    $r3$.ɵɵattributeInterpolate2("aria-label", "hello-", 1 + 3, "-", 2 + 3, "");
+    $r3$.ɵɵattributeInterpolate1("tabindex", "prefix-", 0 + 3);
+    $r3$.ɵɵattributeInterpolate2("aria-label", "hello-", 1 + 3, "-", 2 + 3);
     $r3$.ɵɵattribute("title", 1)("id", 2);
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js
@@ -1,7 +1,7 @@
 template: function MyComponent_Template(rf, ctx) {
   …
   if (rf & 2) {
-    $r3$.ɵɵattributeInterpolate1("aria-label", "prefix-", 1 + 3, "");
+    $r3$.ɵɵattributeInterpolate1("aria-label", "prefix-", 1 + 3);
     $r3$.ɵɵproperty("id", 2);
     $r3$.ɵɵattribute("title", 1)("tabindex", 3);
   }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js
@@ -26,8 +26,8 @@ function MyCmp_Template(rf, ctx) {
 	} if (rf & 2) {
 		i0.ɵɵstyleProp("style1", ctx.foo);
 		i0.ɵɵclassProp("class1", ctx.foo);
-		i0.ɵɵattributeInterpolate1("attrInterp1", "interp ", ctx.foo, "");
-		i0.ɵɵpropertyInterpolate1("propInterp1", "interp ", ctx.foo, "");
+		i0.ɵɵattributeInterpolate1("attrInterp1", "interp ", ctx.foo);
+		i0.ɵɵpropertyInterpolate1("propInterp1", "interp ", ctx.foo);
 		i0.ɵɵproperty("prop1", ctx.foo);
 		i0.ɵɵattribute("attr1", ctx.foo);
 	}
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js
@@ -2,7 +2,7 @@ template: function MyComponent_Template(rf, ctx) {
   …
   if (rf & 2) {
     $r3$.ɵɵpropertyInterpolate("tabindex", 0 + 3);
-    $r3$.ɵɵpropertyInterpolate2("aria-label", "hello-", 1 + 3, "-", 2 + 3, "");
+    $r3$.ɵɵpropertyInterpolate2("aria-label", "hello-", 1 + 3, "-", 2 + 3);
     $r3$.ɵɵproperty("title", 1)("id", 2);
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js
@@ -6,6 +6,6 @@ template:function MyComponent_Template(rf, $ctx$){
     $i0$.ɵɵelement(0, "a", 0);
   }
   if (rf & 2) {
-    $i0$.ɵɵpropertyInterpolate1("title", "Hello ", $ctx$.name, "");
+    $i0$.ɵɵpropertyInterpolate1("title", "Hello ", $ctx$.name);
   }
 }
\ No newline at end of file
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js
@@ -7,6 +7,6 @@ template:function MyComponent_Template(rf, $ctx$){
   }
   if (rf & 2) {
     $r3$.ɵɵadvance();
-    $i0$.ɵɵtextInterpolate1("Hello ", $ctx$.name, "");
+    $i0$.ɵɵtextInterpolate1("Hello ", $ctx$.name);
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js
@@ -67,7 +67,7 @@ template: function MyComponent_Template(rf, ctx) {
   }
   if (rf & 2) {
     i0.ɵɵadvance(2);
-    i0.ɵɵpropertyInterpolate2("title", "", ctx.foo, "-", ctx.foo, "");
+    i0.ɵɵpropertyInterpolate2("title", "", ctx.foo, "-", ctx.foo);
     i0.ɵɵadvance(2);
     i0.ɵɵi18nExp(ctx.foo)(ctx.foo)(ctx.foo)(ctx.foo)(ctx.foo);
     i0.ɵɵi18nApply(1);
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js
@@ -14,6 +14,6 @@ template: function MyComponent_Template(rf, $ctx$) {
     $r3$.ɵɵstyleProp("bar", $r3$.ɵɵpipeBind2(2, 14, $ctx$.barExp, 3000))("baz", $r3$.ɵɵpipeBind2(3, 17, $ctx$.bazExp, 4000));
     $r3$.ɵɵclassProp("foo", $r3$.ɵɵpipeBind2(4, 20, $ctx$.fooExp, 2000));
     $r3$.ɵɵadvance(5);
-   $r3$.ɵɵtextInterpolate1(" ", $ctx$.item, "");
+   $r3$.ɵɵtextInterpolate1(" ", $ctx$.item);
   }
 }
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js
@@ -6,7 +6,7 @@
       $r3$.ɵɵelement(0, "div");
     }
     if (rf & 2) {
-      $r3$.ɵɵclassMapInterpolate1("foo foo-", $ctx$.fooId, "");
+      $r3$.ɵɵclassMapInterpolate1("foo foo-", $ctx$.fooId);
     }
   }
 // ...
@@ -17,7 +17,7 @@
       $r3$.ɵɵelement(0, "div");
     }
     if (rf & 2) {
-      $r3$.ɵɵclassMapInterpolate2("foo foo-", $ctx$.fooId, "-", $ctx$.fooUsername, "");
+      $r3$.ɵɵclassMapInterpolate2("foo foo-", $ctx$.fooId, "-", $ctx$.fooUsername);
     }
   }
 // ...
diff --git a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js
--- a/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js
+++ b/packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js
@@ -1,2 +1,2 @@
 …
-i0.ɵɵtextInterpolate1(" ", (ctx.a == null ? null : ctx.a.b) ? 1 : 2, "")
+i0.ɵɵtextInterpolate1(" ", (ctx.a == null ? null : ctx.a.b) ? 1 : 2)
diff --git a/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js b/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js
--- a/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js
+++ b/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js
@@ -2,4 +2,4 @@ i0.ɵɵelementStart(0, "h3") // SOURCE: "/interpolation_basic.ts" "<h3>"
 …
 i0.ɵɵelementEnd() // SOURCE: "/interpolation_basic.ts" "</h3>"
 …
-i0.ɵɵtextInterpolate1("Hello ", ctx.name, "") // SOURCE: "/interpolation_basic.ts" "Hello {{ name }}"
+i0.ɵɵtextInterpolate1("Hello ", ctx.name) // SOURCE: "/interpolation_basic.ts" "Hello {{ name }}"
diff --git a/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js b/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js
--- a/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js
+++ b/packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js
@@ -3,4 +3,4 @@
 // TODO: Work out how to fix the broken segment for the last item in a template
 .ɵɵele // SOURCE: "/interpolation_basic.ts" "</h3>'"
 …
-.ɵɵtextInterpolate1("Hello ", ctx.name, "") // SOURCE: "/interpolation_basic.ts" "Hello {{ name }}"
+.ɵɵtextInterpolate1("Hello ", ctx.name) // SOURCE: "/interpolation_basic.ts" "Hello {{ name }}"
diff --git a/packages/compiler-cli/test/ngtsc/template_mapping_spec.ts b/packages/compiler-cli/test/ngtsc/template_mapping_spec.ts
--- a/packages/compiler-cli/test/ngtsc/template_mapping_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/template_mapping_spec.ts
@@ -72,7 +72,7 @@ runInEachFileSystem((os) => {
           });
           expectMapping(mappings, {
             source: 'Hello {{ name }}',
-            generated: 'i0.ɵɵtextInterpolate1("Hello ", ctx.name, "")',
+            generated: 'i0.ɵɵtextInterpolate1("Hello ", ctx.name)',
             sourceUrl: '../test.ts',
           });
           expectMapping(mappings, {
EOF_114329324912

# Run compliance tests that validate the golden files
# These tests check that compiler output matches expected .js files
bazelisk test \
  //packages/compiler-cli/test/compliance/... \
  --test_output=errors \
  --jobs=4

compliance_rc=$?

# Run the ngtsc test for template_mapping_spec.ts
bazelisk test \
  //packages/compiler-cli/test/ngtsc:ngtsc \
  --test_output=errors \
  --jobs=4

ngtsc_rc=$?

# Determine overall exit code (fail if either test suite fails)
if [ $compliance_rc -ne 0 ] || [ $ngtsc_rc -ne 0 ]; then
  rc=1
else
  rc=0
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e3afa240892d7384de566a19e8c77033a21cbf5f \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/lifecycle_hooks/local_reference_nested.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipe_invocation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/pipes/pipes_my_app_def.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/number_separator.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/structural_directives_my_component_def.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/tagged_template_literals.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_compiler_compliance/components_and_directives/value_composition/template_literals.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/nullish_coalescing/nullish_coalescing_interpolation_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_deep_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler/safe_access/safe_access_temporaries_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_bindings_with_interpolations.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/attribute_bindings/chain_multiple_bindings_mixed.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/order_bindings.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/chain_bindings_with_interpolations.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/property_bindings/interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_bindings/text_bindings/interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_i18n/icu_logic/attribute_interpolation.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/mixed_style_and_class/pipe_bindings_slots.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_styling/style_bindings/binding_slots.js" \
  "packages/compiler-cli/test/compliance/test_cases/r3_view_compiler_template/nested_ternary_operation_template.js" \
  "packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic.js" \
  "packages/compiler-cli/test/compliance/test_cases/source_mapping/inline_templates/interpolation_basic_partial.js" \
  "packages/compiler-cli/test/ngtsc/template_mapping_spec.ts"