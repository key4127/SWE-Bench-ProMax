#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout a44dcbe513e3e073271e0b8e369b75aca51affae "tests/models/timm_wrapper/test_modeling_timm_wrapper.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/timm_wrapper/test_modeling_timm_wrapper.py b/tests/models/timm_wrapper/test_modeling_timm_wrapper.py
--- a/tests/models/timm_wrapper/test_modeling_timm_wrapper.py
+++ b/tests/models/timm_wrapper/test_modeling_timm_wrapper.py
@@ -170,6 +170,16 @@ def test_mismatched_shapes_have_properly_initialized_weights(self):
     def test_model_is_small(self):
         pass
 
+    def test_gradient_checkpointing(self):
+        config, _ = self.model_tester.prepare_config_and_inputs_for_common()
+        model = TimmWrapperModel._from_config(config)
+        self.assertTrue(model.supports_gradient_checkpointing)
+
+    def test_gradient_checkpointing_on_non_supported_model(self):
+        config = TimmWrapperConfig.from_pretrained("timm/hrnet_w18.ms_aug_in1k")
+        model = TimmWrapperModel._from_config(config)
+        self.assertFalse(model.supports_gradient_checkpointing)
+
     def test_forward_signature(self):
         config, _ = self.model_tester.prepare_config_and_inputs_for_common()
 
EOF_114329324912

# Run the target test file
# Using pytest with appropriate flags:
# --no-header: Suppress pytest header
# -rA: Show all test outcomes (passed, failed, skipped, etc.)
# --tb=short: Use short traceback format for better readability
# -v: Verbose output
# Single process mode for stability in virtualized environment
python -m pytest --no-header -rA --tb=short -v tests/models/timm_wrapper/test_modeling_timm_wrapper.py

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout a44dcbe513e3e073271e0b8e369b75aca51affae "tests/models/timm_wrapper/test_modeling_timm_wrapper.py"