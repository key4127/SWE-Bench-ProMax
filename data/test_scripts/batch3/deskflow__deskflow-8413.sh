#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 632be4b240c62574d8b75602ebf8842b828326b5 "src/unittests/deskflow/CMakeLists.txt" "src/test/unittests/deskflow/KeyMapTests.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/unittests/deskflow/CMakeLists.txt b/src/unittests/deskflow/CMakeLists.txt
--- a/src/unittests/deskflow/CMakeLists.txt
+++ b/src/unittests/deskflow/CMakeLists.txt
@@ -45,6 +45,13 @@ create_test(
   WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/src/lib/deskflow"
 )
 
+create_test(
+  NAME KeyMapTests
+  DEPENDS app
+  LIBS arch base ${extra_libs}
+  SOURCE KeyMapTests.cpp
+  WORKING_DIRECTORY "${CMAKE_BINARY_DIR}/src/lib/deskflow"
+)
 
 create_test(
   NAME test_LanguageManagerTests
diff --git a/src/test/unittests/deskflow/KeyMapTests.cpp b/src/unittests/deskflow/KeyMapTests.cpp
rename from src/test/unittests/deskflow/KeyMapTests.cpp
rename to src/unittests/deskflow/KeyMapTests.cpp
--- a/src/test/unittests/deskflow/KeyMapTests.cpp
+++ b/src/unittests/deskflow/KeyMapTests.cpp
@@ -1,60 +1,52 @@
 /*
  * Deskflow -- mouse and keyboard sharing utility
+ * SPDX-FileCopyrightText: (C) 2025 Chris Rizzitello <sithlord48@gmail.com>
  * SPDX-FileCopyrightText: (C) 2016 Symless Ltd.
  * SPDX-License-Identifier: GPL-2.0-only WITH LicenseRef-OpenSSL-Exception
  */
+#include "KeyMapTests.h"
 
-#define TEST_ENV
+#include "../../lib/deskflow/KeyMap.h"
 
-#include "deskflow/KeyMap.h"
+using namespace deskflow;
+using KeyItemList = KeyMap::KeyItemList;
+using KeyEntryList = std::vector<KeyItemList>;
 
-#include <gmock/gmock.h>
-#include <gtest/gtest.h>
-
-using ::testing::_;
-using ::testing::Invoke;
-using ::testing::NiceMock;
-using ::testing::Return;
-using ::testing::ReturnRef;
-using ::testing::SaveArg;
-
-namespace deskflow {
-
-TEST(KeyMapTests, findBestKey_requiredDown_matchExactFirstItem)
+void KeyMapTests::findBestKey_requiredDown_matchExactFirstItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList;
+  KeyEntryList entryList;
+  KeyItemList itemList;
   KeyMap::KeyItem item;
   item.m_required = KeyModifierShift;
   item.m_sensitive = KeyModifierShift;
   KeyModifierMask desiredState = KeyModifierShift;
   itemList.push_back(item);
   entryList.push_back(itemList);
 
-  EXPECT_EQ(0, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 0);
 }
 
-TEST(KeyMapTests, findBestKey_requiredAndExtraSensitiveDown_matchExactFirstItem)
+void KeyMapTests::findBestKey_requiredAndExtraSensitiveDown_matchExactFirstItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList;
+  KeyEntryList entryList;
+  KeyItemList itemList;
   KeyMap::KeyItem item;
   item.m_required = KeyModifierShift;
   item.m_sensitive = KeyModifierShift | KeyModifierAlt;
   KeyModifierMask desiredState = KeyModifierShift;
   itemList.push_back(item);
   entryList.push_back(itemList);
 
-  EXPECT_EQ(0, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 0);
 }
 
-TEST(KeyMapTests, findBestKey_requiredAndExtraSensitiveDown_matchExactSecondItem)
+void KeyMapTests::findBestKey_requiredAndExtraSensitiveDown_matchExactSecondItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList1;
+  KeyEntryList entryList;
+  KeyItemList itemList1;
   KeyMap::KeyItem item1;
   item1.m_required = KeyModifierAlt;
   item1.m_sensitive = KeyModifierShift | KeyModifierAlt;
@@ -67,15 +59,14 @@ TEST(KeyMapTests, findBestKey_requiredAndExtraSensitiveDown_matchExactSecondItem
   itemList2.push_back(item2);
   entryList.push_back(itemList1);
   entryList.push_back(itemList2);
-
-  EXPECT_EQ(1, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 1);
 }
 
-TEST(KeyMapTests, findBestKey_extraSensitiveDown_matchExactSecondItem)
+void KeyMapTests::findBestKey_extraSensitiveDown_matchExactSecondItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList1;
+  KeyEntryList entryList;
+  KeyItemList itemList1;
   KeyMap::KeyItem item1;
   item1.m_required = 0;
   item1.m_sensitive = KeyModifierAlt;
@@ -89,14 +80,14 @@ TEST(KeyMapTests, findBestKey_extraSensitiveDown_matchExactSecondItem)
   entryList.push_back(itemList1);
   entryList.push_back(itemList2);
 
-  EXPECT_EQ(1, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 1);
 }
 
-TEST(KeyMapTests, findBestKey_noRequiredDown_matchOneRequiredChangeItem)
+void KeyMapTests::findBestKey_noRequiredDown_matchOneRequiredChangeItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList1;
+  KeyEntryList entryList;
+  KeyItemList itemList1;
   KeyMap::KeyItem item1;
   item1.m_required = KeyModifierShift | KeyModifierAlt;
   item1.m_sensitive = KeyModifierShift | KeyModifierAlt;
@@ -110,18 +101,18 @@ TEST(KeyMapTests, findBestKey_noRequiredDown_matchOneRequiredChangeItem)
   entryList.push_back(itemList1);
   entryList.push_back(itemList2);
 
-  EXPECT_EQ(1, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 1);
 }
 
-TEST(KeyMapTests, findBestKey_onlyOneRequiredDown_matchTwoRequiredChangesItem)
+void KeyMapTests::findBestKey_onlyOneRequiredDown_matchTwoRequiredChangesItem()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList1;
+  KeyEntryList entryList;
+  KeyItemList itemList1;
   KeyMap::KeyItem item1;
   item1.m_required = KeyModifierShift | KeyModifierAlt | KeyModifierControl;
   item1.m_sensitive = KeyModifierShift | KeyModifierAlt | KeyModifierControl;
-  KeyMap::KeyItemList itemList2;
+  KeyItemList itemList2;
   KeyMap::KeyItem item2;
   item2.m_required = KeyModifierShift | KeyModifierAlt;
   item2.m_sensitive = KeyModifierShift | KeyModifierAlt | KeyModifierControl;
@@ -131,73 +122,47 @@ TEST(KeyMapTests, findBestKey_onlyOneRequiredDown_matchTwoRequiredChangesItem)
   entryList.push_back(itemList1);
   entryList.push_back(itemList2);
 
-  EXPECT_EQ(1, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), 1);
 }
 
-TEST(KeyMapTests, findBestKey_noRequiredDown_cannotMatch)
+void KeyMapTests::findBestKey_noRequiredDown_cannotMatch()
 {
   KeyMap keyMap;
-  KeyMap::KeyEntryList entryList;
-  KeyMap::KeyItemList itemList;
+  KeyEntryList entryList;
+  KeyItemList itemList;
   KeyMap::KeyItem item;
   item.m_required = 0xffffffff;
   item.m_sensitive = 0xffffffff;
   KeyModifierMask desiredState = 0;
   itemList.push_back(item);
   entryList.push_back(itemList);
 
-  EXPECT_EQ(-1, keyMap.findBestKey(entryList, desiredState));
+  QCOMPARE(keyMap.findBestKey(entryList, desiredState), -1);
 }
 
-TEST(KeyMapTests, isCommand_shiftMask_returnFalse)
+void KeyMapTests::isCommand()
 {
   KeyMap keyMap;
   KeyModifierMask mask = KeyModifierShift;
+  QVERIFY(!keyMap.isCommand(mask));
 
-  EXPECT_FALSE(keyMap.isCommand(mask));
-}
-
-TEST(KeyMapTests, isCommand_controlMask_returnTrue)
-{
-  KeyMap keyMap;
-  KeyModifierMask mask = KeyModifierControl;
-
-  EXPECT_EQ(true, keyMap.isCommand(mask));
-}
-
-TEST(KeyMapTests, isCommand_alternateMask_returnTrue)
-{
-  KeyMap keyMap;
-  KeyModifierMask mask = KeyModifierAlt;
-
-  EXPECT_EQ(true, keyMap.isCommand(mask));
-}
+  mask = KeyModifierControl;
+  QVERIFY(keyMap.isCommand(mask));
 
-TEST(KeyMapTests, isCommand_alternateGraphicMask_returnTrue)
-{
-  KeyMap keyMap;
-  KeyModifierMask mask = KeyModifierAltGr;
+  mask = KeyModifierAlt;
+  QVERIFY(keyMap.isCommand(mask));
 
-  EXPECT_EQ(true, keyMap.isCommand(mask));
-}
+  mask = KeyModifierAltGr;
+  QVERIFY(keyMap.isCommand(mask));
 
-TEST(KeyMapTests, isCommand_metaMask_returnTrue)
-{
-  KeyMap keyMap;
-  KeyModifierMask mask = KeyModifierMeta;
-
-  EXPECT_EQ(true, keyMap.isCommand(mask));
-}
-
-TEST(KeyMapTests, isCommand_superMask_returnTrue)
-{
-  KeyMap keyMap;
-  KeyModifierMask mask = KeyModifierSuper;
+  mask = KeyModifierMeta;
+  QVERIFY(keyMap.isCommand(mask));
 
-  EXPECT_EQ(true, keyMap.isCommand(mask));
+  mask = KeyModifierSuper;
+  QVERIFY(keyMap.isCommand(mask));
 }
 
-TEST(KeyMapTests, mapkey_handles_setmodifier_with_no_mapped)
+void KeyMapTests::mapkey()
 {
   KeyMap keyMap{};
   KeyMap::Keystroke stroke('A', true, false, 1);
@@ -212,10 +177,10 @@ TEST(KeyMapTests, mapkey_handles_setmodifier_with_no_mapped)
   KeyModifierMask currentState{};
   KeyModifierMask desiredMask{};
   auto result = keyMap.mapKey(strokes, kKeySetModifiers, 1, activeModifiers, currentState, desiredMask, false, "en");
-  EXPECT_FALSE(result == nullptr);
+  QVERIFY(result != nullptr);
   desiredMask = KeyModifierControl;
   result = keyMap.mapKey(strokes, kKeySetModifiers, 1, activeModifiers, currentState, desiredMask, false, "en");
-  EXPECT_TRUE(result == nullptr);
+  QVERIFY(result == nullptr);
 }
 
-} // namespace deskflow
+QTEST_MAIN(KeyMapTests)
diff --git a/src/unittests/deskflow/KeyMapTests.h b/src/unittests/deskflow/KeyMapTests.h
new file mode 100644
--- /dev/null
+++ b/src/unittests/deskflow/KeyMapTests.h
@@ -0,0 +1,29 @@
+/*
+ * Deskflow -- mouse and keyboard sharing utility
+ * SPDX-FileCopyrightText: (C) 2025 Chris Rizzitello <sithlord48@gmail.com>
+ * SPDX-License-Identifier: GPL-2.0-only WITH LicenseRef-OpenSSL-Exception
+ */
+#include "base/Log.h"
+
+#include <QTest>
+
+namespace deskflow {
+class KeyMapTests : public QObject
+{
+  Q_OBJECT
+private slots:
+  void findBestKey_requiredDown_matchExactFirstItem();
+  void findBestKey_requiredAndExtraSensitiveDown_matchExactFirstItem();
+  void findBestKey_requiredAndExtraSensitiveDown_matchExactSecondItem();
+  void findBestKey_extraSensitiveDown_matchExactSecondItem();
+  void findBestKey_noRequiredDown_matchOneRequiredChangeItem();
+  void findBestKey_onlyOneRequiredDown_matchTwoRequiredChangesItem();
+  void findBestKey_noRequiredDown_cannotMatch();
+  void isCommand();
+  void mapkey();
+
+private:
+  Arch m_arch;
+  Log m_log;
+};
+} // namespace deskflow
EOF_114329324912

# Rebuild the project to incorporate any changes from the patch
cd /testbed
cmake --build build --config Release -j$(nproc)

# Ensure QT_QPA_PLATFORM is set for headless execution
export QT_QPA_PLATFORM=offscreen

# Run the KeyMapTests executable directly (it's a standalone test binary after the patch)
./build/bin/KeyMapTests
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout 632be4b240c62574d8b75602ebf8842b828326b5 "src/unittests/deskflow/CMakeLists.txt" "src/test/unittests/deskflow/KeyMapTests.cpp"