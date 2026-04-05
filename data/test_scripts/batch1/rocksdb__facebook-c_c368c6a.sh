#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout 1614345a525cfa43c11725936dba446529e00cb5 "db/blob/blob_file_builder_test.cc" "db/blob/blob_file_reader_test.cc" "db/blob/blob_source_test.cc"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/db/blob/blob_file_builder_test.cc b/db/blob/blob_file_builder_test.cc
--- a/db/blob/blob_file_builder_test.cc
+++ b/db/blob/blob_file_builder_test.cc
@@ -405,10 +405,9 @@ TEST_F(BlobFileBuilderTest, Compression) {
 
   CompressionOptions opts;
   CompressionContext context(kSnappyCompression, opts);
-  constexpr uint64_t sample_for_compression = 0;
 
   CompressionInfo info(opts, context, CompressionDict::GetEmptyDict(),
-                       kSnappyCompression, sample_for_compression);
+                       kSnappyCompression);
 
   std::string compressed_value;
   ASSERT_TRUE(Snappy_Compress(info, uncompressed_value.data(),
diff --git a/db/blob/blob_file_reader_test.cc b/db/blob/blob_file_reader_test.cc
--- a/db/blob/blob_file_reader_test.cc
+++ b/db/blob/blob_file_reader_test.cc
@@ -75,9 +75,8 @@ void WriteBlobFile(const ImmutableOptions& immutable_options,
   } else {
     CompressionOptions opts;
     CompressionContext context(compression, opts);
-    constexpr uint64_t sample_for_compression = 0;
     CompressionInfo info(opts, context, CompressionDict::GetEmptyDict(),
-                         compression, sample_for_compression);
+                         compression);
 
     constexpr uint32_t compression_format_version = 2;
 
diff --git a/db/blob/blob_source_test.cc b/db/blob/blob_source_test.cc
--- a/db/blob/blob_source_test.cc
+++ b/db/blob/blob_source_test.cc
@@ -77,9 +77,8 @@ void WriteBlobFile(const ImmutableOptions& immutable_options,
   } else {
     CompressionOptions opts;
     CompressionContext context(compression, opts);
-    constexpr uint64_t sample_for_compression = 0;
     CompressionInfo info(opts, context, CompressionDict::GetEmptyDict(),
-                         compression, sample_for_compression);
+                         compression);
 
     constexpr uint32_t compression_format_version = 2;
 
EOF_114329324912

# Build the specific test binaries
make blob_file_builder_test blob_file_reader_test blob_source_test

# Run the test binaries and capture results
# Initialize exit code
rc=0

# Run blob_file_builder_test
echo "=========================================="
echo "Running blob_file_builder_test"
echo "=========================================="
./blob_file_builder_test
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=$test_rc
    echo "blob_file_builder_test FAILED with exit code $test_rc"
else
    echo "blob_file_builder_test PASSED"
fi

# Run blob_file_reader_test
echo "=========================================="
echo "Running blob_file_reader_test"
echo "=========================================="
./blob_file_reader_test
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=$test_rc
    echo "blob_file_reader_test FAILED with exit code $test_rc"
else
    echo "blob_file_reader_test PASSED"
fi

# Run blob_source_test
echo "=========================================="
echo "Running blob_source_test"
echo "=========================================="
./blob_source_test
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=$test_rc
    echo "blob_source_test FAILED with exit code $test_rc"
else
    echo "blob_source_test PASSED"
fi

# Output final exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 1614345a525cfa43c11725936dba446529e00cb5 "db/blob/blob_file_builder_test.cc" "db/blob/blob_file_reader_test.cc" "db/blob/blob_source_test.cc"