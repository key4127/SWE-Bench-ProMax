#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset target test file to original state
git checkout dfaaa0afccd0844493345c6ab22c7be9ab2c4912 "test/unit/test_codemeta.c"

# Apply test patch to update target test
git apply -v - <<'EOF_114329324912'
diff --git a/test/unit/test_codemeta.c b/test/unit/test_codemeta.c
--- a/test/unit/test_codemeta.c
+++ b/test/unit/test_codemeta.c
@@ -323,13 +323,10 @@ static bool test_r_codemeta_print(void) {
 			       "    sym.imp.puts(\"Hello, World!\");\n"
 			       "    return;\n"
 			       "}\n";
-	RCons *cons = r_cons_new ();
-	r_kons_push (cons);
-	r_codemeta_print (code, NULL);
-	actual = strdup (r_cons_get_buffer ());
-	r_kons_pop (cons);
+	
+	actual = r_codemeta_print (code, NULL);
 	mu_assert_streq (actual, expected_first, "pdg OUTPUT DOES NOT MATCH");
-	r_kons_pop (cons);
+	free (actual);
 
 	//Checking with offset - pdgo
 	RVector *offsets = r_codemeta_line_offsets (code);
@@ -339,15 +336,10 @@ static bool test_r_codemeta_print(void) {
 				"    0x00001158    |    sym.imp.puts(\"Hello, World!\");\n"
 				"    0x0000115f    |    return;\n"
 				"                  |}\n";
-	r_codemeta_print (code, offsets);
-	free (actual);
-	actual = strdup (r_cons_get_buffer ());
-	r_kons_pop (cons);
+	actual = r_codemeta_print (code, offsets);
 	mu_assert_streq (actual, expected_second, "pdgo OUTPUT DOES NOT MATCH");
-	r_kons_pop (cons);
-
-	r_kons_free (cons);
 	free (actual);
+
 	r_vector_free (offsets);
 	r_codemeta_free (code);
 	mu_end;
@@ -358,14 +350,10 @@ static bool test_r_codemeta_print_comment_cmds(void) {
 	char *actual;
 	char *expected = "CCu base64:c3ltLmltcC5wdXRzKCJIZWxsbywgV29ybGQhIik= @ 0x1158\n"
 			 "CCu base64:cmV0dXJu @ 0x115f\n";
-	RCons *cons = r_cons_new ();
-	r_kons_push (cons);
-	r_codemeta_print_comment_cmds (code);
-	actual = strdup (r_cons_get_buffer ());
-	r_kons_pop (cons);
+	
+	actual = r_codemeta_print_comment_cmds (code);
 	mu_assert_streq (actual, expected, "pdg* OUTPUT DOES NOT MATCH");
 
-	r_kons_free (cons);
 	free (actual);
 	r_codemeta_free (code);
 	mu_end;
EOF_114329324912

# Set environment variables for proper library discovery
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}

# Check if meson build directory exists and tests are available
if [ -d "build" ]; then
    # List available tests to verify codemeta test exists
    echo "Available tests:"
    meson test -C build --list
    
    # Run the specific codemeta test using meson test system
    echo "Running codemeta test:"
    meson test -C build codemeta --verbose
    rc=$?
else
    echo "ERROR: Meson build directory not found"
    echo "Available build directories:"
    ls -la
    rc=1
fi

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout dfaaa0afccd0844493345c6ab22c7be9ab2c4912 "test/unit/test_codemeta.c"