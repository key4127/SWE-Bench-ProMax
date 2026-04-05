#!/bin/bash
set -uxo pipefail

# Ensure we're in the testbed directory
cd /testbed

# Ensure Rust environment is available
source $HOME/.cargo/env

# Checkout the target test file to ensure clean state
git checkout 35cbab476ebfc271909777029f56f666b29d76a2 "src/tests/window_opening.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/tests/window_opening.rs b/src/tests/window_opening.rs
--- a/src/tests/window_opening.rs
+++ b/src/tests/window_opening.rs
@@ -65,6 +65,7 @@ fn simple() {
 }
 
 #[test]
+#[should_panic(expected = "Protocol error 3 on object xdg_surface")]
 fn dont_ack_initial_configure() {
     let mut f = Fixture::new();
     f.add_output(1, (1920, 1080));
@@ -80,19 +81,6 @@ fn dont_ack_initial_configure() {
     // Don't ack the configure.
     window.commit();
     f.double_roundtrip(id);
-
-    // FIXME: Technically this is a protocol violation but uh. Smithay currently doesn't check it,
-    // and I'm not sure if it can be done generically in Smithay (because a compositor may not use
-    // its rendering helpers). I might add a check in niri itself sometime; I'm just not sure if
-    // there might be clients that this could break.
-    let window = f.client(id).window(&surface);
-    assert_snapshot!(
-        window.format_recent_configures(),
-        @r"
-    size: 936 × 1048, bounds: 1888 × 1048, states: []
-    size: 936 × 1048, bounds: 1888 × 1048, states: [Activated]
-    "
-    );
 }
 
 #[derive(Clone, Copy)]
EOF_114329324912

# Run the specific test file
# Using --lib flag to run library tests and specifying the test module name
# The --nocapture flag ensures test output is visible
# Running single-threaded to avoid issues in virtualized environment
cargo test --lib window_opening -- --nocapture --test-threads=1

# Capture exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 35cbab476ebfc271909777029f56f666b29d76a2 "src/tests/window_opening.rs"