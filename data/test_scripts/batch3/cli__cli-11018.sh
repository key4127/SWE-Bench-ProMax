#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit to ensure clean state
git checkout d7d9228609e555b5541088e56c8f25bbbe1177db

# Checkout the specific files to ensure they're in the correct state
git checkout d7d9228609e555b5541088e56c8f25bbbe1177db \
    "pkg/cmd/attestation/artifact/file.go" \
    "pkg/cmd/release/shared/attestation.go" \
    "pkg/cmd/release/shared/options_test.go" \
    "pkg/cmd/release/shared/policy_test.go" \
    "pkg/cmd/release/verify-asset/verify-asset_test.go" \
    "pkg/cmd/release/verify/verify_test.go"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pkg/cmd/attestation/artifact/file.go b/pkg/cmd/attestation/artifact/file.go
--- a/pkg/cmd/attestation/artifact/file.go
+++ b/pkg/cmd/attestation/artifact/file.go
@@ -10,7 +10,7 @@ import (
 func digestLocalFileArtifact(filename, digestAlg string) (*DigestedArtifact, error) {
 	data, err := os.Open(filename)
 	if err != nil {
-		return nil, fmt.Errorf("failed to get open local artifact: %v", err)
+		return nil, fmt.Errorf("failed to open local artifact: %v", err)
 	}
 	defer data.Close()
 	digest, err := digest.CalculateDigestWithAlgorithm(data, digestAlg)
diff --git a/pkg/cmd/release/shared/attestation.go b/pkg/cmd/release/shared/attestation.go
--- a/pkg/cmd/release/shared/attestation.go
+++ b/pkg/cmd/release/shared/attestation.go
@@ -1,56 +1,58 @@
 package shared
 
 import (
-	"errors"
 	"fmt"
+	"net/http"
 
-	"github.com/cli/cli/v2/internal/text"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/api"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/artifact"
+	att_io "github.com/cli/cli/v2/pkg/cmd/attestation/io"
+	"github.com/cli/cli/v2/pkg/cmd/attestation/test/data"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
+	"github.com/cli/cli/v2/pkg/iostreams"
+	"github.com/sigstore/sigstore-go/pkg/fulcio/certificate"
+	"github.com/sigstore/sigstore-go/pkg/verify"
 
 	v1 "github.com/in-toto/attestation/go/v1"
 	"google.golang.org/protobuf/encoding/protojson"
 )
 
-func GetAttestations(o *AttestOptions, sha string) ([]*api.Attestation, string, error) {
-	if o.APIClient == nil {
-		errMsg := "X No APIClient provided"
-		return nil, errMsg, errors.New(errMsg)
-	}
+const ReleasePredicateType = "https://in-toto.io/attestation/release/v0.1"
 
-	params := api.FetchParams{
-		Digest:        sha,
-		Limit:         o.Limit,
-		Owner:         o.Owner,
-		PredicateType: o.PredicateType,
-		Repo:          o.Repo,
-	}
+type Verifier interface {
+	// VerifyAttestation verifies the attestation for a given artifact
+	VerifyAttestation(art *artifact.DigestedArtifact, att *api.Attestation) (*verification.AttestationProcessingResult, error)
+}
+
+type AttestationVerifier struct {
+	AttClient  api.Client
+	HttpClient *http.Client
+	IO         *iostreams.IOStreams
+}
 
-	attestations, err := o.APIClient.GetByDigest(params)
+func (v *AttestationVerifier) VerifyAttestation(art *artifact.DigestedArtifact, att *api.Attestation) (*verification.AttestationProcessingResult, error) {
+	td, err := v.AttClient.GetTrustDomain()
 	if err != nil {
-		msg := "X Loading attestations from GitHub API failed"
-		return nil, msg, err
+		return nil, err
 	}
-	pluralAttestation := text.Pluralize(len(attestations), "attestation")
-	msg := fmt.Sprintf("Loaded %s from GitHub API", pluralAttestation)
-	return attestations, msg, nil
-}
 
-func VerifyAttestations(art artifact.DigestedArtifact, att []*api.Attestation, sgVerifier verification.SigstoreVerifier, ec verification.EnforcementCriteria) ([]*verification.AttestationProcessingResult, string, error) {
-	sgPolicy, err := buildSigstoreVerifyPolicy(ec, art)
+	verifier, err := verification.NewLiveSigstoreVerifier(verification.SigstoreConfig{
+		HttpClient:   v.HttpClient,
+		Logger:       att_io.NewHandler(v.IO),
+		NoPublicGood: true,
+		TrustDomain:  td,
+	})
 	if err != nil {
-		logMsg := "X Failed to build Sigstore verification policy"
-		return nil, logMsg, err
+		return nil, err
 	}
 
-	sigstoreVerified, err := sgVerifier.Verify(att, sgPolicy)
+	policy := buildVerificationPolicy(*art)
+	sigstoreVerified, err := verifier.Verify([]*api.Attestation{att}, policy)
 	if err != nil {
-		logMsg := "X Sigstore verification failed"
-		return nil, logMsg, err
+		return nil, err
 	}
 
-	return sigstoreVerified, "", nil
+	return sigstoreVerified[0], nil
 }
 
 func FilterAttestationsByTag(attestations []*api.Attestation, tagName string) ([]*api.Attestation, error) {
@@ -71,7 +73,7 @@ func FilterAttestationsByTag(attestations []*api.Attestation, tagName string) ([
 	return filtered, nil
 }
 
-func FilterAttestationsByFileDigest(attestations []*api.Attestation, repo, tagName, fileDigest string) ([]*api.Attestation, error) {
+func FilterAttestationsByFileDigest(attestations []*api.Attestation, fileDigest string) ([]*api.Attestation, error) {
 	var filtered []*api.Attestation
 	for _, att := range attestations {
 		statement := att.Bundle.Bundle.GetDsseEnvelope().Payload
@@ -95,3 +97,32 @@ func FilterAttestationsByFileDigest(attestations []*api.Attestation, repo, tagNa
 	}
 	return filtered, nil
 }
+
+// buildVerificationPolicy constructs a verification policy for GitHub releases
+func buildVerificationPolicy(a artifact.DigestedArtifact) verify.PolicyBuilder {
+	// SAN must match the GitHub releases domain. No issuer extension (match anything)
+	sanMatcher, _ := verify.NewSANMatcher("", "^https://.*\\.releases\\.github\\.com$")
+	issuerMatcher, _ := verify.NewIssuerMatcher("", ".*")
+	certId, _ := verify.NewCertificateIdentity(sanMatcher, issuerMatcher, certificate.Extensions{})
+
+	artifactDigestPolicyOption, _ := verification.BuildDigestPolicyOption(a)
+	return verify.NewPolicy(artifactDigestPolicyOption, verify.WithCertificateIdentity(certId))
+}
+
+type MockVerifier struct {
+	mockResult *verification.AttestationProcessingResult
+}
+
+func NewMockVerifier(mockResult *verification.AttestationProcessingResult) *MockVerifier {
+	return &MockVerifier{mockResult: mockResult}
+}
+
+func (v *MockVerifier) VerifyAttestation(art *artifact.DigestedArtifact, att *api.Attestation) (*verification.AttestationProcessingResult, error) {
+	return &verification.AttestationProcessingResult{
+		Attestation: &api.Attestation{
+			Bundle:    data.GitHubReleaseBundle(nil),
+			BundleURL: "https://example.com",
+		},
+		VerificationResult: nil,
+	}, nil
+}
diff --git a/pkg/cmd/release/shared/options_test.go b/pkg/cmd/release/shared/options_test.go
deleted file mode 100644
--- a/pkg/cmd/release/shared/options_test.go
+++ /dev/null
@@ -1,60 +0,0 @@
-package shared
-
-import (
-	"errors"
-	"testing"
-)
-
-func TestAttestOptions_AreFlagsValid_Valid(t *testing.T) {
-	opts := &AttestOptions{
-		Repo:  "owner/repo",
-		Limit: 10,
-	}
-	if err := opts.AreFlagsValid(); err != nil {
-		t.Errorf("expected no error, got %v", err)
-	}
-}
-
-func TestAttestOptions_AreFlagsValid_InvalidRepo(t *testing.T) {
-	opts := &AttestOptions{
-		Repo: "invalidrepo",
-	}
-	err := opts.AreFlagsValid()
-	if err == nil || !errors.Is(err, err) {
-		t.Errorf("expected error for invalid repo, got %v", err)
-	}
-}
-
-func TestAttestOptions_AreFlagsValid_LimitTooLow(t *testing.T) {
-	opts := &AttestOptions{
-		Repo:  "owner/repo",
-		Limit: 0,
-	}
-	err := opts.AreFlagsValid()
-	if err == nil || !errors.Is(err, err) {
-		t.Errorf("expected error for limit too low, got %v", err)
-	}
-}
-
-func TestAttestOptions_AreFlagsValid_LimitTooHigh(t *testing.T) {
-	opts := &AttestOptions{
-		Repo:  "owner/repo",
-		Limit: 1001,
-	}
-	err := opts.AreFlagsValid()
-	if err == nil || !errors.Is(err, err) {
-		t.Errorf("expected error for limit too high, got %v", err)
-	}
-}
-
-func TestAttestOptions_AreFlagsValid_ValidHostname(t *testing.T) {
-	opts := &AttestOptions{
-		Repo:     "owner/repo",
-		Limit:    10,
-		Hostname: "github.com",
-	}
-	err := opts.AreFlagsValid()
-	if err != nil {
-		t.Errorf("expected no error for valid hostname, got %v", err)
-	}
-}
diff --git a/pkg/cmd/release/shared/policy_test.go b/pkg/cmd/release/shared/policy_test.go
deleted file mode 100644
--- a/pkg/cmd/release/shared/policy_test.go
+++ /dev/null
@@ -1,71 +0,0 @@
-package shared
-
-import (
-	"testing"
-
-	"github.com/stretchr/testify/require"
-)
-
-func TestNewEnforcementCriteria(t *testing.T) {
-	t.Run("check SAN", func(t *testing.T) {
-		opts := &AttestOptions{
-			Owner:         "foo",
-			Repo:          "foo/bar",
-			PredicateType: "https://in-toto.io/attestation/release/v0.1",
-		}
-
-		c, err := NewEnforcementCriteria(opts)
-		require.NoError(t, err)
-		require.Equal(t, "https://dotcom.releases.github.com", c.SAN)
-		require.Equal(t, "https://in-toto.io/attestation/release/v0.1", c.PredicateType)
-	})
-
-	t.Run("sets Extensions.SourceRepositoryURI using opts.Repo and opts.Tenant", func(t *testing.T) {
-		opts := &AttestOptions{
-			Owner:  "foo",
-			Repo:   "foo/bar",
-			Tenant: "baz",
-		}
-
-		c, err := NewEnforcementCriteria(opts)
-		require.NoError(t, err)
-		require.Equal(t, "https://baz.ghe.com/foo/bar", c.Certificate.SourceRepositoryURI)
-	})
-
-	t.Run("sets Extensions.SourceRepositoryURI using opts.Repo", func(t *testing.T) {
-		opts := &AttestOptions{
-			Owner: "foo",
-			Repo:  "foo/bar",
-		}
-
-		c, err := NewEnforcementCriteria(opts)
-		require.NoError(t, err)
-		require.Equal(t, "https://github.com/foo/bar", c.Certificate.SourceRepositoryURI)
-	})
-
-	t.Run("sets Extensions.SourceRepositoryOwnerURI using opts.Owner and opts.Tenant", func(t *testing.T) {
-		opts := &AttestOptions{
-
-			Owner:  "foo",
-			Repo:   "foo/bar",
-			Tenant: "baz",
-		}
-
-		c, err := NewEnforcementCriteria(opts)
-		require.NoError(t, err)
-		require.Equal(t, "https://baz.ghe.com/foo", c.Certificate.SourceRepositoryOwnerURI)
-	})
-
-	t.Run("sets Extensions.SourceRepositoryOwnerURI using opts.Owner", func(t *testing.T) {
-		opts := &AttestOptions{
-
-			Owner: "foo",
-			Repo:  "foo/bar",
-		}
-
-		c, err := NewEnforcementCriteria(opts)
-		require.NoError(t, err)
-		require.Equal(t, "https://github.com/foo", c.Certificate.SourceRepositoryOwnerURI)
-	})
-
-}
diff --git a/pkg/cmd/release/verify-asset/verify-asset_test.go b/pkg/cmd/release/verify-asset/verify-asset_test.go
deleted file mode 100644
--- a/pkg/cmd/release/verify-asset/verify-asset_test.go
+++ /dev/null
@@ -1,230 +0,0 @@
-package verifyasset
-
-import (
-	"bytes"
-	"net/http"
-	"testing"
-
-	"github.com/cli/cli/v2/pkg/cmd/attestation/api"
-	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
-	"github.com/cli/cli/v2/pkg/cmd/attestation/test"
-	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
-	"github.com/cli/cli/v2/pkg/cmd/release/shared"
-	"github.com/cli/cli/v2/pkg/cmdutil"
-	"github.com/cli/cli/v2/pkg/iostreams"
-	"github.com/stretchr/testify/assert"
-	"github.com/stretchr/testify/require"
-
-	"github.com/cli/cli/v2/internal/ghrepo"
-
-	attestation "github.com/cli/cli/v2/pkg/cmd/release/shared"
-	"github.com/cli/cli/v2/pkg/httpmock"
-)
-
-func TestNewCmdVerifyAsset_Args(t *testing.T) {
-	tests := []struct {
-		name     string
-		args     []string
-		wantTag  string
-		wantFile string
-		wantErr  string
-	}{
-		{
-			name:     "valid args",
-			args:     []string{"v1.2.3", "../../attestation/test/data/github_release_artifact.zip"},
-			wantTag:  "v1.2.3",
-			wantFile: test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
-		},
-		{
-			name: "valid flag with no tag",
-
-			args:     []string{"../../attestation/test/data/github_release_artifact.zip"},
-			wantFile: test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
-		},
-		{
-			name:    "no args",
-			args:    []string{},
-			wantErr: "you must specify an asset filepath",
-		},
-	}
-	for _, tt := range tests {
-		t.Run(tt.name, func(t *testing.T) {
-			testIO, _, _, _ := iostreams.Test()
-			var testReg httpmock.Registry
-			var metaResp = api.MetaResponse{
-				Domains: api.Domain{
-					ArtifactAttestations: api.ArtifactAttestations{},
-				},
-			}
-			testReg.Register(httpmock.REST(http.MethodGet, "meta"),
-				httpmock.StatusJSONResponse(200, &metaResp))
-
-			f := &cmdutil.Factory{
-				IOStreams: testIO,
-				HttpClient: func() (*http.Client, error) {
-					reg := &testReg
-					client := &http.Client{}
-					httpmock.ReplaceTripper(client, reg)
-					return client, nil
-				},
-				BaseRepo: func() (ghrepo.Interface, error) {
-					return ghrepo.FromFullName("owner/repo")
-				},
-			}
-
-			var opts *shared.AttestOptions
-			cmd := NewCmdVerifyAsset(f, func(o *shared.AttestOptions) error {
-				opts = o
-				return nil
-			})
-			cmd.SetArgs(tt.args)
-			cmd.SetIn(&bytes.Buffer{})
-			cmd.SetOut(&bytes.Buffer{})
-			cmd.SetErr(&bytes.Buffer{})
-			_, err := cmd.ExecuteC()
-			if tt.wantErr != "" {
-				require.Error(t, err)
-				assert.Contains(t, err.Error(), tt.wantErr)
-			} else {
-				require.NoError(t, err)
-				assert.Equal(t, tt.wantTag, opts.TagName)
-				assert.Equal(t, tt.wantFile, opts.AssetFilePath)
-			}
-		})
-	}
-}
-
-func Test_verifyAssetRun_Success(t *testing.T) {
-	ios, _, _, _ := iostreams.Test()
-	tagName := "v6"
-
-	fakeHTTP := &httpmock.Registry{}
-	defer fakeHTTP.Verify(t)
-	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
-	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
-
-	baseRepo, err := ghrepo.FromFullName("owner/repo")
-	require.NoError(t, err)
-
-	opts := &shared.AttestOptions{
-		TagName:          tagName,
-		AssetFilePath:    test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		PredicateType:    shared.ReleasePredicateType,
-		HttpClient:       &http.Client{Transport: fakeHTTP},
-		BaseRepo:         baseRepo,
-	}
-
-	ec, err := shared.NewEnforcementCriteria(opts)
-	require.NoError(t, err)
-	opts.EC = ec
-	opts.Clean()
-	err = verifyAssetRun(opts)
-	require.NoError(t, err)
-}
-
-func Test_verifyAssetRun_Failed_With_Invalid_tag(t *testing.T) {
-	ios, _, _, _ := iostreams.Test()
-	tagName := "v1"
-
-	fakeHTTP := &httpmock.Registry{}
-	defer fakeHTTP.Verify(t)
-	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
-	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
-
-	baseRepo, err := ghrepo.FromFullName("owner/repo")
-	require.NoError(t, err)
-
-	opts := &attestation.AttestOptions{
-		TagName:          tagName,
-		AssetFilePath:    test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		PredicateType:    attestation.ReleasePredicateType,
-		HttpClient:       &http.Client{Transport: fakeHTTP},
-		BaseRepo:         baseRepo,
-	}
-
-	ec, err := attestation.NewEnforcementCriteria(opts)
-	require.NoError(t, err)
-	opts.EC = ec
-
-	err = verifyAssetRun(opts)
-	require.Error(t, err, "no attestations found for github_release_artifact.zip in release v1")
-}
-
-func Test_verifyAssetRun_Failed_With_Invalid_Artifact(t *testing.T) {
-	ios, _, _, _ := iostreams.Test()
-	tagName := "v6"
-
-	fakeHTTP := &httpmock.Registry{}
-	defer fakeHTTP.Verify(t)
-	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
-	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
-
-	baseRepo, err := ghrepo.FromFullName("owner/repo")
-	require.NoError(t, err)
-
-	opts := &attestation.AttestOptions{
-		TagName:          tagName,
-		AssetFilePath:    test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		PredicateType:    attestation.ReleasePredicateType,
-		HttpClient:       &http.Client{Transport: fakeHTTP},
-		BaseRepo:         baseRepo,
-	}
-
-	err = verifyAssetRun(opts)
-	require.Error(t, err, "no attestations found for github_release_artifact_invalid.zip in release v1.2.3")
-}
-
-func Test_verifyAssetRun_NoAttestation(t *testing.T) {
-	ios, _, _, _ := iostreams.Test()
-	opts := &attestation.AttestOptions{
-		TagName:          "v1.2.3",
-		AssetFilePath:    "artifact.tgz",
-		Repo:             "owner/repo",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		IO:               ios,
-		APIClient:        api.NewTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		PredicateType:    attestation.ReleasePredicateType,
-
-		EC: verification.EnforcementCriteria{},
-	}
-
-	err := verifyAssetRun(opts)
-	require.Error(t, err, "failed to get open local artifact: open artifact.tgz: no such file or director")
-}
-
-func Test_getFileName(t *testing.T) {
-	tests := []struct {
-		input string
-		want  string
-	}{
-		{"foo/bar/baz.txt", "baz.txt"},
-		{"baz.txt", "baz.txt"},
-		{"/tmp/foo.tar.gz", "foo.tar.gz"},
-	}
-	for _, tt := range tests {
-		t.Run(tt.input, func(t *testing.T) {
-			got := getFileName(tt.input)
-			assert.Equal(t, tt.want, got)
-		})
-	}
-}
diff --git a/pkg/cmd/release/verify-asset/verify_asset_test.go b/pkg/cmd/release/verify-asset/verify_asset_test.go
new file mode 100644
--- /dev/null
+++ b/pkg/cmd/release/verify-asset/verify_asset_test.go
@@ -0,0 +1,267 @@
+package verifyasset
+
+import (
+	"bytes"
+	"net/http"
+	"testing"
+
+	"github.com/cli/cli/v2/pkg/cmd/attestation/api"
+	"github.com/cli/cli/v2/pkg/cmd/attestation/test"
+	"github.com/cli/cli/v2/pkg/cmd/attestation/test/data"
+	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
+	"github.com/cli/cli/v2/pkg/cmd/release/shared"
+	"github.com/cli/cli/v2/pkg/cmdutil"
+	"github.com/cli/cli/v2/pkg/httpmock"
+	"github.com/cli/cli/v2/pkg/iostreams"
+	"github.com/stretchr/testify/assert"
+	"github.com/stretchr/testify/require"
+
+	"github.com/cli/cli/v2/internal/ghrepo"
+)
+
+func TestNewCmdVerifyAsset_Args(t *testing.T) {
+	tests := []struct {
+		name     string
+		args     []string
+		wantTag  string
+		wantFile string
+		wantErr  string
+	}{
+		{
+			name:     "valid args",
+			args:     []string{"v1.2.3", "../../attestation/test/data/github_release_artifact.zip"},
+			wantTag:  "v1.2.3",
+			wantFile: test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
+		},
+		{
+			name: "valid flag with no tag",
+
+			args:     []string{"../../attestation/test/data/github_release_artifact.zip"},
+			wantFile: test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip"),
+		},
+		{
+			name:    "no args",
+			args:    []string{},
+			wantErr: "you must specify an asset filepath",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			testIO, _, _, _ := iostreams.Test()
+
+			f := &cmdutil.Factory{
+				IOStreams: testIO,
+				HttpClient: func() (*http.Client, error) {
+					return nil, nil
+				},
+				BaseRepo: func() (ghrepo.Interface, error) {
+					return ghrepo.FromFullName("owner/repo")
+				},
+			}
+
+			var cfg *VerifyAssetConfig
+			cmd := NewCmdVerifyAsset(f, func(c *VerifyAssetConfig) error {
+				cfg = c
+				return nil
+			})
+			cmd.SetArgs(tt.args)
+			cmd.SetIn(&bytes.Buffer{})
+			cmd.SetOut(&bytes.Buffer{})
+			cmd.SetErr(&bytes.Buffer{})
+
+			_, err := cmd.ExecuteC()
+
+			if tt.wantErr != "" {
+				require.Error(t, err)
+				assert.Contains(t, err.Error(), tt.wantErr)
+			} else {
+				require.NoError(t, err)
+				assert.Equal(t, tt.wantTag, cfg.Opts.TagName)
+				assert.Equal(t, tt.wantFile, cfg.Opts.AssetFilePath)
+			}
+		})
+	}
+}
+
+func Test_verifyAssetRun_Success(t *testing.T) {
+	ios, _, _, _ := iostreams.Test()
+	tagName := "v6"
+
+	fakeHTTP := &httpmock.Registry{}
+	defer fakeHTTP.Verify(t)
+
+	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
+	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
+
+	baseRepo, err := ghrepo.FromFullName("owner/repo")
+	require.NoError(t, err)
+
+	result := &verification.AttestationProcessingResult{
+		Attestation: &api.Attestation{
+			Bundle:    data.GitHubReleaseBundle(t),
+			BundleURL: "https://example.com",
+		},
+		VerificationResult: nil,
+	}
+
+	releaseAssetPath := test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip")
+
+	cfg := &VerifyAssetConfig{
+		Opts: &VerifyAssetOptions{
+			AssetFilePath: releaseAssetPath,
+			TagName:       tagName,
+			BaseRepo:      baseRepo,
+			Exporter:      nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: shared.NewMockVerifier(result),
+	}
+
+	err = verifyAssetRun(cfg)
+	require.NoError(t, err)
+}
+
+func Test_verifyAssetRun_FailedNoAttestations(t *testing.T) {
+	ios, _, _, _ := iostreams.Test()
+	tagName := "v1"
+
+	fakeHTTP := &httpmock.Registry{}
+	defer fakeHTTP.Verify(t)
+	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
+	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
+
+	baseRepo, err := ghrepo.FromFullName("owner/repo")
+	require.NoError(t, err)
+
+	releaseAssetPath := test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip")
+
+	cfg := &VerifyAssetConfig{
+		Opts: &VerifyAssetOptions{
+			AssetFilePath: releaseAssetPath,
+			TagName:       tagName,
+			BaseRepo:      baseRepo,
+			Exporter:      nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewFailTestClient(),
+		AttVerifier: nil,
+	}
+
+	err = verifyAssetRun(cfg)
+	require.ErrorContains(t, err, "no attestations found for tag v1")
+}
+
+func Test_verifyAssetRun_FailedTagNotInAttestation(t *testing.T) {
+	ios, _, _, _ := iostreams.Test()
+
+	// Tag name does not match the one present in the attestation which
+	// will be returned by the mock client. Simulates a scenario where
+	// multiple releases may point to the same commit SHA, but not all
+	// of them are attested.
+	tagName := "v1.2.3"
+
+	fakeHTTP := &httpmock.Registry{}
+	defer fakeHTTP.Verify(t)
+	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
+	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
+
+	baseRepo, err := ghrepo.FromFullName("owner/repo")
+	require.NoError(t, err)
+
+	releaseAssetPath := test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact.zip")
+
+	cfg := &VerifyAssetConfig{
+		Opts: &VerifyAssetOptions{
+			AssetFilePath: releaseAssetPath,
+			TagName:       tagName,
+			BaseRepo:      baseRepo,
+			Exporter:      nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: nil,
+	}
+
+	err = verifyAssetRun(cfg)
+	require.ErrorContains(t, err, "no attestations found for release v1.2.3")
+}
+
+func Test_verifyAssetRun_FailedInvalidAsset(t *testing.T) {
+	ios, _, _, _ := iostreams.Test()
+	tagName := "v6"
+
+	fakeHTTP := &httpmock.Registry{}
+	defer fakeHTTP.Verify(t)
+	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
+	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
+
+	baseRepo, err := ghrepo.FromFullName("owner/repo")
+	require.NoError(t, err)
+
+	releaseAssetPath := test.NormalizeRelativePath("../../attestation/test/data/github_release_artifact_invalid.zip")
+
+	cfg := &VerifyAssetConfig{
+		Opts: &VerifyAssetOptions{
+			AssetFilePath: releaseAssetPath,
+			TagName:       tagName,
+			BaseRepo:      baseRepo,
+			Exporter:      nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: nil,
+	}
+
+	err = verifyAssetRun(cfg)
+	require.ErrorContains(t, err, "attestation for v6 does not contain subject")
+}
+
+func Test_verifyAssetRun_NoSuchAsset(t *testing.T) {
+	ios, _, _, _ := iostreams.Test()
+	tagName := "v6"
+
+	fakeHTTP := &httpmock.Registry{}
+	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
+	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
+
+	baseRepo, err := ghrepo.FromFullName("owner/repo")
+	require.NoError(t, err)
+
+	cfg := &VerifyAssetConfig{
+		Opts: &VerifyAssetOptions{
+			AssetFilePath: "artifact.zip",
+			TagName:       tagName,
+			BaseRepo:      baseRepo,
+			Exporter:      nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: nil,
+	}
+
+	err = verifyAssetRun(cfg)
+	require.ErrorContains(t, err, "failed to open local artifact")
+}
+
+func Test_getFileName(t *testing.T) {
+	tests := []struct {
+		input string
+		want  string
+	}{
+		{"foo/bar/baz.txt", "baz.txt"},
+		{"baz.txt", "baz.txt"},
+		{"/tmp/foo.tar.gz", "foo.tar.gz"},
+	}
+	for _, tt := range tests {
+		t.Run(tt.input, func(t *testing.T) {
+			got := getFileName(tt.input)
+			assert.Equal(t, tt.want, got)
+		})
+	}
+}
diff --git a/pkg/cmd/release/verify/verify_test.go b/pkg/cmd/release/verify/verify_test.go
--- a/pkg/cmd/release/verify/verify_test.go
+++ b/pkg/cmd/release/verify/verify_test.go
@@ -7,7 +7,7 @@ import (
 
 	"github.com/cli/cli/v2/internal/ghrepo"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/api"
-	"github.com/cli/cli/v2/pkg/cmd/attestation/io"
+	"github.com/cli/cli/v2/pkg/cmd/attestation/test/data"
 	"github.com/cli/cli/v2/pkg/cmd/attestation/verification"
 	"github.com/cli/cli/v2/pkg/cmd/release/shared"
 	"github.com/cli/cli/v2/pkg/cmdutil"
@@ -38,40 +38,30 @@ func TestNewCmdVerify_Args(t *testing.T) {
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
 			testIO, _, _, _ := iostreams.Test()
-			var testReg httpmock.Registry
-			var metaResp = api.MetaResponse{
-				Domains: api.Domain{
-					ArtifactAttestations: api.ArtifactAttestations{},
-				},
-			}
-			testReg.Register(httpmock.REST(http.MethodGet, "meta"),
-				httpmock.StatusJSONResponse(200, &metaResp))
-
 			f := &cmdutil.Factory{
 				IOStreams: testIO,
 				HttpClient: func() (*http.Client, error) {
-					reg := &testReg
-					client := &http.Client{}
-					httpmock.ReplaceTripper(client, reg)
-					return client, nil
+					return nil, nil
 				},
 				BaseRepo: func() (ghrepo.Interface, error) {
 					return ghrepo.FromFullName("owner/repo")
 				},
 			}
 
-			var opts *shared.AttestOptions
-			cmd := NewCmdVerify(f, func(o *shared.AttestOptions) error {
-				opts = o
+			var cfg *VerifyConfig
+			cmd := NewCmdVerify(f, func(c *VerifyConfig) error {
+				cfg = c
 				return nil
 			})
 			cmd.SetArgs(tt.args)
 			cmd.SetIn(&bytes.Buffer{})
 			cmd.SetOut(&bytes.Buffer{})
 			cmd.SetErr(&bytes.Buffer{})
+
 			_, err := cmd.ExecuteC()
+
 			require.NoError(t, err)
-			assert.Equal(t, tt.wantTag, opts.TagName)
+			assert.Equal(t, tt.wantTag, cfg.Opts.TagName)
 		})
 	}
 }
@@ -82,36 +72,40 @@ func Test_verifyRun_Success(t *testing.T) {
 
 	fakeHTTP := &httpmock.Registry{}
 	defer fakeHTTP.Verify(t)
+
 	fakeSHA := "1234567890abcdef1234567890abcdef12345678"
 	shared.StubFetchRefSHA(t, fakeHTTP, "owner", "repo", tagName, fakeSHA)
 
 	baseRepo, err := ghrepo.FromFullName("owner/repo")
 	require.NoError(t, err)
 
-	opts := &shared.AttestOptions{
-		TagName:          tagName,
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		HttpClient:       &http.Client{Transport: fakeHTTP},
-		BaseRepo:         baseRepo,
-		PredicateType:    shared.ReleasePredicateType,
+	result := &verification.AttestationProcessingResult{
+		Attestation: &api.Attestation{
+			Bundle:    data.GitHubReleaseBundle(t),
+			BundleURL: "https://example.com",
+		},
+		VerificationResult: nil,
 	}
 
-	ec, err := shared.NewEnforcementCriteria(opts)
-	require.NoError(t, err)
-	opts.EC = ec
+	cfg := &VerifyConfig{
+		Opts: &VerifyOptions{
+			TagName:  tagName,
+			BaseRepo: baseRepo,
+			Exporter: nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: shared.NewMockVerifier(result),
+	}
 
-	err = verifyRun(opts)
+	err = verifyRun(cfg)
 	require.NoError(t, err)
 }
 
-func Test_verifyRun_Failed_With_Invalid_Tag(t *testing.T) {
+func Test_verifyRun_FailedNoAttestations(t *testing.T) {
 	ios, _, _, _ := iostreams.Test()
-	tagName := "v1.2.3"
+	tagName := "v1"
 
 	fakeHTTP := &httpmock.Registry{}
 	defer fakeHTTP.Verify(t)
@@ -121,30 +115,29 @@ func Test_verifyRun_Failed_With_Invalid_Tag(t *testing.T) {
 	baseRepo, err := ghrepo.FromFullName("owner/repo")
 	require.NoError(t, err)
 
-	opts := &shared.AttestOptions{
-		TagName:          tagName,
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewFailTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		PredicateType:    shared.ReleasePredicateType,
-
-		HttpClient: &http.Client{Transport: fakeHTTP},
-		BaseRepo:   baseRepo,
+	cfg := &VerifyConfig{
+		Opts: &VerifyOptions{
+			TagName:  tagName,
+			BaseRepo: baseRepo,
+			Exporter: nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewFailTestClient(),
+		AttVerifier: nil,
 	}
 
-	ec, err := shared.NewEnforcementCriteria(opts)
-	require.NoError(t, err)
-	opts.EC = ec
-
-	err = verifyRun(opts)
-	require.Error(t, err, "failed to fetch attestations from owner/repo")
+	err = verifyRun(cfg)
+	require.ErrorContains(t, err, "no attestations for tag v1")
 }
 
-func Test_verifyRun_Failed_NoAttestation(t *testing.T) {
+func Test_verifyRun_FailedTagNotInAttestation(t *testing.T) {
 	ios, _, _, _ := iostreams.Test()
+
+	// Tag name does not match the one present in the attestation which
+	// will be returned by the mock client. Simulates a scenario where
+	// multiple releases may point to the same commit SHA, but not all
+	// of them are attested.
 	tagName := "v1.2.3"
 
 	fakeHTTP := &httpmock.Registry{}
@@ -155,23 +148,18 @@ func Test_verifyRun_Failed_NoAttestation(t *testing.T) {
 	baseRepo, err := ghrepo.FromFullName("owner/repo")
 	require.NoError(t, err)
 
-	opts := &shared.AttestOptions{
-		TagName:          tagName,
-		Repo:             "owner/repo",
-		Owner:            "owner",
-		Limit:            10,
-		Logger:           io.NewHandler(ios),
-		APIClient:        api.NewFailTestClient(),
-		SigstoreVerifier: verification.NewMockSigstoreVerifier(t),
-		HttpClient:       &http.Client{Transport: fakeHTTP},
-		BaseRepo:         baseRepo,
-		PredicateType:    shared.ReleasePredicateType,
+	cfg := &VerifyConfig{
+		Opts: &VerifyOptions{
+			TagName:  tagName,
+			BaseRepo: baseRepo,
+			Exporter: nil,
+		},
+		IO:          ios,
+		HttpClient:  &http.Client{Transport: fakeHTTP},
+		AttClient:   api.NewTestClient(),
+		AttVerifier: nil,
 	}
 
-	ec, err := shared.NewEnforcementCriteria(opts)
-	require.NoError(t, err)
-	opts.EC = ec
-
-	err = verifyRun(opts)
-	require.Error(t, err, "failed to fetch attestations from owner/repo")
+	err = verifyRun(cfg)
+	require.ErrorContains(t, err, "no attestations found for release v1.2.3")
 }
EOF_114329324912

# Run the target test files
# Combining all test packages into a single command for efficiency
# Using -v for verbose output to help with debugging
go test -v \
    ./pkg/cmd/release/shared/ \
    ./pkg/cmd/release/verify-asset/ \
    ./pkg/cmd/release/verify/

# Capture exit code immediately
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original state
git checkout d7d9228609e555b5541088e56c8f25bbbe1177db \
    "pkg/cmd/attestation/artifact/file.go" \
    "pkg/cmd/release/shared/attestation.go" \
    "pkg/cmd/release/shared/options_test.go" \
    "pkg/cmd/release/shared/policy_test.go" \
    "pkg/cmd/release/verify-asset/verify-asset_test.go" \
    "pkg/cmd/release/verify/verify_test.go"