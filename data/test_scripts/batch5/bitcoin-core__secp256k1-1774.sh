#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout b6c2a3cd7752085d46434921238401766c964c01 "src/tests.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/tests.c b/src/tests.c
--- a/src/tests.c
+++ b/src/tests.c
@@ -4315,8 +4315,6 @@ static void test_point_times_order(const secp256k1_gej *point) {
     secp256k1_scalar nx;
     secp256k1_gej res1, res2;
     secp256k1_ge res3;
-    unsigned char pub[65];
-    size_t psize = 65;
     testutil_random_scalar_order_test(&x);
     secp256k1_scalar_negate(&nx, &x);
     secp256k1_ecmult(&res1, point, &x, &x); /* calc res1 = x * point + x * G; */
@@ -4326,9 +4324,6 @@ static void test_point_times_order(const secp256k1_gej *point) {
     secp256k1_ge_set_gej(&res3, &res1);
     CHECK(secp256k1_ge_is_infinity(&res3));
     CHECK(secp256k1_ge_is_valid_var(&res3) == 0);
-    CHECK(secp256k1_eckey_pubkey_serialize(&res3, pub, &psize, 0) == 0);
-    psize = 65;
-    CHECK(secp256k1_eckey_pubkey_serialize(&res3, pub, &psize, 1) == 0);
     /* check zero/one edge cases */
     secp256k1_ecmult(&res1, point, &secp256k1_scalar_zero, &secp256k1_scalar_zero);
     secp256k1_ge_set_gej(&res3, &res1);
@@ -5435,7 +5430,6 @@ static void test_ecmult_accumulate(secp256k1_sha256* acc, const secp256k1_scalar
     secp256k1_gej rj1, rj2, rj3, rj4, rj5, rj6, gj, infj;
     secp256k1_ge r;
     unsigned char bytes[65];
-    size_t size = 65;
     secp256k1_gej_set_ge(&gj, &secp256k1_ge_const_g);
     secp256k1_gej_set_infinity(&infj);
     secp256k1_ecmult_gen(&CTX->ecmult_gen_ctx, &rj1, x);
@@ -5456,9 +5450,8 @@ static void test_ecmult_accumulate(secp256k1_sha256* acc, const secp256k1_scalar
         secp256k1_sha256_write(acc, zerobyte, 1);
     } else {
         /* Store other points using their uncompressed serialization. */
-        secp256k1_eckey_pubkey_serialize(&r, bytes, &size, 0);
-        CHECK(size == 65);
-        secp256k1_sha256_write(acc, bytes, size);
+        secp256k1_eckey_pubkey_serialize65(&r, bytes);
+        secp256k1_sha256_write(acc, bytes, sizeof(bytes));
     }
 }
 
@@ -6543,16 +6536,18 @@ static void test_random_pubkeys(void) {
         size_t size = len;
         firstb = in[0];
         /* If the pubkey can be parsed, it should round-trip... */
-        CHECK(secp256k1_eckey_pubkey_serialize(&elem, out, &size, len == 33));
-        CHECK(size == len);
+        if (len == 33) {
+            secp256k1_eckey_pubkey_serialize33(&elem, out);
+        } else {
+            secp256k1_eckey_pubkey_serialize65(&elem, out);
+        }
         CHECK(secp256k1_memcmp_var(&in[1], &out[1], len-1) == 0);
         /* ... except for the type of hybrid inputs. */
         if ((in[0] != 6) && (in[0] != 7)) {
             CHECK(in[0] == out[0]);
         }
         size = 65;
-        CHECK(secp256k1_eckey_pubkey_serialize(&elem, in, &size, 0));
-        CHECK(size == 65);
+        secp256k1_eckey_pubkey_serialize65(&elem, in);
         CHECK(secp256k1_eckey_pubkey_parse(&elem2, in, size));
         CHECK(secp256k1_ge_eq_var(&elem2, &elem));
         /* Check that the X9.62 hybrid type is checked. */
@@ -6567,7 +6562,7 @@ static void test_random_pubkeys(void) {
         }
         if (res) {
             CHECK(secp256k1_ge_eq_var(&elem, &elem2));
-            CHECK(secp256k1_eckey_pubkey_serialize(&elem, out, &size, 0));
+            secp256k1_eckey_pubkey_serialize65(&elem, out);
             CHECK(secp256k1_memcmp_var(&in[1], &out[1], 64) == 0);
         }
     }
EOF_114329324912

# Rebuild the project to incorporate changes from the patch
# The test file src/tests.c is compiled into the tests binary, so we need to rebuild
make clean
make -j4

# Set environment variables for test execution
export SECP256K1_TEST_ITERS=64
export LC_ALL=C

# Run the tests binary directly (which includes src/tests.c)
# This is more targeted than 'make check' which runs all tests
./tests
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout b6c2a3cd7752085d46434921238401766c964c01 "src/tests.c"