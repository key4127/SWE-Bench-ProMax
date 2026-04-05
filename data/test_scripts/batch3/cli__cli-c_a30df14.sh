#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 49ddacf5b85cff6d72faded445047a9e4485f298 "internal/prompter/speech_synthesizer_friendly_prompter_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/prompter/speech_synthesizer_friendly_prompter_test.go b/internal/prompter/speech_synthesizer_friendly_prompter_test.go
--- a/internal/prompter/speech_synthesizer_friendly_prompter_test.go
+++ b/internal/prompter/speech_synthesizer_friendly_prompter_test.go
@@ -39,6 +39,8 @@ func TestSpeechSynthesizerFriendlyPrompter(t *testing.T) {
 	require.NoError(t, err)
 	t.Cleanup(func() { testCloser(t, console) })
 
+	// Using OS here because huh currently ignores configured iostreams
+	// See https://github.com/charmbracelet/huh/issues/612
 	stdIn := os.Stdin
 	stdOut := os.Stdout
 	stdErr := os.Stderr
@@ -53,9 +55,7 @@ func TestSpeechSynthesizerFriendlyPrompter(t *testing.T) {
 	os.Stdout = console.Tty()
 	os.Stderr = console.Tty()
 
-	// Using OS here because huh currently ignores configured iostreams
-	// See https://github.com/charmbracelet/huh/issues/612
-	t.Setenv("GH_SCREENREADER_FRIENDLY", "true")
+	t.Setenv("GH_SPEECH_SYNTHESIZER_FRIENDLY_PROMPTER", "true")
 	p := prompter.New("", nil, nil, nil)
 
 	t.Run("Select", func(t *testing.T) {
EOF_114329324912

# Run the specific test file
# Using the package path approach for better Go test compatibility
go test -v ./internal/prompter/

# Capture exit code
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original file
git checkout 49ddacf5b85cff6d72faded445047a9e4485f298 "internal/prompter/speech_synthesizer_friendly_prompter_test.go"