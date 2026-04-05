#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files at the specified commit
git checkout 4fe3307fb2d9f86d19777c7eb0e4809e9694dde7 "googlemock/test/gmock-matchers-arithmetic_test.cc" "googlemock/test/gmock-matchers-comparisons_test.cc"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/googlemock/test/gmock-matchers-arithmetic_test.cc b/googlemock/test/gmock-matchers-arithmetic_test.cc
--- a/googlemock/test/gmock-matchers-arithmetic_test.cc
+++ b/googlemock/test/gmock-matchers-arithmetic_test.cc
@@ -770,7 +770,8 @@ TEST_P(AllOfTestP, ExplainsResult) {
   // Failed match.  The first matcher, which failed, needs to
   // explain.
   m = AllOf(GreaterThan(10), GreaterThan(20));
-  EXPECT_EQ("which is 5 less than 10", Explain(m, 5));
+  EXPECT_EQ("which is 5 less than 10, and which is 15 less than 20",
+            Explain(m, 5));
 
   // Failed match.  The second matcher, which failed, needs to
   // explain.  Since it doesn't given an explanation, the matcher text is
diff --git a/googlemock/test/gmock-matchers-comparisons_test.cc b/googlemock/test/gmock-matchers-comparisons_test.cc
--- a/googlemock/test/gmock-matchers-comparisons_test.cc
+++ b/googlemock/test/gmock-matchers-comparisons_test.cc
@@ -2389,22 +2389,19 @@ PolymorphicMatcher<DivisibleByImpl> DivisibleBy(int n) {
   return MakePolymorphicMatcher(DivisibleByImpl(n));
 }
 
-// Tests that when AllOf() fails, only the first failing matcher is
-// asked to explain why.
+// Tests that when AllOf() fails, all failing matchers are asked to explain why.
 TEST(ExplainMatchResultTest, AllOf_False_False) {
   const Matcher<int> m = AllOf(DivisibleBy(4), DivisibleBy(3));
-  EXPECT_EQ("which is 1 modulo 4", Explain(m, 5));
+  EXPECT_EQ("which is 1 modulo 4, and which is 2 modulo 3", Explain(m, 5));
 }
 
-// Tests that when AllOf() fails, only the first failing matcher is
-// asked to explain why.
+// Tests that when AllOf() fails, all failing matchers are asked to explain why.
 TEST(ExplainMatchResultTest, AllOf_False_True) {
   const Matcher<int> m = AllOf(DivisibleBy(4), DivisibleBy(3));
   EXPECT_EQ("which is 2 modulo 4", Explain(m, 6));
 }
 
-// Tests that when AllOf() fails, only the first failing matcher is
-// asked to explain why.
+// Tests that when AllOf() fails, all failing matchers are asked to explain why.
 TEST(ExplainMatchResultTest, AllOf_True_False) {
   const Matcher<int> m = AllOf(Ge(1), DivisibleBy(3));
   EXPECT_EQ("which is 2 modulo 3", Explain(m, 5));
EOF_114329324912

# Rebuild the modified test executables
# Navigate to build directory and rebuild only the affected tests
cd /testbed/build
make gmock-matchers-arithmetic_test gmock-matchers-comparisons_test -j$(nproc)

# Run the target tests using CTest for better output handling
# Using regex to match both tests in a single command for efficiency
ctest -R "gmock-matchers-arithmetic_test|gmock-matchers-comparisons_test" --output-on-failure --verbose
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
cd /testbed
git checkout 4fe3307fb2d9f86d19777c7eb0e4809e9694dde7 "googlemock/test/gmock-matchers-arithmetic_test.cc" "googlemock/test/gmock-matchers-comparisons_test.cc"