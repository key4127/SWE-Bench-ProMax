#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 9d270a2a9181e70df7606ff489820fd63822cfe8 "packages/common/test/services/logger.service.spec.ts"

# Apply the test patch - it will modify all necessary files (test + implementation)
git apply -v - <<'EOF_114329324912'
diff --git a/packages/common/test/services/logger.service.spec.ts b/packages/common/test/services/logger.service.spec.ts
--- a/packages/common/test/services/logger.service.spec.ts
+++ b/packages/common/test/services/logger.service.spec.ts
@@ -1,51 +1,9 @@
 import { expect } from 'chai';
 import 'reflect-metadata';
 import * as sinon from 'sinon';
-import {
-  ConsoleLogger,
-  filterLogLevels,
-  Logger,
-  LoggerService,
-  LogLevel,
-} from '../../services';
+import { ConsoleLogger, Logger, LoggerService, LogLevel } from '../../services';
 
 describe('Logger', () => {
-  describe('[log helpers]', () => {
-    describe('when using filterLogLevels', () => {
-      it('should correctly parse an exclusive range', () => {
-        const returned = filterLogLevels('>warn');
-        expect(returned).to.deep.equal(['error', 'fatal']);
-      });
-
-      it('should correctly parse an inclusive range', () => {
-        const returned = filterLogLevels('>=warn');
-        expect(returned).to.deep.equal(['warn', 'error', 'fatal']);
-      });
-
-      it('should correctly parse a string list', () => {
-        const returned = filterLogLevels('verbose,warn,fatal');
-        expect(returned).to.deep.equal(['verbose', 'warn', 'fatal']);
-      });
-
-      it('should correctly parse a single log level', () => {
-        const returned = filterLogLevels('debug');
-        expect(returned).to.deep.equal(['debug']);
-      });
-
-      it('should return all otherwise', () => {
-        const returned = filterLogLevels();
-        expect(returned).to.deep.equal([
-          'verbose',
-          'debug',
-          'log',
-          'warn',
-          'error',
-          'fatal',
-        ]);
-      });
-    });
-  });
-
   describe('[static methods]', () => {
     describe('when the default logger is used', () => {
       let processStdoutWriteSpy: sinon.SinonSpy;
diff --git a/packages/common/test/services/utils/filter-log-levels.util.spec.ts b/packages/common/test/services/utils/filter-log-levels.util.spec.ts
new file mode 100644
--- /dev/null
+++ b/packages/common/test/services/utils/filter-log-levels.util.spec.ts
@@ -0,0 +1,36 @@
+import { expect } from 'chai';
+import { filterLogLevels } from '../../../services/utils/filter-log-levels.util';
+
+describe('filterLogLevels', () => {
+  it('should correctly parse an exclusive range', () => {
+    const returned = filterLogLevels('>warn');
+    expect(returned).to.deep.equal(['error', 'fatal']);
+  });
+
+  it('should correctly parse an inclusive range', () => {
+    const returned = filterLogLevels('>=warn');
+    expect(returned).to.deep.equal(['warn', 'error', 'fatal']);
+  });
+
+  it('should correctly parse a string list', () => {
+    const returned = filterLogLevels('verbose,warn,fatal');
+    expect(returned).to.deep.equal(['verbose', 'warn', 'fatal']);
+  });
+
+  it('should correctly parse a single log level', () => {
+    const returned = filterLogLevels('debug');
+    expect(returned).to.deep.equal(['debug']);
+  });
+
+  it('should return all otherwise', () => {
+    const returned = filterLogLevels();
+    expect(returned).to.deep.equal([
+      'verbose',
+      'debug',
+      'log',
+      'warn',
+      'error',
+      'fatal',
+    ]);
+  });
+});
EOF_114329324912

# Rebuild the project since source code may have changed
# This is critical because TypeScript needs to recompile with any new changes
npm run build

# Execute the target test file using Mocha with required configurations
# Using npx to ensure mocha is executed from node_modules
npx mocha \
  --require ts-node/register \
  --require tsconfig-paths/register \
  --require reflect-metadata/Reflect.js \
  --require hooks/mocha-init-hook.ts \
  --exit \
  packages/common/test/services/logger.service.spec.ts

# Capture the exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore all modified files to original state
git checkout 9d270a2a9181e70df7606ff489820fd63822cfe8 "packages/common/test/services/logger.service.spec.ts"