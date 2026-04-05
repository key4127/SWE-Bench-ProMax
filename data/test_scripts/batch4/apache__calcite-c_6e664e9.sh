#!/bin/bash
set -uxo pipefail

# Set working directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 47d096d26e087ed3385407450a9c8e89558910ad "core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/core/src/test/java/org/apache/calcite/rel/RelRootTest.java b/core/src/test/java/org/apache/calcite/rel/RelRootTest.java
new file mode 100644
--- /dev/null
+++ b/core/src/test/java/org/apache/calcite/rel/RelRootTest.java
@@ -0,0 +1,122 @@
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
+package org.apache.calcite.rel;
+
+import org.apache.calcite.rel.logical.LogicalProject;
+import org.apache.calcite.rel.type.RelDataTypeField;
+import org.apache.calcite.rel.type.RelDataTypeFieldImpl;
+import org.apache.calcite.rel.type.RelRecordType;
+import org.apache.calcite.schema.SchemaPlus;
+import org.apache.calcite.sql.SqlKind;
+import org.apache.calcite.test.CalciteAssert;
+import org.apache.calcite.test.RelBuilderTest;
+import org.apache.calcite.tools.FrameworkConfig;
+import org.apache.calcite.tools.Frameworks;
+import org.apache.calcite.tools.RelBuilder;
+
+import org.junit.jupiter.api.Test;
+
+import java.util.Collections;
+import java.util.List;
+
+import static org.hamcrest.CoreMatchers.equalTo;
+import static org.hamcrest.CoreMatchers.instanceOf;
+import static org.hamcrest.CoreMatchers.is;
+import static org.hamcrest.CoreMatchers.not;
+import static org.hamcrest.MatcherAssert.assertThat;
+
+/**
+ * Tests for {@link RelRoot}.
+ */
+public class RelRootTest {
+  /** Test case for
+   * <a href="https://issues.apache.org/jira/browse/CALCITE-6877">[CALCITE-6877]
+   * Generate LogicalProject in RelRoot.project() when mapping is not name trivial</a>. */
+  @Test void testRelRootProjectForceNonNameTrivial() {
+    final SchemaPlus rootSchema = Frameworks.createRootSchema(true);
+    final SchemaPlus defaultSchema =
+        CalciteAssert.addSchema(rootSchema, CalciteAssert.SchemaSpec.HR);
+    final FrameworkConfig frameworkConfig = RelBuilderTest.config()
+        .defaultSchema(defaultSchema)
+        .build();
+    final RelBuilder relBuilder = RelBuilder.create(frameworkConfig);
+    final RelNode inputRel = relBuilder.scan("emps")
+        .project(relBuilder.fields(Collections.singletonList("empid"))).build();
+
+    final List<RelDataTypeField> fields =
+        Collections.singletonList(
+            // rename empid to empno via RelRoot
+            new RelDataTypeFieldImpl("empno",
+                inputRel.getRowType().getFieldList().get(0).getIndex(),
+                inputRel.getRowType().getFieldList().get(0).getType()));
+
+    final RelRoot root = RelRoot.of(inputRel, new RelRecordType(fields), SqlKind.SELECT);
+
+    // inner LogicalProject selects one field and RelRoot only has one field
+    assertThat(root.isRefTrivial(), is(true));
+
+    // inner LogicalProject has different field name than RelRoot
+    assertThat(root.isNameTrivial(), is(false));
+
+    final RelNode project = root.project();
+    assertThat(project, equalTo(inputRel));
+
+    // regular project() and force project() are different
+    final RelNode forceProject = root.project(true);
+    assertThat(forceProject, not(equalTo(project)));
+
+    // new LogicalProject on top of inputRel
+    assertThat(forceProject, instanceOf(LogicalProject.class));
+    assertThat(forceProject.getInput(0), equalTo(inputRel));
+
+    // new LogicalProject renames field
+    if (forceProject instanceof LogicalProject) {
+      assertThat(((LogicalProject) forceProject).getNamedProjects().get(0).getValue(),
+          equalTo("empno"));
+    }
+  }
+
+  /** Test case for
+   * <a href="https://issues.apache.org/jira/browse/CALCITE-6877">[CALCITE-6877]
+   * Generate LogicalProject in RelRoot.project() when mapping is not name trivial</a>. */
+  @Test void testRelRootProjectForceNameTrivial() {
+    final SchemaPlus rootSchema = Frameworks.createRootSchema(true);
+    final SchemaPlus defaultSchema =
+        CalciteAssert.addSchema(rootSchema, CalciteAssert.SchemaSpec.HR);
+    final FrameworkConfig frameworkConfig = RelBuilderTest.config()
+        .defaultSchema(defaultSchema)
+        .build();
+    final RelBuilder relBuilder = RelBuilder.create(frameworkConfig);
+    final RelNode inputRel = relBuilder.scan("emps")
+        .project(relBuilder.fields(Collections.singletonList("empid"))).build();
+
+    final RelRoot root = RelRoot.of(inputRel, SqlKind.SELECT);
+
+    // inner LogicalProject selects one field and RelRoot only has one field
+    assertThat(root.isRefTrivial(), is(true));
+
+    // inner LogicalProject has same field name as RelRoot
+    assertThat(root.isNameTrivial(), is(true));
+
+    final RelNode project = root.project();
+    assertThat(project, equalTo(inputRel));
+
+    // regular project() and force project() are the same
+    final RelNode forceProject = root.project(true);
+    assertThat(forceProject, equalTo(project));
+  }
+}
diff --git a/core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java b/core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java
--- a/core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java
+++ b/core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java
@@ -27,14 +27,12 @@
 import org.apache.calcite.rel.RelFieldCollation.Direction;
 import org.apache.calcite.rel.RelFieldCollation.NullDirection;
 import org.apache.calcite.rel.RelNode;
-import org.apache.calcite.rel.RelRoot;
 import org.apache.calcite.rel.core.JoinRelType;
 import org.apache.calcite.rel.hint.HintPredicates;
 import org.apache.calcite.rel.hint.HintStrategyTable;
 import org.apache.calcite.rel.hint.RelHint;
 import org.apache.calcite.rel.logical.LogicalAggregate;
 import org.apache.calcite.rel.logical.LogicalFilter;
-import org.apache.calcite.rel.logical.LogicalProject;
 import org.apache.calcite.rel.rules.AggregateJoinTransposeRule;
 import org.apache.calcite.rel.rules.AggregateProjectMergeRule;
 import org.apache.calcite.rel.rules.CoreRules;
@@ -44,18 +42,14 @@
 import org.apache.calcite.rel.rules.PruneEmptyRules;
 import org.apache.calcite.rel.type.RelDataType;
 import org.apache.calcite.rel.type.RelDataTypeFactory;
-import org.apache.calcite.rel.type.RelDataTypeField;
-import org.apache.calcite.rel.type.RelDataTypeFieldImpl;
 import org.apache.calcite.rel.type.RelDataTypeSystem;
 import org.apache.calcite.rel.type.RelDataTypeSystemImpl;
-import org.apache.calcite.rel.type.RelRecordType;
 import org.apache.calcite.runtime.FlatLists;
 import org.apache.calcite.runtime.Hook;
 import org.apache.calcite.schema.SchemaPlus;
 import org.apache.calcite.sql.SqlCall;
 import org.apache.calcite.sql.SqlDialect;
 import org.apache.calcite.sql.SqlDialect.DatabaseProduct;
-import org.apache.calcite.sql.SqlKind;
 import org.apache.calcite.sql.SqlNode;
 import org.apache.calcite.sql.SqlSelect;
 import org.apache.calcite.sql.SqlWriter;
@@ -106,7 +100,6 @@
 
 import java.math.BigDecimal;
 import java.util.Collection;
-import java.util.Collections;
 import java.util.List;
 import java.util.Map;
 import java.util.Set;
@@ -122,10 +115,7 @@
 import static org.hamcrest.CoreMatchers.notNullValue;
 import static org.hamcrest.MatcherAssert.assertThat;
 import static org.hamcrest.Matchers.hasToString;
-import static org.junit.jupiter.api.Assertions.assertEquals;
 import static org.junit.jupiter.api.Assertions.assertFalse;
-import static org.junit.jupiter.api.Assertions.assertInstanceOf;
-import static org.junit.jupiter.api.Assertions.assertNotEquals;
 import static org.junit.jupiter.api.Assertions.assertTrue;
 
 /**
@@ -9798,84 +9788,6 @@ private void checkLiteral2(String expression, String expected) {
     sql(sql).ok(expected);
   }
 
-
-  /** Test case for
-   * <a href="https://issues.apache.org/jira/browse/CALCITE-6877">[CALCITE-6877]
-   * Generate LogicalProject in RelRoot.project() when mapping is not name trivial</a>. */
-  @Test void testRelRootProjectForceNonNameTrivial() {
-    final SchemaPlus rootSchema = Frameworks.createRootSchema(true);
-    final SchemaPlus defaultSchema =
-        CalciteAssert.addSchema(rootSchema, CalciteAssert.SchemaSpec.HR);
-    final FrameworkConfig frameworkConfig = RelBuilderTest.config()
-        .defaultSchema(defaultSchema)
-        .build();
-    final RelBuilder relBuilder = RelBuilder.create(frameworkConfig);
-    final RelNode inputRel = relBuilder.scan("emps")
-        .project(relBuilder.fields(Collections.singletonList("empid"))).build();
-
-    final List<RelDataTypeField> fields =
-        Collections.singletonList(
-            // rename empid to empno via RelRoot
-            new RelDataTypeFieldImpl("empno",
-                inputRel.getRowType().getFieldList().get(0).getIndex(),
-                inputRel.getRowType().getFieldList().get(0).getType()));
-
-    final RelRoot root = RelRoot.of(inputRel, new RelRecordType(fields), SqlKind.SELECT);
-
-    // inner LogicalProject selects one field and RelRoot only has one field
-    assertTrue(root.isRefTrivial());
-
-    // inner LogicalProject has different field name than RelRoot
-    assertFalse(root.isNameTrivial());
-
-    final RelNode project = root.project();
-    assertEquals(inputRel, project);
-
-    // regular project() and force project() are different
-    final RelNode forceProject = root.project(true);
-    assertNotEquals(project, forceProject);
-
-    // new LogicalProject on top of inputRel
-    assertInstanceOf(LogicalProject.class, forceProject);
-    assertEquals(inputRel, forceProject.getInput(0));
-
-    // new LogicalProject renames field
-    if (forceProject instanceof LogicalProject) {
-      assertEquals("empno",
-          ((LogicalProject) forceProject).getNamedProjects().get(0).getValue());
-    }
-  }
-
-  /** Test case for
-   * <a href="https://issues.apache.org/jira/browse/CALCITE-6877">[CALCITE-6877]
-   * Generate LogicalProject in RelRoot.project() when mapping is not name trivial</a>. */
-  @Test void testRelRootProjectForceNameTrivial() {
-    final SchemaPlus rootSchema = Frameworks.createRootSchema(true);
-    final SchemaPlus defaultSchema =
-        CalciteAssert.addSchema(rootSchema, CalciteAssert.SchemaSpec.HR);
-    final FrameworkConfig frameworkConfig = RelBuilderTest.config()
-        .defaultSchema(defaultSchema)
-        .build();
-    final RelBuilder relBuilder = RelBuilder.create(frameworkConfig);
-    final RelNode inputRel = relBuilder.scan("emps")
-        .project(relBuilder.fields(Collections.singletonList("empid"))).build();
-
-    final RelRoot root = RelRoot.of(inputRel, SqlKind.SELECT);
-
-    // inner LogicalProject selects one field and RelRoot only has one field
-    assertTrue(root.isRefTrivial());
-
-    // inner LogicalProject has same field name as RelRoot
-    assertTrue(root.isNameTrivial());
-
-    final RelNode project = root.project();
-    assertEquals(inputRel, project);
-
-    // regular project() and force project() are the same
-    final RelNode forceProject = root.project(true);
-    assertEquals(project, forceProject);
-  }
-
   /** Test case for
    * <a href="https://issues.apache.org/jira/browse/CALCITE-6825">[CALCITE-6825]
    * Add support for ALL, SOME, ANY in RelToSqlConverter</a>. */
EOF_114329324912

# Set environment variables for test execution
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH
export GRADLE_OPTS="-XX:+UseG1GC -Xmx2g -XX:MaxMetaspaceSize=512m -Djdk.net.URLClassPath.disableClassPathURLCheck=true -Djava.security.manager=allow"
export JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Djava.security.manager=allow"

# Execute the target test using Gradle
# Using --no-daemon to avoid daemon-related issues in containerized environment
# Using --max-workers=4 to limit parallelism as per requirements
./gradlew :core:test --tests "org.apache.calcite.rel.rel2sql.RelToSqlConverterTest" \
    --no-daemon \
    --max-workers=4 \
    -Duser.language=TR \
    -Duser.country=tr \
    -Duser.timezone=UTC \
    -Djava.awt.headless=true \
    -Djunit.jupiter.execution.parallel.enabled=true \
    -Djunit.jupiter.execution.parallel.mode.default=concurrent \
    -Djunit.jupiter.execution.timeout.default="5 m"

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 47d096d26e087ed3385407450a9c8e89558910ad "core/src/test/java/org/apache/calcite/rel/rel2sql/RelToSqlConverterTest.java"