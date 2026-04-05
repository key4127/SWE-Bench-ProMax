#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 67b672d1b822f4d39766d0cb932b9894b6e294ce \
    "src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java" \
    "src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java" \
    "src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java" \
    "src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java b/src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java
--- a/src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java
+++ b/src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java
@@ -88,12 +88,11 @@ public void clear_removesAllElements() {
     ActionInput input2 = new TestInput("/ghi/jkl");
     SpecialArtifact tree = createTreeArtifact("tree");
     TreeFileArtifact treeChild = TreeFileArtifact.createTreeOutput(tree, "child");
-    map.putWithNoDepOwner(input1, TestMetadata.create(1));
-    map.putWithNoDepOwner(input2, TestMetadata.create(2));
+    map.put(input1, TestMetadata.create(1));
+    map.put(input2, TestMetadata.create(2));
     map.putTreeArtifact(
         tree,
-        TreeArtifactValue.newBuilder(tree).putChild(treeChild, TestMetadata.create(3)).build(),
-        /*depOwner=*/ null);
+        TreeArtifactValue.newBuilder(tree).putChild(treeChild, TestMetadata.create(3)).build());
     // Sanity check
     assertThat(map.sizeForDebugging()).isEqualTo(3);
 
@@ -110,7 +109,7 @@ public void clear_removesAllElements() {
   public void putTreeArtifact_addsEmptyTreeArtifact() {
     SpecialArtifact tree = createTreeArtifact("tree");
 
-    map.putTreeArtifact(tree, TreeArtifactValue.empty(), /*depOwner=*/ null);
+    map.putTreeArtifact(tree, TreeArtifactValue.empty());
 
     assertThat(map.sizeForDebugging()).isEqualTo(1);
     assertContainsTree(tree, TreeArtifactValue.empty());
@@ -129,7 +128,7 @@ public void putTreeArtifact_addsTreeArtifactAndAllChildren() {
             .putChild(child2, child2Metadata)
             .build();
 
-    map.putTreeArtifact(tree, treeValue, /*depOwner=*/ null);
+    map.putTreeArtifact(tree, treeValue);
 
     assertThat(map.sizeForDebugging()).isEqualTo(1);
     assertContainsTree(tree, treeValue);
@@ -144,11 +143,11 @@ public void putTreeArtifact_mixedTreeAndFiles_addsTreeAndChildren() {
     FileArtifactValue childMetadata = TestMetadata.create(1);
     ActionInput file = ActionInputHelper.fromPath("file");
     FileArtifactValue fileMetadata = TestMetadata.create(2);
-    map.putWithNoDepOwner(file, fileMetadata);
+    map.put(file, fileMetadata);
     TreeArtifactValue treeValue =
         TreeArtifactValue.newBuilder(tree).putChild(child, childMetadata).build();
 
-    map.putTreeArtifact(tree, treeValue, /*depOwner=*/ null);
+    map.putTreeArtifact(tree, treeValue);
 
     assertContainsTree(tree, treeValue);
     assertContainsFile(child, childMetadata);
@@ -168,8 +167,8 @@ public void putTreeArtifact_multipleTrees_addsAllTreesAndChildren() {
     TreeArtifactValue tree2Value =
         TreeArtifactValue.newBuilder(tree2).putChild(tree2Child, tree2ChildMetadata).build();
 
-    map.putTreeArtifact(tree1, tree1Value, /*depOwner=*/ null);
-    map.putTreeArtifact(tree2, tree2Value, /*depOwner=*/ null);
+    map.putTreeArtifact(tree1, tree1Value);
+    map.putTreeArtifact(tree2, tree2Value);
 
     assertContainsTree(tree1, tree1Value);
     assertContainsFile(tree1Child, tree1ChildMetadata);
@@ -183,9 +182,9 @@ public void putTreeArtifact_multipleTreesUnderSameDirectory_addsAllTrees() {
     SpecialArtifact tree2 = createTreeArtifact("dir/tree2");
     SpecialArtifact tree3 = createTreeArtifact("dir/tree3");
 
-    map.putTreeArtifact(tree1, TreeArtifactValue.empty(), /*depOwner=*/ null);
-    map.putTreeArtifact(tree2, TreeArtifactValue.empty(), /*depOwner=*/ null);
-    map.putTreeArtifact(tree3, TreeArtifactValue.empty(), /*depOwner=*/ null);
+    map.putTreeArtifact(tree1, TreeArtifactValue.empty());
+    map.putTreeArtifact(tree2, TreeArtifactValue.empty());
+    map.putTreeArtifact(tree3, TreeArtifactValue.empty());
 
     assertContainsTree(tree1, TreeArtifactValue.empty());
     assertContainsTree(tree2, TreeArtifactValue.empty());
@@ -200,9 +199,9 @@ public void putTreeArtifact_afterPutTreeArtifactWithSameExecPath_doesNothing() {
     TreeArtifactValue tree1Value = TreeArtifactValue.empty();
     TreeArtifactValue tree2Value =
         TreeArtifactValue.newBuilder(tree2).putChild(tree2File, TestMetadata.create(1)).build();
-    map.putTreeArtifact(tree1, tree1Value, /*depOwner=*/ null);
+    map.putTreeArtifact(tree1, tree1Value);
 
-    map.putTreeArtifact(tree2, tree2Value, /*depOwner=*/ null);
+    map.putTreeArtifact(tree2, tree2Value);
 
     assertContainsTree(tree1, tree1Value);
     // Cannot assertContainsTree since the execpath will point to tree1 instead.
@@ -216,11 +215,10 @@ public void putTreeArtifact_afterPutTreeArtifactWithSameExecPath_doesNothing() {
   public void putTreeArtifact_sameExecPathAsARegularFile_fails() {
     SpecialArtifact tree = createTreeArtifact("tree");
     ActionInput file = ActionInputHelper.fromPath(tree.getExecPath());
-    map.put(file, TestMetadata.create(1), /*depOwner=*/ null);
+    map.put(file, TestMetadata.create(1));
 
     assertThrows(
-        IllegalArgumentException.class,
-        () -> map.putTreeArtifact(tree, TreeArtifactValue.empty(), /*depOwner=*/ null));
+        IllegalArgumentException.class, () -> map.putTreeArtifact(tree, TreeArtifactValue.empty()));
   }
 
   private enum PutOrder {
@@ -249,9 +247,7 @@ public void putTreeArtifact_nestedFile_returnsNestedFileFromExecPath(
     TreeArtifactValue treeValue =
         TreeArtifactValue.newBuilder(tree).putChild(treeFile, treeFileMetadata).build();
 
-    putOrder.runPuts(
-        () -> map.put(file, fileMetadata, /*depOwner=*/ null),
-        () -> map.putTreeArtifact(tree, treeValue, /*depOwner=*/ null));
+    putOrder.runPuts(() -> map.put(file, fileMetadata), () -> map.putTreeArtifact(tree, treeValue));
 
     assertThat(map.getInputMetadata(file)).isSameInstanceAs(fileMetadata);
     assertThat(map.getInputMetadata(treeFile)).isSameInstanceAs(treeFileMetadata);
@@ -265,7 +261,7 @@ public void put_treeFileArtifact_addsEntry() {
         TreeFileArtifact.createTreeOutput(createTreeArtifact("tree"), "file");
     FileArtifactValue metadata = TestMetadata.create(1);
 
-    map.put(treeFile, metadata, /*depOwner=*/ null);
+    map.put(treeFile, metadata);
 
     assertContainsFile(treeFile, metadata);
   }
@@ -275,24 +271,23 @@ public void put_sameExecPathAsATree_fails() {
     SpecialArtifact tree = createTreeArtifact("tree");
     ActionInput file = ActionInputHelper.fromPath(tree.getExecPath());
     FileArtifactValue fileMetadata = TestMetadata.create(1);
-    map.putTreeArtifact(tree, TreeArtifactValue.empty(), /*depOwner=*/ null);
+    map.putTreeArtifact(tree, TreeArtifactValue.empty());
 
-    assertThrows(
-        IllegalArgumentException.class, () -> map.put(file, fileMetadata, /*depOwner=*/ null));
+    assertThrows(IllegalArgumentException.class, () -> map.put(file, fileMetadata));
   }
 
   @Test
   public void put_treeArtifact_fails() {
     SpecialArtifact tree = createTreeArtifact("tree");
     FileArtifactValue metadata = TestMetadata.create(1);
 
-    assertThrows(IllegalArgumentException.class, () -> map.put(tree, metadata, /*depOwner=*/ null));
+    assertThrows(IllegalArgumentException.class, () -> map.put(tree, metadata));
   }
 
   @Test
   public void getMetadata_actionInputWithTreeExecPath_returnsTreeArtifactEntries() {
     SpecialArtifact tree = createTreeArtifact("tree");
-    map.putTreeArtifact(tree, TreeArtifactValue.empty(), /*depOwner=*/ null);
+    map.putTreeArtifact(tree, TreeArtifactValue.empty());
     ActionInput input = ActionInputHelper.fromPath(tree.getExecPath());
 
     assertThat(map.getInputMetadata(input)).isEqualTo(TreeArtifactValue.empty().getMetadata());
@@ -309,7 +304,7 @@ public void getMetadata_actionInputWithTreeFileExecPath_returnsTreeArtifactEntri
     FileArtifactValue treeFileMetadata = TestMetadata.create(1);
     TreeArtifactValue treeValue =
         TreeArtifactValue.newBuilder(tree).putChild(treeFile, treeFileMetadata).build();
-    inputMap.putTreeArtifact(tree, treeValue, /*depOwner=*/ null);
+    inputMap.putTreeArtifact(tree, treeValue);
     ActionInput input = ActionInputHelper.fromPath(treeFile.getExecPath());
 
     FileArtifactValue metadata = inputMap.getInputMetadata(input);
@@ -327,7 +322,7 @@ public void getMetadata_artifactWithTreeFileExecPath_returnsNull() {
     TreeFileArtifact treeFile = TreeFileArtifact.createTreeOutput(tree, "file");
     TreeArtifactValue treeValue =
         TreeArtifactValue.newBuilder(tree).putChild(treeFile, TestMetadata.create(1)).build();
-    map.putTreeArtifact(tree, treeValue, /*depOwner=*/ null);
+    map.putTreeArtifact(tree, treeValue);
     Artifact artifact =
         ActionsTestUtil.createArtifactWithExecPath(artifactRoot, treeFile.getExecPath());
 
@@ -343,8 +338,7 @@ public void getMetadata_missingFileWithinTree_returnsNull() {
         tree,
         TreeArtifactValue.newBuilder(tree)
             .putChild(TreeFileArtifact.createTreeOutput(tree, "file"), TestMetadata.create(1))
-            .build(),
-        /*depOwner=*/ null);
+            .build());
     TreeFileArtifact nonexistentTreeFile = TreeFileArtifact.createTreeOutput(tree, "nonexistent");
 
     assertDoesNotContain(nonexistentTreeFile);
@@ -355,15 +349,15 @@ public void getInputMetadata_treeFileUnderFile_fails() {
     SpecialArtifact tree = createTreeArtifact("tree");
     TreeFileArtifact child = TreeFileArtifact.createTreeOutput(tree, "file");
     ActionInput file = ActionInputHelper.fromPath(tree.getExecPath());
-    map.put(file, TestMetadata.create(1), /*depOwner=*/ null);
+    map.put(file, TestMetadata.create(1));
 
     assertThrows(IllegalArgumentException.class, () -> map.getInputMetadata(child));
   }
 
   @Test
   public void getTreeMetadataForPrefix_nonTree() {
     ActionInput file = ActionInputHelper.fromPath("some/file");
-    map.put(file, TestMetadata.create(1), /* depOwner= */ null);
+    map.put(file, TestMetadata.create(1));
 
     assertThat(map.getTreeMetadataForPrefix(file.getExecPath())).isNull();
     assertThat(map.getTreeMetadataForPrefix(file.getExecPath().getParentDirectory())).isNull();
@@ -374,7 +368,7 @@ public void getTreeMetadataForPrefix_nonTree() {
   public void getTreeMetadataForPrefix_emptyTree() {
     SpecialArtifact tree = createTreeArtifact("a/tree");
     TreeArtifactValue treeValue = TreeArtifactValue.newBuilder(tree).build();
-    map.putTreeArtifact(tree, treeValue, /* depOwner= */ null);
+    map.putTreeArtifact(tree, treeValue);
 
     assertThat(map.getTreeMetadataForPrefix(tree.getExecPath().getParentDirectory())).isNull();
     assertThat(map.getTreeMetadataForPrefix(tree.getExecPath())).isEqualTo(treeValue);
@@ -388,7 +382,7 @@ public void getTreeMetadataForPrefix_nonEmptyTree() {
     TreeFileArtifact child = TreeFileArtifact.createTreeOutput(tree, "some/child");
     TreeArtifactValue treeValue =
         TreeArtifactValue.newBuilder(tree).putChild(child, TestMetadata.create(1)).build();
-    map.putTreeArtifact(tree, treeValue, /* depOwner= */ null);
+    map.putTreeArtifact(tree, treeValue);
 
     assertThat(map.getTreeMetadataForPrefix(tree.getExecPath().getParentDirectory())).isNull();
     assertThat(map.getTreeMetadataForPrefix(tree.getExecPath())).isEqualTo(treeValue);
@@ -401,7 +395,7 @@ public void getTreeMetadataForPrefix_nonEmptyTree() {
 
   @Test
   public void getters_missingTree_returnNull() {
-    map.putTreeArtifact(createTreeArtifact("tree"), TreeArtifactValue.empty(), /*depOwner=*/ null);
+    map.putTreeArtifact(createTreeArtifact("tree"), TreeArtifactValue.empty());
     SpecialArtifact otherTree = createTreeArtifact("other");
 
     assertDoesNotContain(otherTree);
@@ -431,7 +425,7 @@ public void stress() {
       Collections.shuffle(data);
       for (int i = 0; i < data.size(); ++i) {
         TestEntry entry = data.get(i);
-        map.putWithNoDepOwner(entry.input, entry.metadata);
+        map.put(entry.input, entry.metadata);
       }
       assertThat(map.sizeForDebugging()).isEqualTo(data.size());
       for (int i = 0; i < data.size(); ++i) {
@@ -442,7 +436,7 @@ public void stress() {
   }
 
   private void put(String execPath, int value) {
-    map.putWithNoDepOwner(new TestInput(execPath), TestMetadata.create(value));
+    map.put(new TestInput(execPath), TestMetadata.create(value));
   }
 
   private void assertContains(String execPath, int value) {
@@ -567,11 +561,6 @@ public boolean wasModifiedSinceDigest(Path path) {
       throw new UnsupportedOperationException();
     }
 
-    @Override
-    public boolean isRemote() {
-      return false;
-    }
-
     @Override
     public FileContentsProxy getContentsProxy() {
       throw new UnsupportedOperationException();
diff --git a/src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java b/src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java
--- a/src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java
+++ b/src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java
@@ -64,7 +64,7 @@ public void createRoots() throws Exception {
   @Test
   public void regularArtifact() {
     Artifact file = ActionsTestUtil.createArtifact(outputRoot, "file");
-    inputMap.put(file, DUMMY_METADATA, /* depOwner= */ null);
+    inputMap.put(file, DUMMY_METADATA);
     CompletionContext ctx = createCompletionContext(/* expandFilesets= */ true);
 
     assertThat(visit(ctx, file)).containsExactly(file);
@@ -82,7 +82,7 @@ public void treeArtifact_present() {
             .putChild(treeFile1, DUMMY_METADATA)
             .putChild(treeFile2, DUMMY_METADATA)
             .build();
-    inputMap.putTreeArtifact(tree, treeValue, /* depOwner= */ null);
+    inputMap.putTreeArtifact(tree, treeValue);
     treeExpansions.put(tree, treeValue);
     CompletionContext ctx = createCompletionContext(/* expandFilesets= */ true);
 
@@ -93,7 +93,7 @@ public void treeArtifact_present() {
   @Test
   public void fileset_noExpansion() {
     SpecialArtifact fileset = createFileset("fs");
-    inputMap.put(fileset, DUMMY_METADATA, /* depOwner= */ null);
+    inputMap.put(fileset, DUMMY_METADATA);
     filesetExpansions.put(
         fileset,
         FilesetOutputTree.create(
@@ -111,7 +111,7 @@ public void fileset_noExpansion() {
   @Test
   public void fileset_withExpansion() throws Exception {
     SpecialArtifact fileset = createFileset("fs");
-    inputMap.put(fileset, DUMMY_METADATA, /* depOwner= */ null);
+    inputMap.put(fileset, DUMMY_METADATA);
     ImmutableList<FilesetOutputSymlink> links =
         ImmutableList.of(filesetLink("a1", "b1"), filesetLink("a2", "b2"));
     filesetExpansions.put(fileset, FilesetOutputTree.create(links));
diff --git a/src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java b/src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java
--- a/src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java
+++ b/src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java
@@ -303,15 +303,8 @@ private CompletionContext getCompletionContext(
       Map<SpecialArtifact, TreeArtifactValue> treeMetadata,
       @Nullable FileArtifactValue baselineCoverageValue) {
     ActionInputMap inputMap = new ActionInputMap(0);
-
-    for (Map.Entry<Artifact, FileArtifactValue> entry : metadata.entrySet()) {
-      inputMap.put(entry.getKey(), entry.getValue(), /* depOwner= */ null);
-    }
-
-    for (Map.Entry<SpecialArtifact, TreeArtifactValue> entry : treeMetadata.entrySet()) {
-      inputMap.putTreeArtifact(entry.getKey(), entry.getValue(), /* depOwner= */ null);
-    }
-
+    metadata.forEach(inputMap::put);
+    treeMetadata.forEach(inputMap::putTreeArtifact);
     return new CompletionContext(
         directories.getExecRoot(TestConstants.WORKSPACE_NAME),
         ImmutableMap.copyOf(treeMetadata),
diff --git a/src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java b/src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java
--- a/src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java
+++ b/src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java
@@ -89,7 +89,6 @@
 import org.junit.runner.RunWith;
 import org.junit.runners.JUnit4;
 import org.mockito.Mockito;
-import org.mockito.MockitoAnnotations;
 
 /** Test for {@link ByteStreamBuildEventArtifactUploader}. */
 @RunWith(JUnit4.class)
@@ -156,11 +155,6 @@ public void tearDown() throws Exception {
     server.awaitTermination();
   }
 
-  @Before
-  public void setup() {
-    MockitoAnnotations.initMocks(this);
-  }
-
   @Test
   public void uploadsShouldWork() throws Exception {
     int numUploads = 2;
@@ -384,7 +378,7 @@ public void someUploadsFail_succeedsWithWarningMessages() throws Exception {
           @Override
           public StreamObserver<WriteRequest> write(StreamObserver<WriteResponse> response) {
             StreamObserver<WriteRequest> delegate = super.write(response);
-            return new StreamObserver<WriteRequest>() {
+            return new StreamObserver<>() {
               private boolean failed;
 
               @Override
@@ -530,15 +524,16 @@ private Artifact createRemoteArtifact(
     HashCode h = HashCode.fromString(DIGEST_UTIL.compute(b).getHash());
     FileArtifactValue f =
         FileArtifactValue.createForRemoteFile(h.asBytes(), b.length, /* locationIndex= */ 1);
-    inputs.putWithNoDepOwner(a, f);
+    inputs.put(a, f);
     return a;
   }
 
-  private CombinedCache newCombinedCache(ReferenceCountedChannel channel, RemoteRetrier retrier) {
+  private static CombinedCache newCombinedCache(
+      ReferenceCountedChannel channel, RemoteRetrier retrier) {
     return newCombinedCache(channel, retrier, new AllMissingDigestsFinder());
   }
 
-  private CombinedCache newCombinedCache(
+  private static CombinedCache newCombinedCache(
       ReferenceCountedChannel channel,
       RemoteRetrier retrier,
       MissingDigestsFinder missingDigestsFinder) {
diff --git a/src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java b/src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java
--- a/src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java
+++ b/src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java
@@ -96,15 +96,12 @@ enum FilesystemTestParam {
     REMOTE;
 
     FileSystem getFilesystem(RemoteActionFileSystem actionFs) {
-      switch (this) {
-        case LOCAL:
-          return actionFs.getLocalFileSystem();
-        case REMOTE:
-          return actionFs.getRemoteOutputTree();
-      }
-      throw new IllegalStateException();
+      return switch (this) {
+        case LOCAL -> actionFs.getLocalFileSystem();
+        case REMOTE -> actionFs.getRemoteOutputTree();
+      };
     }
-  };
+  }
 
   @Before
   public void setUp() throws IOException {
@@ -893,7 +890,7 @@ public void readdir_notFound() throws Exception {
     assertReaddirThrows(actionFs, path, /* followSymlinks= */ true);
   }
 
-  private void assertReaddir(
+  private static void assertReaddir(
       RemoteActionFileSystem actionFs,
       PathFragment dirPath,
       boolean followSymlinks,
@@ -905,9 +902,8 @@ private void assertReaddir(
             stream(expected).map(Dirent::getName).collect(toImmutableList()));
   }
 
-  private void assertReaddirThrows(
-      RemoteActionFileSystem actionFs, PathFragment dirPath, boolean followSymlinks)
-      throws Exception {
+  private static void assertReaddirThrows(
+      RemoteActionFileSystem actionFs, PathFragment dirPath, boolean followSymlinks) {
     assertThrows(IOException.class, () -> actionFs.readdir(dirPath, followSymlinks));
     assertThrows(IOException.class, () -> actionFs.getDirectoryEntries(dirPath));
   }
@@ -1018,7 +1014,7 @@ public void readSymbolicLink_fromInputArtifactData_unresolvedSymlink() throws Ex
     // an unrealistic scenario, as symlinks are always materialized even when produced remotely.
     Path symlinkPath = getLocalFileSystem(actionFs).getPath(symlink.getPath().getPathString());
     symlinkPath.createSymbolicLink(targetPath);
-    inputs.putWithNoDepOwner(symlink, FileArtifactValue.createForUnresolvedSymlink(symlinkPath));
+    inputs.put(symlink, FileArtifactValue.createForUnresolvedSymlink(symlinkPath));
     symlinkPath.delete();
 
     assertThat(actionFs.readSymbolicLink(getOutputPath("symlink"))).isEqualTo(targetPath);
@@ -1353,7 +1349,7 @@ private Artifact createRemoteArtifact(
             Utf8.encodedLength(content),
             /* locationIndex= */ 1,
             /* expirationTime= */ null);
-    inputs.putWithNoDepOwner(a, f);
+    inputs.put(a, f);
     return a;
   }
 
@@ -1362,7 +1358,7 @@ private SpecialArtifact createRemoteTreeArtifact(
       String pathFragment, Map<String, String> contentMap, ActionInputMap inputs) {
     SpecialArtifact a =
         ActionsTestUtil.createTreeArtifactWithGeneratingAction(outputRoot, pathFragment);
-    inputs.putTreeArtifact(a, createRemoteTreeArtifactValue(a, contentMap), /* depOwner= */ null);
+    inputs.putTreeArtifact(a, createRemoteTreeArtifactValue(a, contentMap));
     return a;
   }
 
@@ -1393,7 +1389,7 @@ private Artifact createLocalArtifact(String pathFragment, String contents, Actio
     // Caution: there's a race condition between stating the file and computing the
     // digest. We need to stat first, since we're using the stat to detect changes.
     // We follow symlinks here to be consistent with getDigest.
-    inputs.putWithNoDepOwner(
+    inputs.put(
         a,
         FileArtifactValue.createFromStat(path, path.stat(Symlinks.FOLLOW), SyscallCache.NO_CACHE));
     return a;
@@ -1413,11 +1409,11 @@ private SpecialArtifact createLocalTreeArtifact(
     }
     SpecialArtifact a =
         ActionsTestUtil.createTreeArtifactWithGeneratingAction(outputRoot, pathFragment);
-    inputs.putTreeArtifact(a, createLocalTreeArtifactValue(a, contentMap), /* depOwner= */ null);
+    inputs.putTreeArtifact(a, createLocalTreeArtifactValue(a, contentMap));
     return a;
   }
 
-  private TreeArtifactValue createLocalTreeArtifactValue(
+  private static TreeArtifactValue createLocalTreeArtifactValue(
       SpecialArtifact a, Map<String, String> contentMap) throws IOException {
     TreeArtifactValue.Builder builder = TreeArtifactValue.newBuilder(a);
     for (String name : contentMap.keySet()) {
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java
@@ -142,7 +142,7 @@ public void withNonArtifactInput() throws Exception {
         FileArtifactValue.createForNormalFile(
             new byte[] {1, 2, 3}, /* proxy= */ null, /* size= */ 10L);
     ActionInputMap map = new ActionInputMap(1);
-    map.putWithNoDepOwner(input, metadata);
+    map.put(input, metadata);
     assertThat(map.getInputMetadata(input)).isEqualTo(metadata);
     ActionInputMetadataProvider inputMetadataProvider =
         new ActionInputMetadataProvider(execRoot.asFragment(), map, ImmutableMap.of());
@@ -158,7 +158,7 @@ public void withArtifactInput() throws Exception {
         FileArtifactValue.createForNormalFile(
             new byte[] {1, 2, 3}, /* proxy= */ null, /* size= */ 10L);
     ActionInputMap map = new ActionInputMap(1);
-    map.putWithNoDepOwner(artifact, metadata);
+    map.put(artifact, metadata);
     ActionInputMetadataProvider inputMetadataProvider =
         new ActionInputMetadataProvider(execRoot.asFragment(), map, ImmutableMap.of());
     assertThat(inputMetadataProvider.getInputMetadata(artifact)).isEqualTo(metadata);
@@ -437,7 +437,7 @@ public void fileArtifactMaterializedAsSymlinkToFileArtifact(
     }
 
     ActionInputMap inputMap = new ActionInputMap(0);
-    inputMap.putWithNoDepOwner(inputArtifact, inputMetadata);
+    inputMap.put(inputArtifact, inputMetadata);
 
     RemoteActionFileSystem actionFs =
         createRemoteActionFileSystem(inputMap, ImmutableSet.of(outputArtifact));
@@ -515,7 +515,7 @@ public void treeArtifactMaterializedAsSymlinkToAnotherTreeArtifact(
     TreeArtifactValue inputMetadata = builder.build();
 
     ActionInputMap inputMap = new ActionInputMap(0);
-    inputMap.putTreeArtifact(inputArtifact, inputMetadata, /* depOwner= */ null);
+    inputMap.putTreeArtifact(inputArtifact, inputMetadata);
 
     RemoteActionFileSystem actionFs =
         createRemoteActionFileSystem(inputMap, ImmutableSet.of(outputArtifact));
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java
@@ -248,12 +248,6 @@ public void flakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringInp
     helper.runFlakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringInputChecking();
   }
 
-  @Test
-  public void flakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringLostInputHandling()
-      throws Exception {
-    helper.runFlakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringLostInputHandling();
-  }
-
   @Test
   public void discoveredCppModuleLost() throws Exception {
     skipIfBazel();
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java b/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java
@@ -2664,7 +2664,41 @@ && isActionExecutionKey(context, fail)) {
     testCase.assertContainsError("Executing genrule //foo:fail failed");
   }
 
-  private void runFlakyActionFailsAfterRewind_raceWithIndirectConsumer() throws Exception {
+  /**
+   * Tests handling of an action that is rewound and completes with an error in between the time
+   * that a second action declares a dependency on it and consumes it during input checking, where
+   * the second action depends on the lost input indirectly (via an {@link ArtifactNestedSetKey}).
+   *
+   * <p>Targets in this test:
+   *
+   * <ul>
+   *   <li>{@code :flaky_lost}: initially executes successfully, but then gets rewound and completes
+   *       with an error.
+   *   <li>{@code :top1}: initiates rewinding on {@code :flaky_lost}.
+   *   <li>{@code :top2}: depends indirectly on {@code :flaky_lost} and observes it as an undone
+   *       input.
+   * </ul>
+   *
+   * <p>Order of events in this test:
+   *
+   * <ol>
+   *   <li>{@code :top2} requests its inputs from Skyframe, including an {@link
+   *       ArtifactNestedSetKey} containing {@code flaky_lost.out}. It is not done, so {@code :top2}
+   *       needs a Skyframe restart.
+   *   <li>The {@link ArtifactNestedSetKey} containing {@code flaky_lost.out} completes
+   *       successfully.
+   *   <li>{@code :top2} resumes after the Skyframe restart.
+   *   <li>{@code :top1} observes {@code flaky_lost.out} to be a lost input and rewinds {@code
+   *       :flaky_lost}.
+   *   <li>{@code :flaky_lost} executes a second time, and this time the action fails.
+   *   <li>{@code :top2} has no missing direct deps, but cannot look up {@code flaky_lost.out}
+   *       because its generating action failed. In order to propagate a valid root cause, it
+   *       initiates rewinding of the {@link ArtifactNestedSetKey}.
+   * </ol>
+   */
+  public final void
+      runFlakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringInputChecking()
+          throws Exception {
     ensureMultipleJobs();
     testCase.write(
         "foo/defs.bzl",
@@ -2713,73 +2747,6 @@ def _action_with_indirect_input(ctx):
             cmd = "touch $@",
         )
         """);
-    Label top2 = Label.parseCanonical("//foo:top2");
-    Label top1 = Label.parseCanonical("//foo:top1");
-    Label flakyLost = Label.parseCanonical("//foo:flaky_lost");
-
-    Map<Label, TargetCompleteEvent> targetCompleteEvents = recordTargetCompleteEvents();
-    List<SkyKey> rewoundKeys = collectOrderedRewoundKeys();
-
-    assertThrows(
-        BuildFailedException.class, () -> testCase.buildTarget("//foo:top1", "//foo:top2"));
-    verifyAllSpawnShimsConsumed();
-    assertThat(rewoundArtifactOwnerLabels(rewoundKeys)).containsExactly("//foo:flaky_lost");
-
-    // Check that TargetCompleteEvents were posted with the correct root cause.
-    if (keepGoing()) {
-      assertThat(targetCompleteEvents.keySet()).containsExactly(top1, top2);
-    } else {
-      assertThat(targetCompleteEvents).hasSize(1);
-      assertThat(targetCompleteEvents.keySet()).containsAnyOf(top1, top2);
-    }
-    targetCompleteEvents.forEach(
-        (target, event) ->
-            assertWithMessage("%s", target)
-                .that(event.getRootCauses().getSingleton().getLabel())
-                .isEqualTo(flakyLost));
-
-    // Trying again irons out the flaky failure with no rewinding.
-    rewoundKeys.clear();
-    targetCompleteEvents.clear();
-    testCase.buildTarget("//foo:top1", "//foo:top2");
-    assertThat(rewoundKeys).isEmpty();
-  }
-
-  /**
-   * Tests handling of an action that is rewound and completes with an error in between the time
-   * that a second action declares a dependency on it and consumes it during input checking, where
-   * the second action depends on the lost input indirectly (via an {@link ArtifactNestedSetKey}).
-   *
-   * <p>Targets in this test:
-   *
-   * <ul>
-   *   <li>{@code :flaky_lost}: initially executes successfully, but then gets rewound and completes
-   *       with an error.
-   *   <li>{@code :top1}: initiates rewinding on {@code :flaky_lost}.
-   *   <li>{@code :top2}: depends indirectly on {@code :flaky_lost} and observes it as an undone
-   *       input.
-   * </ul>
-   *
-   * <p>Order of events in this test:
-   *
-   * <ol>
-   *   <li>{@code :top2} requests its inputs from Skyframe, including an {@link
-   *       ArtifactNestedSetKey} containing {@code flaky_lost.out}. It is not done, so {@code :top2}
-   *       needs a Skyframe restart.
-   *   <li>The {@link ArtifactNestedSetKey} containing {@code flaky_lost.out} completes
-   *       successfully.
-   *   <li>{@code :top2} resumes after the Skyframe restart.
-   *   <li>{@code :top1} observes {@code flaky_lost.out} to be a lost input and rewinds {@code
-   *       :flaky_lost}.
-   *   <li>{@code :flaky_lost} executes a second time, and this time the action fails.
-   *   <li>{@code :top2} has no missing direct deps, but cannot look up {@code flaky_lost.out}
-   *       because its generating action failed. In order to propagate a valid root cause, it
-   *       initiates rewinding of the {@link ArtifactNestedSetKey}.
-   * </ol>
-   */
-  public final void
-      runFlakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringInputChecking()
-          throws Exception {
     CountDownLatch top2RestartedWithDoneNestedSet = new CountDownLatch(1);
     CountDownLatch errorSet = new CountDownLatch(1);
     addSpawnShim(
@@ -2817,83 +2784,36 @@ def _action_with_indirect_input(ctx):
           }
         });
 
-    runFlakyActionFailsAfterRewind_raceWithIndirectConsumer();
-  }
+    Label top2 = Label.parseCanonical("//foo:top2");
+    Label top1 = Label.parseCanonical("//foo:top1");
+    Label flakyLost = Label.parseCanonical("//foo:flaky_lost");
 
-  /**
-   * Tests handling of an action that is rewound and completes with an error in between the time
-   * that a second action observes it to be lost and attempts to look it up during lost input
-   * handling, where the second action depends on the lost input indirectly (via an {@link
-   * ArtifactNestedSetKey}).
-   *
-   * <p>Targets in this test:
-   *
-   * <ul>
-   *   <li>{@code :flaky_lost}: initially executes successfully, but then gets rewound and completes
-   *       with an error.
-   *   <li>{@code :top1}: initiates rewinding on {@code :flaky_lost}.
-   *   <li>{@code :top2}: depends indirectly on {@code :flaky_lost} and observes it as an undone
-   *       input.
-   * </ul>
-   *
-   * <p>Order of events in this test:
-   *
-   * <ol>
-   *   <li>{@code :top2} requests its inputs from Skyframe, including an {@link
-   *       ArtifactNestedSetKey} containing {@code flaky_lost.out}. All are done, so it begins to
-   *       execute, and observes {@code flaky_lost.out} to be lost.
-   *   <li>{@code :top1} observes {@code flaky_lost.out} to be a lost input and rewinds {@code
-   *       :flaky_lost}.
-   *   <li>{@code :flaky_lost} executes a second time, and this time the action fails.
-   *   <li>{@code :top2} attempts to handle lost inputs by initiating rewinding, but this requires
-   *       looking up {@code flaky_lost.out}, which is undone.
-   * </ol>
-   */
-  public final void
-      runFlakyActionFailsAfterRewind_raceWithIndirectConsumer_undoneDuringLostInputHandling()
-          throws Exception {
-    CountDownLatch top2Executing = new CountDownLatch(1);
-    CountDownLatch errorSet = new CountDownLatch(1);
-    addSpawnShim(
-        "Executing genrule //foo:top1",
-        (spawn, context) -> {
-          top2Executing.await();
-          addSpawnShim(
-              "Executing genrule //foo:flaky_lost",
-              (spawn2, context2) ->
-                  ExecResult.ofException(
-                      new SpawnExecException(
-                          "Flaky action failure",
-                          FAILED_RESULT,
-                          /* forciblyRunRemotely= */ false,
-                          /* catastrophe= */ false)));
-          ImmutableList<ActionInput> lostInputs =
-              ImmutableList.of(SpawnInputUtils.getInputWithName(spawn, "flaky_lost.out"));
-          return createLostInputsExecException(
-              context, lostInputs, new ActionInputDepOwnerMap(lostInputs));
-        });
-    addSpawnShim(
-        "Action foo/top2.out",
-        (spawn, context) -> {
-          top2Executing.countDown();
-          awaitUninterruptibly(errorSet);
-          ImmutableList<ActionInput> lostInputs =
-              ImmutableList.of(SpawnInputUtils.getInputWithName(spawn, "flaky_lost.out"));
-          return createLostInputsExecException(
-              context, lostInputs, new ActionInputDepOwnerMap(lostInputs));
-        });
+    Map<Label, TargetCompleteEvent> targetCompleteEvents = recordTargetCompleteEvents();
+    List<SkyKey> rewoundKeys = collectOrderedRewoundKeys();
 
-    testCase.injectListenerAtStartOfNextBuild(
-        (key, type, order, context) -> {
-          if (isActionExecutionKey(key, Label.parseCanonicalUnchecked("//foo:flaky_lost"))
-              && type == EventType.SET_VALUE
-              && order == Order.AFTER
-              && ValueWithMetadata.getMaybeErrorInfo((SkyValue) context) != null) {
-            errorSet.countDown();
-          }
-        });
+    assertThrows(
+        BuildFailedException.class, () -> testCase.buildTarget("//foo:top1", "//foo:top2"));
+    verifyAllSpawnShimsConsumed();
+    assertThat(rewoundArtifactOwnerLabels(rewoundKeys)).containsExactly("//foo:flaky_lost");
 
-    runFlakyActionFailsAfterRewind_raceWithIndirectConsumer();
+    // Check that TargetCompleteEvents were posted with the correct root cause.
+    if (keepGoing()) {
+      assertThat(targetCompleteEvents.keySet()).containsExactly(top1, top2);
+    } else {
+      assertThat(targetCompleteEvents).hasSize(1);
+      assertThat(targetCompleteEvents.keySet()).containsAnyOf(top1, top2);
+    }
+    targetCompleteEvents.forEach(
+        (target, event) ->
+            assertWithMessage("%s", target)
+                .that(event.getRootCauses().getSingleton().getLabel())
+                .isEqualTo(flakyLost));
+
+    // Trying again irons out the flaky failure with no rewinding.
+    rewoundKeys.clear();
+    targetCompleteEvents.clear();
+    testCase.buildTarget("//foo:top1", "//foo:top2");
+    assertThat(rewoundKeys).isEmpty();
   }
 
   public void runDiscoveredCppModuleLost() throws Exception {
EOF_114329324912

# Set environment variables for Bazel
export USE_BAZEL_VERSION=8.1.1
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Create test working directory
mkdir -p $HOME/bazeltest

# Run the specific test targets using the correct Bazel target names
# Based on the BUILD file analysis, the targets are:
# 1. ActionsTests (includes ActionInputMapTest and CompletionContextTest)
# 2. TargetCompleteEventTest
# 3. RemoteTests (includes ByteStreamBuildEventArtifactUploaderTest and RemoteActionFileSystemTest)
# 4. ActionOutputMetadataStoreTest
# 5. RewindingTest (includes RewindingTest and RewindingTestsHelper)

bazel test \
    --test_output=errors \
    --test_summary=detailed \
    --jobs=4 \
    --local_test_jobs=4 \
    //src/test/java/com/google/devtools/build/lib/actions:ActionsTests \
    //src/test/java/com/google/devtools/build/lib/analysis:TargetCompleteEventTest \
    //src/test/java/com/google/devtools/build/lib/remote:RemoteTests \
    //src/test/java/com/google/devtools/build/lib/skyframe:ActionOutputMetadataStoreTest \
    //src/test/java/com/google/devtools/build/lib/skyframe/rewinding:RewindingTest

rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 67b672d1b822f4d39766d0cb932b9894b6e294ce \
    "src/test/java/com/google/devtools/build/lib/actions/ActionInputMapTest.java" \
    "src/test/java/com/google/devtools/build/lib/actions/CompletionContextTest.java" \
    "src/test/java/com/google/devtools/build/lib/analysis/TargetCompleteEventTest.java" \
    "src/test/java/com/google/devtools/build/lib/remote/ByteStreamBuildEventArtifactUploaderTest.java" \
    "src/test/java/com/google/devtools/build/lib/remote/RemoteActionFileSystemTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/ActionOutputMetadataStoreTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTest.java" \
    "src/test/java/com/google/devtools/build/lib/skyframe/rewinding/RewindingTestsHelper.java"