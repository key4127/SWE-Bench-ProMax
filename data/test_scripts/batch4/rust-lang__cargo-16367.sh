#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout d49dca3bf27a1d69aff93c0519038cde6d5d287a "tests/testsuite/lints/inherited/stderr.term.svg" "tests/testsuite/lints/mod.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/testsuite/lints/inherited/stderr.term.svg b/tests/testsuite/lints/inherited/stderr.term.svg
--- a/tests/testsuite/lints/inherited/stderr.term.svg
+++ b/tests/testsuite/lints/inherited/stderr.term.svg
@@ -1,7 +1,7 @@
 <svg width="818px" height="272px" xmlns="http://www.w3.org/2000/svg">
   <style>
     .fg { fill: #AAAAAA }
-    .bg { background: #000000 }
+    .bg { fill: #000000 }
     .fg-bright-blue { fill: #5555FF }
     .fg-bright-green { fill: #55FF55 }
     .fg-bright-red { fill: #FF5555 }
@@ -44,7 +44,7 @@
 </tspan>
     <tspan x="10px" y="226px"><tspan>  </tspan><tspan class="fg-bright-blue bold">|</tspan><tspan> </tspan><tspan class="fg-bright-blue bold">----------------</tspan>
 </tspan>
-    <tspan x="10px" y="244px"><tspan class="fg-bright-red bold">error</tspan><tspan>: encountered 1 errors(s) while verifying lints</tspan>
+    <tspan x="10px" y="244px"><tspan class="fg-bright-red bold">error</tspan><tspan>: encountered 1 error while verifying lints</tspan>
 </tspan>
     <tspan x="10px" y="262px">
 </tspan>
diff --git a/tests/testsuite/lints/mod.rs b/tests/testsuite/lints/mod.rs
--- a/tests/testsuite/lints/mod.rs
+++ b/tests/testsuite/lints/mod.rs
@@ -257,7 +257,7 @@ im_a_teapot = "warn"
   | ^^^^^^^^^^^ this is behind `test-dummy-unstable`, which is not enabled
   |
   = [HELP] consider adding `cargo-features = ["test-dummy-unstable"]` to the top of the manifest
-[ERROR] encountered 1 errors(s) while verifying lints
+[ERROR] encountered 1 error while verifying lints
 
 "#]])
         .run();
@@ -321,7 +321,7 @@ workspace = true
   |
 9 | workspace = true
   | ----------------
-[ERROR] encountered 2 errors(s) while verifying lints
+[ERROR] encountered 2 errors while verifying lints
 
 "#]])
         .run();
EOF_114329324912

# Run the specific test for lints::inherited module
# Using single-threaded execution for stability in virtualized environment
cargo test --test testsuite -- lints::inherited --test-threads=1
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout d49dca3bf27a1d69aff93c0519038cde6d5d287a "tests/testsuite/lints/inherited/stderr.term.svg" "tests/testsuite/lints/mod.rs"