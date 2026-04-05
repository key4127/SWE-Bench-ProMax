#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 1478082e556768033d5681a3b86c84fcbdf65c2b \
    "src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java" \
    "src/test/java/net/starlark/java/eval/EvaluationTestCase.java" \
    "src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java" \
    "src/test/java/net/starlark/java/syntax/ResolverTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java b/src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java
--- a/src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java
+++ b/src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java
@@ -37,6 +37,8 @@ public class DynamicTypeCheckTest {
   @Before
   public void setup() {
     ev = new EvaluationTestCase();
+    // TODO: #27728 - Ensure the predeclared environment contains builtin type names so that we can
+    // set resolveTypeSyntax(true) here.
     ev.setFileOptions(FileOptions.builder().allowTypeSyntax(true).build());
     ev.setSemantics(
         StarlarkSemantics.builder()
diff --git a/src/test/java/net/starlark/java/eval/EvaluationTestCase.java b/src/test/java/net/starlark/java/eval/EvaluationTestCase.java
--- a/src/test/java/net/starlark/java/eval/EvaluationTestCase.java
+++ b/src/test/java/net/starlark/java/eval/EvaluationTestCase.java
@@ -90,12 +90,9 @@ final void exec(String... lines)
   }
 
   // A hook for subclasses to alter the created module.
-  // Implementations may add to the predeclared environment,
-  // and return the module's client data value.
+  // Implementations may add to the predeclared environment.
   // TODO(adonovan): only used in StarlarkFlagGuardingTest; move there.
-  protected Object newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {
-    return null; // no client data
-  }
+  protected void newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {}
 
   StarlarkThread getStarlarkThread() {
     if (this.thread == null) {
@@ -112,7 +109,7 @@ StarlarkThread getStarlarkThread() {
   private Module getModule() {
     if (this.module == null) {
       ImmutableMap.Builder<String, Object> predeclared = ImmutableMap.builder();
-      newModuleHook(predeclared); // see StarlarkFlagGuardingTest
+      newModuleHook(predeclared);
       this.module = Module.withPredeclared(semantics, predeclared.buildOrThrow());
     }
     return this.module;
diff --git a/src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java b/src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java
--- a/src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java
+++ b/src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java
@@ -199,11 +199,10 @@ public void testExperimentalFlagGuardedValue() throws Exception {
     ev =
         new EvaluationTestCase() {
           @Override
-          protected Object newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {
+          protected void newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {
             predeclared.put(
                 "GlobalSymbol",
                 FlagGuardedValue.onlyWhenExperimentalFlagIsTrue(EXPERIMENTAL_FLAG, "foo"));
-            return null; // no client data
           }
         };
 
@@ -232,10 +231,9 @@ public void testIncompatibleFlagGuardedValue() throws Exception {
     ev =
         new EvaluationTestCase() {
           @Override
-          protected Object newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {
+          protected void newModuleHook(ImmutableMap.Builder<String, Object> predeclared) {
             predeclared.put(
                 "GlobalSymbol", FlagGuardedValue.onlyWhenIncompatibleFlagIsFalse(FLAG2, "foo"));
-            return null; // no client data
           }
         };
 
diff --git a/src/test/java/net/starlark/java/syntax/ResolverTest.java b/src/test/java/net/starlark/java/syntax/ResolverTest.java
--- a/src/test/java/net/starlark/java/syntax/ResolverTest.java
+++ b/src/test/java/net/starlark/java/syntax/ResolverTest.java
@@ -461,8 +461,6 @@ public void testUndefError() throws Exception {
     assertThat(errors.get(0).message()).isEqualTo("name 'undef' is not defined");
   }
 
-  // TODO: #27728 - Add resolver behavior for type expressions, add bindingScopeAndIndex tests here.
-
   @Test
   public void testBindingScopeAndIndex_basic() throws Exception {
     checkBindings(
@@ -544,16 +542,106 @@ public void testBindingScopeAndIndex_loads() throws Exception {
   }
 
   @Test
-  public void testBindingScopeAndIndex_varStatement() throws Exception {
+  public void testBindingScopeAndIndex_functionAnnotations() throws Exception {
     options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+
     checkBindings(
-        // Var statement creates a binding, even in the absence of assignment.
-        "xᴳ₀ : T",
-        // Var statement can shadow predeclared.
-        "preᴳ₁ : T",
-        "def fᴳ₂():",
-        "  xᴳ₀",
-        "  preᴳ₁");
+        """
+        Tᴳ₀ = 1
+        def fᴳ₁(xᴸ₀: Tᴳ₀ = preᴾ₀) -> preᴾ₀:
+          pass
+        """);
+
+    // Type annotations are resolved outside of the function's block, just like default expressions.
+    checkBindings(
+        """
+        xᴳ₀ = 1
+        def fᴳ₁(xᴸ₀: xᴳ₀) -> xᴳ₀:
+          xᴸ₀
+        """);
+  }
+
+  @Test
+  public void testBindingScopeAndIndex_varAnnotations() throws Exception {
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+
+    checkBindings(
+        "Tᴳ₀ = 1",
+        // A var statement creates a binding for its variable (x), and its type annotation (T) has
+        // its binding set.
+        "xᴳ₁ : Tᴳ₀",
+        // Var statements can shadow predeclared.
+        "preᴳ₂ : Tᴳ₀",
+        "def fᴳ₃():",
+        "  xᴳ₁",
+        "  preᴳ₂");
+
+    // Type annotations in assignments have their bindings set.
+    checkBindings("xᴳ₀ : preᴾ₀ = 1");
+  }
+
+  @Test
+  public void testBindingScopeAndIndex_typeAlias() throws Exception {
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+
+    // A type declaration creates a binding for its variable (T) and its definition has its bindings
+    // set.
+    checkBindings("type Tᴳ₀ = preᴾ₀");
+
+    // A type declaration can shadow a predeclared.
+    checkBindings(
+        """
+        Tᴳ₀ = 1
+        type preᴳ₁ = Tᴳ₀
+        """);
+
+    // This is dumb and illegal, but not for resolver-related reasons.
+    checkBindings("type Tᴳ₀ = Tᴳ₀");
+  }
+
+  @Test
+  public void testBindingScopeAndIndex_cast() throws Exception {
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+
+    checkBindings("cast(preᴾ₀, preᴾ₀)");
+  }
+
+  // TODO: #27848 - Add test case for isinstance(), once supported.
+
+  @Test
+  public void testBindingScopeAndIndex_typeSyntaxNotResolvedWhenFlagDisabled() throws Exception {
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(false);
+
+    checkBindings(
+        """
+        def fᴳ₀(xᴸ₀: T   = preᴾ₀) -> pre  :
+          pass
+        xᴳ₁ : pre  #
+        yᴳ₂ : pre   = 1
+        """);
+
+    checkBindings(
+        """
+        type T   = S  #
+        cast(T  , preᴾ₀)
+        """);
+  }
+
+  @Test
+  public void testBindingScopeAndIndex_genericTypeVars_notResolved() throws Exception {
+    // Check that these are not currently processed.
+    // TODO: #27370 - Add support to the resolver for these.
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+    checkBindings(
+        "def fᴳ₀[S  , T  ]():", //
+        "  pass",
+        "type Fooᴳ₁[X  ] = preᴾ₀");
   }
 
   @Test
@@ -569,8 +657,8 @@ public void testDocComments() throws Exception {
             BAR, BAZ = (2, 3)  #: Applies to LHS list
 
             #: Applies to var annotation without initialier
-            QUX : T
-            QUUX : T #: And the trailing version...
+            QUX : pre
+            QUUX : pre #: And the trailing version...
             """);
 
     assertThat(file.docCommentsMap.keySet())
@@ -597,6 +685,51 @@ def f():
         """);
   }
 
+  @Test
+  public void testTypeAliasStatement_redeclarationDisallowed() throws Exception {
+    options.allowTypeSyntax(true);
+    options.resolveTypeSyntax(true);
+    assertInvalid(
+        ":2:6: 'T' redeclared at top level",
+        """
+        type T = pre
+        type T = pre
+        """);
+    assertInvalid(
+        ":2:6: 'T' redeclared at top level",
+        """
+        T = 1
+        type T = pre
+        """);
+    assertInvalid(
+        ":2:1: 'T' redeclared at top level",
+        """
+        type T = pre
+        T = 1
+        """);
+  }
+
+  @Test
+  public void testTypeAliasStatement_redeclarationAllowedWithFlag() throws Exception {
+    options.allowTypeSyntax(true);
+    options.allowToplevelRebinding(true);
+    assertValid(
+        """
+        type T = pre
+        type T = pre
+        """);
+    assertValid(
+        """
+        T = 1
+        type T = pre
+        """);
+    assertValid(
+        """
+        type T = pre
+        T = 1
+        """);
+  }
+
   @Test
   public void testMultipleTypeAnnotationsDisallowed_topLevel() throws Exception {
     options.allowTypeSyntax(true);
@@ -659,7 +792,7 @@ public void testMultipleTypeAnnotationsDisallowed_defStatement() throws Exceptio
         def f():
             # Redefinition is allowed (but bad style) if second definition has no type
             # annotation.
-            def a(x : int):
+            def a(x : pre):
                 pass
             def a(x):
                 pass
@@ -673,13 +806,13 @@ def f():
                 # none.
                 def b(x):
                     pass
-                def b(x : int):
+                def b(x : pre):
                     pass
 
                 # Return type annotation counts too.
                 def c(x):
                     pass
-                def c(x) -> int:
+                def c(x) -> pre:
                     pass
 
                 # Even generic type vars count.
@@ -701,7 +834,7 @@ public void testSingleAnnotationWithReassignmentIsAllowed() throws Exception {
     assertValid(
         """
         def f():
-            a : int
+            a : pre
             a = 123
         """);
   }
@@ -770,31 +903,20 @@ public void testCastExpression_cannotBeLhsOfAssignment() throws Exception {
   }
 
   @Test
-  public void testCastExpression_value_isResolved() throws Exception {
+  public void testCastExpression_valueAndType_areResolved() throws Exception {
     options.allowTypeSyntax(true);
-    StarlarkFile badFile = resolveFile("cast(int, f())");
-    assertThat(badFile.ok()).isFalse();
-    assertContainsError(badFile.errors(), "name 'f' is not defined");
+    options.resolveTypeSyntax(true);
 
-    StarlarkFile goodFile =
-        resolveFile(
-            """
-            def f():
-              return 1
-            cast(int, f())
-            """);
+    StarlarkFile goodFile = resolveFile("cast(pre, pre)");
     assertThat(goodFile.ok()).isTrue();
-  }
 
-  @Test
-  public void testCastExpression_type_notResolved() throws Exception {
-    // TODO(brandjon): resolve the cast's type once we have type checking.
-    options.allowTypeSyntax(true);
-    StarlarkFile badFile = resolveFile("cast(NoSuchType[int], 42)");
-    assertThat(badFile.ok()).isTrue();
+    StarlarkFile badFile = resolveFile("cast(a, b)");
+    assertThat(badFile.ok()).isFalse();
+    assertContainsError(badFile.errors(), "name 'a' is not defined");
+    assertContainsError(badFile.errors(), "name 'b' is not defined");
   }
 
-  // TODO(b/350661266): resolve types in isinstance().
+  // TODO: #27848 - Resolve types in isinstance().
   @Test
   public void testIsInstanceExpression_notYetSupported() throws Exception {
     options.allowTypeSyntax(true);
@@ -832,13 +954,6 @@ public void visit(Identifier id) {
                 + suffix
                 + out[0].substring(id.getEndOffset() + 2);
       }
-
-      @Override
-      public void visit(VarStatement varStatement) {
-        visit(varStatement.getIdentifier());
-        // Don't visit type expression, it isn't processed.
-        // TODO: #27728 - Include the type expression in these tests.
-      }
     }.visit(file);
     assertThat(out[0]).isEqualTo(src);
   }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root
export TEST_INSTALL_BASE=/var/lib/buildkite-agent/bazeltest/install_base
export REPOSITORY_CACHE=/var/lib/buildkite-agent/bazeltest/repo_cache
export REMOTE_NETWORK_ADDRESS=bazel.build:80

# Create test working directory
rm -rf $HOME/bazeltest
mkdir -p $HOME/bazeltest

# Run the EvalTests suite with filters for the three eval test classes
echo "=== Running EvalTests (DynamicTypeCheckTest, EvaluationTestCase, StarlarkFlagGuardingTest) ==="
bazel test \
    --test_output=all \
    --jvmopt=-Djava.lang.Thread.allowVirtualThreads=true \
    --jvmopt=--sun-misc-unsafe-memory-access=allow \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter="DynamicTypeCheckTest|EvaluationTestCase|StarlarkFlagGuardingTest" \
    //src/test/java/net/starlark/java/eval:EvalTests

eval_rc=$?

# Run the SyntaxTests suite with filter for ResolverTest
echo "=== Running SyntaxTests (ResolverTest) ==="
bazel test \
    --test_output=all \
    --jvmopt=-Djava.lang.Thread.allowVirtualThreads=true \
    --jvmopt=--sun-misc-unsafe-memory-access=allow \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=ResolverTest \
    //src/test/java/net/starlark/java/syntax:SyntaxTests

syntax_rc=$?

# Combine exit codes - if either failed, overall fails
if [ $eval_rc -ne 0 ] || [ $syntax_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 1478082e556768033d5681a3b86c84fcbdf65c2b \
    "src/test/java/net/starlark/java/eval/DynamicTypeCheckTest.java" \
    "src/test/java/net/starlark/java/eval/EvaluationTestCase.java" \
    "src/test/java/net/starlark/java/eval/StarlarkFlagGuardingTest.java" \
    "src/test/java/net/starlark/java/syntax/ResolverTest.java"