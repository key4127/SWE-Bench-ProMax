#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout e262d021e87727a501ccbdff306d188ed88bcb29 "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD
@@ -115,9 +115,9 @@ java_test(
     srcs = ["FileOpMatchMemoizingLookupTest.java"],
     deps = [
         ":controllable_file_dependencies",
-        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:depot_delta_validator",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:file_dependency_deserializer",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes_validator",
         "//third_party:guava",
         "//third_party:junit4",
         "//third_party:truth",
@@ -130,9 +130,23 @@ java_test(
     srcs = ["NestedMatchMemoizingLookupTest.java"],
     deps = [
         ":controllable_file_dependencies",
-        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:depot_delta_validator",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:file_dependency_deserializer",
         "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes_validator",
+        "//third_party:guava",
+        "//third_party:junit4",
+        "//third_party:truth",
+        "@maven//:com_google_testparameterinjector_test_parameter_injector",
+    ],
+)
+
+java_test(
+    name = "VersionedChangesValidatorTest",
+    srcs = ["VersionedChangesValidatorTest.java"],
+    deps = [
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:file_dependency_deserializer",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes",
+        "//src/main/java/com/google/devtools/build/lib/skyframe/serialization/analysis:versioned_changes_validator",
         "//third_party:guava",
         "//third_party:junit4",
         "//third_party:truth",
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java
@@ -14,6 +14,7 @@
 package com.google.devtools.build.lib.skyframe.serialization.analysis;
 
 import static com.google.common.truth.Truth.assertThat;
+import static com.google.devtools.build.lib.skyframe.serialization.analysis.NestedMatchResultTypes.createNestedMatchResult;
 import static com.google.devtools.build.lib.skyframe.serialization.analysis.NoMatch.NO_MATCH_RESULT;
 import static com.google.devtools.build.lib.skyframe.serialization.analysis.VersionedChanges.NO_MATCH;
 
@@ -28,7 +29,6 @@
 import com.google.devtools.build.lib.skyframe.serialization.analysis.NestedMatchResultTypes.SourceMatch;
 import com.google.testing.junit.testparameterinjector.TestParameterInjector;
 import com.google.testing.junit.testparameterinjector.TestParameters;
-import java.util.List;
 import java.util.concurrent.ConcurrentHashMap;
 import java.util.concurrent.CountDownLatch;
 import java.util.concurrent.ForkJoinPool;
@@ -80,15 +80,15 @@ public void matchingNested_withDependencies_aggregatesDependencies(
     changes.registerFileChange("src/a", 98);
 
     var key =
-        createNestedDependencies(
+        new NestedDependencies(
             ImmutableList.of(
                 FileDependencies.builder("dep/a").build(),
                 FileDependencies.builder("dep/b").build(),
                 FileDependencies.builder("dep/c").build()),
             ImmutableList.of(FileDependencies.builder("src/a").build()));
 
     NestedMatchResult expectedResult =
-        createMatchResult(expectedAnalysisMatch, expectedSourceMatch);
+        createNestedMatchResult(expectedAnalysisMatch, expectedSourceMatch);
     assertThat(getLookupResult(key, validityHorizon)).isEqualTo(expectedResult);
   }
 
@@ -115,7 +115,7 @@ public void matchingNested_withAsyncDependencies_aggregatesDependencies(
     var depB = new ControllableFileDependencies(ImmutableList.of("dep/b"), ImmutableList.of());
     var depC = new ControllableFileDependencies(ImmutableList.of("dep/c"), ImmutableList.of());
     var srcA = new ControllableFileDependencies(ImmutableList.of("src/a"), ImmutableList.of());
-    var key = createNestedDependencies(ImmutableList.of(depA, depB, depC), ImmutableList.of(srcA));
+    var key = new NestedDependencies(ImmutableList.of(depA, depB, depC), ImmutableList.of(srcA));
 
     var pool = new ForkJoinPool(4); // one for each dependency and source
     pool.execute(
@@ -152,7 +152,7 @@ public void matchingNested_withAsyncDependencies_aggregatesDependencies(
     srcA.enable();
 
     NestedMatchResult expectedResult =
-        createMatchResult(expectedAnalysisMatch, expectedSourceMatch);
+        createNestedMatchResult(expectedAnalysisMatch, expectedSourceMatch);
     assertThat(lookupResult.get()).isEqualTo(expectedResult);
   }
 
@@ -173,19 +173,19 @@ public void matchingNested_withNestedDependencies_aggregatesDependencies(
     changes.registerFileChange("src/a", 102);
 
     var nestedDep =
-        createNestedDependencies(
+        new NestedDependencies(
             ImmutableList.of(
                 FileDependencies.builder("dep/b").build(),
                 FileDependencies.builder("dep/c").build()),
             ImmutableList.of(FileDependencies.builder("src/a").build()));
 
     var key =
-        createNestedDependencies(
+        new NestedDependencies(
             ImmutableList.of(FileDependencies.builder("dep/a").build(), nestedDep),
             ImmutableList.of());
 
     NestedMatchResult expectedResult =
-        createMatchResult(expectedAnalysisMatch, expectedSourceMatch);
+        createNestedMatchResult(expectedAnalysisMatch, expectedSourceMatch);
     assertThat(getLookupResult(key, validityHorizon)).isEqualTo(expectedResult);
   }
 
@@ -208,19 +208,19 @@ public void matchingNested_withAsyncNestedDependencies_aggregatesDependencies(
     changes.registerFileChange("src/a", 102);
 
     var nestedDep =
-        createNestedDependencies(
+        new NestedDependencies(
             ImmutableList.of(
                 FileDependencies.builder("dep/b").build(),
                 FileDependencies.builder("dep/c").build()),
             ImmutableList.of(FileDependencies.builder("src/a").build()));
 
     var key =
-        createNestedDependencies(
+        new NestedDependencies(
             ImmutableList.of(FileDependencies.builder("dep/a").build(), nestedDep),
             ImmutableList.of());
 
     NestedMatchResult expectedResult =
-        createMatchResult(expectedAnalysisMatch, expectedSourceMatch);
+        createNestedMatchResult(expectedAnalysisMatch, expectedSourceMatch);
 
     // Spawns THREAD_COUNT threads to test parallel nested dependency lookups.
     var executor = new ForkJoinPool(THREAD_COUNT);
@@ -248,13 +248,40 @@ public void matchingNested_withAsyncNestedDependencies_aggregatesDependencies(
     latch.await();
   }
 
-  private static NestedMatchResult createMatchResult(int analysisVersion, int sourceVersion) {
-    if (analysisVersion == NO_MATCH) {
-      return sourceVersion == NO_MATCH ? NO_MATCH_RESULT : new SourceMatch(sourceVersion);
-    }
-    return sourceVersion == NO_MATCH
-        ? new AnalysisMatch(analysisVersion)
-        : new AnalysisAndSourceMatch(analysisVersion, sourceVersion);
+  @Test
+  public void createNestedMatchResult_analysisVersionNoMatch_sourceVersionPositive_sourceMatch() {
+    NestedMatchResult result = createNestedMatchResult(NO_MATCH, 5);
+    assertThat(result).isEqualTo(new SourceMatch(5));
+  }
+
+  @Test
+  public void createNestedMatchResult_analysisVersionLessEqualSourceVersion_analysisMatch() {
+    NestedMatchResult result = createNestedMatchResult(10, 20);
+    assertThat(result).isEqualTo(new AnalysisMatch(10));
+  }
+
+  @Test
+  public void createNestedMatchResult_analysisVersionGreaterSourceVersion_analysisNonNoMatch() {
+    NestedMatchResult result = createNestedMatchResult(20, 5);
+    assertThat(result).isEqualTo(new AnalysisAndSourceMatch(20, 5));
+  }
+
+  @Test
+  public void createNestedMatchResult_analysisVersionGreaterSourceVersion_analysisAndSourceMatch() {
+    NestedMatchResult result = createNestedMatchResult(20, 10);
+    assertThat(result).isEqualTo(new AnalysisAndSourceMatch(20, 10));
+  }
+
+  @Test
+  public void createNestedMatchResult_analysisVersionEqualSourceVersion_analysisMatch() {
+    NestedMatchResult result = createNestedMatchResult(10, 10);
+    assertThat(result).isEqualTo(new AnalysisMatch(10));
+  }
+
+  @Test
+  public void createNestedMatchResult_analysisVersionNoMatch_sourceVersionNoMatch_noMatchResult() {
+    NestedMatchResult result = createNestedMatchResult(NO_MATCH, NO_MATCH);
+    assertThat(result).isEqualTo(NO_MATCH_RESULT);
   }
 
   private NestedMatchResult getLookupResult(NestedDependencies key, int validityHorizon) {
@@ -293,11 +320,4 @@ private static NestedDependencies createNestedDependencies(FileDependencies file
     return new NestedDependencies(
         new FileSystemDependencies[] {fileDependency}, NestedDependencies.EMPTY_SOURCES);
   }
-
-  private static NestedDependencies createNestedDependencies(
-      List<? extends FileSystemDependencies> analysisDependencies, List<FileDependencies> sources) {
-    return new NestedDependencies(
-        analysisDependencies.toArray(FileSystemDependencies[]::new),
-        sources.toArray(FileDependencies[]::new));
-  }
 }
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/VersionedChangesValidatorTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/VersionedChangesValidatorTest.java
new file mode 100644
--- /dev/null
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/VersionedChangesValidatorTest.java
@@ -0,0 +1,171 @@
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
+package com.google.devtools.build.lib.skyframe.serialization.analysis;
+
+import static com.google.common.truth.Truth.assertThat;
+import static com.google.devtools.build.lib.skyframe.serialization.analysis.NestedMatchResultTypes.createNestedMatchResult;
+import static com.google.devtools.build.lib.skyframe.serialization.analysis.NoMatch.NO_MATCH_RESULT;
+
+import com.google.common.collect.ImmutableList;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.FileOpMatchResultTypes.FileOpMatch;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.FileOpMatchResultTypes.FileOpMatchResult;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.FileOpMatchResultTypes.FutureFileOpMatchResult;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.FileSystemDependencies.FileOpDependency;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.NestedMatchResultTypes.FutureNestedMatchResult;
+import com.google.devtools.build.lib.skyframe.serialization.analysis.NestedMatchResultTypes.NestedMatchResult;
+import com.google.testing.junit.testparameterinjector.TestParameterInjector;
+import com.google.testing.junit.testparameterinjector.TestParameters;
+import java.util.concurrent.ForkJoinPool;
+import org.junit.Test;
+import org.junit.runner.RunWith;
+
+@RunWith(TestParameterInjector.class)
+public final class VersionedChangesValidatorTest {
+  private static final int THREAD_COUNT = 10;
+
+  private final VersionedChanges changes = new VersionedChanges(ImmutableList.of());
+  private final VersionedChangesValidator validator =
+      new VersionedChangesValidator(new ForkJoinPool(THREAD_COUNT), changes);
+
+  @Test
+  public void matchesFileOpDependency_noMatch() throws Exception {
+    changes.registerFileChange("abc/def", 100);
+    assertThat(getMatchResult(FileDependencies.builder("abc/def").build(), 100))
+        .isEqualTo(NO_MATCH_RESULT);
+  }
+
+  @Test
+  public void matchesFileOpDependency_match() throws Exception {
+    changes.registerFileChange("abc/def", 100);
+    assertThat(getMatchResult(FileDependencies.builder("abc/def").build(), 99))
+        .isEqualTo(new FileOpMatch(100));
+  }
+
+  @Test
+  @TestParameters("{validityHorizon: 97, expectedAnalysisMatch: 99, expectedSourceMatch: 98}")
+  @TestParameters(
+      "{validityHorizon: 98, expectedAnalysisMatch: 99, expectedSourceMatch: 2147483647}")
+  @TestParameters(
+      "{validityHorizon: 99, expectedAnalysisMatch: 100, expectedSourceMatch: 2147483647}")
+  @TestParameters(
+      "{validityHorizon: 100, expectedAnalysisMatch: 101, expectedSourceMatch: 2147483647}")
+  @TestParameters(
+      "{validityHorizon: 101, expectedAnalysisMatch: 2147483647, expectedSourceMatch: 2147483647}")
+  public void matchingNested_withDependencies_aggregatesDependencies(
+      int validityHorizon, int expectedAnalysisMatch, int expectedSourceMatch) {
+    changes.registerFileChange("dep/a", 99);
+    changes.registerFileChange("dep/b", 100);
+    changes.registerFileChange("dep/c", 101);
+    changes.registerFileChange("src/a", 98);
+
+    var key =
+        new NestedDependencies(
+            ImmutableList.of(
+                FileDependencies.builder("dep/a").build(),
+                FileDependencies.builder("dep/b").build(),
+                FileDependencies.builder("dep/c").build()),
+            ImmutableList.of(FileDependencies.builder("src/a").build()));
+
+    NestedMatchResult expectedResult =
+        createNestedMatchResult(expectedAnalysisMatch, expectedSourceMatch);
+    assertThat(getMatchResult(key, validityHorizon)).isEqualTo(expectedResult);
+  }
+
+  @Test
+  public void differentValidityHorizons_sameFileDependencies() throws Exception {
+    // This test case models Scenario 1 in the class comment of VersionedChangesValidator. It's not
+    // mechanically interesting. The interesting constraints are properties of the MTSV and VH.
+    changes.registerFileChange("shared", 100);
+    changes.registerFileChange("dep/a", 101);
+    changes.registerFileChange("dep/b", 102);
+
+    var keyA =
+        new NestedDependencies(
+            ImmutableList.of(
+                FileDependencies.builder("shared").build(),
+                FileDependencies.builder("dep/a").build()),
+            ImmutableList.of());
+
+    var keyB =
+        new NestedDependencies(
+            ImmutableList.of(
+                FileDependencies.builder("shared").build(),
+                FileDependencies.builder("dep/b").build()),
+            ImmutableList.of());
+
+    // "A" has dependencies 'shared' and 'dep/a'. It was marked valid at VH 105 and has MTSV 101.
+    // There are no invalidating changes. This marks 'shared' as NO_MATCH_RESULT.
+    //
+    // At the MTSV of 101, "shared" was at version 100. Since the VH is 105, it means there can't be
+    // any changes in "shared" on the interval [101, 105].
+    assertThat(getMatchResult(keyA, 105)).isEqualTo(NO_MATCH_RESULT);
+
+    // "B" has dependencies 'shared' and 'dep/b'. It was marked clean at VH 110 and has MTSV 102.
+    // There are no invalidating changes. It uses cached NO_MATCH_RESULT from "A"'s traversal.
+    //
+    // At the MTSV of 102, "shared" was at version 100. Since the VH is 110, it means there can't be
+    // any changes in "shared" on the interval [101, 110].
+    assertThat(getMatchResult(keyB, 110)).isEqualTo(NO_MATCH_RESULT);
+  }
+
+  @Test
+  public void staleCachedValue_ignoredForSameKeyButDifferentValidityHorizon() throws Exception {
+    // This test case models Scenario 2 in the class comment of VersionedChangesValidator.
+    changes.registerFileChange("dep", 101);
+
+    // Looks up 'dep' at version 100 and observes the invalidation at 101.
+    var key1 = FileDependencies.builder("dep").build();
+    assertThat(getMatchResult(key1, 100)).isEqualTo(new FileOpMatch(101));
+
+    // Looks up 'dep' at version 102 and does not observe the invalidation.
+    //
+    // Even though these keys are identical, the trick here is that FileDependencies is based on
+    // reference equality. The references in the FileDependencyDeserializer will be different if the
+    // (canonical) MTSVs are different.
+    var key2 = FileDependencies.builder("dep").build();
+    assertThat(getMatchResult(key2, 102)).isEqualTo(NO_MATCH_RESULT);
+  }
+
+  private FileOpMatchResult getMatchResult(FileOpDependency key, int validityHorizon) {
+    try {
+      switch (validator.matches(key, validityHorizon)) {
+        case FileOpMatchResult result:
+          return result;
+        case FutureFileOpMatchResult future:
+          return future.get();
+      }
+    } catch (Exception e) {
+      if (e instanceof InterruptedException) {
+        Thread.currentThread().interrupt();
+      }
+      throw new AssertionError(e);
+    }
+  }
+
+  private NestedMatchResult getMatchResult(NestedDependencies key, int validityHorizon) {
+    try {
+      switch (validator.matches(key, validityHorizon)) {
+        case NestedMatchResult result:
+          return result;
+        case FutureNestedMatchResult future:
+          return future.get();
+      }
+    } catch (Exception e) {
+      if (e instanceof InterruptedException) {
+        Thread.currentThread().interrupt();
+      }
+      throw new AssertionError(e);
+    }
+  }
+}
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test
# Based on the collected information, the test target is:
# //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:NestedMatchMemoizingLookupTest
echo "=== Running NestedMatchMemoizingLookupTest ==="
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:NestedMatchMemoizingLookupTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e262d021e87727a501ccbdff306d188ed88bcb29 "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/BUILD" "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/NestedMatchMemoizingLookupTest.java"