#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 1ffdc16b71e48dddcc123b197434b67f87c810a0 "pkg/apis/resource/validation/validation_deviceclass_test.go" "pkg/apis/resource/validation/validation_resourceclaim_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/apis/resource/validation/validation_deviceclass_test.go b/pkg/apis/resource/validation/validation_deviceclass_test.go
--- a/pkg/apis/resource/validation/validation_deviceclass_test.go
+++ b/pkg/apis/resource/validation/validation_deviceclass_test.go
@@ -237,7 +237,6 @@ func TestValidateClass(t *testing.T) {
 		"configuration": {
 			wantFailures: field.ErrorList{
 				field.Required(field.NewPath("spec", "config").Index(1).Child("opaque", "driver"), ""),
-				field.Invalid(field.NewPath("spec", "config").Index(1).Child("opaque", "driver"), "", "a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')"),
 				field.Required(field.NewPath("spec", "config").Index(1).Child("opaque", "parameters"), ""),
 				field.Invalid(field.NewPath("spec", "config").Index(2).Child("opaque", "parameters"), "<value omitted>", "error parsing data as JSON: invalid character 'x' looking for beginning of value"),
 				field.Invalid(field.NewPath("spec", "config").Index(3).Child("opaque", "parameters"), "<value omitted>", "must be a valid JSON object"),
diff --git a/pkg/apis/resource/validation/validation_resourceclaim_test.go b/pkg/apis/resource/validation/validation_resourceclaim_test.go
--- a/pkg/apis/resource/validation/validation_resourceclaim_test.go
+++ b/pkg/apis/resource/validation/validation_resourceclaim_test.go
@@ -1192,7 +1192,6 @@ func TestValidateClaimStatusUpdate(t *testing.T) {
 				field.NotSupported(field.NewPath("status", "allocation", "devices", "config").Index(2).Child("source"), resource.AllocationConfigSource("no-such-source"), []resource.AllocationConfigSource{resource.AllocationConfigSourceClaim, resource.AllocationConfigSourceClass}),
 				field.Required(field.NewPath("status", "allocation", "devices", "config").Index(3).Child("opaque"), ""),
 				field.Required(field.NewPath("status", "allocation", "devices", "config").Index(4).Child("opaque", "driver"), ""),
-				field.Invalid(field.NewPath("status", "allocation", "devices", "config").Index(4).Child("opaque", "driver"), "", "a lowercase RFC 1123 subdomain must consist of lower case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric character (e.g. 'example.com', regex used for validation is '[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')"),
 				field.Required(field.NewPath("status", "allocation", "devices", "config").Index(4).Child("opaque", "parameters"), ""),
 				field.TooLong(field.NewPath("status", "allocation", "devices", "config").Index(6).Child("opaque", "parameters"), "" /* unused */, resource.OpaqueParametersMaxLength),
 			},
EOF_114329324912

# Run the specific test files
# Using -v for verbose output to see individual test results
# Using -run . to match all tests (more inclusive pattern)
# The repository uses vendored dependencies and go workspace, so we can run tests directly
go test -v ./pkg/apis/resource/validation -run .

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 1ffdc16b71e48dddcc123b197434b67f87c810a0 "pkg/apis/resource/validation/validation_deviceclass_test.go" "pkg/apis/resource/validation/validation_resourceclaim_test.go"