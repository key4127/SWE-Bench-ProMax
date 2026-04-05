#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2f5e8965355bd120364cccb52e6f973a6e85718c "internal/prompter/accessible_prompter_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/prompter/accessible_prompter_test.go b/internal/prompter/accessible_prompter_test.go
--- a/internal/prompter/accessible_prompter_test.go
+++ b/internal/prompter/accessible_prompter_test.go
@@ -5,9 +5,7 @@ package prompter_test
 import (
 	"fmt"
 	"io"
-	"os"
 	"strings"
-	"sync"
 	"testing"
 	"time"
 
@@ -20,54 +18,11 @@ import (
 )
 
 func TestAccessiblePrompter(t *testing.T) {
-	// Create a PTY and hook up a virtual terminal emulator
-	ptm, pts, err := pty.Open()
-	require.NoError(t, err)
-
-	term := vt10x.New(vt10x.WithWriter(pts))
-
-	// Create a console via Expect that allows scripting against the terminal
-	consoleOpts := []expect.ConsoleOpt{
-		expect.WithStdin(ptm),
-		expect.WithStdout(term),
-		expect.WithCloser(ptm, pts),
-		failOnExpectError(t),
-		failOnSendError(t),
-		expect.WithDefaultTimeout(time.Second),
-	}
-
-	console, err := expect.NewConsole(consoleOpts...)
-	require.NoError(t, err)
-	t.Cleanup(func() { testCloser(t, console) })
-
-	// Using OS here because huh currently ignores configured iostreams
-	// See https://github.com/charmbracelet/huh/issues/612
-	stdIn := os.Stdin
-	stdOut := os.Stdout
-	stdErr := os.Stderr
-
-	t.Cleanup(func() {
-		os.Stdin = stdIn
-		os.Stdout = stdOut
-		os.Stderr = stdErr
-	})
-
-	os.Stdin = console.Tty()
-	os.Stdout = console.Tty()
-	os.Stderr = console.Tty()
-
-	t.Setenv("GH_ACCESSIBLE_PROMPTER", "true")
-	// Using echo as the editor command here because it will immediately exit
-	// and return no input.
-	p := prompter.New("echo", nil, nil, nil)
-
-	var wg sync.WaitGroup
-
 	t.Run("Select", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Choose:")
 			require.NoError(t, err)
@@ -80,15 +35,13 @@ func TestAccessiblePrompter(t *testing.T) {
 		selectValue, err := p.Select("Select a number", "", []string{"1", "2", "3"})
 		require.NoError(t, err)
 		assert.Equal(t, 0, selectValue)
-
-		wg.Wait()
 	})
 
 	t.Run("MultiSelect", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Select a number")
 			require.NoError(t, err)
@@ -107,16 +60,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		multiSelectValue, err := p.MultiSelect("Select a number", []string{}, []string{"1", "2", "3"})
 		require.NoError(t, err)
 		assert.Equal(t, []int{0, 1}, multiSelectValue)
-
-		wg.Wait()
 	})
 
 	t.Run("Input", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		dummyText := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Enter some characters")
 			require.NoError(t, err)
@@ -129,16 +80,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.Input("Enter some characters", "")
 		require.NoError(t, err)
 		assert.Equal(t, dummyText, inputValue)
-
-		wg.Wait()
 	})
 
 	t.Run("Input - blank input returns default value", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		dummyDefaultValue := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Enter some characters")
 			require.NoError(t, err)
@@ -155,16 +104,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.Input("Enter some characters", dummyDefaultValue)
 		require.NoError(t, err)
 		assert.Equal(t, dummyDefaultValue, inputValue)
-
-		wg.Wait()
 	})
 
 	t.Run("Password", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		dummyPassword := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Enter password")
 			require.NoError(t, err)
@@ -177,15 +124,13 @@ func TestAccessiblePrompter(t *testing.T) {
 		passwordValue, err := p.Password("Enter password")
 		require.NoError(t, err)
 		require.Equal(t, dummyPassword, passwordValue)
-
-		wg.Wait()
 	})
 
 	t.Run("Confirm", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Are you sure")
 			require.NoError(t, err)
@@ -198,11 +143,12 @@ func TestAccessiblePrompter(t *testing.T) {
 		confirmValue, err := p.Confirm("Are you sure", false)
 		require.NoError(t, err)
 		require.Equal(t, true, confirmValue)
-
-		wg.Wait()
 	})
 
 	t.Run("Confirm - blank input returns default", func(t *testing.T) {
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
+
 		go func() {
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Are you sure")
@@ -219,11 +165,11 @@ func TestAccessiblePrompter(t *testing.T) {
 	})
 
 	t.Run("AuthToken", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		dummyAuthToken := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Paste your authentication token:")
 			require.NoError(t, err)
@@ -236,16 +182,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		authValue, err := p.AuthToken()
 		require.NoError(t, err)
 		require.Equal(t, dummyAuthToken, authValue)
-
-		wg.Wait()
 	})
 
 	t.Run("AuthToken - blank input returns error", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		dummyAuthTokenForAfterFailure := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Paste your authentication token:")
 			require.NoError(t, err)
@@ -266,16 +210,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		authValue, err := p.AuthToken()
 		require.NoError(t, err)
 		require.Equal(t, dummyAuthTokenForAfterFailure, authValue)
-
-		wg.Wait()
 	})
 
 	t.Run("ConfirmDeletion", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		requiredValue := "test"
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString(fmt.Sprintf("Type %q to confirm deletion", requiredValue))
 			require.NoError(t, err)
@@ -288,17 +230,15 @@ func TestAccessiblePrompter(t *testing.T) {
 		// An err indicates that the confirmation text sent did not match
 		err := p.ConfirmDeletion(requiredValue)
 		require.NoError(t, err)
-
-		wg.Wait()
 	})
 
 	t.Run("ConfirmDeletion - bad input", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		requiredValue := "test"
 		badInputValue := "garbage"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString(fmt.Sprintf("Type %q to confirm deletion", requiredValue))
 			require.NoError(t, err)
@@ -319,16 +259,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		// An err indicates that the confirmation text sent did not match
 		err := p.ConfirmDeletion(requiredValue)
 		require.NoError(t, err)
-
-		wg.Wait()
 	})
 
 	t.Run("InputHostname", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		hostname := "example.com"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("Hostname:")
 			require.NoError(t, err)
@@ -341,15 +279,13 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.InputHostname()
 		require.NoError(t, err)
 		require.Equal(t, hostname, inputValue)
-
-		wg.Wait()
 	})
 
 	t.Run("MarkdownEditor - blank allowed with blank input returns blank", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("How to edit?")
 			require.NoError(t, err)
@@ -362,16 +298,14 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.MarkdownEditor("How to edit?", "", true)
 		require.NoError(t, err)
 		require.Equal(t, "", inputValue)
-
-		wg.Wait()
 	})
 
 	t.Run("MarkdownEditor - blank disallowed with default value returns default value", func(t *testing.T) {
-		wg.Add(1)
-
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 		defaultValue := "12345abcdefg"
+
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("How to edit?")
 			require.NoError(t, err)
@@ -392,15 +326,13 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.MarkdownEditor("How to edit?", defaultValue, false)
 		require.NoError(t, err)
 		require.Equal(t, defaultValue, inputValue)
-
-		wg.Wait()
 	})
 
 	t.Run("MarkdownEditor - blank disallowed no default value returns error", func(t *testing.T) {
-		wg.Add(1)
+		console := newTestVirtualTerminal(t)
+		p := newTestAcessiblePrompter(t, console)
 
 		go func() {
-			defer wg.Done()
 			// Wait for prompt to appear
 			_, err := console.ExpectString("How to edit?")
 			require.NoError(t, err)
@@ -422,12 +354,39 @@ func TestAccessiblePrompter(t *testing.T) {
 		inputValue, err := p.MarkdownEditor("How to edit?", "", false)
 		require.NoError(t, err)
 		require.Equal(t, "", inputValue)
-
-		wg.Wait()
 	})
 }
 
 func TestSurveyPrompter(t *testing.T) {
+	// This not a comprehensive test of the survey prompter, but it does
+	// demonstrate that the survey prompter is used when the
+	// accessible prompter is disabled.
+	t.Run("Select uses survey prompter when accessible prompter is disabled", func(t *testing.T) {
+		console := newTestVirtualTerminal(t)
+		p := newTestSurveyPrompter(t, console)
+
+		go func() {
+			// Wait for prompt to appear
+			_, err := console.ExpectString("Select a number")
+			require.NoError(t, err)
+
+			// Send a newline to select the first option
+			// Note: This would not work with the accessible prompter
+			// because it would requires sending a 1 to select the first option.
+			// So it proves we are seeing a survey prompter.
+			_, err = console.SendLine("")
+			require.NoError(t, err)
+		}()
+
+		selectValue, err := p.Select("Select a number", "", []string{"1", "2", "3"})
+		require.NoError(t, err)
+		assert.Equal(t, 0, selectValue)
+	})
+}
+
+func newTestVirtualTerminal(t testing.TB) *expect.Console {
+	t.Helper()
+
 	// Create a PTY and hook up a virtual terminal emulator
 	ptm, pts, err := pty.Open()
 	require.NoError(t, err)
@@ -441,45 +400,28 @@ func TestSurveyPrompter(t *testing.T) {
 		expect.WithCloser(ptm, pts),
 		failOnExpectError(t),
 		failOnSendError(t),
-		expect.WithDefaultTimeout(time.Second * 600),
+		expect.WithDefaultTimeout(time.Second),
 	}
 
 	console, err := expect.NewConsole(consoleOpts...)
 	require.NoError(t, err)
 	t.Cleanup(func() { testCloser(t, console) })
 
-	// Using echo as the editor command here because it will immediately exit
-	// and return no input.
-	p := prompter.New("echo", console.Tty(), console.Tty(), console.Tty())
-
-	var wg sync.WaitGroup
-
-	// This not a comprehensive test of the survey prompter, but it does
-	// demonstrate that the survey prompter is used when the
-	// accessible prompter is disabled.
-	t.Run("Select uses survey prompter when accessible prompter is disabled", func(t *testing.T) {
-		wg.Add(1)
+	return console
+}
 
-		go func() {
-			defer wg.Done()
-			// Wait for prompt to appear
-			_, err := console.ExpectString("Select a number")
-			require.NoError(t, err)
+func newTestAcessiblePrompter(t testing.TB, console *expect.Console) prompter.Prompter {
+	t.Helper()
 
-			// Send a newline to select the first option
-			// Note: This would not work with the accessible prompter
-			// because it would requires sending a 1 to select the first option.
-			// So it proves we are seeing a survey prompter.
-			_, err = console.SendLine("")
-			require.NoError(t, err)
-		}()
+	t.Setenv("GH_ACCESSIBLE_PROMPTER", "true")
+	return prompter.New("echo", console.Tty(), console.Tty(), console.Tty())
+}
 
-		selectValue, err := p.Select("Select a number", "", []string{"1", "2", "3"})
-		require.NoError(t, err)
-		assert.Equal(t, 0, selectValue)
+func newTestSurveyPrompter(t testing.TB, console *expect.Console) prompter.Prompter {
+	t.Helper()
 
-		wg.Wait()
-	})
+	t.Setenv("GH_ACCESSIBLE_PROMPTER", "false")
+	return prompter.New("echo", console.Tty(), console.Tty(), console.Tty())
 }
 
 // failOnExpectError adds an observer that will fail the test in a standardised way
EOF_114329324912

# Set environment variable required for accessible prompter tests
export GH_ACCESSIBLE_PROMPTER=true

# Run the tests using the package path with pattern matching
# This allows Go to properly resolve all dependencies within the package
# The -run flag ensures only accessible prompter tests are executed
go test -v ./internal/prompter -run 'TestAccessible.*'

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 2f5e8965355bd120364cccb52e6f973a6e85718c "internal/prompter/accessible_prompter_test.go"