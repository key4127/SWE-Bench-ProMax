#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 97d3253aaf11ba6f1a366afc8be6772719b301cd "pkg/cmd/agent-task/shared/log_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/agent-task/shared/log_test.go b/pkg/cmd/agent-task/shared/log_test.go
--- a/pkg/cmd/agent-task/shared/log_test.go
+++ b/pkg/cmd/agent-task/shared/log_test.go
@@ -13,19 +13,26 @@ import (
 
 func TestFollow(t *testing.T) {
 	tests := []struct {
-		name string
-		log  string
-		want string
+		name           string
+		log            string
+		wantStdoutFile string
+		wantStderrFile string
 	}{
 		{
-			name: "sample log 1",
-			log:  "testdata/log-1-input.txt",
-			want: "testdata/log-1-want.txt",
+			name:           "sample log 1",
+			log:            "testdata/log-1-input.txt",
+			wantStdoutFile: "testdata/log-1-want.txt",
 		},
 		{
-			name: "sample log 2",
-			log:  "testdata/log-2-input.txt",
-			want: "testdata/log-2-want.txt",
+			name:           "sample log 2",
+			log:            "testdata/log-2-input.txt",
+			wantStdoutFile: "testdata/log-2-want.txt",
+		},
+		{
+			name:           "sample log 3 (tolerant parse failures)",
+			log:            "testdata/log-3-synthetic-failures-input.txt",
+			wantStdoutFile: "testdata/log-3-synthetic-failures-want.txt",
+			wantStderrFile: "testdata/log-3-synthetic-failures-want-stderr.txt",
 		},
 	}
 
@@ -50,7 +57,7 @@ func TestFollow(t *testing.T) {
 				return []byte(strings.Join(lines[0:hits], "\n\n")), nil
 			}
 
-			ios, _, stdout, _ := iostreams.Test()
+			ios, _, stdout, stderr := iostreams.Test()
 
 			err = NewLogRenderer().Follow(fetcher, stdout, ios)
 			require.NoError(t, err)
@@ -60,14 +67,29 @@ func TestFollow(t *testing.T) {
 			// stripped := strings.TrimSuffix(tt.log, ext)
 			// stripped = strings.TrimSuffix(stripped, "-input")
 			// os.WriteFile(stripped+"-want"+ext, stdout.Bytes(), 0644)
+			// if tt.wantStderrFile != "" {
+			// 	os.WriteFile(stripped+"-want-stderr"+ext, stderr.Bytes(), 0644)
+			// }
 
-			want, err := os.ReadFile(tt.want)
+			wantStdout, err := os.ReadFile(tt.wantStdoutFile)
 			require.NoError(t, err)
 
 			// Normalize CRLF to LF to make the tests OS-agnostic.
-			want = []byte(strings.ReplaceAll(string(want), "\r\n", "\n"))
+			wantStdout = []byte(strings.ReplaceAll(string(wantStdout), "\r\n", "\n"))
+
+			assert.Equal(t, string(wantStdout), stdout.String())
 
-			assert.Equal(t, string(want), stdout.String())
+			if tt.wantStderrFile != "" {
+				wantStderr, err := os.ReadFile(tt.wantStderrFile)
+				require.NoError(t, err)
+
+				// Normalize CRLF to LF to make the tests OS-agnostic.
+				wantStderr = []byte(strings.ReplaceAll(string(wantStderr), "\r\n", "\n"))
+
+				assert.Equal(t, string(wantStderr), stderr.String())
+			} else {
+				require.Empty(t, stderr, "expected no stderr output")
+			}
 		})
 	}
 }
diff --git a/pkg/cmd/agent-task/shared/testdata/log-3-input.txt b/pkg/cmd/agent-task/shared/testdata/log-3-input.txt
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/agent-task/shared/testdata/log-3-input.txt
@@ -0,0 +1,27 @@
+data: {"id": "bad1", "object": "chat.completion.chunk", "choices": [ { "delta": { "tool_calls": [ { "function": { "name": "view", "arguments": "{bad json" } } ] } } ] }
+
+data: {"id":"v1","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line\nINSIDE A VIEW CALL","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md\"}"},"id":"tc1","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"v1b","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md\"}"},"id":"tc1b","index":0}]}],"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"v1","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line\nINSIDE A VIEW CALL","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md"},"id":"tc1","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"t1","object":"chat.completion.chunk","choices":[{"delta":{"content":"THINK","tool_calls":[{"function":{"name":"think","arguments":"{\"thought\":123"},"id":"tc2","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"t2","object":"chat.completion.chunk","choices":[{"delta":{"content":"A valid thought to render.","reasoning_text":"Interim reasoning that should show as raw markdown.","tool_calls":[{"function":{"name":"think","arguments":"{\"thought\":\"A valid thought to render.\"}"},"id":"tc3","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"rp1","object":"chat.completion.chunk","choices":[{"delta":{"content":"RP","tool_calls":[{"function":{"name":"report_progress","arguments":"{\"commitMessage\": 5"},"id":"tc4","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"rp2","object":"chat.completion.chunk","choices":[{"delta":{"content":"not-json","tool_calls":[{"function":{"name":"report_progress","arguments":"{\"commitMessage\":\"Valid commit msg\"}"},"id":"tc5","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"c1","object":"chat.completion.chunk","choices":[{"delta":{"content":"CREATE","tool_calls":[{"function":{"name":"create","arguments":"{\"path\":\"/abs/path/file.txt\""},"id":"tc6","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"c2","object":"chat.completion.chunk","choices":[{"delta":{"content":"CREATE2","tool_calls":[{"function":{"name":"create","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/new.txt\",\"file_text\":\"hello world\"}"},"id":"tc7","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"sr1","object":"chat.completion.chunk","choices":[{"delta":{"content":"SR","tool_calls":[{"function":{"name":"str_replace","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/file.diff"},"id":"tc8","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"sr2","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line","tool_calls":[{"function":{"name":"str_replace","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/file.diff\"}"},"id":"tc9","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"u1","object":"chat.completion.chunk","choices":[{"delta":{"content":"{\"foo\":1}","tool_calls":[{"function":{"name":"mystery_tool","arguments":"{\"bar\":2}"},"id":"tc10","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"end","object":"chat.completion.chunk","choices":[{"delta":{"content":"","tool_calls":[],"role":"assistant"},"finish_reason":"stop","index":0}]}
diff --git a/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-input.txt b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-input.txt
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-input.txt
@@ -0,0 +1,27 @@
+data: {"id": "bad1", "object": "chat.completion.chunk", "choices": [ { "delta": { "tool_calls": [ { "function": { "name": "view", "arguments": "{bad json" } } ] } } ] }
+
+data: {"id":"v1","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line\nINSIDE A VIEW CALL","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md\"}"},"id":"tc1","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"v1b","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md\"}"},"id":"tc1b","index":0}]}],"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"v1","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line\nINSIDE A VIEW CALL","tool_calls":[{"function":{"name":"view","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/README.md"},"id":"tc1","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"t1","object":"chat.completion.chunk","choices":[{"delta":{"content":"THINK","tool_calls":[{"function":{"name":"think","arguments":"{\"thought\":123"},"id":"tc2","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"t2","object":"chat.completion.chunk","choices":[{"delta":{"content":"A valid thought to render.","reasoning_text":"Interim reasoning that should show as raw markdown.","tool_calls":[{"function":{"name":"think","arguments":"{\"thought\":\"A valid thought to render.\"}"},"id":"tc3","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"rp1","object":"chat.completion.chunk","choices":[{"delta":{"content":"RP","tool_calls":[{"function":{"name":"report_progress","arguments":"{\"commitMessage\": 5"},"id":"tc4","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"rp2","object":"chat.completion.chunk","choices":[{"delta":{"content":"not-json","tool_calls":[{"function":{"name":"report_progress","arguments":"{\"commitMessage\":\"Valid commit msg\"}"},"id":"tc5","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"c1","object":"chat.completion.chunk","choices":[{"delta":{"content":"CREATE","tool_calls":[{"function":{"name":"create","arguments":"{\"path\":\"/abs/path/file.txt\""},"id":"tc6","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"c2","object":"chat.completion.chunk","choices":[{"delta":{"content":"CREATE2","tool_calls":[{"function":{"name":"create","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/new.txt\",\"file_text\":\"hello world\"}"},"id":"tc7","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"sr1","object":"chat.completion.chunk","choices":[{"delta":{"content":"SR","tool_calls":[{"function":{"name":"str_replace","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/file.diff"},"id":"tc8","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"sr2","object":"chat.completion.chunk","choices":[{"delta":{"content":"@@ -1,2 +1,2 @@\n-old line\n+new line\nunchanged line","tool_calls":[{"function":{"name":"str_replace","arguments":"{\"path\":\"/home/runner/work/repo/owner/repo/file.diff\"}"},"id":"tc9","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"u1","object":"chat.completion.chunk","choices":[{"delta":{"content":"{\"foo\":1}","tool_calls":[{"function":{"name":"mystery_tool","arguments":"{\"bar\":2}"},"id":"tc10","index":0}]},"finish_reason":"tool_calls","index":0}]}
+
+data: {"id":"end","object":"chat.completion.chunk","choices":[{"delta":{"content":"","tool_calls":[],"role":"assistant"},"finish_reason":"stop","index":0}]}
diff --git a/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want-stderr.txt b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want-stderr.txt
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want-stderr.txt
@@ -0,0 +1,10 @@
+
+failed to parse 'view' tool call arguments: unexpected end of JSON input
+
+failed to parse 'think' tool call arguments: unexpected end of JSON input
+
+failed to parse 'report_progress' tool call arguments: unexpected end of JSON input
+
+failed to parse 'create' tool call arguments: unexpected end of JSON input
+
+failed to parse 'str_replace' tool call arguments: unexpected end of JSON input
diff --git a/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want.txt b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want.txt
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/agent-task/shared/testdata/log-3-synthetic-failures-want.txt
@@ -0,0 +1,39 @@
+View repo/README.md
+
+old line                                                                    
+  new line                                                                    
+  unchanged line                                                              
+  INSIDE A VIEW CALL
+
+
+Interim reasoning that should show as raw markdown.
+
+Thought
+
+A valid thought to render.
+
+Progress update: Valid commit msg
+Create: repo/new.txt
+hello world
+
+Edit: repo/file.diff
+@@ -1,2 +1,2 @@                                                           
+    -old line                                                                 
+    +new line                                                                 
+    unchanged line
+
+Call to mystery_tool
+
+Output:
+
+{                                                                         
+      "foo": 1                                                                
+    }
+
+
+Input:
+
+{                                                                         
+      "bar": 2                                                                
+    }
+
diff --git a/pkg/cmd/agent-task/shared/testdata/log-3-want.txt b/pkg/cmd/agent-task/shared/testdata/log-3-want.txt
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/agent-task/shared/testdata/log-3-want.txt
@@ -0,0 +1,39 @@
+View repo/README.md
+
+old line                                                                    
+  new line                                                                    
+  unchanged line                                                              
+  INSIDE A VIEW CALL
+
+
+Interim reasoning that should show as raw markdown.
+
+Thought
+
+A valid thought to render.
+
+Progress update: Valid commit msg
+Create: repo/new.txt
+hello world
+
+Edit: repo/file.diff
+@@ -1,2 +1,2 @@                                                           
+    -old line                                                                 
+    +new line                                                                 
+    unchanged line
+
+Call to mystery_tool
+
+Output:
+
+{                                                                         
+      "foo": 1                                                                
+    }
+
+
+Input:
+
+{                                                                         
+      "bar": 2                                                                
+    }
+
EOF_114329324912

# Run the target test
# Using the specific test command from context retrieval agent
go test -v ./pkg/cmd/agent-task/shared -run TestFollow
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 97d3253aaf11ba6f1a366afc8be6772719b301cd "pkg/cmd/agent-task/shared/log_test.go"