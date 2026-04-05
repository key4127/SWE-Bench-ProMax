#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 64786ddcb72b91493b10bf25ffe945847f053dde "src/unittests/base/XBaseTests.cpp" "src/unittests/base/XBaseTests.h" "src/unittests/base/CMakeLists.txt"

# Apply test patch
# Note: The patch renames XBaseTests to BaseExceptionTests
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/base/XBaseTests.cpp b/src/unittests/base/BaseExceptionTests.cpp
rename from src/unittests/base/XBaseTests.cpp
rename to src/unittests/base/BaseExceptionTests.cpp
--- a/src/unittests/base/XBaseTests.cpp
+++ b/src/unittests/base/BaseExceptionTests.cpp
@@ -5,24 +5,24 @@
  * SPDX-License-Identifier: GPL-2.0-only WITH LicenseRef-OpenSSL-Exception
  */
 
-#include "XBaseTests.h"
+#include "BaseExceptionTests.h"
 
-#include "base/XBase.h"
+#include "base/BaseException.h"
 
-void XBaseTests::empty()
+void BaseExceptionTests::empty()
 {
-  XBase xbase;
-  const char *result = xbase.what();
+  BaseException BaseException;
+  const char *result = BaseException.what();
 
   QCOMPARE(result, "");
 }
 
-void XBaseTests::nonEmpty()
+void BaseExceptionTests::nonEmpty()
 {
-  XBase xbase("test");
-  const char *result = xbase.what();
+  BaseException BaseException("test");
+  const char *result = BaseException.what();
 
   QCOMPARE(result, "test");
 }
 
-QTEST_MAIN(XBaseTests)
+QTEST_MAIN(BaseExceptionTests)
diff --git a/src/unittests/base/XBaseTests.h b/src/unittests/base/BaseExceptionTests.h
rename from src/unittests/base/XBaseTests.h
rename to src/unittests/base/BaseExceptionTests.h
--- a/src/unittests/base/XBaseTests.h
+++ b/src/unittests/base/BaseExceptionTests.h
@@ -6,7 +6,7 @@
 
 #include <QTest>
 
-class XBaseTests : public QObject
+class BaseExceptionTests : public QObject
 {
   Q_OBJECT
 private Q_SLOTS:
diff --git a/src/unittests/base/CMakeLists.txt b/src/unittests/base/CMakeLists.txt
--- a/src/unittests/base/CMakeLists.txt
+++ b/src/unittests/base/CMakeLists.txt
@@ -30,10 +30,10 @@ create_test(
 )
 
 create_test(
-  NAME XBaseTests
+  NAME BaseExceptionTests
   DEPENDS base
   LIBS arch
-  SOURCE XBaseTests.cpp
+  SOURCE BaseExceptionTests.cpp
   WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/src/lib/base"
 )
 
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed
cmake --build build --config Release -j$(nproc)

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run BaseExceptionTests (renamed from XBaseTests in the patch)
ctest --test-dir build/src/unittests -R "BaseExceptionTests" --output-on-failure
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout 64786ddcb72b91493b10bf25ffe945847f053dde "src/unittests/base/XBaseTests.cpp" "src/unittests/base/XBaseTests.h" "src/unittests/base/CMakeLists.txt"