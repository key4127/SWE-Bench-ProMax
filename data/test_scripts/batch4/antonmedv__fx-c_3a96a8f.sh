#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure we're on the correct commit
git checkout 9611f375a82db8f9352a25cf9817814265459584

# Checkout the target test file to ensure clean state
git checkout 9611f375a82db8f9352a25cf9817814265459584 "search_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/search_test.go b/search_test.go
--- a/search_test.go
+++ b/search_test.go
@@ -6,11 +6,37 @@ import (
 	"testing"
 	"time"
 
-	. "github.com/antonmedv/fx/internal/jsonx"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
+
+	. "github.com/antonmedv/fx/internal/jsonx"
 )
 
+// doSearch is a test helper that performs a synchronous search using executeSearch.
+func doSearch(m *model, s string) {
+	if s == "" {
+		return
+	}
+
+	// Check cache first
+	if cachedSearch, _, found := m.searchCache.get(s); found {
+		m.search = cachedSearch
+		m.selectSearchResult(0)
+		return
+	}
+
+	result, re, err := executeSearch(m.top, s, nil)
+	if err != nil {
+		m.search = newSearch()
+		m.search.err = err
+		return
+	}
+
+	m.search = result
+	m.searchCache.put(s, re, m.search)
+	m.selectSearchResult(0)
+}
+
 func TestBasicSearch(t *testing.T) {
 	jsonData := `{
 		"name": "John Doe",
@@ -46,7 +72,7 @@ func TestBasicSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearchSync(tc.searchTerm)
+			doSearch(m, tc.searchTerm)
 
 			if tc.expectedResults == 0 {
 				assert.Equal(t, 0, len(m.search.results), "Should find no results for: %s", tc.searchTerm)
@@ -114,7 +140,7 @@ func TestRegexSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearchSync(tc.pattern)
+			doSearch(m, tc.pattern)
 
 			if tc.shouldMatch {
 				assert.Nil(t, m.search.err, "Pattern should be valid: %s", tc.pattern)
@@ -160,7 +186,7 @@ func TestCaseInsensitiveSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearchSync(tc.searchTerm)
+			doSearch(m, tc.searchTerm)
 
 			// Case insensitive search should find matches regardless of case
 			assert.Greater(t, len(m.search.results), 0, "Should find case-insensitive match for: %s", tc.searchTerm)
@@ -209,7 +235,7 @@ func TestSearchInDifferentNodeTypes(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearchSync(tc.searchTerm)
+			doSearch(m, tc.searchTerm)
 
 			assert.Greater(t, len(m.search.results), 0, "Should find %s in %s", tc.searchTerm, tc.nodeType)
 			assert.Nil(t, m.search.err, "Search should not error")
@@ -234,7 +260,7 @@ func TestSearchResultDetails(t *testing.T) {
 	}
 
 	// Test multiple matches in same value
-	m.doSearchSync("fox")
+	doSearch(m, "fox")
 
 	assert.Greater(t, len(m.search.results), 0, "Should find fox matches")
 	assert.Nil(t, m.search.err, "Search should not error")
@@ -272,7 +298,7 @@ func TestSearchNavigation(t *testing.T) {
 	}
 
 	// Search for term with multiple matches
-	m.doSearchSync("apple")
+	doSearch(m, "apple")
 
 	require.Greater(t, len(m.search.results), 1, "Should find multiple apple matches")
 
@@ -332,7 +358,7 @@ func TestSpecialCharacterSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearchSync(tc.searchTerm)
+			doSearch(m, tc.searchTerm)
 
 			// Should either find matches or have valid regex (no panic)
 			assert.Nil(t, m.search.err, "Should handle special characters without error: %s", tc.searchTerm)
@@ -369,7 +395,7 @@ func TestEmptyAndEdgeCases(t *testing.T) {
 				searchCache: newSearchCache(1),
 			}
 
-			m.doSearchSync(tc.searchTerm)
+			doSearch(m, tc.searchTerm)
 
 			// Should not panic or error on edge cases
 			assert.Nil(t, m.search.err, "Should handle edge case without error")
@@ -416,12 +442,12 @@ func TestLargeJSONSearch(t *testing.T) {
 	}
 
 	// Test that search completes in reasonable time
-	m.doSearchSync("User")
+	doSearch(m, "User")
 	assert.Greater(t, len(m.search.results), 0, "Should find users in large JSON")
 	assert.Nil(t, m.search.err, "Should not error on large JSON")
 
 	// Test repeated terms
-	m.doSearchSync("test")
+	doSearch(m, "test")
 	assert.Greater(t, len(m.search.results), 3, "Should find multiple instances of repeated term")
 }
 
@@ -462,28 +488,28 @@ func TestSearchCaching(t *testing.T) {
 
 	searchTerm := "alice"
 	start := time.Now()
-	m.doSearchSync(searchTerm)
+	doSearch(m, searchTerm)
 	firstSearchTime := time.Since(start)
 
 	// Verify results found
 	assert.Greater(t, len(m.search.results), 0, "Should find search results for 'alice'")
 	assert.Nil(t, m.search.err, "Search should not have errors")
 
 	start = time.Now()
-	m.doSearchSync(searchTerm)
+	doSearch(m, searchTerm)
 	cachedSearchTime := time.Since(start)
 
 	assert.Less(t, cachedSearchTime, firstSearchTime/10, "Cached search should be at least 10x faster")
 	assert.Greater(t, len(m.search.results), 0, "Cached search should return same results")
 
 	start = time.Now()
-	m.doSearchSync("admin")
+	doSearch(m, "admin")
 	secondSearchTime := time.Since(start)
 
 	assert.Greater(t, len(m.search.results), 0, "Should find results for 'admin'")
 
 	start = time.Now()
-	m.doSearchSync(searchTerm)
+	doSearch(m, searchTerm)
 	secondCachedTime := time.Since(start)
 
 	assert.Less(t, secondCachedTime, firstSearchTime/5, "Second cache hit should also be very fast")
@@ -529,13 +555,13 @@ func TestSearchCacheWithComplexPatterns(t *testing.T) {
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
 			start := time.Now()
-			m.doSearchSync(tc.pattern)
+			doSearch(m, tc.pattern)
 			firstTime := time.Since(start)
 
 			assert.Nil(t, m.search.err, "Pattern should compile successfully: %s", tc.pattern)
 
 			start = time.Now()
-			m.doSearchSync(tc.pattern)
+			doSearch(m, tc.pattern)
 			cachedTime := time.Since(start)
 
 			assert.Less(t, cachedTime, firstTime, "Cached search should be faster for pattern: %s", tc.pattern)
@@ -558,21 +584,21 @@ func TestSearchCacheInvalidation(t *testing.T) {
 		termWidth:   80,
 	}
 
-	m.doSearchSync("test")
+	doSearch(m, "test")
 	assert.Equal(t, 1, m.searchCache.size(), "Should have 1 cached entry")
 
 	m.searchCache.invalidate() // Simulates new JSON data arriving
 	_, _, found := m.searchCache.get("test")
 	assert.False(t, found, "Cache should be invalidated after new data")
 
-	m.doSearchSync("test")
+	doSearch(m, "test")
 	assert.Equal(t, 1, m.searchCache.size(), "Should cache again after invalidation")
 
 	m.searchCache.invalidate() // Simulates wrap toggle
 	_, _, found = m.searchCache.get("test")
 	assert.False(t, found, "Cache should be invalidated after wrap toggle")
 
-	m.doSearchSync("test") // Re-cache
+	doSearch(m, "test") // Re-cache
 	oldTermWidth := m.termWidth
 	m.termWidth = 120
 
@@ -597,12 +623,12 @@ func TestSearchCacheLRUEviction(t *testing.T) {
 		searchCache: newSearchCache(3),
 	}
 
-	m.doSearchSync("a")
-	m.doSearchSync("b")
-	m.doSearchSync("c")
+	doSearch(m, "a")
+	doSearch(m, "b")
+	doSearch(m, "c")
 	assert.Equal(t, 3, m.searchCache.size(), "Cache should be full")
 
-	m.doSearchSync("d")
+	doSearch(m, "d")
 	assert.Equal(t, 3, m.searchCache.size(), "Cache should still be at max size")
 
 	// "a" should be evicted (oldest)
@@ -649,7 +675,7 @@ func BenchmarkSearchCaching(b *testing.B) {
 		for i := 0; i < b.N; i++ {
 			// Use different search terms to avoid cache hits
 			searchTerm := fmt.Sprintf("user-%d", i%100)
-			m.doSearchSync(searchTerm)
+			doSearch(m, searchTerm)
 		}
 	})
 
@@ -665,7 +691,7 @@ func BenchmarkSearchCaching(b *testing.B) {
 		for i := 0; i < b.N; i++ {
 			// Reuse search terms to get cache hits
 			searchTerm := fmt.Sprintf("user-%d", i%10) // Only 10 different terms
-			m.doSearchSync(searchTerm)
+			doSearch(m, searchTerm)
 		}
 	})
 }
@@ -709,15 +735,15 @@ func TestCacheDemo(t *testing.T) {
 	fmt.Println("\nFirst run (cache misses):")
 	for _, search := range searches {
 		start := time.Now()
-		m.doSearchSync(search)
+		doSearch(m, search)
 		duration := time.Since(start)
 		fmt.Printf("  Search '%s': %v (%d results)\n", search, duration, len(m.search.results))
 	}
 
 	fmt.Println("\nSecond run (cache hits):")
 	for _, search := range searches {
 		start := time.Now()
-		m.doSearchSync(search)
+		doSearch(m, search)
 		duration := time.Since(start)
 		fmt.Printf("  Search '%s': %v (%d results) [CACHED]\n", search, duration, len(m.search.results))
 	}
EOF_114329324912

# Set Go environment variables
export GO111MODULE=on
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Verify Go environment
go version
go env

# Run tests in the current package context
# This ensures all package files are included, resolving dependencies like model, regexCase, and safeSlice
# Using -run flag to target tests from search_test.go specifically
go test -v -run=TestSearch .

# Capture exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset to original state
git checkout 9611f375a82db8f9352a25cf9817814265459584 "search_test.go"