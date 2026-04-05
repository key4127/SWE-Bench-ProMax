#!/bin/bash
set -uxo pipefail

# Activate the conda environment
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate testbed

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout f8f111ea05547ecd4f747537143cf4cf8e432664 "tests/sparse_encoder/test_model_card.py" "tests/sparse_encoder/test_train_stsb.py" "tests/sparse_encoder/test_trainer.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/sparse_encoder/test_model_card.py b/tests/sparse_encoder/test_model_card.py
--- a/tests/sparse_encoder/test_model_card.py
+++ b/tests/sparse_encoder/test_model_card.py
@@ -58,7 +58,7 @@ def dummy_dataset():
                 "| details | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> |",
                 " | <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         (
@@ -68,7 +68,7 @@ def dummy_dataset():
                 "This is a [SPLADE Sparse Encoder](https://www.sbert.net/docs/sparse_encoder/usage/usage.html) model finetuned from [sparse-encoder-testing/splade-bert-tiny-nq](https://huggingface.co/sparse-encoder-testing/splade-bert-tiny-nq) on the train_0 dataset using the [sentence-transformers](https://www.SBERT.net) library.",
                 "#### train_0",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         (
@@ -79,7 +79,7 @@ def dummy_dataset():
                 "#### train_0",
                 "#### train_1",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         (
@@ -92,7 +92,7 @@ def dummy_dataset():
                 "</details>\n<details><summary>train_9</summary>",
                 "#### train_9",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         # We start using "50 datasets" when the ", "-joined dataset name exceed 200 characters
@@ -106,7 +106,7 @@ def dummy_dataset():
                 "</details>\n<details><summary>train_49</summary>",
                 "#### train_49",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         (
@@ -125,7 +125,7 @@ def dummy_dataset():
                 "| details | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> |",
                 " | <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
         (
@@ -146,7 +146,7 @@ def dummy_dataset():
                 "| details | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> | <ul><li>min: 4 tokens</li><li>mean: 4.0 tokens</li><li>max: 4 tokens</li></ul> |",
                 " | <code>anchor 1</code> | <code>positive 1</code> | <code>negative 1</code> |",
                 "* Loss: [<code>SpladeLoss</code>](https://sbert.net/docs/package_reference/sparse_encoder/losses.html#spladeloss) with these parameters:",
-                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "lambda_corpus": 3e-05,\n      "lambda_query": 5e-05\n  }\n  ```',
+                '  ```json\n  {\n      "loss": "SparseMultipleNegativesRankingLoss(scale=1.0, similarity_fct=\'dot_score\')",\n      "corpus_regularizer_weight": 3e-05,\n      "query_regularizer_weight": 5e-05\n  }\n  ```',
             ],
         ),
     ],
@@ -168,8 +168,8 @@ def test_model_card_base(
     loss = losses.SpladeLoss(
         model=model,
         loss=losses.SparseMultipleNegativesRankingLoss(model=model),
-        lambda_query=5e-5,  # Weight for query loss
-        lambda_corpus=3e-5,  # Weight for document loss
+        query_regularizer_weight=5e-5,  # Weight for query loss
+        corpus_regularizer_weight=3e-5,  # Weight for document loss
     )
 
     args = SparseEncoderTrainingArguments(
diff --git a/tests/sparse_encoder/test_train_stsb.py b/tests/sparse_encoder/test_train_stsb.py
--- a/tests/sparse_encoder/test_train_stsb.py
+++ b/tests/sparse_encoder/test_train_stsb.py
@@ -93,7 +93,10 @@ def test_train_stsb_slow(
     )
 
     loss = losses.SpladeLoss(
-        model=model, loss=losses.SparseMultipleNegativesRankingLoss(model=model), lambda_corpus=3e-5, lambda_query=5e-5
+        model=model,
+        loss=losses.SparseMultipleNegativesRankingLoss(model=model),
+        corpus_regularizer_weight=3e-5,
+        query_regularizer_weight=5e-5,
     )
 
     training_args = SparseEncoderTrainingArguments(
@@ -137,7 +140,10 @@ def test_train_stsb(
     train_dataset = Dataset.from_dict(train_dict)
 
     loss = losses.SpladeLoss(
-        model=model, loss=losses.SparseMultipleNegativesRankingLoss(model=model), lambda_corpus=3e-5, lambda_query=5e-5
+        model=model,
+        loss=losses.SparseMultipleNegativesRankingLoss(model=model),
+        corpus_regularizer_weight=3e-5,
+        query_regularizer_weight=5e-5,
     )
 
     training_args = SparseEncoderTrainingArguments(
diff --git a/tests/sparse_encoder/test_trainer.py b/tests/sparse_encoder/test_trainer.py
--- a/tests/sparse_encoder/test_trainer.py
+++ b/tests/sparse_encoder/test_trainer.py
@@ -57,8 +57,8 @@ def test_model_card_reuse(dummy_sparse_encoder_for_trainer: SparseEncoder):
         loss=losses.SpladeLoss(
             model=model,
             loss=losses.SparseMultipleNegativesRankingLoss(model=model),
-            lambda_corpus=3e-5,
-            lambda_query=5e-5,
+            corpus_regularizer_weight=3e-5,
+            query_regularizer_weight=5e-5,
         ),
     )
 
@@ -92,7 +92,10 @@ def test_trainer(
     original_model_params = [p.clone() for p in model.parameters()]
 
     loss = losses.SpladeLoss(
-        model=model, loss=losses.SparseMultipleNegativesRankingLoss(model=model), lambda_corpus=3e-5, lambda_query=5e-5
+        model=model,
+        loss=losses.SparseMultipleNegativesRankingLoss(model=model),
+        corpus_regularizer_weight=3e-5,
+        query_regularizer_weight=5e-5,
     )
 
     with tempfile.TemporaryDirectory() as temp_dir:
EOF_114329324912

# Run the target test files
# Using pytest with the three specified test files
# Note: We're not using the default markers filter since we want to run all tests in these files
pytest --no-header -rA --tb=short -p no:cacheprovider tests/sparse_encoder/test_model_card.py tests/sparse_encoder/test_train_stsb.py tests/sparse_encoder/test_trainer.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout f8f111ea05547ecd4f747537143cf4cf8e432664 "tests/sparse_encoder/test_model_card.py" "tests/sparse_encoder/test_train_stsb.py" "tests/sparse_encoder/test_trainer.py"