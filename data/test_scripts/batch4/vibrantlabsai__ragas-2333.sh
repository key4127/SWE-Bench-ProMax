#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 31bf2a832d6347f89ab93192be6bfeaa19082dbe "tests/unit/test_simple_llm_metric_persistence.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unit/test_simple_llm_metric_persistence.py b/tests/unit/test_simple_llm_metric_persistence.py
--- a/tests/unit/test_simple_llm_metric_persistence.py
+++ b/tests/unit/test_simple_llm_metric_persistence.py
@@ -206,7 +206,7 @@ async def aembed_query(self, text: str):
 
         try:
             # Save (should warn about embedding model)
-            with pytest.warns(UserWarning, match="embedding_model cannot be saved"):
+            with pytest.warns(UserWarning, match="embedding_model will be lost"):
                 original_metric.save(temp_path)
 
             # Load (provide embedding model)
EOF_114329324912

# Set environment variables for test execution
export RAGAS_DO_NOT_TRACK=true
export __RAGAS_DEBUG_TRACKING=true

# Execute the target test file
# Using single-process mode for stability in virtualized environment
pytest tests/unit/test_simple_llm_metric_persistence.py -v --tb=short
rc=$?

# Echo exit code for test result verification
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original file
git checkout 31bf2a832d6347f89ab93192be6bfeaa19082dbe "tests/unit/test_simple_llm_metric_persistence.py"