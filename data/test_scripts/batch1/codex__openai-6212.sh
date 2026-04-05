#!/bin/bash
set -uxo pipefail

# Navigate to the codex-rs working directory
cd /testbed/codex-rs

# Restore the original test file from the target commit
git checkout d40a6b7f73ed2714f9e869b19c764fc2eecb8b3f "app-server/tests/suite/rate_limits.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/codex-rs/app-server/tests/suite/rate_limits.rs b/codex-rs/app-server/tests/suite/rate_limits.rs
--- a/codex-rs/app-server/tests/suite/rate_limits.rs
+++ b/codex-rs/app-server/tests/suite/rate_limits.rs
@@ -7,10 +7,10 @@ use codex_app_server_protocol::GetAccountRateLimitsResponse;
 use codex_app_server_protocol::JSONRPCError;
 use codex_app_server_protocol::JSONRPCResponse;
 use codex_app_server_protocol::LoginApiKeyParams;
+use codex_app_server_protocol::RateLimitSnapshot;
+use codex_app_server_protocol::RateLimitWindow;
 use codex_app_server_protocol::RequestId;
 use codex_core::auth::AuthCredentialsStoreMode;
-use codex_protocol::protocol::RateLimitSnapshot;
-use codex_protocol::protocol::RateLimitWindow;
 use pretty_assertions::assert_eq;
 use serde_json::json;
 use std::path::Path;
@@ -143,13 +143,13 @@ async fn get_account_rate_limits_returns_snapshot() -> Result<()> {
     let expected = GetAccountRateLimitsResponse {
         rate_limits: RateLimitSnapshot {
             primary: Some(RateLimitWindow {
-                used_percent: 42.0,
-                window_minutes: Some(60),
+                used_percent: 42,
+                window_duration_mins: Some(60),
                 resets_at: Some(primary_reset_timestamp),
             }),
             secondary: Some(RateLimitWindow {
-                used_percent: 5.0,
-                window_minutes: Some(1440),
+                used_percent: 5,
+                window_duration_mins: Some(1440),
                 resets_at: Some(secondary_reset_timestamp),
             }),
         },
EOF_114329324912

# Execute all tests in the codex-app-server package
# This will run all tests including those in rate_limits.rs
cargo test -p codex-app-server -- --test-threads=1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout d40a6b7f73ed2714f9e869b19c764fc2eecb8b3f "app-server/tests/suite/rate_limits.rs"