#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout e2bed653dfb3ee6d70fcd12655a17069c38992e9

# Checkout the specific test file to ensure it's in the correct state
git checkout e2bed653dfb3ee6d70fcd12655a17069c38992e9 "pkg/cmd/pr/shared/params_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/shared/params_test.go b/pkg/cmd/pr/shared/params_test.go
--- a/pkg/cmd/pr/shared/params_test.go
+++ b/pkg/cmd/pr/shared/params_test.go
@@ -192,21 +192,21 @@ func TestCopilotReplacer_ReplaceSlice(t *testing.T) {
 		handles []string
 	}
 	tests := []struct {
-		name    string
-		webMode bool
-		args    args
-		want    []string
+		name        string
+		returnLogin bool
+		args        args
+		want        []string
 	}{
 		{
-			name: "replaces @copilot with copilot-swe-agent for non-web mode",
+			name:        "replaces @copilot with copilot-swe-agent for non-web mode",
+			returnLogin: true,
 			args: args{
 				handles: []string{"monalisa", "@copilot", "hubot"},
 			},
 			want: []string{"monalisa", "copilot-swe-agent", "hubot"},
 		},
 		{
-			name:    "replaces @copilot with copilot for web mode",
-			webMode: true,
+			name: "replaces @copilot with copilot for web mode",
 			args: args{
 				handles: []string{"monalisa", "@copilot", "hubot"},
 			},
@@ -220,14 +220,16 @@ func TestCopilotReplacer_ReplaceSlice(t *testing.T) {
 			want: []string{"monalisa", "user", "hubot"},
 		},
 		{
-			name: "replaces multiple @copilot mentions",
+			name:        "replaces multiple @copilot mentions",
+			returnLogin: true,
 			args: args{
 				handles: []string{"@copilot", "user", "@copilot"},
 			},
 			want: []string{"copilot-swe-agent", "user", "copilot-swe-agent"},
 		},
 		{
-			name: "handles @copilot case-insensitively",
+			name:        "handles @copilot case-insensitively",
+			returnLogin: true,
 			args: args{
 				handles: []string{"@Copilot", "user", "@CoPiLoT"},
 			},
@@ -250,7 +252,7 @@ func TestCopilotReplacer_ReplaceSlice(t *testing.T) {
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			r := NewCopilotReplacer(tt.webMode)
+			r := NewCopilotReplacer(tt.returnLogin)
 			got := r.ReplaceSlice(tt.args.handles)
 			require.Equal(t, tt.want, got)
 		})
EOF_114329324912

# Run the target test file
# Using the test command identified by the context retrieval agent
# Running tests for the specific package containing the target test file
go test -v ./pkg/cmd/pr/shared/

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout e2bed653dfb3ee6d70fcd12655a17069c38992e9 "pkg/cmd/pr/shared/params_test.go"