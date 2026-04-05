#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 0218a19a6b489d84232732fa39aea18bc0838514 "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java
--- a/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java
+++ b/src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java
@@ -26,7 +26,7 @@
 import com.google.devtools.build.lib.actions.ActionLookupKey;
 import com.google.devtools.build.lib.buildtool.util.BuildIntegrationTestCase;
 import com.google.devtools.build.lib.skyframe.AbstractNestedFileOpNodes.NestedFileOpNodes;
-import com.google.devtools.build.lib.skyframe.AbstractNestedFileOpNodes.NestedFileOpNodesWithSources;
+import com.google.devtools.build.lib.skyframe.AbstractNestedFileOpNodes.NestedFileOpNodesWithSource;
 import com.google.devtools.build.lib.skyframe.DirectoryListingKey;
 import com.google.devtools.build.lib.skyframe.FileKey;
 import com.google.devtools.build.lib.skyframe.FileOpNodeOrFuture.FileOpNode;
@@ -199,13 +199,11 @@ private static void flattenNode(
           flattenNode(nested.getAnalysisDependency(i), nodes, sources, visited);
         }
         break;
-      case NestedFileOpNodesWithSources withSources:
+      case NestedFileOpNodesWithSource withSources:
         for (int i = 0; i < withSources.analysisDependenciesCount(); i++) {
           flattenNode(withSources.getAnalysisDependency(i), nodes, sources, visited);
         }
-        for (int i = 0; i < withSources.sourceCount(); i++) {
-          sources.add(withSources.getSource(i));
-        }
+        sources.add(withSources.source());
         break;
     }
   }
EOF_114329324912

# Set up environment variables
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export HOME=/root

# Verify Bazel version
echo "=== Verifying Bazel version ==="
bazel version

# Run the specific test
# Based on the collected information, we use the exact test target and flags
bazel test \
    --java_runtime_version=21 \
    --java_language_version=21 \
    --tool_java_language_version=21 \
    --tool_java_runtime_version=21 \
    --test_output=all \
    --verbose_failures \
    --jobs=4 \
    --local_test_jobs=1 \
    //src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis:FileOpNodeMemoizingLookupTest

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 0218a19a6b489d84232732fa39aea18bc0838514 "src/test/java/com/google/devtools/build/lib/skyframe/serialization/analysis/FileOpNodeMemoizingLookupTest.java"