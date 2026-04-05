#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure we're on the correct commit and have clean test files
git checkout a926a28d78a4d0b7706a16f67bb54be30eb0cf20 "lib/quantization/tests/integration/test_avx2.rs" "lib/quantization/tests/integration/test_neon.rs" "lib/quantization/tests/integration/test_simple.rs" "lib/quantization/tests/integration/test_sse.rs"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/quantization/tests/integration/test_avx2.rs b/lib/quantization/tests/integration/test_avx2.rs
--- a/lib/quantization/tests/integration/test_avx2.rs
+++ b/lib/quantization/tests/integration/test_avx2.rs
@@ -45,7 +45,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_avx(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_avx(&query_u8, quantized_vector);
             let orginal_score = dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -86,7 +87,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_avx(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_avx(&query_u8, quantized_vector);
             let orginal_score = l2_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -131,7 +133,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_avx(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_avx(&query_u8, quantized_vector);
             let orginal_score = l1_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
diff --git a/lib/quantization/tests/integration/test_neon.rs b/lib/quantization/tests/integration/test_neon.rs
--- a/lib/quantization/tests/integration/test_neon.rs
+++ b/lib/quantization/tests/integration/test_neon.rs
@@ -45,7 +45,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_neon(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_neon(&query_u8, quantized_vector);
             let orginal_score = dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -86,7 +87,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_neon(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_neon(&query_u8, quantized_vector);
             let orginal_score = l2_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -127,7 +129,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_neon(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_neon(&query_u8, quantized_vector);
             let orginal_score = l1_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
diff --git a/lib/quantization/tests/integration/test_simple.rs b/lib/quantization/tests/integration/test_simple.rs
--- a/lib/quantization/tests/integration/test_simple.rs
+++ b/lib/quantization/tests/integration/test_simple.rs
@@ -45,7 +45,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -86,7 +87,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = l2_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -131,7 +133,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = l1_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -172,7 +175,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = -dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -213,7 +217,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = -l2_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -258,7 +263,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = -l1_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -379,7 +385,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_simple(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_simple(&query_u8, quantized_vector);
             let orginal_score = dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
diff --git a/lib/quantization/tests/integration/test_sse.rs b/lib/quantization/tests/integration/test_sse.rs
--- a/lib/quantization/tests/integration/test_sse.rs
+++ b/lib/quantization/tests/integration/test_sse.rs
@@ -45,7 +45,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_sse(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_sse(&query_u8, quantized_vector);
             let orginal_score = dot_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -86,7 +87,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_sse(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_sse(&query_u8, quantized_vector);
             let orginal_score = l2_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
@@ -127,7 +129,8 @@ mod tests {
         let query_u8 = encoded.encode_query(&query);
 
         for (index, vector) in vector_data.iter().enumerate() {
-            let score = encoded.score_point_sse(&query_u8, index as u32);
+            let quantized_vector = encoded.get_quantized_vector(index as u32);
+            let score = encoded.score_point_sse(&query_u8, quantized_vector);
             let orginal_score = l1_similarity(&query, vector);
             assert!((score - orginal_score).abs() < error);
         }
EOF_114329324912

# Run the specific integration tests for quantization with CI profile
cargo test -p quantization --test integration --profile ci -- --test-threads=1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout a926a28d78a4d0b7706a16f67bb54be30eb0cf20 "lib/quantization/tests/integration/test_avx2.rs" "lib/quantization/tests/integration/test_neon.rs" "lib/quantization/tests/integration/test_simple.rs" "lib/quantization/tests/integration/test_sse.rs"