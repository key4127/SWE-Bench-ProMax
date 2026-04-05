#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target file to ensure clean state
git checkout e7c94f43ab529e8b2d4eb3cb6e0d656c4a8d7f2a "go/cmd/dolt/commands/ci/dolt_test_step.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/go/cmd/dolt/commands/ci/dolt_test_step.go b/go/cmd/dolt/commands/ci/dolt_test_step_run.go
rename from go/cmd/dolt/commands/ci/dolt_test_step.go
rename to go/cmd/dolt/commands/ci/dolt_test_step_run.go
--- a/go/cmd/dolt/commands/ci/dolt_test_step.go
+++ b/go/cmd/dolt/commands/ci/dolt_test_step_run.go

diff --git a/go/cmd/dolt/commands/ci/dolt_test_step_view.go b/go/cmd/dolt/commands/ci/dolt_test_step_view.go
new file mode 100644
--- /dev/null
+++ b/go/cmd/dolt/commands/ci/dolt_test_step_view.go
@@ -0,0 +1,79 @@
+// Copyright 2025 Dolthub, Inc.
+//
+// Licensed under the Apache License, Version 2.0 (the "License");
+// you may not use this file except in compliance with the License.
+// You may obtain a copy of the License at
+//
+//     http://www.apache.org/licenses/LICENSE-2.0
+//
+// Unless required by applicable law or agreed to in writing, software
+// distributed under the License is distributed on an "AS IS" BASIS,
+// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+// See the License for the specific language governing permissions and
+// limitations under the License.
+
+package ci
+
+import (
+	"fmt"
+	"strings"
+
+	"github.com/dolthub/dolt/go/libraries/doltcore/env/actions/dolt_ci"
+	dtablefunctions "github.com/dolthub/dolt/go/libraries/doltcore/sqle/dtablefunctions"
+)
+
+// previewDoltTestStatements returns the SQL queries that would be executed by dolt_test_run
+// for the given DoltTestStep selection (groups and tests). We reuse the same selection semantics
+// as run-time resolution, but only return the table function invocations for preview.
+func previewDoltTestStatements(dt *dolt_ci.DoltTestStep) ([]string, error) {
+	selectors := buildPreviewSelectors(dt)
+	return makePreviewStatements(selectors), nil
+}
+
+// buildPreviewSelectors computes which selectors (test names and group names) to preview based on
+// the provided DoltTestStep configuration. Wildcards collapse the corresponding set to a single "*".
+func buildPreviewSelectors(dt *dolt_ci.DoltTestStep) []string {
+	spec := deriveSelectionSpec(dt)
+	testsProvided := len(dt.Tests) > 0
+	groupsProvided := len(dt.TestGroups) > 0
+
+	switch {
+	case testsProvided && groupsProvided:
+		if spec.testsWildcard && !spec.groupsWildcard {
+			return nodesToValues(dt.TestGroups)
+		}
+		if spec.groupsWildcard && !spec.testsWildcard {
+			return nodesToValues(dt.Tests)
+		}
+		if spec.testsWildcard && spec.groupsWildcard {
+			return []string{"*"}
+		}
+		args := append([]string{}, nodesToValues(dt.Tests)...)
+		args = append(args, nodesToValues(dt.TestGroups)...)
+		return args
+
+	case testsProvided:
+		if spec.testsWildcard {
+			return []string{"*"}
+		}
+		return nodesToValues(dt.Tests)
+
+	case groupsProvided:
+		if spec.groupsWildcard {
+			return []string{"*"}
+		}
+		return nodesToValues(dt.TestGroups)
+	}
+
+	return []string{"*"}
+}
+
+func makePreviewStatements(selectors []string) []string {
+	fn := (&dtablefunctions.TestsRunTableFunction{}).Name()
+	stmts := make([]string, 0, len(selectors))
+	for _, s := range selectors {
+		esc := strings.ReplaceAll(s, "'", "''")
+		stmts = append(stmts, fmt.Sprintf("SELECT * FROM %s('%s')", fn, esc))
+	}
+	return stmts
+}
EOF_114329324912

# Navigate to the Go module directory
cd /testbed/go

# Ensure environment variables are set
export PATH=/usr/local/go/bin:$PATH
export GOPATH=/root/go
export PATH=$GOPATH/bin:$PATH
export CGO_ENABLED=1

# Since the ci package has no test files, we need to run tests that would exercise this code
# Run tests for the entire commands package which would include any tests that use the ci package
# This ensures the refactoring doesn't break any dependent code
go test -v -vet=off -timeout 30m ./cmd/dolt/commands/...

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original file
cd /testbed
git checkout e7c94f43ab529e8b2d4eb3cb6e0d656c4a8d7f2a "go/cmd/dolt/commands/ci/dolt_test_step.go"