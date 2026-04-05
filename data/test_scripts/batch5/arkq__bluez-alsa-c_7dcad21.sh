#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout c41e84756d5e7b9798a31d41010e9ba3c537e1eb "test/test-dbus.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/test-dbus.c b/test/test-dbus.c
--- a/test/test-dbus.c
+++ b/test/test-dbus.c
@@ -284,6 +284,32 @@ CK_START_TEST(test_g_dbus_get_managed_objects) {
 
 } CK_END_TEST
 
+CK_START_TEST(test_g_dbus_get_properties) {
+
+	FooServer *server;
+	GTestDBusConnection *tc;
+
+	ck_assert_ptr_nonnull((tc = test_dbus_connection_new()));
+	ck_assert_ptr_nonnull((server = dbus_foo_server_new(tc->conn)));
+
+	GError *err = NULL;
+	/* try to get properties on non-existing interface */
+	ck_assert_ptr_null(g_dbus_get_properties(tc->conn,
+			"org.example", "/foo", "org.example.Foo5", &err));
+	ck_assert_int_eq(err->code, G_DBUS_ERROR_INVALID_ARGS);
+	g_error_free(err);
+
+	/* try to get properties on existing interface */
+	GVariantIter *props = g_dbus_get_properties(tc->conn,
+			"org.example", "/foo", "org.example.Foo", NULL);
+	ck_assert_ptr_nonnull(props);
+	g_variant_iter_free(props);
+
+	dbus_foo_server_free(server);
+	test_dbus_connection_free(tc);
+
+} CK_END_TEST
+
 CK_START_TEST(test_g_dbus_get_property) {
 
 	FooServer *server;
@@ -349,6 +375,7 @@ int main(void) {
 	tcase_add_test(tc, test_dbus_dispatch_method_call);
 	tcase_add_test(tc, test_g_dbus_connection_emit_properties_changed);
 	tcase_add_test(tc, test_g_dbus_get_managed_objects);
+	tcase_add_test(tc, test_g_dbus_get_properties);
 	tcase_add_test(tc, test_g_dbus_get_property);
 	tcase_add_test(tc, test_g_dbus_set_property);
 
EOF_114329324912

# Rebuild the test binary after applying the patch
make -C test test-dbus

# Execute the target test
./test/test-dbus
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout c41e84756d5e7b9798a31d41010e9ba3c537e1eb "test/test-dbus.c"