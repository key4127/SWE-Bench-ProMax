#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 492f3da8df9d84957c5e25338cd6ee9b5220fabe "src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java b/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
--- a/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
+++ b/src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java
@@ -243,6 +243,7 @@ private PackagePiece.ForBuildFile.Builder minimalBuildFilePieceBuilder(String na
             /* repositoryMapping= */ RepositoryMapping.ALWAYS_FALLBACK,
             /* mainRepositoryMapping= */ null,
             /* cpuBoundSemaphore= */ null,
+            PackageOverheadEstimator.NOOP_ESTIMATOR,
             /* generatorMap= */ null,
             /* configSettingVisibilityPolicy= */ null,
             /* globber= */ null,
@@ -261,6 +262,7 @@ private PackagePiece.ForMacro.Builder minimalMacroPieceBuilder(
         /* repositoryMapping= */ RepositoryMapping.ALWAYS_FALLBACK,
         /* mainRepositoryMapping= */ null,
         /* cpuBoundSemaphore= */ null,
+        PackageOverheadEstimator.NOOP_ESTIMATOR,
         /* generatorMap= */ null,
         /* enableNameConflictChecking= */ true,
         /* trackFullMacroInformation= */ false);
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root
export TEST_INSTALL_BASE=/tmp/bazeltest/install_base
export REPOSITORY_CACHE=/tmp/bazeltest/repo_cache
export REMOTE_NETWORK_ADDRESS=bazel.build:80

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test with fully qualified class name and disabled sharding
echo "=== Running PackagePieceTest ==="
bazel test \
    --config=ci-linux \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --sandbox_default_allow_network=false \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_sharding_strategy=disabled \
    --test_filter=com.google.devtools.build.lib.packages.PackagePieceTest \
    //src/test/java/com/google/devtools/build/lib/packages:PackagesTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 492f3da8df9d84957c5e25338cd6ee9b5220fabe "src/test/java/com/google/devtools/build/lib/packages/PackagePieceTest.java"