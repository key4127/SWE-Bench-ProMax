#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 827456f977c3ab81fd419bafd490d502413c336d "crates/ty_server/tests/e2e/initialize.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ty_server/tests/e2e/initialize.rs b/crates/ty_server/tests/e2e/initialize.rs
--- a/crates/ty_server/tests/e2e/initialize.rs
+++ b/crates/ty_server/tests/e2e/initialize.rs
@@ -508,3 +508,53 @@ fn not_register_rename_capability_when_disabled() -> Result<()> {
 
     Ok(())
 }
+
+/// Tests that the server can register multiple capabilities at once.
+///
+/// This test would need to be updated when the server supports additional capabilities in the
+/// future.
+#[test]
+fn register_multiple_capabilities() -> Result<()> {
+    let workspace_root = SystemPath::new("foo");
+    let mut server = TestServerBuilder::new()?
+        .with_workspace(workspace_root, None)?
+        .with_initialization_options(
+            ClientOptions::default()
+                .with_experimental_rename(true)
+                .with_diagnostic_mode(DiagnosticMode::Workspace),
+        )
+        .enable_rename_dynamic_registration(true)
+        .enable_diagnostic_dynamic_registration(true)
+        .build()?
+        .wait_until_workspaces_are_initialized()?;
+
+    let (_, params) = server.await_request::<RegisterCapability>()?;
+    let registrations = params.registrations;
+
+    assert_eq!(registrations.len(), 2);
+
+    insta::assert_json_snapshot!(registrations, @r#"
+    [
+      {
+        "id": "ty/textDocument/diagnostic",
+        "method": "textDocument/diagnostic",
+        "registerOptions": {
+          "documentSelector": null,
+          "identifier": "ty",
+          "interFileDependencies": true,
+          "workDoneProgress": true,
+          "workspaceDiagnostics": true
+        }
+      },
+      {
+        "id": "ty/textDocument/rename",
+        "method": "textDocument/rename",
+        "registerOptions": {
+          "prepareProvider": true
+        }
+      }
+    ]
+    "#);
+
+    Ok(())
+}
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Run the specific ty_server e2e test for initialize
# Using --test e2e to run the e2e test binary (the correct test target)
# Filtering for 'initialize' to run only tests from initialize.rs
# Using --nocapture to show test output
cargo test --package ty_server --test e2e initialize -- --nocapture --test-threads=1

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 827456f977c3ab81fd419bafd490d502413c336d "crates/ty_server/tests/e2e/initialize.rs"

# Exit with the test result code
exit $rc