#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout target test files to ensure clean state
git checkout 60882473c933131a4cd78ed2eb3a4a3ff591c430 "internal/ui/list/example_test.go" "internal/ui/list/item_test.go" "internal/ui/list/list_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/ui/list/example_test.go b/internal/ui/list/example_test.go
--- a/internal/ui/list/example_test.go
+++ b/internal/ui/list/example_test.go
@@ -12,15 +12,15 @@ import (
 func Example_basic() {
 	// Create some items
 	items := []list.Item{
-		list.NewStringItem("1", "First item"),
-		list.NewStringItem("2", "Second item"),
-		list.NewStringItem("3", "Third item"),
+		list.NewStringItem("First item"),
+		list.NewStringItem("Second item"),
+		list.NewStringItem("Third item"),
 	}
 
 	// Create a list with options
 	l := list.New(items...)
 	l.SetSize(80, 10)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 	if true {
 		l.Focus()
 	}
@@ -109,7 +109,7 @@ func Example_focusable() {
 	// Create list with first item selected and focused
 	l := list.New(items...)
 	l.SetSize(80, 20)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 	if true {
 		l.Focus()
 	}
@@ -127,8 +127,8 @@ func Example_focusable() {
 // Example demonstrates dynamic item updates.
 func Example_dynamicUpdates() {
 	items := []list.Item{
-		list.NewStringItem("1", "Item 1"),
-		list.NewStringItem("2", "Item 2"),
+		list.NewStringItem("Item 1"),
+		list.NewStringItem("Item 2"),
 	}
 
 	l := list.New(items...)
@@ -140,13 +140,13 @@ func Example_dynamicUpdates() {
 	l.Draw(&screen, area)
 
 	// Update an item
-	l.UpdateItem("2", list.NewStringItem("2", "Updated Item 2"))
+	l.UpdateItem(2, list.NewStringItem("Updated Item 2"))
 
 	// Draw again - only changed item is re-rendered
 	l.Draw(&screen, area)
 
 	// Append a new item
-	l.AppendItem(list.NewStringItem("3", "New Item 3"))
+	l.AppendItem(list.NewStringItem("New Item 3"))
 
 	// Draw again - master buffer grows efficiently
 	l.Draw(&screen, area)
@@ -161,15 +161,14 @@ func Example_scrolling() {
 	items := make([]list.Item, 100)
 	for i := range items {
 		items[i] = list.NewStringItem(
-			fmt.Sprintf("%d", i),
 			fmt.Sprintf("Item %d", i),
 		)
 	}
 
 	// Create list with small viewport
 	l := list.New(items...)
 	l.SetSize(80, 10)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 
 	// Draw initial view (shows items 0-9)
 	screen := uv.NewScreenBuffer(80, 10)
@@ -181,7 +180,7 @@ func Example_scrolling() {
 	l.Draw(&screen, area) // Now shows items 5-14
 
 	// Jump to specific item
-	l.ScrollToItem("50")
+	l.ScrollToItem(50)
 	l.Draw(&screen, area) // Now shows item 50 and neighbors
 
 	// Scroll to bottom
@@ -258,9 +257,9 @@ func Example_variableHeights() {
 func Example_markdown() {
 	// Create markdown items
 	items := []list.Item{
-		list.NewMarkdownItem("1", "# Welcome\n\nThis is a **markdown** item."),
-		list.NewMarkdownItem("2", "## Features\n\n- Supports **bold**\n- Supports *italic*\n- Supports `code`"),
-		list.NewMarkdownItem("3", "### Code Block\n\n```go\nfunc main() {\n    fmt.Println(\"Hello\")\n}\n```"),
+		list.NewMarkdownItem("# Welcome\n\nThis is a **markdown** item."),
+		list.NewMarkdownItem("## Features\n\n- Supports **bold**\n- Supports *italic*\n- Supports `code`"),
+		list.NewMarkdownItem("### Code Block\n\n```go\nfunc main() {\n    fmt.Println(\"Hello\")\n}\n```"),
 	}
 
 	// Create list
diff --git a/internal/ui/list/item_test.go b/internal/ui/list/item_test.go
--- a/internal/ui/list/item_test.go
+++ b/internal/ui/list/item_test.go
@@ -10,9 +10,9 @@ import (
 
 func TestRenderHelper(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
@@ -39,11 +39,11 @@ func TestRenderHelper(t *testing.T) {
 
 func TestRenderWithScrolling(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
-		NewStringItem("4", "Item 4"),
-		NewStringItem("5", "Item 5"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
+		NewStringItem("Item 4"),
+		NewStringItem("Item 5"),
 	}
 
 	l := New(items...)
@@ -89,8 +89,8 @@ func TestRenderEmptyList(t *testing.T) {
 
 func TestRenderVsDrawConsistency(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
 	}
 
 	l := New(items...)
@@ -119,7 +119,7 @@ func TestRenderVsDrawConsistency(t *testing.T) {
 func BenchmarkRender(b *testing.B) {
 	items := make([]Item, 100)
 	for i := range items {
-		items[i] = NewStringItem(string(rune(i)), "Item content here")
+		items[i] = NewStringItem("Item content here")
 	}
 
 	l := New(items...)
@@ -135,7 +135,7 @@ func BenchmarkRender(b *testing.B) {
 func BenchmarkRenderWithScrolling(b *testing.B) {
 	items := make([]Item, 1000)
 	for i := range items {
-		items[i] = NewStringItem(string(rune(i)), "Item content here")
+		items[i] = NewStringItem("Item content here")
 	}
 
 	l := New(items...)
@@ -150,7 +150,7 @@ func BenchmarkRenderWithScrolling(b *testing.B) {
 }
 
 func TestStringItemCache(t *testing.T) {
-	item := NewStringItem("1", "Test content")
+	item := NewStringItem("Test content")
 
 	// First draw at width 80 should populate cache
 	screen1 := uv.NewScreenBuffer(80, 5)
@@ -188,14 +188,14 @@ func TestStringItemCache(t *testing.T) {
 
 func TestWrappingItemHeight(t *testing.T) {
 	// Short text that fits in one line
-	item1 := NewWrappingStringItem("1", "Short")
+	item1 := NewWrappingStringItem("Short")
 	if h := item1.Height(80); h != 1 {
 		t.Errorf("expected height 1 for short text, got %d", h)
 	}
 
 	// Long text that wraps
 	longText := "This is a very long line that will definitely wrap when constrained to a narrow width"
-	item2 := NewWrappingStringItem("2", longText)
+	item2 := NewWrappingStringItem(longText)
 
 	// At width 80, should be fewer lines than width 20
 	height80 := item2.Height(80)
@@ -207,19 +207,15 @@ func TestWrappingItemHeight(t *testing.T) {
 	}
 
 	// Non-wrapping version should always be 1 line
-	item3 := NewStringItem("3", longText)
+	item3 := NewStringItem(longText)
 	if h := item3.Height(20); h != 1 {
 		t.Errorf("expected height 1 for non-wrapping item, got %d", h)
 	}
 }
 
 func TestMarkdownItemBasic(t *testing.T) {
 	markdown := "# Hello\n\nThis is a **test**."
-	item := NewMarkdownItem("1", markdown)
-
-	if item.ID() != "1" {
-		t.Errorf("expected ID '1', got '%s'", item.ID())
-	}
+	item := NewMarkdownItem(markdown)
 
 	// Test that height is calculated
 	height := item.Height(80)
@@ -241,7 +237,7 @@ func TestMarkdownItemBasic(t *testing.T) {
 
 func TestMarkdownItemCache(t *testing.T) {
 	markdown := "# Test\n\nSome content."
-	item := NewMarkdownItem("1", markdown)
+	item := NewMarkdownItem(markdown)
 
 	// First render at width 80 should populate cache
 	height1 := item.Height(80)
@@ -267,7 +263,7 @@ func TestMarkdownItemCache(t *testing.T) {
 
 func TestMarkdownItemMaxCacheWidth(t *testing.T) {
 	markdown := "# Test\n\nSome content."
-	item := NewMarkdownItem("1", markdown).WithMaxWidth(50)
+	item := NewMarkdownItem(markdown).WithMaxWidth(50)
 
 	// Render at width 40 (below limit) - should cache at width 40
 	_ = item.Height(40)
@@ -302,7 +298,7 @@ func TestMarkdownItemWithStyleConfig(t *testing.T) {
 		},
 	}
 
-	item := NewMarkdownItem("1", markdown).WithStyleConfig(styleConfig)
+	item := NewMarkdownItem(markdown).WithStyleConfig(styleConfig)
 
 	// Render should use the custom style
 	height := item.Height(80)
@@ -323,9 +319,9 @@ func TestMarkdownItemWithStyleConfig(t *testing.T) {
 
 func TestMarkdownItemInList(t *testing.T) {
 	items := []Item{
-		NewMarkdownItem("1", "# First\n\nMarkdown item."),
-		NewMarkdownItem("2", "# Second\n\nAnother item."),
-		NewStringItem("3", "Regular string item"),
+		NewMarkdownItem("# First\n\nMarkdown item."),
+		NewMarkdownItem("# Second\n\nAnother item."),
+		NewStringItem("Regular string item"),
 	}
 
 	l := New(items...)
@@ -353,7 +349,7 @@ func TestMarkdownItemHeightWithWidth(t *testing.T) {
 	// Test that widths are capped to maxWidth
 	markdown := "This is a paragraph with some text."
 
-	item := NewMarkdownItem("1", markdown).WithMaxWidth(50)
+	item := NewMarkdownItem(markdown).WithMaxWidth(50)
 
 	// At width 30 (below limit), should cache and render at width 30
 	height30 := item.Height(30)
@@ -381,7 +377,7 @@ func TestMarkdownItemHeightWithWidth(t *testing.T) {
 
 func BenchmarkMarkdownItemRender(b *testing.B) {
 	markdown := "# Heading\n\nThis is a paragraph with **bold** and *italic* text.\n\n- Item 1\n- Item 2\n- Item 3"
-	item := NewMarkdownItem("1", markdown)
+	item := NewMarkdownItem(markdown)
 
 	// Prime the cache
 	screen := uv.NewScreenBuffer(80, 10)
@@ -401,20 +397,15 @@ func BenchmarkMarkdownItemUncached(b *testing.B) {
 
 	b.ResetTimer()
 	for i := 0; i < b.N; i++ {
-		item := NewMarkdownItem("1", markdown)
+		item := NewMarkdownItem(markdown)
 		screen := uv.NewScreenBuffer(80, 10)
 		area := uv.Rect(0, 0, 80, 10)
 		item.Draw(&screen, area)
 	}
 }
 
 func TestSpacerItem(t *testing.T) {
-	spacer := NewSpacerItem("spacer1", 3)
-
-	// Check ID
-	if spacer.ID() != "spacer1" {
-		t.Errorf("expected ID 'spacer1', got %q", spacer.ID())
-	}
+	spacer := NewSpacerItem(3)
 
 	// Check height
 	if h := spacer.Height(80); h != 3 {
@@ -444,11 +435,11 @@ func TestSpacerItem(t *testing.T) {
 func TestSpacerItemInList(t *testing.T) {
 	// Create a list with items separated by spacers
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewSpacerItem("spacer1", 1),
-		NewStringItem("2", "Item 2"),
-		NewSpacerItem("spacer2", 2),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewSpacerItem(1),
+		NewStringItem("Item 2"),
+		NewSpacerItem(2),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
@@ -477,28 +468,28 @@ func TestSpacerItemInList(t *testing.T) {
 func TestSpacerItemNavigation(t *testing.T) {
 	// Spacers should not be selectable (they're not focusable)
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewSpacerItem("spacer1", 1),
-		NewStringItem("2", "Item 2"),
+		NewStringItem("Item 1"),
+		NewSpacerItem(1),
+		NewStringItem("Item 2"),
 	}
 
 	l := New(items...)
 	l.SetSize(20, 10)
 
 	// Select first item
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 	if l.SelectedIndex() != 0 {
 		t.Errorf("expected selected index 0, got %d", l.SelectedIndex())
 	}
 
 	// Can select the spacer (it's a valid item, just not focusable)
-	l.SetSelectedIndex(1)
+	l.SetSelected(1)
 	if l.SelectedIndex() != 1 {
 		t.Errorf("expected selected index 1, got %d", l.SelectedIndex())
 	}
 
 	// Can select item after spacer
-	l.SetSelectedIndex(2)
+	l.SetSelected(2)
 	if l.SelectedIndex() != 2 {
 		t.Errorf("expected selected index 2, got %d", l.SelectedIndex())
 	}
@@ -512,11 +503,11 @@ func uintPtr(v uint) *uint {
 func TestListDoesNotEatLastLine(t *testing.T) {
 	// Create items that exactly fill the viewport
 	items := []Item{
-		NewStringItem("1", "Line 1"),
-		NewStringItem("2", "Line 2"),
-		NewStringItem("3", "Line 3"),
-		NewStringItem("4", "Line 4"),
-		NewStringItem("5", "Line 5"),
+		NewStringItem("Line 1"),
+		NewStringItem("Line 2"),
+		NewStringItem("Line 3"),
+		NewStringItem("Line 4"),
+		NewStringItem("Line 5"),
 	}
 
 	// Create list with height exactly matching content (5 lines, no gaps)
@@ -527,7 +518,7 @@ func TestListDoesNotEatLastLine(t *testing.T) {
 	output := l.Render()
 
 	// Count actual lines in output
-	lines := strings.Split(strings.TrimRight(output, "\r\n"), "\r\n")
+	lines := strings.Split(strings.TrimRight(output, "\n"), "\n")
 	actualLineCount := 0
 	for _, line := range lines {
 		if strings.TrimSpace(line) != "" {
@@ -560,13 +551,13 @@ func TestListDoesNotEatLastLine(t *testing.T) {
 func TestListWithScrollDoesNotEatLastLine(t *testing.T) {
 	// Create more items than viewport height
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
-		NewStringItem("4", "Item 4"),
-		NewStringItem("5", "Item 5"),
-		NewStringItem("6", "Item 6"),
-		NewStringItem("7", "Item 7"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
+		NewStringItem("Item 4"),
+		NewStringItem("Item 5"),
+		NewStringItem("Item 6"),
+		NewStringItem("Item 7"),
 	}
 
 	// Viewport shows 3 items at a time
diff --git a/internal/ui/list/list_test.go b/internal/ui/list/list_test.go
--- a/internal/ui/list/list_test.go
+++ b/internal/ui/list/list_test.go
@@ -11,9 +11,9 @@ import (
 
 func TestNewList(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
@@ -30,9 +30,9 @@ func TestNewList(t *testing.T) {
 
 func TestListDraw(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
@@ -54,52 +54,44 @@ func TestListDraw(t *testing.T) {
 
 func TestListAppendItem(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
+		NewStringItem("Item 1"),
 	}
 
 	l := New(items...)
-	l.AppendItem(NewStringItem("2", "Item 2"))
+	l.AppendItem(NewStringItem("Item 2"))
 
 	if len(l.items) != 2 {
 		t.Errorf("expected 2 items after append, got %d", len(l.items))
 	}
-
-	if l.items[1].ID() != "2" {
-		t.Errorf("expected item ID '2', got '%s'", l.items[1].ID())
-	}
 }
 
 func TestListDeleteItem(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
-	l.DeleteItem("2")
+	l.DeleteItem(2)
 
 	if len(l.items) != 2 {
 		t.Errorf("expected 2 items after delete, got %d", len(l.items))
 	}
-
-	if l.items[1].ID() != "3" {
-		t.Errorf("expected item ID '3', got '%s'", l.items[1].ID())
-	}
 }
 
 func TestListUpdateItem(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
 	}
 
 	l := New(items...)
 	l.SetSize(80, 10)
 
 	// Update item
-	newItem := NewStringItem("2", "Updated Item 2")
-	l.UpdateItem("2", newItem)
+	newItem := NewStringItem("Updated Item 2")
+	l.UpdateItem(1, newItem)
 
 	if l.items[1].(*StringItem).content != "Updated Item 2" {
 		t.Errorf("expected updated content, got '%s'", l.items[1].(*StringItem).content)
@@ -108,13 +100,13 @@ func TestListUpdateItem(t *testing.T) {
 
 func TestListSelection(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
 	}
 
 	l := New(items...)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 
 	if l.SelectedIndex() != 0 {
 		t.Errorf("expected selected index 0, got %d", l.SelectedIndex())
@@ -133,11 +125,11 @@ func TestListSelection(t *testing.T) {
 
 func TestListScrolling(t *testing.T) {
 	items := []Item{
-		NewStringItem("1", "Item 1"),
-		NewStringItem("2", "Item 2"),
-		NewStringItem("3", "Item 3"),
-		NewStringItem("4", "Item 4"),
-		NewStringItem("5", "Item 5"),
+		NewStringItem("Item 1"),
+		NewStringItem("Item 2"),
+		NewStringItem("Item 3"),
+		NewStringItem("Item 4"),
+		NewStringItem("Item 5"),
 	}
 
 	l := New(items...)
@@ -208,7 +200,7 @@ func TestListFocus(t *testing.T) {
 
 	l := New(items...)
 	l.SetSize(80, 10)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 
 	// Focus the list
 	l.Focus()
@@ -256,12 +248,12 @@ func TestFocusNavigationAfterAppendingToViewportHeight(t *testing.T) {
 
 	// Start with one item
 	items := []Item{
-		NewStringItem("1", "Item 1").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 1").WithFocusStyles(&focusStyle, &blurStyle),
 	}
 
 	l := New(items...)
 	l.SetSize(20, 15) // 15 lines viewport height
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 	l.Focus()
 
 	// Initial draw to build buffer
@@ -271,12 +263,12 @@ func TestFocusNavigationAfterAppendingToViewportHeight(t *testing.T) {
 	// Append items until we exceed viewport height
 	// Each focusable item with border is 5 lines tall
 	for i := 2; i <= 4; i++ {
-		item := NewStringItem(string(rune('0'+i)), "Item "+string(rune('0'+i))).WithFocusStyles(&focusStyle, &blurStyle)
+		item := NewStringItem("Item "+string(rune('0'+i))).WithFocusStyles(&focusStyle, &blurStyle)
 		l.AppendItem(item)
 	}
 
 	// Select the last item
-	l.SetSelectedIndex(3)
+	l.SetSelected(3)
 
 	// Draw
 	screen = uv.NewScreenBuffer(20, 15)
@@ -318,7 +310,7 @@ func TestFocusableItemUpdate(t *testing.T) {
 		BorderForeground(lipgloss.Color("240"))
 
 	// Create a focusable item
-	item := NewStringItem("1", "Test Item").WithFocusStyles(&focusStyle, &blurStyle)
+	item := NewStringItem("Test Item").WithFocusStyles(&focusStyle, &blurStyle)
 
 	// Initially not focused - render with blur style
 	screen1 := uv.NewScreenBuffer(20, 5)
@@ -369,14 +361,14 @@ func TestFocusableItemHeightWithBorder(t *testing.T) {
 		Border(lipgloss.RoundedBorder())
 
 	// Item without styles has height 1
-	plainItem := NewStringItem("1", "Test")
+	plainItem := NewStringItem("Test")
 	plainHeight := plainItem.Height(20)
 	if plainHeight != 1 {
 		t.Errorf("expected plain height 1, got %d", plainHeight)
 	}
 
 	// Item with border should add border height (2 lines)
-	item := NewStringItem("2", "Test").WithFocusStyles(&borderStyle, &borderStyle)
+	item := NewStringItem("Test").WithFocusStyles(&borderStyle, &borderStyle)
 	itemHeight := item.Height(20)
 	expectedHeight := 1 + 2 // content + border
 	if itemHeight != expectedHeight {
@@ -396,14 +388,14 @@ func TestFocusableItemInList(t *testing.T) {
 
 	// Create list with focusable items
 	items := []Item{
-		NewStringItem("1", "Item 1").WithFocusStyles(&focusStyle, &blurStyle),
-		NewStringItem("2", "Item 2").WithFocusStyles(&focusStyle, &blurStyle),
-		NewStringItem("3", "Item 3").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 1").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 2").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 3").WithFocusStyles(&focusStyle, &blurStyle),
 	}
 
 	l := New(items...)
 	l.SetSize(80, 20)
-	l.SetSelectedIndex(0)
+	l.SetSelected(0)
 
 	// Focus the list
 	l.Focus()
@@ -421,7 +413,7 @@ func TestFocusableItemInList(t *testing.T) {
 	}
 
 	// Select second item
-	l.SetSelectedIndex(1)
+	l.SetSelected(1)
 
 	// First item should be blurred, second focused
 	if firstItem.IsFocused() {
@@ -447,7 +439,7 @@ func TestFocusableItemInList(t *testing.T) {
 
 func TestFocusableItemWithNilStyles(t *testing.T) {
 	// Test with nil styles - should render inner item directly
-	item := NewStringItem("1", "Plain Item").WithFocusStyles(nil, nil)
+	item := NewStringItem("Plain Item").WithFocusStyles(nil, nil)
 
 	// Height should be based on content (no border since styles are nil)
 	itemHeight := item.Height(20)
@@ -488,7 +480,7 @@ func TestFocusableItemWithOnlyFocusStyle(t *testing.T) {
 		Border(lipgloss.RoundedBorder()).
 		BorderForeground(lipgloss.Color("86"))
 
-	item := NewStringItem("1", "Test").WithFocusStyles(&focusStyle, nil)
+	item := NewStringItem("Test").WithFocusStyles(&focusStyle, nil)
 
 	// When not focused, should use nil blur style (no border)
 	screen1 := uv.NewScreenBuffer(20, 5)
@@ -519,15 +511,15 @@ func TestFocusableItemLastLineNotEaten(t *testing.T) {
 		BorderForeground(lipgloss.Color("240"))
 
 	items := []Item{
-		NewStringItem("1", "Item 1").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 1").WithFocusStyles(&focusStyle, &blurStyle),
 		Gap,
-		NewStringItem("2", "Item 2").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 2").WithFocusStyles(&focusStyle, &blurStyle),
 		Gap,
-		NewStringItem("3", "Item 3").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 3").WithFocusStyles(&focusStyle, &blurStyle),
 		Gap,
-		NewStringItem("4", "Item 4").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 4").WithFocusStyles(&focusStyle, &blurStyle),
 		Gap,
-		NewStringItem("5", "Item 5").WithFocusStyles(&focusStyle, &blurStyle),
+		NewStringItem("Item 5").WithFocusStyles(&focusStyle, &blurStyle),
 	}
 
 	// Items with padding(1) and border are 5 lines each
@@ -543,7 +535,7 @@ func TestFocusableItemLastLineNotEaten(t *testing.T) {
 	l.Focus()
 
 	// Select last item
-	l.SetSelectedIndex(len(items) - 1)
+	l.SetSelected(len(items) - 1)
 
 	// Scroll to bottom
 	l.ScrollToBottom()
EOF_114329324912

# Set Go environment variables (ensuring they're active in the current shell)
export CGO_ENABLED=0
export GOEXPERIMENT=greenteagc
export GOTOOLCHAIN=go1.25.0

# Run tests for the internal/ui/list package
# Using -v for verbose output to help with debugging
go test -v ./internal/ui/list/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 60882473c933131a4cd78ed2eb3a4a3ff591c430 "internal/ui/list/example_test.go" "internal/ui/list/item_test.go" "internal/ui/list/list_test.go"