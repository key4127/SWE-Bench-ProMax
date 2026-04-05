#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout b57cc5be330847bb6f83f9af4bf5364dc3ac4ffe \
    "crates/ty_python_semantic/resources/mdtest/call/overloads.md"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/ty_python_semantic/resources/mdtest/call/overloads.md b/crates/ty_python_semantic/resources/mdtest/call/overloads.md
--- a/crates/ty_python_semantic/resources/mdtest/call/overloads.md
+++ b/crates/ty_python_semantic/resources/mdtest/call/overloads.md
@@ -660,9 +660,9 @@ class Foo:
 
 ```py
 from overloaded import A, B, C, Foo, f
-from typing_extensions import reveal_type
+from typing_extensions import Any, reveal_type
 
-def _(ab: A | B, a=1):
+def _(ab: A | B, a: int | Any):
     reveal_type(f(a1=a, a2=a, a3=a))  # revealed: C
     reveal_type(f(A(), a1=a, a2=a, a3=a))  # revealed: A
     reveal_type(f(B(), a1=a, a2=a, a3=a))  # revealed: B
@@ -750,7 +750,7 @@ def _(ab: A | B, a=1):
         )
     )
 
-def _(foo: Foo, ab: A | B, a=1):
+def _(foo: Foo, ab: A | B, a: int | Any):
     reveal_type(foo.f(a1=a, a2=a, a3=a))  # revealed: C
     reveal_type(foo.f(A(), a1=a, a2=a, a3=a))  # revealed: A
     reveal_type(foo.f(B(), a1=a, a2=a, a3=a))  # revealed: B
@@ -831,6 +831,76 @@ def _(foo: Foo, ab: A | B, a=1):
     )
 ```
 
+### Optimization: Limit expansion size
+
+<!-- snapshot-diagnostics -->
+
+To prevent combinatorial explosion, ty limits the number of argument lists created by expanding a
+single argument.
+
+`overloaded.pyi`:
+
+```pyi
+from typing import overload
+
+class A: ...
+class B: ...
+class C: ...
+
+@overload
+def f() -> None: ...
+@overload
+def f(**kwargs: int) -> C: ...
+@overload
+def f(x: A, /, **kwargs: int) -> A: ...
+@overload
+def f(x: B, /, **kwargs: int) -> B: ...
+```
+
+```py
+from overloaded import A, B, f
+from typing_extensions import reveal_type
+
+def _(a: int | None):
+    reveal_type(
+        # error: [no-matching-overload]
+        # revealed: Unknown
+        f(
+            A(),
+            a1=a,
+            a2=a,
+            a3=a,
+            a4=a,
+            a5=a,
+            a6=a,
+            a7=a,
+            a8=a,
+            a9=a,
+            a10=a,
+            a11=a,
+            a12=a,
+            a13=a,
+            a14=a,
+            a15=a,
+            a16=a,
+            a17=a,
+            a18=a,
+            a19=a,
+            a20=a,
+            a21=a,
+            a22=a,
+            a23=a,
+            a24=a,
+            a25=a,
+            a26=a,
+            a27=a,
+            a28=a,
+            a29=a,
+            a30=a,
+        )
+    )
+```
+
 ## Filtering based on `Any` / `Unknown`
 
 This is the step 5 of the overload call evaluation algorithm which specifies that:
diff --git a/crates/ty_python_semantic/resources/mdtest/snapshots/overloads.md_-_Overloads_-_Argument_type_expans…_-_Optimization___Limit_…_(cd61048adbc17331).snap b/crates/ty_python_semantic/resources/mdtest/snapshots/overloads.md_-_Overloads_-_Argument_type_expans…_-_Optimization___Limit_…_(cd61048adbc17331).snap
new file mode 100644
--- /dev/null
+++ b/crates/ty_python_semantic/resources/mdtest/snapshots/overloads.md_-_Overloads_-_Argument_type_expans…_-_Optimization___Limit_…_(cd61048adbc17331).snap
@@ -0,0 +1,183 @@
+---
+source: crates/ty_test/src/lib.rs
+expression: snapshot
+---
+---
+mdtest name: overloads.md - Overloads - Argument type expansion - Optimization: Limit expansion size
+mdtest path: crates/ty_python_semantic/resources/mdtest/call/overloads.md
+---
+
+# Python source files
+
+## overloaded.pyi
+
+```
+ 1 | from typing import overload
+ 2 | 
+ 3 | class A: ...
+ 4 | class B: ...
+ 5 | class C: ...
+ 6 | 
+ 7 | @overload
+ 8 | def f() -> None: ...
+ 9 | @overload
+10 | def f(**kwargs: int) -> C: ...
+11 | @overload
+12 | def f(x: A, /, **kwargs: int) -> A: ...
+13 | @overload
+14 | def f(x: B, /, **kwargs: int) -> B: ...
+```
+
+## mdtest_snippet.py
+
+```
+ 1 | from overloaded import A, B, f
+ 2 | from typing_extensions import reveal_type
+ 3 | 
+ 4 | def _(a: int | None):
+ 5 |     reveal_type(
+ 6 |         # error: [no-matching-overload]
+ 7 |         # revealed: Unknown
+ 8 |         f(
+ 9 |             A(),
+10 |             a1=a,
+11 |             a2=a,
+12 |             a3=a,
+13 |             a4=a,
+14 |             a5=a,
+15 |             a6=a,
+16 |             a7=a,
+17 |             a8=a,
+18 |             a9=a,
+19 |             a10=a,
+20 |             a11=a,
+21 |             a12=a,
+22 |             a13=a,
+23 |             a14=a,
+24 |             a15=a,
+25 |             a16=a,
+26 |             a17=a,
+27 |             a18=a,
+28 |             a19=a,
+29 |             a20=a,
+30 |             a21=a,
+31 |             a22=a,
+32 |             a23=a,
+33 |             a24=a,
+34 |             a25=a,
+35 |             a26=a,
+36 |             a27=a,
+37 |             a28=a,
+38 |             a29=a,
+39 |             a30=a,
+40 |         )
+41 |     )
+```
+
+# Diagnostics
+
+```
+error[no-matching-overload]: No overload of function `f` matches arguments
+  --> src/mdtest_snippet.py:8:9
+   |
+ 6 |           # error: [no-matching-overload]
+ 7 |           # revealed: Unknown
+ 8 | /         f(
+ 9 | |             A(),
+10 | |             a1=a,
+11 | |             a2=a,
+12 | |             a3=a,
+13 | |             a4=a,
+14 | |             a5=a,
+15 | |             a6=a,
+16 | |             a7=a,
+17 | |             a8=a,
+18 | |             a9=a,
+19 | |             a10=a,
+20 | |             a11=a,
+21 | |             a12=a,
+22 | |             a13=a,
+23 | |             a14=a,
+24 | |             a15=a,
+25 | |             a16=a,
+26 | |             a17=a,
+27 | |             a18=a,
+28 | |             a19=a,
+29 | |             a20=a,
+30 | |             a21=a,
+31 | |             a22=a,
+32 | |             a23=a,
+33 | |             a24=a,
+34 | |             a25=a,
+35 | |             a26=a,
+36 | |             a27=a,
+37 | |             a28=a,
+38 | |             a29=a,
+39 | |             a30=a,
+40 | |         )
+   | |_________^
+41 |       )
+   |
+info: Limit of argument type expansion reached at argument 10
+info: First overload defined here
+  --> src/overloaded.pyi:8:5
+   |
+ 7 | @overload
+ 8 | def f() -> None: ...
+   |     ^^^^^^^^^^^
+ 9 | @overload
+10 | def f(**kwargs: int) -> C: ...
+   |
+info: Possible overloads for function `f`:
+info:   () -> None
+info:   (**kwargs: int) -> C
+info:   (x: A, /, **kwargs: int) -> A
+info:   (x: B, /, **kwargs: int) -> B
+info: rule `no-matching-overload` is enabled by default
+
+```
+
+```
+info[revealed-type]: Revealed type
+  --> src/mdtest_snippet.py:8:9
+   |
+ 6 |           # error: [no-matching-overload]
+ 7 |           # revealed: Unknown
+ 8 | /         f(
+ 9 | |             A(),
+10 | |             a1=a,
+11 | |             a2=a,
+12 | |             a3=a,
+13 | |             a4=a,
+14 | |             a5=a,
+15 | |             a6=a,
+16 | |             a7=a,
+17 | |             a8=a,
+18 | |             a9=a,
+19 | |             a10=a,
+20 | |             a11=a,
+21 | |             a12=a,
+22 | |             a13=a,
+23 | |             a14=a,
+24 | |             a15=a,
+25 | |             a16=a,
+26 | |             a17=a,
+27 | |             a18=a,
+28 | |             a19=a,
+29 | |             a20=a,
+30 | |             a21=a,
+31 | |             a22=a,
+32 | |             a23=a,
+33 | |             a24=a,
+34 | |             a25=a,
+35 | |             a26=a,
+36 | |             a27=a,
+37 | |             a28=a,
+38 | |             a29=a,
+39 | |             a30=a,
+40 | |         )
+   | |_________^ `Unknown`
+41 |       )
+   |
+
+```
EOF_114329324912

# Ensure Rust environment is available
export PATH="/root/.cargo/bin:$PATH"

# Run the specific mdtest for overloads
# Using the exact test name as identified by the context retrieval agent
cargo test --test mdtest mdtest__call_overloads --no-fail-fast -- --nocapture

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout b57cc5be330847bb6f83f9af4bf5364dc3ac4ffe \
    "crates/ty_python_semantic/resources/mdtest/call/overloads.md"