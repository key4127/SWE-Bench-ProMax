#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout ce4df26fad03a8cb76dfdd674a6bae642fbf6f4d "tests/testsuite/patch.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/testsuite/patch.rs b/tests/testsuite/patch.rs
--- a/tests/testsuite/patch.rs
+++ b/tests/testsuite/patch.rs
@@ -1510,11 +1510,8 @@ fn replace_with_crates_io() {
         .with_status(101)
         .with_stderr_data(str![[r#"
 [UPDATING] `dummy-registry` index
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` points to the same source, but patches must point to different sources.
-  Check the patch definition in `[ROOT]/foo/Cargo.toml`.
+[ERROR] patch for `bar` points to the same source, but patches must point to different sources
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
@@ -1890,11 +1887,8 @@ fn patch_same_version() {
         .with_status(101)
         .with_stderr_data(str![[r#"
 [UPDATING] git repository `[ROOTURL]/override`
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  cannot have two `[patch]` entries which both resolve to `bar v0.1.0`.
-  Check patch definitions for `bar` in `[ROOT]/foo/Cargo.toml`
+[ERROR] several `[patch]` entries resolving to same version `bar v0.1.0`
+[HELP] check `bar` patch definitions for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
@@ -1950,11 +1944,8 @@ fn patch_same_version_different_patch_locations() {
         .with_status(101)
         .with_stderr_data(str![[r#"
 [UPDATING] git repository `[ROOTURL]/override`
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  cannot have two `[patch]` entries which both resolve to `bar v0.1.0`.
-  Check patch definitions for `bar` in `[ROOT]/foo/.cargo/config.toml, [ROOT]/foo/Cargo.toml`
+[ERROR] several `[patch]` entries resolving to same version `bar v0.1.0`
+[HELP] check `bar` patch definitions for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/.cargo/config.toml`, `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
@@ -2286,16 +2277,68 @@ fn too_many_matches() {
         .with_status(101)
         .with_stderr_data(str![[r#"
 [UPDATING] `alternative` index
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
+[ERROR] patch for `bar` in `registry `alternative`` resolved to more than one candidate
+[NOTE] found versions: 0.1.0, 0.1.1
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
+[HELP] select only one package using `version = "=0.1.1"`
 
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
+"#]])
+        .run();
+}
 
-Caused by:
-  patch for `bar` in `registry `alternative`` resolved to more than one candidate
-  Found versions: 0.1.0, 0.1.1
-  Update the patch definition in `[ROOT]/foo/Cargo.toml` to select only one package.
-  For example, add an `=` version requirement to the patch definition, such as `version = "=0.1.1"`.
+#[cargo_test]
+fn too_many_matches_in_git_repo() {
+    // The patch location has multiple versions that match.
+    Package::new("bar", "0.1.0").publish();
+    let git_repo = git::repo(&paths::root().join("git-repo"))
+        .file(
+            "Cargo.toml",
+            r#"
+        [workspace]
+        members = ["bar", "bar2"]
+        "#,
+        )
+        .file("bar/Cargo.toml", &basic_manifest("bar", "0.1.0"))
+        .file("bar/src/lib.rs", "")
+        .file("bar2/Cargo.toml", &basic_manifest("bar", "0.1.1"))
+        .file("bar2/src/lib.rs", "")
+        .build();
+
+    let p = project()
+        .file(
+            "Cargo.toml",
+            &format!(
+                r#"
+                [package]
+                name = "foo"
+                version = "0.1.0"
+                edition = "2015"
+
+                [dependencies]
+                bar = "0.1"
+
+                [patch.crates-io]
+                bar = {{ version = "0.1", git = '{}' }}
+            "#,
+                git_repo.url()
+            ),
+        )
+        .file("src/lib.rs", "")
+        .file("bar/Cargo.toml", &basic_manifest("bar", "0.1.0"))
+        .file("bar/src/lib.rs", "")
+        .file("bar2/Cargo.toml", &basic_manifest("bar", "0.1.1"))
+        .file("bar2/src/lib.rs", "")
+        .build();
+
+    // Picks 0.1.1, the most recent version.
+    p.cargo("check")
+        .with_status(101)
+        .with_stderr_data(str![[r#"
+[UPDATING] git repository `[ROOTURL]/git-repo`
+[ERROR] patch for `bar` in `[ROOTURL]/git-repo` resolved to more than one candidate
+[NOTE] found versions: 0.1.0, 0.1.1
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
+[HELP] select only one package using `version = "=0.1.1"`
 
 "#]])
         .run();
@@ -2328,14 +2371,8 @@ fn no_matches() {
     p.cargo("check")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
-
-Caused by:
-  The patch location `[ROOT]/foo/bar` does not appear to contain any packages matching the name `bar`.
-  Check the patch definition in `[ROOT]/foo/Cargo.toml`.
+[ERROR] patch location `[ROOT]/foo/bar` does not contain packages matching `bar`
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
@@ -2368,14 +2405,10 @@ fn mismatched_version() {
     p.cargo("check")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
-
-Caused by:
-  The patch location `[ROOT]/foo/bar` contains a `bar` package with version `0.1.0`, but the patch definition in `[ROOT]/foo/Cargo.toml` requires `^0.1.1`.
-  Check that the version in the patch location is what you expect, and update the patch definition to match.
+[ERROR] patch `bar` version mismatch
+[NOTE] patch location contains version `0.1.0`, but patch definition requires `^0.1.1`
+[HELP] check patch location `[ROOT]/foo/bar`
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
@@ -2407,14 +2440,10 @@ fn mismatched_version_from_cli_config() {
         .arg_line("--config 'patch.crates-io.bar.version=\"0.1.1\"'")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
-
-Caused by:
-  The patch location `[ROOT]/foo/bar` contains a `bar` package with version `0.1.0`, but the patch definition in `--config cli option` requires `^0.1.1`.
-  Check that the version in the patch location is what you expect, and update the patch definition to match.
+[ERROR] patch `bar` version mismatch
+[NOTE] patch location contains version `0.1.0`, but patch definition requires `^0.1.1`
+[HELP] check patch location `[ROOT]/foo/bar`
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `--config cli option`
 
 "#]])
         .run();
@@ -2454,14 +2483,10 @@ fn mismatched_version_from_config_file_provided_via_cli() {
         .arg_line("--config tmp/my-config.toml")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
-
-Caused by:
-  The patch location `[ROOT]/foo/bar` contains a `bar` package with version `0.1.0`, but the patch definition in `[ROOT]/foo/tmp/my-config.toml` requires `^0.1.1`.
-  Check that the version in the patch location is what you expect, and update the patch definition to match.
+[ERROR] patch `bar` version mismatch
+[NOTE] patch location contains version `0.1.0`, but patch definition requires `^0.1.1`
+[HELP] check patch location `[ROOT]/foo/bar`
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/tmp/my-config.toml`
 
 "#]])
         .run();
@@ -2603,14 +2628,10 @@ fn patch_walks_backwards_restricted() {
     p.cargo("check")
         .with_status(101)
         .with_stderr_data(str![[r#"
-[ERROR] failed to resolve patches for `https://github.com/rust-lang/crates.io-index`
-
-Caused by:
-  patch for `bar` in `https://github.com/rust-lang/crates.io-index` failed to resolve
-
-Caused by:
-  The patch location `[ROOT]/foo/bar` contains a `bar` package with version `0.1.0`, but the patch definition in `[ROOT]/foo/Cargo.toml` requires `^0.1.1`.
-  Check that the version in the patch location is what you expect, and update the patch definition to match.
+[ERROR] patch `bar` version mismatch
+[NOTE] patch location contains version `0.1.0`, but patch definition requires `^0.1.1`
+[HELP] check patch location `[ROOT]/foo/bar`
+[HELP] check `bar` patch definition for `https://github.com/rust-lang/crates.io-index` in `[ROOT]/foo/Cargo.toml`
 
 "#]])
         .run();
EOF_114329324912

# Run the specific test for patch module
# Using single-threaded execution for stability in virtualized environment
cargo test -p cargo --test testsuite -- patch:: --test-threads=1
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout ce4df26fad03a8cb76dfdd674a6bae642fbf6f4d "tests/testsuite/patch.rs"