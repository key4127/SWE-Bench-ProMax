#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file before applying patch
git checkout 0d94c33c26ac70363007c1b4ac0fda3f37d4cd10 "tests/utils/test_torch_functional.py"

# Apply the test patch to modify the test file
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils/test_torch_functional.py b/tests/utils/test_torch_functional.py
--- a/tests/utils/test_torch_functional.py
+++ b/tests/utils/test_torch_functional.py
@@ -20,7 +20,12 @@
 import torch.multiprocessing as mp
 
 from verl.utils.device import get_device_name, get_nccl_backend, get_torch_device
-from verl.utils.torch_functional import distributed_masked_mean, distributed_mean_max_min_std, masked_mean
+from verl.utils.torch_functional import (
+    distributed_masked_mean,
+    distributed_mean_max_min_std,
+    expand_as_nested,
+    masked_mean,
+)
 
 
 def _worker_mean(rank: int, world_size: int, rendezvous_file: str):
@@ -115,3 +120,33 @@ def test_distributed_masked_mean(world_size, tmp_path):
         nprocs=world_size,
         join=True,
     )
+
+
+def test_expand_as_nested():
+    a = torch.randn(2)
+    b = torch.randn(3)
+    c = torch.randn(4)
+    nested_tensor = torch.nested.as_nested_tensor([a, b, c], layout=torch.jagged)
+    tensor = torch.tensor([1, 2, 3])
+
+    output = expand_as_nested(tensor, nested_tensor)
+
+    assert output.values().tolist() == [1, 1, 2, 2, 2, 3, 3, 3, 3]
+    assert torch.all(output.offsets() == nested_tensor.offsets()).item()
+
+    # test exceptions
+    with pytest.raises(AssertionError):
+        expand_as_nested(tensor, tensor)
+
+    other_tensor = torch.tensor([1, 2, 3, 4])
+
+    with pytest.raises(AssertionError):
+        expand_as_nested(other_tensor, nested_tensor)
+
+    other_tensor = torch.tensor([[1, 2, 3]])
+
+    with pytest.raises(AssertionError):
+        expand_as_nested(other_tensor, nested_tensor)
+
+    with pytest.raises(AssertionError):
+        expand_as_nested(tensor, nested_tensor.unsqueeze(-1))
EOF_114329324912

# Verify the test environment and required files
echo "======================================================================"
echo "VALIDATION: VERL Torch Functional Test Setup"
echo "======================================================================"
echo "Python version: $(python --version)"
echo "Working directory: $(pwd)"
echo "Git commit: $(git rev-parse HEAD)"
echo "PYTHONPATH: $PYTHONPATH"
echo ""
echo "Target test file:"
ls -lh tests/utils/test_torch_functional.py
echo ""
echo "Verifying PyTorch installation:"
python -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); import torch.distributed as dist; print(f'NCCL available: {dist.is_nccl_available()}'); print(f'Gloo available: {dist.is_gloo_available()}')"
echo "======================================================================"

# Patch the backend to use 'gloo' instead of 'nccl' for CPU execution
# This is necessary because NCCL requires GPUs, but we're running on CPU
echo ""
echo "======================================================================"
echo "Patching verl/utils/device.py to use 'gloo' backend for CPU..."
echo "======================================================================"

# Backup the original device.py file
cp verl/utils/device.py verl/utils/device.py.backup

# Apply a simple and reliable patch using sed
# Replace the return 'nccl' statement in get_nccl_backend function with return 'gloo'
sed -i "s/def get_nccl_backend():/def get_nccl_backend():\n    import torch\n    if torch.cuda.is_available():\n        return 'nccl'\n    return 'gloo'  # CPU fallback\n\ndef get_nccl_backend_original():/g" verl/utils/device.py

# Alternative simpler approach: just replace all 'nccl' returns with 'gloo' in the function
# This is more direct and reliable
cat > /tmp/patch_backend.py << 'PYTHON_PATCH'
import re

# Read the file
with open('verl/utils/device.py', 'r') as f:
    content = f.read()

# Find the get_nccl_backend function and replace it entirely
# Look for the function definition and replace the whole function
old_function_pattern = r'def get_nccl_backend\(\):[^}]*?return\s+["\']nccl["\']'

new_function = '''def get_nccl_backend():
    """Get the appropriate backend for distributed training.
    Returns 'gloo' for CPU compatibility.
    """
    import torch
    if torch.cuda.is_available():
        return 'nccl'
    return 'gloo'  # Use gloo for CPU environments'''

# Try to replace using regex
if re.search(old_function_pattern, content, re.DOTALL):
    content = re.sub(old_function_pattern, new_function, content, flags=re.DOTALL)
    print("✓ Replaced get_nccl_backend function using regex")
else:
    # Fallback: simple string replacement
    content = content.replace("return 'nccl'", "return 'gloo'")
    content = content.replace('return "nccl"', "return 'gloo'")
    print("✓ Applied fallback string replacement for nccl->gloo")

# Write back
with open('verl/utils/device.py', 'w') as f:
    f.write(content)

print("✓ Backend patch applied")
PYTHON_PATCH

python /tmp/patch_backend.py

# Verify the patch was applied by checking the actual backend returned
echo ""
echo "Verifying backend patch..."
BACKEND=$(python -c "from verl.utils.device import get_nccl_backend; print(get_nccl_backend())")
echo "Current backend: $BACKEND"

if [ "$BACKEND" != "gloo" ]; then
    echo "WARNING: Backend is still '$BACKEND', not 'gloo'. Attempting alternative patch..."
    
    # More aggressive patching - directly edit the file with a known working implementation
    cat > verl/utils/device.py.new << 'NEWFILE'
# Patched version for CPU compatibility
import torch

def get_nccl_backend():
    """Get the appropriate backend for distributed training.
    Returns 'gloo' for CPU environments.
    """
    if torch.cuda.is_available():
        return 'nccl'
    return 'gloo'

# Keep the rest of the original file
NEWFILE
    
    # Append the rest of the original file (excluding the original get_nccl_backend function)
    python -c "
import re
with open('verl/utils/device.py.backup', 'r') as f:
    content = f.read()
# Remove the original get_nccl_backend function
content = re.sub(r'def get_nccl_backend\(\):.*?(?=\ndef |\nclass |\Z)', '', content, flags=re.DOTALL)
with open('verl/utils/device.py.new', 'a') as f:
    f.write(content)
"
    
    mv verl/utils/device.py.new verl/utils/device.py
    
    # Verify again
    BACKEND=$(python -c "from verl.utils.device import get_nccl_backend; print(get_nccl_backend())" 2>&1 || echo "error")
    echo "Backend after alternative patch: $BACKEND"
fi

echo "✓ Backend configuration complete"

# Execute the torch functional tests
# Note: These tests include distributed multi-process tests that spawn their own processes
# We run pytest in single-process mode as the tests handle their own parallelization
echo ""
echo "======================================================================"
echo "Running Torch Functional Tests..."
echo "======================================================================"
pytest -xvs tests/utils/test_torch_functional.py
rc=$?
echo "Test exit code: $rc"

# Required: echo test status for the judge
echo ""
echo "======================================================================"
echo "OMNIGRIL_EXIT_CODE=$rc"
echo "======================================================================"

# Restore original files
echo "Restoring original files..."
mv verl/utils/device.py.backup verl/utils/device.py
git checkout 0d94c33c26ac70363007c1b4ac0fda3f37d4cd10 "tests/utils/test_torch_functional.py"

exit $rc