#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure Rust environment is properly set up
source /root/.bashrc

# Reset the target test file to original state
git checkout 4542228e745cd4cdcb8aa7118374e951411cb32d "lib/collection/src/collection_manager/tests/mod.rs"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/collection/src/collection_manager/tests/mod.rs b/lib/collection/src/collection_manager/tests/mod.rs
--- a/lib/collection/src/collection_manager/tests/mod.rs
+++ b/lib/collection/src/collection_manager/tests/mod.rs
@@ -13,6 +13,8 @@ use segment::entry::entry_point::SegmentEntry;
 use segment::json_path::JsonPath;
 use segment::payload_json;
 use segment::types::{ExtendedPointId, PayloadContainer, PointIdType, WithPayload, WithVector};
+use shard::retrieve::record_internal::RecordInternal;
+use shard::retrieve::retrieve_blocking::retrieve_blocking;
 use shard::update::{delete_points, set_payload, upsert_points};
 use tempfile::Builder;
 
@@ -22,9 +24,7 @@ use crate::collection_manager::holders::proxy_segment::ProxySegment;
 use crate::collection_manager::holders::segment_holder::{
     LockedSegment, LockedSegmentHolder, SegmentHolder, SegmentId,
 };
-use crate::collection_manager::segments_searcher::SegmentsSearcher;
 use crate::operations::point_ops::{PointStructPersisted, VectorStructPersisted};
-use crate::operations::types::RecordInternal;
 
 mod test_search_aggregation;
 
@@ -292,7 +292,7 @@ fn test_delete_all_point_versions() {
     let segments = Arc::new(RwLock::new(holder));
 
     // We should be able to retrieve point 123
-    let retrieved = SegmentsSearcher::retrieve_blocking(
+    let retrieved = retrieve_blocking(
         segments.clone(),
         &[point_id],
         &WithPayload::from(false),
@@ -337,7 +337,7 @@ fn test_delete_all_point_versions() {
 
     // We must not be able to retrieve point 123
     // Note: before the bug fix we could retrieve the point again from segment 1
-    let retrieved = SegmentsSearcher::retrieve_blocking(
+    let retrieved = retrieve_blocking(
         segments.clone(),
         &[point_id],
         &WithPayload::from(false),
@@ -456,7 +456,7 @@ fn test_proxy_shared_updates() {
     let with_payload = WithPayload::from(true);
     let with_vector = WithVector::from(true);
 
-    let result = SegmentsSearcher::retrieve_blocking(
+    let result = retrieve_blocking(
         locked_holder.clone(),
         &ids,
         &with_payload,
@@ -595,7 +595,7 @@ fn test_proxy_shared_updates_same_version() {
     let with_payload = WithPayload::from(true);
     let with_vector = WithVector::from(true);
 
-    let result = SegmentsSearcher::retrieve_blocking(
+    let result = retrieve_blocking(
         locked_holder.clone(),
         &ids,
         &with_payload,
EOF_114329324912

# Execute the specific tests in the collection_manager::tests module
# Using --package collection to target the correct package and single-threaded execution
cargo test --package collection --lib collection_manager::tests -- --test-threads=1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Revert the test file to original state
git checkout 4542228e745cd4cdcb8aa7118374e951411cb32d "lib/collection/src/collection_manager/tests/mod.rs"