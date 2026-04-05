#!/bin/bash
set -uxo pipefail

cd /testbed

# Checkout to the target commit
git checkout 2ff964bcb4995f1b9faf310d34852d72471ef4b5

# Checkout the test file to ensure we have the correct version
git checkout 2ff964bcb4995f1b9faf310d34852d72471ef4b5 "tests/models/vjepa2/test_modeling_vjepa2.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/vjepa2/test_modeling_vjepa2.py b/tests/models/vjepa2/test_modeling_vjepa2.py
--- a/tests/models/vjepa2/test_modeling_vjepa2.py
+++ b/tests/models/vjepa2/test_modeling_vjepa2.py
@@ -40,7 +40,7 @@
     import torch
     from torch import nn
 
-    from transformers import VJEPA2Model
+    from transformers import VJEPA2ForVideoClassification, VJEPA2Model
 
 
 if is_vision_available():
@@ -153,7 +153,7 @@ class VJEPA2ModelTest(ModelTesterMixin, PipelineTesterMixin, unittest.TestCase):
 
     test_torch_exportable = True
 
-    all_model_classes = (VJEPA2Model,) if is_torch_available() else ()
+    all_model_classes = (VJEPA2Model, VJEPA2ForVideoClassification) if is_torch_available() else ()
 
     fx_compatible = True
 
@@ -267,7 +267,7 @@ def test_inference_image(self):
             [[-0.0061, -1.8365, 2.7343], [-2.5938, -2.7181, -0.1663], [-1.7993, -2.2430, -1.1388]],
             device=torch_device,
         )
-        torch.testing.assert_close(outputs.last_hidden_state[0, :3, :3], expected_slice, rtol=1e-3, atol=1e-3)
+        torch.testing.assert_close(outputs.last_hidden_state[0, :3, :3], expected_slice, rtol=8e-2, atol=8e-2)
 
     @slow
     def test_inference_video(self):
@@ -343,3 +343,22 @@ def test_predictor_partial_mask(self):
         # verify the last hidden states
         expected_shape = torch.Size((1, num_masks, 1024))
         self.assertEqual(outputs.predictor_output.last_hidden_state.shape, expected_shape)
+
+    @slow
+    def test_video_classification(self):
+        checkpoint = "facebook/vjepa2-vitl-fpc16-256-ssv2"
+
+        model = VJEPA2ForVideoClassification.from_pretrained(checkpoint).to(torch_device)
+        video_processor = AutoVideoProcessor.from_pretrained(checkpoint)
+
+        sample_video = np.ones((16, 3, 256, 256))
+        inputs = video_processor(sample_video, return_tensors="pt").to(torch_device)
+
+        with torch.no_grad():
+            outputs = model(**inputs)
+
+        self.assertEqual(outputs.logits.shape, (1, 174))
+
+        expected_logits = torch.tensor([0.8814, -0.1195, -0.6389], device=torch_device)
+        resulted_logits = outputs.logits[0, 100:103]
+        torch.testing.assert_close(resulted_logits, expected_logits, rtol=1e-2, atol=1e-2)
EOF_114329324912

# Verify environment is ready
echo "Python version:"
python --version
echo "PyTorch version:"
python -c "import torch; print(torch.__version__)"
echo "Transformers location:"
python -c "import transformers; print(transformers.__file__)"

# Set environment variables for testing
export PYTHONPATH=/testbed/src:$PYTHONPATH
export TRANSFORMERS_VERBOSITY=info

# Run the target vjepa2 tests
# Using single process mode for stability in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider -v tests/models/vjepa2/test_modeling_vjepa2.py
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
git checkout 2ff964bcb4995f1b9faf310d34852d72471ef4b5 "tests/models/vjepa2/test_modeling_vjepa2.py"