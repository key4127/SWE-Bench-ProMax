#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target snapshot files to ensure clean state
git checkout 5a116e48c3dff2a52526258951785ff627d8fea2 \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap" \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap" \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__show_source.snap"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap b/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap
--- a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap
+++ b/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap
@@ -1,30 +1,10 @@
 ---
 source: crates/ruff_linter/src/message/grouped.rs
 expression: content
-snapshot_kind: text
 ---
 fib.py:
   1:8 F401 `os` imported but unused
-    |
-  1 | import os
-    |        ^^ F401
-    |
-    = help: Remove unused import: `os`
-  
   6:5 F841 Local variable `x` is assigned to but never used
-    |
-  4 | def fibonacci(n):
-  5 |     """Compute the nth number in the Fibonacci sequence."""
-  6 |     x = 1
-    |     ^ F841
-  7 |     if n == 0:
-  8 |         return 0
-    |
-    = help: Remove assignment to unused variable `x`
-  
+
 undef.py:
   1:4 F821 Undefined name `a`
-    |
-  1 | if a == 1: pass
-    |    ^ F821
-    |
diff --git a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap b/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap
--- a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap
+++ b/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap
@@ -1,30 +1,10 @@
 ---
 source: crates/ruff_linter/src/message/grouped.rs
 expression: content
-snapshot_kind: text
 ---
 fib.py:
   1:8 F401 [*] `os` imported but unused
-    |
-  1 | import os
-    |        ^^ F401
-    |
-    = help: Remove unused import: `os`
-  
   6:5 F841 [*] Local variable `x` is assigned to but never used
-    |
-  4 | def fibonacci(n):
-  5 |     """Compute the nth number in the Fibonacci sequence."""
-  6 |     x = 1
-    |     ^ F841
-  7 |     if n == 0:
-  8 |         return 0
-    |
-    = help: Remove assignment to unused variable `x`
-  
+
 undef.py:
   1:4 F821 Undefined name `a`
-    |
-  1 | if a == 1: pass
-    |    ^ F821
-    |
diff --git a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__show_source.snap b/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__show_source.snap
deleted file mode 100644
--- a/crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__show_source.snap
+++ /dev/null
@@ -1,30 +0,0 @@
----
-source: crates/ruff_linter/src/message/grouped.rs
-expression: content
-snapshot_kind: text
----
-fib.py:
-  1:8 F401 `os` imported but unused
-    |
-  1 | import os
-    |        ^^ F401
-    |
-    = help: Remove unused import: `os`
-  
-  6:5 F841 Local variable `x` is assigned to but never used
-    |
-  4 | def fibonacci(n):
-  5 |     """Compute the nth number in the Fibonacci sequence."""
-  6 |     x = 1
-    |     ^ F841
-  7 |     if n == 0:
-  8 |         return 0
-    |
-    = help: Remove assignment to unused variable `x`
-  
-undef.py:
-  1:4 F821 Undefined name `a`
-    |
-  1 | if a == 1: pass
-    |    ^ F821
-    |
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Run the specific message::grouped tests
# Using the most specific test pattern to target only the grouped tests
cargo test --package ruff_linter --lib message::grouped::tests -- --nocapture

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original snapshot files
git checkout 5a116e48c3dff2a52526258951785ff627d8fea2 \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status.snap" \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__fix_status_unsafe.snap" \
    "crates/ruff_linter/src/message/snapshots/ruff_linter__message__grouped__tests__show_source.snap"