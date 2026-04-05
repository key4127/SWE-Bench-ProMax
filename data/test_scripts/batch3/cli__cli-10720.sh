#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout addbc6ac5c0dc3ed4611904972d5b122e4426756 "pkg/cmd/gist/list/list_test.go" "pkg/iostreams/color_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/gist/list/list_test.go b/pkg/cmd/gist/list/list_test.go
--- a/pkg/cmd/gist/list/list_test.go
+++ b/pkg/cmd/gist/list/list_test.go
@@ -654,50 +654,57 @@ func Test_highlightMatch(t *testing.T) {
 	tests := []struct {
 		name  string
 		input string
-		color bool
+		cs    *iostreams.ColorScheme
 		want  string
 	}{
 		{
 			name:  "single match",
 			input: "Octo",
+			cs:    &iostreams.ColorScheme{},
 			want:  "Octo",
 		},
 		{
 			name:  "single match (color)",
 			input: "Octo",
-			color: true,
-			want:  "\x1b[0;30;43mOcto\x1b[0m",
+			cs: &iostreams.ColorScheme{
+				Enabled: true,
+			},
+			want: "\x1b[0;30;43mOcto\x1b[0m",
 		},
 		{
 			name:  "single match with extra",
 			input: "Hello, Octocat!",
+			cs:    &iostreams.ColorScheme{},
 			want:  "Hello, Octocat!",
 		},
 		{
 			name:  "single match with extra (color)",
 			input: "Hello, Octocat!",
-			color: true,
-			want:  "\x1b[0;34mHello, \x1b[0m\x1b[0;30;43mOcto\x1b[0m\x1b[0;34mcat!\x1b[0m",
+			cs: &iostreams.ColorScheme{
+				Enabled: true,
+			},
+			want: "\x1b[0;34mHello, \x1b[0m\x1b[0;30;43mOcto\x1b[0m\x1b[0;34mcat!\x1b[0m",
 		},
 		{
 			name:  "multiple matches",
 			input: "Octocat/octo",
+			cs:    &iostreams.ColorScheme{},
 			want:  "Octocat/octo",
 		},
 		{
 			name:  "multiple matches (color)",
 			input: "Octocat/octo",
-			color: true,
-			want:  "\x1b[0;30;43mOcto\x1b[0m\x1b[0;34mcat/\x1b[0m\x1b[0;30;43mocto\x1b[0m",
+			cs: &iostreams.ColorScheme{
+				Enabled: true,
+			},
+			want: "\x1b[0;30;43mOcto\x1b[0m\x1b[0;34mcat/\x1b[0m\x1b[0;30;43mocto\x1b[0m",
 		},
 	}
 
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			cs := iostreams.NewColorScheme(tt.color, false, false, false, false, iostreams.NoTheme)
-
 			matched := false
-			got, err := highlightMatch(tt.input, regex, &matched, cs.Blue, cs.Highlight)
+			got, err := highlightMatch(tt.input, regex, &matched, tt.cs.Blue, tt.cs.Highlight)
 			assert.NoError(t, err)
 			assert.True(t, matched)
 			assert.Equal(t, tt.want, got)
diff --git a/pkg/iostreams/color_test.go b/pkg/iostreams/color_test.go
--- a/pkg/iostreams/color_test.go
+++ b/pkg/iostreams/color_test.go
@@ -20,35 +20,52 @@ func TestLabel(t *testing.T) {
 			hex:   "fc0303",
 			text:  "red",
 			wants: "\033[38;2;252;3;3mred\033[0m",
-			cs:    NewColorScheme(true, true, true, false, true, NoTheme),
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				ColorLabels:   true,
+			},
 		},
 		{
 			name:  "no truecolor",
 			hex:   "fc0303",
 			text:  "red",
 			wants: "red",
-			cs:    NewColorScheme(true, true, false, false, true, NoTheme),
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				ColorLabels:   true,
+			},
 		},
 		{
 			name:  "no color",
 			hex:   "fc0303",
 			text:  "red",
 			wants: "red",
-			cs:    NewColorScheme(false, false, false, false, true, NoTheme),
+			cs: &ColorScheme{
+				ColorLabels: true,
+			},
 		},
 		{
 			name:  "invalid hex",
 			hex:   "fc0",
 			text:  "red",
 			wants: "red",
-			cs:    NewColorScheme(false, false, false, false, true, NoTheme),
+			cs: &ColorScheme{
+				ColorLabels: true,
+			},
 		},
 		{
 			name:  "no color labels",
 			hex:   "fc0303",
 			text:  "red",
 			wants: "red",
-			cs:    NewColorScheme(true, true, true, false, false, NoTheme),
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				ColorLabels:   true,
+			},
 		},
 	}
 
@@ -71,62 +88,110 @@ func TestTableHeader(t *testing.T) {
 		expected string
 	}{
 		{
-			name:     "when color is disabled, text is not stylized",
-			cs:       NewColorScheme(false, false, false, true, false, NoTheme),
+			name: "when color is disabled, text is not stylized",
+			cs: &ColorScheme{
+				Accessible: true,
+				Theme:      NoTheme,
+			},
 			input:    "this should not be stylized",
 			expected: "this should not be stylized",
 		},
 		{
-			name:     "when 4-bit color is enabled but no theme, 4-bit default color and underline are used",
-			cs:       NewColorScheme(true, false, false, true, false, NoTheme),
+			name: "when 4-bit color is enabled but no theme, 4-bit default color and underline are used",
+			cs: &ColorScheme{
+				Enabled:    true,
+				Accessible: true,
+				Theme:      NoTheme,
+			},
 			input:    "this should have no explicit color but underlined",
 			expected: fmt.Sprintf("%sthis should have no explicit color but underlined%s", defaultUnderline, reset),
 		},
 		{
-			name:     "when 4-bit color is enabled and theme is light, 4-bit dark color and underline are used",
-			cs:       NewColorScheme(true, false, false, true, false, LightTheme),
+			name: "when 4-bit color is enabled and theme is light, 4-bit dark color and underline are used",
+			cs: &ColorScheme{
+				Enabled:    true,
+				Accessible: true,
+				Theme:      LightTheme,
+			},
 			input:    "this should have dark foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have dark foreground color and underlined%s", brightBlackUnderline, reset),
 		},
 		{
-			name:     "when 4-bit color is enabled and theme is dark, 4-bit light color and underline are used",
-			cs:       NewColorScheme(true, false, false, true, false, DarkTheme),
+			name: "when 4-bit color is enabled and theme is dark, 4-bit light color and underline are used",
+			cs: &ColorScheme{
+				Enabled:    true,
+				Accessible: true,
+				Theme:      DarkTheme,
+			},
 			input:    "this should have light foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have light foreground color and underlined%s", dimBlackUnderline, reset),
 		},
 		{
-			name:     "when 8-bit color is enabled but no theme, 4-bit default color and underline are used",
-			cs:       NewColorScheme(true, true, false, true, false, NoTheme),
+			name: "when 8-bit color is enabled but no theme, 4-bit default color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				Accessible:    true,
+				Theme:         NoTheme,
+			},
 			input:    "this should have no explicit color but underlined",
 			expected: fmt.Sprintf("%sthis should have no explicit color but underlined%s", defaultUnderline, reset),
 		},
 		{
-			name:     "when 8-bit color is enabled and theme is light, 4-bit dark color and underline are used",
-			cs:       NewColorScheme(true, true, false, true, false, LightTheme),
+			name: "when 8-bit color is enabled and theme is light, 4-bit dark color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				Accessible:    true,
+				Theme:         LightTheme,
+			},
 			input:    "this should have dark foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have dark foreground color and underlined%s", brightBlackUnderline, reset),
 		},
 		{
-			name:     "when 8-bit color is true and theme is dark, 4-bit light color and underline are used",
-			cs:       NewColorScheme(true, true, false, true, false, DarkTheme),
+			name: "when 8-bit color is true and theme is dark, 4-bit light color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				Accessible:    true,
+				Theme:         DarkTheme,
+			},
 			input:    "this should have light foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have light foreground color and underlined%s", dimBlackUnderline, reset),
 		},
 		{
-			name:     "when 24-bit color is enabled but no theme, 4-bit default color and underline are used",
-			cs:       NewColorScheme(true, true, true, true, false, NoTheme),
+			name: "when 24-bit color is enabled but no theme, 4-bit default color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         NoTheme,
+			},
 			input:    "this should have no explicit color but underlined",
 			expected: fmt.Sprintf("%sthis should have no explicit color but underlined%s", defaultUnderline, reset),
 		},
 		{
-			name:     "when 24-bit color is enabled and theme is light, 4-bit dark color and underline are used",
-			cs:       NewColorScheme(true, true, true, true, false, LightTheme),
+			name: "when 24-bit color is enabled and theme is light, 4-bit dark color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         LightTheme,
+			},
 			input:    "this should have dark foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have dark foreground color and underlined%s", brightBlackUnderline, reset),
 		},
 		{
-			name:     "when 24-bit color is true and theme is dark, 4-bit light color and underline are used",
-			cs:       NewColorScheme(true, true, true, true, false, DarkTheme),
+			name: "when 24-bit color is true and theme is dark, 4-bit light color and underline are used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         DarkTheme,
+			},
 			input:    "this should have light foreground color and underlined",
 			expected: fmt.Sprintf("%sthis should have light foreground color and underlined%s", dimBlackUnderline, reset),
 		},
@@ -154,43 +219,70 @@ func TestMuted(t *testing.T) {
 	}{
 		{
 			name:     "when color is disabled but accessible colors are disabled, text is not stylized",
-			cs:       NewColorScheme(false, false, false, false, false, NoTheme),
+			cs:       &ColorScheme{},
 			input:    "this should not be stylized",
 			expected: "this should not be stylized",
 		},
 		{
-			name:     "when 4-bit color is enabled but accessible colors are disabled, legacy 4-bit gray color is used",
-			cs:       NewColorScheme(true, false, false, false, false, NoTheme),
+			name: "when 4-bit color is enabled but accessible colors are disabled, legacy 4-bit gray color is used",
+			cs: &ColorScheme{
+				Enabled: true,
+			},
 			input:    "this should be 4-bit gray",
 			expected: fmt.Sprintf("%sthis should be 4-bit gray%s", gray4bit, reset),
 		},
 		{
-			name:     "when 8-bit color is enabled but accessible colors are disabled, legacy 8-bit gray color is used",
-			cs:       NewColorScheme(true, true, false, false, false, NoTheme),
+			name: "when 8-bit color is enabled but accessible colors are disabled, legacy 8-bit gray color is used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+			},
 			input:    "this should be 8-bit gray",
 			expected: fmt.Sprintf("%sthis should be 8-bit gray%s", gray8bit, reset),
 		},
 		{
-			name:     "when 24-bit color is enabled but accessible colors are disabled, legacy 8-bit gray color is used",
-			cs:       NewColorScheme(true, true, true, false, false, NoTheme),
+			name: "when 24-bit color is enabled but accessible colors are disabled, legacy 8-bit gray color is used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+			},
 			input:    "this should be 8-bit gray",
 			expected: fmt.Sprintf("%sthis should be 8-bit gray%s", gray8bit, reset),
 		},
 		{
-			name:     "when 4-bit color is enabled and theme is dark, 4-bit light color is used",
-			cs:       NewColorScheme(true, true, true, true, false, DarkTheme),
+			name: "when 4-bit color is enabled and theme is dark, 4-bit light color is used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         DarkTheme,
+			},
 			input:    "this should be 4-bit dim black",
 			expected: fmt.Sprintf("%sthis should be 4-bit dim black%s", dimBlack4bit, reset),
 		},
 		{
-			name:     "when 4-bit color is enabled and theme is light, 4-bit dark color is used",
-			cs:       NewColorScheme(true, true, true, true, false, LightTheme),
+			name: "when 4-bit color is enabled and theme is light, 4-bit dark color is used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         LightTheme,
+			},
 			input:    "this should be 4-bit bright black",
 			expected: fmt.Sprintf("%sthis should be 4-bit bright black%s", brightBlack4bit, reset),
 		},
 		{
-			name:     "when 4-bit color is enabled but no theme, 4-bit default color is used",
-			cs:       NewColorScheme(true, true, true, true, false, NoTheme),
+			name: "when 4-bit color is enabled but no theme, 4-bit default color is used",
+			cs: &ColorScheme{
+				Enabled:       true,
+				EightBitColor: true,
+				TrueColor:     true,
+				Accessible:    true,
+				Theme:         NoTheme,
+			},
 			input:    "this should have no explicit color",
 			expected: "this should have no explicit color",
 		},
EOF_114329324912

# Run the tests for both packages in a single command
# This is more efficient than running them separately
go test -v ./pkg/cmd/gist/list ./pkg/iostreams

# Capture exit code
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
git checkout addbc6ac5c0dc3ed4611904972d5b122e4426756 "pkg/cmd/gist/list/list_test.go" "pkg/iostreams/color_test.go"