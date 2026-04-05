#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure we're on the correct commit
git checkout 389e627dc423207d15ae1f74057ef0ac04641f23

# Checkout the target test file to ensure it's in a clean state
git checkout 389e627dc423207d15ae1f74057ef0ac04641f23 "bindings/rust/aws-kms-tls-auth/src/test_utils.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/bindings/rust/aws-kms-tls-auth/src/test_utils.rs b/bindings/rust/aws-kms-tls-auth/src/test_utils.rs
--- a/bindings/rust/aws-kms-tls-auth/src/test_utils.rs
+++ b/bindings/rust/aws-kms-tls-auth/src/test_utils.rs
@@ -5,7 +5,8 @@ use crate::{
     epoch_schedule,
     psk_derivation::{EpochSecret, PskIdentity},
     psk_parser::retrieve_psk_identities,
-    DecodeValue,
+    receiver::PskReceiver,
+    DecodeValue, PskProvider,
 };
 use aws_lc_rs::hmac;
 use aws_sdk_kms::{operation::generate_mac::GenerateMacOutput, primitives::Blob, Client};
@@ -58,14 +59,15 @@ const MOCKED_EPOCH_COUNT: u64 = 100;
 ////////////////////////////////////////////////////////////////////////////////
 
 /// Mock the "generateMAC" operation for `key` on `message`.
-fn construct_rule(key: MockKmsKey, message: u64) -> Rule {
+fn construct_rule(key: MockKmsKey, epoch: u64) -> Rule {
+    let message = EpochSecret::construct_message(epoch);
     let mac = {
         let s_key = hmac::Key::new(hmac::HMAC_SHA384, key.material);
-        let tag = hmac::sign(&s_key, &message.to_be_bytes());
+        let tag = hmac::sign(&s_key, &message);
         tag.as_ref().to_vec()
     };
 
-    let message = Blob::new(message.to_be_bytes().to_vec());
+    let message = Blob::new(message);
     let mac = Blob::new(mac);
 
     mock!(Client::generate_mac)
@@ -119,6 +121,28 @@ pub fn configs_from_callbacks(
     (client_config, server_config)
 }
 
+pub fn make_client_config(psk_provider: PskProvider) -> s2n_tls::config::Config {
+    let mut client_config = s2n_tls::config::Builder::new();
+    client_config
+        .set_connection_initializer(psk_provider)
+        .unwrap();
+    client_config
+        .set_security_policy(&s2n_tls::security::DEFAULT_TLS13)
+        .unwrap();
+    client_config.build().unwrap()
+}
+
+pub fn make_server_config(psk_receiver: PskReceiver) -> s2n_tls::config::Config {
+    let mut server_config = s2n_tls::config::Builder::new();
+    server_config
+        .set_client_hello_callback(psk_receiver)
+        .unwrap();
+    server_config
+        .set_security_policy(&s2n_tls::security::DEFAULT_TLS13)
+        .unwrap();
+    server_config.build().unwrap()
+}
+
 /// Handshake two configs over localhost sockets, returning any errors encountered.
 ///
 /// If the connection is successful, the server's tcp stream is returned which can
EOF_114329324912

# Set environment variable to prevent mlock() failures in containers
export S2N_DONT_MLOCK=1

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Navigate to the Rust crate directory
cd /testbed/bindings/rust/aws-kms-tls-auth

# Run the target test with explicit single-threaded execution
echo "=== Running test_utils tests ==="
cargo test --lib test_utils -- --nocapture --test-threads=1
rc=$?

# Navigate back to testbed root
cd /testbed

# Restore the test file to its original state
git checkout 389e627dc423207d15ae1f74057ef0ac04641f23 "bindings/rust/aws-kms-tls-auth/src/test_utils.rs"

# Output test result
if [ $rc -eq 0 ]; then
    echo "=== test_utils tests PASSED ==="
else
    echo "=== test_utils tests FAILED ==="
fi

echo "OMNIGRIL_EXIT_CODE=$rc"