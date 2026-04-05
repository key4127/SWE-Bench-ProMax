#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout b26aad4129a2d550109dcf23e7c41750c9d97781 "crates/audit/tests/integration_test.rs" "crates/audit/tests/performance_test.rs" "crates/audit/tests/system_integration_test.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/audit/tests/integration_test.rs b/crates/audit/tests/integration_test.rs
--- a/crates/audit/tests/integration_test.rs
+++ b/crates/audit/tests/integration_test.rs
@@ -52,7 +52,7 @@ async fn test_config_parsing_webhook() {
     // We expect this to fail due to server storage not being initialized
     // but the parsing should work correctly
     match result {
-        Err(AuditError::ServerNotInitialized(_)) => {
+        Err(AuditError::StorageNotAvailable(_)) => {
             // This is expected in test environment
         }
         Err(e) => {
diff --git a/crates/audit/tests/performance_test.rs b/crates/audit/tests/performance_test.rs
--- a/crates/audit/tests/performance_test.rs
+++ b/crates/audit/tests/performance_test.rs
@@ -73,7 +73,7 @@ async fn test_concurrent_target_creation() {
 
     // Verify it fails with expected error (server not initialized)
     match result {
-        Err(AuditError::ServerNotInitialized(_)) => {
+        Err(AuditError::StorageNotAvailable(_)) => {
             // Expected in test environment
         }
         Err(e) => {
@@ -103,17 +103,17 @@ async fn test_audit_log_dispatch_performance() {
     use std::collections::HashMap;
     let id = 1;
 
-    let mut req_header = HashMap::new();
+    let mut req_header = hashbrown::HashMap::new();
     req_header.insert("authorization".to_string(), format!("Bearer test-token-{id}"));
     req_header.insert("content-type".to_string(), "application/octet-stream".to_string());
 
-    let mut resp_header = HashMap::new();
+    let mut resp_header = hashbrown::HashMap::new();
     resp_header.insert("x-response".to_string(), "ok".to_string());
 
-    let mut tags = HashMap::new();
+    let mut tags = hashbrown::HashMap::new();
     tags.insert(format!("tag-{id}"), json!("sample"));
 
-    let mut req_query = HashMap::new();
+    let mut req_query = hashbrown::HashMap::new();
     req_query.insert("id".to_string(), id.to_string());
 
     let api_details = ApiDetails {
diff --git a/crates/audit/tests/system_integration_test.rs b/crates/audit/tests/system_integration_test.rs
--- a/crates/audit/tests/system_integration_test.rs
+++ b/crates/audit/tests/system_integration_test.rs
@@ -35,7 +35,7 @@ async fn test_complete_audit_system_lifecycle() {
 
     // Should fail in test environment but state handling should work
     match start_result {
-        Err(AuditError::ServerNotInitialized(_)) => {
+        Err(AuditError::StorageNotAvailable(_)) => {
             // Expected in test environment
             assert_eq!(system.get_state().await, system::AuditSystemState::Stopped);
         }
@@ -168,7 +168,7 @@ async fn test_config_parsing_with_multiple_instances() {
 
     // Should fail due to server storage not initialized, but parsing should work
     match result {
-        Err(AuditError::ServerNotInitialized(_)) => {
+        Err(AuditError::StorageNotAvailable(_)) => {
             // Expected - parsing worked but save failed
         }
         Err(e) => {
@@ -182,48 +182,6 @@ async fn test_config_parsing_with_multiple_instances() {
     }
 }
 
-// #[tokio::test]
-// async fn test_environment_variable_precedence() {
-//     // Test that environment variables override config file settings
-//     // This test validates the ENV > file instance > file default precedence
-//     // Set some test environment variables
-//     std::env::set_var("RUSTFS_AUDIT_WEBHOOK_ENABLE_TEST", "on");
-//     std::env::set_var("RUSTFS_AUDIT_WEBHOOK_ENDPOINT_TEST", "http://env.example.com/audit");
-//     std::env::set_var("RUSTFS_AUDIT_WEBHOOK_AUTH_TOKEN_TEST", "env-token");
-//     let mut registry = AuditRegistry::new();
-//
-//     // Create config that should be overridden by env vars
-//     let mut config = Config(HashMap::new());
-//     let mut webhook_section = HashMap::new();
-//
-//     let mut test_kvs = KVS::new();
-//     test_kvs.insert("enable".to_string(), "off".to_string()); // Should be overridden
-//     test_kvs.insert("endpoint".to_string(), "http://file.example.com/audit".to_string()); // Should be overridden
-//     test_kvs.insert("batch_size".to_string(), "10".to_string()); // Should remain from file
-//     webhook_section.insert("test".to_string(), test_kvs);
-//
-//     config.0.insert("audit_webhook".to_string(), webhook_section);
-//
-//     // Try to create targets - should use env vars for endpoint/enable, file for batch_size
-//     let result = registry.create_targets_from_config(&config).await;
-//     // Clean up env vars
-//     std::env::remove_var("RUSTFS_AUDIT_WEBHOOK_ENABLE_TEST");
-//     std::env::remove_var("RUSTFS_AUDIT_WEBHOOK_ENDPOINT_TEST");
-//     std::env::remove_var("RUSTFS_AUDIT_WEBHOOK_AUTH_TOKEN_TEST");
-//     // Should fail due to server storage, but precedence logic should work
-//     match result {
-//         Err(AuditError::ServerNotInitialized(_)) => {
-//             // Expected - precedence parsing worked but save failed
-//         }
-//         Err(e) => {
-//             println!("Environment precedence test error: {}", e);
-//         }
-//         Ok(_) => {
-//             println!("Unexpected success in environment precedence test");
-//         }
-//     }
-// }
-
 #[test]
 fn test_target_type_validation() {
     use rustfs_targets::target::TargetType;
@@ -315,19 +273,18 @@ fn create_sample_audit_entry_with_id(id: u32) -> AuditEntry {
     use chrono::Utc;
     use rustfs_targets::EventName;
     use serde_json::json;
-    use std::collections::HashMap;
 
-    let mut req_header = HashMap::new();
+    let mut req_header = hashbrown::HashMap::new();
     req_header.insert("authorization".to_string(), format!("Bearer test-token-{id}"));
     req_header.insert("content-type".to_string(), "application/octet-stream".to_string());
 
-    let mut resp_header = HashMap::new();
+    let mut resp_header = hashbrown::HashMap::new();
     resp_header.insert("x-response".to_string(), "ok".to_string());
 
-    let mut tags = HashMap::new();
+    let mut tags = hashbrown::HashMap::new();
     tags.insert(format!("tag-{id}"), json!("sample"));
 
-    let mut req_query = HashMap::new();
+    let mut req_query = hashbrown::HashMap::new();
     req_query.insert("id".to_string(), id.to_string());
 
     let api_details = ApiDetails {
EOF_114329324912

# Ensure protocol buffer code is generated (critical prebuild step)
cargo run --bin gproto

# Run all target tests in a single command for efficiency
# Using --test-threads=1 to control parallelism in the virtualized environment
# Using --nocapture for better output visibility
cargo test --package rustfs-audit --test integration_test --test performance_test --test system_integration_test -- --nocapture --test-threads=1

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout b26aad4129a2d550109dcf23e7c41750c9d97781 "crates/audit/tests/integration_test.rs" "crates/audit/tests/performance_test.rs" "crates/audit/tests/system_integration_test.rs"