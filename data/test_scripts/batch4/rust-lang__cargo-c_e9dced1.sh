#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout original test files
git checkout ce58ead133ede5464269c5e2507eef4d56ac0451 "tests/testsuite/bad_config.rs" "tests/testsuite/config.rs"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/testsuite/bad_config.rs b/tests/testsuite/bad_config.rs
--- a/tests/testsuite/bad_config.rs
+++ b/tests/testsuite/bad_config.rs
@@ -159,7 +159,10 @@ fn invalid_global_config() {
     p.cargo("check -v")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] could not load Cargo configuration
+[ERROR] failed to parse manifest at `[ROOT]/foo/Cargo.toml`
+
+Caused by:
+  could not load Cargo configuration
 
 Caused by:
   could not parse TOML configuration in `[ROOT]/foo/.cargo/config.toml`
diff --git a/tests/testsuite/config.rs b/tests/testsuite/config.rs
--- a/tests/testsuite/config.rs
+++ b/tests/testsuite/config.rs
@@ -1649,7 +1649,19 @@ target-dir = ''
 
 #[cargo_test]
 fn cargo_target_empty_env() {
-    let project = project().build();
+    let project = project()
+        .file(
+            "Cargo.toml",
+            r#"
+                [package]
+                name = "foo"
+                authors = []
+                version = "0.0.0"
+                build = "build.rs"
+            "#,
+        )
+        .file("src/lib.rs", "")
+        .build();
 
     project.cargo("check")
         .env("CARGO_TARGET_DIR", "")
EOF_114329324912

# Ensure environment variables are set
export CARGO_PROFILE_DEV_DEBUG=1
export CARGO_PROFILE_TEST_DEBUG=1
export CARGO_INCREMENTAL=0
export RUST_BACKTRACE=1
export CFG_DISABLE_CROSS_TESTS=1

# Run the target tests - combining both test modules in a single command for efficiency
# Using -- to pass test filter arguments to the test binary
cargo test --test testsuite -- bad_config config --nocapture
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout ce58ead133ede5464269c5e2507eef4d56ac0451 "tests/testsuite/bad_config.rs" "tests/testsuite/config.rs"