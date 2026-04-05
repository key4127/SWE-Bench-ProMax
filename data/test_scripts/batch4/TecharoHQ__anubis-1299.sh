#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a709a2b2daecea6b893de6bb4224bab85ae200d8 ".github/workflows/smoke-tests.yml" "internal/ogtags/cache_test.go" "internal/ogtags/fetch_test.go" "internal/ogtags/integration_test.go" "internal/ogtags/mem_test.go" "internal/ogtags/ogtags_fuzz_test.go" "internal/ogtags/ogtags_test.go" "internal/ogtags/parse_test.go" "internal/test/playwright_test.go" "lib/anubis_test.go" "lib/challenge/proofofwork/proofofwork_test.go" "lib/policy/config/asn_test.go" "lib/policy/config/config_test.go" "lib/policy/config/expressionorlist_test.go" "lib/policy/config/geoip_test.go" "lib/policy/config/impressum_test.go" "lib/policy/config/opengraph_test.go" "lib/policy/config/store_test.go" "lib/policy/config/testdata/bad/badregexes.json" "lib/policy/config/testdata/bad/badregexes.yaml" "lib/policy/config/testdata/bad/import_and_bot.json" "lib/policy/config/testdata/bad/import_and_bot.yaml" "lib/policy/config/testdata/bad/import_invalid_file.json" "lib/policy/config/testdata/bad/import_invalid_file.yaml" "lib/policy/config/testdata/bad/impressum-no-footer.yaml" "lib/policy/config/testdata/bad/impressum-no-page-contents.yaml" "lib/policy/config/testdata/bad/invalid.json" "lib/policy/config/testdata/bad/invalid.yaml" "lib/policy/config/testdata/bad/multiple_expression_types.json" "lib/policy/config/testdata/bad/multiple_expression_types.yaml" "lib/policy/config/testdata/bad/nobots.json" "lib/policy/config/testdata/bad/nobots.yaml" "lib/policy/config/testdata/bad/opengraph_bad_ttl.yaml" "lib/policy/config/testdata/bad/regex_ends_newline.json" "lib/policy/config/testdata/bad/regex_ends_newline.yaml" "lib/policy/config/testdata/bad/status-codes-0.json" "lib/policy/config/testdata/bad/status-codes-0.yaml" "lib/policy/config/testdata/bad/threshold-challenge-without-challenge.yaml" "lib/policy/config/testdata/bad/thresholds.yaml" "lib/policy/config/testdata/bad/unparseable.json" "lib/policy/config/testdata/bad/unparseable.yaml" "lib/policy/config/testdata/good/allow_everyone.json" "lib/policy/config/testdata/good/allow_everyone.yaml" "lib/policy/config/testdata/good/block_cf_workers.json" "lib/policy/config/testdata/good/block_cf_workers.yaml" "lib/policy/config/testdata/good/challenge_cloudflare.yaml" "lib/policy/config/testdata/good/challengemozilla.json" "lib/policy/config/testdata/good/challengemozilla.yaml" "lib/policy/config/testdata/good/entropy.yaml" "lib/policy/config/testdata/good/everything_blocked.json" "lib/policy/config/testdata/good/everything_blocked.yaml" "lib/policy/config/testdata/good/geoip_us.yaml" "lib/policy/config/testdata/good/git_client.json" "lib/policy/config/testdata/good/git_client.yaml" "lib/policy/config/testdata/good/import_filesystem.json" "lib/policy/config/testdata/good/import_filesystem.yaml" "lib/policy/config/testdata/good/import_keep_internet_working.json" "lib/policy/config/testdata/good/import_keep_internet_working.yaml" "lib/policy/config/testdata/good/impressum.yaml" "lib/policy/config/testdata/good/no-thresholds.yaml" "lib/policy/config/testdata/good/old_xesite.json" "lib/policy/config/testdata/good/opengraph_all_good.yaml" "lib/policy/config/testdata/good/simple-weight.yaml" "lib/policy/config/testdata/good/status-codes-paranoid.json" "lib/policy/config/testdata/good/status-codes-paranoid.yaml" "lib/policy/config/testdata/good/status-codes-rfc.json" "lib/policy/config/testdata/good/status-codes-rfc.yaml" "lib/policy/config/testdata/good/thresholds.yaml" "lib/policy/config/testdata/good/weight-no-weight.yaml" "lib/policy/config/testdata/hack-test.json" "lib/policy/config/testdata/hack-test.yaml" "lib/policy/config/threshold_test.go" "lib/config_test.go" "lib/policy/policy_test.go" "test/go.mod" "test/go.sum"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/.github/workflows/smoke-tests.yml b/.github/workflows/smoke-tests.yml
--- a/.github/workflows/smoke-tests.yml
+++ b/.github/workflows/smoke-tests.yml
@@ -22,6 +22,7 @@ jobs:
           - git-push
           - healthcheck
           - i18n
+          - log-file
           - palemoon/amd64
           #- palemoon/i386
           - robots_txt
diff --git a/internal/ogtags/cache_test.go b/internal/ogtags/cache_test.go
--- a/internal/ogtags/cache_test.go
+++ b/internal/ogtags/cache_test.go
@@ -9,7 +9,7 @@ import (
 	"testing"
 	"time"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 )
diff --git a/internal/ogtags/fetch_test.go b/internal/ogtags/fetch_test.go
--- a/internal/ogtags/fetch_test.go
+++ b/internal/ogtags/fetch_test.go
@@ -11,7 +11,7 @@ import (
 	"testing"
 	"time"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 	"golang.org/x/net/html"
 )
diff --git a/internal/ogtags/integration_test.go b/internal/ogtags/integration_test.go
--- a/internal/ogtags/integration_test.go
+++ b/internal/ogtags/integration_test.go
@@ -7,7 +7,7 @@ import (
 	"testing"
 	"time"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 )
 
diff --git a/internal/ogtags/mem_test.go b/internal/ogtags/mem_test.go
--- a/internal/ogtags/mem_test.go
+++ b/internal/ogtags/mem_test.go
@@ -6,7 +6,7 @@ import (
 	"strings"
 	"testing"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 	"golang.org/x/net/html"
 )
diff --git a/internal/ogtags/ogtags_fuzz_test.go b/internal/ogtags/ogtags_fuzz_test.go
--- a/internal/ogtags/ogtags_fuzz_test.go
+++ b/internal/ogtags/ogtags_fuzz_test.go
@@ -7,7 +7,7 @@ import (
 	"testing"
 	"unicode/utf8"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 	"golang.org/x/net/html"
 )
diff --git a/internal/ogtags/ogtags_test.go b/internal/ogtags/ogtags_test.go
--- a/internal/ogtags/ogtags_test.go
+++ b/internal/ogtags/ogtags_test.go
@@ -22,7 +22,7 @@ import (
 	"testing"
 	"time"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 )
 
diff --git a/internal/ogtags/parse_test.go b/internal/ogtags/parse_test.go
--- a/internal/ogtags/parse_test.go
+++ b/internal/ogtags/parse_test.go
@@ -6,7 +6,7 @@ import (
 	"testing"
 	"time"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/memory"
 	"golang.org/x/net/html"
 )
diff --git a/internal/test/playwright_test.go b/internal/test/playwright_test.go
--- a/internal/test/playwright_test.go
+++ b/internal/test/playwright_test.go
@@ -595,7 +595,7 @@ func spawnAnubisWithOptions(t *testing.T, basePrefix string) string {
 		fmt.Fprintf(w, "<html><body><span id=anubis-test>%d</span></body></html>", time.Now().Unix())
 	})
 
-	policy, err := libanubis.LoadPoliciesOrDefault(t.Context(), "", anubis.DefaultDifficulty)
+	policy, err := libanubis.LoadPoliciesOrDefault(t.Context(), "", anubis.DefaultDifficulty, "info")
 	if err != nil {
 		t.Fatal(err)
 	}
diff --git a/lib/anubis_test.go b/lib/anubis_test.go
--- a/lib/anubis_test.go
+++ b/lib/anubis_test.go
@@ -20,8 +20,8 @@ import (
 	"github.com/TecharoHQ/anubis/data"
 	"github.com/TecharoHQ/anubis/internal"
 	"github.com/TecharoHQ/anubis/lib/challenge"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/policy"
-	"github.com/TecharoHQ/anubis/lib/policy/config"
 	"github.com/TecharoHQ/anubis/lib/store"
 	"github.com/TecharoHQ/anubis/lib/thoth/thothmock"
 )
@@ -58,7 +58,7 @@ func loadPolicies(t *testing.T, fname string, difficulty int) *policy.ParsedConf
 
 	t.Logf("loading policy file: %s", fname)
 
-	anubisPolicy, err := LoadPoliciesOrDefault(ctx, fname, difficulty)
+	anubisPolicy, err := LoadPoliciesOrDefault(ctx, fname, difficulty, "info")
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -250,7 +250,7 @@ func TestLoadPolicies(t *testing.T) {
 			}
 			defer fin.Close()
 
-			if _, err := policy.ParseConfig(t.Context(), fin, fname, 4); err != nil {
+			if _, err := policy.ParseConfig(t.Context(), fin, fname, 4, "info"); err != nil {
 				t.Fatal(err)
 			}
 		})
diff --git a/lib/challenge/proofofwork/proofofwork_test.go b/lib/challenge/proofofwork/proofofwork_test.go
--- a/lib/challenge/proofofwork/proofofwork_test.go
+++ b/lib/challenge/proofofwork/proofofwork_test.go
@@ -8,8 +8,8 @@ import (
 	"testing"
 
 	"github.com/TecharoHQ/anubis/lib/challenge"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/policy"
-	"github.com/TecharoHQ/anubis/lib/policy/config"
 )
 
 func mkRequest(t *testing.T, values map[string]string) *http.Request {
diff --git a/lib/policy/config/asn_test.go b/lib/config/asn_test.go
rename from lib/policy/config/asn_test.go
rename to lib/config/asn_test.go
--- a/lib/policy/config/asn_test.go
+++ b/lib/config/asn_test.go

diff --git a/lib/policy/config/config_test.go b/lib/config/config_test.go
rename from lib/policy/config/config_test.go
rename to lib/config/config_test.go
--- a/lib/policy/config/config_test.go
+++ b/lib/config/config_test.go
@@ -8,7 +8,7 @@ import (
 	"testing"
 
 	"github.com/TecharoHQ/anubis/data"
-	. "github.com/TecharoHQ/anubis/lib/policy/config"
+	. "github.com/TecharoHQ/anubis/lib/config"
 )
 
 func p[V any](v V) *V { return &v }
diff --git a/lib/policy/config/expressionorlist_test.go b/lib/config/expressionorlist_test.go
rename from lib/policy/config/expressionorlist_test.go
rename to lib/config/expressionorlist_test.go
--- a/lib/policy/config/expressionorlist_test.go
+++ b/lib/config/expressionorlist_test.go

diff --git a/lib/policy/config/geoip_test.go b/lib/config/geoip_test.go
rename from lib/policy/config/geoip_test.go
rename to lib/config/geoip_test.go
--- a/lib/policy/config/geoip_test.go
+++ b/lib/config/geoip_test.go

diff --git a/lib/policy/config/impressum_test.go b/lib/config/impressum_test.go
rename from lib/policy/config/impressum_test.go
rename to lib/config/impressum_test.go
--- a/lib/policy/config/impressum_test.go
+++ b/lib/config/impressum_test.go

diff --git a/lib/config/logging_test.go b/lib/config/logging_test.go
new file mode 100644
--- /dev/null
+++ b/lib/config/logging_test.go
@@ -0,0 +1,103 @@
+package config
+
+import (
+	"errors"
+	"testing"
+)
+
+func TestLoggingValid(t *testing.T) {
+	for _, tt := range []struct {
+		name  string
+		input *Logging
+		want  error
+	}{
+		{
+			name:  "simple happy",
+			input: (Logging{}).Default(),
+		},
+		{
+			name: "default file config",
+			input: &Logging{
+				Sink:       LogSinkFile,
+				Parameters: (&LoggingFileConfig{}).Default(),
+			},
+		},
+		{
+			name: "invalid sink",
+			input: &Logging{
+				Sink: "taco invalid",
+			},
+			want: ErrInvalidLoggingSink,
+		},
+		{
+			name: "missing parameters",
+			input: &Logging{
+				Sink: LogSinkFile,
+			},
+			want: ErrMissingLoggingFileConfig,
+		},
+		{
+			name: "invalid parameters",
+			input: &Logging{
+				Sink:       LogSinkFile,
+				Parameters: &LoggingFileConfig{},
+			},
+			want: ErrInvalidLoggingFileConfig,
+		},
+		{
+			name: "file sink with no filename",
+			input: &Logging{
+				Sink: LogSinkFile,
+				Parameters: &LoggingFileConfig{
+					Filename:     "",
+					MaxBackups:   3,
+					MaxBytes:     104857600, // 100 Mi
+					MaxAge:       7,         // 7 days
+					Compress:     true,
+					UseLocalTime: false,
+				},
+			},
+			want: ErrMissingValue,
+		},
+		{
+			name: "file sink with negative max backups",
+			input: &Logging{
+				Sink: LogSinkFile,
+				Parameters: &LoggingFileConfig{
+					Filename:     "./var/anubis.log",
+					MaxBackups:   -3,
+					MaxBytes:     104857600, // 100 Mi
+					MaxAge:       7,         // 7 days
+					Compress:     true,
+					UseLocalTime: false,
+				},
+			},
+			want: ErrOutOfRange,
+		},
+		{
+			name: "file sink with negative max age",
+			input: &Logging{
+				Sink: LogSinkFile,
+				Parameters: &LoggingFileConfig{
+					Filename:     "./var/anubis.log",
+					MaxBackups:   3,
+					MaxBytes:     104857600, // 100 Mi
+					MaxAge:       -7,        // 7 days
+					Compress:     true,
+					UseLocalTime: false,
+				},
+			},
+			want: ErrOutOfRange,
+		},
+	} {
+		t.Run(tt.name, func(t *testing.T) {
+			err := tt.input.Valid()
+
+			if !errors.Is(err, tt.want) {
+				t.Logf("wanted error: %v", tt.want)
+				t.Logf("   got error: %v", err)
+				t.Fatal("got wrong error")
+			}
+		})
+	}
+}
diff --git a/lib/policy/config/opengraph_test.go b/lib/config/opengraph_test.go
rename from lib/policy/config/opengraph_test.go
rename to lib/config/opengraph_test.go
--- a/lib/policy/config/opengraph_test.go
+++ b/lib/config/opengraph_test.go

diff --git a/lib/policy/config/store_test.go b/lib/config/store_test.go
rename from lib/policy/config/store_test.go
rename to lib/config/store_test.go
--- a/lib/policy/config/store_test.go
+++ b/lib/config/store_test.go
@@ -5,7 +5,7 @@ import (
 	"errors"
 	"testing"
 
-	"github.com/TecharoHQ/anubis/lib/policy/config"
+	"github.com/TecharoHQ/anubis/lib/config"
 	"github.com/TecharoHQ/anubis/lib/store/bbolt"
 	"github.com/TecharoHQ/anubis/lib/store/valkey"
 )
diff --git a/lib/policy/config/testdata/bad/badregexes.json b/lib/config/testdata/bad/badregexes.json
rename from lib/policy/config/testdata/bad/badregexes.json
rename to lib/config/testdata/bad/badregexes.json
--- a/lib/policy/config/testdata/bad/badregexes.json
+++ b/lib/config/testdata/bad/badregexes.json

diff --git a/lib/policy/config/testdata/bad/badregexes.yaml b/lib/config/testdata/bad/badregexes.yaml
rename from lib/policy/config/testdata/bad/badregexes.yaml
rename to lib/config/testdata/bad/badregexes.yaml
--- a/lib/policy/config/testdata/bad/badregexes.yaml
+++ b/lib/config/testdata/bad/badregexes.yaml

diff --git a/lib/policy/config/testdata/bad/import_and_bot.json b/lib/config/testdata/bad/import_and_bot.json
rename from lib/policy/config/testdata/bad/import_and_bot.json
rename to lib/config/testdata/bad/import_and_bot.json
--- a/lib/policy/config/testdata/bad/import_and_bot.json
+++ b/lib/config/testdata/bad/import_and_bot.json

diff --git a/lib/policy/config/testdata/bad/import_and_bot.yaml b/lib/config/testdata/bad/import_and_bot.yaml
rename from lib/policy/config/testdata/bad/import_and_bot.yaml
rename to lib/config/testdata/bad/import_and_bot.yaml
--- a/lib/policy/config/testdata/bad/import_and_bot.yaml
+++ b/lib/config/testdata/bad/import_and_bot.yaml

diff --git a/lib/policy/config/testdata/bad/import_invalid_file.json b/lib/config/testdata/bad/import_invalid_file.json
rename from lib/policy/config/testdata/bad/import_invalid_file.json
rename to lib/config/testdata/bad/import_invalid_file.json
--- a/lib/policy/config/testdata/bad/import_invalid_file.json
+++ b/lib/config/testdata/bad/import_invalid_file.json

diff --git a/lib/policy/config/testdata/bad/import_invalid_file.yaml b/lib/config/testdata/bad/import_invalid_file.yaml
rename from lib/policy/config/testdata/bad/import_invalid_file.yaml
rename to lib/config/testdata/bad/import_invalid_file.yaml
--- a/lib/policy/config/testdata/bad/import_invalid_file.yaml
+++ b/lib/config/testdata/bad/import_invalid_file.yaml

diff --git a/lib/policy/config/testdata/bad/impressum-no-footer.yaml b/lib/config/testdata/bad/impressum-no-footer.yaml
rename from lib/policy/config/testdata/bad/impressum-no-footer.yaml
rename to lib/config/testdata/bad/impressum-no-footer.yaml
--- a/lib/policy/config/testdata/bad/impressum-no-footer.yaml
+++ b/lib/config/testdata/bad/impressum-no-footer.yaml

diff --git a/lib/policy/config/testdata/bad/impressum-no-page-contents.yaml b/lib/config/testdata/bad/impressum-no-page-contents.yaml
rename from lib/policy/config/testdata/bad/impressum-no-page-contents.yaml
rename to lib/config/testdata/bad/impressum-no-page-contents.yaml
--- a/lib/policy/config/testdata/bad/impressum-no-page-contents.yaml
+++ b/lib/config/testdata/bad/impressum-no-page-contents.yaml

diff --git a/lib/policy/config/testdata/bad/invalid.json b/lib/config/testdata/bad/invalid.json
rename from lib/policy/config/testdata/bad/invalid.json
rename to lib/config/testdata/bad/invalid.json
--- a/lib/policy/config/testdata/bad/invalid.json
+++ b/lib/config/testdata/bad/invalid.json

diff --git a/lib/policy/config/testdata/bad/invalid.yaml b/lib/config/testdata/bad/invalid.yaml
rename from lib/policy/config/testdata/bad/invalid.yaml
rename to lib/config/testdata/bad/invalid.yaml
--- a/lib/policy/config/testdata/bad/invalid.yaml
+++ b/lib/config/testdata/bad/invalid.yaml

diff --git a/lib/config/testdata/bad/logging-invalid-sink.yaml b/lib/config/testdata/bad/logging-invalid-sink.yaml
new file mode 100644
--- /dev/null
+++ b/lib/config/testdata/bad/logging-invalid-sink.yaml
@@ -0,0 +1,2 @@
+logging:
+  sink: "nope"
diff --git a/lib/config/testdata/bad/logging-no-parameters.yaml b/lib/config/testdata/bad/logging-no-parameters.yaml
new file mode 100644
--- /dev/null
+++ b/lib/config/testdata/bad/logging-no-parameters.yaml
@@ -0,0 +1,2 @@
+logging:
+  sink: "file"
diff --git a/lib/policy/config/testdata/bad/multiple_expression_types.json b/lib/config/testdata/bad/multiple_expression_types.json
rename from lib/policy/config/testdata/bad/multiple_expression_types.json
rename to lib/config/testdata/bad/multiple_expression_types.json
--- a/lib/policy/config/testdata/bad/multiple_expression_types.json
+++ b/lib/config/testdata/bad/multiple_expression_types.json

diff --git a/lib/policy/config/testdata/bad/multiple_expression_types.yaml b/lib/config/testdata/bad/multiple_expression_types.yaml
rename from lib/policy/config/testdata/bad/multiple_expression_types.yaml
rename to lib/config/testdata/bad/multiple_expression_types.yaml
--- a/lib/policy/config/testdata/bad/multiple_expression_types.yaml
+++ b/lib/config/testdata/bad/multiple_expression_types.yaml

diff --git a/lib/policy/config/testdata/bad/nobots.json b/lib/config/testdata/bad/nobots.json
rename from lib/policy/config/testdata/bad/nobots.json
rename to lib/config/testdata/bad/nobots.json
--- a/lib/policy/config/testdata/bad/nobots.json
+++ b/lib/config/testdata/bad/nobots.json

diff --git a/lib/policy/config/testdata/bad/nobots.yaml b/lib/config/testdata/bad/nobots.yaml
rename from lib/policy/config/testdata/bad/nobots.yaml
rename to lib/config/testdata/bad/nobots.yaml
--- a/lib/policy/config/testdata/bad/nobots.yaml
+++ b/lib/config/testdata/bad/nobots.yaml

diff --git a/lib/policy/config/testdata/bad/opengraph_bad_ttl.yaml b/lib/config/testdata/bad/opengraph_bad_ttl.yaml
rename from lib/policy/config/testdata/bad/opengraph_bad_ttl.yaml
rename to lib/config/testdata/bad/opengraph_bad_ttl.yaml
--- a/lib/policy/config/testdata/bad/opengraph_bad_ttl.yaml
+++ b/lib/config/testdata/bad/opengraph_bad_ttl.yaml

diff --git a/lib/policy/config/testdata/bad/regex_ends_newline.json b/lib/config/testdata/bad/regex_ends_newline.json
rename from lib/policy/config/testdata/bad/regex_ends_newline.json
rename to lib/config/testdata/bad/regex_ends_newline.json
--- a/lib/policy/config/testdata/bad/regex_ends_newline.json
+++ b/lib/config/testdata/bad/regex_ends_newline.json

diff --git a/lib/policy/config/testdata/bad/regex_ends_newline.yaml b/lib/config/testdata/bad/regex_ends_newline.yaml
rename from lib/policy/config/testdata/bad/regex_ends_newline.yaml
rename to lib/config/testdata/bad/regex_ends_newline.yaml
--- a/lib/policy/config/testdata/bad/regex_ends_newline.yaml
+++ b/lib/config/testdata/bad/regex_ends_newline.yaml

diff --git a/lib/policy/config/testdata/bad/status-codes-0.json b/lib/config/testdata/bad/status-codes-0.json
rename from lib/policy/config/testdata/bad/status-codes-0.json
rename to lib/config/testdata/bad/status-codes-0.json
--- a/lib/policy/config/testdata/bad/status-codes-0.json
+++ b/lib/config/testdata/bad/status-codes-0.json

diff --git a/lib/policy/config/testdata/bad/status-codes-0.yaml b/lib/config/testdata/bad/status-codes-0.yaml
rename from lib/policy/config/testdata/bad/status-codes-0.yaml
rename to lib/config/testdata/bad/status-codes-0.yaml
--- a/lib/policy/config/testdata/bad/status-codes-0.yaml
+++ b/lib/config/testdata/bad/status-codes-0.yaml

diff --git a/lib/policy/config/testdata/bad/threshold-challenge-without-challenge.yaml b/lib/config/testdata/bad/threshold-challenge-without-challenge.yaml
rename from lib/policy/config/testdata/bad/threshold-challenge-without-challenge.yaml
rename to lib/config/testdata/bad/threshold-challenge-without-challenge.yaml
--- a/lib/policy/config/testdata/bad/threshold-challenge-without-challenge.yaml
+++ b/lib/config/testdata/bad/threshold-challenge-without-challenge.yaml

diff --git a/lib/policy/config/testdata/bad/thresholds.yaml b/lib/config/testdata/bad/thresholds.yaml
rename from lib/policy/config/testdata/bad/thresholds.yaml
rename to lib/config/testdata/bad/thresholds.yaml
--- a/lib/policy/config/testdata/bad/thresholds.yaml
+++ b/lib/config/testdata/bad/thresholds.yaml

diff --git a/lib/policy/config/testdata/bad/unparseable.json b/lib/config/testdata/bad/unparseable.json
rename from lib/policy/config/testdata/bad/unparseable.json
rename to lib/config/testdata/bad/unparseable.json
--- a/lib/policy/config/testdata/bad/unparseable.json
+++ b/lib/config/testdata/bad/unparseable.json

diff --git a/lib/policy/config/testdata/bad/unparseable.yaml b/lib/config/testdata/bad/unparseable.yaml
rename from lib/policy/config/testdata/bad/unparseable.yaml
rename to lib/config/testdata/bad/unparseable.yaml
--- a/lib/policy/config/testdata/bad/unparseable.yaml
+++ b/lib/config/testdata/bad/unparseable.yaml

diff --git a/lib/policy/config/testdata/good/allow_everyone.json b/lib/config/testdata/good/allow_everyone.json
rename from lib/policy/config/testdata/good/allow_everyone.json
rename to lib/config/testdata/good/allow_everyone.json
--- a/lib/policy/config/testdata/good/allow_everyone.json
+++ b/lib/config/testdata/good/allow_everyone.json

diff --git a/lib/policy/config/testdata/good/allow_everyone.yaml b/lib/config/testdata/good/allow_everyone.yaml
rename from lib/policy/config/testdata/good/allow_everyone.yaml
rename to lib/config/testdata/good/allow_everyone.yaml
--- a/lib/policy/config/testdata/good/allow_everyone.yaml
+++ b/lib/config/testdata/good/allow_everyone.yaml

diff --git a/lib/policy/config/testdata/good/block_cf_workers.json b/lib/config/testdata/good/block_cf_workers.json
rename from lib/policy/config/testdata/good/block_cf_workers.json
rename to lib/config/testdata/good/block_cf_workers.json
--- a/lib/policy/config/testdata/good/block_cf_workers.json
+++ b/lib/config/testdata/good/block_cf_workers.json

diff --git a/lib/policy/config/testdata/good/block_cf_workers.yaml b/lib/config/testdata/good/block_cf_workers.yaml
rename from lib/policy/config/testdata/good/block_cf_workers.yaml
rename to lib/config/testdata/good/block_cf_workers.yaml
--- a/lib/policy/config/testdata/good/block_cf_workers.yaml
+++ b/lib/config/testdata/good/block_cf_workers.yaml

diff --git a/lib/policy/config/testdata/good/challenge_cloudflare.yaml b/lib/config/testdata/good/challenge_cloudflare.yaml
rename from lib/policy/config/testdata/good/challenge_cloudflare.yaml
rename to lib/config/testdata/good/challenge_cloudflare.yaml
--- a/lib/policy/config/testdata/good/challenge_cloudflare.yaml
+++ b/lib/config/testdata/good/challenge_cloudflare.yaml

diff --git a/lib/policy/config/testdata/good/challengemozilla.json b/lib/config/testdata/good/challengemozilla.json
rename from lib/policy/config/testdata/good/challengemozilla.json
rename to lib/config/testdata/good/challengemozilla.json
--- a/lib/policy/config/testdata/good/challengemozilla.json
+++ b/lib/config/testdata/good/challengemozilla.json

diff --git a/lib/policy/config/testdata/good/challengemozilla.yaml b/lib/config/testdata/good/challengemozilla.yaml
rename from lib/policy/config/testdata/good/challengemozilla.yaml
rename to lib/config/testdata/good/challengemozilla.yaml
--- a/lib/policy/config/testdata/good/challengemozilla.yaml
+++ b/lib/config/testdata/good/challengemozilla.yaml

diff --git a/lib/policy/config/testdata/good/entropy.yaml b/lib/config/testdata/good/entropy.yaml
rename from lib/policy/config/testdata/good/entropy.yaml
rename to lib/config/testdata/good/entropy.yaml
--- a/lib/policy/config/testdata/good/entropy.yaml
+++ b/lib/config/testdata/good/entropy.yaml

diff --git a/lib/policy/config/testdata/good/everything_blocked.json b/lib/config/testdata/good/everything_blocked.json
rename from lib/policy/config/testdata/good/everything_blocked.json
rename to lib/config/testdata/good/everything_blocked.json
--- a/lib/policy/config/testdata/good/everything_blocked.json
+++ b/lib/config/testdata/good/everything_blocked.json

diff --git a/lib/policy/config/testdata/good/everything_blocked.yaml b/lib/config/testdata/good/everything_blocked.yaml
rename from lib/policy/config/testdata/good/everything_blocked.yaml
rename to lib/config/testdata/good/everything_blocked.yaml
--- a/lib/policy/config/testdata/good/everything_blocked.yaml
+++ b/lib/config/testdata/good/everything_blocked.yaml

diff --git a/lib/policy/config/testdata/good/geoip_us.yaml b/lib/config/testdata/good/geoip_us.yaml
rename from lib/policy/config/testdata/good/geoip_us.yaml
rename to lib/config/testdata/good/geoip_us.yaml
--- a/lib/policy/config/testdata/good/geoip_us.yaml
+++ b/lib/config/testdata/good/geoip_us.yaml

diff --git a/lib/policy/config/testdata/good/git_client.json b/lib/config/testdata/good/git_client.json
rename from lib/policy/config/testdata/good/git_client.json
rename to lib/config/testdata/good/git_client.json
--- a/lib/policy/config/testdata/good/git_client.json
+++ b/lib/config/testdata/good/git_client.json

diff --git a/lib/policy/config/testdata/good/git_client.yaml b/lib/config/testdata/good/git_client.yaml
rename from lib/policy/config/testdata/good/git_client.yaml
rename to lib/config/testdata/good/git_client.yaml
--- a/lib/policy/config/testdata/good/git_client.yaml
+++ b/lib/config/testdata/good/git_client.yaml

diff --git a/lib/policy/config/testdata/good/import_filesystem.json b/lib/config/testdata/good/import_filesystem.json
rename from lib/policy/config/testdata/good/import_filesystem.json
rename to lib/config/testdata/good/import_filesystem.json
--- a/lib/policy/config/testdata/good/import_filesystem.json
+++ b/lib/config/testdata/good/import_filesystem.json

diff --git a/lib/policy/config/testdata/good/import_filesystem.yaml b/lib/config/testdata/good/import_filesystem.yaml
rename from lib/policy/config/testdata/good/import_filesystem.yaml
rename to lib/config/testdata/good/import_filesystem.yaml
--- a/lib/policy/config/testdata/good/import_filesystem.yaml
+++ b/lib/config/testdata/good/import_filesystem.yaml

diff --git a/lib/policy/config/testdata/good/import_keep_internet_working.json b/lib/config/testdata/good/import_keep_internet_working.json
rename from lib/policy/config/testdata/good/import_keep_internet_working.json
rename to lib/config/testdata/good/import_keep_internet_working.json
--- a/lib/policy/config/testdata/good/import_keep_internet_working.json
+++ b/lib/config/testdata/good/import_keep_internet_working.json

diff --git a/lib/policy/config/testdata/good/import_keep_internet_working.yaml b/lib/config/testdata/good/import_keep_internet_working.yaml
rename from lib/policy/config/testdata/good/import_keep_internet_working.yaml
rename to lib/config/testdata/good/import_keep_internet_working.yaml
--- a/lib/policy/config/testdata/good/import_keep_internet_working.yaml
+++ b/lib/config/testdata/good/import_keep_internet_working.yaml

diff --git a/lib/policy/config/testdata/good/impressum.yaml b/lib/config/testdata/good/impressum.yaml
rename from lib/policy/config/testdata/good/impressum.yaml
rename to lib/config/testdata/good/impressum.yaml
--- a/lib/policy/config/testdata/good/impressum.yaml
+++ b/lib/config/testdata/good/impressum.yaml

diff --git a/lib/config/testdata/good/logging-file.yaml b/lib/config/testdata/good/logging-file.yaml
new file mode 100644
--- /dev/null
+++ b/lib/config/testdata/good/logging-file.yaml
@@ -0,0 +1,15 @@
+bots:
+  - name: simple
+    action: CHALLENGE
+    user_agent_regex: Mozilla
+
+logs:
+  sink: "file"
+  parameters:
+    file: "/var/log/botstopper/default.log"
+    maxBackups: 3 # keep at least 3 old copies
+    maxBytes: 67108864 # each file can have up to 64 MB of logs
+    maxAge: 7 # rotate files out every n days
+    oldFileTimeFormat: 2006-01-02T15-04-05 # RFC 3339-ish
+    compress: true
+    useLocalTime: false # timezone for rotated files is UTC
diff --git a/lib/config/testdata/good/logging-stdio.yaml b/lib/config/testdata/good/logging-stdio.yaml
new file mode 100644
--- /dev/null
+++ b/lib/config/testdata/good/logging-stdio.yaml
@@ -0,0 +1,7 @@
+bots:
+  - name: simple
+    action: CHALLENGE
+    user_agent_regex: Mozilla
+
+logging:
+  sink: "stdio"
diff --git a/lib/policy/config/testdata/good/no-thresholds.yaml b/lib/config/testdata/good/no-thresholds.yaml
rename from lib/policy/config/testdata/good/no-thresholds.yaml
rename to lib/config/testdata/good/no-thresholds.yaml
--- a/lib/policy/config/testdata/good/no-thresholds.yaml
+++ b/lib/config/testdata/good/no-thresholds.yaml

diff --git a/lib/policy/config/testdata/good/old_xesite.json b/lib/config/testdata/good/old_xesite.json
rename from lib/policy/config/testdata/good/old_xesite.json
rename to lib/config/testdata/good/old_xesite.json
--- a/lib/policy/config/testdata/good/old_xesite.json
+++ b/lib/config/testdata/good/old_xesite.json

diff --git a/lib/policy/config/testdata/good/opengraph_all_good.yaml b/lib/config/testdata/good/opengraph_all_good.yaml
rename from lib/policy/config/testdata/good/opengraph_all_good.yaml
rename to lib/config/testdata/good/opengraph_all_good.yaml
--- a/lib/policy/config/testdata/good/opengraph_all_good.yaml
+++ b/lib/config/testdata/good/opengraph_all_good.yaml

diff --git a/lib/policy/config/testdata/good/simple-weight.yaml b/lib/config/testdata/good/simple-weight.yaml
rename from lib/policy/config/testdata/good/simple-weight.yaml
rename to lib/config/testdata/good/simple-weight.yaml
--- a/lib/policy/config/testdata/good/simple-weight.yaml
+++ b/lib/config/testdata/good/simple-weight.yaml

diff --git a/lib/policy/config/testdata/good/status-codes-paranoid.json b/lib/config/testdata/good/status-codes-paranoid.json
rename from lib/policy/config/testdata/good/status-codes-paranoid.json
rename to lib/config/testdata/good/status-codes-paranoid.json
--- a/lib/policy/config/testdata/good/status-codes-paranoid.json
+++ b/lib/config/testdata/good/status-codes-paranoid.json

diff --git a/lib/policy/config/testdata/good/status-codes-paranoid.yaml b/lib/config/testdata/good/status-codes-paranoid.yaml
rename from lib/policy/config/testdata/good/status-codes-paranoid.yaml
rename to lib/config/testdata/good/status-codes-paranoid.yaml
--- a/lib/policy/config/testdata/good/status-codes-paranoid.yaml
+++ b/lib/config/testdata/good/status-codes-paranoid.yaml

diff --git a/lib/policy/config/testdata/good/status-codes-rfc.json b/lib/config/testdata/good/status-codes-rfc.json
rename from lib/policy/config/testdata/good/status-codes-rfc.json
rename to lib/config/testdata/good/status-codes-rfc.json
--- a/lib/policy/config/testdata/good/status-codes-rfc.json
+++ b/lib/config/testdata/good/status-codes-rfc.json

diff --git a/lib/policy/config/testdata/good/status-codes-rfc.yaml b/lib/config/testdata/good/status-codes-rfc.yaml
rename from lib/policy/config/testdata/good/status-codes-rfc.yaml
rename to lib/config/testdata/good/status-codes-rfc.yaml
--- a/lib/policy/config/testdata/good/status-codes-rfc.yaml
+++ b/lib/config/testdata/good/status-codes-rfc.yaml

diff --git a/lib/policy/config/testdata/good/thresholds.yaml b/lib/config/testdata/good/thresholds.yaml
rename from lib/policy/config/testdata/good/thresholds.yaml
rename to lib/config/testdata/good/thresholds.yaml
--- a/lib/policy/config/testdata/good/thresholds.yaml
+++ b/lib/config/testdata/good/thresholds.yaml

diff --git a/lib/policy/config/testdata/good/weight-no-weight.yaml b/lib/config/testdata/good/weight-no-weight.yaml
rename from lib/policy/config/testdata/good/weight-no-weight.yaml
rename to lib/config/testdata/good/weight-no-weight.yaml
--- a/lib/policy/config/testdata/good/weight-no-weight.yaml
+++ b/lib/config/testdata/good/weight-no-weight.yaml

diff --git a/lib/policy/config/testdata/hack-test.json b/lib/config/testdata/hack-test.json
rename from lib/policy/config/testdata/hack-test.json
rename to lib/config/testdata/hack-test.json
--- a/lib/policy/config/testdata/hack-test.json
+++ b/lib/config/testdata/hack-test.json

diff --git a/lib/policy/config/testdata/hack-test.yaml b/lib/config/testdata/hack-test.yaml
rename from lib/policy/config/testdata/hack-test.yaml
rename to lib/config/testdata/hack-test.yaml
--- a/lib/policy/config/testdata/hack-test.yaml
+++ b/lib/config/testdata/hack-test.yaml

diff --git a/lib/policy/config/threshold_test.go b/lib/config/threshold_test.go
rename from lib/policy/config/threshold_test.go
rename to lib/config/threshold_test.go
--- a/lib/policy/config/threshold_test.go
+++ b/lib/config/threshold_test.go

diff --git a/lib/config_test.go b/lib/config_test.go
--- a/lib/config_test.go
+++ b/lib/config_test.go
@@ -12,21 +12,21 @@ import (
 )
 
 func TestInvalidChallengeMethod(t *testing.T) {
-	if _, err := LoadPoliciesOrDefault(t.Context(), "testdata/invalid-challenge-method.yaml", 4); !errors.Is(err, policy.ErrChallengeRuleHasWrongAlgorithm) {
+	if _, err := LoadPoliciesOrDefault(t.Context(), "testdata/invalid-challenge-method.yaml", 4, "info"); !errors.Is(err, policy.ErrChallengeRuleHasWrongAlgorithm) {
 		t.Fatalf("wanted error %v but got %v", policy.ErrChallengeRuleHasWrongAlgorithm, err)
 	}
 }
 
 func TestBadConfigs(t *testing.T) {
-	finfos, err := os.ReadDir("policy/config/testdata/bad")
+	finfos, err := os.ReadDir("config/testdata/bad")
 	if err != nil {
 		t.Fatal(err)
 	}
 
 	for _, st := range finfos {
 		st := st
 		t.Run(st.Name(), func(t *testing.T) {
-			if _, err := LoadPoliciesOrDefault(t.Context(), filepath.Join("policy", "config", "testdata", "bad", st.Name()), anubis.DefaultDifficulty); err == nil {
+			if _, err := LoadPoliciesOrDefault(t.Context(), filepath.Join("config", "testdata", "bad", st.Name()), anubis.DefaultDifficulty, "info"); err == nil {
 				t.Fatal(err)
 			} else {
 				t.Log(err)
@@ -36,7 +36,7 @@ func TestBadConfigs(t *testing.T) {
 }
 
 func TestGoodConfigs(t *testing.T) {
-	finfos, err := os.ReadDir("policy/config/testdata/good")
+	finfos, err := os.ReadDir("config/testdata/good")
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -46,13 +46,13 @@ func TestGoodConfigs(t *testing.T) {
 		t.Run(st.Name(), func(t *testing.T) {
 			t.Run("with-thoth", func(t *testing.T) {
 				ctx := thothmock.WithMockThoth(t)
-				if _, err := LoadPoliciesOrDefault(ctx, filepath.Join("policy", "config", "testdata", "good", st.Name()), anubis.DefaultDifficulty); err != nil {
+				if _, err := LoadPoliciesOrDefault(ctx, filepath.Join("config", "testdata", "good", st.Name()), anubis.DefaultDifficulty, "info"); err != nil {
 					t.Fatal(err)
 				}
 			})
 
 			t.Run("without-thoth", func(t *testing.T) {
-				if _, err := LoadPoliciesOrDefault(t.Context(), filepath.Join("policy", "config", "testdata", "good", st.Name()), anubis.DefaultDifficulty); err != nil {
+				if _, err := LoadPoliciesOrDefault(t.Context(), filepath.Join("config", "testdata", "good", st.Name()), anubis.DefaultDifficulty, "info"); err != nil {
 					t.Fatal(err)
 				}
 			})
diff --git a/lib/policy/policy_test.go b/lib/policy/policy_test.go
--- a/lib/policy/policy_test.go
+++ b/lib/policy/policy_test.go
@@ -19,14 +19,14 @@ func TestDefaultPolicyMustParse(t *testing.T) {
 	}
 	defer fin.Close()
 
-	if _, err := ParseConfig(ctx, fin, "botPolicies.yaml", anubis.DefaultDifficulty); err != nil {
+	if _, err := ParseConfig(ctx, fin, "botPolicies.yaml", anubis.DefaultDifficulty, "info"); err != nil {
 		t.Fatalf("can't parse config: %v", err)
 	}
 }
 
 func TestGoodConfigs(t *testing.T) {
 
-	finfos, err := os.ReadDir("config/testdata/good")
+	finfos, err := os.ReadDir("../config/testdata/good")
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -35,26 +35,26 @@ func TestGoodConfigs(t *testing.T) {
 		st := st
 		t.Run(st.Name(), func(t *testing.T) {
 			t.Run("with-thoth", func(t *testing.T) {
-				fin, err := os.Open(filepath.Join("config", "testdata", "good", st.Name()))
+				fin, err := os.Open(filepath.Join("..", "config", "testdata", "good", st.Name()))
 				if err != nil {
 					t.Fatal(err)
 				}
 				defer fin.Close()
 
 				ctx := thothmock.WithMockThoth(t)
-				if _, err := ParseConfig(ctx, fin, fin.Name(), anubis.DefaultDifficulty); err != nil {
+				if _, err := ParseConfig(ctx, fin, fin.Name(), anubis.DefaultDifficulty, "info"); err != nil {
 					t.Fatal(err)
 				}
 			})
 
 			t.Run("without-thoth", func(t *testing.T) {
-				fin, err := os.Open(filepath.Join("config", "testdata", "good", st.Name()))
+				fin, err := os.Open(filepath.Join("..", "config", "testdata", "good", st.Name()))
 				if err != nil {
 					t.Fatal(err)
 				}
 				defer fin.Close()
 
-				if _, err := ParseConfig(t.Context(), fin, fin.Name(), anubis.DefaultDifficulty); err != nil {
+				if _, err := ParseConfig(t.Context(), fin, fin.Name(), anubis.DefaultDifficulty, "info"); err != nil {
 					t.Fatal(err)
 				}
 			})
@@ -65,21 +65,21 @@ func TestGoodConfigs(t *testing.T) {
 func TestBadConfigs(t *testing.T) {
 	ctx := thothmock.WithMockThoth(t)
 
-	finfos, err := os.ReadDir("config/testdata/bad")
+	finfos, err := os.ReadDir("../config/testdata/bad")
 	if err != nil {
 		t.Fatal(err)
 	}
 
 	for _, st := range finfos {
 		st := st
 		t.Run(st.Name(), func(t *testing.T) {
-			fin, err := os.Open(filepath.Join("config", "testdata", "bad", st.Name()))
+			fin, err := os.Open(filepath.Join("..", "config", "testdata", "bad", st.Name()))
 			if err != nil {
 				t.Fatal(err)
 			}
 			defer fin.Close()
 
-			if _, err := ParseConfig(ctx, fin, fin.Name(), anubis.DefaultDifficulty); err == nil {
+			if _, err := ParseConfig(ctx, fin, fin.Name(), anubis.DefaultDifficulty, "info"); err == nil {
 				t.Fatal(err)
 			} else {
 				t.Log(err)
diff --git a/test/go.mod b/test/go.mod
--- a/test/go.mod
+++ b/test/go.mod
@@ -42,11 +42,13 @@ require (
 	github.com/containerd/errdefs/pkg v0.3.0 // indirect
 	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
 	github.com/distribution/reference v0.6.0 // indirect
+	github.com/djherbis/times v1.6.0 // indirect
 	github.com/docker/go-connections v0.6.0 // indirect
 	github.com/docker/go-units v0.5.0 // indirect
 	github.com/ebitengine/purego v0.9.1 // indirect
 	github.com/facebookgo/ensure v0.0.0-20200202191622-63f1cf65ac4c // indirect
 	github.com/facebookgo/subset v0.0.0-20200203212716-c811ad88dec4 // indirect
+	github.com/fahedouch/go-logrotate v0.3.0 // indirect
 	github.com/felixge/httpsnoop v1.0.4 // indirect
 	github.com/gaissmai/bart v0.26.0 // indirect
 	github.com/go-logr/logr v1.4.3 // indirect
diff --git a/test/go.sum b/test/go.sum
--- a/test/go.sum
+++ b/test/go.sum
@@ -82,6 +82,8 @@ github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f h1:lO4WD4F/r
 github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f/go.mod h1:cuUVRXasLTGF7a8hSLbxyZXjz+1KgoB3wDUb6vlszIc=
 github.com/distribution/reference v0.6.0 h1:0IXCQ5g4/QMHHkarYzh5l+u8T3t73zM5QvfrDyIgxBk=
 github.com/distribution/reference v0.6.0/go.mod h1:BbU0aIcezP1/5jX/8MP0YiH4SdvB5Y4f/wlDRiLyi3E=
+github.com/djherbis/times v1.6.0 h1:w2ctJ92J8fBvWPxugmXIv7Nz7Q3iDMKNx9v5ocVH20c=
+github.com/djherbis/times v1.6.0/go.mod h1:gOHeRAz2h+VJNZ5Gmc/o7iD9k4wW7NMVqieYCY99oc0=
 github.com/docker/docker v28.5.2+incompatible h1:DBX0Y0zAjZbSrm1uzOkdr1onVghKaftjlSWt4AFexzM=
 github.com/docker/docker v28.5.2+incompatible/go.mod h1:eEKB0N0r5NX/I1kEveEz05bcu8tLC/8azJZsviup8Sk=
 github.com/docker/go-connections v0.6.0 h1:LlMG9azAe1TqfR7sO+NJttz1gy6KO7VJBh+pMmjSD94=
@@ -98,6 +100,8 @@ github.com/facebookgo/stack v0.0.0-20160209184415-751773369052 h1:JWuenKqqX8nojt
 github.com/facebookgo/stack v0.0.0-20160209184415-751773369052/go.mod h1:UbMTZqLaRiH3MsBH8va0n7s1pQYcu3uTb8G4tygF4Zg=
 github.com/facebookgo/subset v0.0.0-20200203212716-c811ad88dec4 h1:7HZCaLC5+BZpmbhCOZJ293Lz68O7PYrF2EzeiFMwCLk=
 github.com/facebookgo/subset v0.0.0-20200203212716-c811ad88dec4/go.mod h1:5tD+neXqOorC30/tWg0LCSkrqj/AR6gu8yY8/fpw1q0=
+github.com/fahedouch/go-logrotate v0.3.0 h1:XP+dHIDgWZ1ckz43mG6gl5ASer3PZDVr755SVMyzaUQ=
+github.com/fahedouch/go-logrotate v0.3.0/go.mod h1:X49m0bvPLkk71MHNCQ1yEfVEw8W/u+qvHa/hOnhCYf4=
 github.com/felixge/httpsnoop v1.0.4 h1:NFTV2Zj1bL4mc9sqWACXbQFVBBg2W3GPvqp8/ESS2Wg=
 github.com/felixge/httpsnoop v1.0.4/go.mod h1:m8KPJKqk1gH5J9DgRY2ASl2lWCfGKXixSwevea8zH2U=
 github.com/gaissmai/bart v0.26.0 h1:xOZ57E9hJLBiQaSyeZa9wgWhGuzfGACgqp4BE77OkO0=
@@ -251,6 +255,7 @@ golang.org/x/sync v0.18.0 h1:kr88TuHDroi+UVf+0hZnirlk8o8T+4MrK6mr60WkH/I=
 golang.org/x/sync v0.18.0/go.mod h1:9KTHXmSnoGruLpwFjVSX0lNNA75CykiMECbovNTZqGI=
 golang.org/x/sys v0.0.0-20190916202348-b4ddaad3f8a3/go.mod h1:h1NjWce9XRLGQEsW7wpKNCjG9DtNlClVuFLEZdDNbEs=
 golang.org/x/sys v0.0.0-20201204225414-ed752295db88/go.mod h1:h1NjWce9XRLGQEsW7wpKNCjG9DtNlClVuFLEZdDNbEs=
+golang.org/x/sys v0.0.0-20220615213510-4f61da869c0c/go.mod h1:oPkhp1MJrh7nUepCBck5+mAzfO9JrbApNNgaTdGDITg=
 golang.org/x/sys v0.1.0/go.mod h1:oPkhp1MJrh7nUepCBck5+mAzfO9JrbApNNgaTdGDITg=
 golang.org/x/sys v0.38.0 h1:3yZWxaJjBmCWXqhN1qh02AkOnCQ1poK6oF+a7xWL6Gc=
 golang.org/x/sys v0.38.0/go.mod h1:OgkHotnGiDImocRcuBABYBEXf8A9a87e/uXjp9XT3ks=
@@ -271,6 +276,8 @@ google.golang.org/protobuf v1.36.10/go.mod h1:HTf+CrKn2C3g5S8VImy6tdcUvCska2kB7j
 gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405/go.mod h1:Co6ibVJAznAaIkqp8huTwlJQCZ016jof/cbN4VW5Yz0=
 gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c h1:Hei/4ADfdWqJk1ZMxUNpqntNwaWcugrBjAiHlqqRiVk=
 gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c/go.mod h1:JHkPIbrfpd72SG/EVd6muEfDQjcINNoR0C8j2r3qZ4Q=
+gopkg.in/yaml.v2 v2.4.0 h1:D8xgwECY7CYvx+Y2n4sBz93Jn9JRvxdiyyo8CTfuKaY=
+gopkg.in/yaml.v2 v2.4.0/go.mod h1:RDklbk79AGWmwhnvt/jBztapEOGDOx6ZbXqjP6csGnQ=
 gopkg.in/yaml.v3 v3.0.0-20200313102051-9f266ea9e77c/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
 gopkg.in/yaml.v3 v3.0.1 h1:fxVm/GzAzEWqLHuvctI91KS9hhNmmWOoWu0XTYJS7CA=
 gopkg.in/yaml.v3 v3.0.1/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
diff --git a/test/log-file/anubis.yaml b/test/log-file/anubis.yaml
new file mode 100644
--- /dev/null
+++ b/test/log-file/anubis.yaml
@@ -0,0 +1,18 @@
+bots:
+  - name: challenge
+    user_agent_regex: CHALLENGE
+    action: CHALLENGE
+
+status_codes:
+  CHALLENGE: 200
+  DENY: 403
+
+logging:
+  sink: file
+  parameters:
+    file: "./var/anubis.log"
+    maxBackups: 3 # keep at least 3 old copies
+    maxBytes: 67108864 # each file can have up to 64 Mi of logs
+    maxAge: 7 # rotate files out every n days
+    compress: true
+    useLocalTime: false # timezone for rotated files is UTC
diff --git a/test/log-file/input.txt b/test/log-file/input.txt
new file mode 100644
--- /dev/null
+++ b/test/log-file/input.txt
@@ -0,0 +1,178 @@
+/wiki//bin
+/wiki//boot
+/wiki//dev
+/wiki//dev/de
+/wiki//dev/en
+/wiki//dev/en-ca
+/wiki//dev/es
+/wiki//dev/fr
+/wiki//dev/hr
+/wiki//dev/hu
+/wiki//dev/it
+/wiki//dev/ja
+/wiki//dev/ko
+/wiki//dev/pl
+/wiki//dev/pt-br
+/wiki//dev/ro
+/wiki//dev/ru
+/wiki//dev/sv
+/wiki//dev/uk
+/wiki//dev/zh-cn
+/wiki//etc
+/wiki//etc/conf.d
+/wiki//etc/env.d
+/wiki//etc/fstab
+/wiki//etc/fstab/de
+/wiki//etc/fstab/en
+/wiki//etc/fstab/es
+/wiki//etc/fstab/fr
+/wiki//etc/fstab/hu
+/wiki//etc/fstab/it
+/wiki//etc/fstab/ja
+/wiki//etc/fstab/ko
+/wiki//etc/fstab/ru
+/wiki//etc/fstab/sv
+/wiki//etc/fstab/uk
+/wiki//etc/fstab/zh-cn
+/wiki//etc/hosts
+/wiki//etc/local.d
+/wiki//etc/make.conf
+/wiki//etc/portage
+/wiki//etc/portage/bashrc
+/wiki//etc/portage/Bashrc
+/wiki//etc/portage/binrepos.conf
+/wiki//etc/portage/binrepos.conf/en
+/wiki//etc/portage/binrepos.conf/hu
+/wiki//etc/portage/binrepos.conf/ja
+/wiki//etc/portage/binrepos.conf/ru
+/wiki//etc/portage/categories
+/wiki//etc/portage/color.map
+/wiki//etc/portage/env
+/wiki//etc/portage/img/ico.png
+/wiki//etc/portage/license_groups
+/wiki//etc/portage/make.conf
+/wiki//etc/portage/make.conf/de
+/wiki//etc/portage/make.conf/de/etc/portage/make.conf
+/wiki//etc/portage/make.conf/en
+/wiki//etc/portage/make.conf/es
+/wiki//etc/portage/make.conf/fr
+/wiki//etc/portage/make.conf/hu
+/wiki//etc/portage/make.conf/it
+/wiki//etc/portage/make.conf/it/var/db/repos/gentoo/licenses
+/wiki//etc/portage/make.conf/ja
+/wiki//etc/portage/make.conf/pl
+/wiki//etc/portage/make.conf/ru
+/wiki//etc/portage/make.conf/uk
+/wiki//etc/portage/make.conf/zh-cn
+/wiki//etc/portage/make.profile
+/wiki//etc/portage/mirrors
+/wiki//etc/portage/modules
+/wiki//etc/portage/package.accept_keywords
+/wiki//etc/portage/package.env
+/wiki//etc/portage/package.license
+/wiki//etc/portage/package.license/en
+/wiki//etc/portage/package.license/es
+/wiki//etc/portage/package.license/hu
+/wiki//etc/portage/package.license/ja
+/wiki//etc/portage/package.mask
+/wiki//etc/portage/package.mask/en
+/wiki//etc/portage/package.mask/hu
+/wiki//etc/portage/package.mask/ja
+/wiki//etc/portage/package.properties
+/wiki//etc/portage/package.unmask
+/wiki//etc/portage/package.use
+/wiki//etc/portage/package.use/de
+/wiki//etc/portage/package.use/en
+/wiki//etc/portage/package.use/es
+/wiki//etc/portage/package.use/fr
+/wiki//etc/portage/package.use/hu
+/wiki//etc/portage/package.use/it
+/wiki//etc/portage/package.use/ja
+/wiki//etc/portage/package.use/ru
+/wiki//etc/portage/package.use/uk
+/wiki//etc/portage/package.use/zh-cn
+/wiki//etc/portage/patches
+/wiki//etc/portage/profile/make.defaults
+/wiki//etc/portage/profile/package.provided
+/wiki//etc/portage/profile/package.provided/etc/portage/profile/package.provided
+/wiki//etc/portage/profile/package.provided/etc/portage/profiles/package.provided
+/wiki//etc/portage/profile/package.use.mask
+/wiki//etc/portage/profiles/package.provided
+/wiki//etc/portage/profiles/package.use.mask
+/wiki//etc/portage/profiles/package.use.mask/etc/portage/profile/package.use.mask
+/wiki//etc/portage/profiles/package.use.mask/etc/portage/profiles/package.use.mask
+/wiki//etc/portage/profiles/use.mask
+/wiki//etc/portage/profile/use.mask
+/wiki//etc/portage/repos.conf
+/wiki//etc/portage/repos.conf/brother-overlay.conf
+/wiki//etc/portage/repos.conf/de
+/wiki//etc/portage/repos.conf/en
+/wiki//etc/portage/repos.conf/es
+/wiki//etc/portage/repos.conf/etc/portage/repos.conf/gentoo.conf
+/wiki//etc/portage/repos.conf/fr
+/wiki//etc/portage/repos.conf/fr/etc/portage/repos.conf/gentoo.conf
+/wiki//etc/portage/repos.conf/gentoo.conf
+/wiki//etc/portage/repos.conf/gentoo.conf/etc/portage/repos.conf/gentoo.conf
+/wiki//etc/portage/repos.conf/hr
+/wiki//etc/portage/repos.conf/hu
+/wiki//etc/portage/repos.conf/it
+/wiki//etc/portage/repos.conf/ja
+/wiki//etc/portage/repos.conf/ko
+/wiki//etc/portage/repos.conf/pl
+/wiki//etc/portage/repos.conf/pt-br
+/wiki//etc/portage/repos.conf/ru
+/wiki//etc/portage/repos.conf/uk
+/wiki//etc/portage/repos.conf/zh-cn
+/wiki//etc/portage/savedconfig
+/wiki//etc/portage/sets
+/wiki//etc/profile
+/wiki//etc/profile.env
+/wiki//etc/sandbox.conf
+/wiki//home
+/wiki//lib
+/wiki//lib64
+/wiki//media
+/wiki//mnt
+/wiki//opt
+/wiki//proc
+/wiki//proc/config.gz
+/wiki//run
+/wiki//sbin
+/wiki//srv
+/wiki//sys
+/wiki//tmp
+/wiki//usr
+/wiki//usr/bin
+/wiki//usr_move
+/wiki//usr/portage
+/wiki//usr/portage/distfiles
+/wiki//usr/portage/licenses
+/wiki//usr/portage/metadata
+/wiki//usr/portage/metadata/md5-cache
+/wiki//usr/portage/metadata/md5-cache/usr/portage/metadata/md5-cache
+/wiki//usr/portage/metadata/md5-cache/var/db/repos/gentoo//metadata/md5-cache
+/wiki//usr/portage/packages
+/wiki//usr/portage/profiles
+/wiki//usr/portage/profiles/license_groups
+/wiki//usr/portage/profiles/license_groups/usr/portage/profiles/license_groups
+/wiki//usr/portage/profiles/license_groups/var/db/repos/gentoo//profiles/license_groups
+/wiki//usr/share/doc/
+/wiki//var/cache/binpkgs
+/wiki//var/cache/distfiles
+/wiki//var/db/pkg
+/wiki//var/db/pkg%22
+/wiki//var/db/repos/gentoo
+/wiki//var/db/repos/gentoo/licenses
+/wiki//var/db/repos/gentoo/licenses/var/db/repos/gentoo//licenses
+/wiki//var/db/repos/gentoo/licenses/var/db/repos/gentoo/licenses
+/wiki//var/db/repos/gentoo/metadata
+/wiki//var/db/repos/gentoo/metadata/md5-cache
+/wiki//var/db/repos/gentoo/metadata/var/db/repos/gentoo//metadata
+/wiki//var/db/repos/gentoo/metadata/var/db/repos/gentoo/metadata
+/wiki//var/db/repos/gentoo/profiles
+/wiki//var/db/repos/gentoo/profiles/license_groups
+/wiki//var/db/repos/gentoo/profiles/package.mask
+/wiki//var/lib/portage
+/wiki//var/lib/portage/world
+/wiki//var/run
+/gcc-bugs/bug-122002-4@http.gcc.gnu.org%2Fbugzilla%2F/T/
\ No newline at end of file
diff --git a/test/log-file/test.mjs b/test/log-file/test.mjs
new file mode 100644
--- /dev/null
+++ b/test/log-file/test.mjs
@@ -0,0 +1,88 @@
+import { statSync } from "fs";
+
+async function getPage(path) {
+  return fetch(`http://localhost:8923${path}`, {
+    headers: {
+      'User-Agent': 'CHALLENGE'
+    }
+  })
+    .then(resp => {
+      if (resp.status !== 200) {
+        throw new Error(`wanted status 200, got status: ${resp.status}`);
+      }
+      return resp;
+    })
+    .then(resp => resp.text());
+}
+
+async function getFileSize(filePath) {
+  try {
+    return statSync(filePath).size;
+  } catch (error) {
+    return 0;
+  }
+}
+
+(async () => {
+  const logFilePath = "./var/anubis.log";
+
+  // Get initial log file size
+  const initialSize = await getFileSize(logFilePath);
+  console.log(`Initial log file size: ${initialSize} bytes`);
+
+  // Make 35 requests with different paths
+  const requests = [];
+  for (let i = 0; i < 35; i++) {
+    requests.push(`/test${i}`);
+  }
+
+  const resultSheet = {};
+  let failed = false;
+
+  for (const path of requests) {
+    try {
+      const resp = await getPage(path);
+      resultSheet[path] = {
+        success: true,
+        line: resp.split("\n")[0],
+      };
+    } catch (error) {
+      resultSheet[path] = {
+        success: false,
+        error: error.message,
+      };
+      console.log(`✗ Request to ${path} failed: ${error.message}`);
+      failed = true;
+    }
+  }
+
+  // Check final log file size
+  const finalSize = await getFileSize(logFilePath);
+  console.log(`Final log file size: ${finalSize} bytes`);
+  console.log(`Size increase: ${finalSize - initialSize} bytes`);
+
+  // Verify that log file size increased
+  if (finalSize <= initialSize) {
+    console.error("ERROR: Log file size did not increase after making requests!");
+    failed = true;
+  }
+
+  let successCount = 0;
+  for (let [k, v] of Object.entries(resultSheet)) {
+    if (!v.success) {
+      console.error({ path: k, error: v.error });
+    } else {
+      successCount++;
+    }
+  }
+
+  console.log(`Successful requests: ${successCount}/${requests.length}`);
+
+  if (failed) {
+    console.error("Test failed: Some requests failed or log file size did not increase");
+    process.exit(1);
+  } else {
+    console.log("Test passed: All requests succeeded and log file size increased");
+    process.exit(0);
+  }
+})();
\ No newline at end of file
diff --git a/test/log-file/test.sh b/test/log-file/test.sh
new file mode 100644
--- /dev/null
+++ b/test/log-file/test.sh
@@ -0,0 +1,25 @@
+#!/usr/bin/env bash
+
+set -euo pipefail
+
+function cleanup() {
+	pkill -P $$
+}
+
+trap cleanup EXIT SIGINT
+
+# Build static assets
+(cd ../.. && npm ci && npm run assets)
+
+go tool anubis --help 2>/dev/null || :
+
+go run ../cmd/httpdebug &
+
+go tool anubis \
+	--policy-fname ./anubis.yaml \
+	--use-remote-address \
+	--target=http://localhost:3923 &
+
+sleep 2
+
+backoff-retry node ./test.mjs
diff --git a/test/log-file/var/.gitignore b/test/log-file/var/.gitignore
new file mode 100644
--- /dev/null
+++ b/test/log-file/var/.gitignore
@@ -0,0 +1,2 @@
+*
+!.gitignore
\ No newline at end of file
EOF_114329324912

# Set environment variables for Go and testing
export GOPATH=/go
export PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
export CGO_ENABLED=1

# Ensure assets are built (in case not done in Dockerfile)
make assets || true

# Run the target tests
# Group tests by package to optimize execution
echo "=== Running internal/ogtags tests ==="
go test -v -p 1 ./internal/ogtags/

echo "=== Running internal/test tests ==="
go test -v -p 1 ./internal/test/

echo "=== Running lib tests ==="
go test -v -p 1 ./lib/

echo "=== Running lib/challenge/proofofwork tests ==="
go test -v -p 1 ./lib/challenge/proofofwork/

echo "=== Running lib/policy/config tests ==="
go test -v -p 1 ./lib/policy/config/

echo "=== Running lib/policy tests ==="
go test -v -p 1 ./lib/policy/

# Capture the final exit code
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout a709a2b2daecea6b893de6bb4224bab85ae200d8 ".github/workflows/smoke-tests.yml" "internal/ogtags/cache_test.go" "internal/ogtags/fetch_test.go" "internal/ogtags/integration_test.go" "internal/ogtags/mem_test.go" "internal/ogtags/ogtags_fuzz_test.go" "internal/ogtags/ogtags_test.go" "internal/ogtags/parse_test.go" "internal/test/playwright_test.go" "lib/anubis_test.go" "lib/challenge/proofofwork/proofofwork_test.go" "lib/policy/config/asn_test.go" "lib/policy/config/config_test.go" "lib/policy/config/expressionorlist_test.go" "lib/policy/config/geoip_test.go" "lib/policy/config/impressum_test.go" "lib/policy/config/opengraph_test.go" "lib/policy/config/store_test.go" "lib/policy/config/testdata/bad/badregexes.json" "lib/policy/config/testdata/bad/badregexes.yaml" "lib/policy/config/testdata/bad/import_and_bot.json" "lib/policy/config/testdata/bad/import_and_bot.yaml" "lib/policy/config/testdata/bad/import_invalid_file.json" "lib/policy/config/testdata/bad/import_invalid_file.yaml" "lib/policy/config/testdata/bad/impressum-no-footer.yaml" "lib/policy/config/testdata/bad/impressum-no-page-contents.yaml" "lib/policy/config/testdata/bad/invalid.json" "lib/policy/config/testdata/bad/invalid.yaml" "lib/policy/config/testdata/bad/multiple_expression_types.json" "lib/policy/config/testdata/bad/multiple_expression_types.yaml" "lib/policy/config/testdata/bad/nobots.json" "lib/policy/config/testdata/bad/nobots.yaml" "lib/policy/config/testdata/bad/opengraph_bad_ttl.yaml" "lib/policy/config/testdata/bad/regex_ends_newline.json" "lib/policy/config/testdata/bad/regex_ends_newline.yaml" "lib/policy/config/testdata/bad/status-codes-0.json" "lib/policy/config/testdata/bad/status-codes-0.yaml" "lib/policy/config/testdata/bad/threshold-challenge-without-challenge.yaml" "lib/policy/config/testdata/bad/thresholds.yaml" "lib/policy/config/testdata/bad/unparseable.json" "lib/policy/config/testdata/bad/unparseable.yaml" "lib/policy/config/testdata/good/allow_everyone.json" "lib/policy/config/testdata/good/allow_everyone.yaml" "lib/policy/config/testdata/good/block_cf_workers.json" "lib/policy/config/testdata/good/block_cf_workers.yaml" "lib/policy/config/testdata/good/challenge_cloudflare.yaml" "lib/policy/config/testdata/good/challengemozilla.json" "lib/policy/config/testdata/good/challengemozilla.yaml" "lib/policy/config/testdata/good/entropy.yaml" "lib/policy/config/testdata/good/everything_blocked.json" "lib/policy/config/testdata/good/everything_blocked.yaml" "lib/policy/config/testdata/good/geoip_us.yaml" "lib/policy/config/testdata/good/git_client.json" "lib/policy/config/testdata/good/git_client.yaml" "lib/policy/config/testdata/good/import_filesystem.json" "lib/policy/config/testdata/good/import_filesystem.yaml" "lib/policy/config/testdata/good/import_keep_internet_working.json" "lib/policy/config/testdata/good/import_keep_internet_working.yaml" "lib/policy/config/testdata/good/impressum.yaml" "lib/policy/config/testdata/good/no-thresholds.yaml" "lib/policy/config/testdata/good/old_xesite.json" "lib/policy/config/testdata/good/opengraph_all_good.yaml" "lib/policy/config/testdata/good/simple-weight.yaml" "lib/policy/config/testdata/good/status-codes-paranoid.json" "lib/policy/config/testdata/good/status-codes-paranoid.yaml" "lib/policy/config/testdata/good/status-codes-rfc.json" "lib/policy/config/testdata/good/status-codes-rfc.yaml" "lib/policy/config/testdata/good/thresholds.yaml" "lib/policy/config/testdata/good/weight-no-weight.yaml" "lib/policy/config/testdata/hack-test.json" "lib/policy/config/testdata/hack-test.yaml" "lib/policy/config/threshold_test.go" "lib/config_test.go" "lib/policy/policy_test.go" "test/go.mod" "test/go.sum"