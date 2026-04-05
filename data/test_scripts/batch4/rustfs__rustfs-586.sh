#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ef0dbaaeb537646ee1f287522b5dd75ab1a08075 "crates/ahm/tests/integration_tests.rs" "crates/ahm/tests/lifecycle_integration_test.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ahm/tests/integration_tests.rs b/crates/ahm/tests/integration_tests.rs
--- a/crates/ahm/tests/integration_tests.rs
+++ b/crates/ahm/tests/integration_tests.rs
@@ -195,6 +195,7 @@ async fn test_distributed_stats_aggregation() {
         total_buckets: 5,
         last_update: std::time::SystemTime::now(),
         scan_progress: Default::default(),
+        data_usage: rustfs_common::data_usage::DataUsageInfo::default(),
     };
 
     aggregator.set_local_stats(local_stats).await;
diff --git a/crates/ahm/tests/lifecycle_integration_test.rs b/crates/ahm/tests/lifecycle_integration_test.rs
--- a/crates/ahm/tests/lifecycle_integration_test.rs
+++ b/crates/ahm/tests/lifecycle_integration_test.rs
@@ -271,7 +271,10 @@ async fn create_test_tier() {
 
 /// Test helper: Check if object exists
 async fn object_exists(ecstore: &Arc<ECStore>, bucket: &str, object: &str) -> bool {
-    ((**ecstore).get_object_info(bucket, object, &ObjectOptions::default()).await).is_ok()
+    match (**ecstore).get_object_info(bucket, object, &ObjectOptions::default()).await {
+        Ok(info) => !info.delete_marker,
+        Err(_) => false,
+    }
 }
 
 /// Test helper: Check if object exists
EOF_114329324912

# Ensure protocol buffer code is generated (critical prebuild step)
cargo run --bin gproto || true

# Set environment variables for test execution
export CARGO_TERM_COLOR=always
export RUST_BACKTRACE=1
export RUST_LOG=warn

# Run the specific integration tests using cargo nextest (preferred test runner)
# Tests must run serially due to #[serial] attribute and port 9002 usage
# Using --test-threads=1 to ensure serial execution
cargo nextest run -p rustfs-ahm --test integration_tests --test lifecycle_integration_test --no-fail-fast

# Capture the exit code
rc=$?

# If nextest fails or is not available, fallback to cargo test
if [ $rc -ne 0 ]; then
    cargo test -p rustfs-ahm --test integration_tests --test lifecycle_integration_test -- --nocapture --test-threads=1
    rc=$?
fi

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout ef0dbaaeb537646ee1f287522b5dd75ab1a08075 "crates/ahm/tests/integration_tests.rs" "crates/ahm/tests/lifecycle_integration_test.rs"