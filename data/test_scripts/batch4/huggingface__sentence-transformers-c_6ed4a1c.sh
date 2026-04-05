#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Ensure environment variables are set
export TOKENIZERS_PARALLELISM=false

# Checkout the target test files to ensure clean state
git checkout e212adcf20a823f9301b05241bb400e794d24b4b \
    "examples/sparse_encoder/applications/application_test_inference_free.py" \
    "tests/models/test_router.py" \
    "tests/test_trainer.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/examples/sparse_encoder/applications/application_test_inference_free.py b/examples/sparse_encoder/applications/application_test_inference_free.py
--- a/examples/sparse_encoder/applications/application_test_inference_free.py
+++ b/examples/sparse_encoder/applications/application_test_inference_free.py
@@ -4,7 +4,7 @@
 
 print("# ------------------------------------------example with v2 distill-----------------------------------------")
 doc_encoder = MLMTransformer("opensearch-project/opensearch-neural-sparse-encoding-doc-v2-distill")
-asym = models.Asym(
+asym = models.Router(
     {
         "query": [
             IDF.from_json(
@@ -13,7 +13,7 @@
                 frozen=True,
             ),
         ],
-        "doc": [
+        "document": [
             doc_encoder,
             SpladePooling("max"),
         ],
@@ -29,7 +29,7 @@
 document = "Currently New York is rainy."
 
 query_embed = model.encode([{"query": query}])
-document_embed = model.encode([{"doc": document}])
+document_embed = model.encode([{"document": document}])
 
 sim = model.similarity(query_embed, document_embed)
 print(f"Similarity: {sim}")
@@ -59,7 +59,7 @@
 
 print("# -----------------------------------------example with v3 distill-----------------------------------------")
 doc_encoder = MLMTransformer("opensearch-project/opensearch-neural-sparse-encoding-doc-v3-distill")
-asym = models.Asym(
+asym = models.Router(
     {
         "query": [
             IDF.from_json(
@@ -68,7 +68,7 @@
                 frozen=True,
             ),
         ],
-        "doc": [
+        "document": [
             doc_encoder,
             SpladePooling(pooling_strategy="max", activation_function="log1p_relu"),
         ],
@@ -84,7 +84,7 @@
 document = "Currently New York is rainy."
 
 query_embed = model.encode([{"query": query}])
-document_embed = model.encode([{"doc": document}])
+document_embed = model.encode([{"document": document}])
 
 sim = model.similarity(query_embed, document_embed)
 print(f"Similarity: {sim}")
diff --git a/tests/models/test_router.py b/tests/models/test_router.py
--- a/tests/models/test_router.py
+++ b/tests/models/test_router.py
@@ -1,11 +1,21 @@
 from __future__ import annotations
 
+import importlib
+import os
 import re
+import tempfile
+from copy import deepcopy
 
 import pytest
-
-from sentence_transformers import SentenceTransformer
-from sentence_transformers.models import Asym, Router
+from datasets import Dataset
+
+from sentence_transformers import (
+    SentenceTransformer,
+    SentenceTransformerTrainer,
+    SentenceTransformerTrainingArguments,
+    losses,
+)
+from sentence_transformers.models import Asym, Dense, Normalize, Router
 from sentence_transformers.models.InputModule import InputModule
 
 
@@ -29,6 +39,21 @@ def __init__(self, max_seq_length=32):
         self.max_seq_length = max_seq_length
 
 
+# Create a custom dict subclass to track access
+class TaskTypesTrackingDict(dict):
+    def __init__(self, *args, **kwargs):
+        super().__init__(*args, **kwargs)
+        self.task_types = []
+
+    def get(self, key, default=None):
+        self.task_types.append(key)
+        return super().get(key, default)
+
+    def __getitem__(self, key):
+        self.task_types.append(key)
+        return super().__getitem__(key)
+
+
 @pytest.mark.parametrize("routes", [{}, None])
 def test_router_empty_routes_raises_value_error(routes):
     """Test that Router raises ValueError when initialized with empty routes dictionary or None."""
@@ -135,20 +160,9 @@ def test_router_encode(static_embedding_model):
     # Create a Router with StaticEmbedding modules
     router = Router({"query": [static_embedding_model], "document": [static_embedding_model]})
 
-    task_types = []
-
-    # Create a custom dict subclass to track access
-    class TrackingDict(dict):
-        def get(self, key, default=None):
-            task_types.append(key)
-            return super().get(key, default)
-
-        def __getitem__(self, key):
-            task_types.append(key)
-            return super().__getitem__(key)
-
     # Replace the dictionary with our tracking version
-    router.sub_modules = TrackingDict(router.sub_modules)
+    tracking_dict = TaskTypesTrackingDict(router.sub_modules)
+    router.sub_modules = tracking_dict
 
     model = SentenceTransformer(modules=[router])
 
@@ -157,23 +171,23 @@ def __getitem__(self, key):
     doc_texts = ["The capital of France is Paris."]
 
     model.encode_query(query_texts)
-    assert "query" in task_types
-    task_types = []
+    assert "query" in tracking_dict.task_types
+    tracking_dict.task_types = []
 
     model.encode_document(doc_texts)
-    assert "document" in task_types
-    task_types = []
+    assert "document" in tracking_dict.task_types
+    tracking_dict.task_types = []
 
     # The default route should be used if no task type is specified
     model.encode(query_texts)
     assert router.default_route == "query"
-    assert "query" in task_types
-    task_types = []
+    assert "query" in tracking_dict.task_types
+    tracking_dict.task_types = []
 
     # Test with a different default route
     router.default_route = "document"
     model.encode(doc_texts)
-    assert "document" in task_types
+    assert "document" in tracking_dict.task_types
 
     # Test with an incorrect route
     with pytest.raises(
@@ -201,26 +215,200 @@ def test_router_backwards_compatibility(static_embedding_model):
     # Create a mock Asym model
     asym_model = Asym({"query": [static_embedding_model], "document": [static_embedding_model]})
 
-    task_types = []
-
-    # Create a custom dict subclass to track access
-    class TrackingDict(dict):
-        def get(self, key, default=None):
-            task_types.append(key)
-            return super().get(key, default)
-
-        def __getitem__(self, key):
-            task_types.append(key)
-            return super().__getitem__(key)
-
     # Replace the dictionary with our tracking version
-    asym_model.sub_modules = TrackingDict(asym_model.sub_modules)
+    tracking_dict = TaskTypesTrackingDict(asym_model.sub_modules)
+    asym_model.sub_modules = tracking_dict
 
     model = SentenceTransformer(modules=[asym_model])
     model.encode([{"query": "What is the capital of France?"}, {"query": "The capital of France is Paris."}])
-    assert task_types == ["query", "query"]
-    task_types = []
+    assert tracking_dict.task_types == ["query", "query"]
+    tracking_dict.task_types = []
 
     model.encode([{"document": "What is the capital of France?"}, {"document": "The capital of France is Paris."}])
-    assert task_types == ["document", "document"]
-    task_types = []
+    assert tracking_dict.task_types == ["document", "document"]
+    tracking_dict.task_types = []
+
+
+def test_router_save_load(static_embedding_model):
+    """Test saving and loading a SentenceTransformer model with Router."""
+    # Create a Router with StaticEmbedding modules
+    router = Router({"query": [static_embedding_model], "document": [static_embedding_model]})
+    model = SentenceTransformer(modules=[router])
+
+    # Test data for encoding
+    query_texts = ["What is the capital of France?"]
+    doc_texts = ["The capital of France is Paris."]
+
+    # Get original embeddings
+    query_embeddings_original = model.encode_query(query_texts)
+    doc_embeddings_original = model.encode_document(doc_texts)
+
+    # Save the model to a temporary directory
+    with tempfile.TemporaryDirectory() as tmp_dir:
+        model_path = os.path.join(tmp_dir, "test_model")
+        model.save(model_path)
+
+        # Load the model
+        loaded_model = SentenceTransformer(model_path)
+
+        # Verify loaded model structure
+        assert len(list(loaded_model.children())) == 1
+        assert isinstance(loaded_model[0], Router)
+        loaded_router = loaded_model[0]
+        assert set(loaded_router.sub_modules.keys()) == {"query", "document"}
+        assert loaded_router.default_route == "query"
+
+        # Get embeddings from loaded model
+        query_embeddings_loaded = loaded_model.encode_query(query_texts)
+        doc_embeddings_loaded = loaded_model.encode_document(doc_texts)
+
+        # Verify embeddings are the same
+        assert (query_embeddings_original == query_embeddings_loaded).all()
+        assert (doc_embeddings_original == doc_embeddings_loaded).all()
+
+
+def test_router_save_load_with_custom_default_route(static_embedding_model):
+    """Test saving and loading a model with custom default route."""
+    router = Router(
+        {"query": [static_embedding_model], "document": [static_embedding_model]}, default_route="document"
+    )
+    model = SentenceTransformer(modules=[router])
+
+    with tempfile.TemporaryDirectory() as tmp_dir:
+        model_path = os.path.join(tmp_dir, "test_model")
+        model.save(model_path)
+
+        loaded_model = SentenceTransformer(model_path)
+        loaded_router = loaded_model[0]
+
+        # Verify default route was preserved
+        assert loaded_router.default_route == "document"
+
+        # Test that default encoding uses the document route
+        texts = ["Test text"]
+        default_embeddings = loaded_model.encode(texts)
+        doc_embeddings = loaded_model.encode_document(texts)
+        assert (default_embeddings == doc_embeddings).all()
+
+
+def test_router_save_load_without_default_route(static_embedding_model):
+    """Test saving and loading a model without a default route."""
+    router = Router({"query": [static_embedding_model], "document": [static_embedding_model]}, allow_empty_key=False)
+    model = SentenceTransformer(modules=[router])
+
+    with tempfile.TemporaryDirectory() as tmp_dir:
+        model_path = os.path.join(tmp_dir, "test_model")
+        model.save(model_path)
+
+        loaded_model = SentenceTransformer(model_path)
+        loaded_router = loaded_model[0]
+        # Verify default route is None
+        assert loaded_router.default_route is None
+
+        # Test that encoding without task_type raises error
+        with pytest.raises(
+            ValueError,
+            match=re.escape("``task_type`` must be specified, or the ``Router`` must have a ``default_route`` set."),
+        ):
+            loaded_model.encode(["Test text"])
+
+
+def test_router_save_load_with_multiple_modules_per_route(static_embedding_model):
+    """Test saving and loading a model with multiple modules per route."""
+    # Create two different mock modules for testing
+    static_embedding_model_one = deepcopy(static_embedding_model)
+    static_embedding_model_two = deepcopy(static_embedding_model)
+    dense = Dense(in_features=static_embedding_model.get_sentence_embedding_dimension(), out_features=128)
+    normalize_one = Normalize()
+    normalize_two = Normalize()
+    router = Router(
+        {
+            "query": [static_embedding_model_one, dense, normalize_one],
+            "document": [static_embedding_model_two, normalize_two],
+        }
+    )
+    model = SentenceTransformer(modules=[router])
+
+    with tempfile.TemporaryDirectory() as tmp_dir:
+        model_path = os.path.join(tmp_dir, "test_model")
+        model.save(model_path)
+
+        loaded_model = SentenceTransformer(model_path)
+        loaded_router = loaded_model[0]
+
+        # Verify structure
+        assert len(loaded_router.sub_modules["query"]) == 3
+        assert len(loaded_router.sub_modules["document"]) == 2
+
+        # The first route has priority here, but usually all routes have the same embedding dimension
+        # as they can't be compared otherwise
+        assert loaded_model.get_sentence_embedding_dimension() == 128
+
+        # If we swap the order of the routes, the new first route should be used
+        loaded_router.sub_modules = {
+            "document": loaded_router.sub_modules["document"],
+            "query": loaded_router.sub_modules["query"],
+        }
+        assert loaded_model.get_sentence_embedding_dimension() == 768
+
+
+def test_router_with_trainer(static_embedding_model):
+    """Test Router works correctly with a training setup using router_mapping."""
+
+    # Create a Router with StaticEmbedding modules
+    router = Router({"query": [static_embedding_model], "document": [static_embedding_model]}, allow_empty_key=False)
+    model = SentenceTransformer(modules=[router])
+
+    tracking_dict = TaskTypesTrackingDict(router.sub_modules)
+    router.sub_modules = tracking_dict
+
+    train_dataset = Dataset.from_dict(
+        {
+            "question": ["What is the capital of France?", "What is the largest ocean?"],
+            "answer": ["The capital of France is Paris.", "The largest ocean is the Pacific Ocean."],
+        }
+    )
+
+    # Setup router mapping for training
+    router_mapping = {"question": "query", "answer": "document"}
+
+    # Create a loss function that works with router
+    loss = losses.MultipleNegativesRankingLoss(model=model)
+
+    args = SentenceTransformerTrainingArguments(
+        output_dir=tempfile.mkdtemp(),
+        router_mapping=router_mapping,
+    )
+
+    trainer = SentenceTransformerTrainer(
+        model=model,
+        train_dataset=train_dataset,
+        loss=loss,
+        args=args,
+    )
+    tracking_dict.task_types.clear()  # Clear tracking before training
+    trainer.train()
+
+    # Once for tokenizing, once for forward
+    assert tracking_dict.task_types == ["query", "document"] * 6
+
+
+@pytest.mark.parametrize(
+    ("module_names", "module_attributes"),
+    [
+        (
+            [
+                "sentence_transformers.models.Asym",
+                "sentence_transformers.models.Router",
+                "sentence_transformers.models",
+            ],
+            [Asym, Router],
+        ),
+    ],
+)
+def test_asym_import(module_names: list[str], module_attributes: list[object]) -> None:
+    for module_name in module_names:
+        module = importlib.import_module(module_name)
+        for module_attribute in module_attributes:
+            obj = getattr(module, module_attribute.__name__, None)
+            assert obj is module_attribute
diff --git a/tests/test_trainer.py b/tests/test_trainer.py
--- a/tests/test_trainer.py
+++ b/tests/test_trainer.py
@@ -455,23 +455,22 @@ def upper_transform(batch):
         args = SentenceTransformerTrainingArguments(
             output_dir=str(temp_dir),
             prompts=prompts,
-            max_steps=2,
-            eval_steps=2,
+            max_steps=4 if train_dict else 2,
+            eval_steps=4 if train_dict else 2,
             eval_strategy="steps",
             per_device_train_batch_size=1,
             per_device_eval_batch_size=1,
             report_to=["none"],
         )
-        with context:
-            trainer = SentenceTransformerTrainer(
-                model=model,
-                args=args,
-                train_dataset=train_dataset,
-                eval_dataset=eval_dataset,
-                loss=loss,
-            )
-        if not isinstance(context, nullcontext):
-            return
+        trainer = SentenceTransformerTrainer(
+            model=model,
+            args=args,
+            train_dataset=train_dataset,
+            eval_dataset=eval_dataset,
+            loss=loss,
+        )
+
+        tracked_texts.clear()
 
         datacollator_keys = set()
         old_compute_loss = trainer.compute_loss
@@ -482,7 +481,11 @@ def compute_loss_tracker(model, inputs, **kwargs):
             return loss
 
         trainer.compute_loss = compute_loss_tracker
-        trainer.train()
+        with context:
+            trainer.train()
+
+        if not isinstance(context, nullcontext):
+            return
 
     # In this one edge case, the prompts won't be used because the datasets aren't dictionaries, so the prompts
     # are seen as column names & ignored as they don't exist.
@@ -497,8 +500,8 @@ def compute_loss_tracker(model, inputs, **kwargs):
     else:
         assert "prompt_length" not in tracked_forward_keys
 
-    # We only need the dataset_name if the loss requires it
-    if loss_dict:
+    # We only need the dataset_name if the loss requires it, or the prompts are a nested dictionary
+    if (train_dict or eval_dict) and (loss_dict or (isinstance(prompts, dict))):
         assert "dataset_name" in datacollator_keys
     else:
         assert "dataset_name" not in datacollator_keys
EOF_114329324912

# Run the target tests
# Note: application_test_inference_free.py is a standalone script, not a pytest test
# We run it separately first, then run the pytest tests

echo "=========================================="
echo "Running standalone example script..."
echo "=========================================="
python examples/sparse_encoder/applications/application_test_inference_free.py
example_rc=$?

echo "=========================================="
echo "Running pytest tests..."
echo "=========================================="
# Run pytest tests in single-process mode for stability
# Using -v for verbose output and -x to stop on first failure
pytest -v -x \
    tests/models/test_router.py \
    tests/test_trainer.py

pytest_rc=$?

# Determine overall exit code (fail if either failed)
if [ $example_rc -ne 0 ] || [ $pytest_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout e212adcf20a823f9301b05241bb400e794d24b4b \
    "examples/sparse_encoder/applications/application_test_inference_free.py" \
    "tests/models/test_router.py" \
    "tests/test_trainer.py"