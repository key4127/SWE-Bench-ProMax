#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 278e5d6d6f9a2e20f97cfbe8bf5e1741b0b70005 "pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java" "pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java
--- a/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java
+++ b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java
@@ -40,7 +40,7 @@ public void testOnClusterConfigChangeWithAllConfigs() {
     properties.put("pinot.audit.capture.request.payload.enabled", "true");
     properties.put("pinot.audit.capture.request.headers", "Content-Type,X-Request-Id,Authorization");
     properties.put("pinot.audit.payload.size.max.bytes", "20480");
-    properties.put("pinot.audit.excluded.endpoints", "/health,/metrics");
+    properties.put("pinot.audit.url.filter.exclude.patterns", "/health,/metrics");
     properties.put("some.other.config", "value");
     properties.put("another.config", "123");
 
@@ -55,7 +55,7 @@ public void testOnClusterConfigChangeWithAllConfigs() {
     assertThat(config.isCaptureRequestPayload()).isTrue();
     assertThat(config.getCaptureRequestHeaders()).isEqualTo("Content-Type,X-Request-Id,Authorization");
     assertThat(config.getMaxPayloadSize()).isEqualTo(20480);
-    assertThat(config.getExcludedEndpoints()).isEqualTo("/health,/metrics");
+    assertThat(config.getUrlFilterExcludePatterns()).isEqualTo("/health,/metrics");
   }
 
   @Test
@@ -79,7 +79,7 @@ public void testOnClusterConfigChangeWithPartialConfigs() {
     // Verify defaults for unspecified configs
     assertThat(config.isCaptureRequestPayload()).isFalse();
     assertThat(config.getCaptureRequestHeaders()).isEmpty();
-    assertThat(config.getExcludedEndpoints()).isEmpty();
+    assertThat(config.getUrlFilterExcludePatterns()).isEmpty();
   }
 
   @Test
@@ -99,7 +99,7 @@ public void testOnClusterConfigChangeWithNoAuditConfigs() {
     assertThat(config.isCaptureRequestPayload()).isFalse();
     assertThat(config.getCaptureRequestHeaders()).isEmpty();
     assertThat(config.getMaxPayloadSize()).isEqualTo(10240);
-    assertThat(config.getExcludedEndpoints()).isEmpty();
+    assertThat(config.getUrlFilterExcludePatterns()).isEmpty();
   }
 
   @Test
@@ -145,7 +145,7 @@ public void testBuildFromClusterConfigDirectly() {
     assertThat(config.getCaptureRequestHeaders()).isEqualTo("X-User-Id,X-Session-Token");
     // Verify defaults for unspecified fields
     assertThat(config.getMaxPayloadSize()).isEqualTo(10240);
-    assertThat(config.getExcludedEndpoints()).isEmpty();
+    assertThat(config.getUrlFilterExcludePatterns()).isEmpty();
   }
 
   @Test
@@ -213,7 +213,7 @@ public void testZookeeperConfigDeletionRevertsToDefaults() {
     customProperties.put("pinot.audit.capture.request.payload.enabled", "true");
     customProperties.put("pinot.audit.capture.request.headers", "X-Trace-Id,X-Correlation-Id");
     customProperties.put("pinot.audit.payload.size.max.bytes", "50000");
-    customProperties.put("pinot.audit.excluded.endpoints", "/test,/debug");
+    customProperties.put("pinot.audit.url.filter.exclude.patterns", "/test,/debug");
     manager.onChange(customProperties.keySet(), customProperties);
 
     // Verify custom configs are applied
@@ -222,7 +222,7 @@ public void testZookeeperConfigDeletionRevertsToDefaults() {
     assertThat(customConfig.isCaptureRequestPayload()).isTrue();
     assertThat(customConfig.getCaptureRequestHeaders()).isEqualTo("X-Trace-Id,X-Correlation-Id");
     assertThat(customConfig.getMaxPayloadSize()).isEqualTo(50000);
-    assertThat(customConfig.getExcludedEndpoints()).isEqualTo("/test,/debug");
+    assertThat(customConfig.getUrlFilterExcludePatterns()).isEqualTo("/test,/debug");
 
     // When - Simulate ZooKeeper config deletion with empty map
     // The changedConfigs should contain the keys that were deleted, but clusterConfigs should be empty
@@ -235,7 +235,7 @@ public void testZookeeperConfigDeletionRevertsToDefaults() {
     assertThat(defaultConfig.isCaptureRequestPayload()).isFalse();
     assertThat(defaultConfig.getCaptureRequestHeaders()).isEmpty();
     assertThat(defaultConfig.getMaxPayloadSize()).isEqualTo(10240);
-    assertThat(defaultConfig.getExcludedEndpoints()).isEmpty();
+    assertThat(defaultConfig.getUrlFilterExcludePatterns()).isEmpty();
   }
 
   @Test
diff --git a/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java
--- a/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java
+++ b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java
@@ -51,24 +51,27 @@ public class AuditRequestProcessorTest {
   @Mock
   private UriInfo _uriInfo;
 
+  @Mock
+  private AuditUrlPathFilter _auditUrlPathFilter;
+
   private AuditRequestProcessor _processor;
   private AuditConfig _defaultConfig;
 
   @BeforeMethod
   public void setUp() {
     MockitoAnnotations.openMocks(this);
-    _processor = new AuditRequestProcessor(_configManager, mock(AuditIdentityResolver.class));
+    _processor = new AuditRequestProcessor(_configManager, mock(AuditIdentityResolver.class), _auditUrlPathFilter);
 
     _defaultConfig = new AuditConfig();
     _defaultConfig.setEnabled(true);
     _defaultConfig.setCaptureRequestPayload(false);
     _defaultConfig.setCaptureRequestHeaders("");
     _defaultConfig.setMaxPayloadSize(10240);
-    _defaultConfig.setExcludedEndpoints("");
+    _defaultConfig.setUrlFilterExcludePatterns("");
 
     when(_configManager.isEnabled()).thenReturn(true);
     when(_configManager.getCurrentConfig()).thenReturn(_defaultConfig);
-    when(_configManager.isEndpointExcluded(any())).thenReturn(false);
+    when(_auditUrlPathFilter.isExcluded(any(), any())).thenReturn(false);
   }
 
   private MultivaluedMap<String, String> createHeaders(String... headerPairs) {
diff --git a/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditUrlPathFilterTest.java b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditUrlPathFilterTest.java
new file mode 100644
--- /dev/null
+++ b/pinot-common/src/test/java/org/apache/pinot/common/audit/AuditUrlPathFilterTest.java
@@ -0,0 +1,165 @@
+/**
+ * Licensed to the Apache Software Foundation (ASF) under one
+ * or more contributor license agreements.  See the NOTICE file
+ * distributed with this work for additional information
+ * regarding copyright ownership.  The ASF licenses this file
+ * to you under the Apache License, Version 2.0 (the
+ * "License"); you may not use this file except in compliance
+ * with the License.  You may obtain a copy of the License at
+ *
+ *   http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing,
+ * software distributed under the License is distributed on an
+ * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
+ * KIND, either express or implied.  See the License for the
+ * specific language governing permissions and limitations
+ * under the License.
+ */
+package org.apache.pinot.common.audit;
+
+import org.testng.annotations.BeforeMethod;
+import org.testng.annotations.Test;
+
+import static org.assertj.core.api.Assertions.assertThat;
+
+
+/**
+ * Unit tests for {@link AuditUrlPathFilter}.
+ * Tests the filter's delegation to PathMatcher and its input handling logic.
+ */
+public class AuditUrlPathFilterTest {
+
+  private AuditUrlPathFilter _filter;
+
+  @BeforeMethod
+  public void setUp() {
+    _filter = new AuditUrlPathFilter();
+  }
+
+  // ===== Input Validation Tests =====
+
+  @Test
+  public void testNullUrlPath() {
+    assertThat(_filter.isExcluded(null, "health")).isFalse();
+  }
+
+  @Test
+  public void testEmptyUrlPath() {
+    assertThat(_filter.isExcluded("", "health")).isFalse();
+    assertThat(_filter.isExcluded("   ", "health")).isFalse();
+  }
+
+  @Test
+  public void testNullExcludePatterns() {
+    assertThat(_filter.isExcluded("api/users", null)).isFalse();
+  }
+
+  @Test
+  public void testEmptyExcludePatterns() {
+    assertThat(_filter.isExcluded("api/users", "")).isFalse();
+    assertThat(_filter.isExcluded("api/users", "   ")).isFalse();
+  }
+
+  @Test
+  public void testBothParametersBlank() {
+    assertThat(_filter.isExcluded(null, null)).isFalse();
+    assertThat(_filter.isExcluded("", "")).isFalse();
+  }
+
+  // ===== Multiple Pattern Processing Tests =====
+
+  @Test
+  public void testMultiplePatternsCommaSeparated() {
+    String patterns = "health,api/users,admin";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/users", patterns)).isTrue();
+    assertThat(_filter.isExcluded("admin", patterns)).isTrue();
+    assertThat(_filter.isExcluded("metrics", patterns)).isFalse();
+  }
+
+  @Test
+  public void testMultiplePatternsWithTrimmingAndEmptyElements() {
+    String patterns = " health , , api/users , , ";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/users", patterns)).isTrue();
+    assertThat(_filter.isExcluded("metrics", patterns)).isFalse();
+  }
+
+  @Test
+  public void testAnyPatternMatchesReturnsTrue() {
+    String patterns = "nonexistent1,health,nonexistent2";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("nonexistent1", patterns)).isTrue();
+    assertThat(_filter.isExcluded("other", patterns)).isFalse();
+  }
+
+  // ===== Prefix Handling Tests =====
+
+  @Test
+  public void testAutomaticGlobPrefixAddition() {
+    assertThat(_filter.isExcluded("health", "health")).isTrue();
+    assertThat(_filter.isExcluded("api/users", "api/*")).isTrue();
+  }
+
+  @Test
+  public void testExplicitGlobPrefix() {
+    assertThat(_filter.isExcluded("health", "glob:health")).isTrue();
+    assertThat(_filter.isExcluded("api/users", "glob:api/*")).isTrue();
+  }
+
+  @Test
+  public void testExplicitRegexPrefix() {
+    String pattern = "regex:api/v[0-9]+/.*";
+    assertThat(_filter.isExcluded("api/v1/users", pattern)).isTrue();
+    assertThat(_filter.isExcluded("api/v123/anything", pattern)).isTrue();
+    assertThat(_filter.isExcluded("api/va/users", pattern)).isFalse();
+  }
+
+  @Test
+  public void testMixedPrefixes() {
+    String patterns = "glob:health,regex:api/v[0-9]+/.*,admin";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/v1/users", patterns)).isTrue();
+    assertThat(_filter.isExcluded("admin", patterns)).isTrue();
+  }
+
+  // ===== Error Handling Tests =====
+
+  @Test
+  public void testInvalidPatternIsSkipped() {
+    String patterns = "api/v[123,health,{unclosed";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/v1", patterns)).isFalse();
+  }
+
+  @Test
+  public void testInvalidPathHandling() {
+    String invalidPath = "path\0with\0nulls";
+    assertThat(_filter.isExcluded(invalidPath, "health")).isFalse();
+  }
+
+  @Test
+  public void testAllInvalidPatternsReturnFalse() {
+    String patterns = "[unclosed,{unclosed,\\invalid";
+
+    assertThat(_filter.isExcluded("anything", patterns)).isFalse();
+  }
+
+  @Test
+  public void testBasicIntegrationWithPathMatcher() {
+    String patterns = "health,api/*,admin/**";
+
+    assertThat(_filter.isExcluded("health", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/users", patterns)).isTrue();
+    assertThat(_filter.isExcluded("api/v1/users", patterns)).isFalse();
+    assertThat(_filter.isExcluded("admin/config", patterns)).isTrue();
+    assertThat(_filter.isExcluded("admin/config/settings", patterns)).isTrue();
+    assertThat(_filter.isExcluded("metrics", patterns)).isFalse();
+  }
+}
EOF_114329324912

# Set Maven options for test execution
export MAVEN_OPTS="-Xms4g -Xmx4g"
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
export MAVEN_HOME=/opt/maven
export PATH=$MAVEN_HOME/bin:$JAVA_HOME/bin:$PATH

# Run the target tests using Maven
# Execute both test classes in a single command to optimize execution
./mvnw test -pl pinot-common -Dtest=AuditConfigManagerTest,AuditRequestProcessorTest

# Capture exit code
rc=$?

# Echo exit code for test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 278e5d6d6f9a2e20f97cfbe8bf5e1741b0b70005 "pinot-common/src/test/java/org/apache/pinot/common/audit/AuditConfigManagerTest.java" "pinot-common/src/test/java/org/apache/pinot/common/audit/AuditRequestProcessorTest.java"