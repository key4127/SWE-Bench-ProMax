#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 555b9f78d642e94f9debc8a7e41daad8ffd238d8 \
    "crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md b/crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md
--- a/crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md
+++ b/crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md
@@ -125,11 +125,11 @@ def _(
     top_meth: Top[TypeOf[A().method]],
     bottom_meth: Bottom[TypeOf[A().method]],
 ):
-    reveal_type(top_func)  # revealed: def function(x: Any) -> None
-    reveal_type(bottom_func)  # revealed: def function(x: Any) -> None
+    reveal_type(top_func)  # revealed: def function(x: Never) -> None
+    reveal_type(bottom_func)  # revealed: def function(x: object) -> None
 
-    reveal_type(top_meth)  # revealed: bound method A.method(x: Any) -> None
-    reveal_type(bottom_meth)  # revealed: bound method A.method(x: Any) -> None
+    reveal_type(top_meth)  # revealed: bound method A.method(x: Never) -> None
+    reveal_type(bottom_meth)  # revealed: bound method A.method(x: object) -> None
 ```
 
 ## Callable
@@ -698,3 +698,35 @@ static_assert(is_assignable_to(InvariantChild[Any], CovariantBase[A]))
 
 static_assert(not is_assignable_to(Top[InvariantChild[Any]], CovariantBase[A]))
 ```
+
+## Attributes
+
+Attributes on top and bottom materializations are specialized on access.
+
+```toml
+[environment]
+python-version = "3.12"
+```
+
+```py
+from ty_extensions import Top, Bottom
+from typing import Any
+
+class Invariant[T]:
+    def get(self) -> T:
+        raise NotImplementedError
+
+    def push(self, obj: T) -> None: ...
+
+    attr: T
+
+def capybara(top: Top[Invariant[Any]], bottom: Bottom[Invariant[Any]]) -> None:
+    reveal_type(top.get)  # revealed: bound method Top[Invariant[Any]].get() -> object
+    reveal_type(top.push)  # revealed: bound method Top[Invariant[Any]].push(obj: Never) -> None
+
+    reveal_type(bottom.get)  # revealed: bound method Bottom[Invariant[Any]].get() -> Never
+    reveal_type(bottom.push)  # revealed: bound method Bottom[Invariant[Any]].push(obj: object) -> None
+
+    reveal_type(top.attr)  # revealed: object
+    reveal_type(bottom.attr)  # revealed: Never
+```
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Set environment variables for clean test output
export NO_COLOR=1
export RUST_BACKTRACE=1

# Run the specific mdtest for materialization
# Using the test filter to target only the materialization test
cargo test --package ty_python_semantic --test mdtest -- materialization --nocapture

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 555b9f78d642e94f9debc8a7e41daad8ffd238d8 \
    "crates/ty_python_semantic/resources/mdtest/type_properties/materialization.md"