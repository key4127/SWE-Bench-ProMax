#!/bin/bash
set -uxo pipefail

# Set up environment variables
export PATH=/root/.cargo/bin:$PATH
export CARGO_HOME=/root/.cargo
export RUSTUP_HOME=/root/.rustup
export CARGO_PROFILE_DEV_DEBUG=1
export CARGO_PROFILE_TEST_DEBUG=1
export CARGO_INCREMENTAL=0
export CARGO_PUBLIC_NETWORK_TESTS=1
export CARGO_CONTAINER_TESTS=1

cd /testbed

# Checkout the original files before applying the patch
git checkout a9e8aa2c65091b520519fd1065f41d156d45f9dd "src/bin/cargo/commands/test.rs" "tests/testsuite/build.rs" "tests/testsuite/member_errors.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/bin/cargo/commands/test.rs b/src/bin/cargo/commands/test.rs
--- a/src/bin/cargo/commands/test.rs
+++ b/src/bin/cargo/commands/test.rs
@@ -72,7 +72,7 @@ pub fn exec(gctx: &mut GlobalContext, args: &ArgMatches) -> CliResult {
     let ws = args.workspace(gctx)?;
 
     let mut compile_opts =
-        args.compile_options(gctx, CompileMode::Test, Some(&ws), ProfileChecking::Custom)?;
+        args.compile_options(gctx, UserIntent::Test, Some(&ws), ProfileChecking::Custom)?;
 
     compile_opts.build_config.requested_profile =
         args.get_profile_name("test", ProfileChecking::Custom)?;
@@ -95,7 +95,7 @@ pub fn exec(gctx: &mut GlobalContext, args: &ArgMatches) -> CliResult {
         if no_run {
             return Err(anyhow::format_err!("Can't skip running doc tests with --no-run").into());
         }
-        compile_opts.build_config.mode = CompileMode::Doctest;
+        compile_opts.build_config.intent = UserIntent::Doctest;
         compile_opts.filter = ops::CompileFilter::lib_only();
     } else if test_name.is_some() && !compile_opts.filter.is_specific() {
         // If arg `TESTNAME` is provided, assumed that the user knows what
diff --git a/tests/testsuite/build.rs b/tests/testsuite/build.rs
--- a/tests/testsuite/build.rs
+++ b/tests/testsuite/build.rs
@@ -5,12 +5,11 @@ use std::fs;
 use std::io::Read;
 use std::process::Stdio;
 
-use cargo::{
-    core::compiler::CompileMode,
-    core::{Shell, Workspace},
-    ops::CompileOptions,
-    GlobalContext,
-};
+use cargo::core::compiler::UserIntent;
+use cargo::core::Shell;
+use cargo::core::Workspace;
+use cargo::ops::CompileOptions;
+use cargo::GlobalContext;
 use cargo_test_support::compare::assert_e2e;
 use cargo_test_support::paths::root;
 use cargo_test_support::prelude::*;
@@ -665,7 +664,7 @@ fn cargo_compile_api_exposes_artifact_paths() {
     let shell = Shell::from_write(Box::new(Vec::new()));
     let gctx = GlobalContext::new(shell, env::current_dir().unwrap(), paths::home());
     let ws = Workspace::new(&p.root().join("Cargo.toml"), &gctx).unwrap();
-    let compile_options = CompileOptions::new(ws.gctx(), CompileMode::Build).unwrap();
+    let compile_options = CompileOptions::new(ws.gctx(), UserIntent::Build).unwrap();
 
     let result = cargo::ops::compile(&ws, &compile_options).unwrap();
 
diff --git a/tests/testsuite/member_errors.rs b/tests/testsuite/member_errors.rs
--- a/tests/testsuite/member_errors.rs
+++ b/tests/testsuite/member_errors.rs
@@ -1,7 +1,9 @@
 //! Tests for workspace member errors.
 
+use cargo::core::compiler::UserIntent;
 use cargo::core::resolver::ResolveError;
-use cargo::core::{compiler::CompileMode, Shell, Workspace};
+use cargo::core::Shell;
+use cargo::core::Workspace;
 use cargo::ops::{self, CompileOptions};
 use cargo::util::{context::GlobalContext, errors::ManifestError};
 use cargo_test_support::paths;
@@ -155,7 +157,7 @@ fn member_manifest_version_error() {
         paths::cargo_home(),
     );
     let ws = Workspace::new(&p.root().join("Cargo.toml"), &gctx).unwrap();
-    let compile_options = CompileOptions::new(&gctx, CompileMode::Build).unwrap();
+    let compile_options = CompileOptions::new(&gctx, UserIntent::Build).unwrap();
     let member_bar = ws.members().find(|m| &*m.name() == "bar").unwrap();
 
     let error = ops::compile(&ws, &compile_options).map(|_| ()).unwrap_err();
EOF_114329324912

# Run the target tests
# Note: src/bin/cargo/commands/test.rs is source code, not a test file
# We only need to run the integration tests from tests/testsuite/
# The testsuite binary contains all integration tests as modules
# We filter for 'build' and 'member_errors' test modules
cargo test --test testsuite -- build member_errors
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original files
git checkout a9e8aa2c65091b520519fd1065f41d156d45f9dd "src/bin/cargo/commands/test.rs" "tests/testsuite/build.rs" "tests/testsuite/member_errors.rs"