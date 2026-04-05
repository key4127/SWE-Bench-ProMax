#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 4daf489c7515e1145be30727bb12b732c5c533e0 \
    "pkg/cmd/api/api_test.go" \
    "pkg/cmd/attestation/api/mock_httpClient_test.go" \
    "pkg/cmd/attestation/download/download.go" \
    "pkg/cmd/attestation/inspect/inspect.go" \
    "pkg/cmd/attestation/trustedroot/trustedroot.go" \
    "pkg/cmd/attestation/verification/extensions.go" \
    "pkg/cmd/attestation/verification/policy.go" \
    "pkg/cmd/attestation/verification/sigstore.go" \
    "pkg/cmd/attestation/verification/sigstore_integration_test.go" \
    "pkg/cmd/attestation/verification/tuf.go" \
    "pkg/cmd/attestation/verification/tuf_test.go" \
    "pkg/cmd/attestation/verify/attestation_integration_test.go" \
    "pkg/cmd/attestation/verify/options.go" \
    "pkg/cmd/attestation/verify/policy.go" \
    "pkg/cmd/attestation/verify/policy_test.go" \
    "pkg/cmd/attestation/verify/verify.go" \
    "pkg/cmd/attestation/verify/verify_integration_test.go" \
    "pkg/cmd/cache/delete/delete_test.go" \
    "pkg/cmd/factory/remote_resolver_test.go" \
    "pkg/cmd/gist/list/list_test.go" \
    "pkg/cmd/issue/comment/comment_test.go" \
    "pkg/cmd/label/list_test.go" \
    "pkg/cmd/pr/checkout/checkout_test.go" \
    "pkg/cmd/pr/close/close_test.go" \
    "pkg/cmd/pr/comment/comment_test.go" \
    "pkg/cmd/pr/create/create_test.go" \
    "pkg/cmd/project/item-edit/item_edit_test.go" \
    "pkg/cmd/release/create/create_test.go" \
    "pkg/cmd/release/view/view_test.go" \
    "pkg/cmd/repo/license/view/view_test.go" \
    "pkg/cmd/repo/rename/rename_test.go" \
    "pkg/cmd/repo/setdefault/setdefault_test.go" \
    "pkg/cmd/ruleset/view/view_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/api/api_test.go b/pkg/cmd/api/api_test.go
--- a/pkg/cmd/api/api_test.go
+++ b/pkg/cmd/api/api_test.go
@@ -367,6 +367,72 @@ func Test_NewCmdApi(t *testing.T) {
 			},
 			wantsErr: false,
 		},
+		{
+			name: "request path with container package name containing slashes",
+			cli:  "/user/packages/container/github.com/username/package_name --verbose",
+			wants: ApiOptions{
+				Hostname:            "",
+				RequestMethod:       "GET",
+				RequestMethodPassed: false,
+				RequestPath:         "/user/packages/container/github.com%2Fusername%2Fpackage_name",
+				RequestInputFile:    "",
+				RawFields:           []string(nil),
+				MagicFields:         []string(nil),
+				RequestHeaders:      []string(nil),
+				ShowResponseHeaders: false,
+				Paginate:            false,
+				Silent:              false,
+				CacheTTL:            0,
+				Template:            "",
+				FilterOutput:        "",
+				Verbose:             true,
+			},
+			wantsErr: false,
+		},
+		{
+			name: "request path with container package name containing slashes and restore",
+			cli:  "/user/packages/container/github.com/username/package_name/restore --verbose",
+			wants: ApiOptions{
+				Hostname:            "",
+				RequestMethod:       "GET",
+				RequestMethodPassed: false,
+				RequestPath:         "/user/packages/container/github.com%2Fusername%2Fpackage_name/restore",
+				RequestInputFile:    "",
+				RawFields:           []string(nil),
+				MagicFields:         []string(nil),
+				RequestHeaders:      []string(nil),
+				ShowResponseHeaders: false,
+				Paginate:            false,
+				Silent:              false,
+				CacheTTL:            0,
+				Template:            "",
+				FilterOutput:        "",
+				Verbose:             true,
+			},
+			wantsErr: false,
+		},
+		{
+			name: "request path with container package name containing slashes and versions",
+			cli:  "/user/packages/container/github.com/username/package_name/versions --verbose",
+			wants: ApiOptions{
+				Hostname:            "",
+				RequestMethod:       "GET",
+				RequestMethodPassed: false,
+				RequestPath:         "/user/packages/container/github.com%2Fusername%2Fpackage_name/versions",
+				RequestInputFile:    "",
+				RawFields:           []string(nil),
+				MagicFields:         []string(nil),
+				RequestHeaders:      []string(nil),
+				ShowResponseHeaders: false,
+				Paginate:            false,
+				Silent:              false,
+				CacheTTL:            0,
+				Template:            "",
+				FilterOutput:        "",
+				Verbose:             true,
+			},
+			wantsErr: false,
+		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
diff --git a/pkg/cmd/attestation/api/mock_httpClient_test.go b/pkg/cmd/attestation/api/mock_httpClient_test.go
--- a/pkg/cmd/attestation/api/mock_httpClient_test.go
+++ b/pkg/cmd/attestation/api/mock_httpClient_test.go
@@ -5,6 +5,7 @@ import (
 	"fmt"
 	"io"
 	"net/http"
+	"sync"
 
 	"github.com/cli/cli/v2/pkg/cmd/attestation/test/data"
 	"github.com/golang/snappy"
@@ -58,12 +59,16 @@ func (m *reqFailHttpClient) Get(url string) (*http.Response, error) {
 
 type failAfterNCallsHttpClient struct {
 	mock.Mock
+	mu                       sync.Mutex
 	FailOnCallN              int
 	FailOnAllSubsequentCalls bool
 	NumCalls                 int
 }
 
 func (m *failAfterNCallsHttpClient) Get(url string) (*http.Response, error) {
+	m.mu.Lock()
+	defer m.mu.Unlock()
+
 	m.On("OnGetFailAfterNCalls").Return()
 
 	m.NumCalls++
diff --git a/pkg/cmd/attestation/download/download.go b/pkg/cmd/attestation/download/download.go
--- a/pkg/cmd/attestation/download/download.go
+++ b/pkg/cmd/attestation/download/download.go
@@ -107,7 +107,7 @@ func NewDownloadCmd(f *cmdutil.Factory, runF func(*Options) error) *cobra.Comman
 		},
 	}
 
-	downloadCmd.Flags().StringVarP(&opts.Owner, "owner", "o", "", "a GitHub organization to scope attestation lookup by")
+	downloadCmd.Flags().StringVarP(&opts.Owner, "owner", "o", "", "GitHub organization to scope attestation lookup by")
 	downloadCmd.Flags().StringVarP(&opts.Repo, "repo", "R", "", "Repository name in the format <owner>/<repo>")
 	downloadCmd.MarkFlagsMutuallyExclusive("owner", "repo")
 	downloadCmd.MarkFlagsOneRequired("owner", "repo")
diff --git a/pkg/cmd/attestation/inspect/inspect.go b/pkg/cmd/attestation/inspect/inspect.go
--- a/pkg/cmd/attestation/inspect/inspect.go
+++ b/pkg/cmd/attestation/inspect/inspect.go
@@ -47,7 +47,7 @@ func NewInspectCmd(f *cmdutil.Factory, runF func(*Options) error) *cobra.Command
 			timestamps, and if the included signatures match the provided public key.
 
 			This command cannot be used to verify a bundle. To verify a bundle, see the
-		 %[1]sgh at verify%[1]s command.
+			%[1]sgh at verify%[1]s command.
 
 			By default, this command prints a condensed table. To see full results, provide the
 			%[1]s--format=json%[1]s flag.
diff --git a/pkg/cmd/attestation/trustedroot/trustedroot.go b/pkg/cmd/attestation/trustedroot/trustedroot.go
--- a/pkg/cmd/attestation/trustedroot/trustedroot.go
+++ b/pkg/cmd/attestation/trustedroot/trustedroot.go
@@ -11,6 +11,7 @@ import (
 	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
 	"github.com/cli/cli/v2/pkg/cmdutil"
+	o "github.com/cli/cli/v2/pkg/option"
 	ghauth "github.com/cli/go-gh/v2/pkg/auth"
 
 	"github.com/MakeNowJust/heredoc"
@@ -56,7 +57,7 @@ func NewTrustedRootCmd(f *cmdutil.Factory, runF func(*Options) error) *cobra.Com
 		`, "`"),
 		Example: heredoc.Doc(`
 			# Get a trusted_root.jsonl for both Sigstore Public Good and GitHub's instance
-			gh attestation trusted-root
+			$ gh attestation trusted-root
 		`),
 		RunE: func(cmd *cobra.Command, args []string) error {
 			if opts.Hostname == "" {
@@ -121,7 +122,7 @@ func getTrustedRoot(makeTUF tufClientInstantiator, opts *Options) error {
 	var tufOptions []tufConfig
 	var defaultTR = "trusted_root.json"
 
-	tufOpt := verification.DefaultOptionsWithCacheSetting()
+	tufOpt := verification.DefaultOptionsWithCacheSetting(o.None[string]())
 	// Disable local caching, so we get up-to-date response from TUF repository
 	tufOpt.CacheValidity = 0
 
@@ -150,7 +151,7 @@ func getTrustedRoot(makeTUF tufClientInstantiator, opts *Options) error {
 			targets:    []string{defaultTR},
 		})
 
-		tufOpt = verification.GitHubTUFOptions()
+		tufOpt = verification.GitHubTUFOptions(o.None[string]())
 		tufOpt.CacheValidity = 0
 		tufOptions = append(tufOptions, tufConfig{
 			tufOptions: tufOpt,
diff --git a/pkg/cmd/attestation/verification/extensions.go b/pkg/cmd/attestation/verification/extensions.go
--- a/pkg/cmd/attestation/verification/extensions.go
+++ b/pkg/cmd/attestation/verification/extensions.go
@@ -59,5 +59,15 @@ func verifyCertExtensions(given, expected certificate.Summary) error {
 		return fmt.Errorf("expected Issuer to be %s, got %s", expected.Issuer, given.Issuer)
 	}
 
+	if expected.BuildSignerDigest != "" && !strings.EqualFold(expected.BuildSignerDigest, given.BuildSignerDigest) {
+		return fmt.Errorf("expected BuildSignerDigest to be %s, got %s", expected.BuildSignerDigest, given.BuildSignerDigest)
+	}
+	if expected.SourceRepositoryDigest != "" && !strings.EqualFold(expected.SourceRepositoryDigest, given.SourceRepositoryDigest) {
+		return fmt.Errorf("expected SourceRepositoryDigest to be %s, got %s", expected.SourceRepositoryDigest, given.SourceRepositoryDigest)
+	}
+	if expected.SourceRepositoryRef != "" && !strings.EqualFold(expected.SourceRepositoryRef, given.SourceRepositoryRef) {
+		return fmt.Errorf("expected SourceRepositoryRef to be %s, got %s", expected.SourceRepositoryRef, given.SourceRepositoryRef)
+	}
+
 	return nil
 }
diff --git a/pkg/cmd/attestation/verification/policy.go b/pkg/cmd/attestation/verification/policy.go
--- a/pkg/cmd/attestation/verification/policy.go
+++ b/pkg/cmd/attestation/verification/policy.go
@@ -52,7 +52,7 @@ func (c EnforcementCriteria) Valid() error {
 }
 
 func (c EnforcementCriteria) BuildPolicyInformation() string {
-	policyAttr := make([][]string, 0, 6)
+	policyAttr := [][]string{}
 
 	policyAttr = appendStr(policyAttr, "- Predicate type must match", c.PredicateType)
 
@@ -62,6 +62,16 @@ func (c EnforcementCriteria) BuildPolicyInformation() string {
 		policyAttr = appendStr(policyAttr, "- Source Repository URI must match", c.Certificate.SourceRepositoryURI)
 	}
 
+	if c.Certificate.BuildSignerDigest != "" {
+		policyAttr = appendStr(policyAttr, "- Build signer digest must match", c.Certificate.BuildSignerDigest)
+	}
+	if c.Certificate.SourceRepositoryDigest != "" {
+		policyAttr = appendStr(policyAttr, "- Source repo digest digest must match", c.Certificate.SourceRepositoryDigest)
+	}
+	if c.Certificate.SourceRepositoryRef != "" {
+		policyAttr = appendStr(policyAttr, "- Source repo ref must match", c.Certificate.SourceRepositoryRef)
+	}
+
 	if c.SAN != "" {
 		policyAttr = appendStr(policyAttr, "- Subject Alternative Name must match", c.SAN)
 	} else if c.SANRegex != "" {
diff --git a/pkg/cmd/attestation/verification/sigstore.go b/pkg/cmd/attestation/verification/sigstore.go
--- a/pkg/cmd/attestation/verification/sigstore.go
+++ b/pkg/cmd/attestation/verification/sigstore.go
@@ -10,6 +10,7 @@ import (
 
 	"github.com/cli/cli/v2/pkg/cmd/attestation/api"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
+	o "github.com/cli/cli/v2/pkg/option"
 
 	"github.com/sigstore/sigstore-go/pkg/bundle"
 	"github.com/sigstore/sigstore-go/pkg/root"
@@ -34,6 +35,8 @@ type SigstoreConfig struct {
 	NoPublicGood bool
 	// If tenancy mode is not used, trust domain is empty
 	TrustDomain string
+	// TUFMetadataDir
+	TUFMetadataDir o.Option[string]
 }
 
 type SigstoreVerifier interface {
@@ -45,7 +48,8 @@ type LiveSigstoreVerifier struct {
 	Logger       *io.Handler
 	NoPublicGood bool
 	// If tenancy mode is not used, trust domain is empty
-	TrustDomain string
+	TrustDomain    string
+	TUFMetadataDir o.Option[string]
 }
 
 var ErrNoAttestationsVerified = errors.New("no attestations were verified")
@@ -55,10 +59,11 @@ var ErrNoAttestationsVerified = errors.New("no attestations were verified")
 // Public Good, GitHub, or a custom trusted root.
 func NewLiveSigstoreVerifier(config SigstoreConfig) *LiveSigstoreVerifier {
 	return &LiveSigstoreVerifier{
-		TrustedRoot:  config.TrustedRoot,
-		Logger:       config.Logger,
-		NoPublicGood: config.NoPublicGood,
-		TrustDomain:  config.TrustDomain,
+		TrustedRoot:    config.TrustedRoot,
+		Logger:         config.Logger,
+		NoPublicGood:   config.NoPublicGood,
+		TrustDomain:    config.TrustDomain,
+		TUFMetadataDir: config.TUFMetadataDir,
 	}
 }
 
@@ -89,9 +94,9 @@ func (v *LiveSigstoreVerifier) chooseVerifier(issuer string) (*verify.SignedEnti
 			if v.NoPublicGood {
 				return nil, fmt.Errorf("detected public good instance but requested verification without public good instance")
 			}
-			return newPublicGoodVerifier()
+			return newPublicGoodVerifier(v.TUFMetadataDir)
 		case GitHubIssuerOrg:
-			return newGitHubVerifier(v.TrustDomain)
+			return newGitHubVerifier(v.TrustDomain, v.TUFMetadataDir)
 		default:
 			return nil, fmt.Errorf("leaf certificate issuer is not recognized")
 		}
@@ -255,10 +260,10 @@ func newCustomVerifier(trustedRoot *root.TrustedRoot) (*verify.SignedEntityVerif
 	return gv, nil
 }
 
-func newGitHubVerifier(trustDomain string) (*verify.SignedEntityVerifier, error) {
+func newGitHubVerifier(trustDomain string, tufMetadataDir o.Option[string]) (*verify.SignedEntityVerifier, error) {
 	var tr string
 
-	opts := GitHubTUFOptions()
+	opts := GitHubTUFOptions(tufMetadataDir)
 	client, err := tuf.New(opts)
 	if err != nil {
 		return nil, fmt.Errorf("failed to create TUF client: %v", err)
@@ -289,8 +294,8 @@ func newGitHubVerifierWithTrustedRoot(trustedRoot *root.TrustedRoot) (*verify.Si
 	return gv, nil
 }
 
-func newPublicGoodVerifier() (*verify.SignedEntityVerifier, error) {
-	opts := DefaultOptionsWithCacheSetting()
+func newPublicGoodVerifier(tufMetadataDir o.Option[string]) (*verify.SignedEntityVerifier, error) {
+	opts := DefaultOptionsWithCacheSetting(tufMetadataDir)
 	client, err := tuf.New(opts)
 	if err != nil {
 		return nil, fmt.Errorf("failed to create TUF client: %v", err)
diff --git a/pkg/cmd/attestation/verification/sigstore_integration_test.go b/pkg/cmd/attestation/verification/sigstore_integration_test.go
--- a/pkg/cmd/attestation/verification/sigstore_integration_test.go
+++ b/pkg/cmd/attestation/verification/sigstore_integration_test.go
@@ -9,6 +9,7 @@ import (
 	"github.com/cli/cli/v2/pkg/cmd/attestation/artifact"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/test"
+	o "github.com/cli/cli/v2/pkg/option"
 
 	"github.com/sigstore/sigstore-go/pkg/verify"
 	"github.com/stretchr/testify/require"
@@ -48,25 +49,29 @@ func TestLiveSigstoreVerifier(t *testing.T) {
 	}
 
 	for _, tc := range testcases {
-		verifier := NewLiveSigstoreVerifier(SigstoreConfig{
-			Logger: io.NewTestHandler(),
+		t.Run(tc.name, func(t *testing.T) {
+			verifier := NewLiveSigstoreVerifier(SigstoreConfig{
+				Logger:         io.NewTestHandler(),
+				TUFMetadataDir: o.Some(t.TempDir()),
+			})
+
+			results, err := verifier.Verify(tc.attestations, publicGoodPolicy(t))
+
+			if tc.expectErr {
+				require.Error(t, err)
+				require.ErrorContains(t, err, tc.errContains)
+				require.Nil(t, results)
+			} else {
+				require.NoError(t, err)
+				require.Equal(t, len(tc.attestations), len(results))
+			}
 		})
-
-		results, err := verifier.Verify(tc.attestations, publicGoodPolicy(t))
-
-		if tc.expectErr {
-			require.Error(t, err, "test case: %s", tc.name)
-			require.ErrorContains(t, err, tc.errContains, "test case: %s", tc.name)
-			require.Nil(t, results, "test case: %s", tc.name)
-		} else {
-			require.Equal(t, len(tc.attestations), len(results), "test case: %s", tc.name)
-			require.NoError(t, err, "test case: %s", tc.name)
-		}
 	}
 
 	t.Run("with 2/3 verified attestations", func(t *testing.T) {
 		verifier := NewLiveSigstoreVerifier(SigstoreConfig{
-			Logger: io.NewTestHandler(),
+			Logger:         io.NewTestHandler(),
+			TUFMetadataDir: o.Some(t.TempDir()),
 		})
 
 		invalidBundle := getAttestationsFor(t, "../test/data/sigstore-js-2.1.0-bundle-v0.1.json")
@@ -82,7 +87,8 @@ func TestLiveSigstoreVerifier(t *testing.T) {
 
 	t.Run("fail with 0/2 verified attestations", func(t *testing.T) {
 		verifier := NewLiveSigstoreVerifier(SigstoreConfig{
-			Logger: io.NewTestHandler(),
+			Logger:         io.NewTestHandler(),
+			TUFMetadataDir: o.Some(t.TempDir()),
 		})
 
 		invalidBundle := getAttestationsFor(t, "../test/data/sigstore-js-2.1.0-bundle-v0.1.json")
@@ -105,7 +111,8 @@ func TestLiveSigstoreVerifier(t *testing.T) {
 		attestations := getAttestationsFor(t, "../test/data/github_provenance_demo-0.0.12-py3-none-any-bundle.jsonl")
 
 		verifier := NewLiveSigstoreVerifier(SigstoreConfig{
-			Logger: io.NewTestHandler(),
+			Logger:         io.NewTestHandler(),
+			TUFMetadataDir: o.Some(t.TempDir()),
 		})
 
 		results, err := verifier.Verify(attestations, githubPolicy)
@@ -117,8 +124,9 @@ func TestLiveSigstoreVerifier(t *testing.T) {
 		attestations := getAttestationsFor(t, "../test/data/sigstore-js-2.1.0_with_2_bundles.jsonl")
 
 		verifier := NewLiveSigstoreVerifier(SigstoreConfig{
-			Logger:      io.NewTestHandler(),
-			TrustedRoot: test.NormalizeRelativePath("../test/data/trusted_root.json"),
+			Logger:         io.NewTestHandler(),
+			TrustedRoot:    test.NormalizeRelativePath("../test/data/trusted_root.json"),
+			TUFMetadataDir: o.Some(t.TempDir()),
 		})
 
 		results, err := verifier.Verify(attestations, publicGoodPolicy(t))
diff --git a/pkg/cmd/attestation/verification/tuf.go b/pkg/cmd/attestation/verification/tuf.go
--- a/pkg/cmd/attestation/verification/tuf.go
+++ b/pkg/cmd/attestation/verification/tuf.go
@@ -5,6 +5,7 @@ import (
 	"os"
 	"path/filepath"
 
+	o "github.com/cli/cli/v2/pkg/option"
 	"github.com/cli/go-gh/v2/pkg/config"
 	"github.com/sigstore/sigstore-go/pkg/tuf"
 )
@@ -14,7 +15,7 @@ var githubRoot []byte
 
 const GitHubTUFMirror = "https://tuf-repo.github.com"
 
-func DefaultOptionsWithCacheSetting() *tuf.Options {
+func DefaultOptionsWithCacheSetting(tufMetadataDir o.Option[string]) *tuf.Options {
 	opts := tuf.DefaultOptions()
 
 	// The CODESPACES environment variable will be set to true in a Codespaces workspace
@@ -25,17 +26,17 @@ func DefaultOptionsWithCacheSetting() *tuf.Options {
 		opts.DisableLocalCache = true
 	}
 
-	// Set the cache path to a directory owned by the CLI
-	opts.CachePath = filepath.Join(config.CacheDir(), ".sigstore", "root")
+	// Set the cache path to the provided dir, or a directory owned by the CLI
+	opts.CachePath = tufMetadataDir.UnwrapOr(filepath.Join(config.CacheDir(), ".sigstore", "root"))
 
 	// Allow TUF cache for 1 day
 	opts.CacheValidity = 1
 
 	return opts
 }
 
-func GitHubTUFOptions() *tuf.Options {
-	opts := DefaultOptionsWithCacheSetting()
+func GitHubTUFOptions(tufMetadataDir o.Option[string]) *tuf.Options {
+	opts := DefaultOptionsWithCacheSetting(tufMetadataDir)
 
 	opts.Root = githubRoot
 	opts.RepositoryBaseURL = GitHubTUFMirror
diff --git a/pkg/cmd/attestation/verification/tuf_test.go b/pkg/cmd/attestation/verification/tuf_test.go
--- a/pkg/cmd/attestation/verification/tuf_test.go
+++ b/pkg/cmd/attestation/verification/tuf_test.go
@@ -5,16 +5,22 @@ import (
 	"path/filepath"
 	"testing"
 
+	o "github.com/cli/cli/v2/pkg/option"
 	"github.com/cli/go-gh/v2/pkg/config"
 	"github.com/stretchr/testify/require"
 )
 
-func TestGitHubTUFOptions(t *testing.T) {
+func TestGitHubTUFOptionsNoMetadataDir(t *testing.T) {
 	os.Setenv("CODESPACES", "true")
-	opts := GitHubTUFOptions()
+	opts := GitHubTUFOptions(o.None[string]())
 
 	require.Equal(t, GitHubTUFMirror, opts.RepositoryBaseURL)
 	require.NotNil(t, opts.Root)
 	require.True(t, opts.DisableLocalCache)
 	require.Equal(t, filepath.Join(config.CacheDir(), ".sigstore", "root"), opts.CachePath)
 }
+
+func TestGitHubTUFOptionsWithMetadataDir(t *testing.T) {
+	opts := GitHubTUFOptions(o.Some("anything"))
+	require.Equal(t, "anything", opts.CachePath)
+}
diff --git a/pkg/cmd/attestation/verify/attestation_integration_test.go b/pkg/cmd/attestation/verify/attestation_integration_test.go
--- a/pkg/cmd/attestation/verify/attestation_integration_test.go
+++ b/pkg/cmd/attestation/verify/attestation_integration_test.go
@@ -10,6 +10,7 @@ import (
 	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/test"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
+	o "github.com/cli/cli/v2/pkg/option"
 	"github.com/sigstore/sigstore-go/pkg/fulcio/certificate"
 	"github.com/stretchr/testify/require"
 )
@@ -25,7 +26,8 @@ func getAttestationsFor(t *testing.T, bundlePath string) []*api.Attestation {
 
 func TestVerifyAttestations(t *testing.T) {
 	sgVerifier := verification.NewLiveSigstoreVerifier(verification.SigstoreConfig{
-		Logger: io.NewTestHandler(),
+		Logger:         io.NewTestHandler(),
+		TUFMetadataDir: o.Some(t.TempDir()),
 	})
 
 	certSummary := certificate.Summary{}
diff --git a/pkg/cmd/attestation/verify/options.go b/pkg/cmd/attestation/verify/options.go
--- a/pkg/cmd/attestation/verify/options.go
+++ b/pkg/cmd/attestation/verify/options.go
@@ -31,8 +31,11 @@ type Options struct {
 	Repo                  string
 	SAN                   string
 	SANRegex              string
+	SignerDigest          string
 	SignerRepo            string
 	SignerWorkflow        string
+	SourceDigest          string
+	SourceRef             string
 	APIClient             api.Client
 	Logger                *io.Handler
 	OCIClient             oci.Client
diff --git a/pkg/cmd/attestation/verify/policy.go b/pkg/cmd/attestation/verify/policy.go
--- a/pkg/cmd/attestation/verify/policy.go
+++ b/pkg/cmd/attestation/verify/policy.go
@@ -66,7 +66,7 @@ func newEnforcementCriteria(opts *Options) (verification.EnforcementCriteria, er
 		// then we default to the repo option
 		c.SANRegex = expandToGitHubURLRegex(opts.Tenant, opts.Repo)
 	} else {
-		// if opts.Repo was not provided, we fallback to the opts.Owner value
+		// if opts.Repo was not provided, we fall back to the opts.Owner value
 		c.SANRegex = expandToGitHubURLRegex(opts.Tenant, owner)
 	}
 
@@ -98,6 +98,12 @@ func newEnforcementCriteria(opts *Options) (verification.EnforcementCriteria, er
 		c.Certificate.Issuer = opts.OIDCIssuer
 	}
 
+	// set the SourceRepositoryDigest, SourceRepositoryRef, and BuildSignerDigest
+	// extensions if the options are provided
+	c.Certificate.BuildSignerDigest = opts.SignerDigest
+	c.Certificate.SourceRepositoryDigest = opts.SourceDigest
+	c.Certificate.SourceRepositoryRef = opts.SourceRef
+
 	return c, nil
 }
 
diff --git a/pkg/cmd/attestation/verify/policy_test.go b/pkg/cmd/attestation/verify/policy_test.go
--- a/pkg/cmd/attestation/verify/policy_test.go
+++ b/pkg/cmd/attestation/verify/policy_test.go
@@ -216,6 +216,48 @@ func TestNewEnforcementCriteria(t *testing.T) {
 		require.NoError(t, err)
 		require.Equal(t, "https://foo.com", c.Certificate.Issuer)
 	})
+
+	t.Run("sets Certificate.BuildSignerDigest using opts.SignerDigest", func(t *testing.T) {
+		opts := &Options{
+			ArtifactPath: artifactPath,
+			Owner:        "wrong",
+			Repo:         "wrong/value",
+			SignerDigest: "foo",
+			Hostname:     "github.com",
+		}
+
+		c, err := newEnforcementCriteria(opts)
+		require.NoError(t, err)
+		require.Equal(t, "foo", c.Certificate.BuildSignerDigest)
+	})
+
+	t.Run("sets Certificate.SourceRepositoryDigest using opts.SourceDigest", func(t *testing.T) {
+		opts := &Options{
+			ArtifactPath: artifactPath,
+			Owner:        "wrong",
+			Repo:         "wrong/value",
+			SourceDigest: "foo",
+			Hostname:     "github.com",
+		}
+
+		c, err := newEnforcementCriteria(opts)
+		require.NoError(t, err)
+		require.Equal(t, "foo", c.Certificate.SourceRepositoryDigest)
+	})
+
+	t.Run("sets Certificate.SourceRepositoryRef using opts.SourceRef", func(t *testing.T) {
+		opts := &Options{
+			ArtifactPath: artifactPath,
+			Owner:        "wrong",
+			Repo:         "wrong/value",
+			SourceRef:    "refs/heads/main",
+			Hostname:     "github.com",
+		}
+
+		c, err := newEnforcementCriteria(opts)
+		require.NoError(t, err)
+		require.Equal(t, "refs/heads/main", c.Certificate.SourceRepositoryRef)
+	})
 }
 
 func TestValidateSignerWorkflow(t *testing.T) {
diff --git a/pkg/cmd/attestation/verify/verify.go b/pkg/cmd/attestation/verify/verify.go
--- a/pkg/cmd/attestation/verify/verify.go
+++ b/pkg/cmd/attestation/verify/verify.go
@@ -195,6 +195,9 @@ func NewVerifyCmd(f *cmdutil.Factory, runF func(*Options) error) *cobra.Command
 	verifyCmd.MarkFlagsMutuallyExclusive("cert-identity", "cert-identity-regex", "signer-repo", "signer-workflow")
 	verifyCmd.Flags().StringVarP(&opts.OIDCIssuer, "cert-oidc-issuer", "", verification.GitHubOIDCIssuer, "Issuer of the OIDC token")
 	verifyCmd.Flags().StringVarP(&opts.Hostname, "hostname", "", "", "Configure host to use")
+	verifyCmd.Flags().StringVarP(&opts.SignerDigest, "signer-digest", "", "", "Digest associated with the signer workflow")
+	verifyCmd.Flags().StringVarP(&opts.SourceRef, "source-ref", "", "", "Ref associated with the source workflow")
+	verifyCmd.Flags().StringVarP(&opts.SourceDigest, "source-digest", "", "", "Digest associated with the source workflow")
 
 	return verifyCmd
 }
diff --git a/pkg/cmd/attestation/verify/verify_integration_test.go b/pkg/cmd/attestation/verify/verify_integration_test.go
--- a/pkg/cmd/attestation/verify/verify_integration_test.go
+++ b/pkg/cmd/attestation/verify/verify_integration_test.go
@@ -11,6 +11,7 @@ import (
 	"github.com/cli/cli/v2/pkg/cmd/attestation/test"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
 	"github.com/cli/cli/v2/pkg/cmd/factory"
+	o "github.com/cli/cli/v2/pkg/option"
 	"github.com/cli/go-gh/v2/pkg/auth"
 	"github.com/stretchr/testify/require"
 )
@@ -19,7 +20,8 @@ func TestVerifyIntegration(t *testing.T) {
 	logger := io.NewTestHandler()
 
 	sigstoreConfig := verification.SigstoreConfig{
-		Logger: logger,
+		Logger:         logger,
+		TUFMetadataDir: o.Some(t.TempDir()),
 	}
 
 	cmdFactory := factory.New("test")
@@ -130,7 +132,8 @@ func TestVerifyIntegrationCustomIssuer(t *testing.T) {
 	logger := io.NewTestHandler()
 
 	sigstoreConfig := verification.SigstoreConfig{
-		Logger: logger,
+		Logger:         logger,
+		TUFMetadataDir: o.Some(t.TempDir()),
 	}
 
 	cmdFactory := factory.New("test")
@@ -200,7 +203,8 @@ func TestVerifyIntegrationReusableWorkflow(t *testing.T) {
 	logger := io.NewTestHandler()
 
 	sigstoreConfig := verification.SigstoreConfig{
-		Logger: logger,
+		Logger:         logger,
+		TUFMetadataDir: o.Some(t.TempDir()),
 	}
 
 	cmdFactory := factory.New("test")
@@ -289,7 +293,8 @@ func TestVerifyIntegrationReusableWorkflowSignerWorkflow(t *testing.T) {
 	logger := io.NewTestHandler()
 
 	sigstoreConfig := verification.SigstoreConfig{
-		Logger: logger,
+		Logger:         logger,
+		TUFMetadataDir: o.Some(t.TempDir()),
 	}
 
 	cmdFactory := factory.New("test")
diff --git a/pkg/cmd/cache/delete/delete_test.go b/pkg/cmd/cache/delete/delete_test.go
--- a/pkg/cmd/cache/delete/delete_test.go
+++ b/pkg/cmd/cache/delete/delete_test.go
@@ -43,6 +43,21 @@ func TestNewCmdDelete(t *testing.T) {
 			cli:   "--all",
 			wants: DeleteOptions{DeleteAll: true},
 		},
+		{
+			name:  "delete all and succeed-on-no-caches flags",
+			cli:   "--all --succeed-on-no-caches",
+			wants: DeleteOptions{DeleteAll: true, SucceedOnNoCaches: true},
+		},
+		{
+			name:     "succeed-on-no-caches flag",
+			cli:      "--succeed-on-no-caches",
+			wantsErr: "--succeed-on-no-caches must be used in conjunction with --all",
+		},
+		{
+			name:     "succeed-on-no-caches flag and id argument",
+			cli:      "--succeed-on-no-caches 123",
+			wantsErr: "--succeed-on-no-caches must be used in conjunction with --all",
+		},
 		{
 			name:     "id argument and delete all flag",
 			cli:      "1 --all",
@@ -72,6 +87,7 @@ func TestNewCmdDelete(t *testing.T) {
 			}
 			assert.NoError(t, err)
 			assert.Equal(t, tt.wants.DeleteAll, gotOpts.DeleteAll)
+			assert.Equal(t, tt.wants.SucceedOnNoCaches, gotOpts.SucceedOnNoCaches)
 			assert.Equal(t, tt.wants.Identifier, gotOpts.Identifier)
 		})
 	}
@@ -160,6 +176,19 @@ func TestDeleteRun(t *testing.T) {
 			tty:        true,
 			wantStdout: "✓ Deleted 2 caches from OWNER/REPO\n",
 		},
+		{
+			name: "attempts to delete all caches but api errors",
+			opts: DeleteOptions{DeleteAll: true},
+			stubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/caches"),
+					httpmock.StatusStringResponse(500, ""),
+				)
+			},
+			tty:        true,
+			wantErr:    true,
+			wantErrMsg: "HTTP 500 (https://api.github.com/repos/OWNER/REPO/actions/caches?per_page=100)",
+		},
 		{
 			name: "displays delete error",
 			opts: DeleteOptions{Identifier: "123"},
@@ -186,6 +215,54 @@ func TestDeleteRun(t *testing.T) {
 			tty:        true,
 			wantStdout: "✓ Deleted 1 cache from OWNER/REPO\n",
 		},
+		{
+			name: "no caches to delete when deleting all",
+			opts: DeleteOptions{DeleteAll: true},
+			stubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/caches"),
+					httpmock.JSONResponse(shared.CachePayload{
+						ActionsCaches: []shared.Cache{},
+						TotalCount:    0,
+					}),
+				)
+			},
+			tty:        false,
+			wantErr:    true,
+			wantErrMsg: "X No caches to delete",
+		},
+		{
+			name: "no caches to delete when deleting all but succeed on no cache tty",
+			opts: DeleteOptions{DeleteAll: true, SucceedOnNoCaches: true},
+			stubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/caches"),
+					httpmock.JSONResponse(shared.CachePayload{
+						ActionsCaches: []shared.Cache{},
+						TotalCount:    0,
+					}),
+				)
+			},
+			tty:        true,
+			wantErr:    false,
+			wantStdout: "✓ No caches to delete\n",
+		},
+		{
+			name: "no caches to delete when deleting all but succeed on no cache non-tty",
+			opts: DeleteOptions{DeleteAll: true, SucceedOnNoCaches: true},
+			stubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/caches"),
+					httpmock.JSONResponse(shared.CachePayload{
+						ActionsCaches: []shared.Cache{},
+						TotalCount:    0,
+					}),
+				)
+			},
+			tty:        false,
+			wantErr:    false,
+			wantStdout: "",
+		},
 	}
 
 	for _, tt := range tests {
diff --git a/pkg/cmd/factory/remote_resolver_test.go b/pkg/cmd/factory/remote_resolver_test.go
--- a/pkg/cmd/factory/remote_resolver_test.go
+++ b/pkg/cmd/factory/remote_resolver_test.go
@@ -1,14 +1,17 @@
 package factory
 
 import (
+	"errors"
 	"net/url"
 	"testing"
 
+	"github.com/cli/cli/v2/context"
 	"github.com/cli/cli/v2/git"
 	"github.com/cli/cli/v2/internal/config"
 	"github.com/cli/cli/v2/internal/gh"
 	ghmock "github.com/cli/cli/v2/internal/gh/mock"
 	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
 )
 
 type identityTranslator struct{}
@@ -288,3 +291,95 @@ func Test_remoteResolver(t *testing.T) {
 		})
 	}
 }
+
+func Test_remoteResolver_Caching(t *testing.T) {
+	t.Run("cache remotes", func(t *testing.T) {
+		var readRemotesCalled bool
+
+		rr := &remoteResolver{
+			readRemotes: func() (git.RemoteSet, error) {
+				if readRemotesCalled {
+					return git.RemoteSet{}, errors.New("readRemotes should only be called once")
+				}
+
+				readRemotesCalled = true
+				return git.RemoteSet{
+					git.NewRemote("origin", "https://github.com/owner/repo.git"),
+				}, nil
+			},
+			getConfig: func() (gh.Config, error) {
+				cfg := &ghmock.ConfigMock{}
+				cfg.AuthenticationFunc = func() gh.AuthConfig {
+					authCfg := &config.AuthConfig{}
+					authCfg.SetHosts([]string{"github.com"})
+					authCfg.SetDefaultHost("github.com", "default")
+					return authCfg
+				}
+				return cfg, nil
+			},
+			urlTranslator: identityTranslator{},
+		}
+
+		resolver := rr.Resolver()
+
+		expectedRemoteNames := []string{"origin"}
+		remotes, err := resolver()
+		require.NoError(t, err)
+		require.Equal(t, expectedRemoteNames, mapRemotesToNames(remotes))
+
+		require.Equal(t, readRemotesCalled, true)
+
+		cachedRemotes, err := resolver()
+		require.NoError(t, err, "expected no error to be cached")
+		require.Equal(t, expectedRemoteNames, mapRemotesToNames(cachedRemotes), "expected the remotes to be cached")
+	})
+
+	t.Run("cache error", func(t *testing.T) {
+		var readRemotesCalled bool
+
+		rr := &remoteResolver{
+			readRemotes: func() (git.RemoteSet, error) {
+				if readRemotesCalled {
+					return git.RemoteSet{
+						git.NewRemote("origin", "https://github.com/owner/repo.git"),
+					}, nil
+				}
+
+				readRemotesCalled = true
+				return git.RemoteSet{}, errors.New("error to be cached")
+			},
+			getConfig: func() (gh.Config, error) {
+				cfg := &ghmock.ConfigMock{}
+				cfg.AuthenticationFunc = func() gh.AuthConfig {
+					authCfg := &config.AuthConfig{}
+					authCfg.SetHosts([]string{"github.com"})
+					authCfg.SetDefaultHost("github.com", "default")
+					return authCfg
+				}
+				return cfg, nil
+			},
+			urlTranslator: identityTranslator{},
+		}
+
+		resolver := rr.Resolver()
+
+		expectedErr := errors.New("error to be cached")
+		remotes, err := resolver()
+		require.Equal(t, expectedErr, err)
+		require.Empty(t, remotes, "should return no remotes")
+
+		require.Equal(t, readRemotesCalled, true)
+
+		cachedRemotes, err := resolver()
+		require.Equal(t, expectedErr, err, "expected the error to be cached")
+		require.Empty(t, cachedRemotes, "should return no remotes")
+	})
+}
+
+func mapRemotesToNames(remotes context.Remotes) []string {
+	names := make([]string, len(remotes))
+	for i, r := range remotes {
+		names[i] = r.Name
+	}
+	return names
+}
diff --git a/pkg/cmd/gist/list/list_test.go b/pkg/cmd/gist/list/list_test.go
--- a/pkg/cmd/gist/list/list_test.go
+++ b/pkg/cmd/gist/list/list_test.go
@@ -540,14 +540,14 @@ func Test_listRun(t *testing.T) {
 			wantOut: heredoc.Doc(`
 				1234 main.txt
 				    octo match in the description
-				
+
 				2345 octo.txt
 				    match in the file name
 
 				3456 main.txt
 				    match in the file text
 				        octo in the text
-				
+
 			`),
 		},
 		{
@@ -599,14 +599,14 @@ func Test_listRun(t *testing.T) {
 			wantOut: heredoc.Docf(`
 				%[1]s[0;34m1234%[1]s[0m %[1]s[0;32mmain.txt%[1]s[0m
 				    %[1]s[0;30;43mocto%[1]s[0m%[1]s[0;1;39m match in the description%[1]s[0m
-				
+
 				%[1]s[0;34m2345%[1]s[0m %[1]s[0;30;43mocto%[1]s[0m%[1]s[0;32m.txt%[1]s[0m
 				    %[1]s[0;1;39mmatch in the file name%[1]s[0m
-				
+
 				%[1]s[0;34m3456%[1]s[0m %[1]s[0;32mmain.txt%[1]s[0m
 				    %[1]s[0;1;39mmatch in the file text%[1]s[0m
 				        %[1]s[0;30;43mocto%[1]s[0m in the text
-				
+
 			`, "\x1b"),
 		},
 	}
diff --git a/pkg/cmd/issue/comment/comment_test.go b/pkg/cmd/issue/comment/comment_test.go
--- a/pkg/cmd/issue/comment/comment_test.go
+++ b/pkg/cmd/issue/comment/comment_test.go
@@ -109,6 +109,29 @@ func TestNewCmdComment(t *testing.T) {
 			},
 			wantsErr: false,
 		},
+		{
+			name:  "edit last flag",
+			input: "1 --edit-last",
+			output: shared.CommentableOptions{
+				Interactive: true,
+				InputType:   shared.InputTypeEditor,
+				Body:        "",
+				EditLast:    true,
+			},
+			wantsErr: false,
+		},
+		{
+			name:  "edit last flag with create if none",
+			input: "1 --edit-last --create-if-none",
+			output: shared.CommentableOptions{
+				Interactive:  true,
+				InputType:    shared.InputTypeEditor,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+			},
+			wantsErr: false,
+		},
 		{
 			name:     "body and body-file flags",
 			input:    "1 --body 'test' --body-file 'test-file.txt'",
@@ -139,6 +162,12 @@ func TestNewCmdComment(t *testing.T) {
 			output:   shared.CommentableOptions{},
 			wantsErr: true,
 		},
+		{
+			name:     "create-if-none flag without edit-last",
+			input:    "1 --create-if-none",
+			output:   shared.CommentableOptions{},
+			wantsErr: true,
+		},
 	}
 
 	for _, tt := range tests {
@@ -188,11 +217,12 @@ func TestNewCmdComment(t *testing.T) {
 
 func Test_commentRun(t *testing.T) {
 	tests := []struct {
-		name      string
-		input     *shared.CommentableOptions
-		httpStubs func(*testing.T, *httpmock.Registry)
-		stdout    string
-		stderr    string
+		name          string
+		input         *shared.CommentableOptions
+		emptyComments bool
+		httpStubs     func(*testing.T, *httpmock.Registry)
+		stdout        string
+		stderr        string
 	}{
 		{
 			name: "interactive editor",
@@ -225,6 +255,24 @@ func Test_commentRun(t *testing.T) {
 			},
 			stdout: "https://github.com/OWNER/REPO/issues/123#issuecomment-111\n",
 		},
+		{
+			name: "interactive editor with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  true,
+				InputType:    0,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				InteractiveEditSurvey:     func(string) (string, error) { return "comment body", nil },
+				ConfirmCreateIfNoneSurvey: func() (bool, error) { return true, nil },
+				ConfirmSubmitSurvey:       func() (bool, error) { return true, nil },
+			},
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				mockCommentUpdate(t, reg)
+			},
+			stdout: "https://github.com/OWNER/REPO/issues/123#issuecomment-111\n",
+		},
 		{
 			name: "non-interactive web",
 			input: &shared.CommentableOptions{
@@ -248,6 +296,39 @@ func Test_commentRun(t *testing.T) {
 			},
 			stderr: "Opening https://github.com/OWNER/REPO/issues/123 in your browser.\n",
 		},
+		{
+			name: "non-interactive web with edit last and create if none for empty comments",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeWeb,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				OpenInBrowser: func(u string) error {
+					assert.Contains(t, u, "#issuecomment-new")
+					return nil
+				},
+			},
+			emptyComments: true,
+			stderr:        "Opening https://github.com/OWNER/REPO/issues/123 in your browser.\n",
+		},
+		{
+			name: "non-interactive web with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeWeb,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				OpenInBrowser: func(u string) error {
+					assert.Contains(t, u, "#issuecomment-111")
+					return nil
+				},
+			},
+			stderr: "Opening https://github.com/OWNER/REPO/issues/123 in your browser.\n",
+		},
 		{
 			name: "non-interactive editor",
 			input: &shared.CommentableOptions{
@@ -277,6 +358,23 @@ func Test_commentRun(t *testing.T) {
 			},
 			stdout: "https://github.com/OWNER/REPO/issues/123#issuecomment-111\n",
 		},
+		{
+			name: "non-interactive editor with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeEditor,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				EditSurvey: func(string) (string, error) { return "comment body", nil },
+			},
+			emptyComments: true,
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				mockCommentCreate(t, reg)
+			},
+			stdout: "https://github.com/OWNER/REPO/issues/123#issuecomment-456\n",
+		},
 		{
 			name: "non-interactive inline",
 			input: &shared.CommentableOptions{
@@ -319,14 +417,21 @@ func Test_commentRun(t *testing.T) {
 		tt.input.HttpClient = func() (*http.Client, error) {
 			return &http.Client{Transport: reg}, nil
 		}
+
+		comments := api.Comments{Nodes: []api.Comment{
+			{ID: "id1", Author: api.CommentAuthor{Login: "octocat"}, URL: "https://github.com/OWNER/REPO/issues/123#issuecomment-111", ViewerDidAuthor: true},
+			{ID: "id2", Author: api.CommentAuthor{Login: "monalisa"}, URL: "https://github.com/OWNER/REPO/issues/123#issuecomment-222"},
+		}}
+
+		if tt.emptyComments {
+			comments.Nodes = []api.Comment{}
+		}
+
 		tt.input.RetrieveCommentable = func() (shared.Commentable, ghrepo.Interface, error) {
 			return &api.Issue{
-				ID:  "ISSUE-ID",
-				URL: "https://github.com/OWNER/REPO/issues/123",
-				Comments: api.Comments{Nodes: []api.Comment{
-					{ID: "id1", Author: api.CommentAuthor{Login: "octocat"}, URL: "https://github.com/OWNER/REPO/issues/123#issuecomment-111", ViewerDidAuthor: true},
-					{ID: "id2", Author: api.CommentAuthor{Login: "monalisa"}, URL: "https://github.com/OWNER/REPO/issues/123#issuecomment-222"},
-				}},
+				ID:       "ISSUE-ID",
+				URL:      "https://github.com/OWNER/REPO/issues/123",
+				Comments: comments,
 			}, ghrepo.New("OWNER", "REPO"), nil
 		}
 
diff --git a/pkg/cmd/label/list_test.go b/pkg/cmd/label/list_test.go
--- a/pkg/cmd/label/list_test.go
+++ b/pkg/cmd/label/list_test.go
@@ -218,7 +218,7 @@ func TestListRun(t *testing.T) {
 			wantStdout: heredoc.Doc(`
 
 				Showing 2 of 2 labels in OWNER/REPO
-				
+
 				NAME  DESCRIPTION           COLOR
 				bug   This is a bug label   #d73a4a
 				docs  This is a docs label  #ffa8da
diff --git a/pkg/cmd/pr/checkout/checkout_test.go b/pkg/cmd/pr/checkout/checkout_test.go
--- a/pkg/cmd/pr/checkout/checkout_test.go
+++ b/pkg/cmd/pr/checkout/checkout_test.go
@@ -23,8 +23,87 @@ import (
 	"github.com/cli/cli/v2/test"
 	"github.com/google/shlex"
 	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
 )
 
+func TestNewCmdCheckout(t *testing.T) {
+	tests := []struct {
+		name      string
+		args      string
+		wantsOpts CheckoutOptions
+		wantErr   error
+	}{
+		{
+			name: "recurse submodules",
+			args: "--recurse-submodules 123",
+			wantsOpts: CheckoutOptions{
+				RecurseSubmodules: true,
+			},
+		},
+		{
+			name: "force",
+			args: "--force 123",
+			wantsOpts: CheckoutOptions{
+				Force: true,
+			},
+		},
+		{
+			name: "detach",
+			args: "--detach 123",
+			wantsOpts: CheckoutOptions{
+				Detach: true,
+			},
+		},
+		{
+			name: "branch",
+			args: "--branch test-branch 123",
+			wantsOpts: CheckoutOptions{
+				BranchName: "test-branch",
+			},
+		},
+		{
+			name:    "when there is no selector and no TTY, returns an error",
+			args:    "",
+			wantErr: cmdutil.FlagErrorf("pull request number, URL, or branch required when not running interactively"),
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			ios, _, _, _ := iostreams.Test()
+			f := &cmdutil.Factory{
+				IOStreams: ios,
+			}
+
+			ios.SetStdinTTY(false)
+
+			argv, err := shlex.Split(tt.args)
+			assert.NoError(t, err)
+
+			var spiedOpts *CheckoutOptions
+			cmd := NewCmdCheckout(f, func(opts *CheckoutOptions) error {
+				spiedOpts = opts
+				return nil
+			})
+			cmd.SetArgs(argv)
+			cmd.SetIn(&bytes.Buffer{})
+			cmd.SetOut(&bytes.Buffer{})
+			cmd.SetErr(&bytes.Buffer{})
+
+			_, err = cmd.ExecuteC()
+			if tt.wantErr != nil {
+				require.Equal(t, tt.wantErr, err)
+				return
+			}
+			require.NoError(t, err)
+			require.Equal(t, tt.wantsOpts.RecurseSubmodules, spiedOpts.RecurseSubmodules)
+			require.Equal(t, tt.wantsOpts.Force, spiedOpts.Force)
+			require.Equal(t, tt.wantsOpts.Detach, spiedOpts.Detach)
+			require.Equal(t, tt.wantsOpts.BranchName, spiedOpts.BranchName)
+		})
+	}
+}
+
 // repo: either "baseOwner/baseRepo" or "baseOwner/baseRepo:defaultBranch"
 // prHead: "headOwner/headRepo:headBranch"
 func stubPR(repo, prHead string) (ghrepo.Interface, *api.PullRequest) {
@@ -70,6 +149,20 @@ func _stubPR(repo, prHead string, number int, title string, state string, isDraf
 	}
 }
 
+type stubPRResolver struct {
+	pr       *api.PullRequest
+	baseRepo ghrepo.Interface
+
+	err error
+}
+
+func (s *stubPRResolver) Resolve() (*api.PullRequest, ghrepo.Interface, error) {
+	if s.err != nil {
+		return nil, nil, s.err
+	}
+	return s.pr, s.baseRepo, nil
+}
+
 func Test_checkoutRun(t *testing.T) {
 	tests := []struct {
 		name string
@@ -88,16 +181,13 @@ func Test_checkoutRun(t *testing.T) {
 		{
 			name: "checkout with ssh remote URL",
 			opts: &CheckoutOptions{
-				SelectorArg: "123",
-				Finder: func() shared.PRFinder {
+				PRResolver: func() PRResolver {
 					baseRepo, pr := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
-					finder := shared.NewMockFinder("123", pr, baseRepo)
-					return finder
+					return &stubPRResolver{
+						pr:       pr,
+						baseRepo: baseRepo,
+					}
 				}(),
-				BaseRepo: func() (ghrepo.Interface, error) {
-					baseRepo, _ := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
-					return baseRepo, nil
-				},
 				Config: func() (gh.Config, error) {
 					return config.NewBlankConfig(), nil
 				},
@@ -110,25 +200,22 @@ func Test_checkoutRun(t *testing.T) {
 			},
 			runStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git show-ref --verify -- refs/heads/feature`, 1, "")
-				cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+				cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 				cs.Register(`git checkout -b feature --track origin/feature`, 0, "")
 			},
 		},
 		{
 			name: "fork repo was deleted",
 			opts: &CheckoutOptions{
-				SelectorArg: "123",
-				Finder: func() shared.PRFinder {
-					baseRepo, pr := stubPR("OWNER/REPO:master", "hubot/REPO:feature")
+				PRResolver: func() PRResolver {
+					baseRepo, pr := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
 					pr.MaintainerCanModify = true
 					pr.HeadRepository = nil
-					finder := shared.NewMockFinder("123", pr, baseRepo)
-					return finder
+					return &stubPRResolver{
+						pr:       pr,
+						baseRepo: baseRepo,
+					}
 				}(),
-				BaseRepo: func() (ghrepo.Interface, error) {
-					baseRepo, _ := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
-					return baseRepo, nil
-				},
 				Config: func() (gh.Config, error) {
 					return config.NewBlankConfig(), nil
 				},
@@ -140,7 +227,7 @@ func Test_checkoutRun(t *testing.T) {
 				"origin": "OWNER/REPO",
 			},
 			runStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git fetch origin refs/pull/123/head:feature`, 0, "")
+				cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags`, 0, "")
 				cs.Register(`git config branch\.feature\.merge`, 1, "")
 				cs.Register(`git checkout feature`, 0, "")
 				cs.Register(`git config branch\.feature\.remote origin`, 0, "")
@@ -151,17 +238,14 @@ func Test_checkoutRun(t *testing.T) {
 		{
 			name: "with local branch rename and existing git remote",
 			opts: &CheckoutOptions{
-				SelectorArg: "123",
-				BranchName:  "foobar",
-				Finder: func() shared.PRFinder {
+				BranchName: "foobar",
+				PRResolver: func() PRResolver {
 					baseRepo, pr := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
-					finder := shared.NewMockFinder("123", pr, baseRepo)
-					return finder
+					return &stubPRResolver{
+						pr:       pr,
+						baseRepo: baseRepo,
+					}
 				}(),
-				BaseRepo: func() (ghrepo.Interface, error) {
-					baseRepo, _ := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
-					return baseRepo, nil
-				},
 				Config: func() (gh.Config, error) {
 					return config.NewBlankConfig(), nil
 				},
@@ -174,25 +258,22 @@ func Test_checkoutRun(t *testing.T) {
 			},
 			runStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git show-ref --verify -- refs/heads/foobar`, 1, "")
-				cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+				cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 				cs.Register(`git checkout -b foobar --track origin/feature`, 0, "")
 			},
 		},
 		{
 			name: "with local branch name, no existing git remote",
 			opts: &CheckoutOptions{
-				SelectorArg: "123",
-				BranchName:  "foobar",
-				Finder: func() shared.PRFinder {
+				BranchName: "foobar",
+				PRResolver: func() PRResolver {
 					baseRepo, pr := stubPR("OWNER/REPO:master", "hubot/REPO:feature")
 					pr.MaintainerCanModify = true
-					finder := shared.NewMockFinder("123", pr, baseRepo)
-					return finder
+					return &stubPRResolver{
+						pr:       pr,
+						baseRepo: baseRepo,
+					}
 				}(),
-				BaseRepo: func() (ghrepo.Interface, error) {
-					baseRepo, _ := stubPR("OWNER/REPO:master", "hubot/REPO:feature")
-					return baseRepo, nil
-				},
 				Config: func() (gh.Config, error) {
 					return config.NewBlankConfig(), nil
 				},
@@ -205,86 +286,22 @@ func Test_checkoutRun(t *testing.T) {
 			},
 			runStubs: func(cs *run.CommandStubber) {
 				cs.Register(`git config branch\.foobar\.merge`, 1, "")
-				cs.Register(`git fetch origin refs/pull/123/head:foobar`, 0, "")
+				cs.Register(`git fetch origin refs/pull/123/head:foobar --no-tags`, 0, "")
 				cs.Register(`git checkout foobar`, 0, "")
 				cs.Register(`git config branch\.foobar\.remote https://github.com/hubot/REPO.git`, 0, "")
 				cs.Register(`git config branch\.foobar\.pushRemote https://github.com/hubot/REPO.git`, 0, "")
 				cs.Register(`git config branch\.foobar\.merge refs/heads/feature`, 0, "")
 			},
 		},
 		{
-			name: "with no selected PR args and non tty, return error",
+			name: "when the PR resolver errors, then that error is bubbled up",
 			opts: &CheckoutOptions{
-				SelectorArg: "",
-				Interactive: false,
-				BaseRepo: func() (ghrepo.Interface, error) {
-					return ghrepo.New("OWNER", "REPO"), nil
+				PRResolver: &stubPRResolver{
+					err: errors.New("expected test error"),
 				},
 			},
-			remotes: map[string]string{
-				"origin": "OWNER/REPO",
-			},
 			wantErr: true,
-			errMsg:  "pull request number, URL, or branch required when not running interactively",
-		},
-		{
-			name: "with no selected PR args and stdin tty, prompts for choice",
-			opts: &CheckoutOptions{
-				SelectorArg: "",
-				Interactive: true,
-				Lister: func() shared.PRLister {
-					_, pr1 := _stubPR("OWNER/REPO:master", "OWNER/REPO:feature", 32, "New feature", "OPEN", false)
-					_, pr2 := _stubPR("OWNER/REPO:master", "OWNER/REPO:bug-fix", 29, "Fixed bad bug", "OPEN", false)
-					_, pr3 := _stubPR("OWNER/REPO:master", "OWNER/REPO:docs", 28, "Improve documentation", "OPEN", true)
-					lister := shared.NewMockLister(&api.PullRequestAndTotalCount{
-						TotalCount: 3,
-						PullRequests: []api.PullRequest{
-							*pr1, *pr2, *pr3,
-						}, SearchCapped: false}, nil)
-					lister.ExpectFields([]string{"number", "title", "state", "isDraft", "headRefName", "headRepository", "headRepositoryOwner", "isCrossRepository", "maintainerCanModify"})
-					return lister
-				}(),
-				BaseRepo: func() (ghrepo.Interface, error) {
-					return ghrepo.New("OWNER", "REPO"), nil
-				},
-				Config: func() (gh.Config, error) {
-					return config.NewBlankConfig(), nil
-				},
-			},
-			promptStubs: func(pm *prompter.MockPrompter) {
-				pm.RegisterSelect("Select a pull request",
-					[]string{"32\tOPEN New feature [feature]", "29\tOPEN Fixed bad bug [bug-fix]", "28\tDRAFT Improve documentation [docs]"},
-					func(_, _ string, opts []string) (int, error) {
-						return prompter.IndexFor(opts, "32\tOPEN New feature [feature]")
-					})
-			},
-			runStubs: func(cs *run.CommandStubber) {
-				cs.Register(`git show-ref --verify -- refs/heads/feature`, 1, "")
-				cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
-				cs.Register(`git checkout -b feature --track origin/feature`, 0, "")
-			},
-			remotes: map[string]string{
-				"origin": "OWNER/REPO",
-			},
-		},
-		{
-			name: "with no select PR args and no open PR, return error",
-			opts: &CheckoutOptions{
-				SelectorArg: "",
-				Interactive: true,
-				BaseRepo: func() (ghrepo.Interface, error) {
-					return ghrepo.New("OWNER", "REPO"), nil
-				},
-				Lister: shared.NewMockLister(&api.PullRequestAndTotalCount{
-					TotalCount:   0,
-					PullRequests: []api.PullRequest{},
-				}, nil),
-			},
-			remotes: map[string]string{
-				"origin": "OWNER/REPO",
-			},
-			wantErr: true,
-			errMsg:  "no open pull requests in OWNER/REPO",
+			errMsg:  "expected test error",
 		},
 	}
 	for _, tt := range tests {
@@ -309,12 +326,6 @@ func Test_checkoutRun(t *testing.T) {
 				tt.runStubs(cmdStubs)
 			}
 
-			pm := prompter.NewMockPrompter(t)
-			tt.opts.Prompter = pm
-			if tt.promptStubs != nil {
-				tt.promptStubs(pm)
-			}
-
 			opts.Remotes = func() (context.Remotes, error) {
 				if len(tt.remotes) == 0 {
 					return nil, errors.New("no remotes")
@@ -351,6 +362,102 @@ func Test_checkoutRun(t *testing.T) {
 	}
 }
 
+func TestSpecificPRResolver(t *testing.T) {
+	t.Run("when the PR Finder returns results, those are returned", func(t *testing.T) {
+		t.Parallel()
+
+		baseRepo, pr := stubPR("OWNER/REPO:master", "OWNER/REPO:feature")
+		mockFinder := shared.NewMockFinder("123", pr, baseRepo)
+		mockFinder.ExpectFields([]string{"number", "headRefName", "headRepository", "headRepositoryOwner", "isCrossRepository", "maintainerCanModify"})
+
+		resolver := &specificPRResolver{
+			prFinder: mockFinder,
+			selector: "123",
+		}
+
+		resolvedPR, resolvedBaseRepo, err := resolver.Resolve()
+		require.NoError(t, err)
+		require.Equal(t, pr, resolvedPR)
+		require.True(t, ghrepo.IsSame(baseRepo, resolvedBaseRepo), "expected repos to be the same")
+	})
+
+	t.Run("when the PR Finder errors, that error is returned", func(t *testing.T) {
+		t.Parallel()
+
+		mockFinder := shared.NewMockFinder("123", nil, nil)
+
+		resolver := &specificPRResolver{
+			prFinder: mockFinder,
+			selector: "123",
+		}
+
+		_, _, err := resolver.Resolve()
+		var notFoundErr *shared.NotFoundError
+		require.ErrorAs(t, err, &notFoundErr)
+	})
+}
+
+func TestPromptingPRResolver(t *testing.T) {
+	t.Run("when the PR Lister has results, then we prompt for a choice", func(t *testing.T) {
+		t.Parallel()
+
+		ios, _, _, _ := iostreams.Test()
+
+		baseRepo, pr1 := _stubPR("OWNER/REPO:master", "OWNER/REPO:feature", 32, "New feature", "OPEN", false)
+		_, pr2 := _stubPR("OWNER/REPO:master", "OWNER/REPO:bug-fix", 29, "Fixed bad bug", "OPEN", false)
+		_, pr3 := _stubPR("OWNER/REPO:master", "OWNER/REPO:docs", 28, "Improve documentation", "OPEN", true)
+		lister := shared.NewMockLister(&api.PullRequestAndTotalCount{
+			TotalCount: 3,
+			PullRequests: []api.PullRequest{
+				*pr1, *pr2, *pr3,
+			}, SearchCapped: false}, nil)
+		lister.ExpectFields([]string{"number", "title", "state", "isDraft", "headRefName", "headRepository", "headRepositoryOwner", "isCrossRepository", "maintainerCanModify"})
+
+		pm := prompter.NewMockPrompter(t)
+		pm.RegisterSelect("Select a pull request",
+			[]string{"32\tOPEN New feature [feature]", "29\tOPEN Fixed bad bug [bug-fix]", "28\tDRAFT Improve documentation [docs]"},
+			func(_, _ string, opts []string) (int, error) {
+				return prompter.IndexFor(opts, "32\tOPEN New feature [feature]")
+			})
+
+		resolver := &promptingPRResolver{
+			io:       ios,
+			prompter: pm,
+
+			prLister: lister,
+
+			baseRepo: baseRepo,
+		}
+
+		resolvedPR, resolvedBaseRepo, err := resolver.Resolve()
+		require.NoError(t, err)
+		require.Equal(t, pr1, resolvedPR)
+		require.True(t, ghrepo.IsSame(baseRepo, resolvedBaseRepo), "expected repos to be the same")
+	})
+
+	t.Run("when the PR lister has no results, then we return an error", func(t *testing.T) {
+		t.Parallel()
+
+		ios, _, _, _ := iostreams.Test()
+
+		lister := shared.NewMockLister(&api.PullRequestAndTotalCount{
+			TotalCount:   0,
+			PullRequests: []api.PullRequest{},
+		}, nil)
+
+		resolver := &promptingPRResolver{
+			io:       ios,
+			prLister: lister,
+			baseRepo: ghrepo.New("OWNER", "REPO"),
+		}
+
+		_, _, err := resolver.Resolve()
+		var noResultsErr cmdutil.NoResultsError
+		require.ErrorAs(t, err, &noResultsErr)
+		require.Equal(t, "no open pull requests in OWNER/REPO", noResultsErr.Error())
+	})
+}
+
 /** LEGACY TESTS **/
 
 func runCommand(rt http.RoundTripper, remotes context.Remotes, branch string, cli string, baseRepo ghrepo.Interface) (*test.CmdOut, error) {
@@ -417,7 +524,7 @@ func TestPRCheckout_sameRepo(t *testing.T) {
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
 
-	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 	cs.Register(`git show-ref --verify -- refs/heads/feature`, 1, "")
 	cs.Register(`git checkout -b feature --track origin/feature`, 0, "")
 
@@ -436,7 +543,7 @@ func TestPRCheckout_existingBranch(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 	cs.Register(`git show-ref --verify -- refs/heads/feature`, 0, "")
 	cs.Register(`git checkout feature`, 0, "")
 	cs.Register(`git merge --ff-only refs/remotes/origin/feature`, 0, "")
@@ -468,7 +575,7 @@ func TestPRCheckout_differentRepo_remoteExists(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch robot-fork \+refs/heads/feature:refs/remotes/robot-fork/feature`, 0, "")
+	cs.Register(`git fetch robot-fork \+refs/heads/feature:refs/remotes/robot-fork/feature --no-tags`, 0, "")
 	cs.Register(`git show-ref --verify -- refs/heads/feature`, 1, "")
 	cs.Register(`git checkout -b feature --track robot-fork/feature`, 0, "")
 
@@ -488,7 +595,7 @@ func TestPRCheckout_differentRepo(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin refs/pull/123/head:feature`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags`, 0, "")
 	cs.Register(`git config branch\.feature\.merge`, 1, "")
 	cs.Register(`git checkout feature`, 0, "")
 	cs.Register(`git config branch\.feature\.remote origin`, 0, "")
@@ -501,6 +608,29 @@ func TestPRCheckout_differentRepo(t *testing.T) {
 	assert.Equal(t, "", output.Stderr())
 }
 
+func TestPRCheckout_differentRepoForce(t *testing.T) {
+	http := &httpmock.Registry{}
+	defer http.Verify(t)
+
+	baseRepo, pr := stubPR("OWNER/REPO:master", "hubot/REPO:feature")
+	finder := shared.RunCommandFinder("123", pr, baseRepo)
+	finder.ExpectFields([]string{"number", "headRefName", "headRepository", "headRepositoryOwner", "isCrossRepository", "maintainerCanModify"})
+
+	cs, cmdTeardown := run.Stub()
+	defer cmdTeardown(t)
+	cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags --force`, 0, "")
+	cs.Register(`git config branch\.feature\.merge`, 1, "")
+	cs.Register(`git checkout feature`, 0, "")
+	cs.Register(`git config branch\.feature\.remote origin`, 0, "")
+	cs.Register(`git config branch\.feature\.pushRemote origin`, 0, "")
+	cs.Register(`git config branch\.feature\.merge refs/pull/123/head`, 0, "")
+
+	output, err := runCommand(http, nil, "master", `123 --force`, baseRepo)
+	assert.NoError(t, err)
+	assert.Equal(t, "", output.String())
+	assert.Equal(t, "", output.Stderr())
+}
+
 func TestPRCheckout_differentRepo_existingBranch(t *testing.T) {
 	http := &httpmock.Registry{}
 	defer http.Verify(t)
@@ -510,7 +640,7 @@ func TestPRCheckout_differentRepo_existingBranch(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin refs/pull/123/head:feature`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags`, 0, "")
 	cs.Register(`git config branch\.feature\.merge`, 0, "refs/heads/feature\n")
 	cs.Register(`git checkout feature`, 0, "")
 
@@ -529,7 +659,7 @@ func TestPRCheckout_detachedHead(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin refs/pull/123/head:feature`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags`, 0, "")
 	cs.Register(`git config branch\.feature\.merge`, 0, "refs/heads/feature\n")
 	cs.Register(`git checkout feature`, 0, "")
 
@@ -548,7 +678,7 @@ func TestPRCheckout_differentRepo_currentBranch(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin refs/pull/123/head`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head --no-tags`, 0, "")
 	cs.Register(`git config branch\.feature\.merge`, 0, "refs/heads/feature\n")
 	cs.Register(`git merge --ff-only FETCH_HEAD`, 0, "")
 
@@ -585,7 +715,7 @@ func TestPRCheckout_maintainerCanModify(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin refs/pull/123/head:feature`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head:feature --no-tags`, 0, "")
 	cs.Register(`git config branch\.feature\.merge`, 1, "")
 	cs.Register(`git checkout feature`, 0, "")
 	cs.Register(`git config branch\.feature\.remote https://github\.com/hubot/REPO\.git`, 0, "")
@@ -606,7 +736,7 @@ func TestPRCheckout_recurseSubmodules(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 	cs.Register(`git show-ref --verify -- refs/heads/feature`, 0, "")
 	cs.Register(`git checkout feature`, 0, "")
 	cs.Register(`git merge --ff-only refs/remotes/origin/feature`, 0, "")
@@ -627,7 +757,7 @@ func TestPRCheckout_force(t *testing.T) {
 
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
-	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature`, 0, "")
+	cs.Register(`git fetch origin \+refs/heads/feature:refs/remotes/origin/feature --no-tags`, 0, "")
 	cs.Register(`git show-ref --verify -- refs/heads/feature`, 0, "")
 	cs.Register(`git checkout feature`, 0, "")
 	cs.Register(`git reset --hard refs/remotes/origin/feature`, 0, "")
@@ -649,7 +779,7 @@ func TestPRCheckout_detach(t *testing.T) {
 	cs, cmdTeardown := run.Stub()
 	defer cmdTeardown(t)
 	cs.Register(`git checkout --detach FETCH_HEAD`, 0, "")
-	cs.Register(`git fetch origin refs/pull/123/head`, 0, "")
+	cs.Register(`git fetch origin refs/pull/123/head --no-tags`, 0, "")
 
 	output, err := runCommand(http, nil, "", `123 --detach`, baseRepo)
 	assert.NoError(t, err)
diff --git a/pkg/cmd/pr/close/close_test.go b/pkg/cmd/pr/close/close_test.go
--- a/pkg/cmd/pr/close/close_test.go
+++ b/pkg/cmd/pr/close/close_test.go
@@ -271,7 +271,7 @@ func TestPrClose_deleteBranch_notInGitRepo(t *testing.T) {
 	assert.Equal(t, "", output.String())
 	assert.Equal(t, heredoc.Doc(`
 		✓ Closed pull request OWNER/REPO#96 (The title of the PR)
-		! Skipped deleting the local branch since current directory is not a git repository 
+		! Skipped deleting the local branch since current directory is not a git repository
 		✓ Deleted branch trunk
 	`), output.Stderr())
 }
diff --git a/pkg/cmd/pr/comment/comment_test.go b/pkg/cmd/pr/comment/comment_test.go
--- a/pkg/cmd/pr/comment/comment_test.go
+++ b/pkg/cmd/pr/comment/comment_test.go
@@ -129,6 +129,29 @@ func TestNewCmdComment(t *testing.T) {
 			},
 			wantsErr: false,
 		},
+		{
+			name:  "edit last flag",
+			input: "1 --edit-last",
+			output: shared.CommentableOptions{
+				Interactive: true,
+				InputType:   shared.InputTypeEditor,
+				Body:        "",
+				EditLast:    true,
+			},
+			wantsErr: false,
+		},
+		{
+			name:  "edit last flag with create if none",
+			input: "1 --edit-last --create-if-none",
+			output: shared.CommentableOptions{
+				Interactive:  true,
+				InputType:    shared.InputTypeEditor,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+			},
+			wantsErr: false,
+		},
 		{
 			name:     "body and body-file flags",
 			input:    "1 --body 'test' --body-file 'test-file.txt'",
@@ -159,6 +182,12 @@ func TestNewCmdComment(t *testing.T) {
 			output:   shared.CommentableOptions{},
 			wantsErr: true,
 		},
+		{
+			name:     "create-if-none flag without edit-last",
+			input:    "1 --create-if-none",
+			output:   shared.CommentableOptions{},
+			wantsErr: true,
+		},
 	}
 
 	for _, tt := range tests {
@@ -208,11 +237,12 @@ func TestNewCmdComment(t *testing.T) {
 
 func Test_commentRun(t *testing.T) {
 	tests := []struct {
-		name      string
-		input     *shared.CommentableOptions
-		httpStubs func(*testing.T, *httpmock.Registry)
-		stdout    string
-		stderr    string
+		name          string
+		input         *shared.CommentableOptions
+		emptyComments bool
+		httpStubs     func(*testing.T, *httpmock.Registry)
+		stdout        string
+		stderr        string
 	}{
 		{
 			name: "interactive editor",
@@ -245,6 +275,24 @@ func Test_commentRun(t *testing.T) {
 			},
 			stdout: "https://github.com/OWNER/REPO/pull/123#issuecomment-111\n",
 		},
+		{
+			name: "interactive editor with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  true,
+				InputType:    0,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				InteractiveEditSurvey:     func(string) (string, error) { return "comment body", nil },
+				ConfirmCreateIfNoneSurvey: func() (bool, error) { return true, nil },
+				ConfirmSubmitSurvey:       func() (bool, error) { return true, nil },
+			},
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				mockCommentUpdate(t, reg)
+			},
+			stdout: "https://github.com/OWNER/REPO/pull/123#issuecomment-111\n",
+		},
 		{
 			name: "non-interactive web",
 			input: &shared.CommentableOptions{
@@ -264,7 +312,43 @@ func Test_commentRun(t *testing.T) {
 				Body:        "",
 				EditLast:    true,
 
-				OpenInBrowser: func(string) error { return nil },
+				OpenInBrowser: func(u string) error {
+					assert.Contains(t, u, "#issuecomment-111")
+					return nil
+				},
+			},
+			stderr: "Opening https://github.com/OWNER/REPO/pull/123 in your browser.\n",
+		},
+		{
+			name: "non-interactive web with edit last and create if none for empty comments",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeWeb,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				OpenInBrowser: func(u string) error {
+					assert.Contains(t, u, "#issuecomment-new")
+					return nil
+				},
+			},
+			emptyComments: true,
+			stderr:        "Opening https://github.com/OWNER/REPO/pull/123 in your browser.\n",
+		},
+		{
+			name: "non-interactive web with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeWeb,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				OpenInBrowser: func(u string) error {
+					assert.Contains(t, u, "#issuecomment-111")
+					return nil
+				},
 			},
 			stderr: "Opening https://github.com/OWNER/REPO/pull/123 in your browser.\n",
 		},
@@ -297,6 +381,23 @@ func Test_commentRun(t *testing.T) {
 			},
 			stdout: "https://github.com/OWNER/REPO/pull/123#issuecomment-111\n",
 		},
+		{
+			name: "non-interactive editor with edit last and create if none",
+			input: &shared.CommentableOptions{
+				Interactive:  false,
+				InputType:    shared.InputTypeEditor,
+				Body:         "",
+				EditLast:     true,
+				CreateIfNone: true,
+
+				EditSurvey: func(string) (string, error) { return "comment body", nil },
+			},
+			emptyComments: true,
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				mockCommentCreate(t, reg)
+			},
+			stdout: "https://github.com/OWNER/REPO/pull/123#issuecomment-456\n",
+		},
 		{
 			name: "non-interactive inline",
 			input: &shared.CommentableOptions{
@@ -339,14 +440,20 @@ func Test_commentRun(t *testing.T) {
 
 		tt.input.IO = ios
 		tt.input.HttpClient = httpClient
+
+		comments := api.Comments{Nodes: []api.Comment{
+			{ID: "id1", Author: api.CommentAuthor{Login: "octocat"}, URL: "https://github.com/OWNER/REPO/pull/123#issuecomment-111", ViewerDidAuthor: true},
+			{ID: "id2", Author: api.CommentAuthor{Login: "monalisa"}, URL: "https://github.com/OWNER/REPO/pull/123#issuecomment-222"},
+		}}
+		if tt.emptyComments {
+			comments.Nodes = []api.Comment{}
+		}
+
 		tt.input.RetrieveCommentable = func() (shared.Commentable, ghrepo.Interface, error) {
 			return &api.PullRequest{
-				Number: 123,
-				URL:    "https://github.com/OWNER/REPO/pull/123",
-				Comments: api.Comments{Nodes: []api.Comment{
-					{ID: "id1", Author: api.CommentAuthor{Login: "octocat"}, URL: "https://github.com/OWNER/REPO/pull/123#issuecomment-111", ViewerDidAuthor: true},
-					{ID: "id2", Author: api.CommentAuthor{Login: "monalisa"}, URL: "https://github.com/OWNER/REPO/pull/123#issuecomment-222"},
-				}},
+				Number:   123,
+				URL:      "https://github.com/OWNER/REPO/pull/123",
+				Comments: comments,
 			}, ghrepo.New("OWNER", "REPO"), nil
 		}
 
diff --git a/pkg/cmd/pr/create/create_test.go b/pkg/cmd/pr/create/create_test.go
--- a/pkg/cmd/pr/create/create_test.go
+++ b/pkg/cmd/pr/create/create_test.go
@@ -798,6 +798,7 @@ func Test_createRun(t *testing.T) {
 				cs.Register("git remote rename origin upstream", 0, "")
 				cs.Register(`git remote add origin https://github.com/monalisa/REPO.git`, 0, "")
 				cs.Register(`git push --set-upstream origin HEAD:refs/heads/feature`, 0, "")
+				cs.Register(`git config --add remote.upstream.gh-resolved base`, 0, "")
 			},
 			promptStubs: func(pm *prompter.PrompterMock) {
 				pm.SelectFunc = func(p, _ string, opts []string) (int, error) {
@@ -809,7 +810,7 @@ func Test_createRun(t *testing.T) {
 				}
 			},
 			expectedOut:    "https://github.com/OWNER/REPO/pull/12\n",
-			expectedErrOut: "\nCreating pull request for monalisa:feature into master in OWNER/REPO\n\nChanged OWNER/REPO remote to \"upstream\"\nAdded monalisa/REPO as remote \"origin\"\n",
+			expectedErrOut: "\nCreating pull request for monalisa:feature into master in OWNER/REPO\n\nChanged OWNER/REPO remote to \"upstream\"\nAdded monalisa/REPO as remote \"origin\"\n! Repository monalisa/REPO set as the default repository. To learn more about the default repository, run: gh repo set-default --help\n",
 		},
 		{
 			name: "pushed to non base repo",
diff --git a/pkg/cmd/project/item-edit/item_edit_test.go b/pkg/cmd/project/item-edit/item_edit_test.go
--- a/pkg/cmd/project/item-edit/item_edit_test.go
+++ b/pkg/cmd/project/item-edit/item_edit_test.go
@@ -55,6 +55,14 @@ func TestNewCmdeditItem(t *testing.T) {
 				itemID: "123",
 			},
 		},
+		{
+			name: "number zero",
+			cli:  "--number 0 --id 123",
+			wants: editItemOpts{
+				number: 0,
+				itemID: "123",
+			},
+		},
 		{
 			name: "field-id",
 			cli:  "--field-id FIELD_ID --id 123",
@@ -292,10 +300,64 @@ func TestRunItemEdit_Number(t *testing.T) {
 	config := editItemConfig{
 		io: ios,
 		opts: editItemOpts{
-			number:    123.45,
-			itemID:    "item_id",
-			projectID: "project_id",
-			fieldID:   "field_id",
+			number:        123.45,
+			numberChanged: true,
+			itemID:        "item_id",
+			projectID:     "project_id",
+			fieldID:       "field_id",
+		},
+		client: client,
+	}
+
+	err := runEditItem(config)
+	assert.NoError(t, err)
+	assert.Equal(
+		t,
+		"Edited item \"title\"\n",
+		stdout.String())
+}
+
+func TestRunItemEdit_NumberZero(t *testing.T) {
+	defer gock.Off()
+	// gock.Observe(gock.DumpRequest)
+
+	// edit item
+	gock.New("https://api.github.com").
+		Post("/graphql").
+		BodyString(`{"query":"mutation UpdateItemValues.*","variables":{"input":{"projectId":"project_id","itemId":"item_id","fieldId":"field_id","value":{"number":0}}}}`).
+		Reply(200).
+		JSON(map[string]interface{}{
+			"data": map[string]interface{}{
+				"updateProjectV2ItemFieldValue": map[string]interface{}{
+					"projectV2Item": map[string]interface{}{
+						"ID": "item_id",
+						"content": map[string]interface{}{
+							"__typename": "Issue",
+							"body":       "body",
+							"title":      "title",
+							"number":     1,
+							"repository": map[string]interface{}{
+								"nameWithOwner": "my-repo",
+							},
+						},
+					},
+				},
+			},
+		})
+
+	client := queries.NewTestClient()
+
+	ios, _, stdout, _ := iostreams.Test()
+	ios.SetStdoutTTY(true)
+
+	config := editItemConfig{
+		io: ios,
+		opts: editItemOpts{
+			number:        0,
+			numberChanged: true,
+			itemID:        "item_id",
+			projectID:     "project_id",
+			fieldID:       "field_id",
 		},
 		client: client,
 	}
diff --git a/pkg/cmd/release/create/create_test.go b/pkg/cmd/release/create/create_test.go
--- a/pkg/cmd/release/create/create_test.go
+++ b/pkg/cmd/release/create/create_test.go
@@ -52,17 +52,18 @@ func Test_NewCmdCreate(t *testing.T) {
 			args:  "",
 			isTTY: true,
 			want: CreateOptions{
-				TagName:      "",
-				Target:       "",
-				Name:         "",
-				Body:         "",
-				BodyProvided: false,
-				Draft:        false,
-				Prerelease:   false,
-				RepoOverride: "",
-				Concurrency:  5,
-				Assets:       []*shared.AssetForUpload(nil),
-				VerifyTag:    false,
+				TagName:         "",
+				Target:          "",
+				Name:            "",
+				Body:            "",
+				BodyProvided:    false,
+				Draft:           false,
+				Prerelease:      false,
+				RepoOverride:    "",
+				Concurrency:     5,
+				Assets:          []*shared.AssetForUpload(nil),
+				VerifyTag:       false,
+				FailOnNoCommits: false,
 			},
 		},
 		{
@@ -76,17 +77,18 @@ func Test_NewCmdCreate(t *testing.T) {
 			args:  "v1.2.3",
 			isTTY: true,
 			want: CreateOptions{
-				TagName:      "v1.2.3",
-				Target:       "",
-				Name:         "",
-				Body:         "",
-				BodyProvided: false,
-				Draft:        false,
-				Prerelease:   false,
-				RepoOverride: "",
-				Concurrency:  5,
-				Assets:       []*shared.AssetForUpload(nil),
-				VerifyTag:    false,
+				TagName:         "v1.2.3",
+				Target:          "",
+				Name:            "",
+				Body:            "",
+				BodyProvided:    false,
+				Draft:           false,
+				Prerelease:      false,
+				RepoOverride:    "",
+				Concurrency:     5,
+				Assets:          []*shared.AssetForUpload(nil),
+				VerifyTag:       false,
+				FailOnNoCommits: false,
 			},
 		},
 		{
@@ -347,6 +349,19 @@ func Test_NewCmdCreate(t *testing.T) {
 			isTTY:   false,
 			wantErr: "using `--notes-from-tag` with `--generate-notes` or `--notes-start-tag` is not supported",
 		},
+		{
+			name:  "with --fail-on-no-commits",
+			args:  "v1.2.3 --fail-on-no-commits",
+			isTTY: false,
+			want: CreateOptions{
+				TagName:         "v1.2.3",
+				BodyProvided:    false,
+				Concurrency:     5,
+				Assets:          []*shared.AssetForUpload(nil),
+				NotesFromTag:    false,
+				FailOnNoCommits: true,
+			},
+		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
@@ -402,6 +417,7 @@ func Test_NewCmdCreate(t *testing.T) {
 			assert.Equal(t, tt.want.IsLatest, opts.IsLatest)
 			assert.Equal(t, tt.want.VerifyTag, opts.VerifyTag)
 			assert.Equal(t, tt.want.NotesFromTag, opts.NotesFromTag)
+			assert.Equal(t, tt.want.FailOnNoCommits, opts.FailOnNoCommits)
 
 			require.Equal(t, len(tt.want.Assets), len(opts.Assets))
 			for i := range tt.want.Assets {
@@ -460,6 +476,100 @@ func Test_createRun(t *testing.T) {
 			wantStdout: "https://github.com/OWNER/REPO/releases/tag/v1.2.3\n",
 			wantStderr: ``,
 		},
+		{
+			name:  "create a release if there are new commits and the last release does not exist",
+			isTTY: true,
+			opts: CreateOptions{
+				TagName:         "v1.2.3",
+				Name:            "The Big 1.2",
+				Body:            "* Fixed bugs",
+				BodyProvided:    true,
+				Target:          "",
+				FailOnNoCommits: true,
+			},
+			runStubs: defaultRunStubs,
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				reg.Register(httpmock.REST("GET", "repos/OWNER/REPO/releases/latest"), httpmock.StatusStringResponse(404, `{
+					"message": "Not Found",
+					"documentation_url": "https://docs.github.com/rest/releases/releases#get-the-latest-release",
+					"status": "404"
+				}`))
+				reg.Register(httpmock.REST("POST", "repos/OWNER/REPO/releases"), httpmock.RESTPayload(201, `{
+					"url": "https://api.github.com/releases/123",
+					"upload_url": "https://api.github.com/assets/upload",
+					"html_url": "https://github.com/OWNER/REPO/releases/tag/v1.2.3"
+				}`, func(params map[string]interface{}) {
+					assert.Equal(t, map[string]interface{}{
+						"tag_name":   "v1.2.3",
+						"name":       "The Big 1.2",
+						"body":       "* Fixed bugs",
+						"draft":      false,
+						"prerelease": false,
+					}, params)
+				}))
+			},
+			wantStdout: "https://github.com/OWNER/REPO/releases/tag/v1.2.3\n",
+			wantStderr: ``,
+		},
+		{
+			name:  "create a release if there are new commits and the last release exists",
+			isTTY: true,
+			opts: CreateOptions{
+				TagName:         "v1.2.3",
+				Name:            "The Big 1.2",
+				Body:            "* Fixed bugs",
+				BodyProvided:    true,
+				Target:          "",
+				FailOnNoCommits: true,
+			},
+			runStubs: defaultRunStubs,
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				reg.Register(httpmock.REST("GET", "repos/OWNER/REPO/releases/latest"), httpmock.StatusStringResponse(200, `{
+					"tag_name": "v1.2.2"
+				}`))
+				reg.Register(httpmock.REST("GET", "repos/OWNER/REPO/compare/v1.2.2...HEAD"), httpmock.StatusStringResponse(200, `{
+						"status": "ahead"
+				}`))
+				reg.Register(httpmock.REST("POST", "repos/OWNER/REPO/releases"), httpmock.RESTPayload(201, `{
+					"url": "https://api.github.com/releases/123",
+					"upload_url": "https://api.github.com/assets/upload",
+					"html_url": "https://github.com/OWNER/REPO/releases/tag/v1.2.3"
+				}`, func(params map[string]interface{}) {
+					assert.Equal(t, map[string]interface{}{
+						"tag_name":   "v1.2.3",
+						"name":       "The Big 1.2",
+						"body":       "* Fixed bugs",
+						"draft":      false,
+						"prerelease": false,
+					}, params)
+				}))
+			},
+			wantStdout: "https://github.com/OWNER/REPO/releases/tag/v1.2.3\n",
+			wantStderr: ``,
+		},
+		{
+			name:  "create a release if there are no new commits but the last release exists",
+			isTTY: true,
+			opts: CreateOptions{
+				TagName:         "v1.2.3",
+				Name:            "The Big 1.2",
+				Body:            "* Fixed bugs",
+				BodyProvided:    true,
+				Target:          "",
+				FailOnNoCommits: true,
+			},
+			httpStubs: func(t *testing.T, reg *httpmock.Registry) {
+				reg.Register(httpmock.REST("GET", "repos/OWNER/REPO/releases/latest"), httpmock.StatusStringResponse(200, `{
+					"tag_name": "v1.2.2"
+				}`))
+				reg.Register(httpmock.REST("GET", "repos/OWNER/REPO/compare/v1.2.2...HEAD"), httpmock.StatusStringResponse(200, `{
+					"status": "identical"
+				}`))
+			},
+			wantErr:    "no new commits since the last release",
+			wantStdout: "",
+			wantStderr: ``,
+		},
 		{
 			name:  "with discussion category",
 			isTTY: true,
diff --git a/pkg/cmd/release/view/view_test.go b/pkg/cmd/release/view/view_test.go
--- a/pkg/cmd/release/view/view_test.go
+++ b/pkg/cmd/release/view/view_test.go
@@ -144,15 +144,15 @@ func Test_viewRun(t *testing.T) {
 			wantStdout: heredoc.Doc(`
 				v1.2.3
 				MonaLisa released this about 1 day ago
-				
+
 				                                                                                  
 				  • Fixed bugs                                                                    
-				
-				
+
+
 				Assets
 				windows.zip  12 B
 				linux.tgz    34 B
-				
+
 				View on GitHub: https://github.com/OWNER/REPO/releases/tags/v1.2.3
 			`),
 			wantStderr: ``,
@@ -168,15 +168,15 @@ func Test_viewRun(t *testing.T) {
 			wantStdout: heredoc.Doc(`
 				v1.2.3
 				MonaLisa released this about 1 day ago
-				
+
 				                                                                                  
 				  • Fixed bugs                                                                    
-				
-				
+
+
 				Assets
 				windows.zip  12 B
 				linux.tgz    34 B
-				
+
 				View on GitHub: https://github.com/OWNER/REPO/releases/tags/v1.2.3
 			`),
 			wantStderr: ``,
diff --git a/pkg/cmd/repo/license/view/view_test.go b/pkg/cmd/repo/license/view/view_test.go
--- a/pkg/cmd/repo/license/view/view_test.go
+++ b/pkg/cmd/repo/license/view/view_test.go
@@ -220,7 +220,7 @@ func TestViewRun(t *testing.T) {
 			wantErr: true,
 			errMsg: heredoc.Docf(`
 				'404' is not a valid license name or SPDX ID.
-				
+
 				Run %[1]sgh repo license list%[1]s to see available commonly used licenses. For even more licenses, visit https://choosealicense.com/appendix`, "`"),
 			httpStubs: func(reg *httpmock.Registry) {
 				reg.Register(
diff --git a/pkg/cmd/repo/rename/rename_test.go b/pkg/cmd/repo/rename/rename_test.go
--- a/pkg/cmd/repo/rename/rename_test.go
+++ b/pkg/cmd/repo/rename/rename_test.go
@@ -227,7 +227,7 @@ func TestRenameRun(t *testing.T) {
 				newRepoSelector: "org/new-name",
 			},
 			wantErr: true,
-			errMsg:  "New repository name cannot contain '/' character - to transfer a repository to a new owner, you must follow additional steps on GitHub.com. For more information on transferring repository ownership, see <https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository>.",
+			errMsg:  "New repository name cannot contain '/' character - to transfer a repository to a new owner, you must follow additional steps on <github.com>. For more information on transferring repository ownership, see <https://docs.github.com/en/repositories/creating-and-managing-repositories/transferring-a-repository>.",
 		},
 	}
 
diff --git a/pkg/cmd/repo/setdefault/setdefault_test.go b/pkg/cmd/repo/setdefault/setdefault_test.go
--- a/pkg/cmd/repo/setdefault/setdefault_test.go
+++ b/pkg/cmd/repo/setdefault/setdefault_test.go
@@ -176,7 +176,7 @@ func TestDefaultRun(t *testing.T) {
 					Repo:   repo1,
 				},
 			},
-			wantStderr: "no default repository has been set; use `gh repo set-default` to select one\n",
+			wantStderr: "X No default remote repository has been set. To learn more about the default repository, run: gh repo set-default --help\n",
 		},
 		{
 			name: "view mode no current default",
@@ -188,7 +188,7 @@ func TestDefaultRun(t *testing.T) {
 					Repo:   repo1,
 				},
 			},
-			wantStderr: "no default repository has been set; use `gh repo set-default` to select one\n",
+			wantStderr: "X No default remote repository has been set. To learn more about the default repository, run: gh repo set-default --help\n",
 		},
 		{
 			name: "view mode with base resolved current default",
diff --git a/pkg/cmd/ruleset/view/view_test.go b/pkg/cmd/ruleset/view/view_test.go
--- a/pkg/cmd/ruleset/view/view_test.go
+++ b/pkg/cmd/ruleset/view/view_test.go
@@ -158,14 +158,14 @@ func Test_viewRun(t *testing.T) {
 	Source: my-owner/repo-name (Repository)
 	Enforcement: Active
 	You can bypass: pull requests only
-	
+
 	Bypass List
 	- OrganizationAdmin (ID: 1), mode: always
 	- RepositoryRole (ID: 5), mode: always
-	
+
 	Conditions
 	- ref_name: [exclude: []] [include: [~ALL]] 
-	
+
 	Rules
 	- commit_author_email_pattern: [name: ] [negate: false] [operator: ends_with] [pattern: @example.com] 
 	- commit_message_pattern: [name: ] [negate: false] [operator: contains] [pattern: asdf] 
@@ -212,14 +212,14 @@ func Test_viewRun(t *testing.T) {
 			ID: 74
 			Source: my-owner (Organization)
 			Enforcement: Evaluate Mode (not enforced)
-			
+
 			Bypass List
 			This ruleset cannot be bypassed
-			
+
 			Conditions
 			- ref_name: [exclude: []] [include: [~ALL]] 
 			- repository_name: [exclude: []] [include: [~ALL]] [protected: true] 
-			
+
 			Rules
 			- commit_author_email_pattern: [name: ] [negate: false] [operator: ends_with] [pattern: @example.com] 
 			- commit_message_pattern: [name: ] [negate: false] [operator: contains] [pattern: asdf] 
diff --git a/pkg/cmd/workflow/shared/shared_test.go b/pkg/cmd/workflow/shared/shared_test.go
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/workflow/shared/shared_test.go
@@ -0,0 +1,422 @@
+package shared
+
+import (
+	"errors"
+	"fmt"
+	"net/http"
+	"net/url"
+	"strings"
+	"testing"
+
+	"github.com/cli/cli/v2/api"
+	"github.com/cli/cli/v2/internal/ghrepo"
+	"github.com/cli/cli/v2/pkg/httpmock"
+	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
+
+	ghAPI "github.com/cli/go-gh/v2/pkg/api"
+)
+
+func TestFindWorkflow(t *testing.T) {
+	badRequestURL, err := url.Parse("https://api.github.com/repos/OWNER/REPO/actions/workflows/nonexistentWorkflow.yml")
+	if err != nil {
+		t.Fatal(err)
+	}
+
+	tests := []struct {
+		name              string
+		workflowSelector  string
+		repo              ghrepo.Interface
+		httpStubs         func(*httpmock.Registry)
+		states            []WorkflowState
+		expectedWorkflow  Workflow
+		expectedHTTPError *api.HTTPError
+		expectedError     error
+	}{
+		{
+			name:             "When the workflow selector is empty, it returns an error",
+			workflowSelector: "",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			expectedError:    errors.New("empty workflow selector"),
+		},
+		{
+			name:             "When the workflow selector is a number, it returns the workflow with that ID",
+			workflowSelector: "1",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows/1"),
+					httpmock.StatusJSONResponse(200, Workflow{
+						ID: 1,
+					}),
+				)
+			},
+			expectedWorkflow: Workflow{
+				ID: 1,
+			},
+		},
+		{
+			name:             "When the workflow selector is a file, it returns the workflow with that path",
+			workflowSelector: "workflowFile.yml",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows/workflowFile.yml"),
+					httpmock.StatusJSONResponse(200, Workflow{
+						ID:   1,
+						Name: "Some Workflow",
+						Path: ".github/workflows/workflowFile.yml",
+					}),
+				)
+			},
+			expectedWorkflow: Workflow{
+				ID:   1,
+				Name: "Some Workflow",
+				Path: ".github/workflows/workflowFile.yml",
+			},
+		},
+		{
+			name:             "When the workflow selector is a workflow that doesn't exist, it returns the workflow not found error",
+			workflowSelector: "nonexistentWorkflow.yml",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", strings.TrimPrefix(badRequestURL.Path, "/")),
+					httpmock.StatusJSONResponse(404, Workflow{}),
+				)
+			},
+			expectedHTTPError: &api.HTTPError{
+				HTTPError: &ghAPI.HTTPError{
+					Message:    "workflow nonexistentWorkflow.yml not found on the default branch",
+					StatusCode: 404,
+					RequestURL: badRequestURL,
+				},
+			},
+		},
+		{
+			name:             "When the workflow selector is a file but the server errors, it returns that error",
+			workflowSelector: "nonexistentWorkflow.yml",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", strings.TrimPrefix(badRequestURL.Path, "/")),
+					httpmock.StatusStringResponse(500, "server error"),
+				)
+			},
+			expectedHTTPError: &api.HTTPError{
+				HTTPError: &ghAPI.HTTPError{
+					Errors: []ghAPI.HTTPErrorItem{
+						{
+							Message: "server error",
+						},
+					},
+					StatusCode: 500,
+					RequestURL: badRequestURL,
+				},
+			},
+		},
+		{
+			name:             "When the workflow selector is a name and the state is active, it returns that workflow",
+			workflowSelector: "Workflow Name",
+			repo:             ghrepo.New("OWNER", "REPO"),
+			states:           []WorkflowState{Active},
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: []Workflow{
+							{
+								ID:    1,
+								Name:  "Workflow Name",
+								State: Active,
+							},
+						}}),
+				)
+			},
+			expectedWorkflow: Workflow{
+				ID:    1,
+				Name:  "Workflow Name",
+				State: "active",
+			},
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			reg := &httpmock.Registry{}
+			if tt.httpStubs != nil {
+				tt.httpStubs(reg)
+			}
+			client := api.NewClientFromHTTP(&http.Client{Transport: reg})
+
+			workflow, err := FindWorkflow(client, tt.repo, tt.workflowSelector, tt.states)
+			if tt.expectedError != nil {
+				require.Error(t, err)
+				assert.Equal(t, tt.expectedError, err)
+			} else if tt.expectedHTTPError != nil {
+				var httpErr api.HTTPError
+				require.ErrorAs(t, err, &httpErr)
+				assert.Equal(t, tt.expectedHTTPError.Error(), httpErr.Error())
+			} else {
+				require.NoError(t, err)
+				assert.Equal(t, tt.expectedWorkflow, workflow[0])
+			}
+		})
+	}
+}
+
+type ErrorTransport struct {
+	Err error
+}
+
+func (t *ErrorTransport) RoundTrip(req *http.Request) (*http.Response, error) {
+	return nil, t.Err
+}
+
+func TestFindWorkflow_nonHTTPError(t *testing.T) {
+	t.Run("When the client fails to instantiate, it returns the error", func(t *testing.T) {
+		client := api.NewClientFromHTTP(&http.Client{Transport: &ErrorTransport{Err: errors.New("non-HTTP error")}})
+		repo := ghrepo.New("OWNER", "REPO")
+		workflow, err := FindWorkflow(client, repo, "1", nil)
+
+		require.Error(t, err)
+		assert.ErrorContains(t, err, "non-HTTP error")
+		assert.Nil(t, workflow)
+	})
+}
+
+func Test_getWorkflowsByName_filtering(t *testing.T) {
+	tests := []struct {
+		name              string
+		workflowName      string
+		repo              ghrepo.Interface
+		states            []WorkflowState
+		httpStubs         func(*httpmock.Registry)
+		expectedWorkflows []Workflow
+		expectedErrorMsg  string
+	}{
+		{
+			name:         "When no workflows match, no workflows are returned",
+			workflowName: "Unmatched Workflow Name",
+			repo:         ghrepo.New("OWNER", "REPO"),
+			states:       []WorkflowState{Active},
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: []Workflow{
+							{
+								ID:    1,
+								Name:  "Workflow Name",
+								State: Active,
+							},
+							{
+								ID:    2,
+								Name:  "Workflow Name",
+								State: DisabledInactivity,
+							},
+							{
+								ID:    3,
+								Name:  "Workflow Name",
+								State: Active,
+							},
+						},
+					}),
+				)
+			},
+			expectedWorkflows: []Workflow(nil),
+		},
+		{
+			name:         "When there are more than one workflow with the same name, only the ones matching the provided state are returned",
+			workflowName: "Workflow Name",
+			repo:         ghrepo.New("OWNER", "REPO"),
+			states:       []WorkflowState{Active},
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: []Workflow{
+							{
+								ID:    1,
+								Name:  "Workflow Name",
+								State: Active,
+							},
+							{
+								ID:    2,
+								Name:  "Workflow Name",
+								State: DisabledInactivity,
+							},
+							{
+								ID:    3,
+								Name:  "Workflow Name",
+								State: Active,
+							},
+						},
+					}),
+				)
+			},
+			expectedWorkflows: []Workflow{
+				{
+					ID:    1,
+					Name:  "Workflow Name",
+					State: Active,
+				},
+				{
+					ID:    3,
+					Name:  "Workflow Name",
+					State: Active,
+				},
+			},
+		},
+		{
+			name: "When GetWorkflows errors",
+			repo: ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusStringResponse(500, ""),
+				)
+			},
+			expectedErrorMsg: "couldn't fetch workflows for OWNER/REPO",
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			reg := &httpmock.Registry{}
+			if tt.httpStubs != nil {
+				tt.httpStubs(reg)
+			}
+			client := api.NewClientFromHTTP(&http.Client{Transport: reg})
+
+			workflows, err := getWorkflowsByName(client, tt.repo, tt.workflowName, tt.states)
+			if tt.expectedErrorMsg != "" {
+				require.Error(t, err)
+				assert.ErrorContains(t, err, tt.expectedErrorMsg)
+			} else {
+				require.NoError(t, err)
+				assert.Equal(t, tt.expectedWorkflows, workflows)
+			}
+		})
+	}
+}
+
+func TestGetWorkflows(t *testing.T) {
+	tests := []struct {
+		name              string
+		repo              ghrepo.Interface
+		limit             int
+		httpStubs         func(*httpmock.Registry)
+		expectedWorkflows []Workflow
+		expectedError     error
+	}{
+		{
+			name: "When the repo has no workflows, it returns an empty slice",
+			repo: ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: []Workflow{},
+					}),
+				)
+			},
+			expectedWorkflows: []Workflow{},
+		},
+		{
+			name: "When the api returns workflows, it returns those workflows",
+			repo: ghrepo.New("OWNER", "REPO"),
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: []Workflow{
+							{
+								Name: "Workflow 1",
+							},
+							{
+								Name: "Workflow 2",
+							},
+						},
+					}),
+				)
+			},
+			expectedWorkflows: []Workflow{
+				{
+					Name: "Workflow 1",
+				},
+				{
+					Name: "Workflow 2",
+				},
+			},
+		},
+		{
+			name:  "When the api return paginates, it returns the workflows from all the pages",
+			repo:  ghrepo.New("OWNER", "REPO"),
+			limit: 0,
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: generateWorkflows(t, 100, 1),
+					}),
+				)
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: generateWorkflows(t, 50, 2),
+					}),
+				)
+			},
+			expectedWorkflows: append(generateWorkflows(t, 100, 1), generateWorkflows(t, 50, 2)...),
+		},
+		{
+			name:  "When the limit is set to fewer workflows than the api returns, it returns the number of workflows specified by the limit",
+			repo:  ghrepo.New("OWNER", "REPO"),
+			limit: 2,
+			httpStubs: func(reg *httpmock.Registry) {
+				reg.Register(
+					httpmock.REST("GET", "repos/OWNER/REPO/actions/workflows"),
+					httpmock.StatusJSONResponse(200, WorkflowsPayload{
+						Workflows: generateWorkflows(t, 100, 1),
+					}),
+				)
+			},
+			expectedWorkflows: generateWorkflows(t, 2, 1),
+		},
+	}
+
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			reg := &httpmock.Registry{}
+			if tt.httpStubs != nil {
+				tt.httpStubs(reg)
+			}
+			client := api.NewClientFromHTTP(&http.Client{Transport: reg})
+
+			workflows, err := GetWorkflows(client, tt.repo, tt.limit)
+			if tt.expectedError != nil {
+				require.Error(t, err)
+				assert.Equal(t, tt.expectedError, err)
+			} else {
+				require.NoError(t, err)
+				assert.Equal(t, tt.expectedWorkflows, workflows)
+			}
+		})
+	}
+}
+
+// generateWorkflows returns an slice of workflows with the given count, labeled
+// with the page number of testing pagination.
+// The page number is used to generate unique Names and IDs for each workflow.
+func generateWorkflows(t *testing.T, workflowCount int, pageNum int) []Workflow {
+	t.Helper()
+	workflows := []Workflow{}
+	for i := 0; i < workflowCount; i++ {
+		workflows = append(workflows, Workflow{
+			Name: fmt.Sprintf("Workflow-%d-%d", pageNum, i),
+			ID:   int64(i) + int64(pageNum-1)*100,
+		})
+	}
+	return workflows
+}
EOF_114329324912

# Run the tests
# First, run unit tests (non-integration tests)
go test -v \
    ./pkg/cmd/api/... \
    ./pkg/cmd/cache/delete/... \
    ./pkg/cmd/factory/... \
    ./pkg/cmd/gist/list/... \
    ./pkg/cmd/issue/comment/... \
    ./pkg/cmd/label/... \
    ./pkg/cmd/pr/checkout/... \
    ./pkg/cmd/pr/close/... \
    ./pkg/cmd/pr/comment/... \
    ./pkg/cmd/pr/create/... \
    ./pkg/cmd/project/item-edit/... \
    ./pkg/cmd/release/create/... \
    ./pkg/cmd/release/view/... \
    ./pkg/cmd/repo/license/view/... \
    ./pkg/cmd/repo/rename/... \
    ./pkg/cmd/repo/setdefault/... \
    ./pkg/cmd/ruleset/view/...

unit_rc=$?

# Run integration tests with -tags=integration
go test -v -tags=integration \
    ./pkg/cmd/attestation/verification/... \
    ./pkg/cmd/attestation/verify/...

integration_rc=$?

# Determine overall exit code (fail if either test suite fails)
if [ $unit_rc -ne 0 ] || [ $integration_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 4daf489c7515e1145be30727bb12b732c5c533e0 \
    "pkg/cmd/api/api_test.go" \
    "pkg/cmd/attestation/api/mock_httpClient_test.go" \
    "pkg/cmd/attestation/download/download.go" \
    "pkg/cmd/attestation/inspect/inspect.go" \
    "pkg/cmd/attestation/trustedroot/trustedroot.go" \
    "pkg/cmd/attestation/verification/extensions.go" \
    "pkg/cmd/attestation/verification/policy.go" \
    "pkg/cmd/attestation/verification/sigstore.go" \
    "pkg/cmd/attestation/verification/sigstore_integration_test.go" \
    "pkg/cmd/attestation/verification/tuf.go" \
    "pkg/cmd/attestation/verification/tuf_test.go" \
    "pkg/cmd/attestation/verify/attestation_integration_test.go" \
    "pkg/cmd/attestation/verify/options.go" \
    "pkg/cmd/attestation/verify/policy.go" \
    "pkg/cmd/attestation/verify/policy_test.go" \
    "pkg/cmd/attestation/verify/verify.go" \
    "pkg/cmd/attestation/verify/verify_integration_test.go" \
    "pkg/cmd/cache/delete/delete_test.go" \
    "pkg/cmd/factory/remote_resolver_test.go" \
    "pkg/cmd/gist/list/list_test.go" \
    "pkg/cmd/issue/comment/comment_test.go" \
    "pkg/cmd/label/list_test.go" \
    "pkg/cmd/pr/checkout/checkout_test.go" \
    "pkg/cmd/pr/close/close_test.go" \
    "pkg/cmd/pr/comment/comment_test.go" \
    "pkg/cmd/pr/create/create_test.go" \
    "pkg/cmd/project/item-edit/item_edit_test.go" \
    "pkg/cmd/release/create/create_test.go" \
    "pkg/cmd/release/view/view_test.go" \
    "pkg/cmd/repo/license/view/view_test.go" \
    "pkg/cmd/repo/rename/rename_test.go" \
    "pkg/cmd/repo/setdefault/setdefault_test.go" \
    "pkg/cmd/ruleset/view/view_test.go"