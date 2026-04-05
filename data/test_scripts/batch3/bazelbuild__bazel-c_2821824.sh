#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout fcc523b4adc2ff1b2f6b9fb4d7b9fa037adaf526 \
    "src/test/java/com/google/devtools/build/lib/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/BUILD" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/packages/BUILD" \
    "src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/pkgcache/BUILD" \
    "src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java" \
    "src/test/java/com/google/devtools/build/lib/rules/repository/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/BUILD b/src/test/java/com/google/devtools/build/lib/analysis/BUILD
--- a/src/test/java/com/google/devtools/build/lib/analysis/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/analysis/BUILD
@@ -449,7 +449,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/analysis:configured_target_value",
         "//src/main/java/com/google/devtools/build/lib/analysis/config:build_configuration",
         "//src/main/java/com/google/devtools/build/lib/cmdline",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_dirtiness_checker",
         "//src/main/java/com/google/devtools/build/lib/skyframe:skyframe_executor_repository_helpers_holder",
         "//src/main/java/com/google/devtools/build/lib/vfs:pathfragment",
         "//src/test/java/com/google/devtools/build/lib/analysis/util",
@@ -808,7 +808,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/actions:commandline_item",
         "//src/main/java/com/google/devtools/build/lib/analysis:analysis_cluster",
         "//src/main/java/com/google/devtools/build/lib/analysis:repo_mapping_manifest_action",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_dirtiness_checker",
         "//src/main/java/com/google/devtools/build/lib/skyframe:skyframe_executor_repository_helpers_holder",
         "//src/main/java/com/google/devtools/build/lib/util",
         "//src/main/java/com/google/devtools/build/lib/vfs:pathfragment",
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java b/src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java
@@ -43,6 +43,7 @@
 import com.google.devtools.build.lib.packages.util.MockPythonSupport;
 import com.google.devtools.build.lib.packages.util.MockToolsConfig;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.runtime.BlazeModule;
 import com.google.devtools.build.lib.skyframe.ClientEnvironmentFunction;
 import com.google.devtools.build.lib.skyframe.PrecomputedValue;
@@ -226,9 +227,8 @@ public ImmutableList<PrecomputedValue.Injected> getPrecomputedValues() {
         PrecomputedValue.injected(
             RepositoryMappingFunction.REPOSITORY_OVERRIDES, ImmutableMap.of()),
         PrecomputedValue.injected(
-            RepositoryDelegatorFunction.FORCE_FETCH,
-            RepositoryDelegatorFunction.FORCE_FETCH_DISABLED),
-        PrecomputedValue.injected(RepositoryDelegatorFunction.VENDOR_DIRECTORY, Optional.empty()),
+            RepositoryDirectoryValue.FORCE_FETCH, RepositoryDirectoryValue.FORCE_FETCH_DISABLED),
+        PrecomputedValue.injected(RepositoryDirectoryValue.VENDOR_DIRECTORY, Optional.empty()),
         PrecomputedValue.injected(ModuleFileFunction.REGISTRIES, ImmutableSet.of()),
         PrecomputedValue.injected(ModuleFileFunction.IGNORE_DEV_DEPS, false),
         PrecomputedValue.injected(ModuleFileFunction.INJECTED_REPOSITORIES, ImmutableMap.of()),
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/util/BUILD b/src/test/java/com/google/devtools/build/lib/analysis/util/BUILD
--- a/src/test/java/com/google/devtools/build/lib/analysis/util/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/analysis/util/BUILD
@@ -98,6 +98,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages:rule_class_utils",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/rules/java:java-compilation",
         "//src/main/java/com/google/devtools/build/lib/shell",
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java b/src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java
@@ -143,7 +143,7 @@
 import com.google.devtools.build.lib.pkgcache.PackageManager;
 import com.google.devtools.build.lib.pkgcache.PackageOptions;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
-import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.runtime.QuiescingExecutorsImpl;
 import com.google.devtools.build.lib.skyframe.AspectKeyCreator;
 import com.google.devtools.build.lib.skyframe.AspectKeyCreator.AspectKey;
@@ -519,7 +519,7 @@ private void setUpSkyframe() {
     skyframeExecutor.injectExtraPrecomputedValues(
         ImmutableList.of(
             PrecomputedValue.injected(
-                RepositoryDelegatorFunction.VENDOR_DIRECTORY, Optional.empty())));
+                RepositoryDirectoryValue.VENDOR_DIRECTORY, Optional.empty())));
   }
 
   protected void setPackageOptions(String... options) throws Exception {
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD
--- a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD
@@ -52,6 +52,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:bzl_load_cycle_reporter",
         "//src/main/java/com/google/devtools/build/lib/skyframe:bzl_load_value",
@@ -66,8 +67,6 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/skyframe:repository_mapping_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:sky_functions",
         "//src/main/java/com/google/devtools/build/lib/skyframe:skyframe_cluster",
-        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/autocodec",
-        "//src/main/java/com/google/devtools/build/lib/starlarkbuildapi/repository",
         "//src/main/java/com/google/devtools/build/lib/util:filetype",
         "//src/main/java/com/google/devtools/build/lib/util/io",
         "//src/main/java/com/google/devtools/build/lib/vfs",
@@ -78,12 +77,10 @@ java_library(
         "//src/main/java/net/starlark/java/eval",
         "//src/main/java/net/starlark/java/syntax",
         "//src/test/java/com/google/devtools/build/lib/analysis/util",
-        "//src/test/java/com/google/devtools/build/lib/packages:testutil",
         "//src/test/java/com/google/devtools/build/lib/skyframe/util:SkyframeExecutorTestUtils",
         "//src/test/java/com/google/devtools/build/lib/testutil",
         "//src/test/java/com/google/devtools/build/lib/testutil:JunitUtils",
         "//third_party:auto_value",
-        "//third_party:error_prone_annotations",
         "//third_party:gson",
         "//third_party:guava",
         "//third_party:jsr305",
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java
--- a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java
+++ b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java
@@ -36,6 +36,7 @@
 import com.google.devtools.build.lib.clock.BlazeClock;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.BazelSkyframeExecutorConstants;
 import com.google.devtools.build.lib.skyframe.BzlmodRepoRuleFunction;
 import com.google.devtools.build.lib.skyframe.ClientEnvironmentFunction;
@@ -202,9 +203,9 @@ private void setUpWithBuiltinModules(ImmutableMap<String, NonRegistryOverride> b
 
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
 
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, packageLocator.get());
     PrecomputedValue.REPO_ENV.set(differencer, ImmutableMap.of());
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java
--- a/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java
@@ -40,6 +40,7 @@
 import com.google.devtools.build.lib.packages.semantics.BuildLanguageOptions;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.BazelSkyframeExecutorConstants;
 import com.google.devtools.build.lib.skyframe.BzlmodRepoRuleFunction;
 import com.google.devtools.build.lib.skyframe.ClientEnvironmentFunction;
@@ -183,9 +184,9 @@ private void setUpWithBuiltinModules(ImmutableMap<String, NonRegistryOverride> b
 
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
 
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, packageLocator.get());
     PrecomputedValue.REPO_ENV.set(differencer, ImmutableMap.of());
diff --git a/src/test/java/com/google/devtools/build/lib/packages/BUILD b/src/test/java/com/google/devtools/build/lib/packages/BUILD
--- a/src/test/java/com/google/devtools/build/lib/packages/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/packages/BUILD
@@ -160,7 +160,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules/cpp",
         "//src/main/java/com/google/devtools/build/lib/rules/proto",
         "//src/main/java/com/google/devtools/build/lib/skyframe:precomputed_value",
diff --git a/src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java b/src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java
--- a/src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java
+++ b/src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java
@@ -40,7 +40,7 @@
 import com.google.devtools.build.lib.pkgcache.PackageManager;
 import com.google.devtools.build.lib.pkgcache.PackageOptions;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
-import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.runtime.QuiescingExecutorsImpl;
 import com.google.devtools.build.lib.skyframe.BazelSkyframeExecutorConstants;
 import com.google.devtools.build.lib.skyframe.PrecomputedValue;
@@ -216,7 +216,7 @@ private SkyframeExecutor createSkyframeExecutor() {
     skyframeExecutor.injectExtraPrecomputedValues(
         ImmutableList.of(
             PrecomputedValue.injected(
-                RepositoryDelegatorFunction.VENDOR_DIRECTORY, Optional.empty())));
+                RepositoryDirectoryValue.VENDOR_DIRECTORY, Optional.empty())));
     skyframeExecutor.injectExtraPrecomputedValues(
         ImmutableList.of(
             PrecomputedValue.injected(
diff --git a/src/test/java/com/google/devtools/build/lib/pkgcache/BUILD b/src/test/java/com/google/devtools/build/lib/pkgcache/BUILD
--- a/src/test/java/com/google/devtools/build/lib/pkgcache/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/pkgcache/BUILD
@@ -83,8 +83,6 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/cmdline",
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
-        "//src/main/java/com/google/devtools/build/lib/skyframe:precomputed_value",
         "//src/main/java/com/google/devtools/build/lib/vfs",
         "//src/main/java/com/google/devtools/build/lib/vfs:pathfragment",
         "//src/test/java/com/google/devtools/build/lib/packages:testutil",
@@ -111,8 +109,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
-        "//src/main/java/com/google/devtools/build/lib/skyframe:broken_diff_awareness_exception",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:diff_awareness",
         "//src/main/java/com/google/devtools/build/lib/skyframe:precomputed_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:repository_mapping_function",
diff --git a/src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java b/src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java
--- a/src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java
+++ b/src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java
@@ -43,7 +43,7 @@
 import com.google.devtools.build.lib.packages.Target;
 import com.google.devtools.build.lib.packages.semantics.BuildLanguageOptions;
 import com.google.devtools.build.lib.packages.util.LoadingMock;
-import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.runtime.QuiescingExecutorsImpl;
 import com.google.devtools.build.lib.skyframe.BazelSkyframeExecutorConstants;
 import com.google.devtools.build.lib.skyframe.DiffAwareness;
@@ -525,7 +525,7 @@ def _impl(ctx):
       skyframeExecutor.injectExtraPrecomputedValues(
           ImmutableList.of(
               PrecomputedValue.injected(
-                  RepositoryDelegatorFunction.VENDOR_DIRECTORY, Optional.empty()),
+                  RepositoryDirectoryValue.VENDOR_DIRECTORY, Optional.empty()),
               PrecomputedValue.injected(
                   RepositoryMappingFunction.REPOSITORY_OVERRIDES, ImmutableMap.of())));
       BuildLanguageOptions buildLanguageOptions = Options.getDefaults(BuildLanguageOptions.class);
diff --git a/src/test/java/com/google/devtools/build/lib/rules/repository/BUILD b/src/test/java/com/google/devtools/build/lib/rules/repository/BUILD
--- a/src/test/java/com/google/devtools/build/lib/rules/repository/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/rules/repository/BUILD
@@ -33,6 +33,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages:autoload_symbols",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repo_recorded_input",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_dirtiness_checker",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:bzl_compile",
diff --git a/src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java b/src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java
--- a/src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java
+++ b/src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java
@@ -233,10 +233,10 @@ public void setupDelegator() throws Exception {
     overrideDirectory = scratch.dir("/foo");
     scratch.file("/foo/REPO.bazel");
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.IS_VENDOR_COMMAND.set(differencer, false);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.IS_VENDOR_COMMAND.set(differencer, false);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, pkgLocator.get());
     StarlarkSemantics semantics = StarlarkSemantics.DEFAULT;
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, semantics);
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java
@@ -33,7 +33,7 @@
 import com.google.devtools.build.lib.packages.semantics.BuildLanguageOptions;
 import com.google.devtools.build.lib.pkgcache.PackageOptions;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
-import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.runtime.QuiescingExecutorsImpl;
 import com.google.devtools.build.lib.skyframe.packages.PackageFactoryBuilderWithSkyframeForTesting;
 import com.google.devtools.build.lib.testing.common.FakeOptions;
@@ -324,10 +324,10 @@ private void initEvaluator()
             PrecomputedValue.injected(
                 RepositoryMappingFunction.REPOSITORY_OVERRIDES, ImmutableMap.of()),
             PrecomputedValue.injected(
-                RepositoryDelegatorFunction.FORCE_FETCH,
-                RepositoryDelegatorFunction.FORCE_FETCH_DISABLED),
+                RepositoryDirectoryValue.FORCE_FETCH,
+                RepositoryDirectoryValue.FORCE_FETCH_DISABLED),
             PrecomputedValue.injected(
-                RepositoryDelegatorFunction.VENDOR_DIRECTORY, Optional.empty())));
+                RepositoryDirectoryValue.VENDOR_DIRECTORY, Optional.empty())));
     OptionsParser parser =
         OptionsParser.builder().optionsClasses(BuildLanguageOptions.class).build();
     parser.parse(TestConstants.PRODUCT_SPECIFIC_BUILD_LANG_OPTIONS);
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
@@ -122,7 +122,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:collect_packages_under_directory_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:precomputed_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:repository_mapping_function",
@@ -533,7 +533,7 @@ java_library(
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages:globber",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:directory_listing_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:directory_listing_state_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:file_function",
@@ -1049,6 +1049,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/io:file_symlink_infinite_expansion_uniqueness_function",
         "//src/main/java/com/google/devtools/build/lib/io:inconsistent_filesystem_exception",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:file_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:package_lookup_function",
@@ -1133,6 +1134,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/events",
         "//src/main/java/com/google/devtools/build/lib/io:file_symlink_cycle_uniqueness_function",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:containing_package_lookup_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:containing_package_lookup_value",
@@ -1386,6 +1388,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/io:file_symlink_cycle_uniqueness_function",
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
+        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_directory_value",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:directory_listing_function",
         "//src/main/java/com/google/devtools/build/lib/skyframe:file_function",
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java
@@ -31,6 +31,7 @@
 import com.google.devtools.build.lib.io.FileSymlinkCycleUniquenessFunction;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.ContainingPackageLookupValue.ContainingPackage;
 import com.google.devtools.build.lib.skyframe.ContainingPackageLookupValue.NoContainingPackage;
 import com.google.devtools.build.lib.skyframe.ExternalFilesHelper.ExternalFileAction;
@@ -150,9 +151,9 @@ public SkyValue compute(SkyKey skyKey, Environment env) {
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, pkgLocator.get());
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
   }
 
   private ContainingPackageLookupValue lookupContainingPackage(String packageName)
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java
@@ -52,6 +52,7 @@
 import com.google.devtools.build.lib.io.InconsistentFilesystemException;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.ExternalFilesHelper.ExternalFileAction;
 import com.google.devtools.build.lib.skyframe.PackageLookupFunction.CrossRepositoryLabelViolationStrategy;
 import com.google.devtools.build.lib.skyframe.serialization.testutils.FsUtils;
@@ -212,9 +213,9 @@ public SkyValue compute(SkyKey skyKey, Environment env) {
     PrecomputedValue.BUILD_ID.set(differencer, UUID.randomUUID());
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, pkgLocator);
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
     return evaluator;
   }
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java b/src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java
@@ -40,7 +40,7 @@
 import com.google.devtools.build.lib.packages.Globber.Operation;
 import com.google.devtools.build.lib.packages.RuleClassProvider;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
-import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.ExternalFilesHelper.ExternalFileAction;
 import com.google.devtools.build.lib.skyframe.PackageLookupFunction.CrossRepositoryLabelViolationStrategy;
 import com.google.devtools.build.lib.testutil.ManualClock;
@@ -122,7 +122,7 @@ public final void setUp() throws Exception {
     PrecomputedValue.BUILD_ID.set(differencer, UUID.randomUUID());
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, pkgLocator.get());
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
 
     createTestFiles();
   }
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java
@@ -36,6 +36,7 @@
 import com.google.devtools.build.lib.packages.RuleClassProvider;
 import com.google.devtools.build.lib.pkgcache.PathPackageLocator;
 import com.google.devtools.build.lib.rules.repository.RepositoryDelegatorFunction;
+import com.google.devtools.build.lib.rules.repository.RepositoryDirectoryValue;
 import com.google.devtools.build.lib.skyframe.ExternalFilesHelper.ExternalFileAction;
 import com.google.devtools.build.lib.skyframe.PackageLookupFunction.CrossRepositoryLabelViolationStrategy;
 import com.google.devtools.build.lib.skyframe.PackageLookupValue.ErrorReason;
@@ -161,9 +162,9 @@ public SkyValue compute(SkyKey skyKey, Environment env) {
     PrecomputedValue.PATH_PACKAGE_LOCATOR.set(differencer, pkgLocator.get());
     PrecomputedValue.STARLARK_SEMANTICS.set(differencer, StarlarkSemantics.DEFAULT);
     RepositoryMappingFunction.REPOSITORY_OVERRIDES.set(differencer, ImmutableMap.of());
-    RepositoryDelegatorFunction.FORCE_FETCH.set(
-        differencer, RepositoryDelegatorFunction.FORCE_FETCH_DISABLED);
-    RepositoryDelegatorFunction.VENDOR_DIRECTORY.set(differencer, Optional.empty());
+    RepositoryDirectoryValue.FORCE_FETCH.set(
+        differencer, RepositoryDirectoryValue.FORCE_FETCH_DISABLED);
+    RepositoryDirectoryValue.VENDOR_DIRECTORY.set(differencer, Optional.empty());
   }
 
   protected PackageLookupValue lookupPackage(String packageName) throws InterruptedException {
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD
@@ -87,8 +87,6 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/analysis/config:fragment",
         "//src/main/java/com/google/devtools/build/lib/analysis/config:fragment_options",
         "//src/main/java/com/google/devtools/build/lib/cmdline",
-        "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
-        "//src/main/java/com/google/devtools/build/lib/skyframe:precomputed_value",
         "//src/main/java/com/google/devtools/build/lib/skyframe:skyframe_cluster",
         "//src/main/java/com/google/devtools/build/lib/skyframe/config",
         "//src/main/java/com/google/devtools/build/lib/skyframe/config:exceptions",
@@ -99,7 +97,6 @@ java_test(
         "//src/test/java/com/google/devtools/build/lib/analysis/util",
         "//src/test/java/com/google/devtools/build/lib/skyframe:testutil",
         "//src/test/java/com/google/devtools/build/lib/testutil",
-        "//third_party:guava",
         "//third_party:junit4",
         "//third_party:truth",
     ],
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
    //src/test/java/com/google/devtools/build/lib/analysis:all \
    //src/test/java/com/google/devtools/build/lib/analysis/util:all \
    //src/test/java/com/google/devtools/build/lib/bazel/bzlmod:BzlmodTests \
    //src/test/java/com/google/devtools/build/lib/packages:PackagesTests \
    //src/test/java/com/google/devtools/build/lib/pkgcache:all \
    //src/test/java/com/google/devtools/build/lib/rules/repository:RepositoryTests \
    //src/test/java/com/google/devtools/build/lib/skyframe:all \
    //src/test/java/com/google/devtools/build/lib/skyframe/config:all

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout fcc523b4adc2ff1b2f6b9fb4d7b9fa037adaf526 \
    "src/test/java/com/google/devtools/build/lib/analysis/BUILD" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/AnalysisMock.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/BUILD" \
    "src/test/java/com/google/devtools/build/lib/analysis/util/BuildViewTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/BUILD" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/DiscoveryTest.java" \
    "src/test/java/com/google/devtools/build/lib/bazel/bzlmod/ModuleFileFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/packages/BUILD" \
    "src/test/java/com/google/devtools/build/lib/packages/util/PackageLoadingTestCase.java" \
    "src/test/java/com/google/devtools/build/lib/pkgcache/BUILD" \
    "src/test/java/com/google/devtools/build/lib/pkgcache/IncrementalLoadingTest.java" \
    "src/test/java/com/google/devtools/build/lib/rules/repository/BUILD" \
    "src/test/java/com/google/devtools/build/lib/rules/repository/RepositoryDelegatorTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/AbstractCollectPackagesUnderDirectoryTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/BUILD" \
    "src/test/java/com/google/devtools/build/lib/skyframe/ContainingPackageLookupFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/FileFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/GlobTestBase.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/PackageLookupFunctionTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/config/BUILD"