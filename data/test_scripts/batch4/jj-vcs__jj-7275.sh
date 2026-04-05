#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 5f8dd79e8b69ad6606be1062d866c7668fe0544b "lib/tests/test_git.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/tests/test_git.rs b/lib/tests/test_git.rs
--- a/lib/tests/test_git.rs
+++ b/lib/tests/test_git.rs
@@ -48,6 +48,7 @@ use jj_lib::git::GitPushStats;
 use jj_lib::git::GitRefKind;
 use jj_lib::git::GitRefUpdate;
 use jj_lib::git::GitResetHeadError;
+use jj_lib::git::expand_fetch_refspecs;
 use jj_lib::git_backend::GitBackend;
 use jj_lib::hex_util;
 use jj_lib::object_id::ObjectId as _;
@@ -139,14 +140,14 @@ fn get_git_repo(repo: &Arc<ReadonlyRepo>) -> gix::Repository {
 fn git_fetch(
     mut_repo: &mut MutableRepo,
     remote_name: &RemoteName,
-    branch_names: &[StringPattern],
+    branch_names: Vec<StringPattern>,
     git_settings: &GitSettings,
     fetch_tags_override: Option<FetchTagsOverride>,
 ) -> Result<GitFetchStats, GitFetchError> {
     let mut git_fetch = GitFetch::new(mut_repo, git_settings).unwrap();
     git_fetch.fetch(
         remote_name,
-        branch_names,
+        expand_fetch_refspecs(remote_name, branch_names)?,
         git::RemoteCallbacks::default(),
         None,
         fetch_tags_override,
@@ -2831,7 +2832,7 @@ fn test_fetch_empty_repo() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -2856,7 +2857,7 @@ fn test_fetch_initial_commit_head_is_not_set() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -2920,7 +2921,7 @@ fn test_fetch_initial_commit_head_is_set() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -2943,7 +2944,7 @@ fn test_fetch_success() {
     git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -2970,7 +2971,7 @@ fn test_fetch_success() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3026,7 +3027,7 @@ fn test_fetch_prune_deleted_ref() {
     git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3049,7 +3050,7 @@ fn test_fetch_prune_deleted_ref() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3076,7 +3077,7 @@ fn test_fetch_no_default_branch() {
     git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3095,7 +3096,7 @@ fn test_fetch_no_default_branch() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3112,7 +3113,14 @@ fn test_fetch_empty_refspecs() {
 
     // Base refspecs shouldn't be respected
     let mut tx = test_data.repo.start_transaction();
-    git_fetch(tx.repo_mut(), "origin".as_ref(), &[], &git_settings, None).unwrap();
+    git_fetch(
+        tx.repo_mut(),
+        "origin".as_ref(),
+        vec![],
+        &git_settings,
+        None,
+    )
+    .unwrap();
     assert!(
         tx.repo_mut()
             .get_remote_bookmark(remote_symbol("main", "origin"))
@@ -3135,7 +3143,7 @@ fn test_fetch_no_such_remote() {
     let result = git_fetch(
         tx.repo_mut(),
         "invalid-remote".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     );
@@ -3155,7 +3163,7 @@ fn test_fetch_multiple_branches() {
     let fetch_stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[
+        vec![
             StringPattern::Exact("main".to_string()),
             StringPattern::Exact("noexist1".to_string()),
             StringPattern::Exact("noexist2".to_string()),
@@ -3233,7 +3241,7 @@ fn test_fetch_with_fetch_tags_override() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
@@ -3245,7 +3253,7 @@ fn test_fetch_with_fetch_tags_override() {
     let stats = git_fetch(
         tx.repo_mut(),
         "origin".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         Some(FetchTagsOverride::AllTags),
     )
@@ -3271,7 +3279,7 @@ fn test_fetch_with_fetch_tags_override() {
     let stats = git_fetch(
         tx.repo_mut(),
         "originAllTags".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         Some(FetchTagsOverride::NoTags),
     )
@@ -3283,7 +3291,7 @@ fn test_fetch_with_fetch_tags_override() {
     let stats = git_fetch(
         tx.repo_mut(),
         "originAllTags".as_ref(),
-        &[StringPattern::everything()],
+        vec![StringPattern::everything()],
         &git_settings,
         None,
     )
EOF_114329324912

# Run the specific test file using cargo test with the correct runner target
# Using --package jj-lib to specify the correct crate in the workspace
# Using --test runner as that's the actual test target
# Adding test_git as a filter to run only tests from that module
cargo test --package jj-lib --test runner test_git -- --test-threads=1 --nocapture

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 5f8dd79e8b69ad6606be1062d866c7668fe0544b "lib/tests/test_git.rs"