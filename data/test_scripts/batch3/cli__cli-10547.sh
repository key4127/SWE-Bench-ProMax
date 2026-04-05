#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout 2b89358543d1fe9c0be902992a05d6f6a2fe4b15

# Checkout the specific test file to ensure it's in the correct state
git checkout 2b89358543d1fe9c0be902992a05d6f6a2fe4b15 "pkg/cmd/pr/create/create_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/create/create_test.go b/pkg/cmd/pr/create/create_test.go
--- a/pkg/cmd/pr/create/create_test.go
+++ b/pkg/cmd/pr/create/create_test.go
@@ -1590,6 +1590,28 @@ func Test_createRun(t *testing.T) {
 			},
 			expectedOut: "https://github.com/OWNER/REPO/pull/12\n",
 		},
+		{
+			name: "web prioritize title and body over fill",
+			setup: func(opts *CreateOptions, t *testing.T) func() {
+				opts.WebMode = true
+				opts.HeadBranch = "feature"
+				opts.TitleProvided = true
+				opts.BodyProvided = true
+				opts.Title = "my title"
+				opts.Body = "my body"
+				opts.Autofill = true
+				return func() {}
+			},
+			cmdStubs: func(cs *run.CommandStubber) {
+				cs.Register(
+					"git -c log.ShowSignature=false log --pretty=format:%H%x00%s%x00%b%x00 --cherry origin/master...feature",
+					0,
+					"56b6f8bb7c9e3a30093cd17e48934ce354148e80\u0000second commit of pr\u0000\u0000\n"+
+						"3a9b48085046d156c5acce8f3b3a0532cd706a4a\u0000first commit of pr\u0000first commit description\u0000\n",
+				)
+			},
+			expectedBrowse: "https://github.com/OWNER/REPO/compare/master...feature?body=my+body&expand=1&title=my+title",
+		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
EOF_114329324912

# Run the target test file
# Using the test command identified by the context retrieval agent
# Running tests for the specific package containing the target test file
go test -v ./pkg/cmd/pr/create/

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout 2b89358543d1fe9c0be902992a05d6f6a2fe4b15 "pkg/cmd/pr/create/create_test.go"