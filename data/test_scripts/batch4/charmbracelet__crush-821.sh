#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit and test file
git checkout 532b47391677d52a34ac2ebb4dd9b0fdadd8306d "internal/shell/command_block_test.go"

# Apply test patch (adds/modifies internal/shell/command_block_test.go)
git apply -v - <<'EOF_114329324912'
diff --git a/internal/shell/command_block_test.go b/internal/shell/command_block_test.go
--- a/internal/shell/command_block_test.go
+++ b/internal/shell/command_block_test.go
@@ -4,6 +4,8 @@ import (
 	"context"
 	"strings"
 	"testing"
+
+	"github.com/stretchr/testify/require"
 )
 
 func TestCommandBlocking(t *testing.T) {
@@ -56,32 +58,24 @@ func TestCommandBlocking(t *testing.T) {
 		{
 			name: "block npm global install with -g",
 			blockFuncs: []BlockFunc{
-				ArgumentsBlocker([][]string{
-					{"npm", "install", "-g"},
-					{"npm", "install", "--global"},
-				}),
+				ArgumentsBlocker("npm", []string{"install"}, []string{"-g"}),
 			},
 			command:     "npm install -g typescript",
 			shouldBlock: true,
 		},
 		{
 			name: "block npm global install with --global",
 			blockFuncs: []BlockFunc{
-				ArgumentsBlocker([][]string{
-					{"npm", "install", "-g"},
-					{"npm", "install", "--global"},
-				}),
+				ArgumentsBlocker("npm", []string{"install"}, []string{"--global"}),
 			},
 			command:     "npm install --global typescript",
 			shouldBlock: true,
 		},
 		{
 			name: "allow npm local install",
 			blockFuncs: []BlockFunc{
-				ArgumentsBlocker([][]string{
-					{"npm", "install", "-g"},
-					{"npm", "install", "--global"},
-				}),
+				ArgumentsBlocker("npm", []string{"install"}, []string{"-g"}),
+				ArgumentsBlocker("npm", []string{"install"}, []string{"--global"}),
 			},
 			command:     "npm install typescript",
 			shouldBlock: false,
@@ -116,3 +110,232 @@ func TestCommandBlocking(t *testing.T) {
 		})
 	}
 }
+
+func TestArgumentsBlocker(t *testing.T) {
+	tests := []struct {
+		name        string
+		cmd         string
+		args        []string
+		flags       []string
+		input       []string
+		shouldBlock bool
+	}{
+		// Basic command blocking
+		{
+			name:        "block exact command match",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       nil,
+			input:       []string{"npm", "install", "package"},
+			shouldBlock: true,
+		},
+		{
+			name:        "allow different command",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       nil,
+			input:       []string{"yarn", "install", "package"},
+			shouldBlock: false,
+		},
+		{
+			name:        "allow different subcommand",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       nil,
+			input:       []string{"npm", "list"},
+			shouldBlock: false,
+		},
+
+		// Flag-based blocking
+		{
+			name:        "block with single flag",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       []string{"-g"},
+			input:       []string{"npm", "install", "-g", "typescript"},
+			shouldBlock: true,
+		},
+		{
+			name:        "block with flag in different position",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       []string{"-g"},
+			input:       []string{"npm", "install", "typescript", "-g"},
+			shouldBlock: true,
+		},
+		{
+			name:        "allow without required flag",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       []string{"-g"},
+			input:       []string{"npm", "install", "typescript"},
+			shouldBlock: false,
+		},
+		{
+			name:        "block with multiple flags",
+			cmd:         "pip",
+			args:        []string{"install"},
+			flags:       []string{"--user"},
+			input:       []string{"pip", "install", "--user", "--upgrade", "package"},
+			shouldBlock: true,
+		},
+
+		// Complex argument patterns
+		{
+			name:        "block multi-arg subcommand",
+			cmd:         "yarn",
+			args:        []string{"global", "add"},
+			flags:       nil,
+			input:       []string{"yarn", "global", "add", "typescript"},
+			shouldBlock: true,
+		},
+		{
+			name:        "allow partial multi-arg match",
+			cmd:         "yarn",
+			args:        []string{"global", "add"},
+			flags:       nil,
+			input:       []string{"yarn", "global", "list"},
+			shouldBlock: false,
+		},
+
+		// Edge cases
+		{
+			name:        "handle empty input",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       nil,
+			input:       []string{},
+			shouldBlock: false,
+		},
+		{
+			name:        "handle command only",
+			cmd:         "npm",
+			args:        []string{"install"},
+			flags:       nil,
+			input:       []string{"npm"},
+			shouldBlock: false,
+		},
+		{
+			name:        "block pacman with -S flag",
+			cmd:         "pacman",
+			args:        nil,
+			flags:       []string{"-S"},
+			input:       []string{"pacman", "-S", "package"},
+			shouldBlock: true,
+		},
+		{
+			name:        "allow pacman without -S flag",
+			cmd:         "pacman",
+			args:        nil,
+			flags:       []string{"-S"},
+			input:       []string{"pacman", "-Q", "package"},
+			shouldBlock: false,
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			blocker := ArgumentsBlocker(tt.cmd, tt.args, tt.flags)
+			result := blocker(tt.input)
+			require.Equal(t, tt.shouldBlock, result,
+				"Expected block=%v for input %v", tt.shouldBlock, tt.input)
+		})
+	}
+}
+
+func TestCommandsBlocker(t *testing.T) {
+	tests := []struct {
+		name        string
+		banned      []string
+		input       []string
+		shouldBlock bool
+	}{
+		{
+			name:        "block single banned command",
+			banned:      []string{"curl"},
+			input:       []string{"curl", "https://example.com"},
+			shouldBlock: true,
+		},
+		{
+			name:        "allow non-banned command",
+			banned:      []string{"curl", "wget"},
+			input:       []string{"echo", "hello"},
+			shouldBlock: false,
+		},
+		{
+			name:        "block from multiple banned",
+			banned:      []string{"curl", "wget", "nc"},
+			input:       []string{"wget", "https://example.com"},
+			shouldBlock: true,
+		},
+		{
+			name:        "handle empty input",
+			banned:      []string{"curl"},
+			input:       []string{},
+			shouldBlock: false,
+		},
+		{
+			name:        "case sensitive matching",
+			banned:      []string{"curl"},
+			input:       []string{"CURL", "https://example.com"},
+			shouldBlock: false,
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			blocker := CommandsBlocker(tt.banned)
+			result := blocker(tt.input)
+			require.Equal(t, tt.shouldBlock, result,
+				"Expected block=%v for input %v", tt.shouldBlock, tt.input)
+		})
+	}
+}
+
+func TestSplitArgsFlags(t *testing.T) {
+	tests := []struct {
+		name      string
+		input     []string
+		wantArgs  []string
+		wantFlags []string
+	}{
+		{
+			name:      "only args",
+			input:     []string{"install", "package", "another"},
+			wantArgs:  []string{"install", "package", "another"},
+			wantFlags: []string{},
+		},
+		{
+			name:      "only flags",
+			input:     []string{"-g", "--verbose", "-f"},
+			wantArgs:  []string{},
+			wantFlags: []string{"-g", "--verbose", "-f"},
+		},
+		{
+			name:      "mixed args and flags",
+			input:     []string{"install", "-g", "package", "--verbose"},
+			wantArgs:  []string{"install", "package"},
+			wantFlags: []string{"-g", "--verbose"},
+		},
+		{
+			name:      "empty input",
+			input:     []string{},
+			wantArgs:  []string{},
+			wantFlags: []string{},
+		},
+		{
+			name:      "single dash flag",
+			input:     []string{"-S", "package"},
+			wantArgs:  []string{"package"},
+			wantFlags: []string{"-S"},
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			args, flags := splitArgsFlags(tt.input)
+			require.Equal(t, tt.wantArgs, args, "args mismatch")
+			require.Equal(t, tt.wantFlags, flags, "flags mismatch")
+		})
+	}
+}
EOF_114329324912

# Verify Go environment is properly set
export GO111MODULE=on
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc
export GOTOOLCHAIN=go1.25.0
export GOPROXY=https://proxy.golang.org,direct

# Ensure dependencies are available
go mod download

# Run tests in the internal/shell package for command_block_test.go
# Using -v for verbose output to see which tests are executed
# Using -count=1 to disable test caching and ensure fresh runs
go test -v -count=1 ./internal/shell -run TestCommandBlock
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes made by the test patch
git checkout 532b47391677d52a34ac2ebb4dd9b0fdadd8306d "internal/shell/command_block_test.go"