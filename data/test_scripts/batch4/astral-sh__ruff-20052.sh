#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout ef4897f9f38440d04716580b9655f5c18d5398d5 "crates/ty_server/tests/e2e/inlay_hints.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ty_server/tests/e2e/inlay_hints.rs b/crates/ty_server/tests/e2e/inlay_hints.rs
--- a/crates/ty_server/tests/e2e/inlay_hints.rs
+++ b/crates/ty_server/tests/e2e/inlay_hints.rs
@@ -42,15 +42,29 @@ foo(1)
           "line": 0,
           "character": 1
         },
-        "label": ": Literal[1]",
+        "label": [
+          {
+            "value": ": "
+          },
+          {
+            "value": "Literal[1]"
+          }
+        ],
         "kind": 1
       },
       {
         "position": {
           "line": 5,
           "character": 4
         },
-        "label": "a=",
+        "label": [
+          {
+            "value": "a"
+          },
+          {
+            "value": "="
+          }
+        ],
         "kind": 2
       }
     ]
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Run the specific ty_server e2e test for inlay_hints
# Using --test e2e to run the e2e test binary, with --nocapture to show output
# The test file inlay_hints.rs is part of the e2e test suite
cargo test --package ty_server --test e2e inlay_hints -- --nocapture

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout ef4897f9f38440d04716580b9655f5c18d5398d5 "crates/ty_server/tests/e2e/inlay_hints.rs"