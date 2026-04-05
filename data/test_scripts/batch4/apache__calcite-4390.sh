#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 988caace5c423c2c98f60e3beeee6d0e660d3111 "core/src/test/java/org/apache/calcite/model/ModelHandlerTest.java" "core/src/test/resources/hsqldb-scott.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/core/src/test/java/org/apache/calcite/model/ModelHandlerTest.java b/core/src/test/java/org/apache/calcite/model/ModelHandlerTest.java
new file mode 100644
--- /dev/null
+++ b/core/src/test/java/org/apache/calcite/model/ModelHandlerTest.java
@@ -0,0 +1,59 @@
+/*
+ * Licensed to the Apache Software Foundation (ASF) under one or more
+ * contributor license agreements.  See the NOTICE file distributed with
+ * this work for additional information regarding copyright ownership.
+ * The ASF licenses this file to you under the Apache License, Version 2.0
+ * (the "License"); you may not use this file except in compliance with
+ * the License.  You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+package org.apache.calcite.model;
+
+import org.apache.calcite.jdbc.CalciteSchema;
+import org.apache.calcite.schema.SchemaPlus;
+import org.apache.calcite.schema.lookup.LikePattern;
+import org.apache.calcite.util.Sources;
+
+import com.google.common.collect.ImmutableSet;
+
+import org.junit.jupiter.api.Test;
+
+import java.io.IOException;
+import java.util.Set;
+
+import static org.hamcrest.CoreMatchers.is;
+import static org.hamcrest.MatcherAssert.assertThat;
+
+import static java.util.Objects.requireNonNull;
+
+/**
+ * Unit test for {@link ModelHandler}.
+ */
+public class ModelHandlerTest {
+
+  /** Test case for
+   * <a href="https://issues.apache.org/jira/browse/CALCITE-7022">[CALCITE-7022]
+   * Decouple ModelHandler from CalciteConnection</a>.
+   * The test ensures/demonstrates that a Schema can be easily parsed/created from a model
+   * file (JSON/YAML) without necessitating the creation of complex/heavy objects
+   * (e.g., CalciteConnection). */
+  @Test void testPopulateRootSchemaFromURL() throws IOException {
+    SchemaPlus root = CalciteSchema.createRootSchema(false, false).plus();
+    String mURI =
+        Sources.of(requireNonNull(ModelHandlerTest.class.getResource("/hsqldb-scott.json")))
+            .path();
+    ModelHandler h = new ModelHandler(root, mURI);
+    SchemaPlus scott = root.subSchemas().get("SCOTT");
+    Set<String> tables = scott.tables().getNames(new LikePattern("%"));
+    assertThat(tables, is(ImmutableSet.of("EMP", "DEPT", "BONUS", "SALGRADE")));
+    assertThat(h.defaultSchemaName(), is("SCOTT"));
+  }
+
+}
diff --git a/core/src/test/resources/hsqldb-scott.json b/core/src/test/resources/hsqldb-scott.json
new file mode 100644
--- /dev/null
+++ b/core/src/test/resources/hsqldb-scott.json
@@ -0,0 +1,28 @@
+/*
+ * Licensed to the Apache Software Foundation (ASF) under one or more
+ * contributor license agreements.  See the NOTICE file distributed with
+ * this work for additional information regarding copyright ownership.
+ * The ASF licenses this file to you under the Apache License, Version 2.0
+ * (the "License"); you may not use this file except in compliance with
+ * the License.  You may obtain a copy of the License at
+ *
+ * http://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+{
+  "version": "1.0",
+  "defaultSchema": "SCOTT",
+  "schemas": [ {
+    "type": "jdbc",
+    "name": "SCOTT",
+    "jdbcUser": "SA",
+    "jdbcPassword": "",
+    "jdbcUrl": "jdbc:hsqldb:res:scott",
+    "jdbcSchema": "SCOTT"
+  } ]
+}
EOF_114329324912

# Set environment variables for test execution
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export GRADLE_OPTS="-XX:+UseG1GC -Xmx2g -XX:MaxMetaspaceSize=512m -Djdk.net.URLClassPath.disableClassPathURLCheck=true"
export JAVA_TOOL_OPTIONS="-Djava.awt.headless=true"

# Execute the target test using Gradle
# Using --no-daemon to avoid daemon-related issues in containerized environment
# Using --max-workers=4 to limit parallelism as per requirements
./gradlew :core:test --tests "org.apache.calcite.model.ModelHandlerTest" \
    --no-daemon \
    --max-workers=4 \
    -Duser.language=TR \
    -Duser.country=tr \
    -Duser.timezone=UTC \
    -Djava.awt.headless=true \
    -Djunit.jupiter.execution.parallel.enabled=true \
    -Djunit.jupiter.execution.timeout.default="5 m"

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 988caace5c423c2c98f60e3beeee6d0e660d3111 "core/src/test/java/org/apache/calcite/model/ModelHandlerTest.java" "core/src/test/resources/hsqldb-scott.json"