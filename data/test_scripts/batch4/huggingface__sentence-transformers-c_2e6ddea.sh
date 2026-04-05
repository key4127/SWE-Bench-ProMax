#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Ensure environment variables are set
export TOKENIZERS_PARALLELISM=false

# Checkout the target test file to ensure clean state
git checkout 3a66a2c4747a5ef82e45afb499620018156f1393 \
    "examples/sparse_encoder/applications/application_test_inference_free.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/examples/sparse_encoder/applications/application_test_inference_free.py b/examples/sparse_encoder/applications/application_test_inference_free.py
--- a/examples/sparse_encoder/applications/application_test_inference_free.py
+++ b/examples/sparse_encoder/applications/application_test_inference_free.py
@@ -1,5 +1,3 @@
-import numpy as np
-
 from sentence_transformers import models
 from sentence_transformers.sparse_encoder import SparseEncoder
 from sentence_transformers.sparse_encoder.models import IDF, MLMTransformer, SpladePooling
@@ -40,18 +38,15 @@
 top_k = 3
 print(f"\nTop tokens {top_k} for each text:")
 
-# Get top k indices in sparse tensor (sorted from highest to lowest)
-top_indices = np.argsort(-query_embed.to_dense().cpu().numpy())[:top_k][0]
-top_tokens = [model.tokenizer.decode([idx]) for idx in top_indices]
-top_value_query_associate_score = query_embed.to_dense().cpu().numpy()[0, top_indices]
-top_value_doc_associate_score = document_embed.to_dense().cpu().numpy()[0, top_indices]
+decoded_query = model.decode(query_embed)[0]
+decoded_document = model.decode(document_embed[0], top_k=100)
+
 for i in range(top_k):
-    if top_value_doc_associate_score[i] != 0:
-        print(
-            f"Token: {top_tokens[i]}, "
-            f"Query score: {top_value_query_associate_score[i]:.4f}, "
-            f"Document score: {top_value_doc_associate_score[i]:.4f}"
-        )
+    query_token, query_score = decoded_query[i]
+    doc_score = next((score for token, score in decoded_document if token == query_token), 0)
+    if doc_score != 0:
+        print(f"Token: {query_token}, Query score: {query_score:.4f}, Document score: {doc_score:.4f}")
+
 """
 # ------------------------------------------example with v2 distill-----------------------------------------
 Similarity: tensor([[17.5307]], device='cuda:0')
@@ -98,18 +93,14 @@
 top_k = 10
 print(f"\nTop tokens {top_k} for each text:")
 
-# Get top k indices in sparse tensor (sorted from highest to lowest)
-top_indices = np.argsort(-query_embed.to_dense().cpu().numpy())[:top_k][0]
-top_tokens = [model.tokenizer.decode([idx]) for idx in top_indices]
-top_value_query_associate_score = query_embed.to_dense().cpu().numpy()[0, top_indices]
-top_value_doc_associate_score = document_embed.to_dense().cpu().numpy()[0, top_indices]
+decoded_query = model.decode(query_embed)[0]
+decoded_document = model.decode(document_embed[0], top_k=100)
+
 for i in range(top_k):
-    if top_value_doc_associate_score[i] != 0:
-        print(
-            f"Token: {top_tokens[i]}, "
-            f"Query score: {top_value_query_associate_score[i]:.4f}, "
-            f"Document score: {top_value_doc_associate_score[i]:.4f}"
-        )
+    query_token, query_score = decoded_query[i]
+    doc_score = next((score for token, score in decoded_document if token == query_token), 0)
+    if doc_score != 0:
+        print(f"Token: {query_token}, Query score: {query_score:.4f}, Document score: {doc_score:.4f}")
 
 """
 # -----------------------------------------example with v3 distill-----------------------------------------
EOF_114329324912

# Run the target test script
# This is a standalone Python script, not a pytest test
python examples/sparse_encoder/applications/application_test_inference_free.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 3a66a2c4747a5ef82e45afb499620018156f1393 \
    "examples/sparse_encoder/applications/application_test_inference_free.py"