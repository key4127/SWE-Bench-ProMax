#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 61987ae7a644ed90bb764d8926ce382ad2b02b0e \
    "src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java" \
    "src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java" \
    "src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java" \
    "src/test/java/com/google/devtools/build/lib/starlark/util/BUILD" \
    "src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD" \
    "src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java b/src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java
@@ -81,7 +81,9 @@ private static Object exec(String... lines) throws Exception {
                   RepositoryMapping.EMPTY,
                   "test/label.bzl",
                   /* loads= */ ImmutableList.of(),
-                  /* bzlTransitiveDigest= */ new byte[0])),
+                  /* bzlTransitiveDigest= */ new byte[0],
+                  /* docCommentsMap= */ ImmutableMap.of(),
+                  /* unusedDocCommentLines= */ ImmutableList.of())),
           thread);
     }
   }
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java b/src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java
@@ -738,7 +738,9 @@ private static Object execStarlark(String code) throws Exception {
                   RepositoryMapping.EMPTY,
                   "test/label.bzl",
                   /* loads= */ ImmutableList.of(),
-                  /* bzlTransitiveDigest= */ new byte[0])),
+                  /* bzlTransitiveDigest= */ new byte[0],
+                  /* docCommentsMap= */ ImmutableMap.of(),
+                  /* unusedDocCommentLines= */ ImmutableList.of())),
           thread);
     }
   }
diff --git a/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD b/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD
--- a/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD
@@ -21,20 +21,18 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/analysis:actions/binary_file_write_action",
         "//src/main/java/com/google/devtools/build/lib/analysis:analysis_cluster",
         "//src/main/java/com/google/devtools/build/lib/analysis:configured_target",
-        "//src/main/java/com/google/devtools/build/lib/bazel/repository/starlark",
         "//src/main/java/com/google/devtools/build/lib/cmdline",
-        "//src/main/java/com/google/devtools/build/lib/starlarkbuildapi/repository",
         "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:moduleinfoextractor",
         "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:ruleinfoextractor",
         "//src/main/java/com/google/devtools/build/lib/vfs",
         "//src/main/protobuf:stardoc_output_java_proto",
         "//src/test/java/com/google/devtools/build/lib/analysis/util",
         "//src/test/java/com/google/devtools/build/lib/bazel/bzlmod:util",
-        "//src/test/java/com/google/devtools/build/lib/testutil",
         "//third_party:guava",
         "//third_party:junit4",
         "//third_party:truth",
         "@com_google_protobuf//:protobuf_java",
+        "@maven//:com_google_testparameterinjector_test_parameter_injector",
     ],
 )
 
diff --git a/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java b/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java
--- a/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java
+++ b/src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java
@@ -45,13 +45,14 @@
 import com.google.devtools.build.lib.vfs.Path;
 import com.google.protobuf.ExtensionRegistry;
 import com.google.protobuf.TextFormat;
+import com.google.testing.junit.testparameterinjector.TestParameter;
+import com.google.testing.junit.testparameterinjector.TestParameterInjector;
 import java.util.NoSuchElementException;
 import org.junit.Before;
 import org.junit.Test;
 import org.junit.runner.RunWith;
-import org.junit.runners.JUnit4;
 
-@RunWith(JUnit4.class)
+@RunWith(TestParameterInjector.class)
 public final class StarlarkDocExtractTest extends BuildViewTestCase {
 
   private static ModuleInfo protoFromBinaryFileWriteAction(Action action) throws Exception {
@@ -1177,4 +1178,41 @@ def my_macro(arg = Label("//target:target")):
     assertThat(getFirstRuleFirstAttr(moduleInfo).getDefaultValue())
         .isEqualTo("\"@dep_mod//target\"");
   }
+
+  @Test
+  public void unusedDocComments(@TestParameter boolean allowUnusedDocComments) throws Exception {
+    scratch.file(
+        "foo.bzl",
+        """
+        #: Unused doc comment
+        def my_func():
+            pass
+
+        def _my_function():
+            pass
+
+        #: Unexpected doc comment
+        MY_FUNCTION_ALIAS = _my_function
+        """);
+    scratch.file(
+        "BUILD",
+        String.format(
+            """
+            starlark_doc_extract(
+                name = "extract",
+                src = "foo.bzl",%s
+            )
+            """,
+            allowUnusedDocComments ? "\n    allow_unused_doc_comments = True" : ""));
+    if (allowUnusedDocComments) {
+      assertThat(protoFromConfiguredTarget("//:extract").getStarlarkOtherSymbolInfoList())
+          .isEmpty();
+    } else {
+      AssertionError error =
+          assertThrows(AssertionError.class, () -> getConfiguredTarget("//:extract"));
+      assertThat(error)
+          .hasMessageThat()
+          .contains("in /workspace/foo.bzl: unexpected or conflicting doc comments on line 1");
+    }
+  }
 }
diff --git a/src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java b/src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java
--- a/src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java
+++ b/src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java
@@ -6751,7 +6751,9 @@ public void testLabelWithStrictVisibility() throws Exception {
                 ImmutableMap.of("my_module", currentRepo, "dep", otherRepo), currentRepo),
             "lib/label.bzl",
             /* loads= */ ImmutableList.of(),
-            /* bzlTransitiveDigest= */ new byte[0]);
+            /* bzlTransitiveDigest= */ new byte[0],
+            /* docCommentsMap= */ ImmutableMap.of(),
+            /* unusedDocCommentLines= */ ImmutableList.of());
     Module module =
         Module.withPredeclaredAndData(
             StarlarkSemantics.DEFAULT,
diff --git a/src/test/java/com/google/devtools/build/lib/starlark/util/BUILD b/src/test/java/com/google/devtools/build/lib/starlark/util/BUILD
--- a/src/test/java/com/google/devtools/build/lib/starlark/util/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/starlark/util/BUILD
@@ -25,7 +25,6 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/cmdline",
         "//src/main/java/com/google/devtools/build/lib/events",
         "//src/main/java/com/google/devtools/build/lib/packages",
-        "//src/main/java/com/google/devtools/build/lib/packages:starlark_exportable",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
         "//src/main/java/com/google/devtools/build/lib/pkgcache:package_options",
diff --git a/src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java b/src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java
--- a/src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java
+++ b/src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java
@@ -31,7 +31,6 @@
 import com.google.devtools.build.lib.events.ExtendedEventHandler;
 import com.google.devtools.build.lib.events.util.EventCollectionApparatus;
 import com.google.devtools.build.lib.packages.BzlInitThreadContext;
-import com.google.devtools.build.lib.packages.StarlarkExportable;
 import com.google.devtools.build.lib.packages.semantics.BuildLanguageOptions;
 import com.google.devtools.build.lib.rules.config.ConfigGlobalLibrary;
 import com.google.devtools.build.lib.rules.config.ConfigStarlarkCommon;
@@ -51,6 +50,8 @@
 import net.starlark.java.eval.StarlarkSemantics;
 import net.starlark.java.eval.StarlarkThread;
 import net.starlark.java.eval.SymbolGenerator;
+import net.starlark.java.syntax.Comment;
+import net.starlark.java.syntax.DocComments;
 import net.starlark.java.syntax.FileOptions;
 import net.starlark.java.syntax.ParserInput;
 import net.starlark.java.syntax.Program;
@@ -182,20 +183,43 @@ public void setFragmentNameToClass(ImmutableMap<String, Class<?>> fragmentNameTo
     this.fragmentNameToClass = fragmentNameToClass;
   }
 
-  private Object newModule(ImmutableMap.Builder<String, Object> predeclared) {
+  private Module newModule(
+      ImmutableMap.Builder<String, Object> predeclared,
+      ImmutableMap<String, DocComments> docCommentsMap,
+      ImmutableList<Comment> unusedDocCommentLines) {
     predeclared.putAll(StarlarkGlobalsImpl.INSTANCE.getFixedBzlToplevels());
     predeclared.put("platform_common", new PlatformCommon());
     predeclared.put("config_common", new ConfigStarlarkCommon());
     predeclared.put("config", new StarlarkConfig());
     Starlark.addMethods(predeclared, new ConfigGlobalLibrary());
 
-    // Return the module's client data. (This one uses dummy values for tests.)
-    return BazelModuleContext.create(
-        BazelModuleKey.createFakeModuleKeyForTesting(label),
-        RepositoryMapping.EMPTY,
-        "test/label.bzl",
-        /* loads= */ ImmutableList.of(),
-        /* bzlTransitiveDigest= */ new byte[0]);
+    BazelModuleContext clientData =
+        BazelModuleContext.create(
+            BazelModuleKey.createFakeModuleKeyForTesting(label),
+            RepositoryMapping.EMPTY,
+            "test/label.bzl",
+            /* loads= */ ImmutableList.of(),
+            /* bzlTransitiveDigest= */ new byte[0],
+            docCommentsMap,
+            unusedDocCommentLines);
+    return Module.withPredeclaredAndData(semantics, predeclared.buildOrThrow(), clientData);
+  }
+
+  /** Creates a new Starlark module for testing, and having no doc comments. */
+  public Module newModule() {
+    return newModule(
+        ImmutableMap.builder(),
+        /* docCommentsMap= */ ImmutableMap.of(),
+        /* unusedDocCommentLines= */ ImmutableList.of());
+  }
+
+  /**
+   * Creates a new Starlark module suitable for testing, with doc comments from the given compiled
+   * {@link Program}.
+   */
+  public Module newModule(Program program) {
+    return newModule(
+        ImmutableMap.builder(), program.getDocCommentsMap(), program.getUnusedDocCommentLines());
   }
 
   /** Sets a thread owner, for cases where the default value of {@code "test"} doesn't work. */
@@ -217,11 +241,7 @@ public StarlarkThread getStarlarkThread() {
 
   public Module getModule() {
     if (this.module == null) {
-      ImmutableMap.Builder<String, Object> predeclared = ImmutableMap.builder();
-      Object clientData = newModule(predeclared);
-      Module module =
-          Module.withPredeclaredAndData(semantics, predeclared.buildOrThrow(), clientData);
-      this.module = module;
+      this.module = newModule();
     }
     return this.module;
   }
diff --git a/src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD b/src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD
--- a/src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD
@@ -67,6 +67,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/cmdline",
         "//src/main/java/com/google/devtools/build/lib/skyframe:bzl_load_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:skyframe_cluster",
+        "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:extractionexception",
         "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:labelrenderer",
         "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:moduleinfoextractor",
         "//src/main/java/com/google/devtools/build/lib/starlarkdocextract:ruleinfoextractor",
@@ -77,5 +78,6 @@ java_test(
         "//third_party:guava",
         "//third_party:junit4",
         "//third_party:truth",
+        "@maven//:com_google_testparameterinjector_test_parameter_injector",
     ],
 )
diff --git a/src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java b/src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java
--- a/src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java
+++ b/src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java
@@ -22,6 +22,7 @@
 import static com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.FunctionParamRole.PARAM_ROLE_KWARGS;
 import static com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.FunctionParamRole.PARAM_ROLE_ORDINARY;
 import static com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.FunctionParamRole.PARAM_ROLE_VARARGS;
+import static org.junit.Assert.assertThrows;
 
 import com.google.common.collect.ImmutableList;
 import com.google.common.collect.ImmutableMap;
@@ -45,6 +46,9 @@
 import com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.ProviderNameGroup;
 import com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.RuleInfo;
 import com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.StarlarkFunctionInfo;
+import com.google.devtools.build.lib.starlarkdocextract.StardocOutputProtos.StarlarkOtherSymbolInfo;
+import com.google.testing.junit.testparameterinjector.TestParameter;
+import com.google.testing.junit.testparameterinjector.TestParameterInjector;
 import java.util.List;
 import java.util.Optional;
 import java.util.function.Predicate;
@@ -55,9 +59,8 @@
 import net.starlark.java.syntax.StarlarkFile;
 import org.junit.Test;
 import org.junit.runner.RunWith;
-import org.junit.runners.JUnit4;
 
-@RunWith(JUnit4.class)
+@RunWith(TestParameterInjector.class)
 public final class ModuleInfoExtractorTest {
 
   private String fakeLabelString = null; // set by exec()
@@ -69,16 +72,17 @@ private Module exec(String... lines) throws Exception {
   private Module execWithOptions(ImmutableList<String> options, String... lines) throws Exception {
     BazelEvaluationTestCase ev = new BazelEvaluationTestCase();
     ev.setSemantics(options.toArray(new String[0]));
-    Module module = ev.getModule();
-    Label fakeLabel = BazelModuleContext.of(module).label();
+    Module moduleForCompilation = ev.newModule();
+    Label fakeLabel = BazelModuleContext.of(moduleForCompilation).label();
     ev.setThreadOwner(keyForBuild(fakeLabel));
     fakeLabelString = fakeLabel.getCanonicalForm();
     ParserInput input = ParserInput.fromLines(lines);
     StarlarkFile file = StarlarkFile.parse(input, FileOptions.DEFAULT);
-    Program program = Program.compileFile(file, module);
+    Program program = Program.compileFile(file, moduleForCompilation);
+    Module moduleForEvaluation = ev.newModule(program);
     BzlLoadFunction.execAndExport(
-        program, fakeLabel, ev.getEventHandler(), module, ev.getStarlarkThread());
-    return ev.getModule();
+        program, fakeLabel, ev.getEventHandler(), moduleForEvaluation, ev.getStarlarkThread());
+    return moduleForEvaluation;
   }
 
   private static ModuleInfoExtractor getExtractor() {
@@ -1245,4 +1249,118 @@ def _my_impl(target, ctx):
     ModuleInfo moduleInfo = getExtractor().extractFrom(module);
     assertThat(moduleInfo.getAspectInfoList()).isEmpty();
   }
+
+  @Test
+  public void starlarkOtherSymbols_extractedIfExportableAndDocumented() throws Exception {
+    Module module =
+        exec(
+            """
+            #: Exportable and documented
+            NAMES = ["foo", "bar"]
+
+            # Exportable but not documented
+            MORE_NAMES = ["baz", "qux"]
+
+            #: Ignored - non-exportable symbol
+            _PRIVATE_CONSTANT = 42
+
+            #: Struct
+            S = struct(answer = _PRIVATE_CONSTANT)
+            """);
+    ModuleInfo moduleInfo = getExtractor().extractFrom(module);
+    assertThat(moduleInfo.getStarlarkOtherSymbolInfoList())
+        .containsExactly(
+            StarlarkOtherSymbolInfo.newBuilder()
+                .setName("NAMES")
+                .setDoc("Exportable and documented")
+                .setTypeName("list")
+                .build(),
+            StarlarkOtherSymbolInfo.newBuilder()
+                .setName("S")
+                .setDoc("Struct")
+                .setTypeName("struct")
+                .build());
+  }
+
+  @Test
+  public void starlarkOtherSymbols_conflictingDocComments(
+      @TestParameter boolean allowUnusedDocComments) throws Exception {
+    Module module =
+        exec(
+            """
+            #: Leading doc comment
+            ANSWER = 42 #: Trailing doc comment
+            """);
+    if (allowUnusedDocComments) {
+      assertThat(
+              getExtractor()
+                  .allowUnusedDocComments()
+                  .extractFrom(module)
+                  .getStarlarkOtherSymbolInfoList())
+          .containsExactly(
+              StarlarkOtherSymbolInfo.newBuilder()
+                  .setName("ANSWER")
+                  .setDoc("Trailing doc comment") // Overrides leading doc comment.
+                  .setTypeName("int")
+                  .build());
+    } else {
+      ExtractionException exception =
+          assertThrows(ExtractionException.class, () -> getExtractor().extractFrom(module));
+      assertThat(exception)
+          .hasMessageThat()
+          .contains("unexpected or conflicting doc comments on line 1");
+    }
+  }
+
+  @Test
+  public void functions_cannotUseDocComments(@TestParameter boolean allowUnusedDocComments)
+      throws Exception {
+    Module module =
+        exec(
+            """
+            def _my_function():
+                pass
+
+            #: Unexpected doc comment
+            MY_FUNCTION_ALIAS = _my_function
+            """);
+    if (allowUnusedDocComments) {
+      assertThat(getExtractor().allowUnusedDocComments().extractFrom(module).getFuncInfoList())
+          .hasSize(1);
+    } else {
+      ExtractionException exception =
+          assertThrows(ExtractionException.class, () -> getExtractor().extractFrom(module));
+      assertThat(exception)
+          .hasMessageThat()
+          .contains(
+              "unexpected doc comment for MY_FUNCTION_ALIAS on line 4; API documentation for a"
+                  + " function must be provided in a docstring at the top of the function body");
+    }
+  }
+
+  @Test
+  public void rules_cannotUseDocComments(@TestParameter boolean allowUnusedDocComments)
+      throws Exception {
+    Module module =
+        exec(
+            """
+            def _impl(ctx):
+                pass
+
+            #: Unexpected doc comment
+            my_rule = rule(implementation = _impl)
+            """);
+    if (allowUnusedDocComments) {
+      assertThat(getExtractor().allowUnusedDocComments().extractFrom(module).getRuleInfoList())
+          .hasSize(1);
+    } else {
+      ExtractionException exception =
+          assertThrows(ExtractionException.class, () -> getExtractor().extractFrom(module));
+      assertThat(exception)
+          .hasMessageThat()
+          .contains(
+              "unexpected doc comment for my_rule on line 4; API documentation for a rule must be"
+                  + " provided in the doc argument to rule()");
+    }
+  }
 }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the tests using Bazel
# Combining all test targets into a single command for efficiency
# Fixed: StarlarkDocExtractTest -> StarlarkDocExtractTests
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=errors \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    --jvmopt=-Djava.lang.Thread.allowVirtualThreads=true \
    //src/test/java/com/google/devtools/build/lib/analysis/actions:BuildInfoFileWriteActionTest \
    //src/test/java/com/google/devtools/build/lib/analysis/starlark:StarlarkCustomCommandLineTest \
    //src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract:StarlarkDocExtractTests \
    //src/test/java/com/google/devtools/build/lib/starlark:StarlarkRuleClassFunctionsTest \
    //src/test/java/com/google/devtools/build/lib/starlarkdocextract:ModuleInfoExtractorTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 61987ae7a644ed90bb764d8926ce382ad2b02b0e \
    "src/test/java/com/google/devtools/build/lib/analysis/actions/BuildInfoFileWriteActionTest.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/starlark/StarlarkCustomCommandLineTest.java" \
    "src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/starlarkdocextract/StarlarkDocExtractTest.java" \
    "src/test/java/com/google/devtools/build/lib/starlark/StarlarkRuleClassFunctionsTest.java" \
    "src/test/java/com/google/devtools/build/lib/starlark/util/BUILD" \
    "src/test/java/com/google/devtools/build/lib/starlark/util/BazelEvaluationTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/starlarkdocextract/BUILD" \
    "src/test/java/com/google/devtools/build/lib/starlarkdocextract/ModuleInfoExtractorTest.java"