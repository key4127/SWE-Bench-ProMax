#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 54da786bec22bb64f298bacb1b72a721ddca2f24 "pkg/cmd/pr/shared/finder_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/shared/finder_test.go b/pkg/cmd/pr/shared/finder_test.go
--- a/pkg/cmd/pr/shared/finder_test.go
+++ b/pkg/cmd/pr/shared/finder_test.go
@@ -972,6 +972,52 @@ func TestPRRefs_GetPRHeadLabel(t *testing.T) {
 	}
 }
 
+func TestPullRequestRefs_HasHead(t *testing.T) {
+	tests := []struct {
+		name   string
+		prRefs PullRequestRefs
+		want   bool
+	}{
+		{
+			name: "HeadRepo is nil and BranchName is empty, return false",
+			prRefs: PullRequestRefs{
+				HeadRepo:   nil,
+				BranchName: "",
+			},
+			want: false,
+		},
+		{
+			name: "HeadRepo is not nil and BranchName is empty, return false",
+			prRefs: PullRequestRefs{
+				HeadRepo:   ghrepo.New("ORIGINOWNER", "REPO"),
+				BranchName: "",
+			},
+			want: false,
+		},
+		{
+			name: "HeadRepo is nil and BranchName is not empty, return false",
+			prRefs: PullRequestRefs{
+				HeadRepo:   nil,
+				BranchName: "feature-branch",
+			},
+			want: false,
+		},
+		{
+			name: "HeadRepo is not nil and BranchName is not empty, return true",
+			prRefs: PullRequestRefs{
+				HeadRepo:   ghrepo.New("ORIGINOWNER", "REPO"),
+				BranchName: "feature-branch",
+			},
+			want: true,
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			assert.Equal(t, tt.want, tt.prRefs.HasHead())
+		})
+	}
+}
+
 func stubBranchConfig(branchConfig git.BranchConfig, err error) func(string) (git.BranchConfig, error) {
 	return func(branch string) (git.BranchConfig, error) {
 		return branchConfig, err
EOF_114329324912

# Run the entire package (recommended approach for Go tests)
# This ensures all package dependencies are included
go test -v ./pkg/cmd/pr/shared/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 54da786bec22bb64f298bacb1b72a721ddca2f24 "pkg/cmd/pr/shared/finder_test.go"