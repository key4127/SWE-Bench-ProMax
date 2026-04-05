#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 67e328cf927611a1823a56ff0b62580a209330e5 \
    "src/test/java/net/starlark/java/syntax/BUILD" \
    "src/test/java/net/starlark/java/syntax/ResolverTest.java" \
    "src/test/java/net/starlark/java/syntax/SyntaxTests.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/net/starlark/java/syntax/BUILD b/src/test/java/net/starlark/java/syntax/BUILD
--- a/src/test/java/net/starlark/java/syntax/BUILD
+++ b/src/test/java/net/starlark/java/syntax/BUILD
@@ -25,6 +25,7 @@ java_test(
         "NodeVisitorTest.java",
         "ParserInputTest.java",
         "ParserTest.java",
+        "ProgramTest.java",
         "ResolverTest.java",
         "StarlarkFileTest.java",
         "StarlarkTypesTest.java",
diff --git a/src/test/java/net/starlark/java/syntax/ProgramTest.java b/src/test/java/net/starlark/java/syntax/ProgramTest.java
new file mode 100644
--- /dev/null
+++ b/src/test/java/net/starlark/java/syntax/ProgramTest.java
@@ -0,0 +1,77 @@
+// Copyright 2025 The Bazel Authors. All rights reserved.
+//
+// Licensed under the Apache License, Version 2.0 (the "License");
+// you may not use this file except in compliance with the License.
+// You may obtain a copy of the License at
+//
+//    http://www.apache.org/licenses/LICENSE-2.0
+//
+// Unless required by applicable law or agreed to in writing, software
+// distributed under the License is distributed on an "AS IS" BASIS,
+// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+// See the License for the specific language governing permissions and
+// limitations under the License.
+package net.starlark.java.syntax;
+
+import static com.google.common.truth.Truth.assertThat;
+
+import org.junit.Test;
+import org.junit.runner.RunWith;
+import org.junit.runners.JUnit4;
+
+/** Tests of the Starlark {@link Program}. */
+@RunWith(JUnit4.class)
+public final class ProgramTest {
+
+  private Program compileFile(String... lines) throws SyntaxError.Exception {
+    ParserInput input = ParserInput.fromLines(lines);
+    StarlarkFile file = StarlarkFile.parse(input, FileOptions.DEFAULT);
+    return Program.compileFile(file, Resolver.moduleWithPredeclared("pre"));
+  }
+
+  @Test
+  public void docComments_basicFunctionality() throws Exception {
+    Program program =
+        compileFile(
+            """
+            #: Doc comment for A
+            #: multiline
+            FOO = 1
+            BAR, BAZ = (2, 3)  #: Applies to LHS list
+            """);
+    assertThat(program.getDocCommentsMap().keySet()).containsExactly("FOO", "BAR", "BAZ").inOrder();
+    assertThat(program.getDocCommentsMap().get("FOO").getText())
+        .isEqualTo("Doc comment for A\nmultiline");
+    assertThat(program.getDocCommentsMap().get("BAR").getText()).isEqualTo("Applies to LHS list");
+    assertThat(program.getDocCommentsMap().get("BAZ").getText()).isEqualTo("Applies to LHS list");
+  }
+
+  @Test
+  public void docComments_unused() throws Exception {
+    Program program =
+        compileFile(
+            """
+            #: Unused - separated by a non-doc comment line
+            # Non-doc comment line - not in module.unassignedDocComments()
+            A = 1
+
+            #: Unused - overridden by trailing doc comment
+            B = 2  #: Trailing doc comment for B overrides preceding doc comment block
+
+            def func():
+                #: Unused - not a global assignment
+                C = 3
+            # Another non-doc comment line - not in module.unassignedDocComments()
+            """);
+
+    assertThat(program.getDocCommentsMap().keySet()).containsExactly("B");
+    assertThat(program.getDocCommentsMap().get("B").getText())
+        .isEqualTo("Trailing doc comment for B overrides preceding doc comment block");
+    assertThat(program.getUnusedDocCommentLines().stream().map(Comment::getDocCommentText))
+        .containsExactly(
+            "Unused - separated by a non-doc comment line",
+            "Unused - overridden by trailing doc comment",
+            "Unused - not a global assignment")
+        .inOrder();
+  }
+}
diff --git a/src/test/java/net/starlark/java/syntax/ResolverTest.java b/src/test/java/net/starlark/java/syntax/ResolverTest.java
--- a/src/test/java/net/starlark/java/syntax/ResolverTest.java
+++ b/src/test/java/net/starlark/java/syntax/ResolverTest.java
@@ -505,6 +505,23 @@ public void testBindingScopeAndIndex() throws Exception {
         "      aᶠ₀, bᴳ₀, cᶠ₁, dᶠ₂, eᴸ₀, fᴳ₁, gᶠ₃, hᶠ₄");
   }
 
+  @Test
+  public void testDocComments() throws Exception {
+    StarlarkFile file =
+        resolveFile(
+            """
+            #: Doc for FOO
+            #: multiline
+            FOO = 1
+            BAR, BAZ = (2, 3)  #: Applies to LHS list
+            """);
+
+    assertThat(file.docCommentsMap.keySet()).containsExactly("FOO", "BAR", "BAZ").inOrder();
+    assertThat(file.docCommentsMap.get("FOO").getText()).isEqualTo("Doc for FOO\nmultiline");
+    assertThat(file.docCommentsMap.get("BAR").getText()).isEqualTo("Applies to LHS list");
+    assertThat(file.docCommentsMap.get("BAZ").getText()).isEqualTo("Applies to LHS list");
+  }
+
   // checkBindings verifies the binding (scope and index) of each identifier.
   // Every variable must be followed by a superscript letter (its scope)
   // and a subscript numeral (its index). They are replaced by spaces, the
diff --git a/src/test/java/net/starlark/java/syntax/SyntaxTests.java b/src/test/java/net/starlark/java/syntax/SyntaxTests.java
--- a/src/test/java/net/starlark/java/syntax/SyntaxTests.java
+++ b/src/test/java/net/starlark/java/syntax/SyntaxTests.java
@@ -27,6 +27,7 @@
   NodeVisitorTest.class,
   ParserInputTest.class,
   ParserTest.class,
+  ProgramTest.class,
   ResolverTest.class,
   StarlarkFileTest.class,
   StarlarkTypesTest.class,
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test target
# Based on the collected information, the primary test target is:
# //src/test/java/net/starlark/java/syntax:SyntaxTests
echo "=== Running SyntaxTests ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --test_summary=detailed \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/net/starlark/java/syntax:SyntaxTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 67e328cf927611a1823a56ff0b62580a209330e5 \
    "src/test/java/net/starlark/java/syntax/BUILD" \
    "src/test/java/net/starlark/java/syntax/ResolverTest.java" \
    "src/test/java/net/starlark/java/syntax/SyntaxTests.java"