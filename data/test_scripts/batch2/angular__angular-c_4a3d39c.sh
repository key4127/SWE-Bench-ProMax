#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test utility file to ensure clean state
git checkout 693006e2191542a3041db1731c3309903c73a61d \
  "packages/core/schematics/utils/tsurge/testing/run_single.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/schematics/utils/tsurge/testing/run_single.ts b/packages/core/schematics/utils/tsurge/testing/run_single.ts
--- a/packages/core/schematics/utils/tsurge/testing/run_single.ts
+++ b/packages/core/schematics/utils/tsurge/testing/run_single.ts
@@ -58,8 +58,7 @@ export async function runTsurgeMigration<Stats>(
     }),
   );
 
-  const baseInfo = migration.createProgram('/tsconfig.json', mockFs);
-  const info = migration.prepareProgram(baseInfo);
+  const info = migration.createProgram('/tsconfig.json', mockFs);
 
   const unitData = await migration.analyze(info);
   const globalMeta = await migration.globalMeta(unitData);
EOF_114329324912

# Run the tsurge test suite using Bazel
# This test suite uses the run_single.ts utility being tested
# Using --test_output=errors for cleaner output (only shows failures)
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/core/schematics/utils/tsurge/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the tests
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test utility file
git checkout 693006e2191542a3041db1731c3309903c73a61d \
  "packages/core/schematics/utils/tsurge/testing/run_single.ts"

exit $rc