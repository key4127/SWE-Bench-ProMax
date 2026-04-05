#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout cc1fe6c111be0f7bb683bb5d369df61d0119be5e "internal/ui/termstatus/background_unix_test.go" "internal/backend/util/foreground_test.go" "internal/ui/termstatus/terminal_windows_test.go" "internal/ui/termstatus/status_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/ui/termstatus/background_unix_test.go b/internal/terminal/background_unix_test.go
rename from internal/ui/termstatus/background_unix_test.go
rename to internal/terminal/background_unix_test.go
--- a/internal/ui/termstatus/background_unix_test.go
+++ b/internal/terminal/background_unix_test.go
@@ -1,6 +1,6 @@
 //go:build unix
 
-package termstatus
+package terminal
 
 import (
 	"os"
diff --git a/internal/backend/util/foreground_test.go b/internal/terminal/foreground_test.go
rename from internal/backend/util/foreground_test.go
rename to internal/terminal/foreground_test.go
--- a/internal/backend/util/foreground_test.go
+++ b/internal/terminal/foreground_test.go
@@ -1,7 +1,7 @@
 //go:build !windows
 // +build !windows
 
-package util_test
+package terminal_test
 
 import (
 	"bufio"
@@ -10,7 +10,7 @@ import (
 	"strings"
 	"testing"
 
-	"github.com/restic/restic/internal/backend/util"
+	"github.com/restic/restic/internal/terminal"
 	rtest "github.com/restic/restic/internal/test"
 )
 
@@ -22,7 +22,7 @@ func TestForeground(t *testing.T) {
 	stdout, err := cmd.StdoutPipe()
 	rtest.OK(t, err)
 
-	bg, err := util.StartForeground(cmd)
+	bg, err := terminal.StartForeground(cmd)
 	rtest.OK(t, err)
 	defer func() {
 		rtest.OK(t, cmd.Wait())
diff --git a/internal/ui/termstatus/terminal_windows_test.go b/internal/terminal/terminal_windows_test.go
rename from internal/ui/termstatus/terminal_windows_test.go
rename to internal/terminal/terminal_windows_test.go
--- a/internal/ui/termstatus/terminal_windows_test.go
+++ b/internal/terminal/terminal_windows_test.go
@@ -1,4 +1,4 @@
-package termstatus
+package terminal
 
 import (
 	"syscall"
diff --git a/internal/ui/termstatus/status_test.go b/internal/ui/termstatus/status_test.go
--- a/internal/ui/termstatus/status_test.go
+++ b/internal/ui/termstatus/status_test.go
@@ -8,6 +8,7 @@ import (
 	"strconv"
 	"testing"
 
+	"github.com/restic/restic/internal/terminal"
 	rtest "github.com/restic/restic/internal/test"
 )
 
@@ -17,16 +18,16 @@ func TestSetStatus(t *testing.T) {
 
 	term.canUpdateStatus = true
 	term.fd = ^uintptr(0)
-	term.clearCurrentLine = posixClearCurrentLine
-	term.moveCursorUp = posixMoveCursorUp
+	term.clearCurrentLine = terminal.PosixClearCurrentLine
+	term.moveCursorUp = terminal.PosixMoveCursorUp
 
 	ctx, cancel := context.WithCancel(context.Background())
 	go term.Run(ctx)
 
 	const (
-		cl   = posixControlClearLine
-		home = posixControlMoveCursorHome
-		up   = posixControlMoveCursorUp
+		cl   = terminal.PosixControlClearLine
+		home = terminal.PosixControlMoveCursorHome
+		up   = terminal.PosixControlMoveCursorUp
 	)
 
 	term.SetStatus([]string{"first"})
EOF_114329324912

# Verify Go environment is properly configured
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export CGO_ENABLED=0

# Run the target test files from the NEW locations after patch is applied
# The patch moves test files to internal/terminal/ directory
# Using -v for verbose output, -timeout 30m for sufficient execution time
# Using -p 1 to run tests sequentially for stability in virtualized environment
# Using -count 1 to disable test caching
# Running both test packages in a single command for efficiency
# Note: terminal_windows_test.go will be auto-excluded on Linux due to build tags
go test -v -timeout 30m -p 1 -count 1 ./internal/terminal ./internal/ui/termstatus
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout cc1fe6c111be0f7bb683bb5d369df61d0119be5e "internal/ui/termstatus/background_unix_test.go" "internal/backend/util/foreground_test.go" "internal/ui/termstatus/terminal_windows_test.go" "internal/ui/termstatus/status_test.go"