#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout bca7612fd0f1ef7570ad54765c23d9a6825f480b "src/test/java/net/starlark/java/syntax/TypeTaggerTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/net/starlark/java/syntax/TypeTaggerTest.java b/src/test/java/net/starlark/java/syntax/TypeTaggerTest.java
--- a/src/test/java/net/starlark/java/syntax/TypeTaggerTest.java
+++ b/src/test/java/net/starlark/java/syntax/TypeTaggerTest.java
@@ -137,30 +137,27 @@ public void extractType_union() throws Exception {
     assertThat(extractType("int|bool")).isEqualTo(Types.union(Types.INT, Types.BOOL));
   }
 
-  // TODO: #27370 - Rather than test applications of constructors for list and dict here, test the
-  // general machinery for calling a type constructor. The actual types should be tested separately.
+  // These are also tests of the list and dict type constructors, not just the TypeTagger.
 
   @Test
   public void extractType_list() throws Exception {
     assertThat(extractType("list[int]")).isEqualTo(Types.list(Types.INT));
     assertThat(extractType("list[list[int]]")).isEqualTo(Types.list(Types.list(Types.INT)));
+    assertThat(extractType("list")).isEqualTo(Types.list(Types.ANY));
 
     assertExtractTypeFails("list[int, bool]", "list[] accepts exactly 1 argument but got 2");
     assertExtractTypeFails("list[[int]]", "unexpected expression '[int]'");
-    // TODO: #27370 - `list` should produce `list[Any]`.
-    assertExtractTypeFails("list", "list[] accepts exactly 1 argument but got 0");
   }
 
   @Test
   public void extractType_dict() throws Exception {
     assertThat(extractType("dict[int, str]")).isEqualTo(Types.dict(Types.INT, Types.STR));
     assertThat(extractType("dict[int, list[str]]"))
         .isEqualTo(Types.dict(Types.INT, Types.list(Types.STR)));
+    assertThat(extractType("dict")).isEqualTo(Types.dict(Types.ANY, Types.ANY));
 
     assertExtractTypeFails("dict[int]", "dict[] accepts exactly 2 arguments but got 1");
     assertExtractTypeFails("dict[int, str, bool]", "dict[] accepts exactly 2 arguments but got 3");
-    // TODO: #27370 - `dict` should produce `dict[Any, Any]`.
-    assertExtractTypeFails("dict", "dict[] accepts exactly 2 arguments but got 0");
   }
 
   @Test
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Run the test using the test filter to specifically target TypeTaggerTest
# This will run only the TypeTaggerTest class within the SyntaxTests suite
bazel test \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=TypeTaggerTest \
    //src/test/java/net/starlark/java/syntax:SyntaxTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout bca7612fd0f1ef7570ad54765c23d9a6825f480b "src/test/java/net/starlark/java/syntax/TypeTaggerTest.java"