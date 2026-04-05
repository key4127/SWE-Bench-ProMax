#!/bin/bash
set -uxo pipefail
cd /testbed

# Activate Rust environment
source /root/.cargo/env

# Restore original test files to ensure clean state
git checkout 62cc8a4b8d17741143b859af8cd159745646c2dc \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap" \
    "codex-rs/tui/src/chatwidget/tests.rs"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap
--- a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap
+++ b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap
@@ -2,15 +2,15 @@
 source: tui/src/chatwidget/tests.rs
 expression: terminal.backend().vt100().screen().contents()
 ---
-  Allow command?
+  Would you like to run the following command?
 
-  this is a test reason such as one that would be produced by the model
+  Reason: this is a test reason such as one that would be produced by the
+  model
 
   $ echo hello world
 
-› 1. Approve and run now          Run this command one time
-  2. Always approve this session  Automatically approve this command for the
-                                  rest of the session
-  3. Cancel                       Do not run the command
+› 1. Yes, proceed
+  2. Yes, and don't ask again for this command
+  3. No, and tell Codex what to do differently esc
 
   Press enter to confirm or esc to cancel
diff --git a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap
--- a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap
+++ b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap
@@ -1,17 +1,13 @@
 ---
 source: tui/src/chatwidget/tests.rs
-expression: terminal.backend()
+expression: terminal.backend().vt100().screen().contents()
 ---
-"                                                                                "
-"                                                                                "
-"  Allow command?                                                                "
-"                                                                                "
-"  $ echo hello world                                                            "
-"                                                                                "
-"› 1. Approve and run now          Run this command one time                     "
-"  2. Always approve this session  Automatically approve this command for the    "
-"                                  rest of the session                           "
-"  3. Cancel                       Do not run the command                        "
-"                                                                                "
-"  Press enter to confirm or esc to cancel                                       "
-"                                                                                "
+  Would you like to run the following command?
+
+  $ echo hello world
+
+› 1. Yes, proceed
+  2. Yes, and don't ask again for this command
+  3. No, and tell Codex what to do differently esc
+
+  Press enter to confirm or esc to cancel
diff --git a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap
--- a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap
+++ b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap
@@ -1,19 +1,17 @@
 ---
 source: tui/src/chatwidget/tests.rs
-expression: terminal.backend()
+expression: terminal.backend().vt100().screen().contents()
 ---
-"                                                                                "
-"                                                                                "
-"  Apply changes?                                                                "
-"                                                                                "
-"  README.md (+2 -0)                                                             "
-"      1     +hello                                                              "
-"      2     +world                                                              "
-"                                                                                "
-"  The model wants to apply changes                                              "
-"                                                                                "
-"› 1. Approve  Apply the proposed changes                                        "
-"  2. Cancel   Do not apply the changes                                          "
-"                                                                                "
-"  Press enter to confirm or esc to cancel                                       "
-"                                                                                "
+  Would you like to make the following edits?
+
+  README.md (+2 -0)
+
+      1     +hello
+      2     +world
+
+  The model wants to apply changes
+
+› 1. Yes, proceed
+  2. No, and tell Codex what to do differently esc
+
+  Press enter to confirm or esc to cancel
diff --git a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap
--- a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap
+++ b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap
@@ -7,35 +7,32 @@ Buffer {
     content: [
         "                                                                                ",
         "                                                                                ",
-        "  Allow command?                                                                ",
+        "  Would you like to run the following command?                                  ",
         "                                                                                ",
-        "  this is a test reason such as one that would be produced by the model         ",
+        "  Reason: this is a test reason such as one that would be produced by the       ",
+        "  model                                                                         ",
         "                                                                                ",
         "  $ echo hello world                                                            ",
         "                                                                                ",
-        "› 1. Approve and run now          Run this command one time                     ",
-        "  2. Always approve this session  Automatically approve this command for the    ",
-        "                                  rest of the session                           ",
-        "  3. Cancel                       Do not run the command                        ",
+        "› 1. Yes, proceed                                                               ",
+        "  2. Yes, and don't ask again for this command                                  ",
+        "  3. No, and tell Codex what to do differently esc                              ",
         "                                                                                ",
         "  Press enter to confirm or esc to cancel                                       ",
         "                                                                                ",
     ],
     styles: [
         x: 0, y: 0, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
         x: 2, y: 2, fg: Reset, bg: Reset, underline: Reset, modifier: BOLD,
-        x: 16, y: 2, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
-        x: 2, y: 4, fg: Reset, bg: Reset, underline: Reset, modifier: ITALIC,
-        x: 71, y: 4, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
-        x: 0, y: 8, fg: Cyan, bg: Reset, underline: Reset, modifier: BOLD,
-        x: 34, y: 8, fg: Cyan, bg: Reset, underline: Reset, modifier: BOLD | DIM,
-        x: 59, y: 8, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
-        x: 34, y: 9, fg: Reset, bg: Reset, underline: Reset, modifier: DIM,
-        x: 76, y: 9, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
-        x: 34, y: 10, fg: Reset, bg: Reset, underline: Reset, modifier: DIM,
-        x: 53, y: 10, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
-        x: 34, y: 11, fg: Reset, bg: Reset, underline: Reset, modifier: DIM,
-        x: 56, y: 11, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
+        x: 46, y: 2, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
+        x: 10, y: 4, fg: Reset, bg: Reset, underline: Reset, modifier: ITALIC,
+        x: 73, y: 4, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
+        x: 2, y: 5, fg: Reset, bg: Reset, underline: Reset, modifier: ITALIC,
+        x: 7, y: 5, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
+        x: 0, y: 9, fg: Cyan, bg: Reset, underline: Reset, modifier: BOLD,
+        x: 17, y: 9, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
+        x: 47, y: 11, fg: Reset, bg: Reset, underline: Reset, modifier: DIM,
+        x: 50, y: 11, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
         x: 2, y: 13, fg: Reset, bg: Reset, underline: Reset, modifier: DIM,
         x: 0, y: 14, fg: Reset, bg: Reset, underline: Reset, modifier: NONE,
     ]
diff --git a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap
--- a/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap
+++ b/codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap
@@ -4,16 +4,16 @@ expression: terminal.backend()
 ---
 "                                                                                "
 "                                                                                "
-"  Allow command?                                                                "
+"  Would you like to run the following command?                                  "
 "                                                                                "
-"  this is a test reason such as one that would be produced by the model         "
+"  Reason: this is a test reason such as one that would be produced by the       "
+"  model                                                                         "
 "                                                                                "
 "  $ echo 'hello world'                                                          "
 "                                                                                "
-"› 1. Approve and run now          Run this command one time                     "
-"  2. Always approve this session  Automatically approve this command for the    "
-"                                  rest of the session                           "
-"  3. Cancel                       Do not run the command                        "
+"› 1. Yes, proceed                                                               "
+"  2. Yes, and don't ask again for this command                                  "
+"  3. No, and tell Codex what to do differently esc                              "
 "                                                                                "
 "  Press enter to confirm or esc to cancel                                       "
 "                                                                                "
diff --git a/codex-rs/tui/src/chatwidget/tests.rs b/codex-rs/tui/src/chatwidget/tests.rs
--- a/codex-rs/tui/src/chatwidget/tests.rs
+++ b/codex-rs/tui/src/chatwidget/tests.rs
@@ -1236,6 +1236,14 @@ fn approval_modal_exec_snapshot() {
     terminal
         .draw(|f| f.render_widget_ref(&chat, f.area()))
         .expect("draw approval modal");
+    assert!(
+        terminal
+            .backend()
+            .vt100()
+            .screen()
+            .contents()
+            .contains("echo hello world")
+    );
     assert_snapshot!(
         "approval_modal_exec",
         terminal.backend().vt100().screen().contents()
@@ -1261,12 +1269,16 @@ fn approval_modal_exec_without_reason_snapshot() {
     });
 
     let height = chat.desired_height(80);
-    let mut terminal = ratatui::Terminal::new(ratatui::backend::TestBackend::new(80, height))
-        .expect("create terminal");
+    let mut terminal =
+        ratatui::Terminal::new(VT100Backend::new(80, height)).expect("create terminal");
+    terminal.set_viewport_area(Rect::new(0, 0, 80, height));
     terminal
         .draw(|f| f.render_widget_ref(&chat, f.area()))
         .expect("draw approval modal (no reason)");
-    assert_snapshot!("approval_modal_exec_no_reason", terminal.backend());
+    assert_snapshot!(
+        "approval_modal_exec_no_reason",
+        terminal.backend().vt100().screen().contents()
+    );
 }
 
 // Snapshot test: patch approval modal
@@ -1296,12 +1308,16 @@ fn approval_modal_patch_snapshot() {
 
     // Render at the widget's desired height and snapshot.
     let height = chat.desired_height(80);
-    let mut terminal = ratatui::Terminal::new(ratatui::backend::TestBackend::new(80, height))
-        .expect("create terminal");
+    let mut terminal =
+        ratatui::Terminal::new(VT100Backend::new(80, height)).expect("create terminal");
+    terminal.set_viewport_area(Rect::new(0, 0, 80, height));
     terminal
         .draw(|f| f.render_widget_ref(&chat, f.area()))
         .expect("draw patch approval modal");
-    assert_snapshot!("approval_modal_patch", terminal.backend());
+    assert_snapshot!(
+        "approval_modal_patch",
+        terminal.backend().vt100().screen().contents()
+    );
 }
 
 #[test]
@@ -1831,14 +1847,14 @@ fn apply_patch_untrusted_shows_approval_modal() {
         for x in 0..area.width {
             row.push(buf[(x, y)].symbol().chars().next().unwrap_or(' '));
         }
-        if row.contains("Apply changes?") {
+        if row.contains("Would you like to make the following edits?") {
             contains_title = true;
             break;
         }
     }
     assert!(
         contains_title,
-        "expected approval modal to be visible with title 'Apply changes?'"
+        "expected approval modal to be visible with title 'Would you like to make the following edits?'"
     );
 }
 
EOF_114329324912

# Run chatwidget tests using cargo test with vt100-tests feature
cd codex-rs
cargo test --features vt100-tests --package codex-tui -- --test-threads=1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout 62cc8a4b8d17741143b859af8cd159745646c2dc \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_exec_no_reason.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__approval_modal_patch.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__exec_approval_modal_exec.snap" \
    "codex-rs/tui/src/chatwidget/snapshots/codex_tui__chatwidget__tests__status_widget_and_approval_modal.snap" \
    "codex-rs/tui/src/chatwidget/tests.rs"