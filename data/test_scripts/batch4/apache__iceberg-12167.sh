#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout eb286de183fd5c78604280f83cf7a807ea75a6b4 \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java b/core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java
--- a/core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java
+++ b/core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java
@@ -24,7 +24,6 @@
 import java.nio.ByteBuffer;
 import java.util.Random;
 import org.apache.iceberg.util.RandomUtil;
-import org.apache.iceberg.variants.Variants.PhysicalType;
 import org.junit.jupiter.api.Test;
 
 public class TestSerializedArray {
diff --git a/core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java b/core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java
--- a/core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java
+++ b/core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java
@@ -29,7 +29,6 @@
 import org.apache.iceberg.relocated.com.google.common.collect.Maps;
 import org.apache.iceberg.relocated.com.google.common.collect.Sets;
 import org.apache.iceberg.util.RandomUtil;
-import org.apache.iceberg.variants.Variants.PhysicalType;
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.params.ParameterizedTest;
 import org.junit.jupiter.params.provider.ValueSource;
@@ -255,12 +254,12 @@ public void testLargeObject(boolean sortFieldNames) {
     VariantMetadata metadata = Variants.metadata(meta);
     SerializedObject object = SerializedObject.from(metadata, value, value.get(0));
 
-    assertThat(object.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(object.type()).isEqualTo(PhysicalType.OBJECT);
     assertThat(object.numFields()).isEqualTo(10_000);
 
     for (Map.Entry<String, VariantPrimitive<String>> entry : fields.entrySet()) {
       VariantValue fieldValue = object.get(entry.getKey());
-      assertThat(fieldValue.type()).isEqualTo(Variants.PhysicalType.STRING);
+      assertThat(fieldValue.type()).isEqualTo(PhysicalType.STRING);
       assertThat(fieldValue.asPrimitive().get()).isEqualTo(entry.getValue().get());
     }
   }
diff --git a/core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java b/core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java
--- a/core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java
+++ b/core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java
@@ -24,7 +24,6 @@
 import java.math.BigDecimal;
 import java.nio.ByteBuffer;
 import org.apache.iceberg.util.DateTimeUtil;
-import org.apache.iceberg.variants.Variants.PhysicalType;
 import org.junit.jupiter.api.Test;
 
 public class TestSerializedPrimitives {
diff --git a/core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java b/core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java
--- a/core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java
+++ b/core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java
@@ -150,7 +150,7 @@ public void testPartiallyShreddedObjectReplacement() {
     assertThat(partial.get("a")).isInstanceOf(VariantPrimitive.class);
     assertThat(partial.get("a").asPrimitive().get()).isEqualTo(34);
     assertThat(partial.get("c")).isInstanceOf(VariantPrimitive.class);
-    assertThat(partial.get("c").type()).isEqualTo(Variants.PhysicalType.DATE);
+    assertThat(partial.get("c").type()).isEqualTo(PhysicalType.DATE);
     assertThat(partial.get("c").asPrimitive().get())
         .isEqualTo(DateTimeUtil.isoDateToDays("2024-10-12"));
   }
@@ -190,7 +190,7 @@ public void testPartiallyShreddedObjectSerializationMinimalBuffer() {
     assertThat(actual.get("a")).isInstanceOf(VariantPrimitive.class);
     assertThat(actual.get("a").asPrimitive().get()).isEqualTo(34);
     assertThat(actual.get("c")).isInstanceOf(VariantPrimitive.class);
-    assertThat(actual.get("c").type()).isEqualTo(Variants.PhysicalType.DATE);
+    assertThat(actual.get("c").type()).isEqualTo(PhysicalType.DATE);
     assertThat(actual.get("c").asPrimitive().get())
         .isEqualTo(DateTimeUtil.isoDateToDays("2024-10-12"));
   }
@@ -212,7 +212,7 @@ public void testPartiallyShreddedObjectSerializationLargeBuffer() {
     assertThat(actual.get("a")).isInstanceOf(VariantPrimitive.class);
     assertThat(actual.get("a").asPrimitive().get()).isEqualTo(34);
     assertThat(actual.get("c")).isInstanceOf(VariantPrimitive.class);
-    assertThat(actual.get("c").type()).isEqualTo(Variants.PhysicalType.DATE);
+    assertThat(actual.get("c").type()).isEqualTo(PhysicalType.DATE);
     assertThat(actual.get("c").asPrimitive().get())
         .isEqualTo(DateTimeUtil.isoDateToDays("2024-10-12"));
   }
@@ -230,17 +230,17 @@ public void testTwoByteOffsets() {
     ShreddedObject shredded = createShreddedObject(data);
     VariantValue value = roundTripLargeBuffer(shredded, shredded.metadata());
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(4);
 
-    assertThat(object.get("a").type()).isEqualTo(Variants.PhysicalType.INT32);
+    assertThat(object.get("a").type()).isEqualTo(PhysicalType.INT32);
     assertThat(object.get("a").asPrimitive().get()).isEqualTo(34);
-    assertThat(object.get("b").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("b").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("b").asPrimitive().get()).isEqualTo("iceberg");
-    assertThat(object.get("c").type()).isEqualTo(Variants.PhysicalType.DECIMAL4);
+    assertThat(object.get("c").type()).isEqualTo(PhysicalType.DECIMAL4);
     assertThat(object.get("c").asPrimitive().get()).isEqualTo(new BigDecimal("12.21"));
-    assertThat(object.get("big").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("big").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("big").asPrimitive().get()).isEqualTo(randomString);
   }
 
@@ -257,17 +257,17 @@ public void testThreeByteOffsets() {
     ShreddedObject shredded = createShreddedObject(data);
     VariantValue value = roundTripLargeBuffer(shredded, shredded.metadata());
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(4);
 
-    assertThat(object.get("a").type()).isEqualTo(Variants.PhysicalType.INT32);
+    assertThat(object.get("a").type()).isEqualTo(PhysicalType.INT32);
     assertThat(object.get("a").asPrimitive().get()).isEqualTo(34);
-    assertThat(object.get("b").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("b").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("b").asPrimitive().get()).isEqualTo("iceberg");
-    assertThat(object.get("c").type()).isEqualTo(Variants.PhysicalType.DECIMAL4);
+    assertThat(object.get("c").type()).isEqualTo(PhysicalType.DECIMAL4);
     assertThat(object.get("c").asPrimitive().get()).isEqualTo(new BigDecimal("12.21"));
-    assertThat(object.get("really-big").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("really-big").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("really-big").asPrimitive().get()).isEqualTo(randomString);
   }
 
@@ -284,17 +284,17 @@ public void testFourByteOffsets() {
     ShreddedObject shredded = createShreddedObject(data);
     VariantValue value = roundTripLargeBuffer(shredded, shredded.metadata());
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(4);
 
-    assertThat(object.get("a").type()).isEqualTo(Variants.PhysicalType.INT32);
+    assertThat(object.get("a").type()).isEqualTo(PhysicalType.INT32);
     assertThat(object.get("a").asPrimitive().get()).isEqualTo(34);
-    assertThat(object.get("b").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("b").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("b").asPrimitive().get()).isEqualTo("iceberg");
-    assertThat(object.get("c").type()).isEqualTo(Variants.PhysicalType.DECIMAL4);
+    assertThat(object.get("c").type()).isEqualTo(PhysicalType.DECIMAL4);
     assertThat(object.get("c").asPrimitive().get()).isEqualTo(new BigDecimal("12.21"));
-    assertThat(object.get("really-big").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("really-big").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("really-big").asPrimitive().get()).isEqualTo(randomString);
   }
 
@@ -315,13 +315,13 @@ public void testLargeObject(boolean sortFieldNames) {
     ShreddedObject shredded = createShreddedObject(metadata, (Map) fields);
     VariantValue value = roundTripLargeBuffer(shredded, metadata);
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(10_000);
 
     for (Map.Entry<String, VariantPrimitive<String>> entry : fields.entrySet()) {
       VariantValue fieldValue = object.get(entry.getKey());
-      assertThat(fieldValue.type()).isEqualTo(Variants.PhysicalType.STRING);
+      assertThat(fieldValue.type()).isEqualTo(PhysicalType.STRING);
       assertThat(fieldValue.asPrimitive().get()).isEqualTo(entry.getValue().get());
     }
   }
@@ -345,15 +345,15 @@ public void testTwoByteFieldIds(boolean sortFieldNames) {
     ShreddedObject shredded = createShreddedObject(metadata, data);
     VariantValue value = roundTripLargeBuffer(shredded, metadata);
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(3);
 
-    assertThat(object.get("aa").type()).isEqualTo(Variants.PhysicalType.INT32);
+    assertThat(object.get("aa").type()).isEqualTo(PhysicalType.INT32);
     assertThat(object.get("aa").asPrimitive().get()).isEqualTo(34);
-    assertThat(object.get("AA").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("AA").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("AA").asPrimitive().get()).isEqualTo("iceberg");
-    assertThat(object.get("ZZ").type()).isEqualTo(Variants.PhysicalType.DECIMAL4);
+    assertThat(object.get("ZZ").type()).isEqualTo(PhysicalType.DECIMAL4);
     assertThat(object.get("ZZ").asPrimitive().get()).isEqualTo(new BigDecimal("12.21"));
   }
 
@@ -376,15 +376,15 @@ public void testThreeByteFieldIds(boolean sortFieldNames) {
     ShreddedObject shredded = createShreddedObject(metadata, data);
     VariantValue value = roundTripLargeBuffer(shredded, metadata);
 
-    assertThat(value.type()).isEqualTo(Variants.PhysicalType.OBJECT);
+    assertThat(value.type()).isEqualTo(PhysicalType.OBJECT);
     SerializedObject object = (SerializedObject) value;
     assertThat(object.numFields()).isEqualTo(3);
 
-    assertThat(object.get("aa").type()).isEqualTo(Variants.PhysicalType.INT32);
+    assertThat(object.get("aa").type()).isEqualTo(PhysicalType.INT32);
     assertThat(object.get("aa").asPrimitive().get()).isEqualTo(34);
-    assertThat(object.get("AA").type()).isEqualTo(Variants.PhysicalType.STRING);
+    assertThat(object.get("AA").type()).isEqualTo(PhysicalType.STRING);
     assertThat(object.get("AA").asPrimitive().get()).isEqualTo("iceberg");
-    assertThat(object.get("ZZ").type()).isEqualTo(Variants.PhysicalType.DECIMAL4);
+    assertThat(object.get("ZZ").type()).isEqualTo(PhysicalType.DECIMAL4);
     assertThat(object.get("ZZ").asPrimitive().get()).isEqualTo(new BigDecimal("12.21"));
   }
 
EOF_114329324912

# Ensure Gradle wrapper is executable
chmod +x ./gradlew

# Run the target tests using Gradle with correct module name
# Using :iceberg-core:test instead of :core:test
# --tests flag to target specific test classes
# --no-daemon to avoid daemon issues in containers
# -DsparkVersions= -DflinkVersions= -DkafkaVersions= to skip unnecessary integration tests
# -Pquick=true for faster execution
# --console=plain for better logging
./gradlew :iceberg-core:test \
    --tests "org.apache.iceberg.variants.TestSerializedArray" \
    --tests "org.apache.iceberg.variants.TestSerializedObject" \
    --tests "org.apache.iceberg.variants.TestSerializedPrimitives" \
    --tests "org.apache.iceberg.variants.TestShreddedObject" \
    --no-daemon \
    --console=plain \
    -DsparkVersions= \
    -DflinkVersions= \
    -DkafkaVersions= \
    -Pquick=true

# Capture exit code
rc=$?

# Echo exit code for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout eb286de183fd5c78604280f83cf7a807ea75a6b4 \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedArray.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedObject.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestSerializedPrimitives.java" \
    "core/src/test/java/org/apache/iceberg/variants/TestShreddedObject.java"