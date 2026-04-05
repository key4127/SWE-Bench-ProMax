#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 263c3a7a09213acc8ec68c45a5fe75fcf77b8ce4 "src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java b/src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java
--- a/src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java
+++ b/src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java
@@ -16,6 +16,7 @@
 import static com.google.common.collect.ImmutableList.toImmutableList;
 import static com.google.common.truth.Truth.assertThat;
 import static java.nio.charset.StandardCharsets.ISO_8859_1;
+import static org.junit.Assert.assertThrows;
 import static org.junit.Assert.fail;
 
 import com.google.auth.Credentials;
@@ -29,6 +30,7 @@
 import com.google.devtools.build.lib.vfs.Path;
 import com.google.devtools.build.lib.vfs.inmemoryfs.InMemoryFileSystem;
 import java.io.IOException;
+import java.io.Reader;
 import java.io.StringReader;
 import java.net.URI;
 import java.net.URL;
@@ -44,9 +46,15 @@
 @RunWith(JUnit4.class)
 public class UrlRewriterTest {
 
+  /** Convenience wrapper to create a {@link UrlRewriter} with a single path/reader. */
+  private UrlRewriter testUrlRewriter(String filePathForErrorReporting, Reader reader)
+      throws UrlRewriterParseException {
+    return new UrlRewriter(ImmutableList.of(filePathForErrorReporting), ImmutableList.of(reader));
+  }
+
   @Test
   public void byDefaultTheUrlRewriterDoesNothing() throws Exception {
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(""));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(""));
 
     List<URL> urls = ImmutableList.of(new URL("http://example.com"));
     ImmutableList<URL> amended =
@@ -55,10 +63,27 @@ public void byDefaultTheUrlRewriterDoesNothing() throws Exception {
     assertThat(amended).isEqualTo(urls);
   }
 
+  @Test
+  public void constructorMustHaveTheSameNumberOfFilePathsAndReaders()
+      throws UrlRewriterParseException {
+    // This has one file path and one reader - no exception is thrown.
+    UrlRewriter munger =
+        new UrlRewriter(ImmutableList.of("/dev/null"), ImmutableList.of(new StringReader("")));
+
+    // Two file paths, but one reader - this will fail the precondition.
+    assertThrows(
+        "filePath and readers size must be equal",
+        IllegalArgumentException.class,
+        () ->
+            new UrlRewriter(
+                ImmutableList.of("/dev/null", "/dev/null"),
+                ImmutableList.of(new StringReader(""))));
+  }
+
   @Test
   public void shouldBeAbleToBlockParticularHostsRegardlessOfScheme() throws Exception {
     String config = "block example.com";
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> urls =
         ImmutableList.of(
@@ -74,7 +99,7 @@ public void shouldBeAbleToBlockParticularHostsRegardlessOfScheme() throws Except
   @Test
   public void shouldAllowAUrlToBeRewritten() throws Exception {
     String config = "rewrite example.com/foo/(.*) mycorp.com/$1/foo";
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> urls = ImmutableList.of(new URL("https://example.com/foo/bar"));
     ImmutableList<URL> amended =
@@ -88,7 +113,26 @@ public void rewritesCanExpandToMoreThanOneUrl() throws Exception {
     String config =
         "rewrite example.com/foo/(.*) mycorp.com/$1/somewhere\n"
             + "rewrite example.com/foo/(.*) mycorp.com/$1/elsewhere";
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
+
+    List<URL> urls = ImmutableList.of(new URL("https://example.com/foo/bar"));
+    ImmutableList<URL> amended =
+        munger.amend(urls).stream().map(url -> url.url()).collect(toImmutableList());
+
+    // There's no guarantee about the ordering of the rewrites
+    assertThat(amended).contains(new URL("https://mycorp.com/bar/somewhere"));
+    assertThat(amended).contains(new URL("https://mycorp.com/bar/elsewhere"));
+  }
+
+  /** Same as {@link #rewritesCanExpandToMoreThanOneUrl()} but spread across two config files. */
+  @Test
+  public void rewritesCanExpandToMoreThanOneUrlWithMultipleConfigs() throws Exception {
+    String config = "rewrite example.com/foo/(.*) mycorp.com/$1/somewhere\n";
+    String config2 = "rewrite example.com/foo/(.*) mycorp.com/$1/elsewhere\n";
+    UrlRewriter munger =
+        new UrlRewriter(
+            ImmutableList.of("/dev/null", "/dev/null"),
+            ImmutableList.of(new StringReader(config), new StringReader(config2)));
 
     List<URL> urls = ImmutableList.of(new URL("https://example.com/foo/bar"));
     ImmutableList<URL> amended =
@@ -103,7 +147,7 @@ public void rewritesCanExpandToMoreThanOneUrl() throws Exception {
   public void shouldBlockAllUrlsOtherThanSpecificOnes() throws Exception {
     String config = "" + "block *\n" + "allow example.com";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> urls =
         ImmutableList.of(
@@ -127,7 +171,7 @@ public void commentsArePrecededByTheHashCharacter() throws Exception {
             + "# But allow example.com\n"
             + "allow example.com";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> urls = ImmutableList.of(new URL("https://foo.com"), new URL("https://example.com"));
     ImmutableList<URL> amended =
@@ -140,7 +184,7 @@ public void commentsArePrecededByTheHashCharacter() throws Exception {
   public void allowListAppliesToSubdomainsToo() throws Exception {
     String config = "" + "block *\n" + "allow example.com";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     ImmutableList<URL> amended =
         munger.amend(ImmutableList.of(new URL("https://subdomain.example.com"))).stream()
@@ -154,7 +198,7 @@ public void allowListAppliesToSubdomainsToo() throws Exception {
   public void blockListAppliesToSubdomainsToo() throws Exception {
     String config = "block example.com";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     ImmutableList<URL> amended =
         munger.amend(ImmutableList.of(new URL("https://subdomain.example.com"))).stream()
@@ -168,7 +212,7 @@ public void blockListAppliesToSubdomainsToo() throws Exception {
   public void emptyLinesAreFine() throws Exception {
     String config = "" + "\n" + "   \n" + "block *\n" + "\t  \n" + "allow example.com";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     ImmutableList<URL> amended =
         munger.amend(ImmutableList.of(new URL("https://subdomain.example.com"))).stream()
@@ -182,7 +226,7 @@ public void emptyLinesAreFine() throws Exception {
   public void rewritingUrlsIsAppliedBeforeBlocking() throws Exception {
     String config = "" + "block bad.com\n" + "rewrite bad.com/foo/(.*) mycorp.com/$1";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> amended =
         munger
@@ -201,7 +245,7 @@ public void rewritingUrlsIsAppliedBeforeAllowing() throws Exception {
     String config =
         "" + "block *\n" + "allow mycorp.com\n" + "rewrite bad.com/foo/(.*) mycorp.com/$1";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> amended =
         munger
@@ -263,7 +307,7 @@ public void rewritingUrlsAllowsProtocolRewrite() throws Exception {
             + "rewrite bad.com/foo/(.*) http://mycorp.com/$1\n"
             + "rewrite bad.com/bar/(.*) https://othercorp.com/bar/$1\n";
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     List<URL> amended =
         munger
@@ -307,7 +351,7 @@ public void rewritingUrlsWithAuthHeaders() throws Exception {
     // but no auth
     // headers added
 
-    UrlRewriter munger = new UrlRewriter(str -> {}, "/dev/null", new StringReader(config));
+    UrlRewriter munger = testUrlRewriter("/dev/null", new StringReader(config));
 
     ImmutableList<UrlRewriter.RewrittenURL> amended =
         munger.amend(
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

# Query Bazel to find the exact target that includes UrlRewriterTest
echo "=== Querying Bazel for targets containing UrlRewriterTest ==="
bazel query 'attr(srcs, "UrlRewriterTest.java", //src/test/java/com/google/devtools/build/lib/bazel/repository/downloader:*)' || true

# Run the test using the test filter to specifically target UrlRewriterTest
# This will run only the UrlRewriterTest class within the DownloaderTestSuite
bazel test \
    --config=ci-linux \
    --test_output=all \
    --jvmopt=-Djava.lang.Thread.allowVirtualThreads=true \
    --jobs=4 \
    --local_test_jobs=1 \
    --test_filter=UrlRewriterTest \
    //src/test/java/com/google/devtools/build/lib/bazel/repository/downloader:DownloaderTestSuite

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 263c3a7a09213acc8ec68c45a5fe75fcf77b8ce4 "src/test/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterTest.java"