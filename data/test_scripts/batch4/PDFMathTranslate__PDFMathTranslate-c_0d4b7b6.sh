#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 96f95030209b9e8eb7f5f8eccd44f7b064e58389 "test/test_translator.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/test_translator.py b/test/test_translator.py
--- a/test/test_translator.py
+++ b/test/test_translator.py
@@ -1,8 +1,13 @@
 import unittest
-from pdf2zh.translator import BaseTranslator
-from pdf2zh.translator import OpenAIlikedTranslator
+from unittest import mock
+
 from pdf2zh import cache
 from pdf2zh.config import ConfigManager
+from pdf2zh.translator import BaseTranslator, OllamaTranslator, OpenAIlikedTranslator
+
+# Since it is necessary to test whether the functionality meets the expected requirements,
+# private functions and private methods are allowed to be called.
+# pyright: reportPrivateUsage=false
 
 
 class AutoIncreaseTranslator(BaseTranslator):
@@ -144,5 +149,29 @@ def test_default_api_key_fallback(self):
         self.assertEqual(translator.envs["OPENAILIKED_API_KEY"], None)
 
 
+class TestOllamaTranslator(unittest.TestCase):
+    def setUp(self) -> None:
+        self.mock_translator = mock.MagicMock()
+
+    def test_do_translate(self):
+        self.mock_translator.do_translate(text="The sky appears blue because of...")
+        self.mock_translator.do_translate.return_value = "天空呈现蓝色是因为..."
+        self.mock_translator.do_translate.assert_called_once()
+
+    def test_remove_cot_content(self):
+        fake_cot_resp_text = """<think>
+
+        </think>
+
+        The sky appears blue because...
+        """
+        removed_cot_content = OllamaTranslator._remove_cot_content(fake_cot_resp_text)
+        excepted_content = "The sky appears blue because..."
+        self.assertEqual(excepted_content, removed_cot_content.strip())
+
+        non_cot_content = OllamaTranslator._remove_cot_content(excepted_content)
+        self.assertEqual(excepted_content, non_cot_content)
+
+
 if __name__ == "__main__":
     unittest.main()
EOF_114329324912

# Ensure PYTHONPATH is set correctly
export PYTHONPATH=/testbed:$PYTHONPATH

# Run the target test file using unittest as specified in the collected information
python -m unittest test.test_translator
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 96f95030209b9e8eb7f5f8eccd44f7b064e58389 "test/test_translator.py"