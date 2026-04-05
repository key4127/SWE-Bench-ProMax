#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 989de088ec91077a773160679e7190092f140b38 "tests/adapters/test_audio.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/adapters/test_audio.py b/tests/adapters/test_audio.py
new file mode 100644
--- /dev/null
+++ b/tests/adapters/test_audio.py
@@ -0,0 +1,32 @@
+import pytest
+
+from dspy.adapters.types.audio import _normalize_audio_format
+
+
+@pytest.mark.parametrize(
+    "input_format, expected_format",
+    [
+        # Case 1: Standard format (no change)
+        ("wav", "wav"),
+        ("mp3", "mp3"),
+
+        # Case 2: The 'x-' prefix
+        ("x-wav", "wav"),
+        ("x-mp3", "mp3"),
+        ("x-flac", "flac"),
+
+        # Case 3: The edge case
+        ("my-x-format", "my-x-format"),
+        ("x-my-format", "my-format"),
+
+        # Case 4: Empty string and edge cases
+        ("", ""),
+        ("x-", ""),
+    ],
+)
+def test_normalize_audio_format(input_format, expected_format):
+    """
+    Tests that the _normalize_audio_format helper correctly removes 'x-' prefixes.
+    This single test covers the logic for from_url, from_file, and encode_audio.
+    """
+    assert _normalize_audio_format(input_format) == expected_format
EOF_114329324912

# Run target test file with pytest
# Using -xvs flags for better output and single-process mode for safety
# -x: stop on first failure
# -v: verbose output
# -s: no output capture (show print statements)
# --tb=short: shorter traceback format
pytest -xvs --tb=short tests/adapters/test_audio.py

# Capture exit code
rc=$?

# Required: echo test status for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 989de088ec91077a773160679e7190092f140b38 "tests/adapters/test_audio.py"

# Exit with the test result code
exit $rc