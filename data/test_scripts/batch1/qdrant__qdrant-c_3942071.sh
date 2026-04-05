#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset the target test file to the original commit state
git checkout 273f53f1b7f81904906e550e8efecea24088fe69 "lib/posting_list/src/tests.rs"

# Apply the test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/lib/posting_list/src/tests.rs b/lib/posting_list/src/tests.rs
--- a/lib/posting_list/src/tests.rs
+++ b/lib/posting_list/src/tests.rs
@@ -1,10 +1,12 @@
+use std::collections::HashMap;
+
 use common::types::PointOffsetType;
 use rand::distr::{Alphanumeric, SampleString};
 use rand::rngs::StdRng;
 use rand::{Rng, SeedableRng};
 
 use crate::value_handler::ValueHandler;
-use crate::{CHUNK_LEN, PostingBuilder, PostingList, UnsizedValue};
+use crate::{CHUNK_LEN, PostingBuilder, PostingList, SizedHandler, UnsizedHandler, UnsizedValue};
 
 // Simple struct that implements VarSizedValue for testing
 #[derive(Debug, Clone, PartialEq)]
@@ -28,7 +30,7 @@ impl UnsizedValue for TestString {
 #[test]
 fn test_just_ids_against_vec() {
     check_various_lengths(|len| {
-        let posting_list = check_against_sorted_vec(|_rng, _id| (), |builder| builder.build(), len);
+        let posting_list = check_against_sorted_vec::<_, SizedHandler<()>>(|_rng, _id| (), len);
 
         // validate that chunks' sized values are empty
         if let Some(first_chunk) = posting_list.chunks.first() {
@@ -46,13 +48,12 @@ fn test_just_ids_against_vec() {
 fn test_var_sized_against_vec() {
     let alphanumeric = Alphanumeric;
     check_various_lengths(|len| {
-        check_against_sorted_vec(
+        check_against_sorted_vec::<_, UnsizedHandler<TestString>>(
             |rng, id| {
                 let len = rng.random_range(1..=20);
                 let s = alphanumeric.sample_string(rng, len);
                 TestString(format!("item_{id} {s}"))
             },
-            |builder| builder.build_unsized(),
             len,
         );
     })
@@ -61,11 +62,7 @@ fn test_var_sized_against_vec() {
 #[test]
 fn test_fixed_sized_against_vec() {
     check_various_lengths(|len| {
-        check_against_sorted_vec(
-            |_rng, id| u64::from(id) * 100,
-            |builder| builder.build_sized(),
-            len,
-        );
+        check_against_sorted_vec::<_, SizedHandler<u64>>(|_rng, id| u64::from(id) * 100, len);
     });
 }
 
@@ -94,6 +91,8 @@ fn check_various_lengths(check: impl Fn(u32)) {
         CHUNK_LEN - 1,
         CHUNK_LEN,
         CHUNK_LEN + 1,
+        CHUNK_LEN + 2,
+        2 * CHUNK_LEN + 10,
         100 * CHUNK_LEN,
         500 * CHUNK_LEN + 1,
         500 * CHUNK_LEN - 1,
@@ -104,12 +103,11 @@ fn check_various_lengths(check: impl Fn(u32)) {
     }
 }
 
-fn check_against_sorted_vec<G, H, B>(gen_value: G, build: B, postings_count: u32) -> PostingList<H>
+fn check_against_sorted_vec<G, H>(gen_value: G, postings_count: u32) -> PostingList<H>
 where
     G: Fn(&mut StdRng, PointOffsetType) -> H::Value,
     H: ValueHandler,
-    B: FnOnce(PostingBuilder<H::Value>) -> PostingList<H>,
-    H::Value: Clone + PartialEq,
+    H::Value: Clone + PartialEq + std::fmt::Debug,
 {
     let rng = &mut StdRng::seed_from_u64(42);
     let test_data = generate_data(postings_count, rng, gen_value);
@@ -125,10 +123,11 @@ where
     }
 
     // Build the actual posting list
-    let posting_list = build(builder);
+    let posting_list = builder.build_generic();
 
     // Access the posting list
     let mut visitor = posting_list.visitor();
+    let mut intersection_iter = posting_list.iter();
 
     // Validate len()
     assert_eq!(visitor.len(), model.len());
@@ -144,6 +143,12 @@ where
 
         // also check that contains function works
         assert!(visitor.contains(*expected_id));
+
+        // also check that the intersection is full
+        let intersection = intersection_iter
+            .advance_until_greater_or_equal(*expected_id)
+            .unwrap();
+        assert_eq!(intersection.id, *expected_id);
     }
 
     // Bounds check
@@ -154,5 +159,16 @@ where
     // There is no such id
     assert!(!visitor.contains(postings_count));
 
+    // intersect against all sequential ids in the posting range, model is a hashmap in this case
+    let model = model.into_iter().collect::<HashMap<_, _>>();
+    let mut intersection_iter = posting_list.iter();
+    for seq_id in 0..postings_count {
+        let model_contains = model.contains_key(&seq_id);
+        let iter_contains = intersection_iter
+            .advance_until_greater_or_equal(seq_id)
+            .is_some_and(|elem| elem.id == seq_id);
+        assert_eq!(model_contains, iter_contains, "Mismatch at seq_id {seq_id}");
+    }
+
     posting_list
 }
diff --git a/lib/segment/src/index/field_index/full_text_index/mmap_inverted_index/tests.rs b/lib/segment/src/index/field_index/full_text_index/mmap_inverted_index/tests.rs
new file mode 100644
--- /dev/null
+++ b/lib/segment/src/index/field_index/full_text_index/mmap_inverted_index/tests.rs
@@ -0,0 +1,61 @@
+use common::counter::hardware_counter::HardwareCounterCell;
+use common::types::PointOffsetType;
+use rand::Rng;
+
+use super::{mmap_postings, old_mmap_postings};
+use crate::index::field_index::full_text_index::compressed_posting::compressed_posting_list::CompressedPostingList;
+
+fn generate_ids(rng: &mut impl Rng, amount: usize) -> Vec<PointOffsetType> {
+    let distr = rand::distr::Uniform::new(0, amount as u32).unwrap();
+    rng.sample_iter(distr).take(amount).collect()
+}
+
+#[test]
+fn test_mmap_posting_lists_compatibility() {
+    let rng = &mut rand::rng();
+    let lengths = [138, 14, 1889, 128, 129, 127];
+
+    // postings in a vec of vecs
+    let postings = lengths
+        .into_iter()
+        .map(|len| generate_ids(rng, len))
+        .collect::<Vec<_>>();
+
+    // old compressed postings implementation
+    let old_compressed_postings = postings
+        .iter()
+        .map(|ids| CompressedPostingList::new(ids))
+        .collect::<Vec<_>>();
+
+    let dir = tempfile::tempdir().unwrap();
+    let postings_path = dir.path().join("postings.dat");
+
+    // Create mmap postings file
+    old_mmap_postings::MmapPostings::create(postings_path.clone(), &old_compressed_postings)
+        .unwrap();
+
+    // open with old impl
+    let old_postings = old_mmap_postings::MmapPostings::open(postings_path.clone(), true).unwrap();
+
+    // open with new impl
+    let new_postings = mmap_postings::MmapPostings::open(postings_path.clone(), true).unwrap();
+
+    let hw_counter = HardwareCounterCell::disposable();
+
+    for token_id in 0..postings.len() as u32 {
+        let old = old_postings.get(token_id, &hw_counter).unwrap();
+        let new = new_postings.get(token_id, &hw_counter).unwrap();
+        let model = &postings[token_id as usize];
+
+        // check all impls iterate the same ids
+        for (offset, id_old, elem_new, &id_model) in
+            itertools::multizip((0u32.., old.iter(), new.into_iter(), model.iter()))
+        {
+            assert!(
+                id_model == id_old && id_model == elem_new.id,
+                "Mismatch at token_id {token_id}: offset: {offset}, old: {id_old}, new: {}, model: {id_model}",
+                elem_new.id
+            );
+        }
+    }
+}
EOF_114329324912

# Execute the specific test file using cargo test for the posting_list crate
cargo test -p posting_list --tests -- --test-threads=1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 273f53f1b7f81904906e550e8efecea24088fe69 "lib/posting_list/src/tests.rs"