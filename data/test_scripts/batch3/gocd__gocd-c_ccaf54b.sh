#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 6c079134804385810caa9c15af16ca897e2cae29 "common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java b/common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java
--- a/common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java
+++ b/common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java
@@ -154,6 +154,39 @@ public void shouldIgnoreExtraMaterialForComparison() {
         assertThat(that.compareTo(entry)).isEqualTo(1);
     }
 
+    @Test
+    public void shouldComparePipelineEntriesWithIdenticalCounterConsistentlyIfNoMatchingRevisions() {
+        // This test is essentially a test for a very old bug. The prior code assumed that the counter is unique for a given
+        // pipeline, (which should generally hold true) however there is data in at least some databases that implies
+        // this was not universally true in history in some cases where the pipeline name differs only by its case.
+        //
+        // Only observed in build.gocd.org data for the `security`/`Security` and `foo`/`Foo` pipelines from 2016/2017
+        //
+        // In these cases you have two pipeline timeline entries in the same pipeline which have the same counter;
+        // which normally should not happen. Code prior to 2026 assumed this wasn't possible and actually violated the
+        // comparison contract as they did not return `0` on an equal pipeline counter.
+        //
+        // The comparison code was changed to make this unambiguous to compare by DB ID as a fallback, rather than stick with
+        // the prior code which broke the compareTo contract. This seems to basically behave as the TreeSet was relying
+        // given the order of insertions. Since the DB results were sorted by pipeline ID; the bigger ID is already
+        // encountered later than the smaller ID; so during insertion only the "bigger" ID is being compared and the result
+        // of comparison to existing entries with same counter;
+
+        ZonedDateTime now = ZonedDateTime.now();
+
+        //Ignore the extra material
+        PipelineTimelineEntry entry = timelineEntry(2, List.of("first"), List.of(now), 1);
+        PipelineTimelineEntry that = timelineEntry(1, List.of("second"), List.of(now.plusMinutes(2)), 1);
+
+        assertThat(entry.compareTo(that)).isEqualTo(1);
+        assertThat(that.compareTo(entry)).isEqualTo(-1);
+
+        // If they have the same pipeline id they become equal and ordering becomes ambiguous (which definitely shouldn't happen!)
+        entry = timelineEntry(1, List.of("first"), List.of(now), 1);
+        assertThat(entry.compareTo(that)).isEqualTo(0);
+        assertThat(that.compareTo(entry)).isEqualTo(0);
+    }
+
     @Test
     public void shouldIgnoreExtraMaterialForComparisonWithNoMatchingMaterials() {
         ZonedDateTime now = ZonedDateTime.now();
EOF_114329324912

# Run the specific test using Gradle
# Using --no-daemon and --no-build-cache as recommended for containerized execution
./gradlew :common:test --tests "com.thoughtworks.go.domain.PipelineTimelineEntryTest" --no-daemon --no-build-cache

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 6c079134804385810caa9c15af16ca897e2cae29 "common/src/test/java/com/thoughtworks/go/domain/PipelineTimelineEntryTest.java"