#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Reset the target test file to the original commit state
git checkout ea77a9ab67d8c04f513adaf0a1c648c738e25922 "modules/caddyhttp/fileserver/matcher_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/caddyhttp/fileserver/matcher_test.go b/modules/caddyhttp/fileserver/matcher_test.go
--- a/modules/caddyhttp/fileserver/matcher_test.go
+++ b/modules/caddyhttp/fileserver/matcher_test.go
@@ -117,7 +117,7 @@ func TestFileMatcher(t *testing.T) {
 		},
 	} {
 		m := &MatchFile{
-			fsmap:    &filesystems.FilesystemMap{},
+			fsmap:    &filesystems.FileSystemMap{},
 			Root:     "./testdata",
 			TryFiles: []string{"{http.request.uri.path}", "{http.request.uri.path}/"},
 		}
@@ -229,7 +229,7 @@ func TestPHPFileMatcher(t *testing.T) {
 		},
 	} {
 		m := &MatchFile{
-			fsmap:     &filesystems.FilesystemMap{},
+			fsmap:     &filesystems.FileSystemMap{},
 			Root:      "./testdata",
 			TryFiles:  []string{"{http.request.uri.path}", "{http.request.uri.path}/index.php"},
 			SplitPath: []string{".php"},
@@ -273,7 +273,7 @@ func TestPHPFileMatcher(t *testing.T) {
 func TestFirstSplit(t *testing.T) {
 	m := MatchFile{
 		SplitPath: []string{".php"},
-		fsmap:     &filesystems.FilesystemMap{},
+		fsmap:     &filesystems.FileSystemMap{},
 	}
 	actual, remainder := m.firstSplit("index.PHP/somewhere")
 	expected := "index.PHP"
EOF_114329324912

# Execute the tests using the module path to ensure proper compilation with all dependencies
go test -v ./modules/caddyhttp/fileserver/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Reset the test file back to the original state
git checkout ea77a9ab67d8c04f513adaf0a1c648c738e25922 "modules/caddyhttp/fileserver/matcher_test.go"