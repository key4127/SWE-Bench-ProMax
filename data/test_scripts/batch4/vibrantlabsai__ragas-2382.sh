#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target files to ensure clean state
git checkout f0bff88cf957a9171f267c6d29e036079e4a4230 "docs/howtos/customizations/testgenerator/_persona_generator.md" "docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md" "docs/howtos/customizations/testgenerator/_testgen-customisation.md" "src/ragas/testset/synthesizers/__init__.py" "src/ragas/testset/synthesizers/base.py" "src/ragas/testset/transforms/base.py" "src/ragas/testset/transforms/default.py" "tests/e2e/metrics_migration/conftest.py" "tests/e2e/metrics_migration/test_answer_correctness_migration.py" "tests/e2e/metrics_migration/test_answer_relevancy_migration.py" "tests/e2e/metrics_migration/test_aspect_critic_migration.py" "tests/e2e/metrics_migration/test_context_entity_recall_migration.py" "tests/unit/llms/test_instructor_factory.py" "tests/utils/llm_setup.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/docs/howtos/customizations/testgenerator/_persona_generator.md b/docs/howtos/customizations/testgenerator/_persona_generator.md
--- a/docs/howtos/customizations/testgenerator/_persona_generator.md
+++ b/docs/howtos/customizations/testgenerator/_persona_generator.md
@@ -44,14 +44,16 @@ And then you can use these personas in the testset generation process by passing
 
 
 ```python
+from openai import OpenAI
 from ragas.testset import TestsetGenerator
 from ragas.testset.graph import KnowledgeGraph
 from ragas.llms import llm_factory
 
 # Load the knowledge graph
 kg = KnowledgeGraph.load("../../../../experiments/gitlab_kg.json")
 # Initialize the Generator LLM
-llm = llm_factory("gpt-4o-mini")
+openai_client = OpenAI()
+llm = llm_factory("gpt-4o-mini", client=openai_client)
 
 # Initialize the Testset Generator
 testset_generator = TestsetGenerator(knowledge_graph=kg, persona_list=personas, llm=llm)
diff --git a/docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md b/docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md
--- a/docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md
+++ b/docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md
@@ -44,12 +44,12 @@ for doc in docs:
 You may use any of [your choice](./../../customizations/customize_models.md), here I am using models from open-ai.
 
 ```python
-from ragas.llms.base import llm_factory
+from openai import OpenAI
+from ragas.llms import llm_factory
 from ragas.embeddings import OpenAIEmbeddings
-import openai
 
-llm = llm_factory()
-openai_client = openai.OpenAI()
+openai_client = OpenAI()
+llm = llm_factory("gpt-4o-mini", client=openai_client)
 embedding = OpenAIEmbeddings(client=openai_client)
 ```
 
diff --git a/docs/howtos/customizations/testgenerator/_testgen-customisation.md b/docs/howtos/customizations/testgenerator/_testgen-customisation.md
--- a/docs/howtos/customizations/testgenerator/_testgen-customisation.md
+++ b/docs/howtos/customizations/testgenerator/_testgen-customisation.md
@@ -47,12 +47,12 @@ You may use any of [your choice](./../../customizations/customize_models.md), he
 
 
 ```python
-from ragas.llms.base import llm_factory
+from openai import OpenAI
+from ragas.llms import llm_factory
 from ragas.embeddings import OpenAIEmbeddings
-import openai
 
-llm = llm_factory()
-openai_client = openai.OpenAI()
+openai_client = OpenAI()
+llm = llm_factory("gpt-4o-mini", client=openai_client)
 embedding = OpenAIEmbeddings(client=openai_client)
 ```
 
diff --git a/src/ragas/testset/synthesizers/__init__.py b/src/ragas/testset/synthesizers/__init__.py
--- a/src/ragas/testset/synthesizers/__init__.py
+++ b/src/ragas/testset/synthesizers/__init__.py
@@ -1,7 +1,7 @@
 import logging
 import typing as t
 
-from ragas.llms import BaseRagasLLM
+from ragas.llms.base import BaseRagasLLM
 from ragas.testset.graph import KnowledgeGraph
 from ragas.testset.synthesizers.multi_hop import (
     MultiHopAbstractQuerySynthesizer,
@@ -13,13 +13,17 @@
 
 from .base import BaseSynthesizer
 
+if t.TYPE_CHECKING:
+    from ragas.llms.base import InstructorBaseRagasLLM
+
 logger = logging.getLogger(__name__)
 
 QueryDistribution = t.List[t.Tuple[BaseSynthesizer, float]]
 
 
 def default_query_distribution(
-    llm: BaseRagasLLM, kg: t.Optional[KnowledgeGraph] = None
+    llm: t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"],
+    kg: t.Optional[KnowledgeGraph] = None,
 ) -> QueryDistribution:
     """ """
     default_queries = [
diff --git a/src/ragas/testset/synthesizers/base.py b/src/ragas/testset/synthesizers/base.py
--- a/src/ragas/testset/synthesizers/base.py
+++ b/src/ragas/testset/synthesizers/base.py
@@ -17,6 +17,18 @@
     from langchain_core.callbacks import Callbacks
 
     from ragas.dataset_schema import BaseSample
+    from ragas.llms.base import InstructorBaseRagasLLM
+
+
+def _default_llm_factory() -> t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"]:
+    """Create a default LLM instance with OpenAI gpt-4o-mini.
+
+    Returns InstructorBaseRagasLLM instance which satisfies BaseRagasLLM interface.
+    """
+    from openai import OpenAI
+
+    client = OpenAI()
+    return llm_factory("gpt-4o-mini", client=client)
 
 
 class QueryLength(str, Enum):
@@ -72,7 +84,9 @@ class BaseSynthesizer(ABC, t.Generic[Scenario], PromptMixin):
     """
 
     name: str = ""
-    llm: BaseRagasLLM = field(default_factory=llm_factory)
+    llm: t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"] = field(
+        default_factory=_default_llm_factory
+    )
 
     def __post_init__(self):
         if not self.name:
diff --git a/src/ragas/testset/transforms/base.py b/src/ragas/testset/transforms/base.py
--- a/src/ragas/testset/transforms/base.py
+++ b/src/ragas/testset/transforms/base.py
@@ -10,6 +10,9 @@
 from ragas.prompt import PromptMixin
 from ragas.testset.graph import KnowledgeGraph, Node, Relationship
 
+if t.TYPE_CHECKING:
+    from ragas.llms.base import InstructorBaseRagasLLM
+
 DEFAULT_TOKENIZER = tiktoken.get_encoding("o200k_base")
 
 logger = logging.getLogger(__name__)
@@ -19,6 +22,17 @@ def default_filter(node: Node) -> bool:
     return True
 
 
+def _default_llm_factory() -> t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"]:
+    """Create a default LLM instance with OpenAI gpt-4o-mini.
+
+    Returns InstructorBaseRagasLLM instance which satisfies BaseRagasLLM interface.
+    """
+    from openai import OpenAI
+
+    client = OpenAI()
+    return llm_factory("gpt-4o-mini", client=client)
+
+
 @dataclass
 class BaseGraphTransformation(ABC):
     """
@@ -207,7 +221,9 @@ async def apply_extract(node: Node):
 
 @dataclass
 class LLMBasedExtractor(Extractor, PromptMixin):
-    llm: BaseRagasLLM = field(default_factory=llm_factory)
+    llm: t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"] = field(
+        default_factory=_default_llm_factory
+    )
     merge_if_possible: bool = True
     max_token_limit: int = 32000
     tokenizer: Encoding = DEFAULT_TOKENIZER
@@ -426,4 +442,6 @@ async def apply_filter(node: Node):
 
 @dataclass
 class LLMBasedNodeFilter(NodeFilter, PromptMixin):
-    llm: BaseRagasLLM = field(default_factory=llm_factory)
+    llm: t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"] = field(
+        default_factory=_default_llm_factory
+    )
diff --git a/src/ragas/testset/transforms/default.py b/src/ragas/testset/transforms/default.py
--- a/src/ragas/testset/transforms/default.py
+++ b/src/ragas/testset/transforms/default.py
@@ -21,18 +21,21 @@
 
 if t.TYPE_CHECKING:
     from ragas.embeddings.base import BaseRagasEmbeddings
-    from ragas.llms.base import BaseRagasLLM
+    from ragas.llms.base import InstructorBaseRagasLLM
 
     from .engine import Transforms
 
 from langchain_core.documents import Document as LCDocument
 
+from ragas.embeddings.base import BaseRagasEmbeddings
+from ragas.llms.base import BaseRagasLLM
+
 
 def default_transforms(
     documents: t.List[LCDocument],
-    llm: BaseRagasLLM,
+    llm: t.Union[BaseRagasLLM, "InstructorBaseRagasLLM"],
     embedding_model: BaseRagasEmbeddings,
-) -> Transforms:
+) -> "Transforms":
     """
     Creates and returns a default set of transforms for processing a knowledge graph.
 
diff --git a/tests/e2e/metrics_migration/conftest.py b/tests/e2e/metrics_migration/conftest.py
--- a/tests/e2e/metrics_migration/conftest.py
+++ b/tests/e2e/metrics_migration/conftest.py
@@ -29,10 +29,10 @@ def legacy_llm():
 
 @pytest.fixture
 def modern_llm():
-    """Create a modern instructor LLM for v2 implementation.
+    """Create a modern LLM for v2 implementation.
 
-    Uses instructor_llm_factory with OpenAI client.
-    Skips if instructor LLM factory is not available or API key is missing.
+    Uses llm_factory with OpenAI client.
+    Skips if LLM factory is not available or API key is missing.
     """
     try:
         return create_modern_llm("openai", model="gpt-3.5-turbo")
diff --git a/tests/e2e/metrics_migration/test_answer_correctness_migration.py b/tests/e2e/metrics_migration/test_answer_correctness_migration.py
--- a/tests/e2e/metrics_migration/test_answer_correctness_migration.py
+++ b/tests/e2e/metrics_migration/test_answer_correctness_migration.py
@@ -65,14 +65,10 @@ def test_modern_llm(self):
         try:
             import openai
 
-            from ragas.llms.base import instructor_llm_factory
+            from ragas.llms import llm_factory
 
             client = openai.AsyncOpenAI()
-            return instructor_llm_factory(
-                "openai",
-                model="gpt-4o",
-                client=client,  # Using GPT-4o for better alignment
-            )
+            return llm_factory("gpt-4o", client=client)
         except ImportError as e:
             pytest.skip(f"Instructor LLM factory not available: {e}")
         except Exception as e:
diff --git a/tests/e2e/metrics_migration/test_answer_relevancy_migration.py b/tests/e2e/metrics_migration/test_answer_relevancy_migration.py
--- a/tests/e2e/metrics_migration/test_answer_relevancy_migration.py
+++ b/tests/e2e/metrics_migration/test_answer_relevancy_migration.py
@@ -60,12 +60,10 @@ def test_modern_llm(self):
         try:
             import openai
 
-            from ragas.llms.base import instructor_llm_factory
+            from ragas.llms import llm_factory
 
             client = openai.AsyncOpenAI()
-            return instructor_llm_factory(
-                "openai", model="gpt-3.5-turbo", client=client
-            )
+            return llm_factory("gpt-3.5-turbo", client=client)
         except ImportError as e:
             pytest.skip(f"Instructor LLM factory not available: {e}")
         except Exception as e:
diff --git a/tests/e2e/metrics_migration/test_aspect_critic_migration.py b/tests/e2e/metrics_migration/test_aspect_critic_migration.py
--- a/tests/e2e/metrics_migration/test_aspect_critic_migration.py
+++ b/tests/e2e/metrics_migration/test_aspect_critic_migration.py
@@ -65,12 +65,10 @@ def test_modern_llm(self):
         try:
             import openai
 
-            from ragas.llms.base import instructor_llm_factory
+            from ragas.llms import llm_factory
 
             client = openai.AsyncOpenAI()
-            return instructor_llm_factory(
-                "openai", model="gpt-3.5-turbo", client=client
-            )
+            return llm_factory("gpt-3.5-turbo", client=client)
         except ImportError as e:
             pytest.skip(f"Instructor LLM factory not available: {e}")
         except Exception as e:
diff --git a/tests/e2e/metrics_migration/test_context_entity_recall_migration.py b/tests/e2e/metrics_migration/test_context_entity_recall_migration.py
--- a/tests/e2e/metrics_migration/test_context_entity_recall_migration.py
+++ b/tests/e2e/metrics_migration/test_context_entity_recall_migration.py
@@ -72,18 +72,14 @@ def test_llm(self):
 
     @pytest.fixture
     def test_modern_llm(self):
-        """Create a modern instructor LLM for v2 implementation."""
+        """Create a modern LLM for v2 implementation."""
         try:
             import openai
 
-            from ragas.llms.base import instructor_llm_factory
+            from ragas.llms import llm_factory
 
             client = openai.AsyncOpenAI()
-            return instructor_llm_factory(
-                "openai",
-                model="gpt-4o",
-                client=client,  # Using GPT-4o for best alignment
-            )
+            return llm_factory("gpt-4o", client=client)
         except ImportError as e:
             pytest.skip(f"Instructor LLM factory not available: {e}")
         except Exception as e:
diff --git a/tests/unit/llms/test_instructor_factory.py b/tests/unit/llms/test_instructor_factory.py
--- a/tests/unit/llms/test_instructor_factory.py
+++ b/tests/unit/llms/test_instructor_factory.py
@@ -3,7 +3,7 @@
 import pytest
 from pydantic import BaseModel
 
-from ragas.llms.base import instructor_llm_factory as llm_factory
+from ragas.llms.base import llm_factory
 
 
 class LLMResponseModel(BaseModel):
@@ -66,15 +66,14 @@ def mock_async_client():
 
 
 def test_llm_factory_initialization(mock_sync_client, monkeypatch):
-    """Test llm_factory initialization with different providers."""
+    """Test llm_factory initialization."""
 
-    # Mock instructor to return our mock instructor
     def mock_from_openai(client):
         return MockInstructor(client)
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_sync_client)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_sync_client)
 
     assert llm.model == "gpt-4"  # type: ignore
     assert llm.client is not None  # type: ignore
@@ -84,26 +83,27 @@ def mock_from_openai(client):
 def test_llm_factory_async_detection(mock_async_client, monkeypatch):
     """Test that llm_factory correctly detects async clients."""
 
-    # Mock instructor to return our mock instructor
     def mock_from_openai(client):
         return MockInstructor(client)
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_async_client)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_async_client)
 
     assert llm.is_async  # type: ignore
 
 
 def test_llm_factory_with_model_args(mock_sync_client, monkeypatch):
-    """Test the llm_factory function with model arguments."""
+    """Test llm_factory with model arguments."""
 
     def mock_from_openai(client):
         return MockInstructor(client)
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_sync_client, temperature=0.7)
+    llm = llm_factory(
+        "gpt-4", provider="openai", client=mock_sync_client, temperature=0.7
+    )
 
     assert llm.model == "gpt-4"  # type: ignore
     assert llm.model_args.get("temperature") == 0.7  # type: ignore
@@ -113,8 +113,8 @@ def test_unsupported_provider():
     """Test that unsupported providers raise ValueError."""
     mock_client = Mock()
 
-    with pytest.raises(ValueError, match="Unsupported provider: unsupported"):
-        llm_factory("unsupported/test-model", client=mock_client)
+    with pytest.raises(ValueError, match="Unsupported provider"):
+        llm_factory("test-model", provider="unsupported", client=mock_client)
 
 
 def test_sync_llm_generate(mock_sync_client, monkeypatch):
@@ -125,7 +125,7 @@ def mock_from_openai(client):
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_sync_client)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_sync_client)
 
     result = llm.generate("Test prompt", LLMResponseModel)
 
@@ -142,7 +142,7 @@ def mock_from_openai(client):
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_async_client)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_async_client)
 
     result = await llm.agenerate("Test prompt", LLMResponseModel)
 
@@ -158,13 +158,11 @@ def mock_from_openai(client):
 
     monkeypatch.setattr("instructor.from_openai", mock_from_openai)
 
-    llm = llm_factory("openai/gpt-4", client=mock_sync_client)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_sync_client)
 
-    # Test that agenerate raises TypeError with sync client
     with pytest.raises(
         TypeError, match="Cannot use agenerate\\(\\) with a synchronous client"
     ):
-        # Use asyncio.run to handle the coroutine
         import asyncio
 
         asyncio.run(llm.agenerate("Test prompt", LLMResponseModel))
@@ -175,23 +173,20 @@ def test_provider_support():
     supported_providers = {
         "openai": "from_openai",
         "anthropic": "from_anthropic",
-        "cohere": "from_cohere",
-        "google": "from_genai",
+        "google": "from_gemini",
         "litellm": "from_litellm",
     }
 
     for provider, func_name in supported_providers.items():
         mock_client = Mock()
 
-        # Mock the appropriate instructor function
         import instructor
 
         mock_instructor_func = Mock(return_value=MockInstructor(mock_client))
         setattr(instructor, func_name, mock_instructor_func)
 
-        # This should not raise an error
         try:
-            llm = llm_factory(f"{provider}/test-model", client=mock_client)
+            llm = llm_factory("test-model", provider=provider, client=mock_client)
             assert llm.model == "test-model"  # type: ignore
         except Exception as e:
             pytest.fail(f"Provider {provider} should be supported but got error: {e}")
@@ -207,34 +202,20 @@ def mock_from_openai(client):
 
     model_args = {"temperature": 0.7, "max_tokens": 1000, "top_p": 0.9}
 
-    llm = llm_factory("openai/gpt-4", client=mock_sync_client, **model_args)
+    llm = llm_factory("gpt-4", provider="openai", client=mock_sync_client, **model_args)
 
     assert llm.model_args == model_args  # type: ignore
 
 
-def test_llm_factory_separate_parameters(mock_sync_client, monkeypatch):
-    """Test llm_factory with separate provider and model parameters."""
-
-    def mock_from_openai(client):
-        return MockInstructor(client)
-
-    monkeypatch.setattr("instructor.from_openai", mock_from_openai)
-
-    llm = llm_factory("openai", "gpt-4", client=mock_sync_client)
-
-    assert llm.model == "gpt-4"  # type: ignore
-    assert llm.client is not None  # type: ignore
+def test_llm_factory_missing_client():
+    """Test that missing client raises ValueError."""
+    with pytest.raises(ValueError, match="requires a client instance"):
+        llm_factory("gpt-4", provider="openai")
 
 
 def test_llm_factory_missing_model():
     """Test that missing model raises ValueError."""
     mock_client = Mock()
 
-    with pytest.raises(ValueError, match="Model name is required"):
-        llm_factory("openai", client=mock_client)
-
-
-def test_llm_factory_missing_client():
-    """Test that missing client raises ValueError."""
-    with pytest.raises(ValueError, match="Openai provider requires a client instance"):
-        llm_factory("openai", "gpt-4")
+    with pytest.raises(ValueError, match="model parameter is required"):
+        llm_factory("", provider="openai", client=mock_client)
diff --git a/tests/utils/llm_setup.py b/tests/utils/llm_setup.py
--- a/tests/utils/llm_setup.py
+++ b/tests/utils/llm_setup.py
@@ -41,22 +41,27 @@ def check_api_key(provider: str = "openai") -> bool:
 
 
 def create_legacy_llm(model: str = "gpt-3.5-turbo", **kwargs):
-    """Create a legacy LLM instance for old-style metrics.
+    """Create an LLM instance using the unified llm_factory.
 
     Args:
         model: The model name to use
-        **kwargs: Additional arguments to pass to llm_factory
+        **kwargs: Additional arguments to pass to llm_factory (must include client)
 
     Returns:
-        Legacy LLM instance
+        InstructorBaseRagasLLM instance
 
     Raises:
         ImportError: If llm_factory is not available
-        Exception: If LLM creation fails (e.g., missing API key)
+        Exception: If LLM creation fails (e.g., missing API key or client)
     """
     try:
         from ragas.llms.base import llm_factory
 
+        if "client" not in kwargs:
+            import openai
+
+            kwargs["client"] = openai.OpenAI()
+
         return llm_factory(model, **kwargs)
     except ImportError as e:
         raise ImportError(f"LLM factory not available: {e}")
@@ -70,25 +75,24 @@ def create_modern_llm(
     client: Optional[any] = None,
     **kwargs,
 ):
-    """Create a modern instructor LLM instance for v2 metrics.
+    """Create an LLM instance using the unified llm_factory.
 
     Args:
-        provider: The LLM provider (e.g., "openai", "anthropic")
+        provider: The LLM provider (default: "openai")
         model: The model name to use
-        client: Optional async client instance. If None, will create one.
-        **kwargs: Additional arguments to pass to instructor_llm_factory
+        client: Optional client instance. If None, will create AsyncOpenAI().
+        **kwargs: Additional arguments to pass to llm_factory
 
     Returns:
-        Modern instructor LLM instance
+        InstructorBaseRagasLLM instance
 
     Raises:
         ImportError: If required libraries are not available
         Exception: If LLM creation fails
     """
     try:
-        from ragas.llms.base import instructor_llm_factory
+        from ragas.llms.base import llm_factory
 
-        # Create client if not provided
         if client is None:
             if provider == "openai":
                 import openai
@@ -97,11 +101,11 @@ def create_modern_llm(
             else:
                 raise ValueError(f"Auto-client creation not supported for {provider}")
 
-        return instructor_llm_factory(provider, model=model, client=client, **kwargs)
+        return llm_factory(model=model, provider=provider, client=client, **kwargs)
     except ImportError as e:
-        raise ImportError(f"Instructor LLM factory not available: {e}")
+        raise ImportError(f"LLM factory not available: {e}")
     except Exception as e:
-        raise Exception(f"Could not create modern LLM (API key may be missing): {e}")
+        raise Exception(f"Could not create LLM (API key may be missing): {e}")
 
 
 def create_legacy_embeddings(model: str = "text-embedding-ada-002", **kwargs):
EOF_114329324912

# Set environment variables for test execution (redundant but explicit)
export RAGAS_DO_NOT_TRACK=true
export __RAGAS_DEBUG_TRACKING=true

# Execute the target test files
# Only running the actual test files (excluding conftest.py which is a fixture file)
# Running e2e and unit tests together in a single command for efficiency
pytest tests/e2e/metrics_migration/test_answer_correctness_migration.py \
       tests/e2e/metrics_migration/test_answer_relevancy_migration.py \
       tests/e2e/metrics_migration/test_aspect_critic_migration.py \
       tests/e2e/metrics_migration/test_context_entity_recall_migration.py \
       tests/unit/llms/test_instructor_factory.py \
       -v --tb=short
rc=$?

# Echo exit code for test result verification
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
git checkout f0bff88cf957a9171f267c6d29e036079e4a4230 "docs/howtos/customizations/testgenerator/_persona_generator.md" "docs/howtos/customizations/testgenerator/_testgen-custom-single-hop.md" "docs/howtos/customizations/testgenerator/_testgen-customisation.md" "src/ragas/testset/synthesizers/__init__.py" "src/ragas/testset/synthesizers/base.py" "src/ragas/testset/transforms/base.py" "src/ragas/testset/transforms/default.py" "tests/e2e/metrics_migration/conftest.py" "tests/e2e/metrics_migration/test_answer_correctness_migration.py" "tests/e2e/metrics_migration/test_answer_relevancy_migration.py" "tests/e2e/metrics_migration/test_aspect_critic_migration.py" "tests/e2e/metrics_migration/test_context_entity_recall_migration.py" "tests/unit/llms/test_instructor_factory.py" "tests/utils/llm_setup.py"