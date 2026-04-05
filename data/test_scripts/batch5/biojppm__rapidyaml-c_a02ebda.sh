#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout be1b8543ea0dc06aa5886de64468750a31ef133f "test/test_callbacks.cpp"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/test_callbacks.cpp b/test/test_callbacks.cpp
--- a/test/test_callbacks.cpp
+++ b/test/test_callbacks.cpp
@@ -765,6 +765,46 @@ TEST(error, basic)
     }
 }
 
+template<class Fn>
+void test_check_basic(Fn &&fn, csubstr expected_msg)
+{
+    set_callbacks(mk_test_callbacks());
+    {
+        std::string exc_msg;(void)exc_msg;
+        RYML_IF_EXC(bool exc_ok = false);
+        C4_IF_EXCEPTIONS_(try, if(setjmp(s_jmp_env_expect_error) == 0))
+        {
+            std::forward<Fn>(fn)();
+        }
+        RYML_IF_EXC(catch(ExceptionBasic const& exc){
+            exc_msg = exc.what();
+            exc_ok = true;
+        })
+        C4_IF_EXCEPTIONS_(catch(std::exception const& exc) { exc_msg = exc.what(); }, else { exc_msg = stored_msg; })
+        std::cout << exc_msg << "\n";
+        std::cout << stored_msg_full << "\n";
+        RYML_IF_EXC(EXPECT_TRUE(exc_ok));
+        EXPECT_NE(csubstr::npos, to_csubstr(exc_msg).find(expected_msg));
+    }
+    reset_callbacks();
+}
+TEST(check, basic)
+{
+    bool disregard_this_message = false;
+    csubstr msg = "disregard_this_message";
+    csubstr fmsg = "disregard_this_message: extra args: 1,2";
+    test_check_basic([&]{ _RYML_CHECK_BASIC(disregard_this_message); }, msg);
+    test_check_basic([&]{ _RYML_CHECK_BASIC_(get_callbacks(), disregard_this_message); }, msg);
+    test_check_basic([&]{ _RYML_CHECK_BASIC_MSG(disregard_this_message, "extra args: {},{}", 1, 2); }, fmsg);
+    test_check_basic([&]{ _RYML_CHECK_BASIC_MSG_(get_callbacks(), disregard_this_message, "extra args: {},{}", 1, 2); }, fmsg);
+    #if RYML_USE_ASSERT
+    test_check_basic([&]{ _RYML_ASSERT_BASIC(disregard_this_message); }, msg);
+    test_check_basic([&]{ _RYML_ASSERT_BASIC_(get_callbacks(), disregard_this_message); }, msg);
+    test_check_basic([&]{ _RYML_ASSERT_BASIC_MSG(disregard_this_message, "extra args: {},{}", 1, 2); }, fmsg);
+    test_check_basic([&]{ _RYML_ASSERT_BASIC_MSG_(get_callbacks(), disregard_this_message, "extra args: {},{}", 1, 2); }, fmsg);
+    #endif
+}
+
 #ifdef _RYML_WITH_EXCEPTIONS
 template<class T, class ...Args>
 void testmsg(Args const& ...args)
@@ -1062,6 +1102,70 @@ TEST(error, parse)
     }
 }
 
+template<class Fn>
+void test_check_parse(Fn &&fn, csubstr expected_msg)
+{
+    set_callbacks(mk_test_callbacks());
+    {
+        std::string exc_msg;(void)exc_msg;
+        RYML_IF_EXC(bool exc_ok = false);
+        C4_IF_EXCEPTIONS_(try, if(setjmp(s_jmp_env_expect_error) == 0))
+        {
+            std::forward<Fn>(fn)();
+        }
+        RYML_IF_EXC(catch(ExceptionParse const& exc){
+            exc_msg = exc.what();
+            exc_ok = true;
+        })
+        C4_IF_EXCEPTIONS_(catch(std::exception const& exc) { exc_msg = exc.what(); }, else { exc_msg = stored_msg; })
+        std::cout << stored_msg_full << "\n";
+        RYML_IF_EXC(EXPECT_TRUE(exc_ok));
+        EXPECT_NE(csubstr::npos, to_csubstr(exc_msg).find(expected_msg));
+    }
+    reset_callbacks();
+}
+TEST(check, parse)
+{
+    bool disregard_this_message = false;
+    csubstr msg = "disregard_this_message";
+    csubstr fmsg = "disregard_this_message: extra args: 1,2";
+    Location ymlloc = {};
+    {
+        SCOPED_TRACE("here 0");
+        test_check_parse([&]{ _RYML_CHECK_PARSE(disregard_this_message, ymlloc); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 1");
+        test_check_parse([&]{ _RYML_CHECK_PARSE_(get_callbacks(), disregard_this_message, ymlloc); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 2");
+        test_check_parse([&]{ _RYML_CHECK_PARSE_MSG(disregard_this_message, ymlloc, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    {
+        SCOPED_TRACE("here 3");
+        test_check_parse([&]{ _RYML_CHECK_PARSE_MSG_(get_callbacks(), disregard_this_message, ymlloc, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    #if RYML_USE_ASSERT
+    {
+        SCOPED_TRACE("here 4");
+        test_check_parse([&]{ _RYML_ASSERT_PARSE(disregard_this_message, ymlloc); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 5");
+        test_check_parse([&]{ _RYML_ASSERT_PARSE_(get_callbacks(), disregard_this_message, ymlloc); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 6");
+        test_check_parse([&]{ _RYML_ASSERT_PARSE_MSG(disregard_this_message, ymlloc, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    {
+        SCOPED_TRACE("here 7");
+        test_check_parse([&]{ _RYML_ASSERT_PARSE_MSG_(get_callbacks(), disregard_this_message, ymlloc, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    #endif
+}
+
 
 //-----------------------------------------------------------------------------
 
@@ -1298,6 +1402,71 @@ TEST(error, visit)
     }
 }
 
+template<class Fn>
+void test_check_visit(Fn &&fn, csubstr expected_msg)
+{
+    set_callbacks(mk_test_callbacks());
+    {
+        std::string exc_msg;(void)exc_msg;
+        RYML_IF_EXC(bool exc_ok = false);
+        C4_IF_EXCEPTIONS_(try, if(setjmp(s_jmp_env_expect_error) == 0))
+        {
+            std::forward<Fn>(fn)();
+        }
+        RYML_IF_EXC(catch(ExceptionVisit const& exc){
+            exc_msg = exc.what();
+            exc_ok = true;
+        })
+        C4_IF_EXCEPTIONS_(catch(std::exception const& exc) { exc_msg = exc.what(); }, else { exc_msg = stored_msg; })
+        std::cout << stored_msg_full << "\n";
+        RYML_IF_EXC(EXPECT_TRUE(exc_ok));
+        EXPECT_NE(csubstr::npos, to_csubstr(exc_msg).find(expected_msg));
+    }
+    reset_callbacks();
+}
+TEST(check, visit)
+{
+    bool disregard_this_message = false;
+    csubstr msg = "disregard_this_message";
+    csubstr fmsg = "disregard_this_message: extra args: 1,2";
+    Tree tree = parse_in_arena("foo: bar");
+    id_type id = tree.root_id();
+    {
+        SCOPED_TRACE("here 0");
+        test_check_visit([&]{ _RYML_CHECK_VISIT(disregard_this_message, &tree, id); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 1");
+        test_check_visit([&]{ _RYML_CHECK_VISIT_(get_callbacks(), disregard_this_message, &tree, id); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 2");
+        test_check_visit([&]{ _RYML_CHECK_VISIT_MSG(disregard_this_message, &tree, id, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    {
+        SCOPED_TRACE("here 3");
+        test_check_visit([&]{ _RYML_CHECK_VISIT_MSG_(get_callbacks(), disregard_this_message, &tree, id, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    #if RYML_USE_ASSERT
+    {
+        SCOPED_TRACE("here 4");
+        test_check_visit([&]{ _RYML_ASSERT_VISIT(disregard_this_message, &tree, id); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 5");
+        test_check_visit([&]{ _RYML_ASSERT_VISIT_(get_callbacks(), disregard_this_message, &tree, id); }, msg);
+    }
+    {
+        SCOPED_TRACE("here 6");
+        test_check_visit([&]{ _RYML_ASSERT_VISIT_MSG(disregard_this_message, &tree, id, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    {
+        SCOPED_TRACE("here 7");
+        test_check_visit([&]{ _RYML_ASSERT_VISIT_MSG_(get_callbacks(), disregard_this_message, &tree, id, "extra args: {},{}", 1, 2); }, fmsg);
+    }
+    #endif
+}
+
 TEST(RYML_CHECK, basic)
 {
     EXPECT_NE(get_callbacks().m_error_parse, &test_error_parse_impl);
@@ -1312,7 +1481,7 @@ TEST(RYML_CHECK, basic)
     {
         ;
     }
-    EXPECT_EQ(stored_msg, "check failed");
+    EXPECT_TRUE(to_csubstr(stored_msg).begins_with("check failed"));
     EXPECT_EQ(stored_cpploc.name, __FILE__);
     EXPECT_EQ(stored_cpploc.offset, npos);
     EXPECT_EQ(stored_cpploc.line, the_line);
@@ -1338,7 +1507,7 @@ TEST(RYML_ASSERT, basic)
         ;
     }
     #if RYML_USE_ASSERT
-    EXPECT_EQ(stored_msg, "check failed");
+    EXPECT_TRUE(to_csubstr(stored_msg).begins_with("check failed"));
     EXPECT_EQ(stored_cpploc.name, __FILE__);
     EXPECT_EQ(stored_cpploc.offset, npos);
     EXPECT_EQ(stored_cpploc.line, the_line);
EOF_114329324912

# Rebuild the test target with the patched test file
cmake --build build --target ryml-test-callbacks

# Run the specific test target
./build/test/ryml-test-callbacks
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout be1b8543ea0dc06aa5886de64468750a31ef133f "test/test_callbacks.cpp"