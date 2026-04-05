#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout efddea720fe9de59f37fb95d474e60e28f118e43 "pkg/search/query_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/search/query_test.go b/pkg/search/query_test.go
--- a/pkg/search/query_test.go
+++ b/pkg/search/query_test.go
@@ -8,7 +8,7 @@ import (
 
 var trueBool = true
 
-func TestQueryString(t *testing.T) {
+func TestStandardSearchString(t *testing.T) {
 	tests := []struct {
 		name  string
 		query Query
@@ -73,7 +73,7 @@ func TestQueryString(t *testing.T) {
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			assert.Equal(t, tt.out, tt.query.String())
+			assert.Equal(t, tt.out, tt.query.StandardSearchString())
 		})
 	}
 }
EOF_114329324912

# Run the target test
go test -v ./pkg/search
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout efddea720fe9de59f37fb95d474e60e28f118e43 "pkg/search/query_test.go"