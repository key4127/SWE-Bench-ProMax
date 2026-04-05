#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout cf3d9c5e5f1c90f71d3a9d30b9ec7ce5de6b1ca0 "test/utils/test_deduplication.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/utils/test_deduplication.py b/test/utils/test_deduplication.py
--- a/test/utils/test_deduplication.py
+++ b/test/utils/test_deduplication.py
@@ -21,8 +21,7 @@
 
 
 class MockEmbedding(BaseEmbedding[str]):
-    """
-    A mock embedding class that always returns the same embedding vector
+    r"""A mock embedding class that always returns the same embedding vector
     for any input text. Useful for testing deduplication logic.
     """
 
@@ -36,6 +35,36 @@ def get_output_dim(self) -> int:
         return 3
 
 
+def test_deduplicate_internally_empty_list():
+    mock_embedding_instance = MockEmbedding()
+    result = deduplicate_internally(
+        texts=[],
+        threshold=0.9,
+        embedding_instance=mock_embedding_instance,
+        strategy="top1",
+    )
+    assert len(result.original_texts) == 0
+    assert len(result.unique_ids) == 0
+    assert len(result.unique_embeddings_dict) == 0
+    assert len(result.duplicate_to_target_map) == 0
+
+
+def test_deduplicate_internally_single_item():
+    mock_embedding_instance = MockEmbedding()
+    texts = ["Hello world!"]
+    result = deduplicate_internally(
+        texts=texts,
+        threshold=0.9,
+        embedding_instance=mock_embedding_instance,
+        strategy="top1",
+    )
+    assert result.original_texts == texts
+    assert result.unique_ids == [0]
+    assert len(result.unique_embeddings_dict) == 1
+    assert 0 in result.unique_embeddings_dict
+    assert len(result.duplicate_to_target_map) == 0
+
+
 def test_deduplicate_internally_with_mock_embedding():
     texts = ["Hello world!", "Hello world!", "HELLO WORLD!", "Something else"]
     mock_embedding_instance = MockEmbedding()
@@ -116,8 +145,7 @@ def test_deduplicate_internally_with_precomputed_embeddings():
 
 
 def test_deduplicate_internally_chain_scenario():
-    """
-    Test scenario:
+    r"""Test scenario:
       - A <-> B similarity > threshold
       - B <-> C similarity > threshold
       - C <-> D similarity > threshold
EOF_114329324912

# Run the target test file with verbose output
pytest test/utils/test_deduplication.py -v

# Capture the exit code
rc=$?

# Echo the exit code for the judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout cf3d9c5e5f1c90f71d3a9d30b9ec7ce5de6b1ca0 "test/utils/test_deduplication.py"