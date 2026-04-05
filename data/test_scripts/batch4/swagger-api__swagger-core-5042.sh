#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 1fcd9196c6f053953126bfaa7288915a0c7f2adf "modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java b/modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java
--- a/modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java
+++ b/modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java
@@ -1,5 +1,6 @@
 package io.swagger.v3.core.converting.override;
 
+import com.fasterxml.jackson.databind.JavaType;
 import com.fasterxml.jackson.databind.ObjectMapper;
 import io.swagger.v3.core.converter.ModelConverters;
 import io.swagger.v3.core.jackson.ModelResolver;
@@ -9,11 +10,9 @@
 import org.apache.commons.lang3.StringUtils;
 import org.testng.annotations.Test;
 
-import java.util.Map;
-import java.util.Set;
+import java.util.*;
 
-import static org.testng.Assert.assertEquals;
-import static org.testng.Assert.assertNotNull;
+import static org.testng.Assert.*;
 
 public class CustomResolverTest {
 
@@ -39,6 +38,37 @@ public void testCustomConverter() {
 
     }
 
+    @Test(description = "it should set the required mode based upon the field type")
+    public void testCustomRequiredModeBasedUponTypeConverter() {
+        // add the custom converter
+        final ModelConverters converters = new ModelConverters();
+        converters.addConverter(new RequiredModeBasedUponFieldTypeResolver(Json.mapper()));
+
+        Map<String, Schema> models = converters.readAll(SuperFoo.class);
+        Schema model = models.get("SuperFoo");
+        assertNotNull(model);
+        assertEquals(model.getProperties().size(), 4);
+        assertEquals(model.getRequired(), (Collections.singletonList("bar")));
+
+        final Schema fooProperty = (Schema) model.getProperties().get("foo");
+        assertEquals(fooProperty.get$ref(), "#/components/schemas/Foo");
+        Schema fooModel = models.get("Foo");
+        assertEquals(fooModel.getRequired(), (Collections.singletonList("bar")));
+
+        final Schema optionalBarProperty = (Schema) model.getProperties().get("optionalBar");
+        assertEquals(optionalBarProperty.get$ref(), "#/components/schemas/Bar");
+        Schema barModel = models.get("Bar");
+        assertNull(barModel.getRequired());
+
+        final Schema barProperty = (Schema) model.getProperties().get("bar");
+        assertEquals(barProperty.get$ref(), "#/components/schemas/Bar");
+        assertNull(barModel.getRequired());
+
+        final Schema titleProperty = (Schema) model.getProperties().get("string");
+        assertNotNull(titleProperty);
+
+    }
+
     class CustomConverter extends ModelResolver {
 
         public CustomConverter(ObjectMapper mapper) {
@@ -60,6 +90,29 @@ protected String nameForClass(Class<?> cls, Set<Options> options) {
         }
     }
 
+    class RequiredModeBasedUponFieldTypeResolver extends ModelResolver {
+
+        public RequiredModeBasedUponFieldTypeResolver(ObjectMapper mapper) {
+            super(mapper);
+        }
+
+        @Override
+        protected io.swagger.v3.oas.annotations.media.Schema.RequiredMode resolveRequiredMode(
+                io.swagger.v3.oas.annotations.media.Schema schema, JavaType type) {
+            if (type.getRawClass().equals(Bar.class)) {
+                return io.swagger.v3.oas.annotations.media.Schema.RequiredMode.REQUIRED;
+            }
+            return super.resolveRequiredMode(schema, type);
+        }
+    }
+
+    class SuperFoo {
+        public Foo foo;
+        public Optional<Bar> optionalBar;
+        public Bar bar;
+        public Optional<String> string;
+    }
+
     class Foo {
         public Bar bar = null;
         public String title = null;
EOF_114329324912

# Execute the specific test using Maven
# Using -pl to specify the module and -Dtest to run only the target test class
mvn test -pl modules/swagger-core -Dtest=CustomResolverTest
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 1fcd9196c6f053953126bfaa7288915a0c7f2adf "modules/swagger-core/src/test/java/io/swagger/v3/core/converting/override/CustomResolverTest.java"