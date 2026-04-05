#!/bin/bash
set -uxo pipefail

# Ensure Rust environment is available
source $HOME/.cargo/env

cd /testbed

# Checkout the original test files to ensure clean state
git checkout 1fe6b288779be92006859aa1a2f30748fd122507 "src/tests/encoding.rs" "src/tests/history.rs" "src/tests/string_escape.rs" "src/wutil/tests.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/tests/encoding.rs b/src/tests/encoding.rs
--- a/src/tests/encoding.rs
+++ b/src/tests/encoding.rs
@@ -1,11 +1,11 @@
-use crate::common::{str2wcstring, wcs2string};
+use crate::common::{bytes2wcstring, wcs2bytes};
 use crate::wchar::prelude::*;
 
 /// Verify correct behavior with embedded nulls.
 #[test]
 fn test_convert_nulls() {
     let input = L!("AAA\0BBB");
-    let out_str = wcs2string(input);
+    let out_str = wcs2bytes(input);
     assert_eq!(
         input.chars().collect::<Vec<_>>(),
         std::str::from_utf8(&out_str)
@@ -14,20 +14,20 @@ fn test_convert_nulls() {
             .collect::<Vec<_>>()
     );
 
-    let out_wstr = str2wcstring(&out_str);
+    let out_wstr = bytes2wcstring(&out_str);
     assert_eq!(input, &out_wstr);
 }
 
 #[cfg(feature = "benchmark")]
 mod bench {
     extern crate test;
-    use crate::tests::encoding::str2wcstring;
+    use crate::tests::encoding::bytes2wcstring;
     use test::Bencher;
 
     #[bench]
     fn bench_convert_ascii(b: &mut Bencher) {
         let s: [u8; 128 * 1024] = std::array::from_fn(|i| b'0' + u8::try_from(i % 10).unwrap());
         b.bytes = u64::try_from(s.len()).unwrap();
-        b.iter(|| str2wcstring(&s));
+        b.iter(|| bytes2wcstring(&s));
     }
 }
diff --git a/src/tests/history.rs b/src/tests/history.rs
--- a/src/tests/history.rs
+++ b/src/tests/history.rs
@@ -1,4 +1,4 @@
-use crate::common::{ScopeGuard, str2wcstring, wcs2osstring, wcs2string};
+use crate::common::{ScopeGuard, bytes2wcstring, wcs2bytes, wcs2osstring};
 use crate::env::{EnvMode, EnvStack};
 use crate::fs::{LockedFile, WriteMethod};
 use crate::history::{
@@ -260,7 +260,7 @@ fn test_history_races() {
     });
     if LockedFile::new(
         crate::fs::LockingMode::Exclusive(WriteMethod::RenameIntoPlace),
-        &str2wcstring(tmp_path.as_os_str().as_bytes()),
+        &bytes2wcstring(tmp_path.as_os_str().as_bytes()),
     )
     .is_err()
     {
@@ -497,7 +497,7 @@ fn test_history_path_detection() {
     let tmpdirbuff = CString::new("/tmp/fish_test_history.XXXXXX").unwrap();
     let tmpdir = unsafe { libc::mkdtemp(tmpdirbuff.into_raw()) };
     let tmpdir = unsafe { CString::from_raw(tmpdir) };
-    let mut tmpdir = str2wcstring(tmpdir.to_bytes());
+    let mut tmpdir = bytes2wcstring(tmpdir.to_bytes());
     if !tmpdir.ends_with('/') {
         tmpdir.push('/');
     }
@@ -602,7 +602,7 @@ fn install_sample_history(name: &wstr) {
     std::fs::copy(
         workspace_root()
             .join("tests")
-            .join(std::str::from_utf8(&wcs2string(name)).unwrap()),
+            .join(std::str::from_utf8(&wcs2bytes(name)).unwrap()),
         wcs2osstring(&(path + L!("/") + name + L!("_history"))),
     )
     .unwrap();
diff --git a/src/tests/string_escape.rs b/src/tests/string_escape.rs
--- a/src/tests/string_escape.rs
+++ b/src/tests/string_escape.rs
@@ -2,7 +2,7 @@ use std::sync::MutexGuard;
 
 use crate::common::{
     ENCODE_DIRECT_BASE, ENCODE_DIRECT_END, EscapeFlags, EscapeStringStyle, UnescapeStringStyle,
-    escape_string, fish_setlocale, str2wcstring, unescape_string, wcs2string,
+    bytes2wcstring, escape_string, fish_setlocale, unescape_string, wcs2bytes,
 };
 use crate::locale::LOCALE_LOCK;
 use crate::util::{get_rng_seed, get_seeded_rng};
@@ -12,7 +12,7 @@ use crate::wutil::encoding::{
 };
 use rand::{Rng, RngCore};
 
-/// wcs2string is locale-dependent, so ensure we have a multibyte locale
+/// wcs2bytes is locale-dependent, so ensure we have a multibyte locale
 /// before using it in a test.
 fn setlocale() -> MutexGuard<'static, ()> {
     let guard = LOCALE_LOCK.lock().unwrap();
@@ -173,7 +173,7 @@ const ESCAPE_TEST_LENGTH: usize = 100;
 pub const ESCAPE_TEST_CHAR: usize = 4000;
 
 /// Helper to convert a narrow string to a sequence of hex digits.
-fn str2hex(input: &[u8]) -> String {
+fn bytes2hex(input: &[u8]) -> String {
     let mut output = "".to_string();
     for byte in input {
         output += &format!("0x{:2X} ", *byte);
@@ -195,8 +195,8 @@ fn test_convert() {
         origin.resize(length, 0);
         rng.fill_bytes(&mut origin);
 
-        let w = str2wcstring(&origin[..]);
-        let n = wcs2string(&w);
+        let w = bytes2wcstring(&origin[..]);
+        let n = wcs2bytes(&w);
         assert_eq!(
             origin,
             n,
@@ -205,9 +205,9 @@ fn test_convert() {
                 {:4} chars: {}\n
                 Use this seed to reproduce: {}",
             origin.len(),
-            &str2hex(&origin),
+            &bytes2hex(&origin),
             n.len(),
-            &str2hex(&n),
+            &bytes2hex(&n),
             seed,
         );
     }
@@ -226,8 +226,8 @@ fn test_convert_ascii() {
         for right in 0..16 {
             let len = s.len() - left - right;
             let input = &s[left..left + len];
-            let wide = str2wcstring(input);
-            let narrow = wcs2string(&wide);
+            let wide = bytes2wcstring(input);
+            let narrow = wcs2bytes(&wide);
             assert_eq!(narrow, input);
         }
     }
@@ -236,7 +236,7 @@ fn test_convert_ascii() {
     for i in 0..s.len() {
         let saved = s[i];
         s[i] = 0xF7;
-        assert_eq!(wcs2string(&str2wcstring(&s)), s);
+        assert_eq!(wcs2bytes(&bytes2wcstring(&s)), s);
         s[i] = saved;
     }
 }
@@ -265,13 +265,13 @@ fn test_convert_private_use() {
         }
         let s = &converted[..len];
 
-        // Ask fish to decode this via str2wcstring.
-        // str2wcstring should notice that the decoded form collides with its private use
+        // Ask fish to decode this via bytes2wcstring.
+        // bytes2wcstring should notice that the decoded form collides with its private use
         // and encode it directly.
-        let ws = str2wcstring(s);
+        let ws = bytes2wcstring(s);
 
         // Each byte should be encoded directly, and round tripping should work.
         assert_eq!(ws.len(), s.len());
-        assert_eq!(wcs2string(&ws), s);
+        assert_eq!(wcs2bytes(&ws), s);
     }
 }
diff --git a/src/wutil/tests.rs b/src/wutil/tests.rs
--- a/src/wutil/tests.rs
+++ b/src/wutil/tests.rs
@@ -76,7 +76,7 @@ fn test_wwrite_to_fd() {
         }
 
         let amt = wwrite_to_fd(&input, fd.fd()).unwrap();
-        let narrow = wcs2string(&input);
+        let narrow = wcs2bytes(&input);
         assert_eq!(amt, narrow.len());
 
         assert!(unsafe { libc::lseek(fd.fd(), 0, SEEK_SET) } >= 0);
EOF_114329324912

# Run the target tests
# These are unit tests within the library (in src/tests/ and src/wutil/tests.rs)
# Running each test module separately to ensure all specified tests are executed
cargo test encoding -- --test-threads=1 --nocapture
cargo test history -- --test-threads=1 --nocapture
cargo test string_escape -- --test-threads=1 --nocapture
cargo test wutil -- --test-threads=1 --nocapture

# Capture exit code from the last test command
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 1fe6b288779be92006859aa1a2f30748fd122507 "src/tests/encoding.rs" "src/tests/history.rs" "src/tests/string_escape.rs" "src/wutil/tests.rs"