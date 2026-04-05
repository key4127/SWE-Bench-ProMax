#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit
git checkout 158ba1b95a9a0de49bc815b253595fd4b96f4fa8

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/results/leakgallery.py b/test/results/leakgallery.py
new file mode 100644
--- /dev/null
+++ b/test/results/leakgallery.py
@@ -0,0 +1,47 @@
+# -*- coding: utf-8 -*-
+
+# This program is free software; you can redistribute it and/or modify
+# it under the terms of the GNU General Public License version 2 as
+# published by the Free Software Foundation.
+
+from gallery_dl.extractor import leakgallery
+FILE_PATTERN = r"https://cdn.leakgallery.com/content(-videos|\d+)?/[\w.-]+\.\w+"
+
+
+__tests__ = (
+{
+    "#url"    : "https://leakgallery.com/sophieraiin/12240",
+    "#class"  : leakgallery.LeakgalleryPostExtractor,
+    "#results": "https://cdn.leakgallery.com/content-videos/watermark_745_sophieraiin_241.mp4",
+
+    "id"     : "12240",
+    "creator": "sophieraiin",
+},
+
+{
+    "#url"    : "https://leakgallery.com/sophieraiin",
+    "#class"  : leakgallery.LeakgalleryUserExtractor,
+    "#pattern": r"https://cdn.leakgallery.com/content3/(compressed_)?watermark_[0-9a-f]+_sophieraiin_\w+\.(jpg|png|mp4|mov)",
+    "#range"  : "1-100",
+    "#count"  : 100,
+
+    "creator": "sophieraiin",
+},
+
+{
+    "#url"    : "https://leakgallery.com/trending-medias/Week",
+    "#class"  : leakgallery.LeakgalleryTrendingExtractor,
+    "#pattern": FILE_PATTERN,
+    "#range"  : "1-100",
+    "#count"  : 100,
+},
+
+{
+    "#url"    : "https://leakgallery.com/most-liked",
+    "#class"  : leakgallery.LeakgalleryMostlikedExtractor,
+    "#pattern": FILE_PATTERN,
+    "#range"  : "1-100",
+    "#count"  : 100,
+},
+
+)
EOF_114329324912

# Run tests using the repository's custom test runner script
# This is the primary test execution method for gallery-dl
python3 scripts/run_tests.py
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes made by the patch
git checkout 158ba1b95a9a0de49bc815b253595fd4b96f4fa8