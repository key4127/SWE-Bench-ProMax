#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9f2c7d096bcc8b524f25ed011620f8f2d08c212d "internal/tui/exp/list/list_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/tui/exp/list/list_test.go b/internal/tui/exp/list/list_test.go
--- a/internal/tui/exp/list/list_test.go
+++ b/internal/tui/exp/list/list_test.go
@@ -7,6 +7,7 @@ import (
 
 	tea "github.com/charmbracelet/bubbletea/v2"
 	"github.com/charmbracelet/crush/internal/tui/components/core/layout"
+	"github.com/charmbracelet/crush/internal/tui/util"
 	"github.com/charmbracelet/lipgloss/v2"
 	"github.com/charmbracelet/x/exp/golden"
 	"github.com/google/uuid"
@@ -602,7 +603,7 @@ func (s *simpleItem) Init() tea.Cmd {
 	return nil
 }
 
-func (s *simpleItem) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
+func (s *simpleItem) Update(msg tea.Msg) (util.Model, tea.Cmd) {
 	return s, nil
 }
 
@@ -644,7 +645,7 @@ func (s *selectableItem) IsFocused() bool {
 	return s.focused
 }
 
-func execCmd(m tea.Model, cmd tea.Cmd) {
+func execCmd(m util.Model, cmd tea.Cmd) {
 	for cmd != nil {
 		msg := cmd()
 		m, cmd = m.Update(msg)
EOF_114329324912

# Set Go environment variables (already set in Dockerfile, but ensuring they're active)
# Note: Removed GOEXPERIMENT=greenteagc as it's not a valid Go experiment flag
export CGO_ENABLED=0
export GO111MODULE=on

# Run tests for the internal/tui/exp/list package
# This is the standard Go way to run tests and will include all necessary files
go test -v ./internal/tui/exp/list/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 9f2c7d096bcc8b524f25ed011620f8f2d08c212d "internal/tui/exp/list/list_test.go"