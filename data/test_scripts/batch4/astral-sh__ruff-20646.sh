#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 130a794c2b894d8ffc96e49c2d48bdddd11c99a6 "crates/ty_python_semantic/resources/mdtest/protocols.md"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ty_python_semantic/resources/mdtest/protocols.md b/crates/ty_python_semantic/resources/mdtest/protocols.md
--- a/crates/ty_python_semantic/resources/mdtest/protocols.md
+++ b/crates/ty_python_semantic/resources/mdtest/protocols.md
@@ -893,8 +893,10 @@ class LotsOfBindings(Protocol):
     match object():
         case l:  # error: [ambiguous-protocol-member]
             ...
+    # error: [ambiguous-protocol-member] "Consider adding an annotation, e.g. `m: int | str = ...`"
+    m = 1 if 1.2 > 3.4 else "a"
 
-# revealed: frozenset[Literal["Nested", "NestedProtocol", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]]
+# revealed: frozenset[Literal["Nested", "NestedProtocol", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m"]]
 reveal_type(get_protocol_members(LotsOfBindings))
 
 class Foo(Protocol):
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"
export RUST_BACKTRACE=1

# Run the ty_python_semantic tests targeting the protocols test
# The mdtest file will be automatically processed by the Rust test harness
# Using the specific test filter to run only the protocols-related tests
cargo test --package ty_python_semantic -- protocols --nocapture

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 130a794c2b894d8ffc96e49c2d48bdddd11c99a6 "crates/ty_python_semantic/resources/mdtest/protocols.md"