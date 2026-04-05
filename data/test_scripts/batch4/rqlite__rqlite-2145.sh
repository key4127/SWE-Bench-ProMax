#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Ensure CGO is enabled (required for SQLite C bindings)
export CGO_ENABLED=1

# Checkout the original test files to ensure clean state
git checkout 08706faa272a4dd6eb736ef90e616539553856fc "auto/backup/config_test.go" "gcp/gcs_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/auto/backup/config_test.go b/auto/backup/config_test.go
--- a/auto/backup/config_test.go
+++ b/auto/backup/config_test.go
@@ -3,13 +3,14 @@ package backup
 import (
 	"bytes"
 	"errors"
+	"fmt"
 	"os"
-	"reflect"
 	"testing"
 	"time"
 
 	"github.com/rqlite/rqlite/v8/auto"
 	"github.com/rqlite/rqlite/v8/aws"
+	"github.com/rqlite/rqlite/v8/gcp"
 )
 
 func Test_ReadConfigFile(t *testing.T) {
@@ -102,13 +103,16 @@ key2=TEST_VAR2`)
 	})
 }
 
-func TestUnmarshal(t *testing.T) {
+func Test_NewStorageClient(t *testing.T) {
+	gcsCredsFile := mustGCSCredFile(t)
+	defer os.Remove(gcsCredsFile)
+
 	testCases := []struct {
-		name        string
-		input       []byte
-		expectedCfg *Config
-		expectedS3  *aws.S3Config
-		expectedErr error
+		name           string
+		input          []byte
+		expectedCfg    *Config
+		expectedClient StorageClient
+		expectedErr    error
 	}{
 		{
 			name: "ValidS3Config",
@@ -137,14 +141,8 @@ func TestUnmarshal(t *testing.T) {
 				Vacuum:     true,
 				Interval:   24 * auto.Duration(time.Hour),
 			},
-			expectedS3: &aws.S3Config{
-				AccessKeyID:     "test_id",
-				SecretAccessKey: "test_secret",
-				Region:          "us-west-2",
-				Bucket:          "test_bucket",
-				Path:            "test/path",
-			},
-			expectedErr: nil,
+			expectedClient: mustNewS3Client(t, "", "us-west-2", "test_id", "test_secret", "test_bucket", "test/path"),
+			expectedErr:    nil,
 		},
 		{
 			name: "ValidS3ConfigNoptionalFields",
@@ -171,14 +169,34 @@ func TestUnmarshal(t *testing.T) {
 				Interval:   24 * auto.Duration(time.Hour),
 				Vacuum:     false,
 			},
-			expectedS3: &aws.S3Config{
-				AccessKeyID:     "test_id",
-				SecretAccessKey: "test_secret",
-				Region:          "us-west-2",
-				Bucket:          "test_bucket",
-				Path:            "test/path",
+			expectedClient: mustNewS3Client(t, "", "us-west-2", "test_id", "test_secret", "test_bucket", "test/path"),
+			expectedErr:    nil,
+		},
+		{
+			name: "ValidGCSConfig",
+			input: []byte(fmt.Sprintf(`{
+				           "version": 1,
+				           "type": "gcs",
+				           "no_compress": true,
+				           "timestamp": true,
+				           "interval": "24h",
+				           "sub": {
+				               "bucket": "test_bucket",
+				               "name": "test/path",
+				               "project_id": "test_project",
+				               "credentials_path": %q
+				           }
+				       }`, gcsCredsFile)),
+			expectedCfg: &Config{
+				Version:    1,
+				Type:       "gcs",
+				NoCompress: true,
+				Timestamp:  true,
+				Vacuum:     true,
+				Interval:   24 * auto.Duration(time.Hour),
 			},
-			expectedErr: nil,
+			expectedClient: mustNewGCSClient(t, "test_bucket", "test/path", "test_project", gcsCredsFile),
+			expectedErr:    nil,
 		},
 		{
 			name: "InvalidVersion",
@@ -197,7 +215,6 @@ func TestUnmarshal(t *testing.T) {
 				}
 			}			`),
 			expectedCfg: nil,
-			expectedS3:  nil,
 			expectedErr: auto.ErrInvalidVersion,
 		},
 		{
@@ -217,28 +234,36 @@ func TestUnmarshal(t *testing.T) {
 				}
 			}			`),
 			expectedCfg: nil,
-			expectedS3:  nil,
 			expectedErr: auto.ErrUnsupportedStorageType,
 		},
 	}
 
 	for _, tc := range testCases {
 		t.Run(tc.name, func(t *testing.T) {
-			cfg, s3Cfg, err := Unmarshal(tc.input)
-			_ = s3Cfg
-
+			cfg, sc, err := NewStorageClient(tc.input)
 			if !errors.Is(err, tc.expectedErr) {
 				t.Fatalf("Test case %s failed, expected error %v, got %v", tc.name, tc.expectedErr, err)
 			}
 
-			if !compareConfig(cfg, tc.expectedCfg) {
-				t.Fatalf("Test case %s failed, expected config %+v, got %+v", tc.name, tc.expectedCfg, cfg)
+			if tc.expectedClient != nil {
+				switch tc.expectedClient.(type) {
+				case *aws.S3Client:
+					_, ok := sc.(*aws.S3Client)
+					if !ok {
+						t.Fatalf("Test case %s failed, expected S3Client, got %T", tc.name, sc)
+					}
+				case *gcp.GCSClient:
+					_, ok := sc.(*gcp.GCSClient)
+					if !ok {
+						t.Fatalf("Test case %s failed, expected GCSClient, got %T", tc.name, sc)
+					}
+				default:
+					t.Fatalf("Test case %s failed, unexpected client type %T", tc.name, sc)
+				}
 			}
 
-			if tc.expectedS3 != nil {
-				if !reflect.DeepEqual(s3Cfg, tc.expectedS3) {
-					t.Fatalf("Test case %s failed, expected S3Config %+v, got %+v", tc.name, tc.expectedS3, s3Cfg)
-				}
+			if !compareConfig(cfg, tc.expectedCfg) {
+				t.Fatalf("Test case %s failed, expected config %+v, got %+v", tc.name, tc.expectedCfg, cfg)
 			}
 		})
 	}
@@ -253,3 +278,40 @@ func compareConfig(a, b *Config) bool {
 		a.NoCompress == b.NoCompress &&
 		a.Interval == b.Interval
 }
+
+func mustNewS3Client(t *testing.T, endpoint, region, accessKey, secretKey, bucket, key string) *aws.S3Client {
+	t.Helper()
+	client, err := aws.NewS3Client(endpoint, region, accessKey, secretKey, bucket, key, nil)
+	if err != nil {
+		t.Fatalf("Failed to create S3 client: %v", err)
+	}
+	return client
+}
+
+func mustNewGCSClient(t *testing.T, bucket, name, projectID, credentialsFile string) *gcp.GCSClient {
+	t.Helper()
+	client, err := gcp.NewGCSClient(&gcp.GCSConfig{
+		Bucket:          bucket,
+		Name:            name,
+		ProjectID:       projectID,
+		CredentialsPath: credentialsFile,
+	})
+	if err != nil {
+		t.Fatalf("Failed to create GCS client: %v", err)
+	}
+	return client
+}
+
+func mustGCSCredFile(t *testing.T) string {
+	t.Helper()
+	f, err := os.CreateTemp("", "cred-*.json")
+	if err != nil {
+		t.Fatalf("temp file: %v", err)
+	}
+	cred := `{"client_email":"test@example.com","private_key":"-----BEGIN PRIVATE KEY----------END PRIVATE KEY-----"}`
+	if _, err = f.WriteString(cred); err != nil {
+		t.Fatalf("write cred: %v", err)
+	}
+	f.Close()
+	return f.Name()
+}
diff --git a/gcp/gcs_test.go b/gcp/gcs_test.go
--- a/gcp/gcs_test.go
+++ b/gcp/gcs_test.go
@@ -17,6 +17,37 @@ import (
 	"time"
 )
 
+func Test_NewGCSClient(t *testing.T) {
+	cfg := &GCSConfig{
+		Endpoint:        "http://localhost:8080",
+		ProjectID:       "proj",
+		Bucket:          "mybucket",
+		Name:            "object.txt",
+		CredentialsPath: createCredFile(t), // dummy, never used
+	}
+
+	cli, err := NewGCSClient(cfg)
+	if err != nil {
+		t.Fatalf("NewGCSClient: %v", err)
+	}
+
+	if cli.cfg.ProjectID != "proj" {
+		t.Errorf("ProjectID = %s, want proj", cli.cfg.ProjectID)
+	}
+	if cli.cfg.Bucket != "mybucket" {
+		t.Errorf("Bucket = %s, want mybucket", cli.cfg.Bucket)
+	}
+	if cli.cfg.Name != "object.txt" {
+		t.Errorf("Name = %s, want object.txt", cli.cfg.Name)
+	}
+	if cli.cfg.Endpoint != "http://localhost:8080" {
+		t.Errorf("Endpoint = %s, want http://localhost:8080", cli.cfg.Endpoint)
+	}
+	if cli.cfg.CredentialsPath != cli.cfg.CredentialsPath {
+		t.Errorf("CredentialsPath = %s, want empty", cli.cfg.CredentialsPath)
+	}
+}
+
 func Test_EnsureBucketExists(t *testing.T) {
 	var gotPath string
 	handler := func(w http.ResponseWriter, r *http.Request) {
EOF_114329324912

# Execute tests for the specified packages
# Running both test packages in sequence to ensure all tests are executed
go test -v -failfast ./auto/backup/ ./gcp/
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 08706faa272a4dd6eb736ef90e616539553856fc "auto/backup/config_test.go" "gcp/gcs_test.go"