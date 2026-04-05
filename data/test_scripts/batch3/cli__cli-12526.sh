#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 38578f7991220aae7829384708edfc9ca4b98201

# Checkout the specific test files to ensure they're in the correct state
git checkout 38578f7991220aae7829384708edfc9ca4b98201 "internal/prompter/accessible_prompter_test.go" "internal/prompter/test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/prompter/accessible_prompter_test.go b/internal/prompter/accessible_prompter_test.go
--- a/internal/prompter/accessible_prompter_test.go
+++ b/internal/prompter/accessible_prompter_test.go
@@ -228,26 +228,36 @@ func TestAccessiblePrompter(t *testing.T) {
 		console := newTestVirtualTerminal(t)
 		p := newTestAccessiblePrompter(t, console)
 		persistentOptions := []string{"persistent-option-1"}
-		searchFunc := func(input string) ([]string, []string, int, error) {
-			var searchResultKeys []string
-			var searchResultLabels []string
-
-			// Initial search with no input
-			if input == "" {
-				moreResults := 2
-				searchResultKeys = []string{"initial-result-1", "initial-result-2"}
-				searchResultLabels = []string{"Initial Result Label 1", "Initial Result Label 2"}
-				return searchResultKeys, searchResultLabels, moreResults, nil
+	searchFunc := func(input string) prompter.MultiSelectSearchResult {
+		var searchResultKeys []string
+		var searchResultLabels []string
+
+		// Initial search with no input
+		if input == "" {
+			moreResults := 2
+			searchResultKeys = []string{"initial-result-1", "initial-result-2"}
+			searchResultLabels = []string{"Initial Result Label 1", "Initial Result Label 2"}
+			return prompter.MultiSelectSearchResult{
+				Keys:        searchResultKeys,
+				Labels:      searchResultLabels,
+				MoreResults: moreResults,
+				Err:         nil,
 			}
+		}
 
-			// Subsequent search with input
-			moreResults := 0
-			searchResultKeys = []string{"search-result-1", "search-result-2"}
-			searchResultLabels = []string{"Search Result Label 1", "Search Result Label 2"}
-			return searchResultKeys, searchResultLabels, moreResults, nil
+		// Subsequent search with input
+		moreResults := 0
+		searchResultKeys = []string{"search-result-1", "search-result-2"}
+		searchResultLabels = []string{"Search Result Label 1", "Search Result Label 2"}
+		return prompter.MultiSelectSearchResult{
+			Keys:        searchResultKeys,
+			Labels:      searchResultLabels,
+			MoreResults: moreResults,
+			Err:         nil,
 		}
+	}
 
-		go func() {
+	go func() {
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Select an option \r\n")
 			require.NoError(t, err)
@@ -291,16 +301,26 @@ func TestAccessiblePrompter(t *testing.T) {
 		initialSearchResultKeys := []string{"initial-result-1"}
 		initialSearchResultLabels := []string{"Initial Result Label 1"}
 		defaultOptions := initialSearchResultKeys
-		searchFunc := func(input string) ([]string, []string, int, error) {
+		searchFunc := func(input string) prompter.MultiSelectSearchResult {
 			// Initial search with no input
 			if input == "" {
 				moreResults := 2
-				return initialSearchResultKeys, initialSearchResultLabels, moreResults, nil
+				return prompter.MultiSelectSearchResult{
+					Keys:        initialSearchResultKeys,
+					Labels:      initialSearchResultLabels,
+					MoreResults: moreResults,
+					Err:         nil,
+				}
 			}
 
 			// No search selected, so this should fail the test.
 			t.FailNow()
-			return nil, nil, 0, nil
+			return prompter.MultiSelectSearchResult{
+				Keys:        nil,
+				Labels:      nil,
+				MoreResults: 0,
+				Err:         nil,
+			}
 		}
 
 		go func() {
@@ -325,21 +345,36 @@ func TestAccessiblePrompter(t *testing.T) {
 		moreResultKeys := []string{"more-result-1"}
 		moreResultLabels := []string{"More Result Label 1"}
 
-		searchFunc := func(input string) ([]string, []string, int, error) {
+		searchFunc := func(input string) prompter.MultiSelectSearchResult {
 			// Initial search with no input
 			if input == "" {
 				moreResults := 2
-				return initialSearchResultKeys, initialSearchResultLabels, moreResults, nil
+				return prompter.MultiSelectSearchResult{
+					Keys:        initialSearchResultKeys,
+					Labels:      initialSearchResultLabels,
+					MoreResults: moreResults,
+					Err:         nil,
+				}
 			}
 
 			// Subsequent search with input "more"
 			if input == "more" {
-				return moreResultKeys, moreResultLabels, 0, nil
+				return prompter.MultiSelectSearchResult{
+					Keys:        moreResultKeys,
+					Labels:      moreResultLabels,
+					MoreResults: 0,
+					Err:         nil,
+				}
 			}
 
 			// No other searches expected
 			t.FailNow()
-			return nil, nil, 0, nil
+			return prompter.MultiSelectSearchResult{
+				Keys:        nil,
+				Labels:      nil,
+				MoreResults: 0,
+				Err:         nil,
+			}
 		}
 
 		go func() {
diff --git a/internal/prompter/test.go b/internal/prompter/test.go
--- a/internal/prompter/test.go
+++ b/internal/prompter/test.go
@@ -99,7 +99,7 @@ func (m *MockPrompter) MarkdownEditor(prompt, defaultValue string, blankAllowed
 	return s.fn(prompt, defaultValue, blankAllowed)
 }
 
-func (m *MockPrompter) MultiSelectWithSearch(prompt, searchPrompt string, defaults []string, persistentOptions []string, searchFunc func(string) ([]string, []string, int, error)) ([]string, error) {
+func (m *MockPrompter) MultiSelectWithSearch(prompt, searchPrompt string, defaults []string, persistentOptions []string, searchFunc func(string) MultiSelectSearchResult) ([]string, error) {
 	var s multiSelectWithSearchStub
 	if len(m.multiSelectWithSearchStubs) == 0 {
 		return nil, NoSuchPromptErr(prompt)
EOF_114329324912

# Run the target test files
# Using the test command identified by the context retrieval agent
# Running tests for the specific package containing the target test files
# Note: test.go is a helper file, not a test file itself, but we include it in the package test
go test -v ./internal/prompter/

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 38578f7991220aae7829384708edfc9ca4b98201 "internal/prompter/accessible_prompter_test.go" "internal/prompter/test.go"