#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Fix git ownership warning
git config --global --add safe.directory /testbed

# Checkout the original test file to ensure clean state
git checkout 5c9c305dbfd6dff3ecdf06da8bce3ac623757756 "tests/test_link_extractor.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_link_extractor.py b/tests/test_link_extractor.py
--- a/tests/test_link_extractor.py
+++ b/tests/test_link_extractor.py
@@ -5,7 +5,7 @@
 
 from crawl4ai.models import Link
 from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
-from crawl4ai.async_configs import LinkExtractionConfig
+from crawl4ai.async_configs import LinkPreviewConfig
 import asyncio
 import sys
 import os
@@ -22,7 +22,7 @@ async def test_link_extractor():
 
     # Test configuration with link extraction AND scoring enabled
     config = CrawlerRunConfig(
-        link_extraction_config=LinkExtractionConfig(
+        link_preview_config=LinkPreviewConfig(
             include_internal=True,
             include_external=False,  # Only internal links for this test
             # No include/exclude patterns for first test - let's see what we get
@@ -53,7 +53,7 @@ async def test_link_extractor():
                 result = await crawler.arun(url, config=config)
                 
                 # Debug: Check if link extraction config is being passed
-                print(f"🔍 Debug - Link extraction config: {config.link_extraction_config.to_dict() if config.link_extraction_config else None}")
+                print(f"🔍 Debug - Link extraction config: {config.link_preview_config.to_dict() if config.link_preview_config else None}")
                 print(f"🔍 Debug - Score links: {config.score_links}")
 
                 if result.success:
@@ -187,7 +187,7 @@ def test_config_examples():
     examples = [
         {
             "name": "BM25 Scored Documentation Links",
-            "config": LinkExtractionConfig(
+            "config": LinkPreviewConfig(
                 include_internal=True,
                 include_external=False,
                 include_patterns=["*/docs/*", "*/api/*", "*/reference/*"],
@@ -199,7 +199,7 @@ def test_config_examples():
         },
         {
             "name": "Internal Links Only",
-            "config": LinkExtractionConfig(
+            "config": LinkPreviewConfig(
                 include_internal=True,
                 include_external=False,
                 max_links=50,
@@ -208,7 +208,7 @@ def test_config_examples():
         },
         {
             "name": "External Links with Patterns",
-            "config": LinkExtractionConfig(
+            "config": LinkPreviewConfig(
                 include_internal=False,
                 include_external=True,
                 include_patterns=["*github.com*", "*stackoverflow.com*"],
@@ -218,7 +218,7 @@ def test_config_examples():
         },
         {
             "name": "High-Performance Mode",
-            "config": LinkExtractionConfig(
+            "config": LinkPreviewConfig(
                 include_internal=True,
                 include_external=False,
                 concurrency=20,
@@ -237,9 +237,9 @@ def test_config_examples():
             print(f"     {key}: {value}")
 
         print("   Usage:")
-        print("     from crawl4ai.async_configs import LinkExtractionConfig")
+        print("     from crawl4ai.async_configs import LinkPreviewConfig")
         print("     config = CrawlerRunConfig(")
-        print("         link_extraction_config=LinkExtractionConfig(")
+        print("         link_preview_config=LinkPreviewConfig(")
         for key, value in config_dict.items():
             if isinstance(value, str):
                 print(f"             {key}='{value}',")
EOF_114329324912

# Run the target test file with pytest
# Using -v for verbose output, single-process mode for stability
# --asyncio-mode=auto enables pytest-asyncio to handle async test functions
pytest tests/test_link_extractor.py -v --tb=short --no-header -rA --asyncio-mode=auto

# Capture exit code
rc=$?

# Echo exit code for judge evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 5c9c305dbfd6dff3ecdf06da8bce3ac623757756 "tests/test_link_extractor.py"