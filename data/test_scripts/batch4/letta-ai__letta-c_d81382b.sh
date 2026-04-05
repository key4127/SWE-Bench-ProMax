#!/bin/bash
set -uxo pipefail

cd /testbed

# Activate Poetry virtual environment
source /testbed/.venv/bin/activate

# Checkout the target configuration file to ensure clean state
git checkout d2f5bb676f66c748504cd6bcf9d8d430802cd215 "tests/configs/llm_model_configs/openai-gpt-4o-mini.json"

# Apply the test patch to the configuration file
git apply -v - <<'EOF_114329324912'
diff --git a/tests/configs/llm_model_configs/openai-gpt-4o-mini.json b/tests/configs/llm_model_configs/openai-gpt-4o-mini.json
--- a/tests/configs/llm_model_configs/openai-gpt-4o-mini.json
+++ b/tests/configs/llm_model_configs/openai-gpt-4o-mini.json
@@ -1,5 +1,5 @@
 {
-  "context_window": 8192,
+  "context_window": 128000,
   "model": "gpt-4o-mini",
   "model_endpoint_type": "openai",
   "model_endpoint": "https://api.openai.com/v1",
EOF_114329324912

# Validate the JSON file with Pydantic schema
echo "Validating JSON configuration against LLMConfig schema..."
python -c "
import json
from pathlib import Path
from letta.schemas.llm_config import LLMConfig

config_path = Path('tests/configs/llm_model_configs/openai-gpt-4o-mini.json')
config_data = json.load(open(config_path))
config = LLMConfig(**config_data)
print('✓ Configuration validation successful!')
print(f'  Model: {config.model}')
print(f'  Endpoint Type: {config.model_endpoint_type}')
print(f'  Context Window: {config.context_window}')
"
rc=$?

if [ $rc -eq 0 ]; then
    echo "✓ JSON configuration file is valid and passes schema validation"
else
    echo "✗ JSON configuration file validation failed"
fi

# Capture and report exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original file
git checkout d2f5bb676f66c748504cd6bcf9d8d430802cd215 "tests/configs/llm_model_configs/openai-gpt-4o-mini.json"