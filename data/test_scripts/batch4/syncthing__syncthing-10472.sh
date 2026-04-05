#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Ensure we're on the correct commit and checkout the target test files
git checkout ce884e5d7253ed82379f918e169438eb64fcece0 "lib/model/folder_recvonly_test.go" "lib/model/folder_sendrecv_test.go" "lib/model/model_test.go" "lib/model/requests_test.go" "lib/model/testutils_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/model/folder_recvonly_test.go b/lib/model/folder_recvonly_test.go
--- a/lib/model/folder_recvonly_test.go
+++ b/lib/model/folder_recvonly_test.go
@@ -407,8 +407,8 @@ func TestRecvOnlyRemoteUndoChanges(t *testing.T) {
 	must(t, m.IndexUpdate(conn, &protocol.IndexUpdate{Folder: "ro", Files: files}))
 
 	// Ensure the pull to resolve conflicts (content identical) happened
-	must(t, f.doInSync(func() error {
-		f.pull()
+	must(t, f.doInSync(func(ctx context.Context) error {
+		f.pull(ctx)
 		return nil
 	}))
 
@@ -456,7 +456,7 @@ func TestRecvOnlyRevertOwnID(t *testing.T) {
 	// Monitor the outcome
 	sub := f.evLogger.Subscribe(events.LocalIndexUpdated)
 	defer sub.Unsubscribe()
-	ctx, cancel := context.WithCancel(context.Background())
+	ctx, cancel := context.WithCancel(t.Context())
 	defer cancel()
 	go func() {
 		defer cancel()
@@ -567,7 +567,7 @@ func setupKnownFiles(t *testing.T, ffs fs.Filesystem, data []byte) []protocol.Fi
 	if err != nil {
 		t.Fatal(err)
 	}
-	blocks, _ := scanner.Blocks(context.TODO(), bytes.NewReader(data), protocol.BlockSize(int64(len(data))), int64(len(data)), nil)
+	blocks, _ := scanner.Blocks(t.Context(), bytes.NewReader(data), protocol.BlockSize(int64(len(data))), int64(len(data)), nil)
 	knownFiles := []protocol.FileInfo{
 		{
 			Name:        "knownDir",
diff --git a/lib/model/folder_sendrecv_test.go b/lib/model/folder_sendrecv_test.go
--- a/lib/model/folder_sendrecv_test.go
+++ b/lib/model/folder_sendrecv_test.go
@@ -65,8 +65,6 @@ func prepareTmpFile(to fs.Filesystem) (string, error) {
 	return tmpName, nil
 }
 
-var folders = []string{"default"}
-
 var diffTestData = []struct {
 	a string
 	b string
@@ -112,23 +110,22 @@ func createEmptyFileInfo(t *testing.T, name string, fs fs.Filesystem) protocol.F
 }
 
 // Sets up a folder and model, but makes sure the services aren't actually running.
-func setupSendReceiveFolder(t testing.TB, files ...protocol.FileInfo) (*testModel, *sendReceiveFolder, context.CancelFunc) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
+func setupSendReceiveFolder(t testing.TB, files ...protocol.FileInfo) (*testModel, *sendReceiveFolder) {
+	w, fcfg := newDefaultCfgWrapper(t)
 	// Initialise model and stop immediately.
 	model := setupModel(t, w)
 	model.cancel()
 	<-model.stopped
 	r, _ := model.folderRunners.Get(fcfg.ID)
 	f := r.(*sendReceiveFolder)
 	f.tempPullErrors = make(map[string]string)
-	f.ctx = context.Background()
 
 	// Update index
 	if files != nil {
 		f.updateLocalsFromScanning(files)
 	}
 
-	return model, f, wCancel
+	return model, f
 }
 
 // Layout of the files: (indexes from the above array)
@@ -146,12 +143,11 @@ func TestHandleFile(t *testing.T) {
 	requiredFile := existingFile
 	requiredFile.Blocks = blocks[1:]
 
-	_, f, wcfgCancel := setupSendReceiveFolder(t, existingFile)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t, existingFile)
 
 	copyChan := make(chan copyBlocksState, 1)
 
-	f.handleFile(requiredFile, copyChan)
+	f.handleFile(t.Context(), requiredFile, copyChan)
 
 	// Receive the results
 	toCopy := <-copyChan
@@ -188,16 +184,15 @@ func TestHandleFileWithTemp(t *testing.T) {
 	requiredFile := existingFile
 	requiredFile.Blocks = blocks[1:]
 
-	_, f, wcfgCancel := setupSendReceiveFolder(t, existingFile)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t, existingFile)
 
 	if _, err := prepareTmpFile(f.Filesystem()); err != nil {
 		t.Fatal(err)
 	}
 
 	copyChan := make(chan copyBlocksState, 1)
 
-	f.handleFile(requiredFile, copyChan)
+	f.handleFile(t.Context(), requiredFile, copyChan)
 
 	// Receive the results
 	toCopy := <-copyChan
@@ -238,8 +233,7 @@ func TestCopierFinder(t *testing.T) {
 	requiredFile.Blocks = blocks[1:]
 	requiredFile.Name = "file2"
 
-	_, f, wcfgCancel := setupSendReceiveFolder(t, existingFile)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t, existingFile)
 
 	if _, err := prepareTmpFile(f.Filesystem()); err != nil {
 		t.Fatal(err)
@@ -250,10 +244,10 @@ func TestCopierFinder(t *testing.T) {
 	finisherChan := make(chan *sharedPullerState, 1)
 
 	// Run a single fetcher routine
-	go f.copierRoutine(copyChan, pullChan, finisherChan)
+	go f.copierRoutine(t.Context(), copyChan, pullChan, finisherChan)
 	defer close(copyChan)
 
-	f.handleFile(requiredFile, copyChan)
+	f.handleFile(t.Context(), requiredFile, copyChan)
 
 	timeout := time.After(10 * time.Second)
 	pulls := make([]pullBlockState, 4)
@@ -302,7 +296,7 @@ func TestCopierFinder(t *testing.T) {
 	}
 
 	// Verify that the fetched blocks have actually been written to the temp file
-	blks, err := scanner.HashFile(context.TODO(), f.ID, f.Filesystem(), tempFile, protocol.MinBlockSize, nil)
+	blks, err := scanner.HashFile(t.Context(), f.ID, f.Filesystem(), tempFile, protocol.MinBlockSize, nil)
 	if err != nil {
 		t.Log(err)
 	}
@@ -319,8 +313,7 @@ func TestCopierCleanup(t *testing.T) {
 	// Create a file
 	file := setupFile("test", []int{0})
 	file.Size = 1
-	m, f, wcfgCancel := setupSendReceiveFolder(t, file)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t, file)
 
 	file.Blocks = []protocol.BlockInfo{blocks[1]}
 	file.Version = file.Version.Update(myID.Short())
@@ -352,8 +345,7 @@ func TestCopierCleanup(t *testing.T) {
 func TestDeregisterOnFailInCopy(t *testing.T) {
 	file := setupFile("filex", []int{0, 2, 0, 0, 5, 0, 0, 8})
 
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 
 	// Set up our evet subscription early
 	s := m.evLogger.Subscribe(events.ItemFinished)
@@ -371,8 +363,8 @@ func TestDeregisterOnFailInCopy(t *testing.T) {
 	finisherChan := make(chan *sharedPullerState)
 	dbUpdateChan := make(chan dbUpdateJob, 1)
 
-	copyChan, copyWg := startCopier(f, pullChan, finisherBufferChan)
-	go f.finisherRoutine(finisherChan, dbUpdateChan, make(chan string))
+	copyChan, copyWg := startCopier(t.Context(), f, pullChan, finisherBufferChan)
+	go f.finisherRoutine(t.Context(), finisherChan, dbUpdateChan, make(chan string))
 
 	defer func() {
 		close(copyChan)
@@ -382,7 +374,7 @@ func TestDeregisterOnFailInCopy(t *testing.T) {
 		close(finisherChan)
 	}()
 
-	f.handleFile(file, copyChan)
+	f.handleFile(t.Context(), file, copyChan)
 
 	// Receive a block at puller, to indicate that at least a single copier
 	// loop has been performed.
@@ -451,8 +443,7 @@ func TestDeregisterOnFailInCopy(t *testing.T) {
 func TestDeregisterOnFailInPull(t *testing.T) {
 	file := setupFile("filex", []int{0, 2, 0, 0, 5, 0, 0, 8})
 
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 
 	// Set up our evet subscription early
 	s := m.evLogger.Subscribe(events.ItemFinished)
@@ -470,14 +461,14 @@ func TestDeregisterOnFailInPull(t *testing.T) {
 	finisherChan := make(chan *sharedPullerState)
 	dbUpdateChan := make(chan dbUpdateJob, 1)
 
-	copyChan, copyWg := startCopier(f, pullChan, finisherBufferChan)
+	copyChan, copyWg := startCopier(t.Context(), f, pullChan, finisherBufferChan)
 	var pullWg sync.WaitGroup
 	pullWg.Add(1)
 	go func() {
-		f.pullerRoutine(pullChan, finisherBufferChan)
+		f.pullerRoutine(t.Context(), pullChan, finisherBufferChan)
 		pullWg.Done()
 	}()
-	go f.finisherRoutine(finisherChan, dbUpdateChan, make(chan string))
+	go f.finisherRoutine(t.Context(), finisherChan, dbUpdateChan, make(chan string))
 	defer func() {
 		// Unblock copier and puller
 		go func() {
@@ -492,7 +483,7 @@ func TestDeregisterOnFailInPull(t *testing.T) {
 		close(finisherChan)
 	}()
 
-	f.handleFile(file, copyChan)
+	f.handleFile(t.Context(), file, copyChan)
 
 	// Receive at finisher, we should error out as puller has nowhere to pull
 	// from.
@@ -553,8 +544,7 @@ func TestDeregisterOnFailInPull(t *testing.T) {
 }
 
 func TestIssue3164(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	ignDir := filepath.Join("issue3164", "oktodelete")
@@ -566,7 +556,7 @@ func TestIssue3164(t *testing.T) {
 		Name: "issue3164",
 	}
 
-	must(t, f.scanSubdirs(nil))
+	must(t, f.scanSubdirs(t.Context(), nil))
 
 	matcher := ignore.New(ffs)
 	must(t, matcher.Parse(bytes.NewBufferString("(?d)oktodelete"), ""))
@@ -583,8 +573,8 @@ func TestIssue3164(t *testing.T) {
 
 func TestDiff(t *testing.T) {
 	for i, test := range diffTestData {
-		a, _ := scanner.Blocks(context.TODO(), bytes.NewBufferString(test.a), test.s, -1, nil)
-		b, _ := scanner.Blocks(context.TODO(), bytes.NewBufferString(test.b), test.s, -1, nil)
+		a, _ := scanner.Blocks(t.Context(), bytes.NewBufferString(test.a), test.s, -1, nil)
+		b, _ := scanner.Blocks(t.Context(), bytes.NewBufferString(test.b), test.s, -1, nil)
 		_, d := blockDiff(a, b)
 		if len(d) != len(test.d) {
 			t.Fatalf("Incorrect length for diff %d; %d != %d", i, len(d), len(test.d))
@@ -604,9 +594,9 @@ func TestDiff(t *testing.T) {
 func BenchmarkDiff(b *testing.B) {
 	testCases := make([]struct{ a, b []protocol.BlockInfo }, 0, len(diffTestData))
 	for _, test := range diffTestData {
-		a, _ := scanner.Blocks(context.TODO(), bytes.NewBufferString(test.a), test.s, -1, nil)
-		b, _ := scanner.Blocks(context.TODO(), bytes.NewBufferString(test.b), test.s, -1, nil)
-		testCases = append(testCases, struct{ a, b []protocol.BlockInfo }{a, b})
+		aBlocks, _ := scanner.Blocks(b.Context(), bytes.NewBufferString(test.a), test.s, -1, nil)
+		bBlocks, _ := scanner.Blocks(b.Context(), bytes.NewBufferString(test.b), test.s, -1, nil)
+		testCases = append(testCases, struct{ a, b []protocol.BlockInfo }{aBlocks, bBlocks})
 	}
 	b.ReportAllocs()
 	b.ResetTimer()
@@ -643,8 +633,7 @@ func TestDiffEmpty(t *testing.T) {
 // option is true and the permissions do not match between the file on disk and
 // in the db.
 func TestDeleteIgnorePerms(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 	f.IgnorePerms = true
 
@@ -682,7 +671,7 @@ func TestCopyOwner(t *testing.T) {
 	)
 
 	// This test hung on a regression, taking a long time to fail - speed that up.
-	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
+	ctx, cancel := context.WithTimeout(t.Context(), 2*time.Second)
 	defer cancel()
 	go func() {
 		<-ctx.Done()
@@ -695,8 +684,7 @@ func TestCopyOwner(t *testing.T) {
 	// Set up a folder with the CopyParentOwner bit and backed by a fake
 	// filesystem.
 
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 	f.folder.FolderConfiguration = newFolderConfiguration(m.cfg, f.ID, f.Label, config.FilesystemTypeFake, "/TestCopyOwner")
 	f.folder.FolderConfiguration.CopyOwnershipFromParent = true
 
@@ -748,15 +736,15 @@ func TestCopyOwner(t *testing.T) {
 	// comes the finisher is done.
 
 	finisherChan := make(chan *sharedPullerState)
-	copierChan, copyWg := startCopier(f, nil, finisherChan)
-	go f.finisherRoutine(finisherChan, dbUpdateChan, nil)
+	copierChan, copyWg := startCopier(t.Context(), f, nil, finisherChan)
+	go f.finisherRoutine(t.Context(), finisherChan, dbUpdateChan, nil)
 	defer func() {
 		close(copierChan)
 		copyWg.Wait()
 		close(finisherChan)
 	}()
 
-	f.handleFile(file, copierChan)
+	f.handleFile(t.Context(), file, copierChan)
 	<-dbUpdateChan
 
 	info, err = f.mtimefs.Lstat("foo/bar/baz")
@@ -794,8 +782,7 @@ func TestCopyOwner(t *testing.T) {
 // TestSRConflictReplaceFileByDir checks that a conflict is created when an existing file
 // is replaced with a directory and versions are conflicting
 func TestSRConflictReplaceFileByDir(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	name := "foo"
@@ -826,8 +813,7 @@ func TestSRConflictReplaceFileByDir(t *testing.T) {
 // TestSRConflictReplaceFileByLink checks that a conflict is created when an existing file
 // is replaced with a link and versions are conflicting
 func TestSRConflictReplaceFileByLink(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	name := "foo"
@@ -859,8 +845,7 @@ func TestSRConflictReplaceFileByLink(t *testing.T) {
 // TestDeleteBehindSymlink checks that we don't delete or schedule a scan
 // when trying to delete a file behind a symlink.
 func TestDeleteBehindSymlink(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	link := "link"
@@ -898,16 +883,14 @@ func TestDeleteBehindSymlink(t *testing.T) {
 
 // Reproduces https://github.com/syncthing/syncthing/issues/6559
 func TestPullCtxCancel(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 
 	pullChan := make(chan pullBlockState)
 	finisherChan := make(chan *sharedPullerState)
 
-	var cancel context.CancelFunc
-	f.ctx, cancel = context.WithCancel(context.Background())
+	ctx, cancel := context.WithCancel(t.Context())
 
-	go f.pullerRoutine(pullChan, finisherChan)
+	go f.pullerRoutine(ctx, pullChan, finisherChan)
 	defer close(pullChan)
 
 	emptyState := func() pullBlockState {
@@ -940,8 +923,7 @@ func TestPullCtxCancel(t *testing.T) {
 }
 
 func TestPullDeleteUnscannedDir(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	dir := "foobar"
@@ -969,14 +951,13 @@ func TestPullDeleteUnscannedDir(t *testing.T) {
 }
 
 func TestPullCaseOnlyPerformFinish(t *testing.T) {
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	name := "foo"
 	contents := []byte("contents")
 	writeFile(t, ffs, name, contents)
-	must(t, f.scanSubdirs(nil))
+	must(t, f.scanSubdirs(t.Context(), nil))
 
 	var cur protocol.FileInfo
 	hasCur := false
@@ -1032,8 +1013,7 @@ func TestPullCaseOnlySymlink(t *testing.T) {
 }
 
 func testPullCaseOnlyDirOrSymlink(t *testing.T, dir bool) {
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 	ffs := f.Filesystem()
 
 	name := "foo"
@@ -1043,7 +1023,7 @@ func testPullCaseOnlyDirOrSymlink(t *testing.T, dir bool) {
 		must(t, ffs.CreateSymlink("target", name))
 	}
 
-	must(t, f.scanSubdirs(nil))
+	must(t, f.scanSubdirs(t.Context(), nil))
 	var cur protocol.FileInfo
 	hasCur := false
 	it, errFn := m.LocalFiles(f.ID, protocol.LocalDeviceID)
@@ -1089,8 +1069,7 @@ func testPullCaseOnlyDirOrSymlink(t *testing.T, dir bool) {
 }
 
 func TestPullTempFileCaseConflict(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 
 	copyChan := make(chan copyBlocksState, 1)
 
@@ -1106,7 +1085,7 @@ func TestPullTempFileCaseConflict(t *testing.T) {
 		fd.Close()
 	}
 
-	f.handleFile(file, copyChan)
+	f.handleFile(t.Context(), file, copyChan)
 
 	cs := <-copyChan
 	if _, err := cs.tempFile(); err != nil {
@@ -1117,8 +1096,7 @@ func TestPullTempFileCaseConflict(t *testing.T) {
 }
 
 func TestPullCaseOnlyRename(t *testing.T) {
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 
 	// tempNameConfl := fs.TempName(confl)
 
@@ -1132,7 +1110,7 @@ func TestPullCaseOnlyRename(t *testing.T) {
 		fd.Close()
 	}
 
-	must(t, f.scanSubdirs(nil))
+	must(t, f.scanSubdirs(t.Context(), nil))
 
 	cur, ok := m.testCurrentFolderFile(f.ID, name)
 	if !ok {
@@ -1158,8 +1136,7 @@ func TestPullSymlinkOverExistingWindows(t *testing.T) {
 		t.Skip()
 	}
 
-	m, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	m, f := setupSendReceiveFolder(t)
 	conn := addFakeConn(m, device1, f.ID)
 
 	name := "foo"
@@ -1172,7 +1149,7 @@ func TestPullSymlinkOverExistingWindows(t *testing.T) {
 		fd.Close()
 	}
 
-	must(t, f.scanSubdirs(nil))
+	must(t, f.scanSubdirs(t.Context(), nil))
 
 	file, ok := m.testCurrentFolderFile(f.ID, name)
 	if !ok {
@@ -1182,7 +1159,7 @@ func TestPullSymlinkOverExistingWindows(t *testing.T) {
 
 	scanChan := make(chan string)
 
-	changed, err := f.pullerIteration(scanChan)
+	changed, err := f.pullerIteration(t.Context(), scanChan)
 	must(t, err)
 	if changed != 1 {
 		t.Error("Expected one change in pull, got", changed)
@@ -1200,8 +1177,7 @@ func TestPullSymlinkOverExistingWindows(t *testing.T) {
 }
 
 func TestPullDeleteCaseConflict(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 
 	name := "foo"
 	fi := protocol.FileInfo{Name: "Foo"}
@@ -1232,8 +1208,7 @@ func TestPullDeleteCaseConflict(t *testing.T) {
 }
 
 func TestPullDeleteIgnoreChildDir(t *testing.T) {
-	_, f, wcfgCancel := setupSendReceiveFolder(t)
-	defer wcfgCancel()
+	_, f := setupSendReceiveFolder(t)
 
 	parent := "parent"
 	del := "ignored"
@@ -1268,12 +1243,12 @@ func cleanupSharedPullerState(s *sharedPullerState) {
 	s.writer.mut.Unlock()
 }
 
-func startCopier(f *sendReceiveFolder, pullChan chan<- pullBlockState, finisherChan chan<- *sharedPullerState) (chan copyBlocksState, *sync.WaitGroup) {
+func startCopier(ctx context.Context, f *sendReceiveFolder, pullChan chan<- pullBlockState, finisherChan chan<- *sharedPullerState) (chan copyBlocksState, *sync.WaitGroup) {
 	copyChan := make(chan copyBlocksState)
 	wg := new(sync.WaitGroup)
 	wg.Add(1)
 	go func() {
-		f.copierRoutine(copyChan, pullChan, finisherChan)
+		f.copierRoutine(ctx, copyChan, pullChan, finisherChan)
 		wg.Done()
 	}()
 	return copyChan, wg
diff --git a/lib/model/model_test.go b/lib/model/model_test.go
--- a/lib/model/model_test.go
+++ b/lib/model/model_test.go
@@ -77,9 +77,8 @@ func addFolderDevicesToClusterConfig(cc *protocol.ClusterConfig, remote protocol
 }
 
 func TestRequest(t *testing.T) {
-	wrapper, fcfg, cancel := newDefaultCfgWrapper()
+	wrapper, fcfg := newDefaultCfgWrapper(t)
 	ffs := fcfg.Filesystem()
-	defer cancel()
 	m := setupModel(t, wrapper)
 	defer cleanupModel(m)
 
@@ -164,8 +163,7 @@ func BenchmarkIndex_100(b *testing.B) {
 }
 
 func benchmarkIndex(b *testing.B, nfiles int) {
-	m, _, fcfg, wcfgCancel := setupModelWithConnection(b)
-	defer wcfgCancel()
+	m, _, fcfg := setupModelWithConnection(b)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	files := genFiles(nfiles)
@@ -191,8 +189,7 @@ func BenchmarkIndexUpdate_10000_1(b *testing.B) {
 }
 
 func benchmarkIndexUpdate(b *testing.B, nfiles, nufiles int) {
-	m, _, fcfg, wcfgCancel := setupModelWithConnection(b)
-	defer wcfgCancel()
+	m, _, fcfg := setupModelWithConnection(b)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	files := genFiles(nfiles)
@@ -223,7 +220,7 @@ func BenchmarkRequestOut(b *testing.B) {
 
 	b.ResetTimer()
 	for i := 0; i < b.N; i++ {
-		data, err := m.RequestGlobal(context.Background(), device1, "default", files[i%n].Name, 0, 0, 32, nil, false)
+		data, err := m.RequestGlobal(b.Context(), device1, "default", files[i%n].Name, 0, 0, 32, nil, false)
 		if err != nil {
 			b.Error(err)
 		}
@@ -1777,8 +1774,7 @@ func TestRWScanRecovery(t *testing.T) {
 }
 
 func TestGlobalDirectoryTree(t *testing.T) {
-	m, conn, fcfg, wCancel := setupModelWithConnection(t)
-	defer wCancel()
+	m, conn, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	var seq int64
@@ -2084,8 +2080,7 @@ func BenchmarkTree_100_10(b *testing.B) {
 }
 
 func benchmarkTree(b *testing.B, n1, n2 int) {
-	m, _, fcfg, wcfgCancel := setupModelWithConnection(b)
-	defer wcfgCancel()
+	m, _, fcfg := setupModelWithConnection(b)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	m.ScanFolder(fcfg.ID)
@@ -2342,8 +2337,7 @@ func TestIssue3829(t *testing.T) {
 
 // TestIssue4573 tests that contents of an unavailable dir aren't marked deleted
 func TestIssue4573(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	testFs := fcfg.Filesystem()
 	defer os.RemoveAll(testFs.URI())
 
@@ -2372,8 +2366,7 @@ func TestIssue4573(t *testing.T) {
 // TestInternalScan checks whether various fs operations are correctly represented
 // in the db after scanning.
 func TestInternalScan(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	testFs := fcfg.Filesystem()
 	defer os.RemoveAll(testFs.URI())
 
@@ -2472,8 +2465,7 @@ func TestCustomMarkerName(t *testing.T) {
 }
 
 func TestRemoveDirWithContent(t *testing.T) {
-	m, conn, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, conn, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -2533,8 +2525,7 @@ func TestRemoveDirWithContent(t *testing.T) {
 }
 
 func TestIssue4475(t *testing.T) {
-	m, conn, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, conn, fcfg := setupModelWithConnection(t)
 	defer cleanupModel(m)
 	testFs := fcfg.Filesystem()
 
@@ -2870,8 +2861,7 @@ func TestIssue4903(t *testing.T) {
 func TestIssue5002(t *testing.T) {
 	// recheckFile should not panic when given an index equal to the number of blocks
 
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	ffs := fcfg.Filesystem()
 
 	fd, err := ffs.Create("foo")
@@ -2899,8 +2889,7 @@ func TestIssue5002(t *testing.T) {
 }
 
 func TestParentOfUnignored(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	ffs := fcfg.Filesystem()
 
 	must(t, ffs.Mkdir("bar", 0o755))
@@ -2979,15 +2968,13 @@ func TestFolderRestartZombies(t *testing.T) {
 }
 
 func TestRequestLimit(t *testing.T) {
-	wrapper, fcfg, cancel := newDefaultCfgWrapper()
+	wrapper, fcfg := newDefaultCfgWrapper(t)
 	ffs := fcfg.Filesystem()
 
 	file := "tmpfile"
 	fd, err := ffs.Create(file)
 	must(t, err)
 	fd.Close()
-
-	defer cancel()
 	waiter, err := wrapper.Modify(func(cfg *config.Configuration) {
 		_, i, _ := cfg.Device(device1)
 		cfg.Devices[i].MaxRequestKiB = 1
@@ -3037,8 +3024,7 @@ func TestConnCloseOnRestart(t *testing.T) {
 		protocol.CloseTimeout = oldCloseTimeout
 	}()
 
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, w)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
@@ -3079,8 +3065,7 @@ func TestConnCloseOnRestart(t *testing.T) {
 }
 
 func TestModTimeWindow(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	tfs := modtimeTruncatingFS{
 		trunc:      0,
 		Filesystem: fcfg.Filesystem(),
@@ -3141,8 +3126,7 @@ func TestModTimeWindow(t *testing.T) {
 }
 
 func TestDevicePause(t *testing.T) {
-	m, _, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, _, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	sub := m.evLogger.Subscribe(events.DevicePaused)
@@ -3171,8 +3155,7 @@ func TestDevicePause(t *testing.T) {
 }
 
 func TestDeviceWasSeen(t *testing.T) {
-	m, _, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, _, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	m.deviceWasSeen(device1)
@@ -3216,8 +3199,7 @@ func TestNewLimitedRequestResponse(t *testing.T) {
 }
 
 func TestSummaryPausedNoError(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	pauseFolder(t, wcfg, fcfg.ID, true)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
@@ -3229,14 +3211,15 @@ func TestSummaryPausedNoError(t *testing.T) {
 }
 
 func TestFolderAPIErrors(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	pauseFolder(t, wcfg, fcfg.ID, true)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
 	methods := []func(folder string) error{
-		m.ScanFolder,
+		func(folder string) error {
+			return m.ScanFolder(folder)
+		},
 		func(folder string) error {
 			return m.ScanFolderSubdirs(folder, nil)
 		},
@@ -3261,8 +3244,7 @@ func TestFolderAPIErrors(t *testing.T) {
 }
 
 func TestRenameSequenceOrder(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
@@ -3324,8 +3306,7 @@ func TestRenameSequenceOrder(t *testing.T) {
 }
 
 func TestRenameSameFile(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
@@ -3368,8 +3349,7 @@ func TestRenameSameFile(t *testing.T) {
 }
 
 func TestBlockListMap(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
@@ -3437,8 +3417,7 @@ func TestBlockListMap(t *testing.T) {
 }
 
 func TestScanRenameCaseOnly(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
@@ -3558,9 +3537,8 @@ func TestAddFolderCompletion(t *testing.T) {
 }
 
 func TestScanDeletedROChangedOnSR(t *testing.T) {
-	m, conn, fcfg, wCancel := setupModelWithConnection(t)
+	m, conn, fcfg := setupModelWithConnection(t)
 	ffs := fcfg.Filesystem()
-	defer wCancel()
 	defer cleanupModelAndRemoveDir(m, ffs.URI())
 	fcfg.Type = config.FolderTypeReceiveOnly
 	setFolder(t, m.cfg, fcfg)
@@ -3600,8 +3578,7 @@ func TestScanDeletedROChangedOnSR(t *testing.T) {
 
 func testConfigChangeTriggersClusterConfigs(t *testing.T, expectFirst, expectSecond bool, pre func(config.Wrapper), fn func(config.Wrapper)) {
 	t.Helper()
-	wcfg, _, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, _ := newDefaultCfgWrapper(t)
 	m := setupModel(t, wcfg)
 	defer cleanupModel(m)
 
@@ -3663,8 +3640,7 @@ func testConfigChangeTriggersClusterConfigs(t *testing.T, expectFirst, expectSec
 // That then causes these files to be considered as needed, while they are not.
 // https://github.com/syncthing/syncthing/issues/6961
 func TestIssue6961(t *testing.T) {
-	wcfg, fcfg, wcfgCancel := newDefaultCfgWrapper()
-	defer wcfgCancel()
+	wcfg, fcfg := newDefaultCfgWrapper(t)
 	tfs := fcfg.Filesystem()
 	waiter, err := wcfg.Modify(func(cfg *config.Configuration) {
 		cfg.SetDevice(newDeviceConfiguration(cfg.Defaults.Device, device2, "device2"))
@@ -3728,8 +3704,7 @@ func TestIssue6961(t *testing.T) {
 }
 
 func TestCompletionEmptyGlobal(t *testing.T) {
-	m, conn, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, conn, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 	files := []protocol.FileInfo{{Name: "foo", Version: protocol.Vector{}.Update(myID.Short()), Sequence: 1}}
 	m.sdb.Update(fcfg.ID, protocol.LocalDeviceID, files)
@@ -3743,8 +3718,7 @@ func TestCompletionEmptyGlobal(t *testing.T) {
 }
 
 func TestNeedMetaAfterIndexReset(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	addDevice2(t, w, fcfg)
 	m := setupModel(t, w)
 	defer cleanupModelAndRemoveDir(m, fcfg.Path)
@@ -3786,8 +3760,7 @@ func TestCcCheckEncryption(t *testing.T) {
 		t.Skip("skipping on short testing - generating encryption tokens is slow")
 	}
 
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, w)
 	m.cancel()
 	defer cleanupModel(m)
@@ -3927,8 +3900,7 @@ func TestCcCheckEncryption(t *testing.T) {
 
 func TestCCFolderNotRunning(t *testing.T) {
 	// Create the folder, but don't start it.
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	tfs := fcfg.Filesystem()
 	m := newModel(t, w, myID, nil)
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
@@ -3955,8 +3927,7 @@ func TestCCFolderNotRunning(t *testing.T) {
 }
 
 func TestPendingFolder(t *testing.T) {
-	w, _, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, _ := newDefaultCfgWrapper(t)
 	m := setupModel(t, w)
 	defer cleanupModel(m)
 
@@ -4035,11 +4006,10 @@ func TestDeletedNotLocallyChangedReceiveEncrypted(t *testing.T) {
 }
 
 func deletedNotLocallyChanged(t *testing.T, ft config.FolderType) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
+	w, fcfg := newDefaultCfgWrapper(t)
 	tfs := fcfg.Filesystem()
 	fcfg.Type = ft
 	setFolder(t, w, fcfg)
-	defer wCancel()
 	m := setupModel(t, w)
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
diff --git a/lib/model/requests_test.go b/lib/model/requests_test.go
--- a/lib/model/requests_test.go
+++ b/lib/model/requests_test.go
@@ -30,8 +30,7 @@ func TestRequestSimple(t *testing.T) {
 	// Verify that the model performs a request and creates a file based on
 	// an incoming index update.
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -78,8 +77,7 @@ func TestSymlinkTraversalRead(t *testing.T) {
 		return
 	}
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	// We listen for incoming index updates and trigger when we see one for
@@ -121,8 +119,7 @@ func TestSymlinkTraversalWrite(t *testing.T) {
 		return
 	}
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	// We listen for incoming index updates and trigger when we see one for
@@ -180,8 +177,7 @@ func TestSymlinkTraversalWrite(t *testing.T) {
 func TestRequestCreateTmpSymlink(t *testing.T) {
 	// Test that an update for a temporary file is invalidated
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	// We listen for incoming index updates and trigger when we see one for
@@ -356,8 +352,7 @@ func pullInvalidIgnored(t *testing.T, ft config.FolderType) {
 }
 
 func TestIssue4841(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	received := make(chan []protocol.FileInfo)
@@ -405,8 +400,7 @@ func TestIssue4841(t *testing.T) {
 }
 
 func TestRescanIfHaveInvalidContent(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -467,8 +461,7 @@ func TestRescanIfHaveInvalidContent(t *testing.T) {
 func TestParentDeletion(t *testing.T) {
 	t.Skip("flaky")
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	testFs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, testFs.URI())
 
@@ -546,8 +539,7 @@ func TestRequestSymlinkWindows(t *testing.T) {
 		t.Skip("windows specific test")
 	}
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModelAndRemoveDir(m, fcfg.Filesystem().URI())
 
 	received := make(chan []protocol.FileInfo)
@@ -623,8 +615,7 @@ func equalContents(fs fs.Filesystem, path string, contents []byte) error {
 func TestRequestRemoteRenameChanged(t *testing.T) {
 	t.Skip("flaky")
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModel(m)
 
@@ -756,8 +747,7 @@ func TestRequestRemoteRenameChanged(t *testing.T) {
 }
 
 func TestRequestRemoteRenameConflict(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModel(m)
 
@@ -846,8 +836,7 @@ func TestRequestRemoteRenameConflict(t *testing.T) {
 }
 
 func TestRequestDeleteChanged(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -925,8 +914,7 @@ func TestRequestDeleteChanged(t *testing.T) {
 }
 
 func TestNeedFolderFiles(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	defer cleanupModel(m)
 
 	sub := m.evLogger.Subscribe(events.RemoteIndexUpdated)
@@ -970,8 +958,7 @@ func TestNeedFolderFiles(t *testing.T) {
 // propagated upon un-ignoring.
 // https://github.com/syncthing/syncthing/issues/6038
 func TestIgnoreDeleteUnignore(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	m := setupModel(t, w)
 	fss := fcfg.Filesystem()
 	defer cleanupModel(m)
@@ -1065,8 +1052,7 @@ func TestIgnoreDeleteUnignore(t *testing.T) {
 // TestRequestLastFileProgress checks that the last pulled file (here only) is registered
 // as in progress.
 func TestRequestLastFileProgress(t *testing.T) {
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -1100,8 +1086,7 @@ func TestRequestIndexSenderPause(t *testing.T) {
 	done := make(chan struct{})
 	defer close(done)
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	tfs := fcfg.Filesystem()
 	defer cleanupModelAndRemoveDir(m, tfs.URI())
 
@@ -1213,8 +1198,7 @@ func TestRequestIndexSenderPause(t *testing.T) {
 }
 
 func TestRequestIndexSenderClusterConfigBeforeStart(t *testing.T) {
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	tfs := fcfg.Filesystem()
 	dir1 := "foo"
 	dir2 := "bar"
@@ -1280,8 +1264,7 @@ func TestRequestReceiveEncrypted(t *testing.T) {
 		t.Skip("skipping on short testing - scrypt is too slow")
 	}
 
-	w, fcfg, wCancel := newDefaultCfgWrapper()
-	defer wCancel()
+	w, fcfg := newDefaultCfgWrapper(t)
 	tfs := fcfg.Filesystem()
 	fcfg.Type = config.FolderTypeReceiveEncrypted
 	setFolder(t, w, fcfg)
@@ -1375,8 +1358,7 @@ func TestRequestGlobalInvalidToValid(t *testing.T) {
 	done := make(chan struct{})
 	defer close(done)
 
-	m, fc, fcfg, wcfgCancel := setupModelWithConnection(t)
-	defer wcfgCancel()
+	m, fc, fcfg := setupModelWithConnection(t)
 	fcfg.Devices = append(fcfg.Devices, config.FolderDeviceConfiguration{DeviceID: device2})
 	waiter, err := m.cfg.Modify(func(cfg *config.Configuration) {
 		cfg.SetDevice(newDeviceConfiguration(cfg.Defaults.Device, device2, "device2"))
diff --git a/lib/model/testutils_test.go b/lib/model/testutils_test.go
--- a/lib/model/testutils_test.go
+++ b/lib/model/testutils_test.go
@@ -85,19 +85,24 @@ func init() {
 }
 
 func newConfigWrapper(cfg config.Configuration) (config.Wrapper, context.CancelFunc) {
-	wrapper := config.Wrap("", cfg, myID, events.NoopLogger)
-	ctx, cancel := context.WithCancel(context.Background())
-	go wrapper.Serve(ctx)
-	return wrapper, cancel
+	return newConfigWrapperFromContext(context.Background(), cfg)
 }
 
-func newDefaultCfgWrapper() (config.Wrapper, config.FolderConfiguration, context.CancelFunc) {
-	w, cancel := newConfigWrapper(defaultCfgWrapper.RawCopy())
+func newDefaultCfgWrapper(t testing.TB) (config.Wrapper, config.FolderConfiguration) {
+	w, cancel := newConfigWrapperFromContext(t.Context(), defaultCfgWrapper.RawCopy())
+	t.Cleanup(cancel)
 	fcfg := newFolderConfig()
 	_, _ = w.Modify(func(cfg *config.Configuration) {
 		cfg.SetFolder(fcfg)
 	})
-	return w, fcfg, cancel
+	return w, fcfg
+}
+
+func newConfigWrapperFromContext(ctx context.Context, cfg config.Configuration) (config.Wrapper, context.CancelFunc) {
+	wrapper := config.Wrap("", cfg, myID, events.NoopLogger)
+	ctx, cancel := context.WithCancel(ctx)
+	go wrapper.Serve(ctx)
+	return wrapper, cancel
 }
 
 func newFolderConfig() config.FolderConfiguration {
@@ -108,11 +113,11 @@ func newFolderConfig() config.FolderConfiguration {
 	return cfg
 }
 
-func setupModelWithConnection(t testing.TB) (*testModel, *fakeConnection, config.FolderConfiguration, context.CancelFunc) {
+func setupModelWithConnection(t testing.TB) (*testModel, *fakeConnection, config.FolderConfiguration) {
 	t.Helper()
-	w, fcfg, cancel := newDefaultCfgWrapper()
+	w, fcfg := newDefaultCfgWrapper(t)
 	m, fc := setupModelWithConnectionFromWrapper(t, w)
-	return m, fc, fcfg, cancel
+	return m, fc, fcfg
 }
 
 func setupModelWithConnectionFromWrapper(t testing.TB, w config.Wrapper) (*testModel, *fakeConnection) {
@@ -157,7 +162,7 @@ func newModel(t testing.TB, cfg config.Wrapper, id protocol.DeviceID, protectedF
 		mdb.Close()
 	})
 	m := NewModel(cfg, id, mdb, protectedFiles, evLogger, protocol.NewKeyGenerator()).(*model)
-	ctx, cancel := context.WithCancel(context.Background())
+	ctx, cancel := context.WithCancel(t.Context())
 	go evLogger.Serve(ctx)
 	return &testModel{
 		model:    m,
EOF_114329324912

# Verify CGO is enabled (required for syncthing's sqlite3 dependency)
export CGO_ENABLED=1

# Run the specific test files in the lib/model package
# Using -v for verbose output to help with debugging
# Using -timeout 120s to prevent tests from hanging indefinitely
# Running tests in single-process mode for stability in virtualized environment
go test -v -timeout 120s ./lib/model -run ".*" 2>&1

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test files
git checkout ce884e5d7253ed82379f918e169438eb64fcece0 "lib/model/folder_recvonly_test.go" "lib/model/folder_sendrecv_test.go" "lib/model/model_test.go" "lib/model/requests_test.go" "lib/model/testutils_test.go"

exit $rc