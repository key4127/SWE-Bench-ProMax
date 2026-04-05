#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 6bdd79f29071408c455c07e5b8fb53d5b197e100 "Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp" "Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp" "Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp
--- a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp
+++ b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp
@@ -47,6 +47,11 @@ TEST(FrameAccumulator, testBufferReturnDeallocation) {
     tester.testBufferReturnDeallocation();
 }
 
+TEST(FrameAccumulator, testDetectionErrorHandling) {
+    Svc::FrameAccumulatorTester tester;
+    tester.testDetectionErrorHandling();
+}
+
 int main(int argc, char** argv) {
     STest::Random::seed();
     ::testing::InitGoogleTest(&argc, argv);
diff --git a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp
--- a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp
+++ b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp
@@ -160,6 +160,49 @@ void FrameAccumulatorTester ::testBufferReturnDeallocation() {
     ASSERT_EQ(this->fromPortHistory_bufferDeallocate->at(0).fwBuffer.getSize(), sizeof(data));
 }
 
+void FrameAccumulatorTester ::testDetectionErrorHandling() {
+    FwSizeType too_large_size = this->component.m_inRing.get_capacity() + 1;
+    // Using buffer_size=1 to simplify test since otherwise Accumulator will loop `buffer_size` times
+    Fw::Buffer::SizeType buffer_size = 1;
+    U8 data[buffer_size];
+    Fw::Buffer buffer(data, buffer_size);
+    ComCfg::FrameContext context;
+
+    // Too large size reported by detector should emit event and continue
+    this->mockDetector.set_next_result(FrameDetector::Status::FRAME_DETECTED, too_large_size);
+    this->invoke_to_dataIn(0, buffer, context);
+    // Checks
+    ASSERT_from_dataReturnOut_SIZE(1);                         // input buffer ownership was returned
+    ASSERT_from_dataOut_SIZE(0);                               // No frame was sent out
+    ASSERT_EVENTS_SIZE(1);                                     // One event should be logged:
+    ASSERT_EVENTS_FrameDetectionSizeError_SIZE(1);             // FrameDetectionSizeError
+    ASSERT_EVENTS_FrameDetectionSizeError(0, too_large_size);  // with expected size_out
+
+    this->clearHistory();
+
+    // Too large size reported by detector should emit event and continue
+    this->mockDetector.set_next_result(FrameDetector::Status::MORE_DATA_NEEDED, too_large_size);
+    this->invoke_to_dataIn(0, buffer, context);
+    // Checks
+    ASSERT_from_dataReturnOut_SIZE(1);                         // input buffer ownership was returned
+    ASSERT_from_dataOut_SIZE(0);                               // No frame was sent out
+    ASSERT_EVENTS_SIZE(1);                                     // One event should be logged:
+    ASSERT_EVENTS_FrameDetectionSizeError_SIZE(1);             // FrameDetectionSizeError
+    ASSERT_EVENTS_FrameDetectionSizeError(0, too_large_size);  // with expected size_out
+
+    this->clearHistory();
+
+    // Too large size reported by detector should emit event and continue
+    this->mockDetector.set_next_result(FrameDetector::Status::NO_FRAME_DETECTED, too_large_size);
+    this->invoke_to_dataIn(0, buffer, context);
+    // Checks
+    ASSERT_from_dataReturnOut_SIZE(1);                         // input buffer ownership was returned
+    ASSERT_from_dataOut_SIZE(0);                               // No frame was sent out
+    ASSERT_EVENTS_SIZE(1);                                     // One event should be logged:
+    ASSERT_EVENTS_FrameDetectionSizeError_SIZE(1);             // FrameDetectionSizeError
+    ASSERT_EVENTS_FrameDetectionSizeError(0, too_large_size);  // with expected size_out
+}
+
 // ----------------------------------------------------------------------
 // Helper functions
 // ----------------------------------------------------------------------
diff --git a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp
--- a/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp
+++ b/Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp
@@ -66,6 +66,9 @@ class FrameAccumulatorTester : public FrameAccumulatorGTestBase {
     //! Test returning ownership of a buffer
     void testBufferReturnDeallocation();
 
+    //! Test handling of errors from the FrameDetector (too large size_out)
+    void testDetectionErrorHandling();
+
   private:
     // ----------------------------------------------------------------------
     // Helper functions
EOF_114329324912

# Navigate to FrameAccumulator directory
cd /testbed/Svc/FrameAccumulator

# Generate the build system for unit tests
fprime-util generate --ut

# Build the unit tests with limited parallelism (max 4 jobs for system stability)
fprime-util build --ut --jobs 4

# Set environment variable for test output
export CTEST_OUTPUT_ON_FAILURE=1

# Run the FrameAccumulator unit tests
fprime-util check

# Capture the exit code immediately
rc=$?

echo ""
echo "=== Test Execution Summary ==="
echo "Exit code: $rc"
echo ""
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 6bdd79f29071408c455c07e5b8fb53d5b197e100 "Svc/FrameAccumulator/test/ut/FrameAccumulatorTestMain.cpp" "Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.cpp" "Svc/FrameAccumulator/test/ut/FrameAccumulatorTester.hpp"