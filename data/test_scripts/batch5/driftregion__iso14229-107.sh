#!/bin/bash
set -uxo pipefail

# Check if running as root and switch to testuser if needed
if [ "$(id -u)" -eq 0 ]; then
    exec sudo -u testuser bash "$0" "$@"
fi

cd /testbed

# Checkout the target test files to ensure clean state
git checkout 8860fa12a5911f23b02ce0421eff62fef433d7f6 "test/BUILD" "test/test_version.sh"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/BUILD b/test/BUILD
--- a/test/BUILD
+++ b/test/BUILD
@@ -94,6 +94,7 @@ sh_test(
     data = [
         "//src:iso14229.h",
         "//:README.md",
+        "//:Doxyfile",
     ],
 )
 
diff --git a/test/test_version.sh b/test/test_version.sh
--- a/test/test_version.sh
+++ b/test/test_version.sh
@@ -1,13 +1,24 @@
 #!/bin/bash
 
-# test that the version in src/version.h matches that in README.md changelog
+# test that all version listings are consistent
 
-VERSION_H_VERSION=$(sed -n 's/^#define UDS_VERSION "\(.*\)"/\1/p' $1)
+VERSION_H_VERSION=$(sed -n 's/^#define UDS_LIB_VERSION "\(.*\)"/\1/p' $1)
 README_VERSION=$(sed -n '/^## [0-9]\+\.[0-9]\+\.[0-9]\+/ { s/^## \([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/; p; q }' README.md)
+DOXYGEN_VERSION=$(sed -n 's/^PROJECT_NUMBER\s*=\s*"\(.*\)"/\1/p' Doxyfile)
 
 if [ "$VERSION_H_VERSION" != "$README_VERSION" ]; then
     echo "Version mismatch:"
     echo "  $1: $VERSION_H_VERSION"
     echo "  README.md: $README_VERSION"
     exit 1
 fi
+
+if [ "$VERSION_H_VERSION" != "$DOXYGEN_VERSION" ]; then
+    echo "Version mismatch:"
+    echo "  $1: $VERSION_H_VERSION"
+    echo "  Doxyfile: $DOXYGEN_VERSION"
+    exit 1
+fi
+
+echo "All version listings are consistent: $VERSION_H_VERSION"
+exit 0
EOF_114329324912

# Execute the target test using Bazel
# The test_version.sh script validates version consistency between src/version.h and README.md
bazel test //test:test_version --test_output=all --verbose_failures
rc=$?

# Capture and report the exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 8860fa12a5911f23b02ce0421eff62fef433d7f6 "test/BUILD" "test/test_version.sh"