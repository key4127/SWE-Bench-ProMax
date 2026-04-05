#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ed054707327b70477865f4fe0be5210d278b84fa "pkg/commands/git_commands/deps_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/commands/git_commands/deps_test.go b/pkg/commands/git_commands/deps_test.go
--- a/pkg/commands/git_commands/deps_test.go
+++ b/pkg/commands/git_commands/deps_test.go
@@ -61,6 +61,10 @@ func buildGitCommon(deps commonDeps) *GitCommon {
 		gitCommon.Common.SetUserConfig(config.GetDefaultConfig())
 	}
 
+	gitCommon.pagerConfig = config.NewPagerConfig(func() *config.UserConfig {
+		return gitCommon.Common.UserConfig()
+	})
+
 	gitCommon.version = deps.gitVersion
 	if gitCommon.version == nil {
 		gitCommon.version = &GitVersion{2, 0, 0, ""}
EOF_114329324912

# Verify Go environment is properly configured
export CGO_ENABLED=0
export GO111MODULE=on

# Run the target test file using package-level testing
# This automatically includes all necessary files from the package
# Using -run to filter tests from deps_test.go (tests typically start with Test)
go test -v ./pkg/commands/git_commands/ -run Test -short 2>&1
rc=$?

# Echo exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout ed054707327b70477865f4fe0be5210d278b84fa "pkg/commands/git_commands/deps_test.go"