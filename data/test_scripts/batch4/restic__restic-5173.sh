#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9566e2db4abc9963c85c9e03899a10edfaa85fc3 "internal/backend/s3/config_test.go" "internal/repository/repack_test.go" "internal/restorer/filerestorer_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/backend/s3/config_test.go b/internal/backend/s3/config_test.go
--- a/internal/backend/s3/config_test.go
+++ b/internal/backend/s3/config_test.go
@@ -3,117 +3,117 @@ package s3
 import (
 	"strings"
 	"testing"
+	"time"
 
 	"github.com/restic/restic/internal/backend/test"
 )
 
+func newTestConfig(cfg Config) Config {
+	if cfg.Connections == 0 {
+		cfg.Connections = 5
+	}
+	if cfg.RestoreDays == 0 {
+		cfg.RestoreDays = 7
+	}
+	if cfg.RestoreTimeout == 0 {
+		cfg.RestoreTimeout = 24 * time.Hour
+	}
+	if cfg.RestoreTier == "" {
+		cfg.RestoreTier = "Standard"
+	}
+	return cfg
+}
+
 var configTests = []test.ConfigTestData[Config]{
-	{S: "s3://eu-central-1/bucketname", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "bucketname",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3://eu-central-1/bucketname/", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "bucketname",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3://eu-central-1/bucketname/prefix/directory", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "bucketname",
-		Prefix:      "prefix/directory",
-		Connections: 5,
-	}},
-	{S: "s3://eu-central-1/bucketname/prefix/directory/", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "bucketname",
-		Prefix:      "prefix/directory",
-		Connections: 5,
-	}},
-	{S: "s3:eu-central-1/foobar", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:eu-central-1/foobar/", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:eu-central-1/foobar/prefix/directory", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "foobar",
-		Prefix:      "prefix/directory",
-		Connections: 5,
-	}},
-	{S: "s3:eu-central-1/foobar/prefix/directory/", Cfg: Config{
-		Endpoint:    "eu-central-1",
-		Bucket:      "foobar",
-		Prefix:      "prefix/directory",
-		Connections: 5,
-	}},
-	{S: "s3:hostname.foo/foobar", Cfg: Config{
-		Endpoint:    "hostname.foo",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:hostname.foo/foobar/prefix/directory", Cfg: Config{
-		Endpoint:    "hostname.foo",
-		Bucket:      "foobar",
-		Prefix:      "prefix/directory",
-		Connections: 5,
-	}},
-	{S: "s3:https://hostname/foobar", Cfg: Config{
-		Endpoint:    "hostname",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:https://hostname:9999/foobar", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:https://hostname:9999/foobar/", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "foobar",
-		Prefix:      "",
-		Connections: 5,
-	}},
-	{S: "s3:http://hostname:9999/foobar", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "foobar",
-		Prefix:      "",
-		UseHTTP:     true,
-		Connections: 5,
-	}},
-	{S: "s3:http://hostname:9999/foobar/", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "foobar",
-		Prefix:      "",
-		UseHTTP:     true,
-		Connections: 5,
-	}},
-	{S: "s3:http://hostname:9999/bucket/prefix/directory", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "bucket",
-		Prefix:      "prefix/directory",
-		UseHTTP:     true,
-		Connections: 5,
-	}},
-	{S: "s3:http://hostname:9999/bucket/prefix/directory/", Cfg: Config{
-		Endpoint:    "hostname:9999",
-		Bucket:      "bucket",
-		Prefix:      "prefix/directory",
-		UseHTTP:     true,
-		Connections: 5,
-	}},
+	{S: "s3://eu-central-1/bucketname", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "bucketname",
+		Prefix:   "",
+	})},
+	{S: "s3://eu-central-1/bucketname/", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "bucketname",
+		Prefix:   "",
+	})},
+	{S: "s3://eu-central-1/bucketname/prefix/directory", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "bucketname",
+		Prefix:   "prefix/directory",
+	})},
+	{S: "s3://eu-central-1/bucketname/prefix/directory/", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "bucketname",
+		Prefix:   "prefix/directory",
+	})},
+	{S: "s3:eu-central-1/foobar", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:eu-central-1/foobar/", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:eu-central-1/foobar/prefix/directory", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "foobar",
+		Prefix:   "prefix/directory",
+	})},
+	{S: "s3:eu-central-1/foobar/prefix/directory/", Cfg: newTestConfig(Config{
+		Endpoint: "eu-central-1",
+		Bucket:   "foobar",
+		Prefix:   "prefix/directory",
+	})},
+	{S: "s3:hostname.foo/foobar", Cfg: newTestConfig(Config{
+		Endpoint: "hostname.foo",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:hostname.foo/foobar/prefix/directory", Cfg: newTestConfig(Config{
+		Endpoint: "hostname.foo",
+		Bucket:   "foobar",
+		Prefix:   "prefix/directory",
+	})},
+	{S: "s3:https://hostname/foobar", Cfg: newTestConfig(Config{
+		Endpoint: "hostname",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:https://hostname:9999/foobar", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:https://hostname:9999/foobar/", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "foobar",
+		Prefix:   "",
+	})},
+	{S: "s3:http://hostname:9999/foobar", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "foobar",
+		Prefix:   "",
+		UseHTTP:  true,
+	})},
+	{S: "s3:http://hostname:9999/foobar/", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "foobar",
+		Prefix:   "",
+		UseHTTP:  true,
+	})},
+	{S: "s3:http://hostname:9999/bucket/prefix/directory", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "bucket",
+		Prefix:   "prefix/directory",
+		UseHTTP:  true,
+	})},
+	{S: "s3:http://hostname:9999/bucket/prefix/directory/", Cfg: newTestConfig(Config{
+		Endpoint: "hostname:9999",
+		Bucket:   "bucket",
+		Prefix:   "prefix/directory",
+		UseHTTP:  true,
+	})},
 }
 
 func TestParseConfig(t *testing.T) {
diff --git a/internal/repository/repack_test.go b/internal/repository/repack_test.go
--- a/internal/repository/repack_test.go
+++ b/internal/repository/repack_test.go
@@ -160,7 +160,7 @@ func findPacksForBlobs(t *testing.T, repo restic.Repository, blobs restic.BlobSe
 }
 
 func repack(t *testing.T, repo restic.Repository, be backend.Backend, packs restic.IDSet, blobs restic.BlobSet) {
-	repackedBlobs, err := repository.Repack(context.TODO(), repo, repo, packs, blobs, nil)
+	repackedBlobs, err := repository.Repack(context.TODO(), repo, repo, packs, blobs, nil, nil)
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -279,7 +279,7 @@ func testRepackCopy(t *testing.T, version uint) {
 	_, keepBlobs := selectBlobs(t, random, repo, 0.2)
 	copyPacks := findPacksForBlobs(t, repo, keepBlobs)
 
-	_, err := repository.Repack(context.TODO(), repoWrapped, dstRepoWrapped, copyPacks, keepBlobs, nil)
+	_, err := repository.Repack(context.TODO(), repoWrapped, dstRepoWrapped, copyPacks, keepBlobs, nil, nil)
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -318,7 +318,7 @@ func testRepackWrongBlob(t *testing.T, version uint) {
 	_, keepBlobs := selectBlobs(t, random, repo, 0)
 	rewritePacks := findPacksForBlobs(t, repo, keepBlobs)
 
-	_, err := repository.Repack(context.TODO(), repo, repo, rewritePacks, keepBlobs, nil)
+	_, err := repository.Repack(context.TODO(), repo, repo, rewritePacks, keepBlobs, nil, nil)
 	if err == nil {
 		t.Fatal("expected repack to fail but got no error")
 	}
@@ -366,7 +366,7 @@ func testRepackBlobFallback(t *testing.T, version uint) {
 	rtest.OK(t, repo.Flush(context.Background()))
 
 	// repack must fallback to valid copy
-	_, err = repository.Repack(context.TODO(), repo, repo, rewritePacks, keepBlobs, nil)
+	_, err = repository.Repack(context.TODO(), repo, repo, rewritePacks, keepBlobs, nil, nil)
 	rtest.OK(t, err)
 
 	keepBlobs = restic.NewBlobSet(restic.BlobHandle{Type: restic.DataBlob, ID: id})
diff --git a/internal/repository/warmup_test.go b/internal/repository/warmup_test.go
new file mode 100644
--- /dev/null
+++ b/internal/repository/warmup_test.go
@@ -0,0 +1,73 @@
+package repository
+
+import (
+	"context"
+	"testing"
+
+	"github.com/restic/restic/internal/backend"
+	"github.com/restic/restic/internal/backend/mock"
+	"github.com/restic/restic/internal/restic"
+)
+
+func TestWarmupRepository(t *testing.T) {
+	warmupCalls := [][]backend.Handle{}
+	warmupWaitCalls := [][]backend.Handle{}
+	simulateWarmingUp := false
+
+	be := mock.NewBackend()
+	be.WarmupFn = func(ctx context.Context, handles []backend.Handle) ([]backend.Handle, error) {
+		warmupCalls = append(warmupCalls, handles)
+		if simulateWarmingUp {
+			return handles, nil
+		}
+		return []backend.Handle{}, nil
+	}
+	be.WarmupWaitFn = func(ctx context.Context, handles []backend.Handle) error {
+		warmupWaitCalls = append(warmupWaitCalls, handles)
+		return nil
+	}
+
+	repo, _ := New(be, Options{})
+
+	id1, _ := restic.ParseID("1111111111111111111111111111111111111111111111111111111111111111")
+	id2, _ := restic.ParseID("2222222222222222222222222222222222222222222222222222222222222222")
+	id3, _ := restic.ParseID("3333333333333333333333333333333333333333333333333333333333333333")
+	job, err := repo.StartWarmup(context.TODO(), restic.NewIDSet(id1, id2))
+	if err != nil {
+		t.Fatalf("error when starting warmup: %v", err)
+	}
+	if len(warmupCalls) != 1 {
+		t.Fatalf("expected %d calls to warmup, got %d", 1, len(warmupCalls))
+	}
+	if len(warmupCalls[0]) != 2 {
+		t.Fatalf("expected warmup on %d handles, got %d", 2, len(warmupCalls[0]))
+	}
+	if job.HandleCount() != 0 {
+		t.Fatalf("expected all files to be warm, got %d cold", job.HandleCount())
+	}
+
+	simulateWarmingUp = true
+	job, err = repo.StartWarmup(context.TODO(), restic.NewIDSet(id3))
+	if err != nil {
+		t.Fatalf("error when starting warmup: %v", err)
+	}
+	if len(warmupCalls) != 2 {
+		t.Fatalf("expected %d calls to warmup, got %d", 2, len(warmupCalls))
+	}
+	if len(warmupCalls[1]) != 1 {
+		t.Fatalf("expected warmup on %d handles, got %d", 1, len(warmupCalls[1]))
+	}
+	if job.HandleCount() != 1 {
+		t.Fatalf("expected %d file to be warming up, got %d", 1, job.HandleCount())
+	}
+
+	if err := job.Wait(context.TODO()); err != nil {
+		t.Fatalf("error when waiting warmup: %v", err)
+	}
+	if len(warmupWaitCalls) != 1 {
+		t.Fatalf("expected %d calls to warmupWait, got %d", 1, len(warmupCalls))
+	}
+	if len(warmupWaitCalls[0]) != 1 {
+		t.Fatalf("expected warmupWait to be called with %d handles, got %d", 1, len(warmupWaitCalls[0]))
+	}
+}
diff --git a/internal/restorer/filerestorer_test.go b/internal/restorer/filerestorer_test.go
--- a/internal/restorer/filerestorer_test.go
+++ b/internal/restorer/filerestorer_test.go
@@ -9,6 +9,7 @@ import (
 	"testing"
 
 	"github.com/restic/restic/internal/errors"
+	"github.com/restic/restic/internal/feature"
 	"github.com/restic/restic/internal/restic"
 	rtest "github.com/restic/restic/internal/test"
 )
@@ -23,6 +24,11 @@ type TestFile struct {
 	blobs []TestBlob
 }
 
+type TestWarmupJob struct {
+	handlesCount int
+	waitCalled   bool
+}
+
 type TestRepo struct {
 	packsIDToData map[restic.ID][]byte
 
@@ -31,6 +37,8 @@ type TestRepo struct {
 	files              []*fileInfo
 	filesPathToContent map[string]string
 
+	warmupJobs []*TestWarmupJob
+
 	//
 	loader blobsLoaderFn
 }
@@ -44,6 +52,21 @@ func (i *TestRepo) fileContent(file *fileInfo) string {
 	return i.filesPathToContent[file.location]
 }
 
+func (i *TestRepo) StartWarmup(ctx context.Context, packs restic.IDSet) (restic.WarmupJob, error) {
+	job := TestWarmupJob{handlesCount: len(packs)}
+	i.warmupJobs = append(i.warmupJobs, &job)
+	return &job, nil
+}
+
+func (job *TestWarmupJob) HandleCount() int {
+	return job.handlesCount
+}
+
+func (job *TestWarmupJob) Wait(_ context.Context) error {
+	job.waitCalled = true
+	return nil
+}
+
 func newTestRepo(content []TestFile) *TestRepo {
 	type Pack struct {
 		name  string
@@ -111,6 +134,7 @@ func newTestRepo(content []TestFile) *TestRepo {
 		blobs:              blobs,
 		files:              files,
 		filesPathToContent: filesPathToContent,
+		warmupJobs:         []*TestWarmupJob{},
 	}
 	repo.loader = func(ctx context.Context, packID restic.ID, blobs []restic.Blob, handleBlobFn func(blob restic.BlobHandle, buf []byte, err error) error) error {
 		blobs = append([]restic.Blob{}, blobs...)
@@ -141,10 +165,12 @@ func newTestRepo(content []TestFile) *TestRepo {
 }
 
 func restoreAndVerify(t *testing.T, tempdir string, content []TestFile, files map[string]bool, sparse bool) {
+	defer feature.TestSetFlag(t, feature.Flag, feature.S3Restore, true)()
+
 	t.Helper()
 	repo := newTestRepo(content)
 
-	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, sparse, false, nil)
+	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, sparse, false, repo.StartWarmup, nil)
 
 	if files == nil {
 		r.files = repo.files
@@ -177,6 +203,15 @@ func verifyRestore(t *testing.T, r *fileRestorer, repo *TestRepo) {
 			t.Errorf("file %v has wrong content: want %q, got %q", file.location, content, data)
 		}
 	}
+
+	if len(repo.warmupJobs) == 0 {
+		t.Errorf("warmup did not occur")
+	}
+	for i, warmupJob := range repo.warmupJobs {
+		if !warmupJob.waitCalled {
+			t.Errorf("warmup job %d was not waited", i)
+		}
+	}
 }
 
 func TestFileRestorerBasic(t *testing.T) {
@@ -285,7 +320,7 @@ func TestErrorRestoreFiles(t *testing.T) {
 		return loadError
 	}
 
-	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, false, false, nil)
+	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, false, false, repo.StartWarmup, nil)
 	r.files = repo.files
 
 	err := r.restoreFiles(context.TODO())
@@ -326,7 +361,7 @@ func TestFatalDownloadError(t *testing.T) {
 		})
 	}
 
-	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, false, false, nil)
+	r := newFileRestorer(tempdir, repo.loader, repo.Lookup, 2, false, false, repo.StartWarmup, nil)
 	r.files = repo.files
 
 	var errors []string
EOF_114329324912

# Verify Go environment is properly configured
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export CGO_ENABLED=1

# Run the target tests - combining all three test packages in a single command for efficiency
# Using -v for verbose output and -cover for coverage information
# Running tests sequentially (no parallelism) to ensure stability in virtualized environment
go test -v -cover -p 1 ./internal/backend/s3/ ./internal/repository/ ./internal/restorer/
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 9566e2db4abc9963c85c9e03899a10edfaa85fc3 "internal/backend/s3/config_test.go" "internal/repository/repack_test.go" "internal/restorer/filerestorer_test.go"