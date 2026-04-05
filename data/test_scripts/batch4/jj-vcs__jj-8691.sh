#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout c64d42eecda7b740f8ada8b203afe889c2720fb0 "lib/tests/test_git.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/tests/test_git.rs b/lib/tests/test_git.rs
--- a/lib/tests/test_git.rs
+++ b/lib/tests/test_git.rs
@@ -16,6 +16,7 @@ use std::collections::BTreeMap;
 use std::collections::HashMap;
 use std::collections::HashSet;
 use std::fs;
+use std::io;
 use std::io::Write as _;
 use std::iter;
 use std::path::Path;
@@ -53,6 +54,7 @@ use jj_lib::git::GitRefKind;
 use jj_lib::git::GitRefUpdate;
 use jj_lib::git::GitResetHeadError;
 use jj_lib::git::GitSettings;
+use jj_lib::git::GitSubprocessCallback;
 use jj_lib::git::GitSubprocessOptions;
 use jj_lib::git::IgnoredRefspec;
 use jj_lib::git::IgnoredRefspecs;
@@ -94,6 +96,23 @@ use testutils::repo_path;
 use testutils::write_random_commit;
 use testutils::write_random_commit_with_parents;
 
+#[derive(Debug)]
+struct NullCallback;
+
+impl GitSubprocessCallback for NullCallback {
+    fn needs_progress(&self) -> bool {
+        false
+    }
+
+    fn progress(&mut self, _progress: &git::GitProgress) -> io::Result<()> {
+        Ok(())
+    }
+
+    fn remote_sideband(&mut self, _message: &[u8]) -> io::Result<()> {
+        Ok(())
+    }
+}
+
 fn empty_git_commit(
     git_repo: &gix::Repository,
     ref_name: &str,
@@ -163,10 +182,9 @@ fn fetch_with(
 ) -> Result<(), GitFetchError> {
     let refspecs =
         expand_fetch_refspecs(remote, bookmark_expr).expect("ref patterns should be valid");
-    let callbacks = git::RemoteCallbacks::default();
     let depth = None;
     let fetch_tags = None;
-    fetcher.fetch(remote, refspecs, callbacks, depth, fetch_tags)
+    fetcher.fetch(remote, refspecs, &mut NullCallback, depth, fetch_tags)
 }
 
 fn push_status_rejected_references(push_stats: GitPushStats) -> Vec<GitRefNameBuf> {
@@ -3876,10 +3894,9 @@ fn test_fetch_with_fetch_tags_override() {
             )
             .unwrap();
             let refspecs = expand_fetch_refspecs(remote, StringExpression::all()).unwrap();
-            let callbacks = git::RemoteCallbacks::default();
             let depth = None;
             fetcher
-                .fetch(remote, refspecs, callbacks, depth, fetch_tags)
+                .fetch(remote, refspecs, &mut NullCallback, depth, fetch_tags)
                 .unwrap();
             fetcher.import_refs().unwrap()
         };
@@ -4078,7 +4095,7 @@ fn test_push_bookmarks_success() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4157,7 +4174,7 @@ fn test_push_bookmarks_deletion() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4235,7 +4252,7 @@ fn test_push_bookmarks_mixed_deletion_and_addition() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4316,7 +4333,7 @@ fn test_push_bookmarks_not_fast_forward() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4369,7 +4386,7 @@ fn test_push_bookmarks_partial_success() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4478,7 +4495,7 @@ fn test_push_bookmarks_unmapped_refs() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4575,7 +4592,7 @@ fn test_push_updates_unexpectedly_moved_sideways_on_remote() {
             subprocess_options,
             "origin".as_ref(),
             &targets,
-            git::RemoteCallbacks::default(),
+            &mut NullCallback,
         )
     };
 
@@ -4659,7 +4676,7 @@ fn test_push_updates_unexpectedly_moved_forward_on_remote() {
             subprocess_options,
             "origin".as_ref(),
             &targets,
-            git::RemoteCallbacks::default(),
+            &mut NullCallback,
         )
     };
 
@@ -4723,7 +4740,7 @@ fn test_push_updates_unexpectedly_exists_on_remote() {
             subprocess_options,
             "origin".as_ref(),
             &targets,
-            git::RemoteCallbacks::default(),
+            &mut NullCallback,
         )
     };
 
@@ -4759,7 +4776,7 @@ fn test_push_updates_success() {
             expected_current_target: Some(setup.main_commit.id().clone()),
             new_target: Some(setup.child_of_main_commit.id().clone()),
         }],
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
     insta::assert_debug_snapshot!(stats, @r#"
@@ -4805,7 +4822,7 @@ fn test_push_updates_no_such_remote() {
             expected_current_target: Some(setup.main_commit.id().clone()),
             new_target: Some(setup.child_of_main_commit.id().clone()),
         }],
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     );
     assert!(matches!(result, Err(GitPushError::NoSuchRemote(_))));
 }
@@ -4825,7 +4842,7 @@ fn test_push_updates_invalid_remote() {
             expected_current_target: Some(setup.main_commit.id().clone()),
             new_target: Some(setup.child_of_main_commit.id().clone()),
         }],
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     );
     assert!(matches!(result, Err(GitPushError::NoSuchRemote(_))));
 }
@@ -4858,7 +4875,7 @@ fn test_push_environment_options() {
         subprocess_options,
         "origin".as_ref(),
         &targets,
-        git::RemoteCallbacks::default(),
+        &mut NullCallback,
     )
     .unwrap();
 
EOF_114329324912

# Set environment variables for test execution
export RUST_BACKTRACE=1
export CARGO_TERM_COLOR=always
export CARGO_INCREMENTAL=0

# Run the specific test file using cargo test with the correct runner target
# Using --package jj-lib to specify the correct crate in the workspace
# Using --test runner as that's the actual test target
# Adding test_git as a filter to run only tests from that module
# Adding -- --nocapture to show test output
# Adding --test-threads=1 to ensure single-threaded execution for stability
cargo test --package jj-lib --test runner test_git -- --nocapture --test-threads=1

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout c64d42eecda7b740f8ada8b203afe889c2720fb0 "lib/tests/test_git.rs"