#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 7dcf01f12700ff21529348879bfd12df034013ee "rustfs/src/server/console_test.rs"

# Apply the test patch (this moves the file from server/ to admin/)
git apply -v - <<'EOF_114329324912'
diff --git a/rustfs/src/server/console_test.rs b/rustfs/src/admin/console_test.rs
rename from rustfs/src/server/console_test.rs
rename to rustfs/src/admin/console_test.rs
--- a/rustfs/src/server/console_test.rs
+++ b/rustfs/src/admin/console_test.rs
@@ -15,42 +15,12 @@
 #[cfg(test)]
 mod tests {
     use crate::config::Opt;
-    use crate::server::start_console_server;
     use clap::Parser;
-    use tokio::time::{Duration, timeout};
-
-    #[tokio::test]
-    async fn test_console_server_can_start_and_stop() {
-        // Test that console server can be started and shut down gracefully
-        let args = vec!["rustfs", "/tmp/test", "--console-address", ":0"]; // Use port 0 for auto-assignment
-        let opt = Opt::parse_from(args);
-
-        let (tx, rx) = tokio::sync::broadcast::channel(1);
-
-        // Start console server in a background task
-        let handle = tokio::spawn(async move { start_console_server(&opt, rx).await });
-
-        // Give it a moment to start
-        tokio::time::sleep(Duration::from_millis(100)).await;
-
-        // Send shutdown signal
-        let _ = tx.send(());
-
-        // Wait for server to shut down
-        let result = timeout(Duration::from_secs(5), handle).await;
-
-        assert!(result.is_ok(), "Console server should shutdown gracefully");
-        let server_result = result.unwrap();
-        assert!(server_result.is_ok(), "Console server should not have errors");
-        let final_result = server_result.unwrap();
-        assert!(final_result.is_ok(), "Console server should complete successfully");
-    }
 
     #[tokio::test]
     async fn test_console_cors_configuration() {
         // Test CORS configuration parsing
-        use crate::server::console::parse_cors_origins;
-
+        use crate::admin::console::parse_cors_origins;
         // Test wildcard origin
         let cors_wildcard = Some("*".to_string());
         let _layer1 = parse_cors_origins(cors_wildcard.as_ref());
EOF_114329324912

# Set Rust environment variables for better debugging
export RUST_BACKTRACE=1
export RUST_LOG=warn
export CARGO_TERM_COLOR=always
export CARGO_HOME=/usr/local/cargo
export RUSTUP_HOME=/usr/local/rustup

# Ensure protocol buffer code is generated (critical prebuild step)
cargo run --bin gproto || true

# Run the specific test from the admin::console_test module (updated path after patch)
# The patch moves the file to rustfs/src/admin/console_test.rs, so we use admin::console_test
# Try multiple approaches in order of preference
cargo test --package rustfs admin::console_test -- --nocapture --test-threads=1

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 7dcf01f12700ff21529348879bfd12df034013ee "rustfs/src/server/console_test.rs"

# Exit with the captured return code
exit $rc