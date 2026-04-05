#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 459c03ee38c2539ad5e4719871d33f1a7bf0a5e7 "tests/testsuite/locate_project.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/testsuite/locate_project.rs b/tests/testsuite/locate_project.rs
--- a/tests/testsuite/locate_project.rs
+++ b/tests/testsuite/locate_project.rs
@@ -145,18 +145,14 @@ fn workspace_missing_member() {
         .build();
 
     p.cargo("locate-project --workspace")
-        .with_status(101)
-        .with_stderr_data(str![[r#"
-[ERROR] failed to load manifest for workspace member `[ROOT]/foo/missing_member`
-referenced by workspace at `[ROOT]/foo/Cargo.toml`
-
-Caused by:
-  failed to read `[ROOT]/foo/missing_member/Cargo.toml`
-
-Caused by:
-  [NOT_FOUND]
-
-"#]])
+        .with_stdout_data(
+            str![[r#"
+{
+  "root": "[ROOT]/foo/Cargo.toml"
+}
+"#]]
+            .is_json(),
+        )
         .run();
 }
 
EOF_114329324912

# Run the specific test for locate_project module
# Using single-threaded execution for stability in virtualized environment
cargo test -p cargo --test testsuite -- locate_project --test-threads=1
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 459c03ee38c2539ad5e4719871d33f1a7bf0a5e7 "tests/testsuite/locate_project.rs"