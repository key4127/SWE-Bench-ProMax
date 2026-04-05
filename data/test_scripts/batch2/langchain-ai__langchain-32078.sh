#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 0861cba04b71ea50c188a6926c0e3a3ce7279fd3 "libs/langchain/tests/unit_tests/embeddings/test_imports.py" "libs/langchain/tests/unit_tests/test_imports.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/libs/langchain/tests/unit_tests/embeddings/test_imports.py b/libs/langchain/tests/unit_tests/embeddings/test_imports.py
--- a/libs/langchain/tests/unit_tests/embeddings/test_imports.py
+++ b/libs/langchain/tests/unit_tests/embeddings/test_imports.py
@@ -11,6 +11,7 @@
     "FastEmbedEmbeddings",
     "HuggingFaceEmbeddings",
     "HuggingFaceInferenceAPIEmbeddings",
+    "HypotheticalDocumentEmbedder",
     "InfinityEmbeddings",
     "GradientEmbeddings",
     "JinaEmbeddings",
diff --git a/libs/langchain/tests/unit_tests/test_imports.py b/libs/langchain/tests/unit_tests/test_imports.py
--- a/libs/langchain/tests/unit_tests/test_imports.py
+++ b/libs/langchain/tests/unit_tests/test_imports.py
@@ -96,7 +96,7 @@ def test_no_more_changes_to_proxy_community() -> None:
         # most cases.
         hash_ += len(str(sorted(deprecated_lookup.items())))
 
-    evil_magic_number = 38572
+    evil_magic_number = 38644
 
     assert hash_ == evil_magic_number, (
         "If you're triggering this test, you're likely adding a new import "
EOF_114329324912

# Change to the working directory as specified in project structure
cd /testbed/libs/langchain

# Execute the target test files using uv run with test group
# Running in single-process mode for safety in virtualized environment
uv run --group test pytest tests/unit_tests/test_imports.py tests/unit_tests/embeddings/test_imports.py \
    --strict-markers \
    --strict-config \
    -v

# Capture exit code immediately after test execution
rc=$?

# Required: Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Reset the test files to original state
cd /testbed
git checkout 0861cba04b71ea50c188a6926c0e3a3ce7279fd3 "libs/langchain/tests/unit_tests/embeddings/test_imports.py" "libs/langchain/tests/unit_tests/test_imports.py"