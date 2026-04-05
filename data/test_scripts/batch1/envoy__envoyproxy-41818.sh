#!/bin/bash
set -uxo pipefail

# Set environment variables
export CC=clang-18
export CXX=clang++-18
export USE_BAZEL_VERSION=7.6.2

cd /testbed

# Checkout the original test file
git checkout 033da06c08de96a64cff1051ace7923d289e2fb6 "test/common/config/datasource_test.cc"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/common/config/datasource_test.cc b/test/common/config/datasource_test.cc
--- a/test/common/config/datasource_test.cc
+++ b/test/common/config/datasource_test.cc
@@ -403,6 +403,48 @@ TEST(DataSourceProviderTest, FileDataSourceAndWithWatchButUpdateError) {
   unlink(TestEnvironment::temporaryPath("envoy_test/watcher_new_link").c_str());
 }
 
+TEST(DataSourceProviderTest, FileDataSourceAndWatchDirectoryCreationFailure) {
+  unlink(TestEnvironment::temporaryPath("envoy_test/watcher_target").c_str());
+  unlink(TestEnvironment::temporaryPath("envoy_test/watcher_link").c_str());
+
+  envoy::config::core::v3::DataSource config;
+  TestEnvironment::createPath(TestEnvironment::temporaryPath("envoy_test"));
+
+  // Use a non-existent directory path that will cause WatchedDirectory::create() to fail.
+  const std::string yaml = fmt::format(R"EOF(
+    filename: "{}"
+    watched_directory:
+      path: "/non/existent/directory/path"
+  )EOF",
+                                       TestEnvironment::temporaryPath("envoy_test/watcher_link"));
+  TestUtility::loadFromYamlAndValidate(yaml, config);
+
+  {
+    std::ofstream file(TestEnvironment::temporaryPath("envoy_test/watcher_target"));
+    file << "Hello, world!";
+    file.close();
+  }
+  TestEnvironment::createSymlink(TestEnvironment::temporaryPath("envoy_test/watcher_target"),
+                                 TestEnvironment::temporaryPath("envoy_test/watcher_link"));
+
+  EXPECT_EQ(envoy::config::core::v3::DataSource::SpecifierCase::kFilename, config.specifier_case());
+
+  Api::ApiPtr api = Api::createApiForTest();
+  Event::DispatcherPtr dispatcher = api->allocateDispatcher("test_thread");
+  NiceMock<ThreadLocal::MockInstance> tls;
+
+  // Creating a provider with an invalid watched directory path should return an error.
+  auto provider_or_error =
+      DataSource::DataSourceProvider::create(config, *dispatcher, tls, *api, false, 0);
+  EXPECT_FALSE(provider_or_error.ok());
+  EXPECT_THAT(provider_or_error.status().message(),
+              testing::HasSubstr("/non/existent/directory/path"));
+
+  // Remove the file.
+  unlink(TestEnvironment::temporaryPath("envoy_test/watcher_target").c_str());
+  unlink(TestEnvironment::temporaryPath("envoy_test/watcher_link").c_str());
+}
+
 } // namespace
 } // namespace Config
 } // namespace Envoy
EOF_114329324912

# Clean any previous build artifacts to ensure a fresh test run
bazel clean --expunge 2>/dev/null || true

# Run the specific test target with appropriate Bazel configurations
# Using --config=clang as specified in the environment
# --test_output=errors to show test failures
# --jobs=4 to limit parallelism for system stability
# --local_test_jobs=1 to run tests serially for safety
bazel test \
    --config=clang \
    --test_output=errors \
    --jobs=4 \
    --local_test_jobs=1 \
    --verbose_failures \
    //test/common/config:datasource_test

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 033da06c08de96a64cff1051ace7923d289e2fb6 "test/common/config/datasource_test.cc"