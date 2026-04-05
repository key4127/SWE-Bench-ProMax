#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 7f47753c3c99fc991727cc3ef775f8008b630f2b "cli/tests/test_evolog_command.rs" "lib/tests/test_conflicts.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/cli/tests/test_evolog_command.rs b/cli/tests/test_evolog_command.rs
--- a/cli/tests/test_evolog_command.rs
+++ b/cli/tests/test_evolog_command.rs
@@ -423,11 +423,13 @@ fn test_evolog_squash() {
     │ │ │     1     : <<<<<<< conflict 1 of 1
     │ │ │     2     : +++++++ side #1
     │ │ │     3    1: squashed 2
-    │ │ │     4     : %%%%%%% diff from base #1 to side #2
-    │ │ │     5     : +fourth
-    │ │ │     6    1: %%%%%%% diff from base #2 to side #3
-    │ │ │     7     : +fifth
-    │ │ │     8     : >>>>>>> conflict 1 of 1 ends
+    │ │ │     4     : %%%%%%% diff from: base #1
+    │ │ │     5     : \\\\\\\        to: side #2
+    │ │ │     6     : +fourth
+    │ │ │     7     : %%%%%%% diff from: base #2
+    │ │ │     8    1: \\\\\\\        to: side #3
+    │ │ │     9     : +fifth
+    │ │ │    10     : >>>>>>> conflict 1 of 1 ends
     │ │ ○  vruxwmqv/0 test.user@example.com 2001-02-03 08:05:15 770795d0 (hidden)
     │ │ │  fifth
     │ │ │  -- operation b22b0aceb94e snapshot working copy
@@ -455,9 +457,10 @@ fn test_evolog_squash() {
     │ │     1     : <<<<<<< conflict 1 of 1
     │ │     2     : +++++++ side #1
     │ │     3    1: squashed 1
-    │ │     4    1: %%%%%%% diff from base to side #2
-    │ │     5     : +third
-    │ │     6     : >>>>>>> conflict 1 of 1 ends
+    │ │     4     : %%%%%%% diff from: base
+    │ │     5    1: \\\\\\\        to: side #2
+    │ │     6     : +third
+    │ │     7     : >>>>>>> conflict 1 of 1 ends
     │ │  Removed regular file file2:
     │ │     1     : foo2
     │ │  Removed regular file file3:
@@ -486,11 +489,12 @@ fn test_evolog_squash() {
     │ │  -- operation 65c81703100d squash commits into 5878cbe03cdf599c9353e5a1a52a01f4c5e0e0fa
     │ │  Modified commit description:
     │ │     1     : <<<<<<< conflict 1 of 1
-    │ │     2     : %%%%%%% diff from base to side #1
-    │ │     3     : +first
-    │ │     4     : +++++++ side #2
-    │ │     5     : second
-    │ │     6     : >>>>>>> conflict 1 of 1 ends
+    │ │     2     : %%%%%%% diff from: base
+    │ │     3     : \\\\\\\        to: side #1
+    │ │     4     : +first
+    │ │     5     : +++++++ side #2
+    │ │     6     : second
+    │ │     7     : >>>>>>> conflict 1 of 1 ends
     │ │          1: squashed 1
     │ ○  kkmpptxz/0 test.user@example.com 2001-02-03 08:05:10 a3759c9d (hidden)
     │ │  second
diff --git a/lib/tests/test_conflicts.rs b/lib/tests/test_conflicts.rs
--- a/lib/tests/test_conflicts.rs
+++ b/lib/tests/test_conflicts.rs
@@ -95,7 +95,8 @@ fn test_materialize_conflict_basic() {
     left 3.1
     left 3.2
     left 3.3
-    %%%%%%% diff from base to side #2
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #2
     -line 3
     +right 3.1
     >>>>>>> conflict 1 of 1 ends
@@ -115,7 +116,8 @@ fn test_materialize_conflict_basic() {
     line 1
     line 2
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 3
     +right 3.1
     +++++++ side #2
@@ -245,7 +247,8 @@ fn test_materialize_conflict_three_sides() {
         @r"
     line 1
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base #1 to side #1
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #1
     -line 2 base
     -line 3 base
     +line 2 a.1
@@ -255,7 +258,8 @@ fn test_materialize_conflict_three_sides() {
     line 2 b.1
     line 3 base
     line 4 b.2
-    %%%%%%% diff from base #2 to side #3
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #3
      line 2 base
     +line 3 c.2
     >>>>>>> conflict 1 of 1 ends
@@ -272,13 +276,15 @@ fn test_materialize_conflict_three_sides() {
     line 2 a.1
     line 3 a.2
     line 4 base
-    %%%%%%% diff from base #1 to side #2
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #2
     -line 2 base
     +line 2 b.1
      line 3 base
     -line 4 base
     +line 4 b.2
-    %%%%%%% diff from base #2 to side #3
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #3
      line 2 base
     +line 3 c.2
     >>>>>>> conflict 1 of 1 ends
@@ -404,11 +410,13 @@ fn test_materialize_conflict_multi_rebase_conflicts() {
     line 2 a.1
     line 2 a.2
     line 2 a.3
-    %%%%%%% diff from base #1 to side #2
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #2
     -line 2 base
     +line 2 b.1
     +line 2 b.2
-    %%%%%%% diff from base #2 to side #3
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #3
     -line 2 base
     +line 2 c.1
     >>>>>>> conflict 1 of 1 ends
@@ -424,10 +432,12 @@ fn test_materialize_conflict_multi_rebase_conflicts() {
         @r"
     line 1
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base #1 to side #1
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #1
     -line 2 base
     +line 2 c.1
-    %%%%%%% diff from base #2 to side #2
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #2
     -line 2 base
     +line 2 b.1
     +line 2 b.2
@@ -448,14 +458,16 @@ fn test_materialize_conflict_multi_rebase_conflicts() {
         @r"
     line 1
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base #1 to side #1
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #1
     -line 2 base
     +line 2 c.1
     +++++++ side #2
     line 2 a.1
     line 2 a.2
     line 2 a.3
-    %%%%%%% diff from base #2 to side #3
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #3
     -line 2 base
     +line 2 b.1
     +line 2 b.2
@@ -519,14 +531,16 @@ fn test_materialize_parse_roundtrip() {
     +++++++ side #1
     line 1 left
     line 2 left
-    %%%%%%% diff from base to side #2
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #2
     -line 1
     +line 1 right
      line 2
     >>>>>>> conflict 1 of 2 ends
     line 3
     <<<<<<< conflict 2 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
      line 4
     -line 5
     +line 5 left
@@ -726,7 +740,8 @@ fn test_materialize_conflict_modify_delete() {
     <<<<<<< conflict 1 of 1
     +++++++ side #1
     modified
-    %%%%%%% diff from base to side #2
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #2
     -line 3
     >>>>>>> conflict 1 of 1 ends
     line 4
@@ -743,7 +758,8 @@ fn test_materialize_conflict_modify_delete() {
     line 1
     line 2
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 3
     +++++++ side #2
     modified
@@ -760,7 +776,8 @@ fn test_materialize_conflict_modify_delete() {
     );
     insta::assert_snapshot!(&materialize_conflict_string(store, path, &conflict, ConflictMarkerStyle::Diff), @r"
     <<<<<<< conflict 1 of 1
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
      line 1
      line 2
     -line 3
@@ -816,12 +833,15 @@ fn test_materialize_conflict_two_forward_diffs() {
     <<<<<<< conflict 1 of 1
     +++++++ side #1
     A
-    %%%%%%% diff from base #1 to side #2
+    %%%%%%% diff from: base #1
+    \\\\\\\        to: side #2
      B
-    %%%%%%% diff from base #2 to side #3
+    %%%%%%% diff from: base #2
+    \\\\\\\        to: side #3
     -C
     +D
-    %%%%%%% diff from base #3 to side #4
+    %%%%%%% diff from: base #3
+    \\\\\\\        to: side #4
     -E
     +C
     >>>>>>> conflict 1 of 1 ends
@@ -1859,15 +1879,17 @@ fn test_update_conflict_from_content_simplified_conflict() {
         materialized,
         @r"
     <<<<<<< conflict 1 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 1
     +left 1
     +++++++ side #2
     right 1
     >>>>>>> conflict 1 of 2 ends
     line 2
     <<<<<<< conflict 2 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 3
     +left 3
     +++++++ side #2
@@ -2104,7 +2126,8 @@ fn test_update_conflict_from_content_no_eol() {
         @r"
     line 1
     <<<<<<< conflict 1 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 2
     +line 2 left
     +++++++ side #2
@@ -2189,11 +2212,11 @@ fn test_update_conflict_from_content_no_eol() {
     <<<<<<< side #1
     base
     left
-    ||||||| base
+    ||||||| base (no terminating newline)
     base
     =======
     right
-    >>>>>>> side #2
+    >>>>>>> side #2 (no terminating newline)
     "
     );
     assert_eq!(
@@ -2265,7 +2288,8 @@ fn test_update_conflict_from_content_no_eol_in_diff_hunk() {
      no newline
     -line 1
     +line 2
-    %%%%%%% diff from base #4 to side #5
+    %%%%%%% diff from: base #4
+    \\\\\\\        to: side #5
      with newline
     -line 1
     +line 2
@@ -2386,15 +2410,17 @@ fn test_update_from_content_malformed_conflict() {
     insta::assert_snapshot!(materialized, @r"
     line 1
     <<<<<<< conflict 1 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 2
     +line 2 left
     +++++++ side #2
     line 2 right
     >>>>>>> conflict 1 of 2 ends
     line 3
     <<<<<<< conflict 2 of 2
-    %%%%%%% diff from base to side #1
+    %%%%%%% diff from: base
+    \\\\\\\        to: side #1
     -line 4
     +line 4 left
     +++++++ side #2
EOF_114329324912

# Set environment variables for test execution
export RUST_BACKTRACE=1
export CARGO_TERM_COLOR=always
export CARGO_INCREMENTAL=0

# Run the specific test files using cargo test with the correct runner target
# For cli/tests/test_evolog_command.rs: use --package jj-cli --test runner test_evolog_command
# For lib/tests/test_conflicts.rs: use --package jj-lib --test runner test_conflicts
# Using --test-threads=1 to ensure single-threaded execution for stability
# Using --nocapture to show test output

# Run cli test
cargo test --package jj-cli --test runner test_evolog_command -- --nocapture --test-threads=1
cli_rc=$?

# Run lib test
cargo test --package jj-lib --test runner test_conflicts -- --nocapture --test-threads=1
lib_rc=$?

# Combine exit codes - if either test fails, the overall result should be failure
if [ $cli_rc -ne 0 ] || [ $lib_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 7f47753c3c99fc991727cc3ef775f8008b630f2b "cli/tests/test_evolog_command.rs" "lib/tests/test_conflicts.rs"