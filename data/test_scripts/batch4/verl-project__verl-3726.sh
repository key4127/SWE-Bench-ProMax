#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file before applying patch
git checkout 656f4e67059e4ca64ed8a9dd600d8f2487d61e40 "tests/test_protocol_on_cpu.py"

# Apply the test patch to modify the test file
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_protocol_on_cpu.py b/tests/test_protocol_on_cpu.py
--- a/tests/test_protocol_on_cpu.py
+++ b/tests/test_protocol_on_cpu.py
@@ -30,6 +30,7 @@
     union_numpy_dict,
     union_tensor_dict,
 )
+from verl.utils import tensordict_utils as tu
 
 
 def test_union_tensor_dict():
@@ -761,6 +762,23 @@ def test_to_tensordict():
     assert output["name"] == "abdce"
 
 
+@pytest.mark.skipif(
+    parse_version(tensordict.__version__) < parse_version("0.10"), reason="requires at least tensordict 0.10"
+)
+def test_from_tensordict():
+    tensor_dict = {
+        "obs": torch.tensor([1, 2, 3, 4, 5, 6]),
+        "labels": ["a", "b", "c", "d", "e", "f"],
+    }
+    non_tensor_dict = {"name": "abdce"}
+    tensordict = tu.get_tensordict(tensor_dict, non_tensor_dict)
+    data = DataProto.from_tensordict(tensordict)
+
+    assert data.non_tensor_batch["labels"].tolist() == tensor_dict["labels"]
+    assert torch.all(torch.eq(data.batch["obs"], tensor_dict["obs"])).item()
+    assert data.meta_info["name"] == "abdce"
+
+
 def test_serialize_deserialize_single_tensor():
     """Test serialization and deserialization of a single tensor"""
     # Create test tensor
EOF_114329324912

# Verify the test environment and required files
echo "======================================================================"
echo "VALIDATION: VERL Protocol Test Setup on CPU"
echo "======================================================================"
echo "Python version: $(python --version)"
echo "Working directory: $(pwd)"
echo "Git commit: $(git rev-parse HEAD)"
echo "PYTHONPATH: $PYTHONPATH"
echo ""
echo "Target test file:"
ls -lh tests/test_protocol_on_cpu.py
echo ""
echo "Verifying core dependencies..."
python -c "import torch; import numpy; import tensordict; import ray; import pytest; print('✓ Core dependencies available')"
echo "======================================================================"

# Execute the protocol tests on CPU
# These tests validate the protocol implementation without requiring GPU
echo ""
echo "======================================================================"
echo "Running Protocol Tests on CPU..."
echo "======================================================================"
pytest -xvs tests/test_protocol_on_cpu.py
rc=$?
echo "Protocol test exit code: $rc"

# Required: echo test status for the judge
echo ""
echo "======================================================================"
echo "OMNIGRIL_EXIT_CODE=$rc"
echo "======================================================================"

# Restore original test file
git checkout 656f4e67059e4ca64ed8a9dd600d8f2487d61e40 "tests/test_protocol_on_cpu.py"

exit $rc