#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 5d532fe0cd1ee6f1af1d588dc6d3976f36c36799 "transport/http/binding/bind_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/transport/http/binding/bind_test.go b/transport/http/binding/bind_test.go
--- a/transport/http/binding/bind_test.go
+++ b/transport/http/binding/bind_test.go
@@ -49,7 +49,7 @@ func TestBindQuery(t *testing.T) {
 				vars:   map[string][]string{"age": {"kratos"}, "url": {"https://go-kratos.dev/"}},
 				target: &TestBind2{},
 			},
-			err: kratoserror.BadRequest("CODEC", "Field Namespace:age ERROR:Invalid Integer Value 'kratos' Type 'int' Namespace 'age'"),
+			err: kratoserror.BadRequest(kratoserror.CodecReason, "Field Namespace:age ERROR:Invalid Integer Value 'kratos' Type 'int' Namespace 'age'"),
 		},
 		{
 			name: "test2",
@@ -118,7 +118,7 @@ func TestBindForm(t *testing.T) {
 				},
 				target: &TestBind2{},
 			},
-			err:  kratoserror.BadRequest("CODEC", "Field Namespace:age ERROR:Invalid Integer Value 'a' Type 'int' Namespace 'age'"),
+			err:  kratoserror.BadRequest(kratoserror.CodecReason, "Field Namespace:age ERROR:Invalid Integer Value 'a' Type 'int' Namespace 'age'"),
 			want: nil,
 		},
 	}
EOF_114329324912

# Execute the target test file
# Using -v for verbose output to help with debugging
# Running only the specific test file as requested
go test -v ./transport/http/binding/bind_test.go ./transport/http/binding/bind.go ./transport/http/binding/encode.go

# Capture exit code
rc=$?

# Echo exit code for judge evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 5d532fe0cd1ee6f1af1d588dc6d3976f36c36799 "transport/http/binding/bind_test.go"