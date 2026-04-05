#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 9fd42d6c851de3d539e24de0425c1932a73ea866 "impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java b/impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java
--- a/impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java
+++ b/impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java
@@ -58,7 +58,7 @@ public void setup() {
 
     @Test
     void testMainJavaDirectory() {
-        var source = new DefaultSourceRoot(
+        var source = DefaultSourceRoot.fromModel(
                 session, Path.of("myproject"), Source.newBuilder().build());
 
         assertTrue(source.module().isEmpty());
@@ -70,7 +70,7 @@ void testMainJavaDirectory() {
 
     @Test
     void testTestJavaDirectory() {
-        var source = new DefaultSourceRoot(
+        var source = DefaultSourceRoot.fromModel(
                 session, Path.of("myproject"), Source.newBuilder().scope("test").build());
 
         assertTrue(source.module().isEmpty());
@@ -82,7 +82,7 @@ void testTestJavaDirectory() {
 
     @Test
     void testTestResourceDirectory() {
-        var source = new DefaultSourceRoot(
+        var source = DefaultSourceRoot.fromModel(
                 session,
                 Path.of("myproject"),
                 Source.newBuilder().scope("test").lang("resources").build());
@@ -96,7 +96,7 @@ void testTestResourceDirectory() {
 
     @Test
     void testModuleMainDirectory() {
-        var source = new DefaultSourceRoot(
+        var source = DefaultSourceRoot.fromModel(
                 session,
                 Path.of("myproject"),
                 Source.newBuilder().module("org.foo.bar").build());
@@ -110,7 +110,7 @@ void testModuleMainDirectory() {
 
     @Test
     void testModuleTestDirectory() {
-        var source = new DefaultSourceRoot(
+        var source = DefaultSourceRoot.fromModel(
                 session,
                 Path.of("myproject"),
                 Source.newBuilder().module("org.foo.bar").scope("test").build());
EOF_114329324912

# Execute the specific test in the maven-impl module
# Using -pl to target the specific module
# Using -Dtest to run only the DefaultSourceRootTest
# Using -DtrimStackTrace=false for better error reporting
mvn test -pl impl/maven-impl -Dtest=DefaultSourceRootTest -DtrimStackTrace=false

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9fd42d6c851de3d539e24de0425c1932a73ea866 "impl/maven-impl/src/test/java/org/apache/maven/impl/DefaultSourceRootTest.java"