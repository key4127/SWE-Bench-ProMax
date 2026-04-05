#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 9997810ad638a48d6fd7de7f76b4a4d79da665a5 "src/test/java/net/starlark/java/syntax/NodeVisitorTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/net/starlark/java/syntax/NodeVisitorTest.java b/src/test/java/net/starlark/java/syntax/NodeVisitorTest.java
--- a/src/test/java/net/starlark/java/syntax/NodeVisitorTest.java
+++ b/src/test/java/net/starlark/java/syntax/NodeVisitorTest.java
@@ -21,11 +21,11 @@
 import org.junit.runner.RunWith;
 import org.junit.runners.JUnit4;
 
-/** Tests for @{code NodeVisitor} */
+/** Tests for {@code NodeVisitor} */
 @RunWith(JUnit4.class)
 public final class NodeVisitorTest {
 
-  private static StarlarkFile parse(String... lines) throws SyntaxError.Exception {
+  private StarlarkFile parse(String... lines) throws SyntaxError.Exception {
     ParserInput input = ParserInput.fromLines(lines);
     StarlarkFile file = StarlarkFile.parse(input);
     if (!file.ok()) {
@@ -34,32 +34,104 @@ private static StarlarkFile parse(String... lines) throws SyntaxError.Exception
     return file;
   }
 
-  @Test
-  public void everyIdentifierAndParameterIsVisitedInOrder() throws Exception {
+  /** Records all identifiers in the order they were seen, including duplicates. */
+  private static class IdentGatherer extends NodeVisitor {
     final List<String> idents = new ArrayList<>();
-    final List<String> params = new ArrayList<>();
-
-    class IdentVisitor extends NodeVisitor {
-      @Override
-      public void visit(Identifier node) {
-        idents.add(node.getName());
-      }
 
-      @Override
-      public void visit(Parameter node) {
-        params.add(node.toString());
-      }
+    @Override
+    public void visit(Identifier node) {
+      idents.add(node.getName());
     }
+  }
+
+  /**
+   * Asserts that the traversed identifiers (in order, including duplicates) of the given source
+   * code match the expected identifiers, which is supplied as a space-delimited string.
+   */
+  public void assertIdentsAre(String src, String expectedIdents) throws Exception {
+    StarlarkFile file = parse(src);
+    IdentGatherer visitor = new IdentGatherer();
+    visitor.visit(file);
+    assertThat(visitor.idents).containsExactlyElementsIn(expectedIdents.split(" ")).inOrder();
+  }
+
+  @Test
+  public void blockAndSimpleStatements() throws Exception {
+    assertIdentsAre(
+        """
+        load("...", "a", b="c")
+        d = e
+        f
+        pass
+        g, h[i] = j + 1 + "xyz" + 0.0
+        """,
+        // "c" is omitted because we don't currently visit the original name in a load binding.
+        "a b d e f g h i j");
+  }
+
+  @Test
+  public void controlStatements() throws Exception {
+    assertIdentsAre(
+        """
+        for a in b:
+          if c:
+            break
+          else:
+            continue
+        """,
+        "a b c");
+  }
 
-    StarlarkFile file =
-        parse(
-            "a = b", //
-            "def c(p1, p2=4, **p3):",
-            "  for d in e: f(g)",
-            "  return h + i.j()");
-    IdentVisitor visitor = new IdentVisitor();
-    file.accept(visitor);
-    assertThat(idents).containsExactly("b", "a", "c", "e", "d", "f", "g", "h", "i", "j").inOrder();
-    assertThat(params).containsExactly("p1", "p2=4", "**p3").inOrder();
+  @Test
+  public void simpleExpressions() throws Exception {
+    assertIdentsAre(
+        """
+        a + b if c else d.e
+        {f: g, h: [i, j]}
+        not k[l:m]
+        """,
+        "a b c d e f g h i j k l m");
+  }
+
+  @Test
+  public void comprehensions() throws Exception {
+    assertIdentsAre(
+        """
+        [a for b, c in d if e for f in {g: h for i in j}]
+        """,
+        "a b c d e f g h i j");
   }
+
+  @Test
+  public void calls() throws Exception {
+    assertIdentsAre(
+        """
+        a(b, c=d, *e, **f)
+        """,
+        "a b c d e f");
+  }
+
+  @Test
+  public void functionDefs() throws Exception {
+    assertIdentsAre(
+        """
+        def a(b, c=d, *e, **f):
+          g
+        """,
+        "a b c d e f g");
+    assertIdentsAre(
+        """
+        def a(*, b, c=d):
+          return
+        """,
+        "a b c d");
+  }
+
+  // TODO(#27728): Add tests for:
+  //   - function param and return annotations
+  //   - VarStatement and annotations in AssignmentStatement
+  //   - TypeAliasStatement
+  //   - Ellipsis
+  //   - CastExpression
+  //   - IsInstanceExpression
 }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Query Bazel to find the exact target that includes NodeVisitorTest
echo "=== Querying Bazel for targets containing NodeVisitorTest ==="
bazel query 'attr(srcs, "NodeVisitorTest.java", //src/test/java/net/starlark/java/syntax:*)' || true

# Run the test using the test filter to specifically target NodeVisitorTest
# This will run only the NodeVisitorTest class within the SyntaxTests suite
bazel test \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=NodeVisitorTest \
    //src/test/java/net/starlark/java/syntax:SyntaxTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9997810ad638a48d6fd7de7f76b4a4d79da665a5 "src/test/java/net/starlark/java/syntax/NodeVisitorTest.java"