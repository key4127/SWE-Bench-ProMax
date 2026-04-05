#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 790bcbe773ef5379999ac3e7edca1647c45ebac1 "lib/anubis_test.go" "lib/policy/config/config_test.go" "lib/policy/config/threshold_test.go" "lib/testdata/test_config.yaml"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/lib/anubis_test.go b/lib/anubis_test.go
--- a/lib/anubis_test.go
+++ b/lib/anubis_test.go
@@ -5,6 +5,7 @@ import (
 	"encoding/json"
 	"fmt"
 	"io"
+	"log/slog"
 	"net/http"
 	"net/http/httptest"
 	"net/url"
@@ -22,8 +23,25 @@ import (
 	"github.com/TecharoHQ/anubis/lib/thoth/thothmock"
 )
 
-func init() {
-	internal.InitSlog("debug")
+// TLogWriter implements io.Writer by logging each line to t.Log.
+type TLogWriter struct {
+	t *testing.T
+}
+
+// NewTLogWriter returns an io.Writer that sends output to t.Log.
+func NewTLogWriter(t *testing.T) io.Writer {
+	return &TLogWriter{t: t}
+}
+
+// Write splits input on newlines and logs each line separately.
+func (w *TLogWriter) Write(p []byte) (n int, err error) {
+	lines := strings.Split(string(p), "\n")
+	for _, line := range lines {
+		if line != "" {
+			w.t.Log(line)
+		}
+	}
+	return len(p), nil
 }
 
 func loadPolicies(t *testing.T, fname string, difficulty int) *policy.ParsedConfig {
@@ -35,6 +53,8 @@ func loadPolicies(t *testing.T, fname string, difficulty int) *policy.ParsedConf
 		fname = "./testdata/test_config.yaml"
 	}
 
+	t.Logf("loading policy file: %s", fname)
+
 	anubisPolicy, err := LoadPoliciesOrDefault(ctx, fname, difficulty)
 	if err != nil {
 		t.Fatal(err)
@@ -55,10 +75,16 @@ func spawnAnubis(t *testing.T, opts Options) *Server {
 		t.Fatalf("can't construct libanubis.Server: %v", err)
 	}
 
+	s.logger = slog.New(slog.NewJSONHandler(&TLogWriter{t: t}, &slog.HandlerOptions{
+		AddSource: true,
+		Level:     slog.LevelDebug,
+	}))
+
 	return s
 }
 
 type challengeResp struct {
+	ID        string `json:"id"`
 	Challenge string `json:"challenge"`
 }
 
@@ -91,6 +117,8 @@ func makeChallenge(t *testing.T, ts *httptest.Server, cli *http.Client) challeng
 func handleChallengeZeroDifficulty(t *testing.T, ts *httptest.Server, cli *http.Client, chall challengeResp) *http.Response {
 	t.Helper()
 
+	t.Logf("%#v", chall)
+
 	nonce := 0
 	elapsedTime := 420
 	redir := "/"
@@ -108,8 +136,11 @@ func handleChallengeZeroDifficulty(t *testing.T, ts *httptest.Server, cli *http.
 	q.Set("nonce", fmt.Sprint(nonce))
 	q.Set("redir", redir)
 	q.Set("elapsedTime", fmt.Sprint(elapsedTime))
+	q.Set("id", chall.ID)
 	req.URL.RawQuery = q.Encode()
 
+	t.Log(q.Encode())
+
 	resp, err := cli.Do(req)
 	if err != nil {
 		t.Fatalf("can't do request: %v", err)
@@ -155,6 +186,17 @@ func (lcj *loggingCookieJar) SetCookies(u *url.URL, cookies []*http.Cookie) {
 	lcj.cookies[u.Host] = append(lcj.cookies[u.Host], cookies...)
 }
 
+type userAgentRoundTripper struct {
+	rt http.RoundTripper
+}
+
+func (u *userAgentRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
+	// Only set if not already present
+	req = req.Clone(req.Context()) // avoid mutating original request
+	req.Header.Set("User-Agent", "Mozilla/5.0")
+	return u.rt.RoundTrip(req)
+}
+
 func httpClient(t *testing.T) *http.Client {
 	t.Helper()
 
@@ -163,6 +205,9 @@ func httpClient(t *testing.T) *http.Client {
 		CheckRedirect: func(req *http.Request, via []*http.Request) error {
 			return http.ErrUseLastResponse
 		},
+		Transport: &userAgentRoundTripper{
+			rt: http.DefaultTransport,
+		},
 	}
 
 	return cli
@@ -207,7 +252,7 @@ func TestCVE2025_24369(t *testing.T) {
 }
 
 func TestCookieCustomExpiration(t *testing.T) {
-	pol := loadPolicies(t, "", 0)
+	pol := loadPolicies(t, "testdata/zero_difficulty.yaml", 0)
 	ckieExpiration := 10 * time.Minute
 
 	srv := spawnAnubis(t, Options{
@@ -223,9 +268,7 @@ func TestCookieCustomExpiration(t *testing.T) {
 	cli := httpClient(t)
 	chall := makeChallenge(t, ts, cli)
 
-	requestReceiveLowerBound := time.Now().Add(-1 * time.Minute)
 	resp := handleChallengeZeroDifficulty(t, ts, cli, chall)
-	requestReceiveUpperBound := time.Now()
 
 	if resp.StatusCode != http.StatusFound {
 		resp.Write(os.Stderr)
@@ -244,19 +287,10 @@ func TestCookieCustomExpiration(t *testing.T) {
 		t.Errorf("Cookie %q not found", anubis.CookieName)
 		return
 	}
-
-	expirationLowerBound := requestReceiveLowerBound.Add(ckieExpiration)
-	expirationUpperBound := requestReceiveUpperBound.Add(ckieExpiration)
-	// Since the cookie expiration precision is only to the second due to the Unix() call, we can
-	// lower the level of expected precision.
-	if ckie.Expires.Unix() < expirationLowerBound.Unix() || ckie.Expires.Unix() > expirationUpperBound.Unix() {
-		t.Errorf("cookie expiration is not within the expected range. expected between: %v and %v. got: %v", expirationLowerBound, expirationUpperBound, ckie.Expires)
-		return
-	}
 }
 
 func TestCookieSettings(t *testing.T) {
-	pol := loadPolicies(t, "", 0)
+	pol := loadPolicies(t, "testdata/zero_difficulty.yaml", 0)
 
 	srv := spawnAnubis(t, Options{
 		Next:   http.NewServeMux(),
@@ -268,15 +302,13 @@ func TestCookieSettings(t *testing.T) {
 		CookieExpiration:  anubis.CookieDefaultExpirationTime,
 	})
 
-	requestReceiveLowerBound := time.Now()
 	ts := httptest.NewServer(internal.RemoteXRealIP(true, "tcp", srv))
 	defer ts.Close()
 
 	cli := httpClient(t)
 	chall := makeChallenge(t, ts, cli)
 
 	resp := handleChallengeZeroDifficulty(t, ts, cli, chall)
-	requestReceiveUpperBound := time.Now()
 
 	if resp.StatusCode != http.StatusFound {
 		resp.Write(os.Stderr)
@@ -300,15 +332,6 @@ func TestCookieSettings(t *testing.T) {
 		t.Errorf("cookie domain is wrong, wanted 127.0.0.1, got: %s", ckie.Domain)
 	}
 
-	expirationLowerBound := requestReceiveLowerBound.Add(anubis.CookieDefaultExpirationTime)
-	expirationUpperBound := requestReceiveUpperBound.Add(anubis.CookieDefaultExpirationTime)
-	// Since the cookie expiration precision is only to the second due to the Unix() call, we can
-	// lower the level of expected precision.
-	if ckie.Expires.Unix() < expirationLowerBound.Unix() || ckie.Expires.Unix() > expirationUpperBound.Unix() {
-		t.Errorf("cookie expiration is not within the expected range. expected between: %v and %v. got: %v", expirationLowerBound, expirationUpperBound, ckie.Expires)
-		return
-	}
-
 	if ckie.Partitioned != srv.opts.CookiePartitioned {
 		t.Errorf("wanted partitioned flag %v, got: %v", srv.opts.CookiePartitioned, ckie.Partitioned)
 	}
@@ -325,7 +348,7 @@ func TestCheckDefaultDifficultyMatchesPolicy(t *testing.T) {
 
 	for i := 1; i < 10; i++ {
 		t.Run(fmt.Sprint(i), func(t *testing.T) {
-			anubisPolicy := loadPolicies(t, "", i)
+			anubisPolicy := loadPolicies(t, "testdata/test_config_no_thresholds.yaml", i)
 
 			s, err := New(Options{
 				Next:           h,
@@ -476,8 +499,11 @@ func TestBasePrefix(t *testing.T) {
 			q.Set("nonce", fmt.Sprint(nonce))
 			q.Set("redir", redir)
 			q.Set("elapsedTime", fmt.Sprint(elapsedTime))
+			q.Set("id", chall.ID)
 			req.URL.RawQuery = q.Encode()
 
+			t.Log(req.URL.String())
+
 			resp, err = cli.Do(req)
 			if err != nil {
 				t.Fatalf("can't do challenge passing: %v", err)
diff --git a/lib/policy/config/config_test.go b/lib/policy/config/config_test.go
--- a/lib/policy/config/config_test.go
+++ b/lib/policy/config/config_test.go
@@ -109,7 +109,7 @@ func TestBotValid(t *testing.T) {
 				Action:    RuleChallenge,
 				PathRegex: p("Mozilla"),
 				Challenge: &ChallengeRules{
-					Difficulty: 0,
+					Difficulty: -1,
 					ReportAs:   4,
 					Algorithm:  "fast",
 				},
diff --git a/lib/policy/config/threshold_test.go b/lib/policy/config/threshold_test.go
--- a/lib/policy/config/threshold_test.go
+++ b/lib/policy/config/threshold_test.go
@@ -70,7 +70,7 @@ func TestThresholdValid(t *testing.T) {
 			name: "challenge invalid",
 			input: &Threshold{
 				Action:    RuleChallenge,
-				Challenge: &ChallengeRules{Difficulty: 0, ReportAs: 0},
+				Challenge: &ChallengeRules{Difficulty: -1, ReportAs: -1},
 			},
 			err: ErrChallengeDifficultyTooLow,
 		},
diff --git a/lib/testdata/test_config.yaml b/lib/testdata/test_config.yaml
--- a/lib/testdata/test_config.yaml
+++ b/lib/testdata/test_config.yaml
@@ -35,4 +35,11 @@ status_codes:
   CHALLENGE: 200
   DENY: 200
 
-thresholds: []
+thresholds:
+  - name: minimal-suspicion
+    expression: "true"
+    action: CHALLENGE
+    challenge:
+      algorithm: fast
+      difficulty: 1
+      report_as: 1
diff --git a/lib/testdata/test_config_no_thresholds.yaml b/lib/testdata/test_config_no_thresholds.yaml
new file mode 100644
--- /dev/null
+++ b/lib/testdata/test_config_no_thresholds.yaml
@@ -0,0 +1,38 @@
+bots:
+  - import: (data)/bots/_deny-pathological.yaml
+  - import: (data)/bots/aggressive-brazilian-scrapers.yaml
+  - import: (data)/meta/ai-block-aggressive.yaml
+  - import: (data)/crawlers/_allow-good.yaml
+  - import: (data)/clients/x-firefox-ai.yaml
+  - import: (data)/common/keep-internet-working.yaml
+  - name: countries-with-aggressive-scrapers
+    action: WEIGH
+    geoip:
+      countries:
+        - BR
+        - CN
+    weight:
+      adjust: 10
+  - name: aggressive-asns-without-functional-abuse-contact
+    action: WEIGH
+    asns:
+      match:
+        - 13335 # Cloudflare
+        - 136907 # Huawei Cloud
+        - 45102 # Alibaba Cloud
+    weight:
+      adjust: 10
+  - name: generic-browser
+    user_agent_regex: >-
+      Mozilla|Opera
+    action: WEIGH
+    weight:
+      adjust: 10
+
+dnsbl: false
+
+status_codes:
+  CHALLENGE: 200
+  DENY: 200
+
+thresholds: []
diff --git a/lib/testdata/zero_difficulty.yaml b/lib/testdata/zero_difficulty.yaml
new file mode 100644
--- /dev/null
+++ b/lib/testdata/zero_difficulty.yaml
@@ -0,0 +1,45 @@
+bots:
+  - import: (data)/bots/_deny-pathological.yaml
+  - import: (data)/bots/aggressive-brazilian-scrapers.yaml
+  - import: (data)/meta/ai-block-aggressive.yaml
+  - import: (data)/crawlers/_allow-good.yaml
+  - import: (data)/clients/x-firefox-ai.yaml
+  - import: (data)/common/keep-internet-working.yaml
+  - name: countries-with-aggressive-scrapers
+    action: WEIGH
+    geoip:
+      countries:
+        - BR
+        - CN
+    weight:
+      adjust: 10
+  - name: aggressive-asns-without-functional-abuse-contact
+    action: WEIGH
+    asns:
+      match:
+        - 13335 # Cloudflare
+        - 136907 # Huawei Cloud
+        - 45102 # Alibaba Cloud
+    weight:
+      adjust: 10
+  - name: generic-browser
+    user_agent_regex: >-
+      Mozilla|Opera
+    action: WEIGH
+    weight:
+      adjust: 10
+
+dnsbl: false
+
+status_codes:
+  CHALLENGE: 200
+  DENY: 200
+
+thresholds:
+  - name: minimal-suspicion
+    expression: "true"
+    action: CHALLENGE
+    challenge:
+      algorithm: fast
+      difficulty: 0
+      report_as: 0
EOF_114329324912

# Set Go environment variables (ensure they're available in this shell)
export PATH=/usr/local/go/bin:$GOPATH/bin:$PATH
export GOPATH=/go

# Add npm binaries to PATH (required for asset generation if needed)
export PATH=/testbed/node_modules/.bin:$PATH

# Ensure assets are built (they should already be built in Dockerfile, but verify)
# This is a safety check in case the container state differs
if [ ! -d "/testbed/data" ]; then
    echo "Assets not found, building..."
    make assets
fi

# Run the target test packages (not individual files)
# This runs all tests in ./lib and ./lib/policy/config packages
# The test patch has already been applied to the target files
go test -v ./lib ./lib/policy/config
rc=$?

# Required: echo test status for judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 790bcbe773ef5379999ac3e7edca1647c45ebac1 "lib/anubis_test.go" "lib/policy/config/config_test.go" "lib/policy/config/threshold_test.go" "lib/testdata/test_config.yaml"