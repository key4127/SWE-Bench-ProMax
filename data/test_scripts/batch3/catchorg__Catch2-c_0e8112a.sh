#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the baseline files to ensure clean state
git checkout 9be81c0e05aedabbf1224ccb424ef0a628bcb9c8 "tests/SelfTest/Baselines/compact.sw.approved.txt" "tests/SelfTest/Baselines/compact.sw.multi.approved.txt" "tests/SelfTest/Baselines/console.std.approved.txt" "tests/SelfTest/Baselines/console.sw.approved.txt" "tests/SelfTest/Baselines/console.sw.multi.approved.txt" "tests/SelfTest/Baselines/console.swa4.approved.txt" "tests/SelfTest/Baselines/junit.sw.approved.txt" "tests/SelfTest/Baselines/junit.sw.multi.approved.txt" "tests/SelfTest/Baselines/sonarqube.sw.approved.txt" "tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt" "tests/SelfTest/Baselines/tap.sw.approved.txt" "tests/SelfTest/Baselines/tap.sw.multi.approved.txt" "tests/SelfTest/Baselines/teamcity.sw.approved.txt" "tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt" "tests/SelfTest/Baselines/xml.sw.approved.txt" "tests/SelfTest/Baselines/xml.sw.multi.approved.txt"

# Apply source code patch to modify the Catch2 source code
# This patch should remove the '{Unknown expression after the reported line}' output
git apply -v - <<'EOF_SOURCE_PATCH'
[CONTENT OF SOURCE PATCH]
EOF_SOURCE_PATCH

# Rebuild the project with the patched source code
echo "Rebuilding project with patched source code..."
cd /testbed
rm -rf build
cmake -B build -S . -G Ninja \
    -DCATCH_DEVELOPMENT_BUILD=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=14
cmake --build build --parallel 4

# Verify the rebuilt SelfTest executable exists
if [ ! -f /testbed/build/tests/SelfTest ]; then
    echo "ERROR: SelfTest executable not found after rebuild"
    exit 1
fi

# Apply the test patch to update baseline files with expected new output
git apply -v - <<'EOF_114329324912'
diff --git a/tests/SelfTest/Baselines/compact.sw.approved.txt b/tests/SelfTest/Baselines/compact.sw.approved.txt
--- a/tests/SelfTest/Baselines/compact.sw.approved.txt
+++ b/tests/SelfTest/Baselines/compact.sw.approved.txt
@@ -84,8 +84,8 @@ Matchers.tests.cpp:<line number>: passed: smallest_non_zero, WithinULP( -smalles
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0 not is within 1 ULPs of -4.9406564584124654e-324 ([-9.8813129168249309e-324, -0.0000000000000000e+00])
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, WithinULP( -smallest_non_zero, 2 ) for: 0.0f is within 2 ULPs of -1.40129846e-45f ([-4.20389539e-45, 1.40129846e-45])
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0f not is within 1 ULPs of -1.40129846e-45f ([-2.80259693e-45, -0.00000000e+00])
-Generators.tests.cpp:<line number>: failed: unexpected exception with message: 'failure to init'
-Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42' with 1 message: 'expected exception'
+Generators.tests.cpp:<line number>: failed: unexpected exception with message: 'failure to init'; expression was: {Unknown expression after the reported line}
+Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42'; expression was: {Unknown expression after the reported line} with 1 message: 'expected exception'
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42'; expression was: thisThrows() with 1 message: 'expected exception'
 Exception.tests.cpp:<line number>: passed: thisThrows() with 1 message: 'answer := 42'
 Compilation.tests.cpp:<line number>: passed: 42 == f for: 42 == {?}
@@ -2392,7 +2392,7 @@ Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'u
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
-Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'unexpected exception'
+Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'unexpected exception'; expression was: {Unknown expression after the reported line}
 Tricky.tests.cpp:<line number>: passed:
 Tricky.tests.cpp:<line number>: passed:
 Tricky.tests.cpp:<line number>: passed:
diff --git a/tests/SelfTest/Baselines/compact.sw.multi.approved.txt b/tests/SelfTest/Baselines/compact.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/compact.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/compact.sw.multi.approved.txt
@@ -82,8 +82,8 @@ Matchers.tests.cpp:<line number>: passed: smallest_non_zero, WithinULP( -smalles
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0 not is within 1 ULPs of -4.9406564584124654e-324 ([-9.8813129168249309e-324, -0.0000000000000000e+00])
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, WithinULP( -smallest_non_zero, 2 ) for: 0.0f is within 2 ULPs of -1.40129846e-45f ([-4.20389539e-45, 1.40129846e-45])
 Matchers.tests.cpp:<line number>: passed: smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0f not is within 1 ULPs of -1.40129846e-45f ([-2.80259693e-45, -0.00000000e+00])
-Generators.tests.cpp:<line number>: failed: unexpected exception with message: 'failure to init'
-Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42' with 1 message: 'expected exception'
+Generators.tests.cpp:<line number>: failed: unexpected exception with message: 'failure to init'; expression was: {Unknown expression after the reported line}
+Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42'; expression was: {Unknown expression after the reported line} with 1 message: 'expected exception'
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'answer := 42'; expression was: thisThrows() with 1 message: 'expected exception'
 Exception.tests.cpp:<line number>: passed: thisThrows() with 1 message: 'answer := 42'
 Compilation.tests.cpp:<line number>: passed: 42 == f for: 42 == {?}
@@ -2385,7 +2385,7 @@ Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'u
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
-Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'unexpected exception'
+Exception.tests.cpp:<line number>: failed: unexpected exception with message: 'unexpected exception'; expression was: {Unknown expression after the reported line}
 Tricky.tests.cpp:<line number>: passed:
 Tricky.tests.cpp:<line number>: passed:
 Tricky.tests.cpp:<line number>: passed:
diff --git a/tests/SelfTest/Baselines/console.std.approved.txt b/tests/SelfTest/Baselines/console.std.approved.txt
--- a/tests/SelfTest/Baselines/console.std.approved.txt
+++ b/tests/SelfTest/Baselines/console.std.approved.txt
@@ -34,6 +34,7 @@ Generators.tests.cpp:<line number>
 ...............................................................................
 
 Generators.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   failure to init
 
@@ -45,6 +46,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with messages:
   answer := 42
   expected exception
@@ -1248,6 +1250,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   unexpected exception
 
diff --git a/tests/SelfTest/Baselines/console.sw.approved.txt b/tests/SelfTest/Baselines/console.sw.approved.txt
--- a/tests/SelfTest/Baselines/console.sw.approved.txt
+++ b/tests/SelfTest/Baselines/console.sw.approved.txt
@@ -768,6 +768,7 @@ Generators.tests.cpp:<line number>
 ...............................................................................
 
 Generators.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   failure to init
 
@@ -779,6 +780,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with messages:
   answer := 42
   expected exception
@@ -15783,6 +15785,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   unexpected exception
 
diff --git a/tests/SelfTest/Baselines/console.sw.multi.approved.txt b/tests/SelfTest/Baselines/console.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/console.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/console.sw.multi.approved.txt
@@ -766,6 +766,7 @@ Generators.tests.cpp:<line number>
 ...............................................................................
 
 Generators.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   failure to init
 
@@ -777,6 +778,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with messages:
   answer := 42
   expected exception
@@ -15776,6 +15778,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   unexpected exception
 
diff --git a/tests/SelfTest/Baselines/console.swa4.approved.txt b/tests/SelfTest/Baselines/console.swa4.approved.txt
--- a/tests/SelfTest/Baselines/console.swa4.approved.txt
+++ b/tests/SelfTest/Baselines/console.swa4.approved.txt
@@ -768,6 +768,7 @@ Generators.tests.cpp:<line number>
 ...............................................................................
 
 Generators.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with message:
   failure to init
 
@@ -779,6 +780,7 @@ Exception.tests.cpp:<line number>
 ...............................................................................
 
 Exception.tests.cpp:<line number>: FAILED:
+  {Unknown expression after the reported line}
 due to unexpected exception with messages:
   answer := 42
   expected exception
diff --git a/tests/SelfTest/Baselines/junit.sw.approved.txt b/tests/SelfTest/Baselines/junit.sw.approved.txt
--- a/tests/SelfTest/Baselines/junit.sw.approved.txt
+++ b/tests/SelfTest/Baselines/junit.sw.approved.txt
@@ -53,17 +53,19 @@ Nor would this
     <testcase classname="<exe-name>.global" name="#2152 - ULP checks between differently signed values were wrong - float" time="{duration}" status="run"/>
     <testcase classname="<exe-name>.global" name="#2615 - Throwing in constructor generator fails test case but does not abort" time="{duration}" status="run">
       <skipped message="TEST_CASE tagged with !mayfail"/>
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 failure to init
 at Generators.tests.cpp:<line number>
       </error>
     </testcase>
     <testcase classname="<exe-name>.global" name="#748 - captures with unexpected exceptions" time="{duration}" status="run"/>
     <testcase classname="<exe-name>.global" name="#748 - captures with unexpected exceptions/outside assertions" time="{duration}" status="run">
       <skipped message="TEST_CASE tagged with !mayfail"/>
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 expected exception
 answer := 42
 at Exception.tests.cpp:<line number>
@@ -1837,8 +1839,9 @@ at Exception.tests.cpp:<line number>
       </error>
     </testcase>
     <testcase classname="<exe-name>.global" name="When unchecked exceptions are thrown from sections they are always failures/section name" time="{duration}" status="run">
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 unexpected exception
 at Exception.tests.cpp:<line number>
       </error>
diff --git a/tests/SelfTest/Baselines/junit.sw.multi.approved.txt b/tests/SelfTest/Baselines/junit.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/junit.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/junit.sw.multi.approved.txt
@@ -52,17 +52,19 @@ Nor would this
     <testcase classname="<exe-name>.global" name="#2152 - ULP checks between differently signed values were wrong - float" time="{duration}" status="run"/>
     <testcase classname="<exe-name>.global" name="#2615 - Throwing in constructor generator fails test case but does not abort" time="{duration}" status="run">
       <skipped message="TEST_CASE tagged with !mayfail"/>
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 failure to init
 at Generators.tests.cpp:<line number>
       </error>
     </testcase>
     <testcase classname="<exe-name>.global" name="#748 - captures with unexpected exceptions" time="{duration}" status="run"/>
     <testcase classname="<exe-name>.global" name="#748 - captures with unexpected exceptions/outside assertions" time="{duration}" status="run">
       <skipped message="TEST_CASE tagged with !mayfail"/>
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 expected exception
 answer := 42
 at Exception.tests.cpp:<line number>
@@ -1836,8 +1838,9 @@ at Exception.tests.cpp:<line number>
       </error>
     </testcase>
     <testcase classname="<exe-name>.global" name="When unchecked exceptions are thrown from sections they are always failures/section name" time="{duration}" status="run">
-      <error type="TEST_CASE">
+      <error message="{Unknown expression after the reported line}">
 FAILED:
+  {Unknown expression after the reported line}
 unexpected exception
 at Exception.tests.cpp:<line number>
       </error>
diff --git a/tests/SelfTest/Baselines/sonarqube.sw.approved.txt b/tests/SelfTest/Baselines/sonarqube.sw.approved.txt
--- a/tests/SelfTest/Baselines/sonarqube.sw.approved.txt
+++ b/tests/SelfTest/Baselines/sonarqube.sw.approved.txt
@@ -1008,8 +1008,9 @@ at Decomposition.tests.cpp:<line number>
   <file path="tests/<exe-name>/UsageTests/Exception.tests.cpp">
     <testCase name="#748 - captures with unexpected exceptions" duration="{duration}"/>
     <testCase name="#748 - captures with unexpected exceptions/outside assertions" duration="{duration}">
-      <skipped message="TEST_CASE()">
+      <skipped message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 expected exception
 answer := 42
 at Exception.tests.cpp:<line number>
@@ -1142,8 +1143,9 @@ at Exception.tests.cpp:<line number>
       </error>
     </testCase>
     <testCase name="When unchecked exceptions are thrown from sections they are always failures/section name" duration="{duration}">
-      <error message="TEST_CASE()">
+      <error message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 unexpected exception
 at Exception.tests.cpp:<line number>
       </error>
@@ -1161,8 +1163,9 @@ at Exception.tests.cpp:<line number>
     <testCase name="#1913 - GENERATE inside a for loop should not keep recreating the generator" duration="{duration}"/>
     <testCase name="#1913 - GENERATEs can share a line" duration="{duration}"/>
     <testCase name="#2615 - Throwing in constructor generator fails test case but does not abort" duration="{duration}">
-      <skipped message="TEST_CASE()">
+      <skipped message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 failure to init
 at Generators.tests.cpp:<line number>
       </skipped>
diff --git a/tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt b/tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt
@@ -1007,8 +1007,9 @@ at Decomposition.tests.cpp:<line number>
   <file path="tests/<exe-name>/UsageTests/Exception.tests.cpp">
     <testCase name="#748 - captures with unexpected exceptions" duration="{duration}"/>
     <testCase name="#748 - captures with unexpected exceptions/outside assertions" duration="{duration}">
-      <skipped message="TEST_CASE()">
+      <skipped message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 expected exception
 answer := 42
 at Exception.tests.cpp:<line number>
@@ -1141,8 +1142,9 @@ at Exception.tests.cpp:<line number>
       </error>
     </testCase>
     <testCase name="When unchecked exceptions are thrown from sections they are always failures/section name" duration="{duration}">
-      <error message="TEST_CASE()">
+      <error message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 unexpected exception
 at Exception.tests.cpp:<line number>
       </error>
@@ -1160,8 +1162,9 @@ at Exception.tests.cpp:<line number>
     <testCase name="#1913 - GENERATE inside a for loop should not keep recreating the generator" duration="{duration}"/>
     <testCase name="#1913 - GENERATEs can share a line" duration="{duration}"/>
     <testCase name="#2615 - Throwing in constructor generator fails test case but does not abort" duration="{duration}">
-      <skipped message="TEST_CASE()">
+      <skipped message="({Unknown expression after the reported line})">
 FAILED:
+	{Unknown expression after the reported line}
 failure to init
 at Generators.tests.cpp:<line number>
       </skipped>
diff --git a/tests/SelfTest/Baselines/tap.sw.approved.txt b/tests/SelfTest/Baselines/tap.sw.approved.txt
--- a/tests/SelfTest/Baselines/tap.sw.approved.txt
+++ b/tests/SelfTest/Baselines/tap.sw.approved.txt
@@ -165,9 +165,9 @@ ok {test-number} - smallest_non_zero, WithinULP( -smallest_non_zero, 2 ) for: 0.
 # #2152 - ULP checks between differently signed values were wrong - float
 ok {test-number} - smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0f not is within 1 ULPs of -1.40129846e-45f ([-2.80259693e-45, -0.00000000e+00])
 # #2615 - Throwing in constructor generator fails test case but does not abort
-not ok {test-number} - unexpected exception with message: 'failure to init'
+not ok {test-number} - unexpected exception with message: 'failure to init'; expression was: {Unknown expression after the reported line}
 # #748 - captures with unexpected exceptions
-not ok {test-number} - unexpected exception with message: 'answer := 42' with 1 message: 'expected exception'
+not ok {test-number} - unexpected exception with message: 'answer := 42'; expression was: {Unknown expression after the reported line} with 1 message: 'expected exception'
 # #748 - captures with unexpected exceptions
 not ok {test-number} - unexpected exception with message: 'answer := 42'; expression was: thisThrows() with 1 message: 'expected exception'
 # #748 - captures with unexpected exceptions
@@ -3772,7 +3772,7 @@ not ok {test-number} - unexpected exception with message: 'expected exception';
 # When unchecked exceptions are thrown from functions they are always failures
 not ok {test-number} - unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 # When unchecked exceptions are thrown from sections they are always failures
-not ok {test-number} - unexpected exception with message: 'unexpected exception'
+not ok {test-number} - unexpected exception with message: 'unexpected exception'; expression was: {Unknown expression after the reported line}
 # X/level/0/a
 ok {test-number} -
 # X/level/0/b
diff --git a/tests/SelfTest/Baselines/tap.sw.multi.approved.txt b/tests/SelfTest/Baselines/tap.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/tap.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/tap.sw.multi.approved.txt
@@ -163,9 +163,9 @@ ok {test-number} - smallest_non_zero, WithinULP( -smallest_non_zero, 2 ) for: 0.
 # #2152 - ULP checks between differently signed values were wrong - float
 ok {test-number} - smallest_non_zero, !WithinULP( -smallest_non_zero, 1 ) for: 0.0f not is within 1 ULPs of -1.40129846e-45f ([-2.80259693e-45, -0.00000000e+00])
 # #2615 - Throwing in constructor generator fails test case but does not abort
-not ok {test-number} - unexpected exception with message: 'failure to init'
+not ok {test-number} - unexpected exception with message: 'failure to init'; expression was: {Unknown expression after the reported line}
 # #748 - captures with unexpected exceptions
-not ok {test-number} - unexpected exception with message: 'answer := 42' with 1 message: 'expected exception'
+not ok {test-number} - unexpected exception with message: 'answer := 42'; expression was: {Unknown expression after the reported line} with 1 message: 'expected exception'
 # #748 - captures with unexpected exceptions
 not ok {test-number} - unexpected exception with message: 'answer := 42'; expression was: thisThrows() with 1 message: 'expected exception'
 # #748 - captures with unexpected exceptions
@@ -3765,7 +3765,7 @@ not ok {test-number} - unexpected exception with message: 'expected exception';
 # When unchecked exceptions are thrown from functions they are always failures
 not ok {test-number} - unexpected exception with message: 'expected exception'; expression was: thisThrows() == 0
 # When unchecked exceptions are thrown from sections they are always failures
-not ok {test-number} - unexpected exception with message: 'unexpected exception'
+not ok {test-number} - unexpected exception with message: 'unexpected exception'; expression was: {Unknown expression after the reported line}
 # X/level/0/a
 ok {test-number} -
 # X/level/0/b
diff --git a/tests/SelfTest/Baselines/teamcity.sw.approved.txt b/tests/SelfTest/Baselines/teamcity.sw.approved.txt
--- a/tests/SelfTest/Baselines/teamcity.sw.approved.txt
+++ b/tests/SelfTest/Baselines/teamcity.sw.approved.txt
@@ -53,10 +53,10 @@
 ##teamcity[testStarted name='#2152 - ULP checks between differently signed values were wrong - float']
 ##teamcity[testFinished name='#2152 - ULP checks between differently signed values were wrong - float' duration="{duration}"]
 ##teamcity[testStarted name='#2615 - Throwing in constructor generator fails test case but does not abort']
-##teamcity[testIgnored name='#2615 - Throwing in constructor generator fails test case but does not abort' message='Generators.tests.cpp:<line number>|n...............................................................................|n|nGenerators.tests.cpp:<line number>|nunexpected exception with message:|n  "failure to init"- failure ignore as test marked as |'ok to fail|'|n']
+##teamcity[testIgnored name='#2615 - Throwing in constructor generator fails test case but does not abort' message='Generators.tests.cpp:<line number>|n...............................................................................|n|nGenerators.tests.cpp:<line number>|nunexpected exception with message:|n  "failure to init"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testFinished name='#2615 - Throwing in constructor generator fails test case but does not abort' duration="{duration}"]
 ##teamcity[testStarted name='#748 - captures with unexpected exceptions']
-##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|noutside assertions|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"- failure ignore as test marked as |'ok to fail|'|n']
+##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|noutside assertions|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|ninside REQUIRE_NOTHROW|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"|n  REQUIRE_NOTHROW( thisThrows() )|nwith expansion:|n  thisThrows()|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testFinished name='#748 - captures with unexpected exceptions' duration="{duration}"]
 ##teamcity[testStarted name='#809']
@@ -751,7 +751,7 @@
 ##teamcity[testFailed name='When unchecked exceptions are thrown from functions they are always failures' message='Exception.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "expected exception"|n  CHECK( thisThrows() == 0 )|nwith expansion:|n  thisThrows() == 0|n']
 ##teamcity[testFinished name='When unchecked exceptions are thrown from functions they are always failures' duration="{duration}"]
 ##teamcity[testStarted name='When unchecked exceptions are thrown from sections they are always failures']
-##teamcity[testFailed name='When unchecked exceptions are thrown from sections they are always failures' message='-------------------------------------------------------------------------------|nsection name|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "unexpected exception"']
+##teamcity[testFailed name='When unchecked exceptions are thrown from sections they are always failures' message='-------------------------------------------------------------------------------|nsection name|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "unexpected exception"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n']
 ##teamcity[testFinished name='When unchecked exceptions are thrown from sections they are always failures' duration="{duration}"]
 ##teamcity[testStarted name='When unchecked exceptions are thrown, but caught, they do not affect the test']
 ##teamcity[testFinished name='When unchecked exceptions are thrown, but caught, they do not affect the test' duration="{duration}"]
diff --git a/tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt b/tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt
@@ -53,10 +53,10 @@
 ##teamcity[testStarted name='#2152 - ULP checks between differently signed values were wrong - float']
 ##teamcity[testFinished name='#2152 - ULP checks between differently signed values were wrong - float' duration="{duration}"]
 ##teamcity[testStarted name='#2615 - Throwing in constructor generator fails test case but does not abort']
-##teamcity[testIgnored name='#2615 - Throwing in constructor generator fails test case but does not abort' message='Generators.tests.cpp:<line number>|n...............................................................................|n|nGenerators.tests.cpp:<line number>|nunexpected exception with message:|n  "failure to init"- failure ignore as test marked as |'ok to fail|'|n']
+##teamcity[testIgnored name='#2615 - Throwing in constructor generator fails test case but does not abort' message='Generators.tests.cpp:<line number>|n...............................................................................|n|nGenerators.tests.cpp:<line number>|nunexpected exception with message:|n  "failure to init"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testFinished name='#2615 - Throwing in constructor generator fails test case but does not abort' duration="{duration}"]
 ##teamcity[testStarted name='#748 - captures with unexpected exceptions']
-##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|noutside assertions|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"- failure ignore as test marked as |'ok to fail|'|n']
+##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|noutside assertions|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testIgnored name='#748 - captures with unexpected exceptions' message='-------------------------------------------------------------------------------|ninside REQUIRE_NOTHROW|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with messages:|n  "answer := 42"|n  "expected exception"|n  REQUIRE_NOTHROW( thisThrows() )|nwith expansion:|n  thisThrows()|n- failure ignore as test marked as |'ok to fail|'|n']
 ##teamcity[testFinished name='#748 - captures with unexpected exceptions' duration="{duration}"]
 ##teamcity[testStarted name='#809']
@@ -751,7 +751,7 @@
 ##teamcity[testFailed name='When unchecked exceptions are thrown from functions they are always failures' message='Exception.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "expected exception"|n  CHECK( thisThrows() == 0 )|nwith expansion:|n  thisThrows() == 0|n']
 ##teamcity[testFinished name='When unchecked exceptions are thrown from functions they are always failures' duration="{duration}"]
 ##teamcity[testStarted name='When unchecked exceptions are thrown from sections they are always failures']
-##teamcity[testFailed name='When unchecked exceptions are thrown from sections they are always failures' message='-------------------------------------------------------------------------------|nsection name|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "unexpected exception"']
+##teamcity[testFailed name='When unchecked exceptions are thrown from sections they are always failures' message='-------------------------------------------------------------------------------|nsection name|n-------------------------------------------------------------------------------|nException.tests.cpp:<line number>|n...............................................................................|n|nException.tests.cpp:<line number>|nunexpected exception with message:|n  "unexpected exception"|n  {Unknown expression after the reported line}|nwith expansion:|n  {Unknown expression after the reported line}|n']
 ##teamcity[testFinished name='When unchecked exceptions are thrown from sections they are always failures' duration="{duration}"]
 ##teamcity[testStarted name='When unchecked exceptions are thrown, but caught, they do not affect the test']
 ##teamcity[testFinished name='When unchecked exceptions are thrown, but caught, they do not affect the test' duration="{duration}"]
diff --git a/tests/SelfTest/Baselines/xml.sw.approved.txt b/tests/SelfTest/Baselines/xml.sw.approved.txt
--- a/tests/SelfTest/Baselines/xml.sw.approved.txt
+++ b/tests/SelfTest/Baselines/xml.sw.approved.txt
@@ -668,19 +668,35 @@ Nor would this
     <OverallResult success="true" skips="0"/>
   </TestCase>
   <TestCase name="#2615 - Throwing in constructor generator fails test case but does not abort" tags="[!shouldfail][generators][regression]" filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
-    <Exception filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
-      failure to init
-    </Exception>
+    <Expression success="false" filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
+      <Original>
+        {Unknown expression after the reported line}
+      </Original>
+      <Expanded>
+        {Unknown expression after the reported line}
+      </Expanded>
+      <Exception filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
+        failure to init
+      </Exception>
+    </Expression>
     <OverallResult success="true" skips="0"/>
   </TestCase>
   <TestCase name="#748 - captures with unexpected exceptions" tags="[!shouldfail][!throws][.][failing]" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
     <Section name="outside assertions" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
       <Info filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
         answer := 42
       </Info>
-      <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-        expected exception
-      </Exception>
+      <Expression success="false" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+        <Original>
+          {Unknown expression after the reported line}
+        </Original>
+        <Expanded>
+          {Unknown expression after the reported line}
+        </Expanded>
+        <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+          expected exception
+        </Exception>
+      </Expression>
       <OverallResults successes="0" failures="0" expectedFailures="1" skipped="false"/>
     </Section>
     <Section name="inside REQUIRE_NOTHROW" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
@@ -18349,9 +18365,17 @@ Approx( 1.23999999999999999 )
   </TestCase>
   <TestCase name="When unchecked exceptions are thrown from sections they are always failures" tags="[!throws][.][failing]" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
     <Section name="section name" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-      <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-        unexpected exception
-      </Exception>
+      <Expression success="false" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+        <Original>
+          {Unknown expression after the reported line}
+        </Original>
+        <Expanded>
+          {Unknown expression after the reported line}
+        </Expanded>
+        <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+          unexpected exception
+        </Exception>
+      </Expression>
       <OverallResults successes="0" failures="1" expectedFailures="0" skipped="false"/>
     </Section>
     <OverallResult success="false" skips="0"/>
diff --git a/tests/SelfTest/Baselines/xml.sw.multi.approved.txt b/tests/SelfTest/Baselines/xml.sw.multi.approved.txt
--- a/tests/SelfTest/Baselines/xml.sw.multi.approved.txt
+++ b/tests/SelfTest/Baselines/xml.sw.multi.approved.txt
@@ -668,19 +668,35 @@ Nor would this
     <OverallResult success="true" skips="0"/>
   </TestCase>
   <TestCase name="#2615 - Throwing in constructor generator fails test case but does not abort" tags="[!shouldfail][generators][regression]" filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
-    <Exception filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
-      failure to init
-    </Exception>
+    <Expression success="false" filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
+      <Original>
+        {Unknown expression after the reported line}
+      </Original>
+      <Expanded>
+        {Unknown expression after the reported line}
+      </Expanded>
+      <Exception filename="tests/<exe-name>/UsageTests/Generators.tests.cpp" >
+        failure to init
+      </Exception>
+    </Expression>
     <OverallResult success="true" skips="0"/>
   </TestCase>
   <TestCase name="#748 - captures with unexpected exceptions" tags="[!shouldfail][!throws][.][failing]" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
     <Section name="outside assertions" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
       <Info filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
         answer := 42
       </Info>
-      <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-        expected exception
-      </Exception>
+      <Expression success="false" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+        <Original>
+          {Unknown expression after the reported line}
+        </Original>
+        <Expanded>
+          {Unknown expression after the reported line}
+        </Expanded>
+        <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+          expected exception
+        </Exception>
+      </Expression>
       <OverallResults successes="0" failures="0" expectedFailures="1" skipped="false"/>
     </Section>
     <Section name="inside REQUIRE_NOTHROW" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
@@ -18349,9 +18365,17 @@ Approx( 1.23999999999999999 )
   </TestCase>
   <TestCase name="When unchecked exceptions are thrown from sections they are always failures" tags="[!throws][.][failing]" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
     <Section name="section name" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-      <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
-        unexpected exception
-      </Exception>
+      <Expression success="false" filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+        <Original>
+          {Unknown expression after the reported line}
+        </Original>
+        <Expanded>
+          {Unknown expression after the reported line}
+        </Expanded>
+        <Exception filename="tests/<exe-name>/UsageTests/Exception.tests.cpp" >
+          unexpected exception
+        </Exception>
+      </Expression>
       <OverallResults successes="0" failures="1" expectedFailures="0" skipped="false"/>
     </Section>
     <OverallResult success="false" skips="0"/>
EOF_114329324912

# Create a temporary directory for approval test outputs
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Run the approval tests using the Python script
# This script will compare the patched SelfTest output against the patched baseline files
# Exit code 0 means outputs match (SUCCESS)
# Exit code 2 means differences found (FAILURE)
python3 tools/scripts/approvalTests.py build/tests/SelfTest "$TEMP_DIR"
rc=$?

# Capture and report the exit code
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the baseline files to their original state
git checkout 9be81c0e05aedabbf1224ccb424ef0a628bcb9c8 "tests/SelfTest/Baselines/compact.sw.approved.txt" "tests/SelfTest/Baselines/compact.sw.multi.approved.txt" "tests/SelfTest/Baselines/console.std.approved.txt" "tests/SelfTest/Baselines/console.sw.approved.txt" "tests/SelfTest/Baselines/console.sw.multi.approved.txt" "tests/SelfTest/Baselines/console.swa4.approved.txt" "tests/SelfTest/Baselines/junit.sw.approved.txt" "tests/SelfTest/Baselines/junit.sw.multi.approved.txt" "tests/SelfTest/Baselines/sonarqube.sw.approved.txt" "tests/SelfTest/Baselines/sonarqube.sw.multi.approved.txt" "tests/SelfTest/Baselines/tap.sw.approved.txt" "tests/SelfTest/Baselines/tap.sw.multi.approved.txt" "tests/SelfTest/Baselines/teamcity.sw.approved.txt" "tests/SelfTest/Baselines/teamcity.sw.multi.approved.txt" "tests/SelfTest/Baselines/xml.sw.approved.txt" "tests/SelfTest/Baselines/xml.sw.multi.approved.txt"

# Remove temporary directory
rm -rf "$TEMP_DIR"