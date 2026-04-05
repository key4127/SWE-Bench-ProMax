#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout aef2642581348e56b6031087288c40aae268cc8b "pkg/cmd/pr/shared/finder_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/pr/shared/finder_test.go b/pkg/cmd/pr/shared/finder_test.go
--- a/pkg/cmd/pr/shared/finder_test.go
+++ b/pkg/cmd/pr/shared/finder_test.go
@@ -18,20 +18,45 @@ type args struct {
 	baseRepoFn   func() (ghrepo.Interface, error)
 	branchFn     func() (string, error)
 	branchConfig func(string) (git.BranchConfig, error)
-	remotesFn    func() (context.Remotes, error)
+	pushDefault  func() (string, error)
+	selector     string
+	fields       []string
+	baseBranch   string
 }
 
 func TestFind(t *testing.T) {
-	type args struct {
-		baseRepoFn   func() (ghrepo.Interface, error)
-		branchFn     func() (string, error)
-		branchConfig func(string) (git.BranchConfig, error)
-		pushDefault  func() (string, error)
-		remotesFn    func() (context.Remotes, error)
-		selector     string
-		fields       []string
-		baseBranch   string
+	// TODO: Abstract these out meaningfully for reuse in parsePRRefs tests
+	originOwnerUrl, err := url.Parse("https://github.com/ORIGINOWNER/REPO.git")
+	if err != nil {
+		t.Fatal(err)
 	}
+	remoteOrigin := context.Remote{
+		Remote: &git.Remote{
+			Name:     "origin",
+			FetchURL: originOwnerUrl,
+		},
+		Repo: ghrepo.New("ORIGINOWNER", "REPO"),
+	}
+	remoteOther := context.Remote{
+		Remote: &git.Remote{
+			Name:     "other",
+			FetchURL: originOwnerUrl,
+		},
+		Repo: ghrepo.New("ORIGINOWNER", "OTHER-REPO"),
+	}
+
+	upstreamOwnerUrl, err := url.Parse("https://github.com/UPSTREAMOWNER/REPO.git")
+	if err != nil {
+		t.Fatal(err)
+	}
+	remoteUpstream := context.Remote{
+		Remote: &git.Remote{
+			Name:     "upstream",
+			FetchURL: upstreamOwnerUrl,
+		},
+		Repo: ghrepo.New("UPSTREAMOWNER", "REPO"),
+	}
+
 	tests := []struct {
 		name     string
 		args     args
@@ -43,11 +68,13 @@ func TestFind(t *testing.T) {
 		{
 			name: "number argument",
 			args: args{
-				selector: "13",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
+				selector:   "13",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -57,17 +84,22 @@ func TestFind(t *testing.T) {
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "number argument with base branch",
 			args: args{
 				selector:   "13",
 				baseBranch: "main",
 				fields:     []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{
+					PushRemoteName: remoteOrigin.Remote.Name,
+				}, nil),
+				pushDefault: stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -80,22 +112,25 @@ func TestFind(t *testing.T) {
 								"baseRefName": "main",
 								"headRefName": "13",
 								"isCrossRepository": false,
-								"headRepositoryOwner": {"login":"OWNER"}
+								"headRepositoryOwner": {"login":"ORIGINOWNER"}
 							}
 						]}
 					}}}`))
 			},
 			wantPR:   123,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "baseRepo is error",
 			args: args{
-				selector: "13",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return nil, errors.New("baseRepoErr")
+				selector:   "13",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(nil, errors.New("baseRepoErr")),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			wantErr: true,
 		},
@@ -110,24 +145,30 @@ func TestFind(t *testing.T) {
 		{
 			name: "number only",
 			args: args{
-				selector: "13",
-				fields:   []string{"number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
+				selector:   "13",
+				fields:     []string{"number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: nil,
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "number with hash argument",
 			args: args{
-				selector: "#13",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
+				selector:   "#13",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -137,14 +178,19 @@ func TestFind(t *testing.T) {
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
-			name: "URL argument",
+			name: "PR URL argument",
 			args: args{
 				selector:   "https://example.org/OWNER/REPO/pull/13/files",
 				fields:     []string{"id", "number"},
 				baseRepoFn: nil,
+				branchFn: func() (string, error) {
+					return "blueberries", nil
+				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -157,13 +203,16 @@ func TestFind(t *testing.T) {
 			wantRepo: "https://example.org/OWNER/REPO",
 		},
 		{
-			name: "branch argument",
+			name: "when provided branch argument with an open and closed PR for that branch name, it returns the open PR",
 			args: args{
-				selector: "blueberries",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
+				selector:   "blueberries",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
+				branchFn: func() (string, error) {
+					return "blueberries", nil
 				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -176,21 +225,21 @@ func TestFind(t *testing.T) {
 								"baseRefName": "main",
 								"headRefName": "blueberries",
 								"isCrossRepository": false,
-								"headRepositoryOwner": {"login":"OWNER"}
+								"headRepositoryOwner": {"login":"ORIGINOWNER"}
 							},
 							{
 								"number": 13,
 								"state": "OPEN",
 								"baseRefName": "main",
 								"headRefName": "blueberries",
 								"isCrossRepository": false,
-								"headRepositoryOwner": {"login":"OWNER"}
+								"headRepositoryOwner": {"login":"ORIGINOWNER"}
 							}
 						]}
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "branch argument with base branch",
@@ -201,6 +250,11 @@ func TestFind(t *testing.T) {
 				baseRepoFn: func() (ghrepo.Interface, error) {
 					return ghrepo.FromFullName("OWNER/REPO")
 				},
+				branchFn: func() (string, error) {
+					return "blueberries", nil
+				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -240,17 +294,8 @@ func TestFind(t *testing.T) {
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				branchConfig: stubBranchConfig(git.BranchConfig{
-					MergeRef:   "refs/heads/blueberries",
-					RemoteName: "origin",
-					Push:       "origin/blueberries",
-				}, nil),
-				remotesFn: func() (context.Remotes, error) {
-					return context.Remotes{{
-						Remote: &git.Remote{Name: "origin"},
-						Repo:   ghrepo.New("OWNER", "REPO"),
-					}}, nil
-				},
+				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -283,6 +328,7 @@ func TestFind(t *testing.T) {
 					return "blueberries", nil
 				},
 				branchConfig: stubBranchConfig(git.BranchConfig{}, nil),
+				pushDefault:  stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -320,70 +366,19 @@ func TestFind(t *testing.T) {
 			wantErr: true,
 		},
 		{
-			name: "current branch with upstream configuration",
+			name: "when the current branch is configured to push to and pull from 'upstream' and push.default = upstream but the repo push/pulls from 'origin', it finds the PR associated with the upstream repo and returns origin as the base repo",
 			args: args{
-				selector: "",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
-				},
+				selector:   "",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
-				pushDefault: func() (string, error) { return "upstream", nil },
 				branchConfig: stubBranchConfig(git.BranchConfig{
 					MergeRef:       "refs/heads/blue-upstream-berries",
-					RemoteName:     "origin",
-					PushRemoteName: "origin",
-					Push:           "origin/blue-upstream-berries",
+					PushRemoteName: "upstream",
 				}, nil),
-				remotesFn: func() (context.Remotes, error) {
-					return context.Remotes{{
-						Remote: &git.Remote{Name: "origin"},
-						Repo:   ghrepo.New("UPSTREAMOWNER", "REPO"),
-					}}, nil
-				},
-			},
-			httpStub: func(r *httpmock.Registry) {
-				r.Register(
-					httpmock.GraphQL(`query PullRequestForBranch\b`),
-					httpmock.StringResponse(`{"data":{"repository":{
-						"pullRequests":{"nodes":[
-							{
-								"number": 13,
-								"state": "OPEN",
-								"baseRefName": "main",
-								"headRefName": "blue-upstream-berries",
-								"isCrossRepository": true,
-								"headRepositoryOwner": {"login":"UPSTREAMOWNER"}
-							}
-						]}
-					}}}`))
-			},
-			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
-		},
-		{
-			name: "current branch with upstream RemoteURL configuration",
-			args: args{
-				selector: "",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
-				},
-				branchFn: func() (string, error) {
-					return "blueberries", nil
-				},
-				branchConfig: func(branch string) (git.BranchConfig, error) {
-					u, _ := url.Parse("https://github.com/UPSTREAMOWNER/REPO")
-					return stubBranchConfig(git.BranchConfig{
-						MergeRef:      "refs/heads/blue-upstream-berries",
-						RemoteURL:     u,
-						PushRemoteURL: u,
-					}, nil)(branch)
-				},
-				pushDefault: func() (string, error) { return "upstream", nil },
-				remotesFn:   nil,
+				pushDefault: stubPushDefault("upstream", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -402,32 +397,22 @@ func TestFind(t *testing.T) {
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
-			name: "current branch with tracking (deprecated synonym of upstream) configuration",
+			name: "the current branch is configured to push to and pull from a URL (upstream, in this example) that is different from what the repo is configured to push to and pull from (origin, in this example) and push.default = upstream, it finds the PR associated with the upstream repo and returns origin as the base repo",
 			args: args{
-				selector: "",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
-				},
+				selector:   "",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
 				branchConfig: stubBranchConfig(git.BranchConfig{
-					MergeRef:       "refs/heads/blue-upstream-berries",
-					RemoteName:     "origin",
-					PushRemoteName: "origin",
-					Push:           "origin/blue-upstream-berries",
+					MergeRef:      "refs/heads/blue-upstream-berries",
+					PushRemoteURL: remoteUpstream.Remote.FetchURL,
 				}, nil),
-				pushDefault: func() (string, error) { return "tracking", nil },
-				remotesFn: func() (context.Remotes, error) {
-					return context.Remotes{{
-						Remote: &git.Remote{Name: "origin"},
-						Repo:   ghrepo.New("UPSTREAMOWNER", "REPO"),
-					}}, nil
-				},
+				pushDefault: stubPushDefault("upstream", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -446,34 +431,21 @@ func TestFind(t *testing.T) {
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "current branch with upstream and fork in same org",
 			args: args{
-				selector: "",
-				fields:   []string{"id", "number"},
-				baseRepoFn: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("OWNER/REPO")
-				},
+				selector:   "",
+				fields:     []string{"id", "number"},
+				baseRepoFn: stubBaseRepoFn(remoteOrigin.Repo, nil),
 				branchFn: func() (string, error) {
 					return "blueberries", nil
 				},
 				branchConfig: stubBranchConfig(git.BranchConfig{
-					RemoteName:     "origin",
-					MergeRef:       "refs/heads/main",
-					PushRemoteName: "origin",
-					Push:           "origin/blueberries",
+					Push: "other/blueberries",
 				}, nil),
-				remotesFn: func() (context.Remotes, error) {
-					return context.Remotes{{
-						Remote: &git.Remote{Name: "origin"},
-						Repo:   ghrepo.New("OWNER", "REPO-FORK"),
-					}, {
-						Remote: &git.Remote{Name: "upstream"},
-						Repo:   ghrepo.New("OWNER", "REPO"),
-					}}, nil
-				},
+				pushDefault: stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -486,13 +458,13 @@ func TestFind(t *testing.T) {
 								"baseRefName": "main",
 								"headRefName": "blueberries",
 								"isCrossRepository": true,
-								"headRepositoryOwner": {"login":"OWNER"}
+								"headRepositoryOwner": {"login":"ORIGINOWNER"}
 							}
 						]}
 					}}}`))
 			},
 			wantPR:   13,
-			wantRepo: "https://github.com/OWNER/REPO",
+			wantRepo: "https://github.com/ORIGINOWNER/REPO",
 		},
 		{
 			name: "current branch made by pr checkout",
@@ -533,6 +505,7 @@ func TestFind(t *testing.T) {
 				branchConfig: stubBranchConfig(git.BranchConfig{
 					MergeRef: "refs/pull/13/head",
 				}, nil),
+				pushDefault: stubPushDefault("simple", nil),
 			},
 			httpStub: func(r *httpmock.Registry) {
 				r.Register(
@@ -597,7 +570,11 @@ func TestFind(t *testing.T) {
 				branchFn:     tt.args.branchFn,
 				branchConfig: tt.args.branchConfig,
 				pushDefault:  tt.args.pushDefault,
-				remotesFn:    tt.args.remotesFn,
+				remotesFn: stubRemotes(context.Remotes{
+					&remoteOrigin,
+					&remoteOther,
+					&remoteUpstream,
+				}, nil),
 			}
 
 			pr, repo, err := f.Find(FindOptions{
@@ -630,42 +607,262 @@ func TestFind(t *testing.T) {
 	}
 }
 
-func Test_parseCurrentBranch(t *testing.T) {
+func Test_parsePRRefs(t *testing.T) {
+	originOwnerUrl, err := url.Parse("https://github.com/ORIGINOWNER/REPO.git")
+	if err != nil {
+		t.Fatal(err)
+	}
+	remoteOrigin := context.Remote{
+		Remote: &git.Remote{
+			Name:     "origin",
+			FetchURL: originOwnerUrl,
+		},
+		Repo: ghrepo.New("ORIGINOWNER", "REPO"),
+	}
+	remoteOther := context.Remote{
+		Remote: &git.Remote{
+			Name:     "other",
+			FetchURL: originOwnerUrl,
+		},
+		Repo: ghrepo.New("ORIGINOWNER", "REPO"),
+	}
+
+	upstreamOwnerUrl, err := url.Parse("https://github.com/UPSTREAMOWNER/REPO.git")
+	if err != nil {
+		t.Fatal(err)
+	}
+	remoteUpstream := context.Remote{
+		Remote: &git.Remote{
+			Name:     "upstream",
+			FetchURL: upstreamOwnerUrl,
+		},
+		Repo: ghrepo.New("UPSTREAMOWNER", "REPO"),
+	}
+
 	tests := []struct {
-		name         string
-		args         args
-		wantSelector string
-		wantPR       int
-		wantError    error
+		name              string
+		branchConfig      git.BranchConfig
+		pushDefault       string
+		currentBranchName string
+		baseRefRepo       ghrepo.Interface
+		rems              context.Remotes
+		wantPRRefs        PRRefs
+		wantErr           error
 	}{
 		{
-			name: "failed branch config",
-			args: args{
-				branchConfig: stubBranchConfig(git.BranchConfig{}, errors.New("branchConfigErr")),
-				branchFn: func() (string, error) {
-					return "blueberries", nil
-				},
+			name:              "When the branch is called 'blueberries' with an empty branch config, it returns the correct PRRefs",
+			branchConfig:      git.BranchConfig{},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			wantPRRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name:              "When the branch is called 'otherBranch' with an empty branch config, it returns the correct PRRefs",
+			branchConfig:      git.BranchConfig{},
+			currentBranchName: "otherBranch",
+			baseRefRepo:       remoteOrigin.Repo,
+			wantPRRefs: PRRefs{
+				BranchName: "otherBranch",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the branch name doesn't match the branch name in BranchConfig.Push, it returns the BranchConfig.Push branch name",
+			branchConfig: git.BranchConfig{
+				Push: "origin/pushBranch",
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "pushBranch",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteOrigin.Repo,
 			},
-			wantSelector: "",
-			wantPR:       0,
-			wantError:    errors.New("branchConfigErr"),
+			wantErr: nil,
+		},
+		{
+			name: "When the branch name doesn't match a different branch name in BranchConfig.Push, it returns the BranchConfig.Push branch name",
+			branchConfig: git.BranchConfig{
+				Push: "origin/differentPushBranch",
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "differentPushBranch",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the branch name doesn't match a different branch name in BranchConfig.Push and the remote isn't 'origin', it returns the BranchConfig.Push branch name",
+			branchConfig: git.BranchConfig{
+				Push: "other/pushBranch",
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOther,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "pushBranch",
+				HeadRepo:   remoteOther.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the push remote is the same as the baseRepo, it returns the baseRepo as the PRRefs HeadRepo",
+			branchConfig: git.BranchConfig{
+				PushRemoteName: remoteOrigin.Remote.Name,
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+				&remoteUpstream,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the push remote is different from the baseRepo, it returns the push remote repo as the PRRefs HeadRepo",
+			branchConfig: git.BranchConfig{
+				PushRemoteName: remoteOrigin.Remote.Name,
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteUpstream.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+				&remoteUpstream,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteUpstream.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the push remote defined by a URL and the baseRepo is different from the push remote, it returns the push remote repo as the PRRefs HeadRepo",
+			branchConfig: git.BranchConfig{
+				PushRemoteURL: remoteOrigin.Remote.FetchURL,
+			},
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteUpstream.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+				&remoteUpstream,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   remoteOrigin.Repo,
+				BaseRepo:   remoteUpstream.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the push remote and merge ref are configured to a different repo and push.default = upstream, it should return the branch name from the other repo",
+			branchConfig: git.BranchConfig{
+				PushRemoteName: remoteUpstream.Remote.Name,
+				MergeRef:       "refs/heads/blue-upstream-berries",
+			},
+			pushDefault:       "upstream",
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+				&remoteUpstream,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "blue-upstream-berries",
+				HeadRepo:   remoteUpstream.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
+		},
+		{
+			name: "When the push remote and merge ref are configured to a different repo and push.default = tracking, it should return the branch name from the other repo",
+			branchConfig: git.BranchConfig{
+				PushRemoteName: remoteUpstream.Remote.Name,
+				MergeRef:       "refs/heads/blue-upstream-berries",
+			},
+			pushDefault:       "tracking",
+			currentBranchName: "blueberries",
+			baseRefRepo:       remoteOrigin.Repo,
+			rems: context.Remotes{
+				&remoteOrigin,
+				&remoteUpstream,
+			},
+			wantPRRefs: PRRefs{
+				BranchName: "blue-upstream-berries",
+				HeadRepo:   remoteUpstream.Repo,
+				BaseRepo:   remoteOrigin.Repo,
+			},
+			wantErr: nil,
 		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			f := finder{
-				httpClient: func() (*http.Client, error) {
-					return &http.Client{}, nil
-				},
-				baseRepoFn:   tt.args.baseRepoFn,
-				branchFn:     tt.args.branchFn,
-				branchConfig: tt.args.branchConfig,
-				remotesFn:    tt.args.remotesFn,
+			prRefs, err := parsePRRefs(tt.currentBranchName, tt.branchConfig, tt.pushDefault, tt.baseRefRepo, tt.rems)
+			if tt.wantErr != nil {
+				require.Error(t, err)
+				assert.Equal(t, tt.wantErr, err)
+			} else {
+				require.NoError(t, err)
 			}
-			selector, pr, err := f.parseCurrentBranch()
-			assert.Equal(t, tt.wantSelector, selector)
-			assert.Equal(t, tt.wantPR, pr)
-			assert.Equal(t, tt.wantError, err)
+			assert.Equal(t, tt.wantPRRefs, prRefs)
+		})
+	}
+}
+
+func TestPRRefs_GetPRLabel(t *testing.T) {
+	originRepo := ghrepo.New("ORIGINOWNER", "REPO")
+	upstreamRepo := ghrepo.New("UPSTREAMOWNER", "REPO")
+	tests := []struct {
+		name   string
+		prRefs PRRefs
+		want   string
+	}{
+		{
+			name: "When the HeadRepo and BaseRepo match, it returns the branch name",
+			prRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   originRepo,
+				BaseRepo:   originRepo,
+			},
+			want: "blueberries",
+		},
+		{
+			name: "When the HeadRepo and BaseRepo do not match, it returns the prepended HeadRepo owner to the branch name",
+			prRefs: PRRefs{
+				BranchName: "blueberries",
+				HeadRepo:   originRepo,
+				BaseRepo:   upstreamRepo,
+			},
+			want: "ORIGINOWNER:blueberries",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			assert.Equal(t, tt.want, tt.prRefs.GetPRLabel())
 		})
 	}
 }
@@ -675,3 +872,21 @@ func stubBranchConfig(branchConfig git.BranchConfig, err error) func(string) (gi
 		return branchConfig, err
 	}
 }
+
+func stubRemotes(remotes context.Remotes, err error) func() (context.Remotes, error) {
+	return func() (context.Remotes, error) {
+		return remotes, err
+	}
+}
+
+func stubBaseRepoFn(baseRepo ghrepo.Interface, err error) func() (ghrepo.Interface, error) {
+	return func() (ghrepo.Interface, error) {
+		return baseRepo, err
+	}
+}
+
+func stubPushDefault(pushDefault string, err error) func() (string, error) {
+	return func() (string, error) {
+		return pushDefault, err
+	}
+}
EOF_114329324912

# Run the specific test file
# Using the recommended command from context retrieval agent
# Running tests for the entire package to ensure all dependencies are properly resolved
go test -v ./pkg/cmd/pr/shared/
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout aef2642581348e56b6031087288c40aae268cc8b "pkg/cmd/pr/shared/finder_test.go"

exit $rc