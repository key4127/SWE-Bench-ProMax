#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files before applying patch
git checkout a901f56b8f3aa7337686164d4ff55016012bca61 "tests/trainer/config/legacy_ppo_trainer.yaml"

# Apply the test patch to modify the test files
git apply -v - <<'EOF_114329324912'
diff --git a/tests/trainer/config/legacy_ppo_trainer.yaml b/tests/trainer/config/legacy_ppo_trainer.yaml
--- a/tests/trainer/config/legacy_ppo_trainer.yaml
+++ b/tests/trainer/config/legacy_ppo_trainer.yaml
@@ -115,6 +115,9 @@ data:
     # the name of the curriculum class like `MySampler`
     class_name: null
 
+  # Additional kwargs when calling tokenizer.apply_chat_template
+  apply_chat_template_kwargs: {}
+
 # config for actor, rollout and reference model
 actor_rollout_ref:
 
EOF_114329324912

# Verify the test environment and required files
echo "======================================================================"
echo "VALIDATION: VERL Configuration Test Setup"
echo "======================================================================"
echo "Python version: $(python --version)"
echo "Working directory: $(pwd)"
echo "Git commit: $(git rev-parse HEAD)"
echo "PYTHONPATH: $PYTHONPATH"
echo ""
echo "Target configuration file:"
ls -lh tests/trainer/config/legacy_ppo_trainer.yaml
echo ""
echo "Related test files in config directory:"
ls -lh tests/trainer/config/*.py 2>/dev/null || echo "No Python test files found"
echo "======================================================================"

# Validate YAML syntax of the configuration file
echo ""
echo "======================================================================"
echo "Validating YAML Configuration Syntax..."
echo "======================================================================"
python -c "import yaml; config = yaml.safe_load(open('tests/trainer/config/legacy_ppo_trainer.yaml')); print('✓ YAML syntax is valid'); print(f'Configuration keys: {list(config.keys()) if isinstance(config, dict) else \"Not a dict\"}')"
yaml_rc=$?
echo "YAML validation exit code: $yaml_rc"

# Execute the related CPU-based configuration tests
# This test validates the legacy PPO trainer configuration structure
echo ""
echo "======================================================================"
echo "Running Configuration Tests..."
echo "======================================================================"
if [ -f "tests/trainer/config/test_legacy_config_on_cpu.py" ]; then
    pytest -xvs tests/trainer/config/test_legacy_config_on_cpu.py
    test_rc=$?
    echo "Configuration test exit code: $test_rc"
else
    echo "Warning: test_legacy_config_on_cpu.py not found, running all config tests..."
    pytest -xvs tests/trainer/config/
    test_rc=$?
    echo "Configuration tests exit code: $test_rc"
fi

# Combine exit codes - fail if either validation fails
if [ $yaml_rc -ne 0 ] || [ $test_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Required: echo test status for the judge
echo ""
echo "======================================================================"
echo "OMNIGRIL_EXIT_CODE=$rc"
echo "======================================================================"

# Restore original test files
git checkout a901f56b8f3aa7337686164d4ff55016012bca61 "tests/trainer/config/legacy_ppo_trainer.yaml"

exit $rc