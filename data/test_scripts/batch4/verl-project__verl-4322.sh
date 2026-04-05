#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file before applying patch
git checkout f623c146ca3042f0f0015db3b58bfcb105704486 "tests/test_protocol_v2_on_cpu.py"

# Apply the test patch to modify the test file
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_protocol_v2_on_cpu.py b/tests/test_protocol_v2_on_cpu.py
--- a/tests/test_protocol_v2_on_cpu.py
+++ b/tests/test_protocol_v2_on_cpu.py
@@ -328,17 +328,65 @@ def test_chunk_concat():
 
 
 def test_pop():
-    obs = torch.randn(100, 10)
-    act = torch.randn(100, 3)
-    dataset = tu.get_tensordict({"obs": obs, "act": act}, non_tensor_dict={"2": 2, "1": 1})
+    obs = torch.randn(3, 10)
+    act = torch.randn(3, 3)
+    labels = ["a", ["b"], []]
+    dataset = tu.get_tensordict({"obs": obs, "act": act, "labels": labels}, non_tensor_dict={"2": 2, "1": 1})
+
+    dataset1 = copy.deepcopy(dataset)
+
+    # test pop keys
+    popped_dataset = tu.pop_keys(dataset, keys=["obs", "2"])
+
+    assert popped_dataset.batch_size[0] == 3
+
+    assert popped_dataset.keys() == {"obs", "2"}
+    assert torch.all(torch.eq(popped_dataset["obs"], obs)).item()
+    assert popped_dataset["2"] == 2
+
+    assert dataset.keys() == {"act", "1", "labels"}
+
+    # test pop non-exist key
+    with pytest.raises(KeyError):
+        tu.pop_keys(dataset, keys=["obs", "2"])
+
+    # test single pop
+    # NonTensorData
+    assert tu.pop(dataset1, key="2") == 2
+    # NonTensorStack
+    assert tu.pop(dataset1, key="labels") == ["a", ["b"], []]
+    # Tensor
+    assert torch.all(torch.eq(tu.pop(dataset1, key="obs"), obs)).item()
+
+
+def test_get():
+    obs = torch.randn(3, 10)
+    act = torch.randn(3, 3)
+    labels = ["a", ["b"], []]
+    dataset = tu.get_tensordict({"obs": obs, "act": act, "labels": labels}, non_tensor_dict={"2": 2, "1": 1})
+
+    # test pop keys
+    popped_dataset = tu.get_keys(dataset, keys=["obs", "2"])
+
+    assert popped_dataset.batch_size[0] == 3
 
-    poped_dataset = tu.pop(dataset, keys=["obs", "2"])
+    assert torch.all(torch.eq(popped_dataset["obs"], dataset["obs"])).item()
 
-    assert poped_dataset.batch_size[0] == 100
+    assert popped_dataset["2"] == dataset["2"]
 
-    assert poped_dataset.keys() == {"obs", "2"}
+    # test pop non-exist key
+    with pytest.raises(KeyError):
+        tu.get_keys(dataset, keys=["obs", "3"])
 
-    assert dataset.keys() == {"act", "1"}
+    # test single pop
+    # NonTensorData
+    assert tu.get(dataset, key="2") == 2
+    # NonTensorStack
+    assert tu.get(dataset, key="labels") == ["a", ["b"], []]
+    # Tensor
+    assert torch.all(torch.eq(tu.get(dataset, key="obs"), obs)).item()
+    # Non-exist key
+    assert tu.get(dataset, key="3", default=3) == 3
 
 
 def test_repeat():
@@ -531,7 +579,7 @@ def test_dataproto_no_batch():
     selected = data.select("labels")
 
     assert selected["labels"] == labels
-    pop_data = tu.pop(data, keys=["labels"])
+    pop_data = tu.pop_keys(data, keys=["labels"])
     assert pop_data["labels"] == labels
     assert "labels" not in data
 
EOF_114329324912

# Verify the test environment
echo "======================================================================"
echo "VALIDATION: Test Environment Setup"
echo "======================================================================"
echo "Python version: $(python --version)"
echo "Working directory: $(pwd)"
echo "Git commit: $(git rev-parse HEAD)"
echo "PYTHONPATH: $PYTHONPATH"
echo ""
echo "Test file:"
ls -lh tests/test_protocol_v2_on_cpu.py
echo ""
echo "Verify verl package import:"
python -c "import verl; print('verl imported successfully')"
echo "======================================================================"

# Execute the target test with pytest
echo ""
echo "======================================================================"
echo "Running Test: tests/test_protocol_v2_on_cpu.py"
echo "======================================================================"
pytest tests/test_protocol_v2_on_cpu.py -v --tb=short
rc=$?
echo "Test exit code: $rc"

# Required: echo test status for the judge
echo ""
echo "======================================================================"
echo "OMNIGRIL_EXIT_CODE=$rc"
echo "======================================================================"

# Restore original test file
git checkout f623c146ca3042f0f0015db3b58bfcb105704486 "tests/test_protocol_v2_on_cpu.py"

exit $rc