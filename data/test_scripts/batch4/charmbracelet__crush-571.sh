#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit and test files
git checkout 989e56eb6f1873593791adb8230c6d403372c1e1 "internal/tui/components/core/status_test.go" "internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden" "internal/tui/components/core/testdata/TestStatus/Default.golden" "internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden" "internal/tui/components/core/testdata/TestStatus/LongDescription.golden" "internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden" "internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden" "internal/tui/components/core/testdata/TestStatus/WithColors.golden" "internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden" "internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden"

# Apply test patch (adds/modifies test files)
git apply -v - <<'EOF_114329324912'
diff --git a/internal/tui/components/core/status_test.go b/internal/tui/components/core/status_test.go
--- a/internal/tui/components/core/status_test.go
+++ b/internal/tui/components/core/status_test.go
@@ -37,7 +37,6 @@ func TestStatus(t *testing.T) {
 		{
 			name: "NoIcon",
 			opts: core.StatusOpts{
-				NoIcon:      true,
 				Title:       "Info",
 				Description: "This status has no icon",
 			},
@@ -47,7 +46,6 @@ func TestStatus(t *testing.T) {
 			name: "WithColors",
 			opts: core.StatusOpts{
 				Icon:             "⚠",
-				IconColor:        color.RGBA{255, 165, 0, 255}, // Orange
 				Title:            "Warning",
 				TitleColor:       color.RGBA{255, 255, 0, 255}, // Yellow
 				Description:      "This is a warning message",
@@ -102,7 +100,6 @@ func TestStatus(t *testing.T) {
 			name: "AllFieldsWithExtraContent",
 			opts: core.StatusOpts{
 				Icon:             "🚀",
-				IconColor:        color.RGBA{0, 255, 0, 255}, // Green
 				Title:            "Deployment",
 				TitleColor:       color.RGBA{0, 0, 255, 255}, // Blue
 				Description:      "Deploying to production environment",
diff --git a/internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden b/internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden
--- a/internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden
+++ b/internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden
@@ -1 +1 @@
-[38;2;0;255;0m🚀[m [38;2;0;0;255mDeployment[m [38;2;128;128;128mDeploying to production environment[m v1.2.3
\ No newline at end of file
+🚀 [38;2;0;0;255mDeployment[m [38;2;128;128;128mDeploying to production environment[m v1.2.3
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/Default.golden b/internal/tui/components/core/testdata/TestStatus/Default.golden
--- a/internal/tui/components/core/testdata/TestStatus/Default.golden
+++ b/internal/tui/components/core/testdata/TestStatus/Default.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mStatus[m [38;2;96;95;107mEverything is working fine[m
\ No newline at end of file
+[38;2;133;131;146mStatus[m [38;2;96;95;107mEverything is working fine[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden b/internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden
--- a/internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden
+++ b/internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mTitle Only[m [38;2;96;95;107m[m
\ No newline at end of file
+● [38;2;133;131;146mTitle Only[m [38;2;96;95;107m[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/LongDescription.golden b/internal/tui/components/core/testdata/TestStatus/LongDescription.golden
--- a/internal/tui/components/core/testdata/TestStatus/LongDescription.golden
+++ b/internal/tui/components/core/testdata/TestStatus/LongDescription.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mProcessing[m [38;2;96;95;107mThis is a very long description that should be…[m
\ No newline at end of file
+[38;2;133;131;146mProcessing[m [38;2;96;95;107mThis is a very long description that should be …[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden b/internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden
--- a/internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden
+++ b/internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mStatus[m [38;2;96;95;107mShort message[m
\ No newline at end of file
+● [38;2;133;131;146mStatus[m [38;2;96;95;107mShort message[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden b/internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden
--- a/internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden
+++ b/internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mTest[m [38;2;96;95;107mThis will be…[m
\ No newline at end of file
+● [38;2;133;131;146mTest[m [38;2;96;95;107mThis will be…[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/WithColors.golden b/internal/tui/components/core/testdata/TestStatus/WithColors.golden
--- a/internal/tui/components/core/testdata/TestStatus/WithColors.golden
+++ b/internal/tui/components/core/testdata/TestStatus/WithColors.golden
@@ -1 +1 @@
-[38;2;255;165;0m⚠[m [38;2;255;255;0mWarning[m [38;2;255;0;0mThis is a warning message[m
\ No newline at end of file
+⚠ [38;2;255;255;0mWarning[m [38;2;255;0;0mThis is a warning message[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden b/internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden
--- a/internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden
+++ b/internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden
@@ -1 +1 @@
-[38;2;18;199;143m✓[m [38;2;133;131;146mSuccess[m [38;2;96;95;107mOperation completed successfully[m
\ No newline at end of file
+✓ [38;2;133;131;146mSuccess[m [38;2;96;95;107mOperation completed successfully[m
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden b/internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden
--- a/internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden
+++ b/internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mBuild[m [38;2;96;95;107mBuilding project[m [2/5]
\ No newline at end of file
+[38;2;133;131;146mBuild[m [38;2;96;95;107mBuilding project[m [2/5]
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden b/internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden
--- a/internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden
+++ b/internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mVery Long Title[m [38;2;96;95;107m[m [extra]
\ No newline at end of file
+● [38;2;133;131;146mVery Long Title[m [38;2;96;95;107m[m [extra]
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden b/internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden
--- a/internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden
+++ b/internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThi…[m [extra]
\ No newline at end of file
+● [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThi…[m [extra]
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden b/internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden
--- a/internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden
+++ b/internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an ex…[m [extra]
\ No newline at end of file
+● [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an ex…[m [extra]
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden b/internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden
--- a/internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden
+++ b/internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an extremely lo…[m [extra]
\ No newline at end of file
+● [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an extremely lo…[m [extra]
\ No newline at end of file
diff --git a/internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden b/internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden
--- a/internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden
+++ b/internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden
@@ -1 +1 @@
-[38;2;18;199;143m●[m [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an extremely long descrip…[m [extra]
\ No newline at end of file
+● [38;2;133;131;146mVery Long Title[m [38;2;96;95;107mThis is an extremely long descrip…[m [extra]
\ No newline at end of file
EOF_114329324912

# Verify Go environment is properly set
export GO111MODULE=on
export CGO_ENABLED=0
export GOPROXY=https://proxy.golang.org,direct

# Ensure dependencies are available
go mod download

# Run the specific tests for status component
# Using -v for verbose output to see which tests are executed
# Using -count=1 to disable test caching and ensure fresh runs
# Using -run to execute only TestStatus and TestStatusTruncation tests
go test -v -count=1 ./internal/tui/components/core -run "^(TestStatus|TestStatusTruncation)$"
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes made by the test patch
git checkout 989e56eb6f1873593791adb8230c6d403372c1e1 "internal/tui/components/core/status_test.go" "internal/tui/components/core/testdata/TestStatus/AllFieldsWithExtraContent.golden" "internal/tui/components/core/testdata/TestStatus/Default.golden" "internal/tui/components/core/testdata/TestStatus/EmptyDescription.golden" "internal/tui/components/core/testdata/TestStatus/LongDescription.golden" "internal/tui/components/core/testdata/TestStatus/NarrowWidth.golden" "internal/tui/components/core/testdata/TestStatus/VeryNarrowWidth.golden" "internal/tui/components/core/testdata/TestStatus/WithColors.golden" "internal/tui/components/core/testdata/TestStatus/WithCustomIcon.golden" "internal/tui/components/core/testdata/TestStatus/WithExtraContent.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width20.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width30.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width40.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width50.golden" "internal/tui/components/core/testdata/TestStatusTruncation/Width60.golden"