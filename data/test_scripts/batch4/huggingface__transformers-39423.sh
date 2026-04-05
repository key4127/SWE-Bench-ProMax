#!/bin/bash
set -uxo pipefail

cd /testbed

# Checkout to the target commit
git checkout 2b819ba4e383dd5b82d6d251039e30c3e94761b1

# Checkout the test files to ensure we have the correct version
git checkout 2b819ba4e383dd5b82d6d251039e30c3e94761b1 \
    "tests/models/blip_2/test_modeling_blip_2.py" \
    "tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py" \
    "tests/test_modeling_common.py" \
    "tests/utils/test_configuration_utils.py" \
    "tests/utils/test_modeling_utils.py" \
    "utils/test_module/custom_configuration.py" \
    "utils/test_module/custom_modeling.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/blip_2/test_modeling_blip_2.py b/tests/models/blip_2/test_modeling_blip_2.py
--- a/tests/models/blip_2/test_modeling_blip_2.py
+++ b/tests/models/blip_2/test_modeling_blip_2.py
@@ -1085,6 +1085,10 @@ def test_initialization(self):
                         msg=f"Parameter {name} of model {model_class} seems not properly initialized",
                     )
 
+    @unittest.skip("T5 backbone deepcopies the configs, and fixing it would be more involved")
+    def test_internal_model_config_and_subconfig_are_same(self):
+        pass
+
 
 class Blip2TextModelWithProjectionTester:
     def __init__(self, parent, vision_kwargs=None, qformer_kwargs=None, is_training=True):
diff --git a/tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py b/tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py
--- a/tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py
+++ b/tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py
@@ -542,6 +542,8 @@ def get_attention(self, multi_query):
             attn_pdrop=0,
             resid_pdrop=0,
         )
+        # We need to set it here as it's normally set by the Model's __init__
+        config._attn_implementation = "sdpa"
         return GPTBigCodeAttention(config)
 
     @parameterized.expand([(seed, is_train_mode) for seed in range(5) for is_train_mode in [True, False]])
diff --git a/tests/test_modeling_common.py b/tests/test_modeling_common.py
--- a/tests/test_modeling_common.py
+++ b/tests/test_modeling_common.py
@@ -4783,6 +4783,126 @@ def test_can_load_with_meta_device_context_manager(self):
                 f"All parameters should be on meta device, but found {unique_devices}.",
             )
 
+    def test_internal_model_config_and_subconfig_are_same(self):
+        config, _ = self.model_tester.prepare_config_and_inputs_for_common()
+        subconfig_keys = list(config.sub_configs.keys())
+        for model_class in self.all_model_classes:
+            if len(config.sub_configs) == 0:
+                self.skipTest(reason="No subconfigs so the test does not make sense")
+            # Need to deepcopy here to avoid changing the _attn_implementation in-place
+            model = model_class(copy.deepcopy(config))
+
+            for submodule in model.modules():
+                # This is a submodel
+                if isinstance(submodule, PreTrainedModel) and submodule.config.__class__ != model.config.__class__:
+                    subconfig_from_model_internal = submodule.config
+                    matching_sub_configs = []
+                    for subconfig_key in subconfig_keys:
+                        # Get the subconfig from the model config
+                        subconfig_from_model_config = getattr(model.config, subconfig_key)
+                        if subconfig_from_model_config.__class__ == subconfig_from_model_internal.__class__:
+                            # Since some composite models have different submodels parameterized by 2 of the same config
+                            # class instances, we need to check against a list of matching classes, and check that at least
+                            # 1 is the exact object (instead of checking immediately for similar object)
+                            matching_sub_configs.append(subconfig_from_model_config)
+
+                    # Both should be exactly the same object, that is when instantiating the submodel when should
+                    # absolutely not copy the subconfig
+                    if len(matching_sub_configs) > 0:
+                        self.assertTrue(
+                            any(
+                                subconfig_from_model_config is subconfig_from_model_internal
+                                for subconfig_from_model_config in matching_sub_configs
+                            )
+                        )
+
+    def test_can_set_attention_dynamically(self):
+        config, _ = self.model_tester.prepare_config_and_inputs_for_common()
+        for model_class in self.all_model_classes:
+            if not model_class._can_set_attn_implementation():
+                self.skipTest(reason="This model does not support setting its attention dynamically")
+
+            # Need to deepcopy here to avoid changing the _attn_implementation in-place
+            model_config = copy.deepcopy(config)
+            # Set eager everywhere (it sets it recursively on subconfigs)
+            model_config._attn_implementation = "eager"
+            model = model_class(model_config)
+
+            # sanity check to make sure everything is correctly eager
+            self.assertTrue(model.config._attn_implementation == "eager")
+            for subconfig_key in model.config.sub_configs:
+                self.assertTrue(getattr(model.config, subconfig_key)._attn_implementation == "eager")
+
+            if not all(
+                submodule._can_set_attn_implementation()
+                for submodule in model.modules()
+                if isinstance(submodule, PreTrainedModel)
+            ):
+                self.skipTest(reason="Parts of this model cannot set attention dynamically")
+            # Some old models technically should support switching, but don't have the flags active...
+            if not all(
+                submodule._supports_sdpa for submodule in model.modules() if isinstance(submodule, PreTrainedModel)
+            ):
+                self.skipTest(reason="Parts of this model don't support sdpa")
+
+            # Now, set it to sdpa
+            model.set_attn_implementation("sdpa")
+
+            # Check everything was correctly changed
+            self.assertTrue(model.config._attn_implementation == "sdpa")
+            for subconfig_key in model.config.sub_configs:
+                self.assertTrue(getattr(model.config, subconfig_key)._attn_implementation == "sdpa")
+
+            # Check we cannot set it to random values, and it raises a warning (but no crash)
+            with self.assertLogs("transformers.modeling_utils", level="WARNING") as cm:
+                model.set_attn_implementation("foo")
+                self.assertTrue(
+                    any(
+                        "Impossible to set the requested `attn_implementation`. The following error was captured:"
+                        in warning
+                        for warning in cm.output
+                    )
+                )
+
+            # Should still be sdpa everywhere
+            self.assertTrue(model.config._attn_implementation == "sdpa")
+            for subconfig_key in model.config.sub_configs:
+                self.assertTrue(getattr(model.config, subconfig_key)._attn_implementation == "sdpa")
+
+    def test_can_set_attention_dynamically_composite_model(self):
+        config, _ = self.model_tester.prepare_config_and_inputs_for_common()
+        for model_class in self.all_model_classes:
+            if not model_class._can_set_attn_implementation():
+                self.skipTest(reason="This model does not support setting its attention dynamically")
+            if not self._is_composite:
+                self.skipTest(reason="This model is not composite")
+
+            # Need to deepcopy here to avoid changing the _attn_implementation in-place
+            model_config = copy.deepcopy(config)
+            # Set eager everywhere (it sets it recursively on subconfigs)
+            model_config._attn_implementation = "eager"
+            model = model_class(model_config)
+
+            # sanity check to make sure everything is correctly eager
+            self.assertTrue(model.config._attn_implementation == "eager")
+            for subconfig_key in model.config.sub_configs:
+                self.assertTrue(getattr(model.config, subconfig_key)._attn_implementation == "eager")
+
+            if not all(
+                submodule._can_set_attn_implementation()
+                for submodule in model.modules()
+                if isinstance(submodule, PreTrainedModel)
+            ):
+                self.skipTest(reason="Parts of this model cannot set attention dynamically")
+
+            # Now, set only top-most to sdpa (should support it if it supports the dynamic switch)
+            model.set_attn_implementation({"": "sdpa"})
+
+            # Check only top-most was correctly changed
+            self.assertTrue(model.config._attn_implementation == "sdpa")
+            for subconfig_key in model.config.sub_configs:
+                self.assertTrue(getattr(model.config, subconfig_key)._attn_implementation == "eager")
+
 
 global_rng = random.Random()
 
diff --git a/tests/utils/test_configuration_utils.py b/tests/utils/test_configuration_utils.py
--- a/tests/utils/test_configuration_utils.py
+++ b/tests/utils/test_configuration_utils.py
@@ -194,7 +194,6 @@ def test_config_common_kwargs_is_complete(self):
                 "_name_or_path",
                 "_commit_hash",
                 "_attn_implementation_internal",
-                "_attn_implementation_autoset",
                 "transformers_version",
             ],
         )
diff --git a/tests/utils/test_modeling_utils.py b/tests/utils/test_modeling_utils.py
--- a/tests/utils/test_modeling_utils.py
+++ b/tests/utils/test_modeling_utils.py
@@ -83,12 +83,13 @@
 
 sys.path.append(str(Path(__file__).parent.parent.parent / "utils"))
 
-from test_module.custom_configuration import CustomConfig, NoSuperInitConfig  # noqa E402
+from test_module.custom_configuration import CustomConfig
+
 
 if is_torch_available():
     import torch
     from safetensors.torch import save_file as safe_save_file
-    from test_module.custom_modeling import CustomModel, NoSuperInitModel
+    from test_module.custom_modeling import CustomModel
     from torch import nn
 
     from transformers import (
@@ -732,36 +733,21 @@ def test_model_from_config_attn_implementation(self):
             config = AutoConfig.from_pretrained(TINY_MISTRAL, attn_implementation=requested_attn_implementation)
             # Ensure the config was set correctly
             self.assertEqual(config._attn_implementation, requested_attn_implementation)
-            self.assertEqual(config._attn_implementation_internal, requested_attn_implementation)
             model = AutoModelForCausalLM.from_config(config)
             self.assertEqual(model.config._attn_implementation, requested_attn_implementation)
 
             config = AutoConfig.from_pretrained(TINY_MISTRAL)
             # When the config is not set, the default is "eager"
-            self.assertEqual(config._attn_implementation, "eager")
-            self.assertEqual(config._attn_implementation_internal, None)
+            self.assertEqual(config._attn_implementation, None)
             model = AutoModelForCausalLM.from_config(config=config, attn_implementation=requested_attn_implementation)
             self.assertEqual(model.config._attn_implementation, requested_attn_implementation)
 
             # Set a nonsense attn_implementation in the config, which should be overridden by the explicit argument
             config = AutoConfig.from_pretrained(TINY_MISTRAL, attn_implementation="foo-bar-baz")
             self.assertEqual(config._attn_implementation, "foo-bar-baz")
-            self.assertEqual(config._attn_implementation_internal, "foo-bar-baz")
             model = AutoModelForCausalLM.from_config(config=config, attn_implementation=requested_attn_implementation)
             self.assertEqual(model.config._attn_implementation, requested_attn_implementation)
 
-    def test_no_super_init_config_and_model(self):
-        config = NoSuperInitConfig(attribute=32)
-        model = NoSuperInitModel(config)
-
-        with tempfile.TemporaryDirectory() as tmp_dir:
-            model.save_pretrained(tmp_dir)
-
-            new_model = NoSuperInitModel.from_pretrained(tmp_dir)
-
-        for p1, p2 in zip(model.parameters(), new_model.parameters()):
-            self.assertTrue(torch.equal(p1, p2))
-
     def test_checkpoint_sharding_local_bin(self):
         model = BertModel.from_pretrained("hf-internal-testing/tiny-random-bert")
 
diff --git a/utils/test_module/custom_configuration.py b/utils/test_module/custom_configuration.py
--- a/utils/test_module/custom_configuration.py
+++ b/utils/test_module/custom_configuration.py
@@ -7,10 +7,3 @@ class CustomConfig(PretrainedConfig):
     def __init__(self, attribute=1, **kwargs):
         self.attribute = attribute
         super().__init__(**kwargs)
-
-
-class NoSuperInitConfig(PretrainedConfig):
-    model_type = "custom"
-
-    def __init__(self, attribute=1, **kwargs):
-        self.attribute = attribute
diff --git a/utils/test_module/custom_modeling.py b/utils/test_module/custom_modeling.py
--- a/utils/test_module/custom_modeling.py
+++ b/utils/test_module/custom_modeling.py
@@ -2,7 +2,7 @@
 
 from transformers import PreTrainedModel
 
-from .custom_configuration import CustomConfig, NoSuperInitConfig
+from .custom_configuration import CustomConfig
 
 
 class CustomModel(PreTrainedModel):
@@ -17,17 +17,3 @@ def forward(self, x):
 
     def _init_weights(self, module):
         pass
-
-
-class NoSuperInitModel(PreTrainedModel):
-    config_class = NoSuperInitConfig
-
-    def __init__(self, config):
-        super().__init__(config)
-        self.linear = torch.nn.Linear(config.attribute, config.attribute)
-
-    def forward(self, x):
-        return self.linear(x)
-
-    def _init_weights(self, module):
-        pass
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
export HF_HOME=/workspace/.cache

# Run the target tests
# Using single process mode for stability in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/models/blip_2/test_modeling_blip_2.py \
    tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py \
    tests/test_modeling_common.py \
    tests/utils/test_configuration_utils.py \
    tests/utils/test_modeling_utils.py \
    utils/test_module/custom_configuration.py \
    utils/test_module/custom_modeling.py

rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
git checkout 2b819ba4e383dd5b82d6d251039e30c3e94761b1 \
    "tests/models/blip_2/test_modeling_blip_2.py" \
    "tests/models/gpt_bigcode/test_modeling_gpt_bigcode.py" \
    "tests/test_modeling_common.py" \
    "tests/utils/test_configuration_utils.py" \
    "tests/utils/test_modeling_utils.py" \
    "utils/test_module/custom_configuration.py" \
    "utils/test_module/custom_modeling.py"