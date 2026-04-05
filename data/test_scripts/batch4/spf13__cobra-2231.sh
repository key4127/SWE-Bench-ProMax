#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 17b6dca2ffaf6113cbd1cf433ec988fa7d63c6f3 "completions_test.go"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/completions_test.go b/completions_test.go
--- a/completions_test.go
+++ b/completions_test.go
@@ -2872,6 +2872,56 @@ func TestFixedCompletions(t *testing.T) {
 	}
 }
 
+func TestFixedCompletionsWithCompletionHelpers(t *testing.T) {
+	rootCmd := &Command{Use: "root", Args: NoArgs, Run: emptyRun}
+	// here we are mixing string, [Completion] and [CompletionWithDesc]
+	choices := []string{"apple", Completion("banana"), CompletionWithDesc("orange", "orange are orange")}
+	childCmd := &Command{
+		Use:               "child",
+		ValidArgsFunction: FixedCompletions(choices, ShellCompDirectiveNoFileComp),
+		Run:               emptyRun,
+	}
+	rootCmd.AddCommand(childCmd)
+
+	t.Run("completion with description", func(t *testing.T) {
+		output, err := executeCommand(rootCmd, ShellCompRequestCmd, "child", "a")
+		if err != nil {
+			t.Errorf("Unexpected error: %v", err)
+		}
+
+		expected := strings.Join([]string{
+			"apple",
+			"banana",
+			"orange\torange are orange", // this one has the description as expected with [ShellCompRequestCmd] flag
+			":4",
+			"Completion ended with directive: ShellCompDirectiveNoFileComp", "",
+		}, "\n")
+
+		if output != expected {
+			t.Errorf("expected: %q, got: %q", expected, output)
+		}
+	})
+
+	t.Run("completion with no description", func(t *testing.T) {
+		output, err := executeCommand(rootCmd, ShellCompNoDescRequestCmd, "child", "a")
+		if err != nil {
+			t.Errorf("Unexpected error: %v", err)
+		}
+
+		expected := strings.Join([]string{
+			"apple",
+			"banana",
+			"orange", // the description is absent as expected with [ShellCompNoDescRequestCmd] flag
+			":4",
+			"Completion ended with directive: ShellCompDirectiveNoFileComp", "",
+		}, "\n")
+
+		if output != expected {
+			t.Errorf("expected: %q, got: %q", expected, output)
+		}
+	})
+}
+
 func TestCompletionForGroupedFlags(t *testing.T) {
 	getCmd := func() *Command {
 		rootCmd := &Command{
EOF_114329324912

# Ensure Go modules are properly initialized
go mod download
go mod verify

# Run tests from completions_test.go only
# We need to compile with the package context but run only specific tests
# First, get the list of test functions from completions_test.go
test_funcs=$(grep -E '^func Test' completions_test.go | sed 's/func \([^(]*\).*/\1/' | paste -sd '|')

# Run only the tests from completions_test.go using the extracted test names
go test -v -run "^($test_funcs)$" .
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 17b6dca2ffaf6113cbd1cf433ec988fa7d63c6f3 "completions_test.go"