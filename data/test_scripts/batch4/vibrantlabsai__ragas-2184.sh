#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target files to ensure clean state
git checkout aa1aacd50f5bff889a26bc3bf6be522c6c5bb048 "ragas/src/ragas/testset/transforms/extractors/embeddings.py" "ragas/tests/experimental/conftest.py" "ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py" "ragas/tests/unit/test_embeddings.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/ragas/src/ragas/testset/transforms/extractors/embeddings.py b/ragas/src/ragas/testset/transforms/extractors/embeddings.py
--- a/ragas/src/ragas/testset/transforms/extractors/embeddings.py
+++ b/ragas/src/ragas/testset/transforms/extractors/embeddings.py
@@ -1,7 +1,7 @@
 import typing as t
 from dataclasses import dataclass, field
 
-from ragas.embeddings import BaseRagasEmbeddings, embedding_factory
+from ragas.embeddings import BaseRagasEmbeddings, BaseRagasEmbedding, embedding_factory
 from ragas.testset.graph import Node
 from ragas.testset.transforms.base import Extractor
 
@@ -17,13 +17,15 @@ class EmbeddingExtractor(Extractor):
         The name of the property to store the embedding
     embed_property_name : str
         The name of the property containing the text to embed
-    embedding_model : BaseRagasEmbeddings
+    embedding_model : BaseRagasEmbeddings or BaseRagasEmbedding
         The embedding model used for generating embeddings
     """
 
     property_name: str = "embedding"
     embed_property_name: str = "page_content"
-    embedding_model: BaseRagasEmbeddings = field(default_factory=embedding_factory)
+    embedding_model: t.Union[BaseRagasEmbeddings, BaseRagasEmbedding] = field(
+        default_factory=embedding_factory
+    )
 
     async def extract(self, node: Node) -> t.Tuple[str, t.Any]:
         """
@@ -39,5 +41,11 @@ async def extract(self, node: Node) -> t.Tuple[str, t.Any]:
             raise ValueError(
                 f"node.property('{self.embed_property_name}') must be a string, found '{type(text)}'"
             )
-        embedding = await self.embedding_model.embed_text(text)
+        # Handle both modern (BaseRagasEmbedding) and legacy (BaseRagasEmbeddings) interfaces
+        if hasattr(self.embedding_model, "aembed_text"):
+            # Modern interface (BaseRagasEmbedding)
+            embedding = await self.embedding_model.aembed_text(text)  # type: ignore[attr-defined]
+        else:
+            # Legacy interface (BaseRagasEmbeddings)
+            embedding = await self.embedding_model.embed_text(text)  # type: ignore[misc]
         return self.property_name, embedding
diff --git a/ragas/tests/experimental/conftest.py b/ragas/tests/experimental/conftest.py
--- a/ragas/tests/experimental/conftest.py
+++ b/ragas/tests/experimental/conftest.py
@@ -6,7 +6,7 @@
 import pytest
 from pydantic import BaseModel
 
-from ragas.experimental.embeddings.base import BaseEmbedding
+from ragas.embeddings.base import BaseRagasEmbedding as BaseEmbedding
 
 
 def pytest_configure(config):
diff --git a/ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py b/ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py
--- a/ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py
+++ b/ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py
@@ -5,7 +5,7 @@
 import pytest
 from pydantic import BaseModel
 
-from ragas.experimental.embeddings.base import BaseEmbedding
+from ragas.embeddings.base import BaseRagasEmbedding as BaseEmbedding
 from ragas.experimental.prompt.dynamic_few_shot import DynamicFewShotPrompt
 
 
diff --git a/ragas/tests/unit/test_embeddings.py b/ragas/tests/unit/test_embeddings.py
--- a/ragas/tests/unit/test_embeddings.py
+++ b/ragas/tests/unit/test_embeddings.py
@@ -1 +1,78 @@
 from __future__ import annotations
+
+
+def test_basic_legacy_imports():
+    """Test that basic legacy imports work."""
+    from ragas.embeddings import BaseRagasEmbeddings, embedding_factory
+
+    assert BaseRagasEmbeddings is not None
+    assert embedding_factory is not None
+
+
+def test_debug_base_module():
+    """Debug what's available in base module."""
+    import ragas.embeddings.base as base_module
+
+    # Check if BaseRagasEmbedding is in the module
+    has_class = hasattr(base_module, "BaseRagasEmbedding")
+    print(f"base_module has BaseRagasEmbedding: {has_class}")
+
+    if has_class:
+        cls = getattr(base_module, "BaseRagasEmbedding")
+        print(f"BaseRagasEmbedding type: {type(cls)}")
+        assert cls is not None
+    else:
+        # List what is available
+        attrs = [attr for attr in dir(base_module) if not attr.startswith("_")]
+        print(f"Available attributes: {attrs}")
+        raise AssertionError("BaseRagasEmbedding not found in base module")
+
+
+def test_direct_import_from_base():
+    """Test direct import from base module."""
+    try:
+        from ragas.embeddings.base import BaseRagasEmbedding
+
+        print(f"Successfully imported BaseRagasEmbedding: {BaseRagasEmbedding}")
+        assert BaseRagasEmbedding is not None
+    except ImportError as e:
+        print(f"Import error: {e}")
+        # Try to import the whole module first
+        import ragas.embeddings.base
+
+        print(f"Module imported successfully: {ragas.embeddings.base}")
+        # Now try to get the class
+        if hasattr(ragas.embeddings.base, "BaseRagasEmbedding"):
+            cls = getattr(ragas.embeddings.base, "BaseRagasEmbedding")
+            print(f"Found class via getattr: {cls}")
+        else:
+            print("Class not found via getattr either")
+        raise
+
+
+def test_main_module_import():
+    """Test import from main embeddings module."""
+    try:
+        from ragas.embeddings import RagasBaseEmbedding
+
+        print(f"Successfully imported from main module: {RagasBaseEmbedding}")
+        assert RagasBaseEmbedding is not None
+    except ImportError as e:
+        print(f"Main module import error: {e}")
+        # Check what's in the main module
+        import ragas.embeddings
+
+        attrs = [
+            attr for attr in dir(ragas.embeddings) if "Ragas" in attr or "Base" in attr
+        ]
+        print(f"Ragas/Base related attributes in main module: {attrs}")
+        raise
+
+
+def test_backward_compatibility_alias():
+    """Test that RagasBaseEmbedding works as an alias to BaseRagasEmbedding."""
+    from ragas.embeddings import BaseRagasEmbedding, RagasBaseEmbedding
+
+    # They should be the same class
+    assert RagasBaseEmbedding is BaseRagasEmbedding
+    print("Backward compatibility confirmed: RagasBaseEmbedding is BaseRagasEmbedding")
EOF_114329324912

# Change to ragas subdirectory for test execution
cd /testbed/ragas

# Set environment variables for test execution
export RAGAS_DO_NOT_TRACK=true
export __RAGAS_DEBUG_TRACKING=true

# Execute the target test files
# Note: Only running the actual test files, excluding conftest.py and source code files
pytest tests/experimental/unit/test_dynamic_few_shot_prompt.py tests/unit/test_embeddings.py -v --tb=short
rc=$?

# Echo exit code for test result verification
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout aa1aacd50f5bff889a26bc3bf6be522c6c5bb048 "ragas/src/ragas/testset/transforms/extractors/embeddings.py" "ragas/tests/experimental/conftest.py" "ragas/tests/experimental/unit/test_dynamic_few_shot_prompt.py" "ragas/tests/unit/test_embeddings.py"