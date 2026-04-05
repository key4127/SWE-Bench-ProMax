#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 82e36a2e82e558ae52d60a1c2b52d0c5d774c47a \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java" \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java" \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java b/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java
--- a/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java
+++ b/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java
@@ -919,16 +919,6 @@ public long getResponseExceptionSize() {
       @Override
       public void incrementResponseExceptionSize(long exceptionSize) {
       }
-
-      @Override
-      public void updateFsReadTime(long latencyMillis) {
-
-      }
-
-      @Override
-      public long getFsReadTime() {
-        return 0;
-      }
     };
     return rpcCall;
   }
diff --git a/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java b/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java
--- a/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java
+++ b/hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java
@@ -264,16 +264,6 @@ public long getResponseExceptionSize() {
       @Override
       public void incrementResponseExceptionSize(long exceptionSize) {
       }
-
-      @Override
-      public void updateFsReadTime(long latencyMillis) {
-
-      }
-
-      @Override
-      public long getFsReadTime() {
-        return 0;
-      }
     };
     return rpcCall;
   }
diff --git a/hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java b/hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java
--- a/hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java
+++ b/hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java
@@ -326,16 +326,6 @@ public long getResponseExceptionSize() {
       @Override
       public void incrementResponseExceptionSize(long exceptionSize) {
       }
-
-      @Override
-      public void updateFsReadTime(long latencyMillis) {
-
-      }
-
-      @Override
-      public long getFsReadTime() {
-        return 0;
-      }
     };
   }
 }
EOF_114329324912

# Execute the target tests using Maven
# Run all three tests in a single command for efficiency
# Using single-process mode for stability in the virtualized environment
mvn test -pl hbase-server \
    -Dtest=TestNamedQueueRecorder,TestRpcLogDetails,TestRegionProcedureStore \
    -Dsurefire.reuseForks=false \
    -DforkCount=1 \
    -Dmaven.test.failure.ignore=false \
    -Dtest.build.webapps=target/test-classes/webapps \
    -Djava.security.egd=file:/dev/./urandom \
    -Djava.net.preferIPv4Stack=true \
    -Djava.awt.headless=true

# Capture exit code
rc=$?

# Echo exit code for test result evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 82e36a2e82e558ae52d60a1c2b52d0c5d774c47a \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestNamedQueueRecorder.java" \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/namequeues/TestRpcLogDetails.java" \
    "hbase-server/src/test/java/org/apache/hadoop/hbase/procedure2/store/region/TestRegionProcedureStore.java"