#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 88bde022c066471f6c552dfb95ca45fc4b9e248a "tests/test_bytecode.h"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_bytecode.h b/tests/test_bytecode.h
--- a/tests/test_bytecode.h
+++ b/tests/test_bytecode.h
@@ -183,16 +183,16 @@ inline void test_script_binary(const String &script_name, const Vector<uint8_t>
 	CHECK(fake_script->get_error_message() == "");
 	CHECK(fake_script->get_override_bytecode_revision() == revision);
 
-	if (decomp->get_bytecode_version() <= GDScriptDecomp::GDSCRIPT_2_0_VERSION) {
-		auto tokenizer = GDScriptTokenizerBufferCompat(decomp.ptr());
-		tokenizer.set_code_buffer(bytecode);
-		auto token = tokenizer.scan();
-		while (token.type != GDScriptDecomp::G_TK_EOF) {
-			print_line(vformat("Token: '%s', Line: %d, Column: %d, Indent: %d, Function: %s, Error: %s", GDScriptTokenizerBufferCompat::get_token_name(token.type), token.line, token.col, token.current_indent, token.func_name, token.error));
-			token = tokenizer.scan();
-		}
-		bool thignas = false;
-	}
+	// if (decomp->get_bytecode_version() <= GDScriptDecomp::GDSCRIPT_2_0_VERSION) {
+	// 	auto tokenizer = GDScriptTokenizerBufferCompat(decomp.ptr());
+	// 	tokenizer.set_code_buffer(bytecode);
+	// 	auto token = tokenizer.scan();
+	// 	while (token.type != GDScriptDecomp::G_TK_EOF) {
+	// 		print_line(vformat("Token: '%s', Line: %d, Column: %d, Indent: %d, Function: %s, Error: %s", GDScriptTokenizerBufferCompat::get_token_name(token.type), token.line, token.col, token.current_indent, token.func_name, token.error));
+	// 		token = tokenizer.scan();
+	// 	}
+	// 	bool thignas = false;
+	// }
 }
 
 inline void test_script_text(const String &script_name, const String &helper_script_text, int revision, bool helper_script, bool no_text_equality_check, bool compare_whitespace = false) {
EOF_114329324912

# Copy the modified test file to the Godot modules directory
cp -f /testbed/tests/test_bytecode.h /godot/modules/gdsdecomp/tests/test_bytecode.h

# Navigate to Godot directory
cd /godot

# Set up environment variables for Rust and .NET
export PATH="/root/.cargo/bin:/root/.dotnet:${PATH}"
export DOTNET_ROOT="/root/.dotnet"

# Rebuild Godot with the updated test file
# This is necessary because tests are compiled into the Godot binary
scons platform=linuxbsd target=editor tests=yes module_gdsdecomp_enabled=yes -j$(nproc)

# Execute the bytecode tests using xvfb-run for headless execution
# Using the specific test-case filter to run only bytecode-related tests
xvfb-run ./bin/godot.linuxbsd.editor.x86_64 --headless --test --test-case="*bytecode*"

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
cd /testbed
git checkout 88bde022c066471f6c552dfb95ca45fc4b9e248a "tests/test_bytecode.h"