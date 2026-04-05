#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original files to ensure clean state
git checkout f6db180a8097ff6fae5bfe78339b109dc0881180 "modules/git/gitcmd/command_race_test.go" "modules/git/gitcmd/command_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/git/gitcmd/command_race_test.go b/modules/git/gitcmd/command_race_test.go
deleted file mode 100644
--- a/modules/git/gitcmd/command_race_test.go
+++ /dev/null
@@ -1,38 +0,0 @@
-// Copyright 2017 The Gitea Authors. All rights reserved.
-// SPDX-License-Identifier: MIT
-
-//go:build race
-
-package gitcmd
-
-import (
-	"context"
-	"testing"
-	"time"
-)
-
-func TestRunWithContextNoTimeout(t *testing.T) {
-	maxLoops := 10
-
-	// 'git --version' does not block so it must be finished before the timeout triggered.
-	for i := 0; i < maxLoops; i++ {
-		cmd := NewCommand("--version")
-		if err := cmd.Run(t.Context()); err != nil {
-			t.Fatal(err)
-		}
-	}
-}
-
-func TestRunWithContextTimeout(t *testing.T) {
-	maxLoops := 10
-
-	// 'git hash-object --stdin' blocks on stdin so we can have the timeout triggered.
-	for i := 0; i < maxLoops; i++ {
-		cmd := NewCommand("hash-object", "--stdin")
-		if err := cmd.WithTimeout(1 * time.Millisecond).Run(t.Context()); err != nil {
-			if err != context.DeadlineExceeded {
-				t.Fatalf("Testing %d/%d: %v", i, maxLoops, err)
-			}
-		}
-	}
-}
diff --git a/modules/git/gitcmd/command_test.go b/modules/git/gitcmd/command_test.go
--- a/modules/git/gitcmd/command_test.go
+++ b/modules/git/gitcmd/command_test.go
@@ -4,9 +4,11 @@
 package gitcmd
 
 import (
+	"context"
 	"fmt"
 	"os"
 	"testing"
+	"time"
 
 	"code.gitea.io/gitea/modules/setting"
 	"code.gitea.io/gitea/modules/tempdir"
@@ -111,3 +113,15 @@ func TestRunStdError(t *testing.T) {
 
 	require.ErrorAs(t, fmt.Errorf("wrapped %w", err), &asErr)
 }
+
+func TestRunWithContextTimeout(t *testing.T) {
+	t.Run("NoTimeout", func(t *testing.T) {
+		// 'git --version' does not block so it must be finished before the timeout triggered.
+		err := NewCommand("--version").Run(t.Context())
+		require.NoError(t, err)
+	})
+	t.Run("WithTimeout", func(t *testing.T) {
+		err := NewCommand("hash-object", "--stdin").WithTimeout(1 * time.Millisecond).Run(t.Context())
+		require.ErrorIs(t, err, context.DeadlineExceeded)
+	})
+}
EOF_114329324912

# Verify Git is available (required for tests that execute real Git commands)
git --version
git_check_rc=$?

if [ $git_check_rc -ne 0 ]; then
    echo "Git verification failed"
    echo "OMNIGRIL_EXIT_CODE=$git_check_rc"
    git checkout f6db180a8097ff6fae5bfe78339b109dc0881180 "modules/git/gitcmd/command_race_test.go" "modules/git/gitcmd/command_test.go"
    exit $git_check_rc
fi

# Verify Go version
go version

# Ensure CGO is enabled and environment variables are set
export CGO_ENABLED=1
export GO111MODULE=on
export GOEXPERIMENT=jsonv2
export CGO_CFLAGS="-DSQLITE_MAX_VARIABLE_NUMBER=32766"

# Run tests from modules/git/gitcmd package
# This will execute all tests in the package including:
# - command_test.go (standard tests including the patched TestRunWithContextTimeout)
# - command_race_test.go (race tests, automatically included when -race flag is used)
# Note: command_race_test.go has build constraint "//go:build race" so it only compiles with -race
echo "Running tests with race detector for modules/git/gitcmd package..."
go test -race -v -tags='sqlite sqlite_unlock_notify' -timeout=20m \
    ./modules/git/gitcmd/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original files
git checkout f6db180a8097ff6fae5bfe78339b109dc0881180 "modules/git/gitcmd/command_race_test.go" "modules/git/gitcmd/command_test.go"

exit $rc