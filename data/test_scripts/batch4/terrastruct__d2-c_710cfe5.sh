#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 73d5942b087043586f9007418ea8a1757a1eb780 "d2chaos/d2chaos_test.go" "d2renderers/d2svg/dark_theme/dark_theme_test.go" "e2etests-cli/main_test.go" "e2etests/report/main.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/d2chaos/d2chaos_test.go b/d2chaos/d2chaos_test.go
--- a/d2chaos/d2chaos_test.go
+++ b/d2chaos/d2chaos_test.go
@@ -3,7 +3,6 @@ package d2chaos_test
 import (
 	"context"
 	"fmt"
-	"io/ioutil"
 	"os"
 	"path/filepath"
 	"runtime/debug"
@@ -90,14 +89,14 @@ func TestD2Chaos(t *testing.T) {
 
 func test(t *testing.T, textPath, text string) {
 	t.Logf("writing d2 to %v (%d bytes)", textPath, len(text))
-	err := ioutil.WriteFile(textPath, []byte(text), 0644)
+	err := os.WriteFile(textPath, []byte(text), 0644)
 	if err != nil {
 		t.Fatal(err)
 	}
 
 	goencText := fmt.Sprintf("%#v", text)
 	t.Logf("writing d2.goenc to %v (%d bytes)", textPath+".goenc", len(goencText))
-	err = ioutil.WriteFile(textPath+".goenc", []byte(goencText), 0644)
+	err = os.WriteFile(textPath+".goenc", []byte(goencText), 0644)
 	if err != nil {
 		t.Fatal(err)
 	}
diff --git a/d2renderers/d2svg/dark_theme/dark_theme_test.go b/d2renderers/d2svg/dark_theme/dark_theme_test.go
--- a/d2renderers/d2svg/dark_theme/dark_theme_test.go
+++ b/d2renderers/d2svg/dark_theme/dark_theme_test.go
@@ -3,7 +3,6 @@ package dark_theme_test
 import (
 	"context"
 	"encoding/xml"
-	"io/ioutil"
 	"log/slog"
 	"os"
 	"path/filepath"
@@ -449,7 +448,7 @@ func run(t *testing.T, tc testCase) {
 	assert.Success(t, err)
 	err = os.MkdirAll(dataPath, 0755)
 	assert.Success(t, err)
-	err = ioutil.WriteFile(pathGotSVG, svgBytes, 0600)
+	err = os.WriteFile(pathGotSVG, svgBytes, 0600)
 	assert.Success(t, err)
 	defer os.Remove(pathGotSVG)
 
diff --git a/e2etests-cli/main_test.go b/e2etests-cli/main_test.go
--- a/e2etests-cli/main_test.go
+++ b/e2etests-cli/main_test.go
@@ -13,7 +13,7 @@ import (
 	"testing"
 	"time"
 
-	"nhooyr.io/websocket"
+	"github.com/coder/websocket"
 
 	"oss.terrastruct.com/util-go/assert"
 	"oss.terrastruct.com/util-go/diff"
diff --git a/e2etests/report/main.go b/e2etests/report/main.go
--- a/e2etests/report/main.go
+++ b/e2etests/report/main.go
@@ -5,7 +5,6 @@ import (
 	_ "embed"
 	"flag"
 	"fmt"
-	"io/ioutil"
 	stdlog "log"
 	"os"
 	"os/exec"
@@ -104,15 +103,15 @@ func main() {
 			return err
 		}
 		if info.IsDir() {
-			files, err := ioutil.ReadDir(path)
+			files, err := os.ReadDir(path)
 			if err != nil {
 				panic(err)
 			}
 
 			var testFile os.FileInfo
 			for _, f := range files {
 				if strings.HasSuffix(f.Name(), "exp.svg") {
-					testFile = f
+					testFile, _ = f.Info()
 					break
 				}
 			}
EOF_114329324912

# Execute the test files
# Note: e2etests/report/main.go is not a test file, it's a utility program
# We'll run the three actual test files with a 30-minute timeout

# Run tests for the specified test files
# Combining test execution for efficiency while maintaining clarity
go test --timeout=30m -v ./d2chaos/ ./d2renderers/d2svg/dark_theme/ ./e2etests-cli/
rc=$?

# Capture the exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 73d5942b087043586f9007418ea8a1757a1eb780 "d2chaos/d2chaos_test.go" "d2renderers/d2svg/dark_theme/dark_theme_test.go" "e2etests-cli/main_test.go" "e2etests/report/main.go"