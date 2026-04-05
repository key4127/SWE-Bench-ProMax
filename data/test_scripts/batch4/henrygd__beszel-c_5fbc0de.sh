#!/bin/bash
set -uxo pipefail

# Navigate to testbed root
cd /testbed

# Checkout the original test file to ensure clean state
git checkout c8130a10d4939e2e39ce053039ed1e1c4ddd3982 "beszel/cmd/agent/agent_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/beszel/cmd/agent/agent_test.go b/beszel/cmd/agent/agent_test.go
--- a/beszel/cmd/agent/agent_test.go
+++ b/beszel/cmd/agent/agent_test.go
@@ -27,22 +27,22 @@ func TestGetAddress(t *testing.T) {
 		{
 			name: "use address from flag",
 			opts: cmdOptions{
-				addr: "8080",
+				listen: "8080",
 			},
 			expected: "8080",
 		},
 		{
 			name: "use unix socket from flag",
 			opts: cmdOptions{
-				addr: "/tmp/beszel.sock",
+				listen: "/tmp/beszel.sock",
 			},
 			expected: "/tmp/beszel.sock",
 		},
 		{
-			name: "use ADDR env var",
+			name: "use LISTEN env var",
 			opts: cmdOptions{},
 			envVars: map[string]string{
-				"ADDR": "1.2.3.4:9090",
+				"LISTEN": "1.2.3.4:9090",
 			},
 			expected: "1.2.3.4:9090",
 		},
@@ -57,21 +57,21 @@ func TestGetAddress(t *testing.T) {
 		{
 			name: "use unix socket from env var",
 			opts: cmdOptions{
-				addr: "",
+				listen: "",
 			},
 			envVars: map[string]string{
-				"ADDR": "/tmp/beszel.sock",
+				"LISTEN": "/tmp/beszel.sock",
 			},
 			expected: "/tmp/beszel.sock",
 		},
 		{
 			name: "flag takes precedence over env vars",
 			opts: cmdOptions{
-				addr: ":8080",
+				listen: ":8080",
 			},
 			envVars: map[string]string{
-				"ADDR": ":9090",
-				"PORT": "7070",
+				"LISTEN": ":9090",
+				"PORT":   "7070",
 			},
 			expected: ":8080",
 		},
@@ -201,27 +201,27 @@ func TestGetNetwork(t *testing.T) {
 		},
 		{
 			name:     "only port",
-			opts:     cmdOptions{addr: "8080"},
+			opts:     cmdOptions{listen: "8080"},
 			expected: "tcp",
 		},
 		{
 			name:     "ipv4 address",
-			opts:     cmdOptions{addr: "1.2.3.4:8080"},
+			opts:     cmdOptions{listen: "1.2.3.4:8080"},
 			expected: "tcp",
 		},
 		{
 			name:     "ipv6 address",
-			opts:     cmdOptions{addr: "[2001:db8::1]:8080"},
+			opts:     cmdOptions{listen: "[2001:db8::1]:8080"},
 			expected: "tcp",
 		},
 		{
 			name:     "unix network",
-			opts:     cmdOptions{addr: "/tmp/beszel.sock"},
+			opts:     cmdOptions{listen: "/tmp/beszel.sock"},
 			expected: "unix",
 		},
 		{
 			name:     "env var network",
-			opts:     cmdOptions{addr: ":8080"},
+			opts:     cmdOptions{listen: ":8080"},
 			envVars:  map[string]string{"NETWORK": "tcp4"},
 			expected: "tcp4",
 		},
@@ -256,32 +256,32 @@ func TestParseFlags(t *testing.T) {
 			name: "no flags",
 			args: []string{"cmd"},
 			expected: cmdOptions{
-				key:  "",
-				addr: "",
+				key:    "",
+				listen: "",
 			},
 		},
 		{
 			name: "key flag only",
 			args: []string{"cmd", "-key", "testkey"},
 			expected: cmdOptions{
-				key:  "testkey",
-				addr: "",
+				key:    "testkey",
+				listen: "",
 			},
 		},
 		{
 			name: "addr flag only",
-			args: []string{"cmd", "-addr", ":8080"},
+			args: []string{"cmd", "-listen", ":8080"},
 			expected: cmdOptions{
-				key:  "",
-				addr: ":8080",
+				key:    "",
+				listen: ":8080",
 			},
 		},
 		{
 			name: "both flags",
-			args: []string{"cmd", "-key", "testkey", "-addr", ":8080"},
+			args: []string{"cmd", "-key", "testkey", "-listen", ":8080"},
 			expected: cmdOptions{
-				key:  "testkey",
-				addr: ":8080",
+				key:    "testkey",
+				listen: ":8080",
 			},
 		},
 	}
EOF_114329324912

# Navigate to the beszel subdirectory where go.mod is located
cd /testbed/beszel

# Set required environment variables
export GOEXPERIMENT=synctest
export CGO_ENABLED=0

# Run the target test file with required flags
# -v: verbose output for better debugging
# -tags=testing: required build tag as specified in Makefile
# ./cmd/agent/: target test package
go test -v -tags=testing ./cmd/agent/

# Capture exit code immediately
rc=$?

# Echo exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
cd /testbed
git checkout c8130a10d4939e2e39ce053039ed1e1c4ddd3982 "beszel/cmd/agent/agent_test.go"