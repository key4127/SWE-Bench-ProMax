#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 1255eb6143214a0a7b4b7820597f63b857bf59c8 "lib/tests/test_commit_builder.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/tests/test_commit_builder.rs b/lib/tests/test_commit_builder.rs
--- a/lib/tests/test_commit_builder.rs
+++ b/lib/tests/test_commit_builder.rs
@@ -458,6 +458,7 @@ fn test_commit_builder_descendants(backend: TestRepoBackend) {
     let mut tx = repo.start_transaction();
     tx.repo_mut()
         .rewrite_commit(&commit2)
+        .clear_rewrite_source()
         .generate_new_change_id()
         .write()
         .unwrap();
EOF_114329324912

# Run the specific test file using cargo test with the correct runner target
# Using --package jj-lib to specify the correct crate in the workspace
# Using --test runner as that's the actual test target
# Adding test_commit_builder as a filter to run only tests from that module
cargo test --package jj-lib --test runner test_commit_builder -- --nocapture

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 1255eb6143214a0a7b4b7820597f63b857bf59c8 "lib/tests/test_commit_builder.rs"