#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 1b48934f477653d8b6573a97420e9024d204ee73 "crates/e2e_test/src/reliant/lock.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/e2e_test/src/reliant/lock.rs b/crates/e2e_test/src/reliant/lock.rs
--- a/crates/e2e_test/src/reliant/lock.rs
+++ b/crates/e2e_test/src/reliant/lock.rs
@@ -13,12 +13,7 @@
 // See the License for the specific language governing permissions and
 // limitations under the License.
 
-use rustfs_lock::{
-    drwmutex::Options,
-    lock_args::LockArgs,
-    namespace_lock::{NsLockMap, new_nslock},
-    new_lock_api,
-};
+use rustfs_lock::{lock_args::LockArgs, namespace::NsLockMap};
 use rustfs_protos::{node_service_time_out_client, proto_gen::node_service::GenerallyLockRequest};
 use std::{error::Error, sync::Arc, time::Duration};
 use tokio::sync::RwLock;
@@ -62,27 +57,13 @@ async fn test_lock_unlock_rpc() -> Result<(), Box<dyn Error>> {
 #[ignore = "requires running RustFS server at localhost:9000"]
 async fn test_lock_unlock_ns_lock() -> Result<(), Box<dyn Error>> {
     let url = url::Url::parse("http://127.0.0.1:9000/data")?;
-    let locker = new_lock_api(false, Some(url));
-    let ns_mutex = Arc::new(RwLock::new(NsLockMap::new(true)));
-    let ns = new_nslock(
-        Arc::clone(&ns_mutex),
-        "local".to_string(),
-        "dandan".to_string(),
-        vec!["foo".to_string()],
-        vec![locker],
-    )
-    .await;
-    assert!(
-        ns.0.write()
-            .await
-            .get_lock(&Options {
-                timeout: Duration::from_secs(5),
-                retry_interval: Duration::from_secs(1),
-            })
-            .await
-            .unwrap()
-    );
+    let ns_mutex = Arc::new(RwLock::new(NsLockMap::new(true, None)));
+    let ns_lock = ns_mutex.read().await.new_nslock(Some(url)).await?;
 
-    ns.0.write().await.un_lock().await.unwrap();
+    let resources = vec!["foo".to_string()];
+    let result = ns_lock.lock_batch(&resources, "dandan", Duration::from_secs(5)).await?;
+    assert!(result);
+
+    ns_lock.unlock_batch(&resources, "dandan").await?;
     Ok(())
 }
EOF_114329324912

# Ensure protocol buffer code is generated (critical prebuild step)
cargo run --bin gproto

# Start the RustFS server in the background (required for e2e tests)
# The server binary was already built during Docker image creation
/testbed/target/release/rustfs &
SERVER_PID=$!

# Wait for server to be ready by checking health endpoint
echo "Waiting for RustFS server to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:9000/health > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    echo "Waiting for server... attempt $i/30"
    sleep 2
done

# Verify server is actually responding
if ! curl -s http://localhost:9000/health > /dev/null 2>&1; then
    echo "ERROR: Server failed to start properly"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Run the target test with --ignored flag (required for e2e tests)
# Using --test-threads=1 to control parallelism in the virtualized environment
cargo test --package e2e_test --lib reliant::lock -- --ignored --nocapture --test-threads=1

# Capture the exit code
rc=$?

# Stop the server
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 1b48934f477653d8b6573a97420e9024d204ee73 "crates/e2e_test/src/reliant/lock.rs"