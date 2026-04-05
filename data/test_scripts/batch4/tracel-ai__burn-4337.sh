#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 868d8845d4a758500f18d47932bf6534309bc1d8 "crates/burn-backend-tests/tests/tensor/float/ops/full.rs" "crates/burn-fusion/src/stream/execution/tests.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/crates/burn-backend-tests/tests/tensor/float/ops/full.rs b/crates/burn-backend-tests/tests/tensor/float/ops/full.rs
--- a/crates/burn-backend-tests/tests/tensor/float/ops/full.rs
+++ b/crates/burn-backend-tests/tests/tensor/float/ops/full.rs
@@ -22,7 +22,6 @@ fn test_tensor_full_options() {
     let tensor = TestTensor::<2>::full([2, 3], 2.1, (&Default::default(), DType::F32));
     assert_eq!(tensor.dtype(), DType::F32);
 
-    // TODO: `Tensor::full` should not use `FloatElem<B>` for `fill_value`.
     tensor
         .into_data()
         .assert_eq(&TensorData::from([[2.1, 2.1, 2.1], [2.1, 2.1, 2.1]]), false);
diff --git a/crates/burn-fusion/src/stream/execution/tests.rs b/crates/burn-fusion/src/stream/execution/tests.rs
--- a/crates/burn-fusion/src/stream/execution/tests.rs
+++ b/crates/burn-fusion/src/stream/execution/tests.rs
@@ -638,7 +638,7 @@ pub fn operation_2() -> OperationIr {
                 status: TensorStatus::ReadOnly,
                 dtype: DType::F32,
             },
-            rhs: ScalarIr::F32(5.0),
+            rhs: ScalarIr::Float(5.0),
             out: TensorIr {
                 id: TensorId::new(2),
                 shape: Shape::new([32, 32]),
EOF_114329324912

# Set environment variable for better error reporting
export RUST_BACKTRACE=1

# Run the burn-backend-tests for the tensor integration test target
# This includes tests from tests/tensor/float/ops/full.rs
# Using --release as per project convention
# Using --no-default-features and --features ndarray,std as required for backend tests
# Using --test-threads=1 for stability in virtualized environment
cargo test -p burn-backend-tests --release --no-default-features --features ndarray,std --test tensor -- --test-threads=1 --nocapture

# Capture exit code from first test
rc1=$?

# Run the burn-fusion tests for the execution/tests.rs module
# Using --release as per project convention
# Using --test-threads=1 for stability in virtualized environment
cargo test -p burn-fusion --release --lib stream::execution::tests -- --test-threads=1 --nocapture

# Capture exit code from second test
rc2=$?

# Combine exit codes - if either fails, overall should fail
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 868d8845d4a758500f18d47932bf6534309bc1d8 "crates/burn-backend-tests/tests/tensor/float/ops/full.rs" "crates/burn-fusion/src/stream/execution/tests.rs"