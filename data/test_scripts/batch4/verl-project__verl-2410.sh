#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files before applying patch
git checkout ad33564f849664069394108792fe5f709b9607f0 "tests/special_sanity/test_config_docs.py" "tests/trainer/config/test_legacy_config_on_cpu.py"

# Apply the test patch to modify the test files
git apply -v - <<'EOF_114329324912'
diff --git a/tests/special_sanity/test_config_docs.py b/tests/special_sanity/test_config_docs.py
--- a/tests/special_sanity/test_config_docs.py
+++ b/tests/special_sanity/test_config_docs.py
@@ -62,6 +62,9 @@ def test_trainer_config_doc():
         "verl/trainer/config/ppo_trainer.yaml",
         "verl/trainer/config/actor/actor.yaml",
         "verl/trainer/config/actor/dp_actor.yaml",
+        "verl/trainer/config/ref/ref.yaml",
+        "verl/trainer/config/ref/dp_ref.yaml",
+        "verl/trainer/config/rollout/rollout.yaml",
     ]
     success = True
     for yaml_to_inspect in yamls_to_inspect:
diff --git a/tests/trainer/config/test_legacy_config_on_cpu.py b/tests/trainer/config/test_legacy_config_on_cpu.py
--- a/tests/trainer/config/test_legacy_config_on_cpu.py
+++ b/tests/trainer/config/test_legacy_config_on_cpu.py
@@ -12,16 +12,24 @@
 # See the License for the specific language governing permissions and
 # limitations under the License.
 
+import os
 import unittest
 
+from hydra import compose, initialize_config_dir
+from hydra.core.global_hydra import GlobalHydra
 from omegaconf import OmegaConf
 
 
 class TestConfigComparison(unittest.TestCase):
     """Test that current configs match their legacy counterparts exactly."""
 
-    def _compare_configs_recursively(self, current_config, legacy_config, path=""):
-        """Recursively compare two OmegaConf configs and assert they are identical."""
+    def _compare_configs_recursively(self, current_config, legacy_config, path="", legacy_allow_missing=False):
+        """Recursively compare two OmegaConf configs and assert they are identical.
+
+        Args:
+            legacy_allow_missing (bool): sometimes the legacy megatron config contains fewer keys and
+              we allow that to happen
+        """
         if isinstance(current_config, dict) and isinstance(legacy_config, dict):
             current_keys = set(current_config.keys())
             legacy_keys = set(legacy_config.keys())
@@ -32,19 +40,29 @@ def _compare_configs_recursively(self, current_config, legacy_config, path=""):
             if missing_in_current:
                 self.fail(f"Keys missing in current config at {path}: {missing_in_current}")
             if missing_in_legacy:
-                self.fail(f"Keys missing in legacy config at {path}: {missing_in_legacy}")
+                # if the legacy
+                msg = f"Keys missing in legacy config at {path}: {missing_in_legacy}"
+                if legacy_allow_missing:
+                    print(msg)
+                else:
+                    self.fail(msg)
 
             for key in current_keys:
                 current_path = f"{path}.{key}" if path else key
-                self._compare_configs_recursively(current_config[key], legacy_config[key], current_path)
+                if key in legacy_config:
+                    self._compare_configs_recursively(
+                        current_config[key], legacy_config[key], current_path, legacy_allow_missing=legacy_allow_missing
+                    )
         elif isinstance(current_config, list) and isinstance(legacy_config, list):
             self.assertEqual(
                 len(current_config),
                 len(legacy_config),
                 f"List lengths differ at {path}: current={len(current_config)}, legacy={len(legacy_config)}",
             )
             for i, (current_item, legacy_item) in enumerate(zip(current_config, legacy_config)):
-                self._compare_configs_recursively(current_item, legacy_item, f"{path}[{i}]")
+                self._compare_configs_recursively(
+                    current_item, legacy_item, f"{path}[{i}]", legacy_allow_missing=legacy_allow_missing
+                )
         else:
             self.assertEqual(
                 current_config,
@@ -66,7 +84,6 @@ def test_ppo_trainer_config_matches_legacy(self):
                 current_config = compose(config_name="ppo_trainer")
 
             legacy_config = OmegaConf.load("tests/trainer/config/legacy_ppo_trainer.yaml")
-
             current_dict = OmegaConf.to_container(current_config, resolve=True)
             legacy_dict = OmegaConf.to_container(legacy_config, resolve=True)
 
@@ -79,29 +96,42 @@ def test_ppo_trainer_config_matches_legacy(self):
 
     def test_ppo_megatron_trainer_config_matches_legacy(self):
         """Test that ppo_megatron_trainer.yaml matches legacy_ppo_megatron_trainer.yaml exactly."""
-        import os
-
-        from hydra import compose, initialize_config_dir
-        from hydra.core.global_hydra import GlobalHydra
 
         GlobalHydra.instance().clear()
 
         try:
-            with initialize_config_dir(config_dir=os.path.abspath("verl/trainer/config"), version_base=None):
+            with initialize_config_dir(config_dir=os.path.abspath("verl/trainer/config")):
                 current_config = compose(config_name="ppo_megatron_trainer")
 
             legacy_config = OmegaConf.load("tests/trainer/config/legacy_ppo_megatron_trainer.yaml")
-
             current_dict = OmegaConf.to_container(current_config, resolve=True)
             legacy_dict = OmegaConf.to_container(legacy_config, resolve=True)
 
             if "defaults" in current_dict:
                 del current_dict["defaults"]
 
-            self._compare_configs_recursively(current_dict, legacy_dict)
+            self._compare_configs_recursively(current_dict, legacy_dict, legacy_allow_missing=True)
         finally:
             GlobalHydra.instance().clear()
 
+    def test_load_component(self):
+        """Test that ppo_megatron_trainer.yaml matches legacy_ppo_megatron_trainer.yaml exactly."""
+
+        GlobalHydra.instance().clear()
+        configs_to_load = [
+            ("verl/trainer/config/actor", "dp_actor"),
+            ("verl/trainer/config/actor", "megatron_actor"),
+            ("verl/trainer/config/ref", "dp_ref"),
+            ("verl/trainer/config/ref", "megatron_ref"),
+            ("verl/trainer/config/rollout", "rollout"),
+        ]
+        for config_dir, config_file in configs_to_load:
+            try:
+                with initialize_config_dir(config_dir=os.path.abspath(config_dir)):
+                    compose(config_name=config_file)
+            finally:
+                GlobalHydra.instance().clear()
+
 
 if __name__ == "__main__":
     unittest.main()
EOF_114329324912

# Ensure CUDA_VISIBLE_DEVICES is set for CPU-only execution
export CUDA_VISIBLE_DEVICES=""

# Verify environment setup
echo "=" * 70
echo "Environment Verification"
echo "=" * 70
python -c "import sys; print('Python version:', sys.version)"
python -c "from verl.trainer.config import ppo_trainer; print('✓ verl.trainer.config module accessible')"
python -c "import pytest; print('✓ pytest available')"
echo "=" * 70

# Run the target test files
# Using -v for verbose output to help with debugging
# Not using parallel execution (-n auto) to ensure stability in virtualized environment
pytest tests/special_sanity/test_config_docs.py tests/trainer/config/test_legacy_config_on_cpu.py -v --tb=short

# Capture exit code from test execution
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout ad33564f849664069394108792fe5f709b9607f0 "tests/special_sanity/test_config_docs.py" "tests/trainer/config/test_legacy_config_on_cpu.py"