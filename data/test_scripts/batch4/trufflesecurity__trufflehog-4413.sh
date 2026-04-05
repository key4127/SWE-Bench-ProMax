#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target commit and specific test files
git checkout bb899f20dc5e38352d10aedbfff6aac52435b43f "pkg/custom_detectors/custom_detectors_test.go" "pkg/custom_detectors/validation_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/custom_detectors/custom_detectors_test.go b/pkg/custom_detectors/custom_detectors_test.go
--- a/pkg/custom_detectors/custom_detectors_test.go
+++ b/pkg/custom_detectors/custom_detectors_test.go
@@ -4,9 +4,13 @@ import (
 	"context"
 	"testing"
 
+	"github.com/google/go-cmp/cmp"
+	"github.com/google/go-cmp/cmp/cmpopts"
 	"github.com/stretchr/testify/assert"
 
+	"github.com/trufflesecurity/trufflehog/v3/pkg/detectors"
 	"github.com/trufflesecurity/trufflehog/v3/pkg/pb/custom_detectorspb"
+	"github.com/trufflesecurity/trufflehog/v3/pkg/pb/detectorspb"
 	"github.com/trufflesecurity/trufflehog/v3/pkg/protoyaml"
 )
 
@@ -227,6 +231,334 @@ func TestDetectorPrimarySecret(t *testing.T) {
 	assert.Equal(t, "secret_YI7C90ACY1_yy", results[0].GetPrimarySecretValue())
 }
 
+func TestDetectorValidations(t *testing.T) {
+	type args struct {
+		CustomRegex *custom_detectorspb.CustomRegex
+		Data        string
+	}
+
+	tests := []struct {
+		name  string
+		input args
+		want  []detectors.Result
+	}{
+		{
+			name: "custom validation - contains digit",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsDigit: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStr0ngP@ssword!
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStr0ngP@ssword!"),
+				},
+			},
+		},
+		{
+			name: "custom validation - does not contains digit",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsDigit: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongPassword!
+						End of file`,
+			},
+			want: nil,
+		},
+		{
+			name: "custom validation - contains lowercase",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsLowercase: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongPassword!
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStrongPassword!"),
+				},
+			},
+		},
+		{
+			name: "custom validation - does not contains lowercase",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsLowercase: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MYSTRONGPASSWORD!
+						End of file`,
+			},
+			want: nil,
+		},
+		{
+			name: "custom validation - contains uppercase",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsUppercase: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongPassword!
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStrongPassword!"),
+				},
+			},
+		},
+		{
+			name: "custom validation - does not contains uppercase",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsUppercase: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: mystrongpassword!
+						End of file`,
+			},
+			want: nil,
+		},
+		{
+			name: "custom validation - contains special character",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsSpecialChar: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStr@ngP@ssword!
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStr@ngP@ssword!"),
+				},
+			},
+		},
+		{
+			name: "custom validation - does not contains special character",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsSpecialChar: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongPassword
+						End of file`,
+			},
+			want: nil,
+		},
+		{
+			name: "custom validation - contains uppercase and special characters",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsUppercase:   true,
+							ContainsSpecialChar: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongP@ssword
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStrongP@ssword"),
+				},
+			},
+		},
+		{
+			name: "custom validation - contains uppercase but does not contain special characters",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsUppercase:   true,
+							ContainsSpecialChar: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongPassword
+						End of file`,
+			},
+			want: nil,
+		},
+		{
+			name: "custom validation - wrong regex name in validations",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password"},
+					Regex:    map[string]string{"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"wrong": {
+							ContainsUppercase: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: mystrongp@ssword
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("mystrongp@ssword"),
+				},
+			},
+		},
+		{
+			name: "custom validation - multiple regex validations",
+			input: args{
+				CustomRegex: &custom_detectorspb.CustomRegex{
+					Name:     "test",
+					Keywords: []string{"password", "api_key"},
+					Regex: map[string]string{
+						"password": `([A-Za-z0-9!@#$%^&*()_+=\-]{12,})`,
+						"api_key":  `([a-f0-9_-]{32})`,
+					},
+					Validations: map[string]*custom_detectorspb.ValidationConfig{
+						"password": {
+							ContainsUppercase:   true,
+							ContainsSpecialChar: true,
+						},
+						"api_key": {
+							ContainsSpecialChar: true,
+						},
+					},
+				},
+				Data: `This is custom example
+						This file has a random text and maybe a secret
+						Password: MyStrongP@ssword
+						API_Key: c392c9837d69b44c764cbf260b-e6184 // should be detected
+						API_Key: c392c9837d69b44c764cbf260be6184 // should be filtered by validation
+						End of file`,
+			},
+			want: []detectors.Result{
+				{
+					DetectorType: detectorspb.DetectorType_CustomRegex,
+					DetectorName: "test",
+					Verified:     false,
+					Raw:          []byte("MyStrongP@sswordc392c9837d69b44c764cbf260b-e6184"),
+				},
+			},
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			detector, err := NewWebhookCustomRegex(tt.input.CustomRegex)
+			assert.NoError(t, err)
+			results, err := detector.FromData(context.Background(), false, []byte(tt.input.Data))
+			assert.NoError(t, err)
+
+			ignoreOpts := cmpopts.IgnoreFields(detectors.Result{}, "ExtraData", "verificationError", "primarySecret")
+			if diff := cmp.Diff(results, tt.want, ignoreOpts); diff != "" {
+				t.Errorf("CustomDetector.FromData() %s diff: (-got +want)\n%s", tt.name, diff)
+			}
+		})
+	}
+}
+
 func BenchmarkProductIndices(b *testing.B) {
 	for i := 0; i < b.N; i++ {
 		_ = productIndices(3, 2, 6)
diff --git a/pkg/custom_detectors/validation_test.go b/pkg/custom_detectors/validation_test.go
--- a/pkg/custom_detectors/validation_test.go
+++ b/pkg/custom_detectors/validation_test.go
@@ -1,6 +1,8 @@
 package custom_detectors
 
-import "testing"
+import (
+	"testing"
+)
 
 func TestCustomDetectorsKeywordValidation(t *testing.T) {
 	tests := []struct {
@@ -232,3 +234,119 @@ func TestCustomDetectorsVerifyRegexVarsValidation(t *testing.T) {
 		})
 	}
 }
+
+func TestContainsDigit(t *testing.T) {
+	type args struct {
+		s string
+	}
+	tests := []struct {
+		name string
+		args args
+		want bool
+	}{
+		{
+			name: "contains digit",
+			args: args{s: "lzscqf&60M"},
+			want: true,
+		},
+		{
+			name: "does not contains digit",
+			args: args{s: "ZlDQOdaM*vsT"},
+			want: false,
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if got := ContainsDigit(tt.args.s); got != tt.want {
+				t.Errorf("ContainsDigit() = %v, want %v", got, tt.want)
+			}
+		})
+	}
+}
+
+func TestContainsLowercase(t *testing.T) {
+	type args struct {
+		s string
+	}
+	tests := []struct {
+		name string
+		args args
+		want bool
+	}{
+		{
+			name: "contains lower case",
+			args: args{s: "g0AJBHdnhRG2"},
+			want: true,
+		},
+		{
+			name: "does not contains lower case",
+			args: args{s: "V7T#MEA6@+TN"},
+			want: false,
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if got := ContainsLowercase(tt.args.s); got != tt.want {
+				t.Errorf("ContainsDigit() = %v, want %v", got, tt.want)
+			}
+		})
+	}
+}
+
+func TestContainsUppercase(t *testing.T) {
+	type args struct {
+		s string
+	}
+	tests := []struct {
+		name string
+		args args
+		want bool
+	}{
+		{
+			name: "contains upper case",
+			args: args{s: "G1sKkJeKlSQf"},
+			want: true,
+		},
+		{
+			name: "does not contains upper case",
+			args: args{s: "pq6-14ydz1@d"},
+			want: false,
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if got := ContainsUppercase(tt.args.s); got != tt.want {
+				t.Errorf("ContainsDigit() = %v, want %v", got, tt.want)
+			}
+		})
+	}
+}
+
+func TestContainsSpecialChar(t *testing.T) {
+	type args struct {
+		s string
+	}
+	tests := []struct {
+		name string
+		args args
+		want bool
+	}{
+		{
+			name: "contains upper case",
+			args: args{s: "HP$gE7s=do0B"},
+			want: true,
+		},
+		{
+			name: "does not contains upper case",
+			args: args{s: "w9gvBYctrSjB"},
+			want: false,
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if got := ContainsSpecialChar(tt.args.s); got != tt.want {
+				t.Errorf("ContainsDigit() = %v, want %v", got, tt.want)
+			}
+		})
+	}
+}
EOF_114329324912

# Set environment variables for Go testing
export CGO_ENABLED=0
export GO111MODULE=on
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Run the target test files with appropriate timeout
# Using the package path as recommended for Go testing
go test -timeout=5m -v ./pkg/custom_detectors/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout bb899f20dc5e38352d10aedbfff6aac52435b43f "pkg/custom_detectors/custom_detectors_test.go" "pkg/custom_detectors/validation_test.go"