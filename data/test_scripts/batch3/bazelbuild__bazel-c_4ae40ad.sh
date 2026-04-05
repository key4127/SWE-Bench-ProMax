#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout ebd5a01cf1bcc3e02dfb2d96be4c9d4e41ecf317 "src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java" "src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java" "src/test/java/com/google/devtools/build/lib/skyframe/BUILD" "src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java b/src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java
--- a/src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java
+++ b/src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java
@@ -1770,7 +1770,7 @@ public void testImplicitVisibility_worksWithPackageDefaultVisibility() throws Ex
     scratch.file("lib/BUILD");
     scratch.file(
         "lib/macro.bzl",
-        """
+"""
 def _impl(name, visibility):
     native.cc_library(name = name, visibility = native.package_default_visibility())
 my_macro = macro(implementation = _impl)
@@ -1799,7 +1799,7 @@ public void testPackageDefaultVisibility_playsWellWithPrivateVisibility() throws
     scratch.file("lib/BUILD");
     scratch.file(
         "lib/macro.bzl",
-        """
+"""
 def _impl(name, visibility):
     native.cc_library(name = name, visibility = native.package_default_visibility())
 my_macro = macro(implementation = _impl)
@@ -1823,7 +1823,7 @@ public void testPackageDefaultVisibility_succeedsIfNoDefaultVisibilitySet() thro
     scratch.file("lib/BUILD");
     scratch.file(
         "lib/macro.bzl",
-        """
+"""
 def _impl(name, visibility):
     native.cc_library(name = name, visibility = native.package_default_visibility())
 my_macro = macro(implementation = _impl)
diff --git a/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java b/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
--- a/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
+++ b/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
@@ -228,9 +228,10 @@ public void packagePieceForMacroBuilder_basicFunctionality() throws Exception {
   }
 
   private PackagePiece.ForBuildFile.Builder minimalBuildFilePieceBuilder(String name) {
+    PackageIdentifier pkgId = PackageIdentifier.createInMainRepo(name);
     return PackagePiece.ForBuildFile.newBuilder(
             PackageSettings.DEFAULTS,
-            PackageIdentifier.createInMainRepo(name),
+            new PackagePieceIdentifier.ForBuildFile(pkgId, Label.createUnvalidated(pkgId, "BUILD")),
             /* filename= */ RootedPath.toRootedPath(
                 Root.fromPath(fileSystem.getPath("/irrelevantRoot")),
                 PathFragment.create(name + "/BUILD")),
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/BUILD
@@ -1223,6 +1223,7 @@ java_test(
         "//src/main/java/com/google/devtools/build/lib/events",
         "//src/main/java/com/google/devtools/build/lib/packages",
         "//src/main/java/com/google/devtools/build/lib/packages:globber",
+        "//src/main/java/com/google/devtools/build/lib/packages:package_piece_identifier",
         "//src/main/java/com/google/devtools/build/lib/packages/semantics",
         "//src/main/java/com/google/devtools/build/lib/pkgcache",
         "//src/main/java/com/google/devtools/build/lib/rules:repository/repository_function",
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java
@@ -48,8 +48,11 @@
 import com.google.devtools.build.lib.packages.NoSuchTargetException;
 import com.google.devtools.build.lib.packages.Package;
 import com.google.devtools.build.lib.packages.PackageOverheadEstimator;
+import com.google.devtools.build.lib.packages.PackagePiece;
+import com.google.devtools.build.lib.packages.PackagePieceIdentifier;
 import com.google.devtools.build.lib.packages.PackageValidator;
 import com.google.devtools.build.lib.packages.PackageValidator.InvalidPackageException;
+import com.google.devtools.build.lib.packages.Packageoid;
 import com.google.devtools.build.lib.packages.RuleVisibility;
 import com.google.devtools.build.lib.packages.semantics.BuildLanguageOptions;
 import com.google.devtools.build.lib.pkgcache.PackageOptions;
@@ -86,6 +89,7 @@
 import com.google.devtools.build.skyframe.SkyKey;
 import com.google.devtools.build.skyframe.SkyValue;
 import com.google.devtools.common.options.Options;
+import com.google.errorprone.annotations.CanIgnoreReturnValue;
 import com.google.testing.junit.testparameterinjector.TestParameter;
 import com.google.testing.junit.testparameterinjector.TestParameterInjector;
 import java.io.IOException;
@@ -127,6 +131,10 @@ public class PackageFunctionTest extends BuildViewTestCase {
 
   @TestParameter private boolean globUnderSingleDep;
 
+  // If true, use PackagePieceIdentifier.ForBuildFile as the key, and retrieve the result as a
+  // PackagePiece.ForBuildFile.
+  @TestParameter private boolean computePackagePiece;
+
   private final CustomInMemoryFs fs = new CustomInMemoryFs(new ManualClock());
 
   private void preparePackageLoading(Path... roots) throws Exception {
@@ -169,48 +177,67 @@ protected PackageOverheadEstimator getPackageOverheadEstimator() {
     return mockPackageOverheadEstimator;
   }
 
-  private Package validPackageWithoutErrors(SkyKey skyKey) throws InterruptedException {
-    return validPackageInternal(skyKey, /*checkPackageError=*/ true);
+  @CanIgnoreReturnValue
+  private Packageoid validPackageoidWithoutErrors(String pkg) throws InterruptedException {
+    return validPackageoidInternal(pkg, /* checkError= */ true);
   }
 
-  private Package validPackage(SkyKey skyKey) throws InterruptedException {
-    return validPackageInternal(skyKey, /*checkPackageError=*/ false);
+  @CanIgnoreReturnValue
+  private Packageoid validPackageoid(String pkg) throws InterruptedException {
+    return validPackageoidInternal(pkg, /* checkError= */ false);
   }
 
-  private Package validPackageInternal(SkyKey skyKey, boolean checkPackageError)
+  private Packageoid validPackageoidInternal(String pkg, boolean checkError)
       throws InterruptedException {
+    SkyKey skyKey = getSkyKey(pkg);
     SkyframeExecutor skyframeExecutor = getSkyframeExecutor();
     skyframeExecutor.injectExtraPrecomputedValues(
         ImmutableList.of(
             PrecomputedValue.injected(
                 RepositoryDelegatorFunction.RESOLVED_FILE_INSTEAD_OF_WORKSPACE, Optional.empty())));
-    EvaluationResult<PackageValue> result =
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(
-            skyframeExecutor, skyKey, /*keepGoing=*/ false, reporter);
+            skyframeExecutor, skyKey, /* keepGoing= */ false, reporter);
     if (result.hasError()) {
       fail(result.getError(skyKey).getException().getMessage());
     }
-    PackageValue value = result.get(skyKey);
-    if (checkPackageError) {
-      assertThat(value.getPackage().containsErrors()).isFalse();
+    Packageoid value = result.get(skyKey).getPackageoid();
+    if (skyKey instanceof PackageIdentifier) {
+      assertThat(value).isInstanceOf(Package.class);
+    } else {
+      assertThat(value).isInstanceOf(PackagePiece.ForBuildFile.class);
+    }
+    if (checkError) {
+      assertThat(value.containsErrors()).isFalse();
     }
-    return value.getPackage();
+    return value;
+  }
+
+  private static PackagePieceIdentifier.ForBuildFile getPackagePieceId(String pkg) {
+    PackageIdentifier pkgId = PackageIdentifier.createInMainRepo(pkg);
+    return new PackagePieceIdentifier.ForBuildFile(pkgId, Label.createUnvalidated(pkgId, "BUILD"));
   }
 
-  private Exception evaluatePackageToException(String pkg) throws Exception {
-    return evaluatePackageToException(pkg, /*keepGoing=*/ false);
+  private SkyKey getSkyKey(String pkg) {
+    return computePackagePiece ? getPackagePieceId(pkg) : PackageIdentifier.createInMainRepo(pkg);
+  }
+
+  @CanIgnoreReturnValue
+  private Exception evaluatePackageoidToException(String pkg) throws Exception {
+    return evaluatePackageoidToException(pkg, /* keepGoing= */ false);
   }
 
   /**
-   * Helper that evaluates the given package and returns the expected exception.
+   * Helper that evaluates the given package or package piece and returns the expected exception.
    *
    * <p>Disables the failFastHandler as a side-effect.
    */
-  private Exception evaluatePackageToException(String pkg, boolean keepGoing) throws Exception {
+  @CanIgnoreReturnValue
+  private Exception evaluatePackageoidToException(String pkg, boolean keepGoing) throws Exception {
     reporter.removeHandler(failFastHandler);
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo(pkg);
-    EvaluationResult<PackageValue> result =
+    SkyKey skyKey = getSkyKey(pkg);
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(getSkyframeExecutor(), skyKey, keepGoing, reporter);
     assertThat(result.hasError()).isTrue();
     return result.getError(skyKey).getException();
@@ -227,12 +254,46 @@ public final void initializeSkyframeExecutor() throws Exception {
 
   @Test
   public void testValidPackage() throws Exception {
-    scratch.file("pkg/BUILD");
-    validPackageWithoutErrors(PackageIdentifier.createInMainRepo("pkg"));
+    scratch.file("pkg/BUILD", "cc_library(name = 'foo')");
+    Packageoid pkg = validPackageoidWithoutErrors("pkg");
+    assertThat(pkg.getTargets()).containsKey("foo");
+  }
+
+  @Test
+  public void symbolicMacroExpansion_onlyInFullPackages() throws Exception {
+    scratch.file(
+        "pkg/macro.bzl",
+        """
+        def legacy(name, visibility = None, **kwargs):
+            native.cc_library(name = name, visibility = visibility, **kwargs)
+
+        symbolic = macro(
+            implementation = legacy,
+        )
+        """);
+    scratch.file(
+        "pkg/BUILD",
+        """
+        load(":macro.bzl", "legacy", "symbolic")
+        legacy(name = "target_in_legacy_macro")
+        symbolic(name = "target_in_symbolic_macro")
+        """);
+    Packageoid pkg = validPackageoidWithoutErrors("pkg");
+    assertThat(pkg.getTargets()).containsKey("target_in_legacy_macro");
+    if (computePackagePiece) {
+      assertThat(pkg.getTargets()).doesNotContainKey("target_in_symbolic_macro");
+    } else {
+      assertThat(pkg.getTargets()).containsKey("target_in_symbolic_macro");
+    }
   }
 
   @Test
   public void testInvalidPackage() throws Exception {
+    if (computePackagePiece) {
+      // TODO(https://github.com/bazelbuild/bazel/issues/23852): test requires package piece
+      // validation.
+      return;
+    }
     scratch.file("pkg/BUILD", "filegroup(name='foo', srcs=['foo.sh'])");
     scratch.file("pkg/foo.sh");
 
@@ -250,14 +311,19 @@ public void testInvalidPackage() throws Exception {
 
     invalidatePackages();
 
-    Exception ex = evaluatePackageToException("pkg");
+    Exception ex = evaluatePackageoidToException("pkg");
     assertThat(ex).isInstanceOf(InvalidPackageException.class);
     assertThat(ex).hasMessageThat().contains("no such package 'pkg': no good");
     assertContainsEvent("warning event");
   }
 
   @Test
   public void testPackageOverheadPassedToValidationLogic() throws Exception {
+    if (computePackagePiece) {
+      // TODO(https://github.com/bazelbuild/bazel/issues/23852): test requires package piece
+      // validation.
+      return;
+    }
     scratch.file("pkg/BUILD", "# Contents doesn't matter, it's all fake");
 
     when(mockPackageOverheadEstimator.estimatePackageOverhead(any(Package.class)))
@@ -268,10 +334,7 @@ public void testPackageOverheadPassedToValidationLogic() throws Exception {
     reset(mockPackageValidator);
 
     SkyframeExecutorTestUtils.evaluate(
-        getSkyframeExecutor(),
-        PackageIdentifier.createInMainRepo("pkg"),
-        /* keepGoing= */ false,
-        reporter);
+        getSkyframeExecutor(), getSkyKey("pkg"), /* keepGoing= */ false, reporter);
 
     verify(mockPackageValidator).validate(packageCaptor.capture(), any(ExtendedEventHandler.class));
     List<Package> packages = packageCaptor.getAllValues();
@@ -280,6 +343,11 @@ public void testPackageOverheadPassedToValidationLogic() throws Exception {
 
   @Test
   public void testSkyframeExecutorClearedPackagesResultsInReload() throws Exception {
+    if (computePackagePiece) {
+      // TODO(https://github.com/bazelbuild/bazel/issues/23852): test requires package piece
+      // validation.
+      return;
+    }
     scratch.file("pkg/BUILD", "filegroup(name='foo', srcs=['foo.sh'])");
     scratch.file("pkg/foo.sh");
 
@@ -297,17 +365,17 @@ public void testSkyframeExecutorClearedPackagesResultsInReload() throws Exceptio
         .when(mockPackageValidator)
         .validate(any(Package.class), any(ExtendedEventHandler.class));
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-    EvaluationResult<PackageValue> result1 =
+    SkyKey skyKey = getSkyKey("pkg");
+    EvaluationResult<PackageoidValue> result1 =
         SkyframeExecutorTestUtils.evaluate(
-            getSkyframeExecutor(), skyKey, /*keepGoing=*/ false, reporter);
+            getSkyframeExecutor(), skyKey, /* keepGoing= */ false, reporter);
     assertThatEvaluationResult(result1).hasNoError();
 
     skyframeExecutor.clearLoadedPackages();
 
-    EvaluationResult<PackageValue> result2 =
+    EvaluationResult<PackageoidValue> result2 =
         SkyframeExecutorTestUtils.evaluate(
-            getSkyframeExecutor(), skyKey, /*keepGoing=*/ false, reporter);
+            getSkyframeExecutor(), skyKey, /* keepGoing= */ false, reporter);
     assertThatEvaluationResult(result2).hasNoError();
 
     assertThat(validationCount.get()).isEqualTo(2);
@@ -370,7 +438,7 @@ public long getNodeId() {
     differencer.inject(
         ImmutableMap.of(FileStateValue.key(pkgRootedPath), Delta.justNew(fooDirValue)));
 
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
     String msg = ex.getMessage();
     assertThat(msg).contains("Inconsistent filesystem operations");
     assertThat(msg)
@@ -413,7 +481,7 @@ public void testPropagatesFilesystemInconsistencies_globbing() throws Exception
                 DirectoryListingStateValue.create(
                     ImmutableList.of(new Dirent("baz", Dirent.Type.DIRECTORY))))));
 
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
     String msg = ex.getMessage();
     assertThat(msg).contains("Inconsistent filesystem operations");
     assertThat(msg).contains("/workspace/foo/bar/baz is no longer an existing directory");
@@ -434,7 +502,7 @@ public void testDiscrepancyBetweenGlobbingErrors() throws Exception {
     fs.scheduleMakeUnreadableAfterReaddir(barDir);
 
     Exception ex =
-        evaluatePackageToException(
+        evaluatePackageoidToException(
             "foo",
             // Use --keep_going, not --nokeep_going, semantics so as to exercise the situation we
             // want to exercise.
@@ -444,7 +512,7 @@ public void testDiscrepancyBetweenGlobbingErrors() throws Exception {
             // PackageValue node again, meaning we would do non-Skyframe globbing except this time
             // non-Skyframe globbing would encounter the io error, meaning there actually wouldn't
             // be a discrepancy.
-            /*keepGoing=*/ true);
+            /* keepGoing= */ true);
     String msg = ex.getMessage();
     assertThat(msg).contains("Inconsistent filesystem operations");
     assertThat(msg).contains("Encountered error '/workspace/foo/bar (Permission denied)'");
@@ -461,8 +529,7 @@ public void testGlobOrderStable() throws Exception {
     scratch.file("foo/b.txt");
     scratch.file("foo/c/c.txt");
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     assertThat((Iterable<Label>) pkg.getTarget("foo").getAssociatedRule().getAttr("srcs"))
         .containsExactly(
             Label.parseCanonicalUnchecked("//foo:b.txt"),
@@ -474,7 +541,7 @@ public void testGlobOrderStable() throws Exception {
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/d.txt")).build(),
             Root.fromPath(rootDirectory));
-    pkg = validPackageWithoutErrors(skyKey);
+    pkg = validPackageoidWithoutErrors("foo");
     assertThat((Iterable<Label>) pkg.getTarget("foo").getAssociatedRule().getAttr("srcs"))
         .containsExactly(
             Label.parseCanonicalUnchecked("//foo:b.txt"),
@@ -489,24 +556,23 @@ public void testGlobOrderStableWithNonSkyframeAndSkyframeComponents() throws Exc
     scratch.file("foo/b.txt");
     scratch.file("foo/a.config");
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:b.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:b.txt");
     scratch.overwriteFile(
         "foo/BUILD", "filegroup(name = 'foo', srcs = glob(['*.txt', '*.config']))");
     getSkyframeExecutor()
         .invalidateFilesUnderPathForTesting(
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:a.config", "//foo:b.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:a.config", "//foo:b.txt");
     scratch.overwriteFile(
         "foo/BUILD", "filegroup(name = 'foo', srcs = glob(['*.txt', '*.config'])) # comment");
     getSkyframeExecutor()
         .invalidateFilesUnderPathForTesting(
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:a.config", "//foo:b.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:a.config", "//foo:b.txt");
     getSkyframeExecutor().resetEvaluator();
     PackageOptions packageOptions = Options.getDefaults(PackageOptions.class);
     packageOptions.defaultVisibility = RuleVisibility.PUBLIC;
@@ -526,24 +592,23 @@ public void testGlobOrderStableWithNonSkyframeAndSkyframeComponents() throws Exc
             tsgm);
     getSkyframeExecutor().injectExtraPrecomputedValues(analysisMock.getPrecomputedValues());
     getSkyframeExecutor().setActionEnv(ImmutableMap.of());
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:a.config", "//foo:b.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:a.config", "//foo:b.txt");
   }
 
   @Test
   public void globEscapesAt() throws Exception {
     scratch.file("foo/BUILD", "filegroup(name = 'foo', srcs = glob(['*.txt']))");
     scratch.file("foo/@f.txt");
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:@f.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:@f.txt");
 
     scratch.overwriteFile("foo/BUILD", "filegroup(name = 'foo', srcs = glob(['*.txt'])) # comment");
     getSkyframeExecutor()
         .invalidateFilesUnderPathForTesting(
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
-    assertSrcs(validPackageWithoutErrors(skyKey), "foo", "//foo:@f.txt");
+    assertSrcs(validPackageoidWithoutErrors("foo"), "foo", "//foo:@f.txt");
   }
 
   /**
@@ -580,8 +645,7 @@ public void testGlobWithExternalSymlink() throws Exception {
     FileSystemUtils.ensureSymbolicLink(
         scratch.resolve("foo/subdir_link"), externalTarget.getParentDirectory());
     preparePackageLoading(rootDirectory);
-    SkyKey fooKey = PackageIdentifier.createInMainRepo("foo");
-    Package fooPkg = validPackageWithoutErrors(fooKey);
+    Packageoid fooPkg = validPackageoidWithoutErrors("foo");
     assertSrcs(fooPkg, "foo", "//foo:link.sh", "//foo:ordinary.sh");
     assertSrcs(fooPkg, "bar", "//foo:link.sh");
     assertSrcs(fooPkg, "baz", "//foo:subdir_link/target.txt");
@@ -608,14 +672,14 @@ public void testGlobWithExternalSymlink() throws Exception {
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
-    Package fooPkg2 = validPackageWithoutErrors(fooKey);
+    Packageoid fooPkg2 = validPackageoidWithoutErrors("foo");
     assertThat(fooPkg2).isNotEqualTo(fooPkg);
     assertSrcs(fooPkg2, "foo", "//foo:link.sh", "//foo:ordinary.sh");
     assertSrcs(fooPkg2, "bar", "//foo:link.sh");
     assertSrcs(fooPkg2, "baz", "//foo:subdir_link/target.txt");
   }
 
-  private static void assertSrcs(Package pkg, String targetName, String... expected)
+  private static void assertSrcs(Packageoid pkg, String targetName, String... expected)
       throws NoSuchTargetException {
     List<Label> expectedLabels = new ArrayList<>();
     for (String item : expected) {
@@ -625,7 +689,7 @@ private static void assertSrcs(Package pkg, String targetName, String... expecte
   }
 
   @SuppressWarnings("unchecked")
-  private static Iterable<Label> getSrcs(Package pkg, String targetName)
+  private static Iterable<Label> getSrcs(Packageoid pkg, String targetName)
       throws NoSuchTargetException {
     return (Iterable<Label>) pkg.getTarget(targetName).getAssociatedRule().getAttr("srcs");
   }
@@ -655,15 +719,14 @@ public void testOneNewElementInMultipleGlob() throws Exception {
         )
         """);
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     scratch.file("foo/irrelevant");
     getSkyframeExecutor()
         .invalidateFilesUnderPathForTesting(
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/irrelevant")).build(),
             Root.fromPath(rootDirectory));
-    assertThat(validPackageWithoutErrors(skyKey)).isSameInstanceAs(pkg);
+    assertThat(validPackageoidWithoutErrors("foo")).isSameInstanceAs(pkg);
   }
 
   @Test
@@ -694,15 +757,14 @@ public void testNoNewElementInMultipleGlob() throws Exception {
         )
         """);
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     scratch.file("foo/irrelevant");
     getSkyframeExecutor()
         .invalidateFilesUnderPathForTesting(
             reporter,
             ModifiedFileSet.builder().modify(PathFragment.create("foo/irrelevant")).build(),
             Root.fromPath(rootDirectory));
-    assertThat(validPackageWithoutErrors(skyKey)).isSameInstanceAs(pkg);
+    assertThat(validPackageoidWithoutErrors("foo")).isSameInstanceAs(pkg);
   }
 
   @Test
@@ -725,8 +787,7 @@ public void testTransitiveStarlarkDepsStoredInPackage() throws Exception {
     // must be done after preparePackageLoading()
     setBuildLanguageOptions("--experimental_enable_scl_dialect=true");
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     assertThat(pkg.getDeclarations().getOrComputeTransitivelyLoadedStarlarkFiles())
         .containsExactly(
             Label.parseCanonical("//bar:ext.bzl"), Label.parseCanonical("//baz:ext.scl"));
@@ -744,7 +805,7 @@ public void testTransitiveStarlarkDepsStoredInPackage() throws Exception {
             ModifiedFileSet.builder().modify(PathFragment.create("bar/ext.bzl")).build(),
             Root.fromPath(rootDirectory));
 
-    pkg = validPackageWithoutErrors(skyKey);
+    pkg = validPackageoidWithoutErrors("foo");
     assertThat(pkg.getDeclarations().getOrComputeTransitivelyLoadedStarlarkFiles())
         .containsExactly(
             Label.parseCanonical("//bar:ext.bzl"), Label.parseCanonical("//qux:ext.bzl"));
@@ -755,7 +816,7 @@ public void testNonExistingStarlarkExtension() throws Exception {
     scratch.file("test/starlark/BUILD", "load('//test/starlark:bad_extension.bzl', 'some_symbol')");
     invalidatePackages();
 
-    Exception ex = evaluatePackageToException("test/starlark");
+    Exception ex = evaluatePackageoidToException("test/starlark");
     assertThat(ex)
         .hasMessageThat()
         .isEqualTo(
@@ -777,7 +838,7 @@ public void testNonExistingStarlarkExtensionFromExtension() throws Exception {
     scratch.file("test/starlark/BUILD", "load('//test/starlark:extension.bzl', 'a')");
     invalidatePackages();
 
-    Exception ex = evaluatePackageToException("test/starlark");
+    Exception ex = evaluatePackageoidToException("test/starlark");
     assertThat(ex)
         .hasMessageThat()
         .isEqualTo(
@@ -801,7 +862,7 @@ public void testBuiltinsInjectionFailure() throws Exception {
         """);
     scratch.file("pkg/BUILD");
 
-    Exception ex = evaluatePackageToException("pkg");
+    Exception ex = evaluatePackageoidToException("pkg");
     assertThat(ex)
         .hasMessageThat()
         .isEqualTo(
@@ -819,7 +880,7 @@ public void testSymlinkCycleWithStarlarkExtension() throws Exception {
     scratch.file("test/starlark/BUILD", "load('//test/starlark:extension.bzl', 'a')");
     invalidatePackages();
 
-    Exception ex = evaluatePackageToException("test/starlark");
+    Exception ex = evaluatePackageoidToException("test/starlark");
     assertThat(ex)
         .hasMessageThat()
         .isEqualTo(
@@ -837,7 +898,7 @@ public void testIOErrorLookingForSubpackageForLabelIsHandled() throws Exception
     Path barBuildFile = scratch.file("foo/bar/BUILD");
     fs.stubStatError(barBuildFile, new IOException("nope"));
 
-    evaluatePackageToException("foo");
+    evaluatePackageoidToException("foo");
     assertContainsEvent("nope");
   }
 
@@ -854,7 +915,7 @@ public void testLoadOK() throws Exception {
         load("a.bzl", "b")
         load("subdir/a.bzl", "c")
         """);
-    validPackageWithoutErrors(PackageIdentifier.createInMainRepo("p"));
+    validPackageoidWithoutErrors("p");
   }
 
   // See WorkspaceFileFunctionTest for tests that exercise load('@repo...').
@@ -863,7 +924,7 @@ public void testLoadOK() throws Exception {
   public void testLoadBadLabel() throws Exception {
     scratch.file("p/BUILD", "load('this\tis not a label', 'a')");
     reporter.removeHandler(failFastHandler);
-    SkyKey key = PackageIdentifier.createInMainRepo("p");
+    SkyKey key = getSkyKey("p");
     SkyframeExecutorTestUtils.evaluate(skyframeExecutor, key, /*keepGoing=*/ false, reporter);
     assertContainsEvent(
         "in load statement: invalid target name 'this<?>is not a label': target names may not"
@@ -874,7 +935,7 @@ public void testLoadBadLabel() throws Exception {
   public void testLoadFromExternalPackage() throws Exception {
     scratch.file("p/BUILD", "load('//external:file.bzl', 'a')");
     reporter.removeHandler(failFastHandler);
-    SkyKey key = PackageIdentifier.createInMainRepo("p");
+    SkyKey key = getSkyKey("p");
     SkyframeExecutorTestUtils.evaluate(skyframeExecutor, key, /*keepGoing=*/ false, reporter);
     assertContainsEvent("Starlark files may not be loaded from the //external package");
   }
@@ -883,7 +944,7 @@ public void testLoadFromExternalPackage() throws Exception {
   public void testLoadWithoutBzlSuffix() throws Exception {
     scratch.file("p/BUILD", "load('//p:file.starlark', 'a')");
     reporter.removeHandler(failFastHandler);
-    SkyKey key = PackageIdentifier.createInMainRepo("p");
+    SkyKey key = getSkyKey("p");
     SkyframeExecutorTestUtils.evaluate(skyframeExecutor, key, /*keepGoing=*/ false, reporter);
     assertContainsEvent("The label must reference a file with extension \".bzl\"");
   }
@@ -904,7 +965,7 @@ public void testBzlVisibilityViolation() throws Exception {
         """);
 
     reporter.removeHandler(failFastHandler);
-    Exception ex = evaluatePackageToException("a");
+    Exception ex = evaluatePackageoidToException("a");
     assertThat(ex)
         .hasMessageThat()
         .contains(
@@ -929,7 +990,7 @@ public void testBzlVisibilityViolationDemotedToWarningWhenBreakGlassFlagIsSet()
         x = 1
         """);
 
-    validPackageWithoutErrors(PackageIdentifier.createInMainRepo("a"));
+    validPackageoidWithoutErrors("a");
     assertContainsEvent("Starlark file //b:foo.bzl is not visible for loading from package //a.");
     assertContainsEvent("Continuing because --nocheck_bzl_visibility is active");
   }
@@ -947,10 +1008,7 @@ public void testVisibilityCallableNotAvailableInBUILD() throws Exception {
     // exceptions (similar to b/26382502). So let's just look for the error event instead of
     // asserting on the exception.
     SkyframeExecutorTestUtils.evaluate(
-        getSkyframeExecutor(),
-        PackageIdentifier.createInMainRepo("a"),
-        /* keepGoing= */ false,
-        reporter);
+        getSkyframeExecutor(), getSkyKey("a"), /* keepGoing= */ false, reporter);
     assertContainsEvent("name 'visibility' is not defined");
   }
 
@@ -974,10 +1032,7 @@ def helper():
 
     reporter.removeHandler(failFastHandler);
     SkyframeExecutorTestUtils.evaluate(
-        getSkyframeExecutor(),
-        PackageIdentifier.createInMainRepo("a"),
-        /* keepGoing= */ false,
-        reporter);
+        getSkyframeExecutor(), getSkyKey("a"), /* keepGoing= */ false, reporter);
     assertContainsEvent(
         "visibility() can only be used during .bzl initialization (top-level evaluation)");
   }
@@ -993,8 +1048,7 @@ public void testIncrementalSkyframeHybridGlobbingOnDanglingSymlink() throws Exce
 
     preparePackageLoading(rootDirectory);
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     assertThat(pkg.containsErrors()).isFalse();
     assertThat(pkg.getTarget("existing.txt").getName()).isEqualTo("existing.txt");
     assertThrows(NoSuchTargetException.class, () -> pkg.getTarget("dangling.txt"));
@@ -1012,7 +1066,7 @@ public void testIncrementalSkyframeHybridGlobbingOnDanglingSymlink() throws Exce
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    Package pkg2 = validPackageWithoutErrors(skyKey);
+    Packageoid pkg2 = validPackageoidWithoutErrors("foo");
     assertThat(pkg2.containsErrors()).isFalse();
     assertThat(pkg2.getTarget("existing.txt").getName()).isEqualTo("existing.txt");
     assertThrows(NoSuchTargetException.class, () -> pkg2.getTarget("dangling.txt"));
@@ -1027,7 +1081,7 @@ public void testIncrementalSkyframeHybridGlobbingOnDanglingSymlink() throws Exce
             ModifiedFileSet.builder().modify(PathFragment.create("foo/nope")).build(),
             Root.fromPath(rootDirectory));
 
-    Package newPkg = validPackageWithoutErrors(skyKey);
+    Packageoid newPkg = validPackageoidWithoutErrors("foo");
     assertThat(newPkg.containsErrors()).isFalse();
     assertThat(newPkg.getTarget("existing.txt").getName()).isEqualTo("existing.txt");
     // Another consequence of the bug is that change pruning would incorrectly cut off changes that
@@ -1048,8 +1102,7 @@ public void testRecursiveGlobNeverMatchesPackageDirectory() throws Exception {
 
     preparePackageLoading(rootDirectory);
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("foo");
-    Package pkg = validPackageWithoutErrors(skyKey);
+    Packageoid pkg = validPackageoidWithoutErrors("foo");
     assertThat(pkg.containsErrors()).isFalse();
     assertThat(pkg.getTarget("bar-matched").getName()).isEqualTo("bar-matched");
     assertThrows(NoSuchTargetException.class, () -> pkg.getTarget("-matched"));
@@ -1069,7 +1122,7 @@ public void testRecursiveGlobNeverMatchesPackageDirectory() throws Exception {
             ModifiedFileSet.builder().modify(PathFragment.create("foo/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    Package pkg2 = validPackageWithoutErrors(skyKey);
+    Packageoid pkg2 = validPackageoidWithoutErrors("foo");
     assertThat(pkg2.containsErrors()).isFalse();
     assertThat(pkg2.getTarget("bar-matched").getName()).isEqualTo("bar-matched");
     assertThrows(NoSuchTargetException.class, () -> pkg2.getTarget("-matched"));
@@ -1081,7 +1134,7 @@ public void testPackageLoadingErrorOnIOExceptionReadingBuildFile() throws Except
     IOException exn = new IOException("nope");
     fs.throwExceptionOnGetInputStream(fooBuildFilePath, exn);
 
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
     assertThat(ex).hasMessageThat().contains("nope");
     assertThat(ex).isInstanceOf(NoSuchPackageException.class);
     assertThat(ex).hasCauseThat().isInstanceOf(IOException.class);
@@ -1093,7 +1146,7 @@ public void testPackageLoadingErrorOnMissingBuildFile_singlePackagePath() throws
     scratch.file("foo/bar");
 
     // There is no foo/BUILD file, but we enforce loading package 'foo'.
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
     assertThat(ex)
         .hasMessageThat()
         .contains(
@@ -1126,7 +1179,7 @@ public void testPackageLoadingErrorOnMissingBuildFile_multiplePackagePath() thro
 
     // There is no foo/BUILD file under both `package_path`s foo directory, but we enforce loading
     // package 'foo'.
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
 
     assertThat(ex)
         .hasMessageThat()
@@ -1147,7 +1200,7 @@ public void testPackageLoadingErrorOnIOExceptionReadingBzlFile() throws Exceptio
     IOException exn = new IOException("nope");
     fs.throwExceptionOnGetInputStream(fooBzlFilePath, exn);
 
-    Exception ex = evaluatePackageToException("foo");
+    Exception ex = evaluatePackageoidToException("foo");
     assertThat(ex).hasMessageThat().contains("nope");
     assertThat(ex).isInstanceOf(NoSuchPackageException.class);
     assertThat(ex).hasCauseThat().isInstanceOf(IOException.class);
@@ -1163,12 +1216,12 @@ public void testLabelsCrossesSubpackageBoundaries_singleSubpackageCrossing() thr
     scratch.file("pkg/foo/sub/BUILD");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg/foo");
-    EvaluationResult<PackageValue> result =
+    SkyKey skyKey = getSkyKey("pkg/foo");
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(
             getSkyframeExecutor(), skyKey, /* keepGoing= */ false, reporter);
     assertThatEvaluationResult(result).hasNoError();
-    assertThat(result.get(skyKey).getPackage().containsErrors()).isTrue();
+    assertThat(result.get(skyKey).getPackageoid().containsErrors()).isTrue();
     assertContainsEvent(
         "Label '//pkg/foo:sub/bar/blah' is invalid because 'pkg/foo/sub' is a subpackage; perhaps"
             + " you meant to put the colon here: '//pkg/foo/sub:bar/blah'?");
@@ -1192,12 +1245,12 @@ public void testLabelsCrossesSubpackageBoundaries_complexSubpackageCrossing() th
 
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg/foo");
-    EvaluationResult<PackageValue> result =
+    SkyKey skyKey = getSkyKey("pkg/foo");
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(
             getSkyframeExecutor(), skyKey, /* keepGoing= */ false, reporter);
     assertThatEvaluationResult(result).hasNoError();
-    assertThat(result.get(skyKey).getPackage().containsErrors()).isTrue();
+    assertThat(result.get(skyKey).getPackageoid().containsErrors()).isTrue();
 
     // Only the deepest package that crosses subpackage boundary should be displayed in the error
     // message.
@@ -1220,7 +1273,7 @@ public void testSymlinkCycleEncounteredWhileHandlingLabelCrossingSubpackageBound
     FileSystemUtils.ensureSymbolicLink(subBuildFilePath, subBuildFilePath);
     invalidatePackages();
 
-    Exception ex = evaluatePackageToException("pkg");
+    Exception ex = evaluatePackageoidToException("pkg");
     assertThat(ex).isInstanceOf(BuildFileNotFoundException.class);
     assertThat(ex)
         .hasMessageThat()
@@ -1257,10 +1310,10 @@ public void nonSkyframeGlobbingIOException_andLabelCrossingSubpackageBoundaries_
     // the non-Skyframe globbing error, but for the label crossing event to *not* get added (because
     // the globbing IOException would put Package.Builder in a state on which we cannot run
     // handleLabelsCrossingSubpackagesAndPropagateInconsistentFilesystemExceptions).
-    SkyKey pkgKey = PackageIdentifier.createInMainRepo("pkg");
-    EvaluationResult<PackageValue> result =
+    SkyKey pkgKey = getSkyKey("pkg");
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(
-            getSkyframeExecutor(), pkgKey, /*keepGoing=*/ true, reporter);
+            getSkyframeExecutor(), pkgKey, /* keepGoing= */ true, reporter);
     assertThatEvaluationResult(result)
         .hasErrorEntryForKeyThat(pkgKey)
         .hasExceptionThat()
@@ -1281,8 +1334,7 @@ public void testGlobAllowEmpty_paramValueMustBeBoolean() throws Exception {
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'], allow_empty = 5)");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-    validPackage(skyKey);
+    validPackageoid("pkg");
 
     assertContainsEvent("expected boolean for argument `allow_empty`, got `5`");
   }
@@ -1292,8 +1344,7 @@ public void testGlobAllowEmpty_functionParam() throws Exception {
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'], allow_empty=True)");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
   }
@@ -1306,8 +1357,7 @@ public void testGlobAllowEmpty_starlarkOption() throws Exception {
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'])");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
   }
@@ -1318,9 +1368,7 @@ public void testGlobDisallowEmpty_functionParam_wasNonEmptyAndBecomesEmpty() thr
     scratch.file("pkg/blah.foo");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
 
@@ -1332,7 +1380,7 @@ public void testGlobDisallowEmpty_functionParam_wasNonEmptyAndBecomesEmpty() thr
             Root.fromPath(rootDirectory));
 
     reporter.removeHandler(failFastHandler);
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(
         "glob pattern '*.foo' didn't match anything, but allow_empty is set to False (the "
@@ -1348,9 +1396,7 @@ public void testGlobDisallowEmpty_starlarkOption_wasNonEmptyAndBecomesEmpty() th
     scratch.file("pkg/blah.foo");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
 
@@ -1362,7 +1408,7 @@ public void testGlobDisallowEmpty_starlarkOption_wasNonEmptyAndBecomesEmpty() th
             Root.fromPath(rootDirectory));
 
     reporter.removeHandler(failFastHandler);
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(
         "glob pattern '*.foo' didn't match anything, but allow_empty is set to False (the "
@@ -1373,11 +1419,9 @@ public void testGlobDisallowEmpty_starlarkOption_wasNonEmptyAndBecomesEmpty() th
   public void testGlobDisallowEmpty_functionParam_wasEmptyAndStaysEmpty() throws Exception {
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'], allow_empty=False)");
     invalidatePackages();
-
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
     reporter.removeHandler(failFastHandler);
 
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     String expectedEventString =
         "glob pattern '*.foo' didn't match anything, but allow_empty is set to False (the "
@@ -1391,7 +1435,7 @@ public void testGlobDisallowEmpty_functionParam_wasEmptyAndStaysEmpty() throws E
             ModifiedFileSet.builder().modify(PathFragment.create("pkg/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(expectedEventString);
   }
@@ -1404,10 +1448,9 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyAndStaysEmpty() throws
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'])");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
     reporter.removeHandler(failFastHandler);
 
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     String expectedEventString =
         "glob pattern '*.foo' didn't match anything, but allow_empty is set to False (the "
@@ -1421,7 +1464,7 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyAndStaysEmpty() throws
             ModifiedFileSet.builder().modify(PathFragment.create("pkg/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(expectedEventString);
   }
@@ -1433,10 +1476,9 @@ public void testGlobDisallowEmpty_functionParam_wasEmptyDueToExcludeAndStaysEmpt
     scratch.file("pkg/blah.foo");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
     reporter.removeHandler(failFastHandler);
 
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     String expectedEventString =
         "all files in the glob have been excluded, but allow_empty is set to False (the "
@@ -1452,7 +1494,7 @@ public void testGlobDisallowEmpty_functionParam_wasEmptyDueToExcludeAndStaysEmpt
             ModifiedFileSet.builder().modify(PathFragment.create("pkg/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(expectedEventString);
   }
@@ -1467,10 +1509,9 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyDueToExcludeAndStaysEmp
     scratch.file("pkg/blah.foo");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
     reporter.removeHandler(failFastHandler);
 
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     String expectedEventString =
         "all files in the glob have been excluded, but allow_empty is set to False (the "
@@ -1484,7 +1525,7 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyDueToExcludeAndStaysEmp
             ModifiedFileSet.builder().modify(PathFragment.create("pkg/BUILD")).build(),
             Root.fromPath(rootDirectory));
 
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(expectedEventString);
   }
@@ -1494,10 +1535,8 @@ public void testGlobDisallowEmpty_functionParam_wasEmptyAndBecomesNonEmpty() thr
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'], allow_empty=False)");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-
     reporter.removeHandler(failFastHandler);
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
     assertContainsEvent(
         "glob pattern '*.foo' didn't match anything, but allow_empty is set to False (the "
@@ -1512,7 +1551,7 @@ public void testGlobDisallowEmpty_functionParam_wasEmptyAndBecomesNonEmpty() thr
 
     reporter.addHandler(failFastHandler);
     eventCollector.clear();
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
   }
@@ -1525,10 +1564,8 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyAndBecomesNonEmpty() th
     scratch.file("pkg/BUILD", "x = " + "glob(['*.foo'])");
     invalidatePackages();
 
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("pkg");
-
     reporter.removeHandler(failFastHandler);
-    Package pkg = validPackage(skyKey);
+    Packageoid pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isTrue();
 
     assertContainsEvent(
@@ -1544,7 +1581,7 @@ public void testGlobDisallowEmpty_starlarkOption_wasEmptyAndBecomesNonEmpty() th
 
     reporter.addHandler(failFastHandler);
     eventCollector.clear();
-    pkg = validPackage(skyKey);
+    pkg = validPackageoid("pkg");
     assertThat(pkg.containsErrors()).isFalse();
     assertNoEvents();
   }
@@ -1559,8 +1596,7 @@ public void testPackageRecordsLoadedModules() throws Exception {
 
     // load p
     preparePackageLoading(rootDirectory);
-    SkyKey skyKey = PackageIdentifier.createInMainRepo("p");
-    Package p = validPackageWithoutErrors(skyKey);
+    Packageoid p = validPackageoidWithoutErrors("p");
 
     assertThat(toStrings(p.getDeclarations().getOrComputeTransitivelyLoadedStarlarkFiles()))
         .containsExactly("//p:a.bzl", "//p:b.bzl", "//p:c.bzl", "//p:d.bzl");
@@ -1584,8 +1620,8 @@ public void veryBrokenPackagePostsDoneToProgressReceiver() throws Exception {
 
     // Note: syntax error (recovered), non-existent .bzl file.
     scratch.file("pkg/BUILD", "load('//does_not:exist.bzl', 'broken'");
-    SkyKey key = PackageIdentifier.createInMainRepo("pkg");
-    EvaluationResult<PackageValue> result =
+    SkyKey key = getSkyKey("pkg");
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(getSkyframeExecutor(), key, false, reporter);
     assertThatEvaluationResult(result).hasErrorEntryForKeyThat(key);
     assertContainsEvent("syntax error at 'newline': expected ,");
@@ -1609,10 +1645,10 @@ public void testNonSkyframeGlobbingEncountersSymlinkCycleAndThrowsIOException()
     assertThat(ioExnFromFS).hasMessageThat().contains("Too many levels of symbolic links");
 
     // Then, when we evaluate the PackageValue node for the Package in keepGoing mode,
-    SkyKey pkgKey = PackageIdentifier.createInMainRepo("foo");
-    EvaluationResult<PackageValue> result =
+    SkyKey pkgKey = getSkyKey("foo");
+    EvaluationResult<PackageoidValue> result =
         SkyframeExecutorTestUtils.evaluate(
-            getSkyframeExecutor(), pkgKey, /*keepGoing=*/ true, reporter);
+            getSkyframeExecutor(), pkgKey, /* keepGoing= */ true, reporter);
     // The result is a *non-transient* Skyframe error.
     assertThatEvaluationResult(result).hasErrorEntryForKeyThat(pkgKey).isNotTransient();
     // And that error is a NoSuchPackageException
@@ -1695,7 +1731,7 @@ public void testGlobbingSkyframeDependencyStructure() throws Exception {
     Path fooSubpkgPath = fooBuildPath.getParentDirectory().getChild("subpkg");
     scratch.file("foo/subpkg/BUILD");
 
-    SkyKey pkgKey = PackageIdentifier.createInMainRepo("foo");
+    SkyKey pkgKey = getSkyKey("foo");
     SkyframeExecutorTestUtils.evaluate(
         getSkyframeExecutor(), pkgKey, /* keepGoing= */ true, reporter);
 
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=/usr/local/bin:$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test targets
# Using --test_output=errors to get concise output
# Using --jobs=4 and --local_test_jobs=1 to control parallelism in the virtualized environment
# Combining both test targets in a single command for efficiency
echo "=== Running tests ==="
bazel test \
    --test_output=errors \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/packages:PackagesTests \
    //src/test/java/com/google/devtools/build/lib/skyframe:PackageFunctionTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout ebd5a01cf1bcc3e02dfb2d96be4c9d4e41ecf317 "src/test/java/com/google/devtools/build/lib/packages/PackageFactoryTest.java" "src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java" "src/test/java/com/google/devtools/build/lib/skyframe/BUILD" "src/test/java/com/google/devtools/build/lib/skyframe/PackageFunctionTest.java"

exit $rc