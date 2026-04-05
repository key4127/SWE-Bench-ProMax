#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target expected output file to ensure clean state
git checkout ea61d3b6a9fecf0da6787f44b7b6b56d9754d7af "e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt"

# Apply test patch (this will modify the expected output file or test configuration)
git apply -v - <<'EOF_114329324912'
diff --git a/e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt b/e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt
--- a/e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt
+++ b/e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt
@@ -9,9 +9,9 @@
                   │                   │    │    │satellites│                   │transmitter│    │                        │    ┌───────┐     │   │            │                                         
                   │                   │    │    │          │───────send───────▶│           │────────────phone logs───────────▶│storage│     │   │            │                                         
                   │                   │    │    │          │───────send───────▶│           │    │                        │    └───────┘     │   │            │                                         
- ┌───────────┐    │                   │    │    └──────────┘                   └───────────┘    │                        │                  │   │            │                                         
- │   user    │────┘                   │    │                                                    │                        └──────────────────┘   │            │                                         
- └───────────┘────┐                   │    └────────────────────────────────────────────────────┘                                               │            │                                         
+ ┌──────────┐     │                   │    │    └──────────┘                   └───────────┘    │                        │                  │   │            │                                         
+ │   user   │ ────┘                   │    │                                                    │                        └──────────────────┘   │            │                                         
+ └──────────┘ ────┐                   │    └────────────────────────────────────────────────────┘                                               │            │                                         
                   │                   │                                                                                                         │            │                                         
                   │                   │     ┌───────────────┐                                                                                   │            │    ┌──────────┐                         
                   │                   │     │ online portal │                                                                                   │            └───▶│api server│                   ┌────┐
EOF_114329324912

# Run the e2e tests which include the ASCII txtar tests
# The test framework will automatically:
# 1. Load test cases from asciitxtar.txt
# 2. Generate ASCII output for network-horizontal test
# 3. Compare with ascii.exp.txt
# 4. Report pass/fail
go test --timeout=30m ./e2etests -v -run TestE2E
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original expected output file
git checkout ea61d3b6a9fecf0da6787f44b7b6b56d9754d7af "e2etests/testdata/asciitxtar/network-horizontal/ascii.exp.txt"