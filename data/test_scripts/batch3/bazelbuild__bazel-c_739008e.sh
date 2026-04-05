#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 2401fad2b433f2b50bb8e084858967d532edbb9e \
    "src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java"

# Also checkout the concrete test class that extends the base
if [ -f "src/test/java/com/google/devtools/build/lib/remote/RemoteActionInputFetcherTest.java" ]; then
    git checkout 2401fad2b433f2b50bb8e084858967d532edbb9e \
        "src/test/java/com/google/devtools/build/lib/remote/RemoteActionInputFetcherTest.java"
fi

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java b/src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java
--- a/src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java
+++ b/src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java
@@ -302,7 +302,7 @@ public void prefetchFiles_fileExists_doNotDownload()
             action, metadata.keySet(), metadata::get, Priority.MEDIUM, Reason.INPUTS));
 
     verify(prefetcher, never())
-        .doDownloadFile(eq(action), any(), any(), any(), any(), any(), any());
+        .doDownloadFile(eq(action), any(), eq(a), any(), any(), any(), any());
     assertThat(prefetcher.downloadedFiles()).containsExactly(a.getPath());
     assertThat(prefetcher.downloadsInProgress()).isEmpty();
   }
@@ -320,8 +320,7 @@ public void prefetchFiles_fileExistsButContentMismatches_download()
         prefetcher.prefetchFilesInterruptibly(
             action, metadata.keySet(), metadata::get, Priority.MEDIUM, Reason.INPUTS));
 
-    verify(prefetcher)
-        .doDownloadFile(eq(action), any(), any(), eq(a.getExecPath()), any(), any(), any());
+    verify(prefetcher).doDownloadFile(eq(action), any(), eq(a), any(), any(), any(), any());
     assertThat(prefetcher.downloadedFiles()).containsExactly(a.getPath());
     assertThat(prefetcher.downloadsInProgress()).isEmpty();
     assertThat(FileSystemUtils.readContent(a.getPath(), UTF_8)).isEqualTo("hello world remote");
@@ -911,7 +910,7 @@ protected static void mockDownload(
       throws IOException {
     doAnswer(
             invocation -> {
-              Path path = invocation.getArgument(2);
+              Path path = invocation.getArgument(3);
               FileArtifactValue metadata = invocation.getArgument(4);
               byte[] content = cas.get(HashCode.fromBytes(metadata.getDigest()));
               if (content == null) {
EOF_114329324912

# Set up environment variables
export USE_BAZEL_VERSION=8.3.1
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test class that extends ActionInputPrefetcherTestBase
# Using test filter to target RemoteActionInputFetcherTest which contains the actual test methods
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_filter=RemoteActionInputFetcherTest \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/remote:RemoteTests

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 2401fad2b433f2b50bb8e084858967d532edbb9e \
    "src/test/java/com/google/devtools/build/lib/remote/ActionInputPrefetcherTestBase.java"

if [ -f "src/test/java/com/google/devtools/build/lib/remote/RemoteActionInputFetcherTest.java" ]; then
    git checkout 2401fad2b433f2b50bb8e084858967d532edbb9e \
        "src/test/java/com/google/devtools/build/lib/remote/RemoteActionInputFetcherTest.java"
fi