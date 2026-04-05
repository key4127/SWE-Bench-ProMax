#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Ensure environment variables are set
export TOKENIZERS_PARALLELISM=false

# Checkout the target test files to ensure clean state (using original paths that exist in the repo)
git checkout 65395572fa9bf5a31e8edfb114c505ec22d0b607 \
    "tests/conftest.py" \
    "tests/evaluation/test_nanobeir_evaluator.py" \
    "tests/samplers/test_group_by_label_batch_sampler.py" \
    "tests/samplers/test_no_duplicates_batch_sampler.py" \
    "tests/samplers/test_round_robin_batch_sampler.py" \
    "tests/test_cross_encoder.py" \
    "tests/test_image_embeddings.py" \
    "tests/test_model_card.py" \
    "tests/test_model_card_data.py" \
    "tests/test_train_stsb.py" \
    "tests/test_trainer.py"

# Apply test patch (this may reorganize files into subdirectories)
git apply -v - <<'EOF_114329324912'
diff --git a/tests/conftest.py b/tests/conftest.py
--- a/tests/conftest.py
+++ b/tests/conftest.py
@@ -4,7 +4,7 @@
 
 import pytest
 
-from sentence_transformers import CrossEncoder, SentenceTransformer
+from sentence_transformers import SentenceTransformer
 from sentence_transformers.models import Pooling, Transformer
 from sentence_transformers.util import is_datasets_available
 from tests.utils import SafeTemporaryDirectory
@@ -38,11 +38,6 @@ def paraphrase_distilroberta_base_v1_model() -> SentenceTransformer:
     return SentenceTransformer("paraphrase-distilroberta-base-v1")
 
 
-@pytest.fixture()
-def distilroberta_base_ce_model() -> CrossEncoder:
-    return CrossEncoder("distilroberta-base", num_labels=1)
-
-
 @pytest.fixture()
 def clip_vit_b_32_model() -> SentenceTransformer:
     return SentenceTransformer("clip-ViT-B-32")
@@ -58,7 +53,7 @@ def distilbert_base_uncased_model() -> SentenceTransformer:
 
 @pytest.fixture(scope="session")
 def stsb_dataset_dict() -> DatasetDict:
-    return load_dataset("mteb/stsbenchmark-sts")
+    return load_dataset("sentence-transformers/stsb")
 
 
 @pytest.fixture()
diff --git a/tests/cross_encoder/conftest.py b/tests/cross_encoder/conftest.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/conftest.py
@@ -0,0 +1,20 @@
+from __future__ import annotations
+
+import pytest
+
+from sentence_transformers import CrossEncoder
+
+
+@pytest.fixture()
+def distilroberta_base_ce_model() -> CrossEncoder:
+    return CrossEncoder("distilroberta-base", num_labels=1)
+
+
+@pytest.fixture()
+def reranker_bert_tiny_model() -> CrossEncoder:
+    return CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce")
+
+
+@pytest.fixture(scope="session")
+def reranker_bert_tiny_model_reused() -> CrossEncoder:
+    return CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce")
diff --git a/tests/cross_encoder/test_cross_encoder.py b/tests/cross_encoder/test_cross_encoder.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_cross_encoder.py
@@ -0,0 +1,591 @@
+from __future__ import annotations
+
+import json
+import logging
+import re
+from pathlib import Path
+
+import numpy as np
+import pytest
+import torch
+from huggingface_hub import CommitInfo, HfApi, RepoUrl
+from pytest import FixtureRequest
+
+from sentence_transformers import CrossEncoder
+from sentence_transformers.cross_encoder.util import (
+    cross_encoder_init_args_decorator,
+    cross_encoder_predict_rank_args_decorator,
+)
+from sentence_transformers.util import fullname
+from tests.utils import SafeTemporaryDirectory
+
+
+def test_classifier_dropout_is_set() -> None:
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce", classifier_dropout=0.1234)
+    assert model.config.classifier_dropout == 0.1234
+    assert model.model.config.classifier_dropout == 0.1234
+
+
+def test_classifier_dropout_default_value() -> None:
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce")
+    assert model.config.classifier_dropout is None
+    assert model.model.config.classifier_dropout is None
+
+
+def test_load_with_revision() -> None:
+    model_name = "sentence-transformers-testing/stsb-bert-tiny-safetensors"
+
+    main_model = CrossEncoder(model_name, num_labels=1, revision="main")
+    latest_model = CrossEncoder(
+        model_name,
+        num_labels=1,
+        revision="f3cb857cba53019a20df283396bcca179cf051a4",
+    )
+    older_model = CrossEncoder(
+        model_name,
+        num_labels=1,
+        revision="ba33022fdf0b0fc2643263f0726f44d0a07d0e24",
+    )
+
+    # Set the classifier.bias and classifier.weight equal among models. This
+    # is needed because the AutoModelForSequenceClassification randomly initializes
+    # the classifier.bias and classifier.weight for each (model) initialization.
+    # The test is only possible if all models have the same classifier.bias
+    # and classifier.weight parameters.
+    latest_model.model.classifier.bias = main_model.model.classifier.bias
+    latest_model.model.classifier.weight = main_model.model.classifier.weight
+    older_model.model.classifier.bias = main_model.model.classifier.bias
+    older_model.model.classifier.weight = main_model.model.classifier.weight
+
+    test_sentences = [["Hello there!", "Hello, World!"]]
+    main_prob = main_model.predict(test_sentences, convert_to_tensor=True)
+    assert torch.equal(main_prob, latest_model.predict(test_sentences, convert_to_tensor=True))
+    assert not torch.equal(main_prob, older_model.predict(test_sentences, convert_to_tensor=True))
+
+
+@pytest.mark.parametrize(
+    argnames="return_documents",
+    argvalues=[True, False],
+    ids=["return-docs", "no-return-docs"],
+)
+def test_rank(return_documents: bool, request: FixtureRequest) -> None:
+    model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
+    # We want to compute the similarity between the query sentence
+    query = "A man is eating pasta."
+
+    # With all sentences in the corpus
+    corpus = [
+        "A man is eating food.",
+        "A man is eating a piece of bread.",
+        "The girl is carrying a baby.",
+        "A man is riding a horse.",
+        "A woman is playing violin.",
+        "Two men pushed carts through the woods.",
+        "A man is riding a white horse on an enclosed ground.",
+        "A monkey is playing drums.",
+        "A cheetah is running behind its prey.",
+    ]
+    expected_ranking = [0, 1, 3, 6, 2, 5, 7, 4, 8]
+
+    # 1. We rank all sentences in the corpus for the query
+    ranks = model.rank(query=query, documents=corpus, return_documents=return_documents)
+    if request.node.callspec.id == "return-docs":
+        assert {*corpus} == {rank.get("text") for rank in ranks}
+
+    pred_ranking = [rank["corpus_id"] for rank in ranks]
+    assert pred_ranking == expected_ranking
+
+
+def test_rank_multiple_labels():
+    model = CrossEncoder("cross-encoder/nli-MiniLM2-L6-H768")
+    with pytest.raises(
+        ValueError,
+        match=re.escape(
+            "CrossEncoder.rank() only works for models with num_labels=1. "
+            "Consider using CrossEncoder.predict() with input pairs instead."
+        ),
+    ):
+        model.rank(
+            query="A man is eating pasta.",
+            documents=[
+                "A man is eating food.",
+                "A man is eating a piece of bread.",
+                "The girl is carrying a baby.",
+            ],
+        )
+
+
+def test_predict_softmax():
+    model = CrossEncoder("cross-encoder/nli-MiniLM2-L6-H768")
+    query = "A man is eating pasta."
+
+    # With all sentences in the corpus
+    corpus = [
+        "A man is eating food.",
+        "A man is eating a piece of bread.",
+        "The girl is carrying a baby.",
+        "A man is riding a horse.",
+    ]
+    scores = model.predict([(query, doc) for doc in corpus], apply_softmax=True, convert_to_tensor=True)
+    assert torch.isclose(scores.sum(1), torch.ones(len(corpus), device=scores.device)).all()
+    scores = model.predict([(query, doc) for doc in corpus], apply_softmax=False, convert_to_tensor=True)
+    assert not torch.isclose(scores.sum(1), torch.ones(len(corpus), device=scores.device)).all()
+
+
+@pytest.mark.parametrize(
+    "model_name", ["cross-encoder-testing/reranker-bert-tiny-gooaq-bce", "cross-encoder/nli-MiniLM2-L6-H768"]
+)
+def test_predict_single_input(model_name: str):
+    model = CrossEncoder(model_name)
+    nested_pair_score = model.predict([["A man is eating pasta.", "A man is eating food."]])
+    assert isinstance(nested_pair_score, np.ndarray)
+    if model.num_labels == 1:
+        assert nested_pair_score.shape == (1,)
+    else:
+        assert nested_pair_score.shape == (1, model.num_labels)
+
+    pair_score = model.predict(["A man is eating pasta.", "A man is eating food."])
+    if model.num_labels == 1:
+        assert isinstance(pair_score, np.float32)
+    else:
+        assert isinstance(pair_score, np.ndarray)
+        assert pair_score.shape == (model.num_labels,)
+
+
+@pytest.mark.parametrize("convert_to_tensor", [True, False])
+@pytest.mark.parametrize("convert_to_numpy", [True, False])
+def test_predict_output_types(
+    convert_to_tensor: bool,
+    convert_to_numpy: bool,
+) -> None:
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce")
+    embeddings = model.predict(
+        [["One sentence", "Another sentence"]],
+        convert_to_tensor=convert_to_tensor,
+        convert_to_numpy=convert_to_numpy,
+    )
+    if convert_to_tensor:
+        assert embeddings[0].dtype == torch.float32
+        assert isinstance(embeddings, torch.Tensor)
+    elif convert_to_numpy:
+        assert embeddings[0].dtype == np.float32
+        assert isinstance(embeddings, np.ndarray)
+    else:
+        assert embeddings[0].dtype == torch.float32
+        assert isinstance(embeddings, list)
+
+
+@pytest.mark.parametrize("safe_serialization", [True, False, None])
+def test_safe_serialization(safe_serialization: bool) -> None:
+    with SafeTemporaryDirectory() as cache_folder:
+        model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce")
+        if safe_serialization:
+            model.save_pretrained(cache_folder, safe_serialization=safe_serialization)
+            model_files = list(Path(cache_folder).glob("**/model.safetensors"))
+            assert 1 == len(model_files)
+        elif safe_serialization is None:
+            model.save_pretrained(cache_folder)
+            model_files = list(Path(cache_folder).glob("**/model.safetensors"))
+            assert 1 == len(model_files)
+        else:
+            model.save_pretrained(cache_folder, safe_serialization=safe_serialization)
+            model_files = list(Path(cache_folder).glob("**/pytorch_model.bin"))
+            assert 1 == len(model_files)
+
+
+def test_bfloat16() -> None:
+    model = CrossEncoder(
+        "cross-encoder-testing/reranker-bert-tiny-gooaq-bce", automodel_args={"torch_dtype": torch.bfloat16}
+    )
+    score = model.predict([["Hello there!", "Hello, World!"]])
+    assert isinstance(score, np.ndarray)
+
+    ranking = model.rank("Hello there!", ["Hello, World!", "Heya!"])
+    assert isinstance(ranking, list)
+
+
+@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
+@pytest.mark.parametrize("device", ["cpu", "cuda"])
+def test_device_assignment(device):
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce", device=device)
+    assert model.device.type == device
+
+
+@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
+def test_device_switching():
+    # test assignment using .to
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce", device="cpu")
+    assert model.device.type == "cpu"
+    assert model.model.device.type == "cpu"
+
+    model.to("cuda")
+    assert model.device.type == "cuda"
+    assert model.model.device.type == "cuda"
+
+    del model
+    torch.cuda.empty_cache()
+
+
+@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
+def test_target_device_backwards_compat():
+    model = CrossEncoder("cross-encoder-testing/reranker-bert-tiny-gooaq-bce", device="cpu")
+    assert model.device.type == "cpu"
+
+    assert model._target_device.type == "cpu"
+    model._target_device = "cuda"
+    assert model.device.type == "cuda"
+
+
+def test_num_labels_fresh_model():
+    model = CrossEncoder("prajjwal1/bert-tiny")
+    assert model.num_labels == 1
+
+
+def test_push_to_hub(
+    reranker_bert_tiny_model: CrossEncoder, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
+) -> None:
+    model = reranker_bert_tiny_model
+
+    def mock_create_repo(self, repo_id, **kwargs):
+        return RepoUrl(f"https://huggingface.co/{repo_id}")
+
+    mock_upload_folder_kwargs = {}
+
+    def mock_upload_folder(self, **kwargs):
+        nonlocal mock_upload_folder_kwargs
+        mock_upload_folder_kwargs = kwargs
+        if kwargs.get("revision") is None:
+            revision = "123456"
+        else:
+            revision = "678901"
+        return CommitInfo(
+            commit_url=f"https://huggingface.co/{kwargs.get('repo_id')}/commit/{revision}",
+            commit_message="commit_message",
+            commit_description="commit_description",
+            oid="oid",
+            pr_url=f"https://huggingface.co/{kwargs.get('repo_id')}/discussions/123",
+        )
+
+    def mock_create_branch(self, repo_id, branch, revision=None, **kwargs):
+        return None
+
+    monkeypatch.setattr(HfApi, "create_repo", mock_create_repo)
+    monkeypatch.setattr(HfApi, "upload_folder", mock_upload_folder)
+    monkeypatch.setattr(HfApi, "create_branch", mock_create_branch)
+
+    url = model.push_to_hub("cross-encoder-testing/stsb-distilroberta-base")
+    assert mock_upload_folder_kwargs["repo_id"] == "cross-encoder-testing/stsb-distilroberta-base"
+    assert url == "https://huggingface.co/cross-encoder-testing/stsb-distilroberta-base/commit/123456"
+    mock_upload_folder_kwargs.clear()
+
+    url = model.push_to_hub("cross-encoder-testing/stsb-distilroberta-base", revision="revision_test")
+    assert mock_upload_folder_kwargs["repo_id"] == "cross-encoder-testing/stsb-distilroberta-base"
+    assert mock_upload_folder_kwargs["revision"] == "revision_test"
+    assert url == "https://huggingface.co/cross-encoder-testing/stsb-distilroberta-base/commit/678901"
+    mock_upload_folder_kwargs.clear()
+
+    url = model.push_to_hub("cross-encoder-testing/stsb-distilroberta-base", create_pr=True)
+    assert mock_upload_folder_kwargs["repo_id"] == "cross-encoder-testing/stsb-distilroberta-base"
+    assert url == "https://huggingface.co/cross-encoder-testing/stsb-distilroberta-base/discussions/123"
+    mock_upload_folder_kwargs.clear()
+
+    url = model.push_to_hub("cross-encoder-testing/stsb-distilroberta-base", tags="test-push-to-hub-tag-1")
+    assert mock_upload_folder_kwargs["repo_id"] == "cross-encoder-testing/stsb-distilroberta-base"
+    assert url == "https://huggingface.co/cross-encoder-testing/stsb-distilroberta-base/commit/123456"
+    mock_upload_folder_kwargs.clear()
+    assert "test-push-to-hub-tag-1" in model.model_card_data.tags
+
+    url = model.push_to_hub(
+        "cross-encoder-testing/stsb-distilroberta-base", tags=["test-push-to-hub-tag-2", "test-push-to-hub-tag-3"]
+    )
+    assert mock_upload_folder_kwargs["repo_id"] == "cross-encoder-testing/stsb-distilroberta-base"
+    assert url == "https://huggingface.co/cross-encoder-testing/stsb-distilroberta-base/commit/123456"
+    mock_upload_folder_kwargs.clear()
+    assert "test-push-to-hub-tag-2" in model.model_card_data.tags
+    assert "test-push-to-hub-tag-3" in model.model_card_data.tags
+
+
+@pytest.mark.parametrize(
+    ["in_args", "in_kwargs", "out_args", "out_kwargs"],
+    [
+        [
+            tuple(),
+            {"model_name": "cross-encoder-testing/reranker-bert-tiny-gooaq-bce", "classifier_dropout": 0.1234},
+            tuple(),
+            {
+                "model_name_or_path": "cross-encoder-testing/reranker-bert-tiny-gooaq-bce",
+                "config_kwargs": {"classifier_dropout": 0.1234},
+            },
+        ],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {"classifier_dropout": 0.1234},
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {"config_kwargs": {"classifier_dropout": 0.1234}},
+        ],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "automodel_args": {"foo": "bar"},
+                "tokenizer_args": {"foo": "baz"},
+            },
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "model_kwargs": {"foo": "bar"},
+                "tokenizer_kwargs": {"foo": "baz"},
+            },
+        ],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "config_args": {"foo": "bar"},
+                "cache_dir": "local_tmp",
+            },
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "config_kwargs": {"foo": "bar"},
+                "cache_folder": "local_tmp",
+            },
+        ],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "automodel_args": {"foo": "bar"},
+                "model_kwargs": {"faa": "baz"},
+            },
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "model_kwargs": {"faa": "baz"},
+            },
+        ],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "default_activation_function": "torch.nn.Sigmoid",
+            },
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {
+                "activation_fn": "torch.nn.Sigmoid",
+            },
+        ],
+        [tuple(), {}, tuple(), {}],
+        [
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {},
+            ("cross-encoder-testing/reranker-bert-tiny-gooaq-bce",),
+            {},
+        ],
+        [
+            tuple(),
+            {
+                "model_name": "cross-encoder-testing/reranker-bert-tiny-gooaq-bce",
+                "automodel_args": {"foo": "bar"},
+                "tokenizer_args": {"foo": "baz"},
+                "config_args": {"foo": "bar"},
+                "cache_dir": "local_tmp",
+            },
+            tuple(),
+            {
+                "model_name_or_path": "cross-encoder-testing/reranker-bert-tiny-gooaq-bce",
+                "model_kwargs": {"foo": "bar"},
+                "tokenizer_kwargs": {"foo": "baz"},
+                "config_kwargs": {"foo": "bar"},
+                "cache_folder": "local_tmp",
+            },
+        ],
+    ],
+)
+def test_init_args_decorator(
+    monkeypatch: pytest.MonkeyPatch, in_args: tuple, in_kwargs: dict, out_args: tuple, out_kwargs: dict
+):
+    decorated_out_args = None
+    decorated_out_kwargs = None
+
+    @cross_encoder_init_args_decorator
+    def mock_init(self, *args, **kwargs):
+        nonlocal decorated_out_args
+        nonlocal decorated_out_kwargs
+        decorated_out_args = args
+        decorated_out_kwargs = kwargs
+        return None
+
+    monkeypatch.setattr(CrossEncoder, "__init__", mock_init)
+
+    CrossEncoder(*in_args, **in_kwargs)
+    assert decorated_out_args == out_args
+    assert decorated_out_kwargs == out_kwargs
+
+
+@pytest.mark.parametrize(
+    ["in_kwargs", "out_kwargs"],
+    [
+        [
+            {
+                "num_workers": 2,
+            },
+            {},
+        ],
+        [
+            {  # You have to pass instances normally, but this is easier for testing
+                "activation_fct": torch.nn.Sigmoid,
+            },
+            {
+                "activation_fn": torch.nn.Sigmoid,
+            },
+        ],
+        [
+            {
+                "activation_fct": torch.nn.Identity,
+                "activation_fn": torch.nn.Sigmoid,
+            },
+            {
+                "activation_fn": torch.nn.Sigmoid,
+            },
+        ],
+    ],
+)
+def test_predict_rank_args_decorator(
+    reranker_bert_tiny_model: CrossEncoder, monkeypatch: pytest.MonkeyPatch, caplog, in_kwargs: dict, out_kwargs: dict
+):
+    model = reranker_bert_tiny_model
+    decorated_out_kwargs = None
+
+    @cross_encoder_predict_rank_args_decorator
+    def mock_predict(self, *args, **kwargs):
+        nonlocal decorated_out_kwargs
+        decorated_out_kwargs = kwargs
+        return None
+
+    monkeypatch.setattr(CrossEncoder, "predict", mock_predict)
+
+    with caplog.at_level(logging.WARNING):
+        model.predict([["Hello there!", "Hello, World!"]], **in_kwargs)
+        assert caplog.text != ""
+    assert decorated_out_kwargs == out_kwargs
+
+
+def test_logger_warning(caplog):
+    model_name = "cross-encoder-testing/reranker-bert-tiny-gooaq-bce"
+    with caplog.at_level(logging.WARNING):
+        CrossEncoder(model_name, classifier_dropout=0.1234)
+        assert "`classifier_dropout` argument is deprecated" in caplog.text
+
+    with caplog.at_level(logging.WARNING):
+        CrossEncoder(model_name, automodel_args={"torch_dtype": torch.float32})
+        assert "`automodel_args` argument was renamed and is now deprecated" in caplog.text
+
+    with caplog.at_level(logging.WARNING):
+        CrossEncoder(model_name, tokenizer_args={"model_max_length": 8192})
+        assert "`tokenizer_args` argument was renamed and is now deprecated" in caplog.text
+
+    with caplog.at_level(logging.WARNING):
+        CrossEncoder(model_name, config_args={"classifier_dropout": 0.2})
+        assert "`config_args` argument was renamed and is now deprecated" in caplog.text
+
+
+@pytest.mark.parametrize(
+    ["num_labels", "activation_fn", "saved_activation_fn"],
+    [
+        [
+            1,
+            torch.nn.Sigmoid(),
+            "torch.nn.modules.activation.Sigmoid",
+        ],
+        [
+            1,
+            torch.nn.Identity(),
+            "torch.nn.modules.linear.Identity",
+        ],
+        [
+            1,
+            torch.nn.Tanh(),
+            "torch.nn.modules.activation.Tanh",
+        ],
+        [
+            1,
+            torch.nn.Softmax(),
+            "torch.nn.modules.activation.Softmax",
+        ],
+        [
+            1,
+            None,
+            "torch.nn.modules.activation.Sigmoid",
+        ],
+        [
+            3,
+            None,
+            "torch.nn.modules.linear.Identity",
+        ],
+    ],
+)
+def test_load_activation_fn_from_kwargs(num_labels: int, activation_fn: str, saved_activation_fn: str, tmp_path: Path):
+    model = CrossEncoder("prajjwal1/bert-tiny", num_labels=num_labels, activation_fn=activation_fn)
+    assert fullname(model.activation_fn) == saved_activation_fn
+
+    model.save_pretrained(tmp_path)
+    with open(tmp_path / "config.json") as f:
+        config = json.load(f)
+    assert config["sentence_transformers"]["activation_fn"] == saved_activation_fn
+    assert "sbert_ce_default_activation_function" not in config
+
+    loaded_model = CrossEncoder(tmp_path)
+    assert fullname(loaded_model.activation_fn) == saved_activation_fn
+
+    # Setting the activation function via a prediction updates the instance, but not the config
+    loaded_model.predict([["Hello there!", "Hello, World!"]], activation_fn=torch.nn.Identity())
+    assert fullname(loaded_model.activation_fn) == "torch.nn.modules.linear.Identity"
+    assert loaded_model.config.sentence_transformers["activation_fn"] == saved_activation_fn
+
+
+@pytest.mark.parametrize(
+    "tanh_model_name",
+    [
+        "cross-encoder-testing/reranker-bert-tiny-gooaq-bce-tanh-v3",
+        "cross-encoder-testing/reranker-bert-tiny-gooaq-bce-tanh-v4",
+    ],
+)
+def test_load_activation_fn_from_config(tanh_model_name: str, tmp_path):
+    saved_activation_fn = "torch.nn.modules.activation.Tanh"
+
+    model = CrossEncoder(tanh_model_name)
+    assert fullname(model.activation_fn) == saved_activation_fn
+
+    model.save_pretrained(tmp_path)
+    with open(tmp_path / "config.json") as f:
+        config = json.load(f)
+    assert config["sentence_transformers"]["activation_fn"] == saved_activation_fn
+    assert "sbert_ce_default_activation_function" not in config
+
+    loaded_model = CrossEncoder(tmp_path)
+    assert fullname(loaded_model.activation_fn) == saved_activation_fn
+
+
+def test_load_activation_fn_from_config_custom(reranker_bert_tiny_model: CrossEncoder, tmp_path: Path, caplog):
+    model = reranker_bert_tiny_model
+
+    model.save_pretrained(tmp_path)
+    with open(tmp_path / "config.json") as f:
+        config = json.load(f)
+    config["sentence_transformers"]["activation_fn"] = "sentence_transformers.custom.activations.CustomActivation"
+    with open(tmp_path / "config.json", "w") as f:
+        json.dump(config, f)
+
+    with caplog.at_level(logging.WARNING):
+        CrossEncoder(tmp_path)
+        assert (
+            "Activation function path 'sentence_transformers.custom.activations.CustomActivation' is not trusted, using default activation function instead."
+            in caplog.text
+        )
+
+    # If we use trust_remote_code, it'll try to load the custom activation function, which doesn't exist
+    with pytest.raises(ImportError):
+        model = CrossEncoder(tmp_path, trust_remote_code=True)
+
+
+def test_default_activation_fn(reranker_bert_tiny_model: CrossEncoder):
+    model = reranker_bert_tiny_model
+    assert fullname(model.activation_fn) == "torch.nn.modules.activation.Sigmoid"
+    with pytest.warns(
+        DeprecationWarning, match="The `default_activation_function` property was renamed and is now deprecated.*"
+    ):
+        assert fullname(model.default_activation_function) == "torch.nn.modules.activation.Sigmoid"
diff --git a/tests/cross_encoder/test_deprecated_imports.py b/tests/cross_encoder/test_deprecated_imports.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_deprecated_imports.py
@@ -0,0 +1,81 @@
+from __future__ import annotations
+
+import importlib
+
+import pytest
+
+from sentence_transformers.cross_encoder.evaluation import (
+    CEBinaryAccuracyEvaluator,
+    CEBinaryClassificationEvaluator,
+    CECorrelationEvaluator,
+    CEF1Evaluator,
+    CERerankingEvaluator,
+    CESoftmaxAccuracyEvaluator,
+)
+
+
+@pytest.mark.parametrize(
+    ("module_names", "module_attributes"),
+    [
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CEBinaryAccuracyEvaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CEBinaryAccuracyEvaluator,
+            ],
+        ),
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CEBinaryClassificationEvaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CEBinaryClassificationEvaluator,
+            ],
+        ),
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CEF1Evaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CEF1Evaluator,
+            ],
+        ),
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CESoftmaxAccuracyEvaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CESoftmaxAccuracyEvaluator,
+            ],
+        ),
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CERerankingEvaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CERerankingEvaluator,
+            ],
+        ),
+        (
+            [
+                "sentence_transformers.cross_encoder.evaluation.CECorrelationEvaluator",
+                "sentence_transformers.cross_encoder.evaluation",
+            ],
+            [
+                CECorrelationEvaluator,
+            ],
+        ),
+    ],
+)
+def test_import(module_names: list[str], module_attributes: list[object]) -> None:
+    for module_name in module_names:
+        module = importlib.import_module(module_name)
+        for module_attribute in module_attributes:
+            obj = getattr(module, module_attribute.__name__, None)
+            assert obj is module_attribute
diff --git a/tests/cross_encoder/test_model_card.py b/tests/cross_encoder/test_model_card.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_model_card.py
@@ -0,0 +1,160 @@
+from __future__ import annotations
+
+import pytest
+
+from sentence_transformers.cross_encoder import CrossEncoder, CrossEncoderTrainer
+from sentence_transformers.cross_encoder.model_card import generate_model_card
+from sentence_transformers.util import is_datasets_available, is_training_available
+
+if is_datasets_available():
+    from datasets import Dataset, DatasetDict
+
+if not is_training_available():
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
+
+
+@pytest.fixture(scope="session")
+def dummy_dataset():
+    """
+    Dummy dataset for testing purposes. The dataset looks as follows:
+    {
+        "anchor": ["anchor 1", "anchor 2", ..., "anchor 10"],
+        "positive": ["positive 1", "positive 2", ..., "positive 10"],
+        "negative": ["negative 1", "negative 2", ..., "negative 10"],
+    }
+    """
+    return Dataset.from_dict(
+        {
+            "anchor": [f"anchor {i}" for i in range(1, 11)],
+            "positive": [f"positive {i}" for i in range(1, 11)],
+            "negative": [f"negative {i}" for i in range(1, 11)],
+        }
+    )
+
+
+@pytest.mark.parametrize(
+    ("num_datasets", "num_labels", "expected_substrings"),
+    [
+        # 0 actually refers to just a single dataset
+        (
+            0,
+            1,
+            [
+                "- sentence-transformers",
+                "- cross-encoder",
+                "pipeline_tag: text-ranking",
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny)",
+                "[sentence-transformers](https://www.SBERT.net) library",
+                "It computes scores for pairs of texts, which can be used for text reranking and semantic search.",
+                "**Maximum Sequence Length:** 512 tokens",
+                "- **Number of Output Labels:** 1 label",
+                "<!-- - **Training Dataset:** Unknown -->",
+                "<!-- - **Language:** Unknown -->",
+                "<!-- - **License:** Unknown -->",
+                'model = CrossEncoder("cross_encoder_model_id")',
+                "['anchor 1', 'positive 1'],",
+                "# (5,)",
+                "ranks = model.rank(",
+                "#### Unnamed Dataset",
+                "| details | <ul><li>min: 8 characters</li><li>mean: 8.1 characters</li><li>max: 9 characters</li></ul> | <ul><li>min: 10 characters</li><li>mean: 10.1 characters</li><li>max: 11 characters</li></ul> | <ul><li>min: 10 characters</li><li>mean: 10.1 characters</li><li>max: 11 characters</li></ul> |",
+                "| <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
+                "Loss: [<code>BinaryCrossEntropyLoss</code>](https://sbert.net/docs/package_reference/cross_encoder/losses.html#binarycrossentropyloss) with these parameters:",
+            ],
+        ),
+        (
+            0,
+            3,
+            [
+                "- sentence-transformers",
+                "- cross-encoder",
+                "pipeline_tag: text-classification",
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny)",
+                "[sentence-transformers](https://www.SBERT.net) library",
+                "It computes scores for pairs of texts, which can be used for text pair classification.",
+                "**Maximum Sequence Length:** 512 tokens",
+                "- **Number of Output Labels:** 3 labels",
+                "<!-- - **Training Dataset:** Unknown -->",
+                "<!-- - **Language:** Unknown -->",
+                "<!-- - **License:** Unknown -->",
+                'model = CrossEncoder("cross_encoder_model_id")',
+                "['anchor 1', 'positive 1'],",
+                "# (5, 3)",
+                "#### Unnamed Dataset",
+                " | <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
+                "Loss: [<code>CrossEntropyLoss</code>](https://sbert.net/docs/package_reference/cross_encoder/losses.html#crossentropyloss)",
+            ],
+        ),
+        (
+            1,
+            1,
+            [
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny) on the train_0 dataset using the [sentence-transformers](https://www.SBERT.net) library.",
+                "#### train_0",
+            ],
+        ),
+        (
+            2,
+            1,
+            [
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny) on the train_0 and train_1 datasets using the [sentence-transformers](https://www.SBERT.net) library.",
+                "#### train_0",
+                "#### train_1",
+            ],
+        ),
+        (
+            10,
+            1,
+            [
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny) on the train_0, train_1, train_2, train_3, train_4, train_5, train_6, train_7, train_8 and train_9 datasets using the [sentence-transformers](https://www.SBERT.net) library.",
+                "<details><summary>train_0</summary>",  # We start using <details><summary> if we have more than 3 datasets
+                "#### train_0",
+                "</details>\n<details><summary>train_9</summary>",
+                "#### train_9",
+            ],
+        ),
+        # We start using "50 datasets" when the ", "-joined dataset name exceed 200 characters
+        (
+            50,
+            1,
+            [
+                "This is a [Cross Encoder](https://www.sbert.net/docs/cross_encoder/usage/usage.html) model finetuned from [prajjwal1/bert-tiny](https://huggingface.co/prajjwal1/bert-tiny) on 50 datasets using the [sentence-transformers](https://www.SBERT.net) library.",
+                "<details><summary>train_0</summary>",
+                "#### train_0",
+                "</details>\n<details><summary>train_49</summary>",
+                "#### train_49",
+            ],
+        ),
+    ],
+)
+def test_model_card_base(
+    dummy_dataset: Dataset,
+    num_datasets: int,
+    num_labels: int,
+    expected_substrings: list[str],
+) -> None:
+    model = CrossEncoder("prajjwal1/bert-tiny", num_labels=num_labels)
+
+    train_dataset = dummy_dataset
+    if num_datasets:
+        train_dataset = DatasetDict({f"train_{i}": train_dataset for i in range(num_datasets)})
+
+    # This adds data to model.model_card_data
+    CrossEncoderTrainer(
+        model,
+        train_dataset=train_dataset,
+    )
+
+    model_card = generate_model_card(model)
+
+    # For debugging purposes, we can save the model card to a file
+    # with open(f"test_model_card_{num_datasets}d_{num_labels}l.md", "w", encoding="utf8") as f:
+    #     f.write(model_card)
+
+    for substring in expected_substrings:
+        assert substring in model_card
+
+    # We don't want to have two consecutive empty lines anywhere
+    assert "\n\n\n" not in model_card
diff --git a/tests/cross_encoder/test_pretrained.py b/tests/cross_encoder/test_pretrained.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_pretrained.py
@@ -0,0 +1,28 @@
+from __future__ import annotations
+
+import pytest
+
+from sentence_transformers.cross_encoder import CrossEncoder
+
+
+@pytest.mark.parametrize(
+    "model_name, expected_score",
+    [
+        ("cross-encoder/ms-marco-MiniLM-L6-v2", [8.12545108795166, -3.045016050338745, -3.1524128913879395]),
+        ("cross-encoder/ms-marco-TinyBERT-L2-v2", [8.142767906188965, 1.2057735919952393, -2.7283530235290527]),
+        ("cross-encoder/stsb-distilroberta-base", [0.4977430999279022, 0.255491703748703, 0.28261035680770874]),
+        ("mixedbread-ai/mxbai-rerank-xsmall-v1", [0.9224735498428345, 0.04793589934706688, 0.03315146267414093]),
+    ],
+)
+def test_pretrained_model(model_name: str, expected_score: list[float]) -> None:
+    # Ensure that pretrained models are not accidentally changed
+    model = CrossEncoder(model_name)
+
+    query = "is toprol xl the same as metoprolol?"
+    answers = [
+        "Metoprolol succinate is also known by the brand name Toprol XL. It is the extended-release form of metoprolol. Metoprolol succinate is approved to treat high blood pressure, chronic chest pain, and congestive heart failure.",
+        "Pill with imprint 1 is White, Round and has been identified as Metoprolol Tartrate 25 mg.",
+        "Interactions between your drugs No interactions were found between Allergy Relief and metoprolol. This does not necessarily mean no interactions exist. Always consult your healthcare provider.",
+    ]
+    scores = model.predict([(query, answer) for answer in answers])
+    assert scores.tolist() == pytest.approx(expected_score, rel=1e-4)
diff --git a/tests/cross_encoder/test_train_stsb.py b/tests/cross_encoder/test_train_stsb.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_train_stsb.py
@@ -0,0 +1,90 @@
+from __future__ import annotations
+
+import csv
+import gzip
+import os
+from collections.abc import Generator
+
+import pytest
+from torch.utils.data import DataLoader
+
+from sentence_transformers import CrossEncoder, util
+from sentence_transformers.cross_encoder.evaluation import CrossEncoderCorrelationEvaluator
+from sentence_transformers.readers import InputExample
+from sentence_transformers.util import is_training_available
+
+if not is_training_available():
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
+
+
+@pytest.fixture()
+def sts_resource() -> Generator[tuple[list[InputExample], list[InputExample]], None, None]:
+    sts_dataset_path = "datasets/stsbenchmark.tsv.gz"
+    if not os.path.exists(sts_dataset_path):
+        util.http_get("https://sbert.net/datasets/stsbenchmark.tsv.gz", sts_dataset_path)
+
+    stsb_train_samples = []
+    stsb_test_samples = []
+    with gzip.open(sts_dataset_path, "rt", encoding="utf8") as fIn:
+        reader = csv.DictReader(fIn, delimiter="\t", quoting=csv.QUOTE_NONE)
+        for row in reader:
+            score = float(row["score"]) / 5.0  # Normalize score to range 0 ... 1
+            inp_example = InputExample(texts=[row["sentence1"], row["sentence2"]], label=score)
+
+            if row["split"] == "test":
+                stsb_test_samples.append(inp_example)
+            elif row["split"] == "train":
+                stsb_train_samples.append(inp_example)
+    yield stsb_train_samples, stsb_test_samples
+
+
+def evaluate_stsb_test(
+    distilroberta_base_ce_model: CrossEncoder,
+    expected_score: float,
+    test_samples: list[InputExample],
+    num_test_samples: int = -1,
+) -> None:
+    model = distilroberta_base_ce_model
+    evaluator = CrossEncoderCorrelationEvaluator.from_input_examples(test_samples[:num_test_samples], name="sts-test")
+    scores = evaluator(model)
+    score = scores[evaluator.primary_metric] * 100
+    print(f"STS-Test Performance: {score:.2f} vs. exp: {expected_score:.2f}")
+    assert score > expected_score or abs(score - expected_score) < 0.1
+
+
+def test_pretrained_stsb(sts_resource: tuple[list[InputExample], list[InputExample]]):
+    _, sts_test_samples = sts_resource
+    model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
+    evaluate_stsb_test(model, 87.92, sts_test_samples)
+
+
+@pytest.mark.slow
+def test_train_stsb_slow(
+    distilroberta_base_ce_model: CrossEncoder, sts_resource: tuple[list[InputExample], list[InputExample]]
+) -> None:
+    model = distilroberta_base_ce_model
+    sts_train_samples, sts_test_samples = sts_resource
+    train_dataloader = DataLoader(sts_train_samples, shuffle=True, batch_size=16)
+    model.fit(
+        train_dataloader=train_dataloader,
+        epochs=1,
+        warmup_steps=int(len(train_dataloader) * 0.1),
+    )
+    evaluate_stsb_test(model, 75, sts_test_samples)
+
+
+def test_train_stsb(
+    distilroberta_base_ce_model: CrossEncoder, sts_resource: tuple[list[InputExample], list[InputExample]]
+) -> None:
+    model = distilroberta_base_ce_model
+    sts_train_samples, sts_test_samples = sts_resource
+    train_dataloader = DataLoader(sts_train_samples[:500], shuffle=True, batch_size=16)
+    model.fit(
+        train_dataloader=train_dataloader,
+        epochs=1,
+        warmup_steps=int(len(train_dataloader) * 0.1),
+    )
+    evaluate_stsb_test(model, 50, sts_test_samples, num_test_samples=100)
diff --git a/tests/cross_encoder/test_trainer.py b/tests/cross_encoder/test_trainer.py
new file mode 100644
--- /dev/null
+++ b/tests/cross_encoder/test_trainer.py
@@ -0,0 +1,198 @@
+from __future__ import annotations
+
+import tempfile
+from contextlib import nullcontext
+from copy import deepcopy
+from pathlib import Path
+
+import pytest
+import torch
+
+from sentence_transformers.cross_encoder import (
+    CrossEncoder,
+    CrossEncoderTrainer,
+    CrossEncoderTrainingArguments,
+    losses,
+)
+from sentence_transformers.util import is_datasets_available, is_training_available
+from tests.utils import SafeTemporaryDirectory
+
+if is_datasets_available():
+    from datasets import DatasetDict, load_dataset
+
+if not is_training_available():
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
+
+
+def test_trainer_multi_dataset_errors(reranker_bert_tiny_model: CrossEncoder, stsb_dataset_dict: DatasetDict) -> None:
+    train_dataset = stsb_dataset_dict["train"]
+    loss = {
+        "multi_nli": losses.BinaryCrossEntropyLoss(model=reranker_bert_tiny_model),
+        "snli": losses.BinaryCrossEntropyLoss(model=reranker_bert_tiny_model),
+        "stsb": losses.BinaryCrossEntropyLoss(model=reranker_bert_tiny_model),
+    }
+    with pytest.raises(
+        ValueError, match="If the provided `loss` is a dict, then the `train_dataset` must be a `DatasetDict`."
+    ):
+        CrossEncoderTrainer(model=reranker_bert_tiny_model, train_dataset=train_dataset, loss=loss)
+
+    train_dataset = DatasetDict(
+        {
+            "multi_nli": stsb_dataset_dict["train"],
+            "snli": stsb_dataset_dict["train"],
+            "stsb": stsb_dataset_dict["train"],
+            "stsb-extra": stsb_dataset_dict["train"],
+        }
+    )
+    with pytest.raises(
+        ValueError,
+        match="If the provided `loss` is a dict, then all keys from the `train_dataset` dictionary must occur in `loss` also. "
+        r"Currently, \['stsb-extra'\] occurs in `train_dataset` but not in `loss`.",
+    ):
+        CrossEncoderTrainer(model=reranker_bert_tiny_model, train_dataset=train_dataset, loss=loss)
+
+    train_dataset = DatasetDict(
+        {
+            "multi_nli": stsb_dataset_dict["train"],
+            "snli": stsb_dataset_dict["train"],
+            "stsb": stsb_dataset_dict["train"],
+        }
+    )
+    with pytest.raises(
+        ValueError, match="If the provided `loss` is a dict, then the `eval_dataset` must be a `DatasetDict`."
+    ):
+        CrossEncoderTrainer(
+            model=reranker_bert_tiny_model,
+            train_dataset=train_dataset,
+            eval_dataset=stsb_dataset_dict["validation"],
+            loss=loss,
+        )
+
+    eval_dataset = DatasetDict(
+        {
+            "multi_nli": stsb_dataset_dict["validation"],
+            "snli": stsb_dataset_dict["validation"],
+            "stsb": stsb_dataset_dict["validation"],
+            "stsb-extra-1": stsb_dataset_dict["validation"],
+            "stsb-extra-2": stsb_dataset_dict["validation"],
+        }
+    )
+    with pytest.raises(
+        ValueError,
+        match="If the provided `loss` is a dict, then all keys from the `eval_dataset` dictionary must occur in `loss` also. "
+        r"Currently, \['stsb-extra-1', 'stsb-extra-2'\] occur in `eval_dataset` but not in `loss`.",
+    ):
+        CrossEncoderTrainer(
+            model=reranker_bert_tiny_model, train_dataset=train_dataset, eval_dataset=eval_dataset, loss=loss
+        )
+
+
+def test_model_card_reuse(reranker_bert_tiny_model: CrossEncoder):
+    assert reranker_bert_tiny_model._model_card_text
+    # Reuse the model card if no training was done
+    with SafeTemporaryDirectory() as tmp_folder:
+        model_path = Path(tmp_folder) / "tiny_model_local"
+        reranker_bert_tiny_model.save_pretrained(str(model_path))
+
+        with open(model_path / "README.md", encoding="utf8") as f:
+            model_card_text = f.read()
+        assert model_card_text == reranker_bert_tiny_model._model_card_text
+
+    # Create a new model card if a Trainer was initialized
+    CrossEncoderTrainer(model=reranker_bert_tiny_model)
+
+    with SafeTemporaryDirectory() as tmp_folder:
+        model_path = Path(tmp_folder) / "tiny_model_local"
+        reranker_bert_tiny_model.save_pretrained(str(model_path))
+
+        with open(model_path / "README.md", encoding="utf8") as f:
+            model_card_text = f.read()
+        assert model_card_text != reranker_bert_tiny_model._model_card_text
+
+
+@pytest.mark.parametrize("streaming", [False, True])
+@pytest.mark.parametrize("train_dict", [False, True])
+@pytest.mark.parametrize("eval_dict", [False, True])
+@pytest.mark.parametrize("loss_dict", [False, True])
+def test_trainer(
+    reranker_bert_tiny_model: CrossEncoder, streaming: bool, train_dict: bool, eval_dict: bool, loss_dict: bool
+) -> None:
+    """
+    Some cases are not allowed:
+    * streaming=True and train_dict=True: streaming is not supported with DatasetDict, because our DatasetDict
+      implementation concatenates the individual datasets and uses their sizes for tracking which original dataset the samples are from.
+      This is not possible with streaming datasets as they don't have a known size.
+      (Note: streaming=True and eval_dict=True does not throw an error because the transformers Trainer already allows for
+      dictionaries of evaluation datasets. In that case, the evaluation dataloader is created with just a normal IterableDataset multiple
+      times instead of a ConcatDataset of IterableDatasets.)
+    * loss_dict=True and (train_dict=False or eval_dict=False): if loss is a dict, then train_dataset and eval_dataset must be dicts too,
+      otherwise the trainer doesn't know which loss to use.
+    """
+    context = nullcontext()
+    if streaming:
+        context = pytest.raises(
+            ValueError,
+            match=(
+                "CrossEncoderTrainer does not support an IterableDataset for the `train_dataset`. "
+                "Please convert the dataset to a `Dataset` or `DatasetDict` before passing it to the trainer."
+            ),
+        )
+    elif loss_dict and not train_dict:
+        context = pytest.raises(
+            ValueError, match="If the provided `loss` is a dict, then the `train_dataset` must be a `DatasetDict`."
+        )
+    elif loss_dict and not eval_dict:
+        context = pytest.raises(
+            ValueError, match="If the provided `loss` is a dict, then the `eval_dataset` must be a `DatasetDict`."
+        )
+    elif streaming and train_dict:
+        context = pytest.raises(
+            ValueError,
+            match="Sentence Transformers is not compatible with a DatasetDict containing an IterableDataset.",
+        )
+
+    model = reranker_bert_tiny_model
+    original_model = deepcopy(model)
+    train_dataset = load_dataset("sentence-transformers/stsb", split="train[:10]")
+    eval_dataset = load_dataset("sentence-transformers/stsb", split="validation[:10]")
+    loss = losses.BinaryCrossEntropyLoss(model=model)
+
+    if streaming:
+        train_dataset = train_dataset.to_iterable_dataset()
+        eval_dataset = eval_dataset.to_iterable_dataset()
+    if train_dict:
+        train_dataset = DatasetDict({"stsb-1": train_dataset, "stsb-2": train_dataset})
+    if eval_dict:
+        eval_dataset = DatasetDict({"stsb-1": eval_dataset, "stsb-2": eval_dataset})
+    if loss_dict:
+        loss = {
+            "stsb-1": loss,
+            "stsb-2": loss,
+        }
+
+    with tempfile.TemporaryDirectory() as temp_dir:
+        args = CrossEncoderTrainingArguments(
+            output_dir=str(temp_dir),
+            max_steps=2,
+            eval_steps=2,
+            eval_strategy="steps",
+            per_device_train_batch_size=1,
+            per_device_eval_batch_size=1,
+        )
+        with context:
+            trainer = CrossEncoderTrainer(
+                model=model,
+                args=args,
+                train_dataset=train_dataset,
+                eval_dataset=eval_dataset,
+                loss=loss,
+            )
+            trainer.train()
+
+    if isinstance(context, nullcontext):
+        original_scores = original_model.predict("The cat is on the mat.", convert_to_tensor=True)
+        new_scores = model.predict("The cat is on the the mat.", convert_to_tensor=True)
+        assert not torch.equal(original_scores, new_scores)
diff --git a/tests/evaluation/test_nanobeir_evaluator.py b/tests/evaluation/test_nanobeir_evaluator.py
--- a/tests/evaluation/test_nanobeir_evaluator.py
+++ b/tests/evaluation/test_nanobeir_evaluator.py
@@ -6,6 +6,13 @@
 
 from sentence_transformers import SentenceTransformer
 from sentence_transformers.evaluation import NanoBEIREvaluator
+from sentence_transformers.util import is_datasets_available
+
+if not is_datasets_available():
+    pytest.skip(
+        reason="Datasets are not installed. Please install `datasets` with `pip install datasets`",
+        allow_module_level=True,
+    )
 
 
 def test_nanobeir_evaluator():
diff --git a/tests/samplers/test_group_by_label_batch_sampler.py b/tests/samplers/test_group_by_label_batch_sampler.py
--- a/tests/samplers/test_group_by_label_batch_sampler.py
+++ b/tests/samplers/test_group_by_label_batch_sampler.py
@@ -3,9 +3,17 @@
 from collections import Counter
 
 import pytest
-from datasets import Dataset
 
 from sentence_transformers.sampler import GroupByLabelBatchSampler
+from sentence_transformers.util import is_datasets_available
+
+if is_datasets_available():
+    from datasets import Dataset
+else:
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
 
 
 @pytest.fixture
diff --git a/tests/samplers/test_no_duplicates_batch_sampler.py b/tests/samplers/test_no_duplicates_batch_sampler.py
--- a/tests/samplers/test_no_duplicates_batch_sampler.py
+++ b/tests/samplers/test_no_duplicates_batch_sampler.py
@@ -4,10 +4,18 @@
 
 import pytest
 import torch
-from datasets import Dataset
 from torch.utils.data import ConcatDataset
 
 from sentence_transformers.sampler import NoDuplicatesBatchSampler, ProportionalBatchSampler
+from sentence_transformers.util import is_datasets_available
+
+if is_datasets_available():
+    from datasets import Dataset
+else:
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
 
 
 @pytest.fixture
diff --git a/tests/samplers/test_round_robin_batch_sampler.py b/tests/samplers/test_round_robin_batch_sampler.py
--- a/tests/samplers/test_round_robin_batch_sampler.py
+++ b/tests/samplers/test_round_robin_batch_sampler.py
@@ -1,10 +1,18 @@
 from __future__ import annotations
 
 import pytest
-from datasets import Dataset
 from torch.utils.data import BatchSampler, ConcatDataset, SequentialSampler
 
 from sentence_transformers.sampler import RoundRobinBatchSampler
+from sentence_transformers.util import is_datasets_available
+
+if is_datasets_available():
+    from datasets import Dataset
+else:
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
 
 DATASET_LENGTH = 25
 
diff --git a/tests/test_cross_encoder.py b/tests/test_cross_encoder.py
deleted file mode 100644
--- a/tests/test_cross_encoder.py
+++ /dev/null
@@ -1,226 +0,0 @@
-"""
-Tests that the pretrained models produce the correct scores on the STSbenchmark dataset
-"""
-
-from __future__ import annotations
-
-import csv
-import gzip
-import os
-from collections.abc import Generator
-from pathlib import Path
-
-import numpy as np
-import pytest
-import torch
-from pytest import FixtureRequest
-from torch.utils.data import DataLoader
-
-from sentence_transformers import CrossEncoder, util
-from sentence_transformers.cross_encoder.evaluation import CECorrelationEvaluator
-from sentence_transformers.readers import InputExample
-from tests.utils import SafeTemporaryDirectory
-
-
-@pytest.fixture()
-def sts_resource() -> Generator[tuple[list[InputExample], list[InputExample]], None, None]:
-    sts_dataset_path = "datasets/stsbenchmark.tsv.gz"
-    if not os.path.exists(sts_dataset_path):
-        util.http_get("https://sbert.net/datasets/stsbenchmark.tsv.gz", sts_dataset_path)
-
-    stsb_train_samples = []
-    stsb_test_samples = []
-    with gzip.open(sts_dataset_path, "rt", encoding="utf8") as fIn:
-        reader = csv.DictReader(fIn, delimiter="\t", quoting=csv.QUOTE_NONE)
-        for row in reader:
-            score = float(row["score"]) / 5.0  # Normalize score to range 0 ... 1
-            inp_example = InputExample(texts=[row["sentence1"], row["sentence2"]], label=score)
-
-            if row["split"] == "test":
-                stsb_test_samples.append(inp_example)
-            elif row["split"] == "train":
-                stsb_train_samples.append(inp_example)
-    yield stsb_train_samples, stsb_test_samples
-
-
-def evaluate_stsb_test(
-    distilroberta_base_ce_model: CrossEncoder,
-    expected_score: float,
-    test_samples: list[InputExample],
-    num_test_samples: int = -1,
-) -> None:
-    model = distilroberta_base_ce_model
-    evaluator = CECorrelationEvaluator.from_input_examples(test_samples[:num_test_samples], name="sts-test")
-    score = evaluator(model) * 100
-    print(f"STS-Test Performance: {score:.2f} vs. exp: {expected_score:.2f}")
-    assert score > expected_score or abs(score - expected_score) < 0.1
-
-
-def test_pretrained_stsb(sts_resource: tuple[list[InputExample], list[InputExample]]):
-    _, sts_test_samples = sts_resource
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
-    evaluate_stsb_test(model, 87.92, sts_test_samples)
-
-
-@pytest.mark.slow
-def test_train_stsb_slow(
-    distilroberta_base_ce_model: CrossEncoder, sts_resource: tuple[list[InputExample], list[InputExample]]
-) -> None:
-    model = distilroberta_base_ce_model
-    sts_train_samples, sts_test_samples = sts_resource
-    train_dataloader = DataLoader(sts_train_samples, shuffle=True, batch_size=16)
-    model.fit(
-        train_dataloader=train_dataloader,
-        epochs=1,
-        warmup_steps=int(len(train_dataloader) * 0.1),
-    )
-    evaluate_stsb_test(model, 75, sts_test_samples)
-
-
-def test_train_stsb(
-    distilroberta_base_ce_model: CrossEncoder, sts_resource: tuple[list[InputExample], list[InputExample]]
-) -> None:
-    model = distilroberta_base_ce_model
-    sts_train_samples, sts_test_samples = sts_resource
-    train_dataloader = DataLoader(sts_train_samples[:500], shuffle=True, batch_size=16)
-    model.fit(
-        train_dataloader=train_dataloader,
-        epochs=1,
-        warmup_steps=int(len(train_dataloader) * 0.1),
-    )
-    evaluate_stsb_test(model, 50, sts_test_samples, num_test_samples=100)
-
-
-def test_classifier_dropout_is_set() -> None:
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base", classifier_dropout=0.1234)
-    assert model.config.classifier_dropout == 0.1234
-    assert model.model.config.classifier_dropout == 0.1234
-
-
-def test_classifier_dropout_default_value() -> None:
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
-    assert model.config.classifier_dropout is None
-    assert model.model.config.classifier_dropout is None
-
-
-def test_load_with_revision() -> None:
-    model_name = "sentence-transformers-testing/stsb-bert-tiny-safetensors"
-
-    main_model = CrossEncoder(model_name, num_labels=1, revision="main")
-    latest_model = CrossEncoder(
-        model_name,
-        num_labels=1,
-        revision="f3cb857cba53019a20df283396bcca179cf051a4",
-    )
-    older_model = CrossEncoder(
-        model_name,
-        num_labels=1,
-        revision="ba33022fdf0b0fc2643263f0726f44d0a07d0e24",
-    )
-
-    # Set the classifier.bias and classifier.weight equal among models. This
-    # is needed because the AutoModelForSequenceClassification randomly initializes
-    # the classifier.bias and classifier.weight for each (model) initialization.
-    # The test is only possible if all models have the same classifier.bias
-    # and classifier.weight parameters.
-    latest_model.model.classifier.bias = main_model.model.classifier.bias
-    latest_model.model.classifier.weight = main_model.model.classifier.weight
-    older_model.model.classifier.bias = main_model.model.classifier.bias
-    older_model.model.classifier.weight = main_model.model.classifier.weight
-
-    test_sentences = [["Hello there!", "Hello, World!"]]
-    main_prob = main_model.predict(test_sentences, convert_to_tensor=True)
-    assert torch.equal(main_prob, latest_model.predict(test_sentences, convert_to_tensor=True))
-    assert not torch.equal(main_prob, older_model.predict(test_sentences, convert_to_tensor=True))
-
-
-@pytest.mark.parametrize(
-    argnames="return_documents",
-    argvalues=[True, False],
-    ids=["return-docs", "no-return-docs"],
-)
-def test_rank(return_documents: bool, request: FixtureRequest) -> None:
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
-    # We want to compute the similarity between the query sentence
-    query = "A man is eating pasta."
-
-    # With all sentences in the corpus
-    corpus = [
-        "A man is eating food.",
-        "A man is eating a piece of bread.",
-        "The girl is carrying a baby.",
-        "A man is riding a horse.",
-        "A woman is playing violin.",
-        "Two men pushed carts through the woods.",
-        "A man is riding a white horse on an enclosed ground.",
-        "A monkey is playing drums.",
-        "A cheetah is running behind its prey.",
-    ]
-    expected_ranking = [0, 1, 3, 6, 2, 5, 7, 4, 8]
-
-    # 1. We rank all sentences in the corpus for the query
-    ranks = model.rank(query=query, documents=corpus, return_documents=return_documents)
-    if request.node.callspec.id == "return-docs":
-        assert {*corpus} == {rank.get("text") for rank in ranks}
-
-    pred_ranking = [rank["corpus_id"] for rank in ranks]
-    assert pred_ranking == expected_ranking
-
-
-@pytest.mark.parametrize("safe_serialization", [True, False, None])
-def test_safe_serialization(safe_serialization: bool) -> None:
-    with SafeTemporaryDirectory() as cache_folder:
-        model = CrossEncoder("cross-encoder/stsb-distilroberta-base")
-        if safe_serialization:
-            model.save(cache_folder, safe_serialization=safe_serialization)
-            model_files = list(Path(cache_folder).glob("**/model.safetensors"))
-            assert 1 == len(model_files)
-        elif safe_serialization is None:
-            model.save(cache_folder)
-            model_files = list(Path(cache_folder).glob("**/model.safetensors"))
-            assert 1 == len(model_files)
-        else:
-            model.save(cache_folder, safe_serialization=safe_serialization)
-            model_files = list(Path(cache_folder).glob("**/pytorch_model.bin"))
-            assert 1 == len(model_files)
-
-
-def test_bfloat16() -> None:
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base", automodel_args={"torch_dtype": torch.bfloat16})
-    score = model.predict([["Hello there!", "Hello, World!"]])
-    assert isinstance(score, np.ndarray)
-
-    ranking = model.rank("Hello there!", ["Hello, World!", "Heya!"])
-    assert isinstance(ranking, list)
-
-
-@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
-@pytest.mark.parametrize("device", ["cpu", "cuda"])
-def test_device_assignment(device):
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base", device=device)
-    assert model.device.type == device
-
-
-@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
-def test_device_switching():
-    # test assignment using .to
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base", device="cpu")
-    assert model.device.type == "cpu"
-    assert model.model.device.type == "cpu"
-
-    model.to("cuda")
-    assert model.device.type == "cuda"
-    assert model.model.device.type == "cuda"
-
-    del model
-    torch.cuda.empty_cache()
-
-
-@pytest.mark.skipif(not torch.cuda.is_available(), reason="CUDA must be available to test moving devices effectively.")
-def test_target_device_backwards_compat():
-    model = CrossEncoder("cross-encoder/stsb-distilroberta-base", device="cpu")
-    assert model.device.type == "cpu"
-
-    assert model._target_device.type == "cpu"
-    model._target_device = "cuda"
-    assert model.device.type == "cuda"
diff --git a/tests/test_image_embeddings.py b/tests/test_image_embeddings.py
--- a/tests/test_image_embeddings.py
+++ b/tests/test_image_embeddings.py
@@ -16,7 +16,7 @@ def test_simple_encode(clip_vit_b_32_model: SentenceTransformer) -> None:
     # Encode an image:
     image_filepath = os.path.join(
         os.path.dirname(os.path.realpath(__file__)),
-        "../examples/applications/image-search/two_dogs_in_snow.jpg",
+        "../examples/sentence_transformer/applications/image-search/two_dogs_in_snow.jpg",
     )
     img_emb = model.encode(Image.open(image_filepath))
 
diff --git a/tests/test_model_card.py b/tests/test_model_card.py
--- a/tests/test_model_card.py
+++ b/tests/test_model_card.py
@@ -1,10 +1,19 @@
 from __future__ import annotations
 
 import pytest
-from datasets import Dataset, DatasetDict
 
 from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
 from sentence_transformers.model_card import generate_model_card
+from sentence_transformers.util import is_datasets_available, is_training_available
+
+if is_datasets_available():
+    from datasets import Dataset, DatasetDict
+
+if not is_training_available():
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
 
 
 @pytest.fixture(scope="session")
@@ -38,6 +47,7 @@ def dummy_dataset():
                 "**Output Dimensionality:** 128 dimensions",
                 "**Similarity Function:** Cosine Similarity",
                 "#### Unnamed Dataset",
+                "| details | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> |",
                 " | <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
                 "* Loss: [<code>CoSENTLoss</code>](https://sbert.net/docs/package_reference/sentence_transformer/losses.html#cosentloss) with these parameters:",
             ],
@@ -100,8 +110,8 @@ def test_model_card_base(
 
     model_card = generate_model_card(model)
 
-    # For debugging purposes, we save the model card to a file
-    # with open(f"test_model_card_{num_datasets}.md", "w", encoding="utf8") as f:
+    # For debugging purposes, we can save the model card to a file
+    # with open(f"test_model_card_{num_datasets}d.md", "w", encoding="utf8") as f:
     #     f.write(model_card)
 
     for substring in expected_substrings:
diff --git a/tests/test_model_card_data.py b/tests/test_model_card_data.py
--- a/tests/test_model_card_data.py
+++ b/tests/test_model_card_data.py
@@ -3,6 +3,7 @@
 import pytest
 
 from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer
+from sentence_transformers.util import is_training_available
 
 
 @pytest.mark.parametrize(
@@ -26,6 +27,9 @@ def test_model_card_data(revision, expected_base_revision) -> None:
         assert model.model_card_data.base_model_revision == expected_base_revision
 
 
+@pytest.mark.skipif(
+    not is_training_available(), reason='Sentence Transformers was not installed with the `["train"]` extra.'
+)
 def test_generated_from_trainer_tag(stsb_bert_tiny_model: SentenceTransformer) -> None:
     model = stsb_bert_tiny_model
 
diff --git a/tests/test_train_stsb.py b/tests/test_train_stsb.py
--- a/tests/test_train_stsb.py
+++ b/tests/test_train_stsb.py
@@ -23,6 +23,12 @@
 from sentence_transformers.readers import InputExample
 from sentence_transformers.util import is_training_available
 
+if not is_training_available():
+    pytest.skip(
+        reason='Sentence Transformers was not installed with the `["train"]` extra.',
+        allow_module_level=True,
+    )
+
 
 @pytest.fixture()
 def sts_resource() -> Generator[tuple[list[InputExample], list[InputExample]], None, None]:
diff --git a/tests/test_trainer.py b/tests/test_trainer.py
--- a/tests/test_trainer.py
+++ b/tests/test_trainer.py
@@ -8,7 +8,6 @@
 
 import pytest
 import torch
-from datasets.dataset_dict import DatasetDict
 
 from sentence_transformers import SentenceTransformer, SentenceTransformerTrainer, losses
 from sentence_transformers.evaluation import EmbeddingSimilarityEvaluator
@@ -182,7 +181,7 @@ def test_model_card_reuse(stsb_bert_tiny_model: SentenceTransformer):
         model_path = Path(tmp_folder) / "tiny_model_local"
         stsb_bert_tiny_model.save(str(model_path))
 
-        with open(model_path / "README.md") as f:
+        with open(model_path / "README.md", encoding="utf8") as f:
             model_card_text = f.read()
         assert model_card_text == stsb_bert_tiny_model._model_card_text
 
@@ -193,7 +192,7 @@ def test_model_card_reuse(stsb_bert_tiny_model: SentenceTransformer):
         model_path = Path(tmp_folder) / "tiny_model_local"
         stsb_bert_tiny_model.save(str(model_path))
 
-        with open(model_path / "README.md") as f:
+        with open(model_path / "README.md", encoding="utf8") as f:
             model_card_text = f.read()
         assert model_card_text != stsb_bert_tiny_model._model_card_text
 
EOF_114329324912

# Run the target tests in a single command for efficiency
# The patch may have moved files to subdirectories, so we run pytest on the new structure
# Using -v for verbose output and single-process mode for stability
pytest -v \
    tests/conftest.py \
    tests/evaluation/test_nanobeir_evaluator.py \
    tests/samplers/test_group_by_label_batch_sampler.py \
    tests/samplers/test_no_duplicates_batch_sampler.py \
    tests/samplers/test_round_robin_batch_sampler.py \
    tests/cross_encoder/test_cross_encoder.py \
    tests/test_image_embeddings.py \
    tests/cross_encoder/test_model_card.py \
    tests/test_model_card_data.py \
    tests/cross_encoder/test_train_stsb.py \
    tests/cross_encoder/test_trainer.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files (using original paths that exist in the repo)
git checkout 65395572fa9bf5a31e8edfb114c505ec22d0b607 \
    "tests/conftest.py" \
    "tests/evaluation/test_nanobeir_evaluator.py" \
    "tests/samplers/test_group_by_label_batch_sampler.py" \
    "tests/samplers/test_no_duplicates_batch_sampler.py" \
    "tests/samplers/test_round_robin_batch_sampler.py" \
    "tests/test_cross_encoder.py" \
    "tests/test_image_embeddings.py" \
    "tests/test_model_card.py" \
    "tests/test_model_card_data.py" \
    "tests/test_train_stsb.py" \
    "tests/test_trainer.py"