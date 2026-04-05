#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout 44aadc37c9c0810f3a41189929ae21c613b6bc98 "modules/templates/util_date_test.go" "modules/templates/util_render_test.go" "templates/repo/latest_commit.tmpl"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/modules/templates/util_date_test.go b/modules/templates/util_date_test.go
--- a/modules/templates/util_date_test.go
+++ b/modules/templates/util_date_test.go
@@ -17,6 +17,7 @@ import (
 func TestDateTime(t *testing.T) {
 	testTz, _ := time.LoadLocation("America/New_York")
 	defer test.MockVariableValue(&setting.DefaultUILocation, testTz)()
+	defer test.MockVariableValue(&setting.IsProd, true)()
 	defer test.MockVariableValue(&setting.IsInTesting, false)()
 
 	du := NewDateUtils()
@@ -53,6 +54,7 @@ func TestDateTime(t *testing.T) {
 func TestTimeSince(t *testing.T) {
 	testTz, _ := time.LoadLocation("America/New_York")
 	defer test.MockVariableValue(&setting.DefaultUILocation, testTz)()
+	defer test.MockVariableValue(&setting.IsProd, true)()
 	defer test.MockVariableValue(&setting.IsInTesting, false)()
 
 	du := NewDateUtils()
diff --git a/modules/templates/util_render_test.go b/modules/templates/util_render_test.go
--- a/modules/templates/util_render_test.go
+++ b/modules/templates/util_render_test.go
@@ -11,11 +11,11 @@ import (
 	"testing"
 
 	"code.gitea.io/gitea/models/issues"
-	"code.gitea.io/gitea/models/unittest"
-	"code.gitea.io/gitea/modules/git"
-	"code.gitea.io/gitea/modules/log"
+	"code.gitea.io/gitea/models/repo"
+	user_model "code.gitea.io/gitea/models/user"
 	"code.gitea.io/gitea/modules/markup"
 	"code.gitea.io/gitea/modules/reqctx"
+	"code.gitea.io/gitea/modules/setting"
 	"code.gitea.io/gitea/modules/test"
 	"code.gitea.io/gitea/modules/translation"
 
@@ -47,19 +47,8 @@ mail@domain.com
 	return strings.ReplaceAll(s, "<SPACE>", " ")
 }
 
-var testMetas = map[string]string{
-	"user":                         "user13",
-	"repo":                         "repo11",
-	"repoPath":                     "../../tests/gitea-repositories-meta/user13/repo11.git/",
-	"markdownNewLineHardBreak":     "true",
-	"markupAllowShortIssuePattern": "true",
-}
-
 func TestMain(m *testing.M) {
-	unittest.InitSettingsForTesting()
-	if err := git.InitSimple(context.Background()); err != nil {
-		log.Fatal("git init failed, err: %v", err)
-	}
+	setting.Markdown.RenderOptionsComment.ShortIssuePattern = true
 	markup.Init(&markup.RenderHelperFuncs{
 		IsUsernameMentionable: func(ctx context.Context, username string) bool {
 			return username == "mention-user"
@@ -74,46 +63,52 @@ func newTestRenderUtils(t *testing.T) *RenderUtils {
 	return NewRenderUtils(ctx)
 }
 
-func TestRenderCommitBody(t *testing.T) {
-	defer test.MockVariableValue(&markup.RenderBehaviorForTesting.DisableAdditionalAttributes, true)()
-	type args struct {
-		msg string
+func TestRenderRepoComment(t *testing.T) {
+	mockRepo := &repo.Repository{
+		ID: 1, OwnerName: "user13", Name: "repo11",
+		Owner: &user_model.User{ID: 13, Name: "user13"},
+		Units: []*repo.RepoUnit{},
 	}
-	tests := []struct {
-		name string
-		args args
-		want template.HTML
-	}{
-		{
-			name: "multiple lines",
-			args: args{
-				msg: "first line\nsecond line",
+	t.Run("RenderCommitBody", func(t *testing.T) {
+		defer test.MockVariableValue(&markup.RenderBehaviorForTesting.DisableAdditionalAttributes, true)()
+		type args struct {
+			msg string
+		}
+		tests := []struct {
+			name string
+			args args
+			want template.HTML
+		}{
+			{
+				name: "multiple lines",
+				args: args{
+					msg: "first line\nsecond line",
+				},
+				want: "second line",
 			},
-			want: "second line",
-		},
-		{
-			name: "multiple lines with leading newlines",
-			args: args{
-				msg: "\n\n\n\nfirst line\nsecond line",
+			{
+				name: "multiple lines with leading newlines",
+				args: args{
+					msg: "\n\n\n\nfirst line\nsecond line",
+				},
+				want: "second line",
 			},
-			want: "second line",
-		},
-		{
-			name: "multiple lines with trailing newlines",
-			args: args{
-				msg: "first line\nsecond line\n\n\n",
+			{
+				name: "multiple lines with trailing newlines",
+				args: args{
+					msg: "first line\nsecond line\n\n\n",
+				},
+				want: "second line",
 			},
-			want: "second line",
-		},
-	}
-	ut := newTestRenderUtils(t)
-	for _, tt := range tests {
-		t.Run(tt.name, func(t *testing.T) {
-			assert.Equalf(t, tt.want, ut.RenderCommitBody(tt.args.msg, nil), "RenderCommitBody(%v, %v)", tt.args.msg, nil)
-		})
-	}
-
-	expected := `/just/a/path.bin
+		}
+		ut := newTestRenderUtils(t)
+		for _, tt := range tests {
+			t.Run(tt.name, func(t *testing.T) {
+				assert.Equalf(t, tt.want, ut.RenderCommitBody(tt.args.msg, mockRepo), "RenderCommitBody(%v, %v)", tt.args.msg, nil)
+			})
+		}
+
+		expected := `/just/a/path.bin
 <a href="https://example.com/file.bin">https://example.com/file.bin</a>
 [local link](file.bin)
 [remote link](<a href="https://example.com">https://example.com</a>)
@@ -132,22 +127,22 @@ com 88fc37a3c0a4dda553bdcfc80c178a58247f42fb mit
 <a href="/mention-user">@mention-user</a> test
 <a href="/user13/repo11/issues/123" class="ref-issue">#123</a>
   space`
-	assert.Equal(t, expected, string(newTestRenderUtils(t).RenderCommitBody(testInput(), testMetas)))
-}
+		assert.Equal(t, expected, string(newTestRenderUtils(t).RenderCommitBody(testInput(), mockRepo)))
+	})
 
-func TestRenderCommitMessage(t *testing.T) {
-	expected := `space <a href="/mention-user" data-markdown-generated-content="">@mention-user</a>  `
-	assert.EqualValues(t, expected, newTestRenderUtils(t).RenderCommitMessage(testInput(), testMetas))
-}
+	t.Run("RenderCommitMessage", func(t *testing.T) {
+		expected := `space <a href="/mention-user" data-markdown-generated-content="">@mention-user</a>  `
+		assert.EqualValues(t, expected, newTestRenderUtils(t).RenderCommitMessage(testInput(), mockRepo))
+	})
 
-func TestRenderCommitMessageLinkSubject(t *testing.T) {
-	expected := `<a href="https://example.com/link" class="muted">space </a><a href="/mention-user" data-markdown-generated-content="">@mention-user</a>`
-	assert.EqualValues(t, expected, newTestRenderUtils(t).RenderCommitMessageLinkSubject(testInput(), "https://example.com/link", testMetas))
-}
+	t.Run("RenderCommitMessageLinkSubject", func(t *testing.T) {
+		expected := `<a href="https://example.com/link" class="muted">space </a><a href="/mention-user" data-markdown-generated-content="">@mention-user</a>`
+		assert.EqualValues(t, expected, newTestRenderUtils(t).RenderCommitMessageLinkSubject(testInput(), "https://example.com/link", mockRepo))
+	})
 
-func TestRenderIssueTitle(t *testing.T) {
-	defer test.MockVariableValue(&markup.RenderBehaviorForTesting.DisableAdditionalAttributes, true)()
-	expected := `  space @mention-user<SPACE><SPACE>
+	t.Run("RenderIssueTitle", func(t *testing.T) {
+		defer test.MockVariableValue(&markup.RenderBehaviorForTesting.DisableAdditionalAttributes, true)()
+		expected := `  space @mention-user<SPACE><SPACE>
 /just/a/path.bin
 https://example.com/file.bin
 [local link](file.bin)
@@ -168,8 +163,9 @@ mail@domain.com
 <a href="/user13/repo11/issues/123" class="ref-issue">#123</a>
   space<SPACE><SPACE>
 `
-	expected = strings.ReplaceAll(expected, "<SPACE>", " ")
-	assert.Equal(t, expected, string(newTestRenderUtils(t).RenderIssueTitle(testInput(), testMetas)))
+		expected = strings.ReplaceAll(expected, "<SPACE>", " ")
+		assert.Equal(t, expected, string(newTestRenderUtils(t).RenderIssueTitle(testInput(), mockRepo)))
+	})
 }
 
 func TestRenderMarkdownToHtml(t *testing.T) {
diff --git a/templates/repo/latest_commit.tmpl b/templates/repo/latest_commit.tmpl
--- a/templates/repo/latest_commit.tmpl
+++ b/templates/repo/latest_commit.tmpl
@@ -21,10 +21,10 @@
 	{{template "repo/commit_statuses" dict "Status" .LatestCommitStatus "Statuses" .LatestCommitStatuses}}
 
 	{{$commitLink:= printf "%s/commit/%s" .RepoLink (PathEscape .LatestCommit.ID.String)}}
-	<span class="grey commit-summary" title="{{.LatestCommit.Summary}}"><span class="message-wrapper">{{ctx.RenderUtils.RenderCommitMessageLinkSubject .LatestCommit.Message $commitLink ($.Repository.ComposeCommentMetas ctx)}}</span>
+	<span class="grey commit-summary" title="{{.LatestCommit.Summary}}"><span class="message-wrapper">{{ctx.RenderUtils.RenderCommitMessageLinkSubject .LatestCommit.Message $commitLink $.Repository}}</span>
 		{{if IsMultilineCommitMessage .LatestCommit.Message}}
 			<button class="ui button ellipsis-button" aria-expanded="false" data-global-click="onRepoEllipsisButtonClick">...</button>
-			<pre class="commit-body tw-hidden">{{ctx.RenderUtils.RenderCommitBody .LatestCommit.Message ($.Repository.ComposeCommentMetas ctx)}}</pre>
+			<pre class="commit-body tw-hidden">{{ctx.RenderUtils.RenderCommitBody .LatestCommit.Message $.Repository}}</pre>
 		{{end}}
 	</span>
 {{end}}
EOF_114329324912

# Run the target tests with proper build tags
# Using the command from context retrieval agent
# Testing the modules/templates package which contains the target test files
go test -v -tags='bindata sqlite sqlite_unlock_notify' ./modules/templates/
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 44aadc37c9c0810f3a41189929ae21c613b6bc98 "modules/templates/util_date_test.go" "modules/templates/util_render_test.go" "templates/repo/latest_commit.tmpl"