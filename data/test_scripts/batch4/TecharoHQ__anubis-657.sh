#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout 7a195f1595086d2543fc9b073f15213724127b85 "internal/ogtags/mem_test.go" "internal/ogtags/ogtags_fuzz_test.go" "lib/policy/config/expressionorlist_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/cmd/robots2policy/robots2policy_test.go b/cmd/robots2policy/robots2policy_test.go
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/robots2policy_test.go
@@ -0,0 +1,418 @@
+package main
+
+import (
+	"encoding/json"
+	"fmt"
+	"os"
+	"path/filepath"
+	"reflect"
+	"strings"
+	"testing"
+
+	"gopkg.in/yaml.v3"
+)
+
+type TestCase struct {
+	name         string
+	robotsFile   string
+	expectedFile string
+	options      TestOptions
+}
+
+type TestOptions struct {
+	format           string
+	action           string
+	crawlDelayWeight int
+	policyName       string
+	deniedAction     string
+}
+
+func TestDataFileConversion(t *testing.T) {
+
+	testCases := []TestCase{
+		{
+			name:         "simple_default",
+			robotsFile:   "simple.robots.txt",
+			expectedFile: "simple.yaml",
+			options:      TestOptions{format: "yaml"},
+		},
+		{
+			name:         "simple_json",
+			robotsFile:   "simple.robots.txt",
+			expectedFile: "simple.json",
+			options:      TestOptions{format: "json"},
+		},
+		{
+			name:         "simple_deny_action",
+			robotsFile:   "simple.robots.txt",
+			expectedFile: "deny-action.yaml",
+			options:      TestOptions{format: "yaml", action: "DENY"},
+		},
+		{
+			name:         "simple_custom_name",
+			robotsFile:   "simple.robots.txt",
+			expectedFile: "custom-name.yaml",
+			options:      TestOptions{format: "yaml", policyName: "my-custom-policy"},
+		},
+		{
+			name:         "blacklist_with_crawl_delay",
+			robotsFile:   "blacklist.robots.txt",
+			expectedFile: "blacklist.yaml",
+			options:      TestOptions{format: "yaml", crawlDelayWeight: 3},
+		},
+		{
+			name:         "wildcards",
+			robotsFile:   "wildcards.robots.txt",
+			expectedFile: "wildcards.yaml",
+			options:      TestOptions{format: "yaml"},
+		},
+		{
+			name:         "empty_file",
+			robotsFile:   "empty.robots.txt",
+			expectedFile: "empty.yaml",
+			options:      TestOptions{format: "yaml"},
+		},
+		{
+			name:         "complex_scenario",
+			robotsFile:   "complex.robots.txt",
+			expectedFile: "complex.yaml",
+			options:      TestOptions{format: "yaml", crawlDelayWeight: 5},
+		},
+	}
+
+	for _, tc := range testCases {
+		t.Run(tc.name, func(t *testing.T) {
+			robotsPath := filepath.Join("testdata", tc.robotsFile)
+			expectedPath := filepath.Join("testdata", tc.expectedFile)
+
+			// Read robots.txt input
+			robotsFile, err := os.Open(robotsPath)
+			if err != nil {
+				t.Fatalf("Failed to open robots file %s: %v", robotsPath, err)
+			}
+			defer robotsFile.Close()
+
+			// Parse robots.txt
+			rules, err := parseRobotsTxt(robotsFile)
+			if err != nil {
+				t.Fatalf("Failed to parse robots.txt: %v", err)
+			}
+
+			// Set test options
+			oldFormat := *outputFormat
+			oldAction := *baseAction
+			oldCrawlDelay := *crawlDelay
+			oldPolicyName := *policyName
+			oldDeniedAction := *userAgentDeny
+
+			if tc.options.format != "" {
+				*outputFormat = tc.options.format
+			}
+			if tc.options.action != "" {
+				*baseAction = tc.options.action
+			}
+			if tc.options.crawlDelayWeight > 0 {
+				*crawlDelay = tc.options.crawlDelayWeight
+			}
+			if tc.options.policyName != "" {
+				*policyName = tc.options.policyName
+			}
+			if tc.options.deniedAction != "" {
+				*userAgentDeny = tc.options.deniedAction
+			}
+
+			// Restore options after test
+			defer func() {
+				*outputFormat = oldFormat
+				*baseAction = oldAction
+				*crawlDelay = oldCrawlDelay
+				*policyName = oldPolicyName
+				*userAgentDeny = oldDeniedAction
+			}()
+
+			// Convert to Anubis rules
+			anubisRules := convertToAnubisRules(rules)
+
+			// Generate output
+			var actualOutput []byte
+			switch strings.ToLower(*outputFormat) {
+			case "yaml":
+				actualOutput, err = yaml.Marshal(anubisRules)
+			case "json":
+				actualOutput, err = json.MarshalIndent(anubisRules, "", "  ")
+			}
+			if err != nil {
+				t.Fatalf("Failed to marshal output: %v", err)
+			}
+
+			// Read expected output
+			expectedOutput, err := os.ReadFile(expectedPath)
+			if err != nil {
+				t.Fatalf("Failed to read expected file %s: %v", expectedPath, err)
+			}
+
+			if strings.ToLower(*outputFormat) == "yaml" {
+				var actualData []interface{}
+				var expectedData []interface{}
+
+				err = yaml.Unmarshal(actualOutput, &actualData)
+				if err != nil {
+					t.Fatalf("Failed to unmarshal actual output: %v", err)
+				}
+
+				err = yaml.Unmarshal(expectedOutput, &expectedData)
+				if err != nil {
+					t.Fatalf("Failed to unmarshal expected output: %v", err)
+				}
+
+				// Compare data structures
+				if !compareData(actualData, expectedData) {
+					actualStr := strings.TrimSpace(string(actualOutput))
+					expectedStr := strings.TrimSpace(string(expectedOutput))
+					t.Errorf("Output mismatch for %s\nExpected:\n%s\n\nActual:\n%s", tc.name, expectedStr, actualStr)
+				}
+			} else {
+				var actualData []interface{}
+				var expectedData []interface{}
+
+				err = json.Unmarshal(actualOutput, &actualData)
+				if err != nil {
+					t.Fatalf("Failed to unmarshal actual JSON output: %v", err)
+				}
+
+				err = json.Unmarshal(expectedOutput, &expectedData)
+				if err != nil {
+					t.Fatalf("Failed to unmarshal expected JSON output: %v", err)
+				}
+
+				// Compare data structures
+				if !compareData(actualData, expectedData) {
+					actualStr := strings.TrimSpace(string(actualOutput))
+					expectedStr := strings.TrimSpace(string(expectedOutput))
+					t.Errorf("Output mismatch for %s\nExpected:\n%s\n\nActual:\n%s", tc.name, expectedStr, actualStr)
+				}
+			}
+		})
+	}
+}
+
+func TestCaseInsensitiveParsing(t *testing.T) {
+	robotsTxt := `User-Agent: *
+Disallow: /admin
+Crawl-Delay: 10
+
+User-agent: TestBot
+disallow: /test
+crawl-delay: 5
+
+USER-AGENT: UpperBot
+DISALLOW: /upper
+CRAWL-DELAY: 20`
+
+	reader := strings.NewReader(robotsTxt)
+	rules, err := parseRobotsTxt(reader)
+	if err != nil {
+		t.Fatalf("Failed to parse case-insensitive robots.txt: %v", err)
+	}
+
+	expectedRules := 3
+	if len(rules) != expectedRules {
+		t.Errorf("Expected %d rules, got %d", expectedRules, len(rules))
+	}
+
+	// Check that all crawl delays were parsed
+	for i, rule := range rules {
+		expectedDelays := []int{10, 5, 20}
+		if rule.CrawlDelay != expectedDelays[i] {
+			t.Errorf("Rule %d: expected crawl delay %d, got %d", i, expectedDelays[i], rule.CrawlDelay)
+		}
+	}
+}
+
+func TestVariousOutputFormats(t *testing.T) {
+	robotsTxt := `User-agent: *
+Disallow: /admin`
+
+	reader := strings.NewReader(robotsTxt)
+	rules, err := parseRobotsTxt(reader)
+	if err != nil {
+		t.Fatalf("Failed to parse robots.txt: %v", err)
+	}
+
+	oldPolicyName := *policyName
+	*policyName = "test-policy"
+	defer func() { *policyName = oldPolicyName }()
+
+	anubisRules := convertToAnubisRules(rules)
+
+	// Test YAML output
+	yamlOutput, err := yaml.Marshal(anubisRules)
+	if err != nil {
+		t.Fatalf("Failed to marshal YAML: %v", err)
+	}
+
+	if !strings.Contains(string(yamlOutput), "name: test-policy-disallow-1") {
+		t.Errorf("YAML output doesn't contain expected rule name")
+	}
+
+	// Test JSON output
+	jsonOutput, err := json.MarshalIndent(anubisRules, "", "  ")
+	if err != nil {
+		t.Fatalf("Failed to marshal JSON: %v", err)
+	}
+
+	if !strings.Contains(string(jsonOutput), `"name": "test-policy-disallow-1"`) {
+		t.Errorf("JSON output doesn't contain expected rule name")
+	}
+}
+
+func TestDifferentActions(t *testing.T) {
+	robotsTxt := `User-agent: *
+Disallow: /admin`
+
+	testActions := []string{"ALLOW", "DENY", "CHALLENGE", "WEIGH"}
+
+	for _, action := range testActions {
+		t.Run("action_"+action, func(t *testing.T) {
+			reader := strings.NewReader(robotsTxt)
+			rules, err := parseRobotsTxt(reader)
+			if err != nil {
+				t.Fatalf("Failed to parse robots.txt: %v", err)
+			}
+
+			oldAction := *baseAction
+			*baseAction = action
+			defer func() { *baseAction = oldAction }()
+
+			anubisRules := convertToAnubisRules(rules)
+
+			if len(anubisRules) != 1 {
+				t.Fatalf("Expected 1 rule, got %d", len(anubisRules))
+			}
+
+			if anubisRules[0].Action != action {
+				t.Errorf("Expected action %s, got %s", action, anubisRules[0].Action)
+			}
+		})
+	}
+}
+
+func TestPolicyNaming(t *testing.T) {
+	robotsTxt := `User-agent: *
+Disallow: /admin
+Disallow: /private
+
+User-agent: BadBot
+Disallow: /`
+
+	testNames := []string{"custom-policy", "my-rules", "site-protection"}
+
+	for _, name := range testNames {
+		t.Run("name_"+name, func(t *testing.T) {
+			reader := strings.NewReader(robotsTxt)
+			rules, err := parseRobotsTxt(reader)
+			if err != nil {
+				t.Fatalf("Failed to parse robots.txt: %v", err)
+			}
+
+			oldName := *policyName
+			*policyName = name
+			defer func() { *policyName = oldName }()
+
+			anubisRules := convertToAnubisRules(rules)
+
+			// Check that all rule names use the custom prefix
+			for _, rule := range anubisRules {
+				if !strings.HasPrefix(rule.Name, name+"-") {
+					t.Errorf("Rule name %s doesn't start with expected prefix %s-", rule.Name, name)
+				}
+			}
+		})
+	}
+}
+
+func TestCrawlDelayWeights(t *testing.T) {
+	robotsTxt := `User-agent: *
+Disallow: /admin
+Crawl-delay: 10
+
+User-agent: SlowBot
+Disallow: /slow
+Crawl-delay: 60`
+
+	testWeights := []int{1, 5, 10, 25}
+
+	for _, weight := range testWeights {
+		t.Run(fmt.Sprintf("weight_%d", weight), func(t *testing.T) {
+			reader := strings.NewReader(robotsTxt)
+			rules, err := parseRobotsTxt(reader)
+			if err != nil {
+				t.Fatalf("Failed to parse robots.txt: %v", err)
+			}
+
+			oldWeight := *crawlDelay
+			*crawlDelay = weight
+			defer func() { *crawlDelay = oldWeight }()
+
+			anubisRules := convertToAnubisRules(rules)
+
+			// Count weight rules and verify they have correct weight
+			weightRules := 0
+			for _, rule := range anubisRules {
+				if rule.Action == "WEIGH" && rule.Weight != nil {
+					weightRules++
+					if rule.Weight.Adjust != weight {
+						t.Errorf("Expected weight %d, got %d", weight, rule.Weight.Adjust)
+					}
+				}
+			}
+
+			expectedWeightRules := 2 // One for *, one for SlowBot
+			if weightRules != expectedWeightRules {
+				t.Errorf("Expected %d weight rules, got %d", expectedWeightRules, weightRules)
+			}
+		})
+	}
+}
+
+func TestBlacklistActions(t *testing.T) {
+	robotsTxt := `User-agent: BadBot
+Disallow: /
+
+User-agent: SpamBot
+Disallow: /`
+
+	testActions := []string{"DENY", "CHALLENGE"}
+
+	for _, action := range testActions {
+		t.Run("blacklist_"+action, func(t *testing.T) {
+			reader := strings.NewReader(robotsTxt)
+			rules, err := parseRobotsTxt(reader)
+			if err != nil {
+				t.Fatalf("Failed to parse robots.txt: %v", err)
+			}
+
+			oldAction := *userAgentDeny
+			*userAgentDeny = action
+			defer func() { *userAgentDeny = oldAction }()
+
+			anubisRules := convertToAnubisRules(rules)
+
+			// All rules should be blacklist rules with the specified action
+			for _, rule := range anubisRules {
+				if !strings.Contains(rule.Name, "blacklist") {
+					t.Errorf("Expected blacklist rule, got %s", rule.Name)
+				}
+				if rule.Action != action {
+					t.Errorf("Expected action %s, got %s", action, rule.Action)
+				}
+			}
+		})
+	}
+}
+
+// compareData performs a deep comparison of two data structures,
+// ignoring differences that are semantically equivalent in YAML/JSON
+func compareData(actual, expected interface{}) bool {
+	return reflect.DeepEqual(actual, expected)
+}
diff --git a/cmd/robots2policy/testdata/blacklist.robots.txt b/cmd/robots2policy/testdata/blacklist.robots.txt
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/blacklist.robots.txt
@@ -0,0 +1,15 @@
+# Test with blacklisted user agents
+User-agent: *
+Disallow: /admin
+Crawl-delay: 10
+
+User-agent: BadBot
+Disallow: /
+
+User-agent: SpamBot
+Disallow: /
+Crawl-delay: 60
+
+User-agent: Googlebot
+Disallow: /search
+Crawl-delay: 5
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/blacklist.yaml b/cmd/robots2policy/testdata/blacklist.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/blacklist.yaml
@@ -0,0 +1,30 @@
+- action: WEIGH
+  expression: "true"
+  name: robots-txt-policy-crawl-delay-1
+  weight:
+    adjust: 3
+- action: CHALLENGE
+  expression: path.startsWith("/admin")
+  name: robots-txt-policy-disallow-2
+- action: DENY
+  expression: userAgent.contains("BadBot")
+  name: robots-txt-policy-blacklist-3
+- action: WEIGH
+  expression: userAgent.contains("SpamBot")
+  name: robots-txt-policy-crawl-delay-4
+  weight:
+    adjust: 3
+- action: DENY
+  expression: userAgent.contains("SpamBot")
+  name: robots-txt-policy-blacklist-5
+- action: WEIGH
+  expression: userAgent.contains("Googlebot")
+  name: robots-txt-policy-crawl-delay-6
+  weight:
+    adjust: 3
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("Googlebot")
+        - path.startsWith("/search")
+  name: robots-txt-policy-disallow-7
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/complex.robots.txt b/cmd/robots2policy/testdata/complex.robots.txt
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/complex.robots.txt
@@ -0,0 +1,30 @@
+# Complex real-world example
+User-agent: *
+Disallow: /admin/
+Disallow: /private/
+Disallow: /api/internal/
+Allow: /api/public/
+Crawl-delay: 5
+
+User-agent: Googlebot
+Disallow: /search/
+Allow: /api/
+Crawl-delay: 2
+
+User-agent: Bingbot
+Disallow: /search/
+Disallow: /admin/
+Crawl-delay: 10
+
+User-agent: BadBot
+Disallow: /
+
+User-agent: SeoBot
+Disallow: /
+Crawl-delay: 300
+
+# Test with various patterns
+User-agent: TestBot
+Disallow: /*/admin
+Disallow: /temp*.html
+Disallow: /file?.log
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/complex.yaml b/cmd/robots2policy/testdata/complex.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/complex.yaml
@@ -0,0 +1,71 @@
+- action: WEIGH
+  expression: "true"
+  name: robots-txt-policy-crawl-delay-1
+  weight:
+    adjust: 5
+- action: CHALLENGE
+  expression: path.startsWith("/admin/")
+  name: robots-txt-policy-disallow-2
+- action: CHALLENGE
+  expression: path.startsWith("/private/")
+  name: robots-txt-policy-disallow-3
+- action: CHALLENGE
+  expression: path.startsWith("/api/internal/")
+  name: robots-txt-policy-disallow-4
+- action: WEIGH
+  expression: userAgent.contains("Googlebot")
+  name: robots-txt-policy-crawl-delay-5
+  weight:
+    adjust: 5
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("Googlebot")
+        - path.startsWith("/search/")
+  name: robots-txt-policy-disallow-6
+- action: WEIGH
+  expression: userAgent.contains("Bingbot")
+  name: robots-txt-policy-crawl-delay-7
+  weight:
+    adjust: 5
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("Bingbot")
+        - path.startsWith("/search/")
+  name: robots-txt-policy-disallow-8
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("Bingbot")
+        - path.startsWith("/admin/")
+  name: robots-txt-policy-disallow-9
+- action: DENY
+  expression: userAgent.contains("BadBot")
+  name: robots-txt-policy-blacklist-10
+- action: WEIGH
+  expression: userAgent.contains("SeoBot")
+  name: robots-txt-policy-crawl-delay-11
+  weight:
+    adjust: 5
+- action: DENY
+  expression: userAgent.contains("SeoBot")
+  name: robots-txt-policy-blacklist-12
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("TestBot")
+        - path.matches("^/.*/admin")
+  name: robots-txt-policy-disallow-13
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("TestBot")
+        - path.matches("^/temp.*\\.html")
+  name: robots-txt-policy-disallow-14
+- action: CHALLENGE
+  expression:
+    all:
+        - userAgent.contains("TestBot")
+        - path.matches("^/file.\\.log")
+  name: robots-txt-policy-disallow-15
diff --git a/cmd/robots2policy/testdata/custom-name.yaml b/cmd/robots2policy/testdata/custom-name.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/custom-name.yaml
@@ -0,0 +1,6 @@
+- action: CHALLENGE
+  expression: path.startsWith("/admin/")
+  name: my-custom-policy-disallow-1
+- action: CHALLENGE
+  expression: path.startsWith("/private")
+  name: my-custom-policy-disallow-2
diff --git a/cmd/robots2policy/testdata/deny-action.yaml b/cmd/robots2policy/testdata/deny-action.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/deny-action.yaml
@@ -0,0 +1,6 @@
+- action: DENY
+  expression: path.startsWith("/admin/")
+  name: robots-txt-policy-disallow-1
+- action: DENY
+  expression: path.startsWith("/private")
+  name: robots-txt-policy-disallow-2
diff --git a/cmd/robots2policy/testdata/empty.robots.txt b/cmd/robots2policy/testdata/empty.robots.txt
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/empty.robots.txt
@@ -0,0 +1,2 @@
+# Empty robots.txt (comments only)
+# No actual rules
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/empty.yaml b/cmd/robots2policy/testdata/empty.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/empty.yaml
@@ -0,0 +1 @@
+[]
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/simple.json b/cmd/robots2policy/testdata/simple.json
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/simple.json
@@ -0,0 +1,12 @@
+[
+  {
+    "action": "CHALLENGE",
+    "expression": "path.startsWith(\"/admin/\")",
+    "name": "robots-txt-policy-disallow-1"
+  },
+  {
+    "action": "CHALLENGE",
+    "expression": "path.startsWith(\"/private\")",
+    "name": "robots-txt-policy-disallow-2"
+  }
+]
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/simple.robots.txt b/cmd/robots2policy/testdata/simple.robots.txt
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/simple.robots.txt
@@ -0,0 +1,5 @@
+# Simple robots.txt test
+User-agent: *
+Disallow: /admin/
+Disallow: /private
+Allow: /public
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/simple.yaml b/cmd/robots2policy/testdata/simple.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/simple.yaml
@@ -0,0 +1,6 @@
+- action: CHALLENGE
+  expression: path.startsWith("/admin/")
+  name: robots-txt-policy-disallow-1
+- action: CHALLENGE
+  expression: path.startsWith("/private")
+  name: robots-txt-policy-disallow-2
diff --git a/cmd/robots2policy/testdata/wildcards.robots.txt b/cmd/robots2policy/testdata/wildcards.robots.txt
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/wildcards.robots.txt
@@ -0,0 +1,6 @@
+# Test wildcard patterns
+User-agent: *
+Disallow: /search*
+Disallow: /*/private
+Disallow: /file?.txt
+Disallow: /admin/*?action=delete
\ No newline at end of file
diff --git a/cmd/robots2policy/testdata/wildcards.yaml b/cmd/robots2policy/testdata/wildcards.yaml
new file mode 100644
--- /dev/null
+++ b/cmd/robots2policy/testdata/wildcards.yaml
@@ -0,0 +1,12 @@
+- action: CHALLENGE
+  expression: path.matches("^/search.*")
+  name: robots-txt-policy-disallow-1
+- action: CHALLENGE
+  expression: path.matches("^/.*/private")
+  name: robots-txt-policy-disallow-2
+- action: CHALLENGE
+  expression: path.matches("^/file.\\.txt")
+  name: robots-txt-policy-disallow-3
+- action: CHALLENGE
+  expression: path.matches("^/admin/.*.action=delete")
+  name: robots-txt-policy-disallow-4
diff --git a/internal/ogtags/mem_test.go b/internal/ogtags/mem_test.go
--- a/internal/ogtags/mem_test.go
+++ b/internal/ogtags/mem_test.go
@@ -1,11 +1,12 @@
 package ogtags
 
 import (
-	"golang.org/x/net/html"
 	"net/url"
 	"runtime"
 	"strings"
 	"testing"
+
+	"golang.org/x/net/html"
 )
 
 func BenchmarkGetTarget(b *testing.B) {
diff --git a/internal/ogtags/ogtags_fuzz_test.go b/internal/ogtags/ogtags_fuzz_test.go
--- a/internal/ogtags/ogtags_fuzz_test.go
+++ b/internal/ogtags/ogtags_fuzz_test.go
@@ -1,11 +1,12 @@
 package ogtags
 
 import (
-	"golang.org/x/net/html"
 	"net/url"
 	"strings"
 	"testing"
 	"unicode/utf8"
+
+	"golang.org/x/net/html"
 )
 
 // FuzzGetTarget tests getTarget with various inputs
diff --git a/lib/policy/config/expressionorlist_test.go b/lib/policy/config/expressionorlist_test.go
--- a/lib/policy/config/expressionorlist_test.go
+++ b/lib/policy/config/expressionorlist_test.go
@@ -1,12 +1,147 @@
 package config
 
 import (
+	"bytes"
 	"encoding/json"
 	"errors"
 	"testing"
+
+	yaml "sigs.k8s.io/yaml/goyaml.v3"
 )
 
-func TestExpressionOrListUnmarshal(t *testing.T) {
+func TestExpressionOrListMarshalJSON(t *testing.T) {
+	for _, tt := range []struct {
+		name   string
+		input  *ExpressionOrList
+		output []byte
+		err    error
+	}{
+		{
+			name: "single expression",
+			input: &ExpressionOrList{
+				Expression: "true",
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+		{
+			name: "all",
+			input: &ExpressionOrList{
+				All: []string{"true", "true"},
+			},
+			output: []byte(`{"all":["true","true"]}`),
+			err:    nil,
+		},
+		{
+			name: "all one",
+			input: &ExpressionOrList{
+				All: []string{"true"},
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+		{
+			name: "any",
+			input: &ExpressionOrList{
+				Any: []string{"true", "false"},
+			},
+			output: []byte(`{"any":["true","false"]}`),
+			err:    nil,
+		},
+		{
+			name: "any one",
+			input: &ExpressionOrList{
+				Any: []string{"true"},
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+	} {
+		t.Run(tt.name, func(t *testing.T) {
+			result, err := json.Marshal(tt.input)
+			if !errors.Is(err, tt.err) {
+				t.Errorf("wanted marshal error: %v but got: %v", tt.err, err)
+			}
+
+			if !bytes.Equal(result, tt.output) {
+				t.Logf("wanted: %s", string(tt.output))
+				t.Logf("got:    %s", string(result))
+				t.Error("mismatched output")
+			}
+		})
+	}
+}
+
+func TestExpressionOrListMarshalYAML(t *testing.T) {
+	for _, tt := range []struct {
+		name   string
+		input  *ExpressionOrList
+		output []byte
+		err    error
+	}{
+		{
+			name: "single expression",
+			input: &ExpressionOrList{
+				Expression: "true",
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+		{
+			name: "all",
+			input: &ExpressionOrList{
+				All: []string{"true", "true"},
+			},
+			output: []byte(`all:
+    - "true"
+    - "true"`),
+			err: nil,
+		},
+		{
+			name: "all one",
+			input: &ExpressionOrList{
+				All: []string{"true"},
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+		{
+			name: "any",
+			input: &ExpressionOrList{
+				Any: []string{"true", "false"},
+			},
+			output: []byte(`any:
+    - "true"
+    - "false"`),
+			err: nil,
+		},
+		{
+			name: "any one",
+			input: &ExpressionOrList{
+				Any: []string{"true"},
+			},
+			output: []byte(`"true"`),
+			err:    nil,
+		},
+	} {
+		t.Run(tt.name, func(t *testing.T) {
+			result, err := yaml.Marshal(tt.input)
+			if !errors.Is(err, tt.err) {
+				t.Errorf("wanted marshal error: %v but got: %v", tt.err, err)
+			}
+
+			result = bytes.TrimSpace(result)
+
+			if !bytes.Equal(result, tt.output) {
+				t.Logf("wanted: %q", string(tt.output))
+				t.Logf("got:    %q", string(result))
+				t.Error("mismatched output")
+			}
+		})
+	}
+}
+
+func TestExpressionOrListUnmarshalJSON(t *testing.T) {
 	for _, tt := range []struct {
 		err      error
 		validErr error
EOF_114329324912

# Set Go environment variables (ensure they're available in this shell)
export PATH=/usr/local/go/bin:$GOPATH/bin:/testbed/node_modules/.bin:$PATH
export GOPATH=/go

# Run the target tests
# Note: Running tests at package level to include all necessary source files
go test -v ./internal/ogtags/ ./lib/policy/config/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 7a195f1595086d2543fc9b073f15213724127b85 "internal/ogtags/mem_test.go" "internal/ogtags/ogtags_fuzz_test.go" "lib/policy/config/expressionorlist_test.go"