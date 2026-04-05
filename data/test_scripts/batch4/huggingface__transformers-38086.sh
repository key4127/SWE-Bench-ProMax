#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a419a40234d2061c2e3480d1c5d699b575129a74 "tests/models/falcon_mamba/test_modeling_falcon_mamba.py" "tests/models/mamba/test_modeling_mamba.py" "tests/utils/test_cache_utils.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/models/falcon_mamba/test_modeling_falcon_mamba.py b/tests/models/falcon_mamba/test_modeling_falcon_mamba.py
--- a/tests/models/falcon_mamba/test_modeling_falcon_mamba.py
+++ b/tests/models/falcon_mamba/test_modeling_falcon_mamba.py
@@ -26,7 +26,6 @@
     require_torch_accelerator,
     require_torch_large_accelerator,
     require_torch_multi_accelerator,
-    require_torch_multi_gpu,
     slow,
     torch_device,
 )
@@ -41,10 +40,10 @@
     import torch
 
     from transformers import (
+        FalconMambaCache,
         FalconMambaForCausalLM,
         FalconMambaModel,
     )
-    from transformers.cache_utils import MambaCache
 
 
 # Copied from transformers.tests.models.mamba.MambaModelTester with Mamba->FalconMamba,mamba->falcon_mamba
@@ -312,31 +311,6 @@ def assertInterval(self, member, container, msg=None):
     def test_config(self):
         self.config_tester.run_common_tests()
 
-    @require_torch_multi_gpu
-    def test_multi_gpu_data_parallel_forward(self):
-        config, inputs_dict = self.model_tester.prepare_config_and_inputs_for_common()
-
-        # some params shouldn't be scattered by nn.DataParallel
-        # so just remove them if they are present.
-        blacklist_non_batched_params = ["cache_params"]
-        for k in blacklist_non_batched_params:
-            inputs_dict.pop(k, None)
-
-        # move input tensors to cuda:O
-        for k, v in inputs_dict.items():
-            if torch.is_tensor(v):
-                inputs_dict[k] = v.to(0)
-
-        for model_class in self.all_model_classes:
-            model = model_class(config=config)
-            model.to(0)
-            model.eval()
-
-            # Wrap model in nn.DataParallel
-            model = torch.nn.DataParallel(model)
-            with torch.no_grad():
-                _ = model(**self._prepare_for_class(inputs_dict, model_class))
-
     def test_falcon_mamba_model(self):
         config_and_inputs = self.model_tester.prepare_config_and_inputs()
         self.model_tester.create_and_check_falcon_mamba_model(*config_and_inputs)
@@ -411,7 +385,7 @@ def check_equivalence(model, tuple_inputs, dict_inputs, additional_kwargs={}):
                 dict_output = model(**dict_inputs, return_dict=True, **additional_kwargs).to_tuple()
 
                 def recursive_check(tuple_object, dict_object):
-                    if isinstance(tuple_object, MambaCache):  # MODIFIED PART START
+                    if isinstance(tuple_object, FalconMambaCache):  # MODIFIED PART START
                         recursive_check(tuple_object.conv_states, dict_object.conv_states)
                         recursive_check(tuple_object.ssm_states, dict_object.ssm_states)
                     elif isinstance(tuple_object, (list, tuple)):  # MODIFIED PART END
@@ -458,6 +432,10 @@ def recursive_check(tuple_object, dict_object):
             dict_inputs = self._prepare_for_class(inputs_dict, model_class, return_labels=True)
             check_equivalence(model, tuple_inputs, dict_inputs, {"output_hidden_states": True})
 
+    @unittest.skip("Mamba models do not support DDP.")
+    def test_multi_gpu_data_parallel_forward(self):
+        pass
+
 
 @require_torch
 @require_torch_accelerator
@@ -497,7 +475,9 @@ def test_generation_fp16(self):
     @require_bitsandbytes
     def test_generation_4bit(self):
         quantization_config = BitsAndBytesConfig(load_in_4bit=True)
-        model = AutoModelForCausalLM.from_pretrained(self.model_id, quantization_config=quantization_config)
+        model = AutoModelForCausalLM.from_pretrained(self.model_id, quantization_config=quantization_config).to(
+            torch_device
+        )
 
         inputs = self.tokenizer(self.text, return_tensors="pt").to(torch_device)
         out = model.generate(**inputs, max_new_tokens=20, do_sample=False)
@@ -513,6 +493,7 @@ def test_generation_torch_compile(self):
 
         inputs = self.tokenizer(self.text, return_tensors="pt").to(torch_device)
         out = model.generate(**inputs, max_new_tokens=20, do_sample=False)
+        print(self.tokenizer.batch_decode(out, skip_special_tokens=False)[0])
 
         self.assertEqual(
             self.tokenizer.batch_decode(out, skip_special_tokens=False)[0],
@@ -543,7 +524,7 @@ def test_batched_generation(self):
         inputs = tok(texts, return_tensors="pt", padding=True, return_token_type_ids=False).to(torch_device)
         model = AutoModelForCausalLM.from_pretrained(model_id, device_map=0, torch_dtype=torch.float16)
 
-        out = model.generate(**inputs, max_new_tokens=20)
+        out = model.generate(**inputs, max_new_tokens=20, do_sample=False)
         out = tok.batch_decode(out, skip_special_tokens=True)
 
         self.assertListEqual(out, EXPECTED_OUTPUT)
@@ -553,7 +534,7 @@ def test_batched_generation(self):
             inputs_embeds = model.get_input_embeddings()(inputs.pop("input_ids"))
 
         inputs["inputs_embeds"] = inputs_embeds
-        out = model.generate(**inputs, max_new_tokens=20)
+        out = model.generate(**inputs, max_new_tokens=20, do_sample=False)
         out = tok.batch_decode(out, skip_special_tokens=True)
 
         EXPECTED_OUTPUTS = Expectations(
diff --git a/tests/models/mamba/test_modeling_mamba.py b/tests/models/mamba/test_modeling_mamba.py
--- a/tests/models/mamba/test_modeling_mamba.py
+++ b/tests/models/mamba/test_modeling_mamba.py
@@ -20,7 +20,7 @@
 from parameterized import parameterized
 
 from transformers import AutoTokenizer, MambaConfig, is_torch_available
-from transformers.testing_utils import require_torch, require_torch_multi_gpu, slow, torch_device
+from transformers.testing_utils import require_torch, slow, torch_device
 
 from ...generation.test_utils import GenerationTesterMixin
 from ...test_configuration_common import ConfigTester
@@ -32,10 +32,10 @@
     import torch
 
     from transformers import (
+        MambaCache,
         MambaForCausalLM,
         MambaModel,
     )
-    from transformers.models.mamba.modeling_mamba import MambaCache
 
 
 class MambaModelTester:
@@ -279,31 +279,6 @@ def assertInterval(self, member, container, msg=None):
     def test_config(self):
         self.config_tester.run_common_tests()
 
-    @require_torch_multi_gpu
-    def test_multi_gpu_data_parallel_forward(self):
-        config, inputs_dict = self.model_tester.prepare_config_and_inputs_for_common()
-
-        # some params shouldn't be scattered by nn.DataParallel
-        # so just remove them if they are present.
-        blacklist_non_batched_params = ["cache_params"]
-        for k in blacklist_non_batched_params:
-            inputs_dict.pop(k, None)
-
-        # move input tensors to cuda:O
-        for k, v in inputs_dict.items():
-            if torch.is_tensor(v):
-                inputs_dict[k] = v.to(0)
-
-        for model_class in self.all_model_classes:
-            model = model_class(config=config)
-            model.to(0)
-            model.eval()
-
-            # Wrap model in nn.DataParallel
-            model = torch.nn.DataParallel(model)
-            with torch.no_grad():
-                _ = model(**self._prepare_for_class(inputs_dict, model_class))
-
     def test_mamba_model(self):
         config_and_inputs = self.model_tester.prepare_config_and_inputs()
         self.model_tester.create_and_check_mamba_model(*config_and_inputs)
@@ -452,6 +427,10 @@ def test_dtype_mismatch_handled_in_cache(self):
             (self.model_tester.batch_size, self.model_tester.seq_length, self.model_tester.hidden_size),
         )
 
+    @unittest.skip("Mamba models do not support DDP.")
+    def test_multi_gpu_data_parallel_forward(self):
+        pass
+
 
 @require_torch
 class MambaIntegrationTests(unittest.TestCase):
@@ -547,11 +526,11 @@ def test_compile_mamba_cache(self):
             torch_device
         )
 
-        output = model.generate(input_ids, max_new_tokens=20, cache_implementation="mamba")
+        output = model.generate(input_ids, max_new_tokens=20)
         output_sentence = self.tokenizer.decode(output[0].tolist())
         self.assertEqual(output_sentence, expected_output)
 
         model.forward = torch.compile(model.forward, fullgraph=True, mode="reduce-overhead")
-        output = model.generate(input_ids, max_new_tokens=20, cache_implementation="mamba")
+        output = model.generate(input_ids, max_new_tokens=20)
         output_sentence = self.tokenizer.decode(output[0].tolist())
         self.assertEqual(output_sentence, expected_output)
diff --git a/tests/utils/test_cache_utils.py b/tests/utils/test_cache_utils.py
--- a/tests/utils/test_cache_utils.py
+++ b/tests/utils/test_cache_utils.py
@@ -62,8 +62,6 @@
 TEST_CACHE_IMPLEMENTATIONS = [
     cache_name
     for cache_name in ALL_CACHE_IMPLEMENTATIONS
-    # TODO (joao): Mamba is not compatible with most models, remove from `ALL_CACHE_IMPLEMENTATIONS`?
-    if cache_name != "mamba"
     # TODO (joao): offloaded_hybrid == offloaded_hybrid_chunked, deprecate one of them
     if cache_name != "offloaded_hybrid"
 ]
EOF_114329324912

# Set environment variables for test execution
export PYTHONPATH=/testbed/src:/testbed:$PYTHONPATH
export TRANSFORMERS_CACHE=/tmp/transformers_cache
export HF_HOME=/tmp/hf_home

# Run the target test files
# Using pytest with appropriate flags:
# --no-header: Suppress pytest header
# -rA: Show all test outcomes (passed, failed, skipped, etc.)
# --tb=short: Use short traceback format for better readability
# -v: Verbose output
# -x: Stop on first failure for faster feedback
# Single process mode for stability in virtualized environment
python -m pytest --no-header -rA --tb=short -v -x \
    tests/models/falcon_mamba/test_modeling_falcon_mamba.py \
    tests/models/mamba/test_modeling_mamba.py \
    tests/utils/test_cache_utils.py

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout a419a40234d2061c2e3480d1c5d699b575129a74 "tests/models/falcon_mamba/test_modeling_falcon_mamba.py" "tests/models/mamba/test_modeling_mamba.py" "tests/utils/test_cache_utils.py"