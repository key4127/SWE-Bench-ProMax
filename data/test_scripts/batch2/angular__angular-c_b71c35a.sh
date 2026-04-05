#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 397f9987efa989b345fd0399cd553f59cd2ec391 \
  "packages/bazel/test/ngc-wrapped/BUILD.bazel" \
  "packages/language-service/test/legacy/BUILD.bazel" \
  "tools/testing/BUILD.bazel"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/bazel/test/ngc-wrapped/BUILD.bazel b/packages/bazel/test/ngc-wrapped/BUILD.bazel
--- a/packages/bazel/test/ngc-wrapped/BUILD.bazel
+++ b/packages/bazel/test/ngc-wrapped/BUILD.bazel
@@ -21,7 +21,8 @@ ts_library(
 # .d.ts files (by default, jasmine_node_test would get the .js files).
 filegroup(
     name = "angular_core",
-    srcs = ["//packages/core"],
+    srcs = ["//packages/core:core_rjs"],
+    output_group = "types",
 )
 
 jasmine_node_test(
diff --git a/packages/language-service/test/legacy/BUILD.bazel b/packages/language-service/test/legacy/BUILD.bazel
--- a/packages/language-service/test/legacy/BUILD.bazel
+++ b/packages/language-service/test/legacy/BUILD.bazel
@@ -14,6 +14,14 @@ ts_library(
     ],
 )
 
+filegroup(
+    name = "package_types",
+    srcs = [
+        "//packages/core:core_rjs",
+    ],
+    output_group = "types",
+)
+
 jasmine_node_test(
     name = "legacy",
     data = [
@@ -23,8 +31,8 @@ jasmine_node_test(
         # npm_package. Ivy does not currently produce flat dts, so we might
         # as well just depend on the outputs of ng_module.
         "//packages/common",
-        "//packages/core",
         "//packages/forms",
+        ":package_types",
         ":project",
     ],
     deps = [
diff --git a/tools/testing/BUILD.bazel b/tools/testing/BUILD.bazel
--- a/tools/testing/BUILD.bazel
+++ b/tools/testing/BUILD.bazel
@@ -103,6 +103,7 @@ jasmine_node_test(
     name = "fail_bootstrap_test",
     srcs = ["fail.spec.js"],
     bootstrap = ["//tools/testing:node"],
+    data = ["//packages:package_json"],
     # While we force the termination of the process with an exitCode of 55 in fail.spec.js. Jasmine force it to 4.
     # see: https://github.com/jasmine/jasmine-npm/blob/eea8b26efe29176ecbb26ce3f1c4990f8bede685/lib/jasmine.js#L213
     expected_exit_code = 4,
EOF_114329324912

# Run the Bazel tests for all three target packages
# Using --test_output=errors for cleaner output (only shows failures)
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/bazel/test/ngc-wrapped/... \
  //packages/language-service/test/legacy:legacy \
  //tools/testing/... \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 397f9987efa989b345fd0399cd553f59cd2ec391 \
  "packages/bazel/test/ngc-wrapped/BUILD.bazel" \
  "packages/language-service/test/legacy/BUILD.bazel" \
  "tools/testing/BUILD.bazel"

exit $rc