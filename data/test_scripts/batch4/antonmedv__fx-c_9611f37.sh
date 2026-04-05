#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure we're on the correct commit
git checkout 0d305e796d6337c267432d2e24064a341532d3ca

# Checkout the target test file to ensure clean state
git checkout 0d305e796d6337c267432d2e24064a341532d3ca "search_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/search_test.go b/search_test.go
--- a/search_test.go
+++ b/search_test.go
@@ -46,7 +46,7 @@ func TestBasicSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearch(tc.searchTerm)
+			m.doSearchSync(tc.searchTerm)
 
 			if tc.expectedResults == 0 {
 				assert.Equal(t, 0, len(m.search.results), "Should find no results for: %s", tc.searchTerm)
@@ -114,7 +114,7 @@ func TestRegexSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearch(tc.pattern)
+			m.doSearchSync(tc.pattern)
 
 			if tc.shouldMatch {
 				assert.Nil(t, m.search.err, "Pattern should be valid: %s", tc.pattern)
@@ -160,7 +160,7 @@ func TestCaseInsensitiveSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearch(tc.searchTerm)
+			m.doSearchSync(tc.searchTerm)
 
 			// Case insensitive search should find matches regardless of case
 			assert.Greater(t, len(m.search.results), 0, "Should find case-insensitive match for: %s", tc.searchTerm)
@@ -209,7 +209,7 @@ func TestSearchInDifferentNodeTypes(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearch(tc.searchTerm)
+			m.doSearchSync(tc.searchTerm)
 
 			assert.Greater(t, len(m.search.results), 0, "Should find %s in %s", tc.searchTerm, tc.nodeType)
 			assert.Nil(t, m.search.err, "Search should not error")
@@ -234,7 +234,7 @@ func TestSearchResultDetails(t *testing.T) {
 	}
 
 	// Test multiple matches in same value
-	m.doSearch("fox")
+	m.doSearchSync("fox")
 
 	assert.Greater(t, len(m.search.results), 0, "Should find fox matches")
 	assert.Nil(t, m.search.err, "Search should not error")
@@ -272,7 +272,7 @@ func TestSearchNavigation(t *testing.T) {
 	}
 
 	// Search for term with multiple matches
-	m.doSearch("apple")
+	m.doSearchSync("apple")
 
 	require.Greater(t, len(m.search.results), 1, "Should find multiple apple matches")
 
@@ -332,7 +332,7 @@ func TestSpecialCharacterSearch(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
-			m.doSearch(tc.searchTerm)
+			m.doSearchSync(tc.searchTerm)
 
 			// Should either find matches or have valid regex (no panic)
 			assert.Nil(t, m.search.err, "Should handle special characters without error: %s", tc.searchTerm)
@@ -369,7 +369,7 @@ func TestEmptyAndEdgeCases(t *testing.T) {
 				searchCache: newSearchCache(1),
 			}
 
-			m.doSearch(tc.searchTerm)
+			m.doSearchSync(tc.searchTerm)
 
 			// Should not panic or error on edge cases
 			assert.Nil(t, m.search.err, "Should handle edge case without error")
@@ -416,12 +416,12 @@ func TestLargeJSONSearch(t *testing.T) {
 	}
 
 	// Test that search completes in reasonable time
-	m.doSearch("User")
+	m.doSearchSync("User")
 	assert.Greater(t, len(m.search.results), 0, "Should find users in large JSON")
 	assert.Nil(t, m.search.err, "Should not error on large JSON")
 
 	// Test repeated terms
-	m.doSearch("test")
+	m.doSearchSync("test")
 	assert.Greater(t, len(m.search.results), 3, "Should find multiple instances of repeated term")
 }
 
@@ -462,28 +462,28 @@ func TestSearchCaching(t *testing.T) {
 
 	searchTerm := "alice"
 	start := time.Now()
-	m.doSearch(searchTerm)
+	m.doSearchSync(searchTerm)
 	firstSearchTime := time.Since(start)
 
 	// Verify results found
 	assert.Greater(t, len(m.search.results), 0, "Should find search results for 'alice'")
 	assert.Nil(t, m.search.err, "Search should not have errors")
 
 	start = time.Now()
-	m.doSearch(searchTerm)
+	m.doSearchSync(searchTerm)
 	cachedSearchTime := time.Since(start)
 
 	assert.Less(t, cachedSearchTime, firstSearchTime/10, "Cached search should be at least 10x faster")
 	assert.Greater(t, len(m.search.results), 0, "Cached search should return same results")
 
 	start = time.Now()
-	m.doSearch("admin")
+	m.doSearchSync("admin")
 	secondSearchTime := time.Since(start)
 
 	assert.Greater(t, len(m.search.results), 0, "Should find results for 'admin'")
 
 	start = time.Now()
-	m.doSearch(searchTerm)
+	m.doSearchSync(searchTerm)
 	secondCachedTime := time.Since(start)
 
 	assert.Less(t, secondCachedTime, firstSearchTime/5, "Second cache hit should also be very fast")
@@ -529,13 +529,13 @@ func TestSearchCacheWithComplexPatterns(t *testing.T) {
 	for _, tc := range testCases {
 		t.Run(tc.description, func(t *testing.T) {
 			start := time.Now()
-			m.doSearch(tc.pattern)
+			m.doSearchSync(tc.pattern)
 			firstTime := time.Since(start)
 
 			assert.Nil(t, m.search.err, "Pattern should compile successfully: %s", tc.pattern)
 
 			start = time.Now()
-			m.doSearch(tc.pattern)
+			m.doSearchSync(tc.pattern)
 			cachedTime := time.Since(start)
 
 			assert.Less(t, cachedTime, firstTime, "Cached search should be faster for pattern: %s", tc.pattern)
@@ -558,21 +558,21 @@ func TestSearchCacheInvalidation(t *testing.T) {
 		termWidth:   80,
 	}
 
-	m.doSearch("test")
+	m.doSearchSync("test")
 	assert.Equal(t, 1, m.searchCache.size(), "Should have 1 cached entry")
 
 	m.searchCache.invalidate() // Simulates new JSON data arriving
 	_, _, found := m.searchCache.get("test")
 	assert.False(t, found, "Cache should be invalidated after new data")
 
-	m.doSearch("test")
+	m.doSearchSync("test")
 	assert.Equal(t, 1, m.searchCache.size(), "Should cache again after invalidation")
 
 	m.searchCache.invalidate() // Simulates wrap toggle
 	_, _, found = m.searchCache.get("test")
 	assert.False(t, found, "Cache should be invalidated after wrap toggle")
 
-	m.doSearch("test") // Re-cache
+	m.doSearchSync("test") // Re-cache
 	oldTermWidth := m.termWidth
 	m.termWidth = 120
 
@@ -597,12 +597,12 @@ func TestSearchCacheLRUEviction(t *testing.T) {
 		searchCache: newSearchCache(3),
 	}
 
-	m.doSearch("a")
-	m.doSearch("b")
-	m.doSearch("c")
+	m.doSearchSync("a")
+	m.doSearchSync("b")
+	m.doSearchSync("c")
 	assert.Equal(t, 3, m.searchCache.size(), "Cache should be full")
 
-	m.doSearch("d")
+	m.doSearchSync("d")
 	assert.Equal(t, 3, m.searchCache.size(), "Cache should still be at max size")
 
 	// "a" should be evicted (oldest)
@@ -649,7 +649,7 @@ func BenchmarkSearchCaching(b *testing.B) {
 		for i := 0; i < b.N; i++ {
 			// Use different search terms to avoid cache hits
 			searchTerm := fmt.Sprintf("user-%d", i%100)
-			m.doSearch(searchTerm)
+			m.doSearchSync(searchTerm)
 		}
 	})
 
@@ -665,7 +665,7 @@ func BenchmarkSearchCaching(b *testing.B) {
 		for i := 0; i < b.N; i++ {
 			// Reuse search terms to get cache hits
 			searchTerm := fmt.Sprintf("user-%d", i%10) // Only 10 different terms
-			m.doSearch(searchTerm)
+			m.doSearchSync(searchTerm)
 		}
 	})
 }
@@ -709,15 +709,15 @@ func TestCacheDemo(t *testing.T) {
 	fmt.Println("\nFirst run (cache misses):")
 	for _, search := range searches {
 		start := time.Now()
-		m.doSearch(search)
+		m.doSearchSync(search)
 		duration := time.Since(start)
 		fmt.Printf("  Search '%s': %v (%d results)\n", search, duration, len(m.search.results))
 	}
 
 	fmt.Println("\nSecond run (cache hits):")
 	for _, search := range searches {
 		start := time.Now()
-		m.doSearch(search)
+		m.doSearchSync(search)
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

# Run the specific test file
# Note: Since search_test.go is in the main package, we need to run tests for the entire package
# Using -run flag to ensure we only run tests from search_test.go if needed
# However, Go's test runner will automatically pick up search_test.go when we run tests in the current directory
go test -v -run=. .

# Capture exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset to original state
git checkout 0d305e796d6337c267432d2e24064a341532d3ca "search_test.go"