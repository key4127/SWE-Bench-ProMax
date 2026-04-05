#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 40025bdf43b76c4a5e5dec8ffaf9185e8904f505 "client/image_search_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/client/image_search_test.go b/client/image_search_test.go
--- a/client/image_search_test.go
+++ b/client/image_search_test.go
@@ -22,15 +22,15 @@ func TestImageSearchAnyError(t *testing.T) {
 	client := &Client{
 		client: newMockClient(errorMock(http.StatusInternalServerError, "Server error")),
 	}
-	_, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{})
+	_, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsInternal))
 }
 
 func TestImageSearchStatusUnauthorizedError(t *testing.T) {
 	client := &Client{
 		client: newMockClient(errorMock(http.StatusUnauthorized, "Unauthorized error")),
 	}
-	_, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{})
+	_, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsUnauthorized))
 }
 
@@ -41,7 +41,7 @@ func TestImageSearchWithUnauthorizedErrorAndPrivilegeFuncError(t *testing.T) {
 	privilegeFunc := func(_ context.Context) (string, error) {
 		return "", errors.New("Error requesting privilege")
 	}
-	_, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{
+	_, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{
 		PrivilegeFunc: privilegeFunc,
 	})
 	assert.Check(t, is.Error(err, "Error requesting privilege"))
@@ -54,7 +54,7 @@ func TestImageSearchWithUnauthorizedErrorAndAnotherUnauthorizedError(t *testing.
 	privilegeFunc := func(_ context.Context) (string, error) {
 		return "a-auth-header", nil
 	}
-	_, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{
+	_, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{
 		PrivilegeFunc: privilegeFunc,
 	})
 	assert.Check(t, is.ErrorType(err, cerrdefs.IsUnauthorized))
@@ -99,7 +99,7 @@ func TestImageSearchWithPrivilegedFuncNoError(t *testing.T) {
 	privilegeFunc := func(_ context.Context) (string, error) {
 		return "IAmValid", nil
 	}
-	results, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{
+	results, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{
 		RegistryAuth:  "NotValid",
 		PrivilegeFunc: privilegeFunc,
 	})
@@ -139,7 +139,7 @@ func TestImageSearchWithoutErrors(t *testing.T) {
 			}, nil
 		}),
 	}
-	results, err := client.ImageSearch(context.Background(), "some-image", SearchOptions{
+	results, err := client.ImageSearch(context.Background(), "some-image", ImageSearchOptions{
 		Filters: filters.NewArgs(
 			filters.Arg("is-automated", "true"),
 			filters.Arg("stars", "3"),
EOF_114329324912

# Verify Go environment is properly set up
export GO111MODULE=on
export CGO_ENABLED=1
export GOOS=linux
export GOARCH=amd64

# Change to the client directory and run the tests
# This approach works best with the moby/moby module structure
cd /testbed/client && go test -v -run TestImageSearch

# Capture the exit code immediately
rc=$?

# Required: Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Restore the original test file (using absolute path since we're in client dir)
cd /testbed
git checkout 40025bdf43b76c4a5e5dec8ffaf9185e8904f505 "client/image_search_test.go"