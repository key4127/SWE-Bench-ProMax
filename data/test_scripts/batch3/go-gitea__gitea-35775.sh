#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original files to ensure clean state
git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/git/catfile_batch_test.go b/modules/git/catfile_batch_test.go
new file mode 100644
--- /dev/null
+++ b/modules/git/catfile_batch_test.go
@@ -0,0 +1,55 @@
+// Copyright 2026 The Gitea Authors. All rights reserved.
+// SPDX-License-Identifier: MIT
+
+package git
+
+import (
+	"io"
+	"path/filepath"
+	"testing"
+
+	"code.gitea.io/gitea/modules/test"
+
+	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
+)
+
+func TestCatFileBatch(t *testing.T) {
+	defer test.MockVariableValue(&DefaultFeatures().SupportCatFileBatchCommand)()
+	DefaultFeatures().SupportCatFileBatchCommand = false
+	t.Run("LegacyCheck", testCatFileBatch)
+	DefaultFeatures().SupportCatFileBatchCommand = true
+	t.Run("BatchCommand", testCatFileBatch)
+}
+
+func testCatFileBatch(t *testing.T) {
+	t.Run("CorruptedGitRepo", func(t *testing.T) {
+		tmpDir := t.TempDir()
+		_, err := NewBatch(t.Context(), tmpDir)
+		require.Error(t, err)
+	})
+
+	batch, err := NewBatch(t.Context(), filepath.Join(testReposDir, "repo1_bare"))
+	require.NoError(t, err)
+	defer batch.Close()
+
+	t.Run("QueryInfo", func(t *testing.T) {
+		info, err := batch.QueryInfo("e2129701f1a4d54dc44f03c93bca0a2aec7c5449")
+		require.NoError(t, err)
+		assert.Equal(t, "e2129701f1a4d54dc44f03c93bca0a2aec7c5449", info.ID)
+		assert.Equal(t, "blob", info.Type)
+		assert.EqualValues(t, 6, info.Size)
+	})
+
+	t.Run("QueryContent", func(t *testing.T) {
+		info, rd, err := batch.QueryContent("e2129701f1a4d54dc44f03c93bca0a2aec7c5449")
+		require.NoError(t, err)
+		assert.Equal(t, "e2129701f1a4d54dc44f03c93bca0a2aec7c5449", info.ID)
+		assert.Equal(t, "blob", info.Type)
+		assert.EqualValues(t, 6, info.Size)
+
+		content, err := io.ReadAll(io.LimitReader(rd, info.Size))
+		require.NoError(t, err)
+		require.Equal(t, "file1\n", string(content))
+	})
+}
diff --git a/modules/git/commit_info_test.go b/modules/git/commit_info_test.go
--- a/modules/git/commit_info_test.go
+++ b/modules/git/commit_info_test.go
@@ -30,28 +30,57 @@ func cloneRepo(tb testing.TB, url string) (string, error) {
 }
 
 func testGetCommitsInfo(t *testing.T, repo1 *Repository) {
+	type expectedEntryInfo struct {
+		CommitID string
+		Size     int64
+	}
+
 	// these test case are specific to the repo1 test repo
 	testCases := []struct {
 		CommitID           string
 		Path               string
-		ExpectedIDs        map[string]string
+		ExpectedIDs        map[string]expectedEntryInfo
 		ExpectedTreeCommit string
 	}{
-		{"8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2", "", map[string]string{
-			"file1.txt": "95bb4d39648ee7e325106df01a621c530863a653",
-			"file2.txt": "8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2",
+		{"8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2", "", map[string]expectedEntryInfo{
+			"file1.txt": {
+				CommitID: "95bb4d39648ee7e325106df01a621c530863a653",
+				Size:     6,
+			},
+			"file2.txt": {
+				CommitID: "8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2",
+				Size:     6,
+			},
 		}, "8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2"},
-		{"2839944139e0de9737a044f78b0e4b40d989a9e3", "", map[string]string{
-			"file1.txt":   "2839944139e0de9737a044f78b0e4b40d989a9e3",
-			"branch1.txt": "9c9aef8dd84e02bc7ec12641deb4c930a7c30185",
+		{"2839944139e0de9737a044f78b0e4b40d989a9e3", "", map[string]expectedEntryInfo{
+			"file1.txt": {
+				CommitID: "2839944139e0de9737a044f78b0e4b40d989a9e3",
+				Size:     15,
+			},
+			"branch1.txt": {
+				CommitID: "9c9aef8dd84e02bc7ec12641deb4c930a7c30185",
+				Size:     8,
+			},
 		}, "2839944139e0de9737a044f78b0e4b40d989a9e3"},
-		{"5c80b0245c1c6f8343fa418ec374b13b5d4ee658", "branch2", map[string]string{
-			"branch2.txt": "5c80b0245c1c6f8343fa418ec374b13b5d4ee658",
+		{"5c80b0245c1c6f8343fa418ec374b13b5d4ee658", "branch2", map[string]expectedEntryInfo{
+			"branch2.txt": {
+				CommitID: "5c80b0245c1c6f8343fa418ec374b13b5d4ee658",
+				Size:     8,
+			},
 		}, "5c80b0245c1c6f8343fa418ec374b13b5d4ee658"},
-		{"feaf4ba6bc635fec442f46ddd4512416ec43c2c2", "", map[string]string{
-			"file1.txt": "95bb4d39648ee7e325106df01a621c530863a653",
-			"file2.txt": "8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2",
-			"foo":       "37991dec2c8e592043f47155ce4808d4580f9123",
+		{"feaf4ba6bc635fec442f46ddd4512416ec43c2c2", "", map[string]expectedEntryInfo{
+			"file1.txt": {
+				CommitID: "95bb4d39648ee7e325106df01a621c530863a653",
+				Size:     6,
+			},
+			"file2.txt": {
+				CommitID: "8d92fc957a4d7cfd98bc375f0b7bb189a0d6c9f2",
+				Size:     6,
+			},
+			"foo": {
+				CommitID: "37991dec2c8e592043f47155ce4808d4580f9123",
+				Size:     0,
+			},
 		}, "feaf4ba6bc635fec442f46ddd4512416ec43c2c2"},
 	}
 	for _, testCase := range testCases {
@@ -93,11 +122,12 @@ func testGetCommitsInfo(t *testing.T, repo1 *Repository) {
 		for _, commitInfo := range commitsInfo {
 			entry := commitInfo.Entry
 			commit := commitInfo.Commit
-			expectedID, ok := testCase.ExpectedIDs[entry.Name()]
+			expectedInfo, ok := testCase.ExpectedIDs[entry.Name()]
 			if !assert.True(t, ok) {
 				continue
 			}
-			assert.Equal(t, expectedID, commit.ID.String())
+			assert.Equal(t, expectedInfo.CommitID, commit.ID.String())
+			assert.Equal(t, expectedInfo.Size, entry.Size(), entry.Name())
 		}
 	}
 }
diff --git a/modules/git/git_test.go b/modules/git/git_test.go
--- a/modules/git/git_test.go
+++ b/modules/git/git_test.go
@@ -4,42 +4,14 @@
 package git
 
 import (
-	"fmt"
-	"os"
 	"testing"
 
-	"code.gitea.io/gitea/modules/setting"
-	"code.gitea.io/gitea/modules/tempdir"
-
 	"github.com/hashicorp/go-version"
 	"github.com/stretchr/testify/assert"
 )
 
-func testRun(m *testing.M) error {
-	gitHomePath, cleanup, err := tempdir.OsTempDir("gitea-test").MkdirTempRandom("git-home")
-	if err != nil {
-		return fmt.Errorf("unable to create temp dir: %w", err)
-	}
-	defer cleanup()
-
-	setting.Git.HomePath = gitHomePath
-
-	if err = InitFull(); err != nil {
-		return fmt.Errorf("failed to call Init: %w", err)
-	}
-
-	exitCode := m.Run()
-	if exitCode != 0 {
-		return fmt.Errorf("run test failed, ExitCode=%d", exitCode)
-	}
-	return nil
-}
-
 func TestMain(m *testing.M) {
-	if err := testRun(m); err != nil {
-		_, _ = fmt.Fprintf(os.Stderr, "Test failed: %v", err)
-		os.Exit(1)
-	}
+	RunGitTests(m)
 }
 
 func TestParseGitVersion(t *testing.T) {
diff --git a/modules/git/gitcmd/command_test.go b/modules/git/gitcmd/command_test.go
--- a/modules/git/gitcmd/command_test.go
+++ b/modules/git/gitcmd/command_test.go
@@ -15,6 +15,8 @@ import (
 )
 
 func TestMain(m *testing.M) {
+	// FIXME: GIT-PACKAGE-DEPENDENCY: the dependency is not right.
+	// "setting.Git.HomePath" is initialized in "git" package but really used in "gitcmd" package
 	gitHomePath, cleanup, err := tempdir.OsTempDir("gitea-test").MkdirTempRandom("git-home")
 	if err != nil {
 		_, _ = fmt.Fprintf(os.Stderr, "unable to create temp dir: %v", err)
diff --git a/modules/git/languagestats/main_test.go b/modules/git/languagestats/main_test.go
--- a/modules/git/languagestats/main_test.go
+++ b/modules/git/languagestats/main_test.go
@@ -4,37 +4,11 @@
 package languagestats
 
 import (
-	"fmt"
-	"os"
 	"testing"
 
 	"code.gitea.io/gitea/modules/git"
-	"code.gitea.io/gitea/modules/setting"
-	"code.gitea.io/gitea/modules/util"
 )
 
-func testRun(m *testing.M) error {
-	gitHomePath, err := os.MkdirTemp(os.TempDir(), "git-home")
-	if err != nil {
-		return fmt.Errorf("unable to create temp dir: %w", err)
-	}
-	defer util.RemoveAll(gitHomePath)
-	setting.Git.HomePath = gitHomePath
-
-	if err = git.InitFull(); err != nil {
-		return fmt.Errorf("failed to call Init: %w", err)
-	}
-
-	exitCode := m.Run()
-	if exitCode != 0 {
-		return fmt.Errorf("run test failed, ExitCode=%d", exitCode)
-	}
-	return nil
-}
-
 func TestMain(m *testing.M) {
-	if err := testRun(m); err != nil {
-		_, _ = fmt.Fprintf(os.Stderr, "Test failed: %v", err)
-		os.Exit(1)
-	}
+	git.RunGitTests(m)
 }
diff --git a/modules/git/pipeline/lfs_test.go b/modules/git/pipeline/lfs_test.go
new file mode 100644
--- /dev/null
+++ b/modules/git/pipeline/lfs_test.go
@@ -0,0 +1,38 @@
+// Copyright 2026 The Gitea Authors. All rights reserved.
+// SPDX-License-Identifier: MIT
+
+package pipeline
+
+import (
+	"testing"
+	"time"
+
+	"code.gitea.io/gitea/modules/git"
+
+	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
+)
+
+func TestFindLFSFile(t *testing.T) {
+	repoPath := "../../../tests/gitea-repositories-meta/user2/lfs.git"
+	gitRepo, err := git.OpenRepository(t.Context(), repoPath)
+	require.NoError(t, err)
+	defer gitRepo.Close()
+
+	objectID := git.MustIDFromString("2b6c6c4eaefa24b22f2092c3d54b263ff26feb58")
+
+	stats, err := FindLFSFile(gitRepo, objectID)
+	require.NoError(t, err)
+
+	tm, err := time.Parse(time.RFC3339, "2022-12-21T17:56:42-05:00")
+	require.NoError(t, err)
+
+	assert.Len(t, stats, 1)
+	assert.Equal(t, "CONTRIBUTING.md", stats[0].Name)
+	assert.Equal(t, "73cf03db6ece34e12bf91e8853dc58f678f2f82d", stats[0].SHA)
+	assert.Equal(t, "Initial commit", stats[0].Summary)
+	assert.Equal(t, tm, stats[0].When)
+	assert.Empty(t, stats[0].ParentHashes)
+	assert.Equal(t, "master", stats[0].BranchName)
+	assert.Equal(t, "master", stats[0].FullCommitName)
+}
diff --git a/modules/git/pipeline/main_test.go b/modules/git/pipeline/main_test.go
new file mode 100644
--- /dev/null
+++ b/modules/git/pipeline/main_test.go
@@ -0,0 +1,14 @@
+// Copyright 2026 The Gitea Authors. All rights reserved.
+// SPDX-License-Identifier: MIT
+
+package pipeline
+
+import (
+	"testing"
+
+	"code.gitea.io/gitea/modules/git"
+)
+
+func TestMain(m *testing.M) {
+	git.RunGitTests(m)
+}
diff --git a/modules/git/repo_base_nogogit_test.go b/modules/git/repo_base_nogogit_test.go
new file mode 100644
--- /dev/null
+++ b/modules/git/repo_base_nogogit_test.go
@@ -0,0 +1,26 @@
+// Copyright 2026 The Gitea Authors. All rights reserved.
+// SPDX-License-Identifier: MIT
+
+//go:build !gogit
+
+package git
+
+import (
+	"path/filepath"
+	"testing"
+
+	"github.com/stretchr/testify/require"
+)
+
+func TestRepoCatFileBatch(t *testing.T) {
+	t.Run("MissingRepoAndClose", func(t *testing.T) {
+		repo, err := OpenRepository(t.Context(), filepath.Join(testReposDir, "repo1_bare"))
+		require.NoError(t, err)
+		repo.Path = "/no-such" // when the repo is missing (it usually occurs during testing because the fixtures are synced frequently)
+		_, _, err = repo.CatFileBatch(t.Context())
+		require.Error(t, err)
+		require.NoError(t, repo.Close()) // shouldn't panic
+	})
+
+	// TODO: test more methods and concurrency queries
+}
diff --git a/modules/testlogger/testlogger.go b/modules/testlogger/testlogger.go
--- a/modules/testlogger/testlogger.go
+++ b/modules/testlogger/testlogger.go
@@ -4,6 +4,7 @@
 package testlogger
 
 import (
+	"context"
 	"fmt"
 	"os"
 	"runtime"
@@ -108,30 +109,33 @@ func PrintCurrentTest(t testing.TB, skip ...int) func() {
 	actualSkip := util.OptionalArg(skip) + 1
 	_, filename, line, _ := runtime.Caller(actualSkip)
 
+	getRuntimeStackAll := func() string {
+		stack := make([]byte, 1024*1024)
+		n := runtime.Stack(stack, true)
+		return util.UnsafeBytesToString(stack[:n])
+	}
+
+	deferHasRun := false
+	t.Cleanup(func() {
+		if !deferHasRun {
+			Printf("!!! defer function hasn't been run but Cleanup is called\n%s", getRuntimeStackAll())
+		}
+	})
 	Printf("=== %s (%s:%d)\n", log.NewColoredValue(t.Name()), strings.TrimPrefix(filename, prefix), line)
 
 	WriterCloser.pushT(t)
 	timeoutChecker := time.AfterFunc(TestTimeout, func() {
-		l := 128 * 1024
-		var stack []byte
-		for {
-			stack = make([]byte, l)
-			n := runtime.Stack(stack, true)
-			if n <= l {
-				stack = stack[:n]
-				break
-			}
-			l = n
-		}
-		Printf("!!! %s ... timeout: %v ... stacktrace:\n%s\n\n", log.NewColoredValue(t.Name(), log.Bold, log.FgRed), TestTimeout, string(stack))
+		Printf("!!! %s ... timeout: %v ... stacktrace:\n%s\n\n", log.NewColoredValue(t.Name(), log.Bold, log.FgRed), TestTimeout, getRuntimeStackAll())
 	})
 	return func() {
+		deferHasRun = true
 		flushStart := time.Now()
 		slowFlushChecker := time.AfterFunc(TestSlowFlush, func() {
 			Printf("+++ %s ... still flushing after %v ...\n", log.NewColoredValue(t.Name(), log.Bold, log.FgRed), TestSlowFlush)
 		})
 		if err := queue.GetManager().FlushAll(t.Context(), -1); err != nil {
-			t.Errorf("Flushing queues failed with error %v", err)
+			// if panic occurs, then the t.Context() is also cancelled ahead, so here it shows "context canceled" error.
+			t.Errorf("Flushing queues failed with error %q, cause %q", err, context.Cause(t.Context()))
 		}
 		slowFlushChecker.Stop()
 		timeoutChecker.Stop()
diff --git a/services/contexttest/context_tests.go b/services/contexttest/context_tests.go
--- a/services/contexttest/context_tests.go
+++ b/services/contexttest/context_tests.go
@@ -143,8 +143,9 @@ func LoadRepoCommit(t *testing.T, ctx gocontext.Context) {
 
 	gitRepo, err := gitrepo.OpenRepository(ctx, repo.Repository)
 	require.NoError(t, err)
-	defer gitRepo.Close()
-
+	t.Cleanup(func() {
+		gitRepo.Close()
+	})
 	if repo.RefFullName == "" {
 		repo.RefFullName = git_module.RefNameFromBranch(repo.Repository.DefaultBranch)
 	}
EOF_114329324912

# Verify Git is available (required for tests that execute real Git commands)
git --version
git_check_rc=$?

if [ $git_check_rc -ne 0 ]; then
    echo "Git verification failed"
    echo "OMNIGRIL_EXIT_CODE=$git_check_rc"
    git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"
    exit $git_check_rc
fi

# Verify Go version
go version

# Ensure CGO is enabled and environment variables are set
export CGO_ENABLED=1
export GO111MODULE=on

# Run tests from modules/git package with specific test functions from target files
# Target tests from commit_info_test.go and git_test.go
# Note: TestMain is a special setup function that runs automatically, no need to specify in -run
go test -v -tags='sqlite sqlite_unlock_notify' -timeout=20m \
    -run '^(TestEntries_GetCommitsInfo|TestParseGitVersion|TestCheckGitVersionCompatibility)$' \
    ./modules/git
rc1=$?

if [ $rc1 -ne 0 ]; then
    echo "Tests in ./modules/git failed with exit code $rc1"
    echo "OMNIGRIL_EXIT_CODE=$rc1"
    git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"
    exit $rc1
fi

# Run tests from modules/git/gitcmd package with specific test functions
# Target tests from command_test.go
go test -v -tags='sqlite sqlite_unlock_notify' -timeout=20m \
    -run '^(TestRunWithContextStd|TestGitArgument|TestCommandString)$' \
    ./modules/git/gitcmd
rc2=$?

if [ $rc2 -ne 0 ]; then
    echo "Tests in ./modules/git/gitcmd failed with exit code $rc2"
    echo "OMNIGRIL_EXIT_CODE=$rc2"
    git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"
    exit $rc2
fi

# Run tests from modules/git/languagestats package
# This package only has TestMain in main_test.go which is a setup function
# Running the entire package as there are no other test functions to filter
go test -v -tags='sqlite sqlite_unlock_notify' -timeout=20m \
    ./modules/git/languagestats
rc3=$?

if [ $rc3 -ne 0 ]; then
    echo "Tests in ./modules/git/languagestats failed with exit code $rc3"
    echo "OMNIGRIL_EXIT_CODE=$rc3"
    git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"
    exit $rc3
fi

# All target tests passed
rc=0
echo "All target tests passed successfully"

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original files
git checkout ee9d8893a73b8607b43d86c569674a73a65b5a70 "modules/git/commit_info_test.go" "modules/git/git_test.go" "modules/git/gitcmd/command_test.go" "modules/git/languagestats/main_test.go" "modules/testlogger/testlogger.go" "services/contexttest/context_tests.go"

exit $rc