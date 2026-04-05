#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original files to ensure clean state
git checkout 5343001835a5aa54bb6bf7e084c5db721b97444c "packages/compiler-cli/private/testing.ts" "packages/compiler-cli/src/ngtsc/testing/BUILD.bazel" "packages/language-service/test/BUILD.bazel" "packages/language-service/test/code_fixes_spec.ts" "packages/language-service/test/compiler_spec.ts" "packages/language-service/test/completions_spec.ts" "packages/language-service/test/definitions_spec.ts" "packages/language-service/test/diagnostic_spec.ts" "packages/language-service/test/get_outlining_spans_spec.ts" "packages/language-service/test/get_template_location_for_component_spec.ts" "packages/language-service/test/gettcb_spec.ts" "packages/language-service/test/legacy/BUILD.bazel" "packages/language-service/test/legacy/language_service_spec.ts" "packages/language-service/test/legacy/mock_host.ts" "packages/language-service/test/quick_info_spec.ts" "packages/language-service/test/references_and_rename_spec.ts" "packages/language-service/test/semantic_tokens_spec.ts" "packages/language-service/test/signal_input_refactoring_action_spec.ts" "packages/language-service/test/signal_queries_refactoring_action_spec.ts" "packages/language-service/test/signature_help_spec.ts" "packages/language-service/test/ts_utils_spec.ts" "packages/language-service/test/type_definitions_spec.ts" "packages/language-service/testing/BUILD.bazel" "packages/language-service/testing/src/env.ts" "packages/language-service/testing/src/host.ts" "packages/language-service/testing/src/language_service_test_cache.ts" "packages/language-service/testing/src/project.ts" "packages/localize/tools/test/BUILD.bazel" "packages/localize/tools/test/extract/extractor_spec.ts" "packages/localize/tools/test/extract/integration/BUILD.bazel" "packages/localize/tools/test/extract/integration/main_spec.ts" "packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts" "packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/mock_message.ts" "packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts" "packages/localize/tools/test/helpers/BUILD.bazel" "packages/localize/tools/test/helpers/index.ts" "packages/localize/tools/test/migrate/integration/BUILD.bazel" "packages/localize/tools/test/migrate/integration/main_spec.ts" "packages/localize/tools/test/source_file_utils_spec.ts" "packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts" "packages/localize/tools/test/translate/integration/BUILD.bazel" "packages/localize/tools/test/translate/integration/main_spec.ts" "packages/localize/tools/test/translate/output_path_spec.ts" "packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts" "packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts" "packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts" "packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts" "packages/localize/tools/test/translate/translator_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/private/testing.ts b/packages/compiler-cli/private/testing.ts
--- a/packages/compiler-cli/private/testing.ts
+++ b/packages/compiler-cli/private/testing.ts
@@ -10,4 +10,13 @@ export {ImportedSymbolsTracker} from '../src/ngtsc/imports';
 export {TypeScriptReflectionHost} from '../src/ngtsc/reflection';
 export {getInitializerApiJitTransform} from '../src/ngtsc/transform/jit';
 
-export {initMockFileSystem, MockFileSystem} from '../src/ngtsc/file_system/testing';
+export {
+  initMockFileSystem,
+  MockFileSystem,
+  MockFileSystemNative,
+  runInEachFileSystem,
+} from '../src/ngtsc/file_system/testing';
+
+export {MockLogger} from '../src/ngtsc/logging/testing';
+export {loadTestDirectory, loadStandardTestFiles, getCachedSourceFile} from '../src/ngtsc/testing';
+export {NgCompilerOptions} from '../src/ngtsc/core';
diff --git a/packages/compiler-cli/src/ngtsc/testing/BUILD.bazel b/packages/compiler-cli/src/ngtsc/testing/BUILD.bazel
--- a/packages/compiler-cli/src/ngtsc/testing/BUILD.bazel
+++ b/packages/compiler-cli/src/ngtsc/testing/BUILD.bazel
@@ -4,7 +4,6 @@ package(default_visibility = ["//visibility:public"])
 
 ts_project(
     name = "testing",
-    testonly = True,
     srcs = glob([
         "**/*.ts",
     ]),
diff --git a/packages/language-service/test/BUILD.bazel b/packages/language-service/test/BUILD.bazel
--- a/packages/language-service/test/BUILD.bazel
+++ b/packages/language-service/test/BUILD.bazel
@@ -7,12 +7,8 @@ ts_project(
     deps = [
         "//:node_modules/typescript",
         "//packages/compiler",
-        "//packages/compiler-cli/src/ngtsc/core:api",
-        "//packages/compiler-cli/src/ngtsc/diagnostics",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/testing",
-        "//packages/compiler-cli/src/ngtsc/typecheck/api",
+        "//packages/compiler-cli",
+        "//packages/compiler-cli/private",
         "//packages/language-service/src",
         "//packages/language-service/src/utils",
         "//packages/language-service/testing",
@@ -24,6 +20,7 @@ jasmine_test(
     data = [
         ":test_lib",
         "//:node_modules/rxjs",
+        "//packages/compiler-cli/private",
         "//packages/compiler-cli/src/ngtsc/testing/fake_common:npm_package",
         "//packages/core:npm_package",
     ],
diff --git a/packages/language-service/test/code_fixes_spec.ts b/packages/language-service/test/code_fixes_spec.ts
--- a/packages/language-service/test/code_fixes_spec.ts
+++ b/packages/language-service/test/code_fixes_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {FixIdForCodeFixesAll} from '../src/codefixes/utils';
diff --git a/packages/language-service/test/compiler_spec.ts b/packages/language-service/test/compiler_spec.ts
--- a/packages/language-service/test/compiler_spec.ts
+++ b/packages/language-service/test/compiler_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {isNgSpecificDiagnostic, LanguageServiceTestEnv} from '../testing';
 
diff --git a/packages/language-service/test/completions_spec.ts b/packages/language-service/test/completions_spec.ts
--- a/packages/language-service/test/completions_spec.ts
+++ b/packages/language-service/test/completions_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {
diff --git a/packages/language-service/test/definitions_spec.ts b/packages/language-service/test/definitions_spec.ts
--- a/packages/language-service/test/definitions_spec.ts
+++ b/packages/language-service/test/definitions_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {
diff --git a/packages/language-service/test/diagnostic_spec.ts b/packages/language-service/test/diagnostic_spec.ts
--- a/packages/language-service/test/diagnostic_spec.ts
+++ b/packages/language-service/test/diagnostic_spec.ts
@@ -6,8 +6,8 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {ErrorCode, ngErrorCode} from '@angular/compiler-cli/src/ngtsc/diagnostics';
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {ErrorCode, ngErrorCode} from '@angular/compiler-cli';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv} from '../testing';
diff --git a/packages/language-service/test/get_outlining_spans_spec.ts b/packages/language-service/test/get_outlining_spans_spec.ts
--- a/packages/language-service/test/get_outlining_spans_spec.ts
+++ b/packages/language-service/test/get_outlining_spans_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv} from '../testing';
diff --git a/packages/language-service/test/get_template_location_for_component_spec.ts b/packages/language-service/test/get_template_location_for_component_spec.ts
--- a/packages/language-service/test/get_template_location_for_component_spec.ts
+++ b/packages/language-service/test/get_template_location_for_component_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {
   assertFileNames,
diff --git a/packages/language-service/test/gettcb_spec.ts b/packages/language-service/test/gettcb_spec.ts
--- a/packages/language-service/test/gettcb_spec.ts
+++ b/packages/language-service/test/gettcb_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv} from '../testing';
 
diff --git a/packages/language-service/test/legacy/BUILD.bazel b/packages/language-service/test/legacy/BUILD.bazel
--- a/packages/language-service/test/legacy/BUILD.bazel
+++ b/packages/language-service/test/legacy/BUILD.bazel
@@ -7,8 +7,7 @@ ts_project(
     deps = [
         "//:node_modules/typescript",
         "//packages/compiler",
-        "//packages/compiler-cli/src/ngtsc/core:api",
-        "//packages/compiler-cli/src/ngtsc/diagnostics",
+        "//packages/compiler-cli/private",
         "//packages/language-service/src",
         "//packages/language-service/src/utils",
     ],
diff --git a/packages/language-service/test/legacy/language_service_spec.ts b/packages/language-service/test/legacy/language_service_spec.ts
--- a/packages/language-service/test/legacy/language_service_spec.ts
+++ b/packages/language-service/test/legacy/language_service_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {ErrorCode, ngErrorCode} from '@angular/compiler-cli/src/ngtsc/diagnostics';
+import {ErrorCode, ngErrorCode} from '@angular/compiler-cli';
 import ts from 'typescript';
 
 import {LanguageService} from '../../src/language_service';
diff --git a/packages/language-service/test/legacy/mock_host.ts b/packages/language-service/test/legacy/mock_host.ts
--- a/packages/language-service/test/legacy/mock_host.ts
+++ b/packages/language-service/test/legacy/mock_host.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {NgCompilerOptions} from '@angular/compiler-cli/src/ngtsc/core/api';
+import {NgCompilerOptions} from '@angular/compiler-cli/private/testing';
 import {join} from 'path';
 import ts from 'typescript';
 
diff --git a/packages/language-service/test/quick_info_spec.ts b/packages/language-service/test/quick_info_spec.ts
--- a/packages/language-service/test/quick_info_spec.ts
+++ b/packages/language-service/test/quick_info_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv, Project} from '../testing';
diff --git a/packages/language-service/test/references_and_rename_spec.ts b/packages/language-service/test/references_and_rename_spec.ts
--- a/packages/language-service/test/references_and_rename_spec.ts
+++ b/packages/language-service/test/references_and_rename_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {
diff --git a/packages/language-service/test/semantic_tokens_spec.ts b/packages/language-service/test/semantic_tokens_spec.ts
--- a/packages/language-service/test/semantic_tokens_spec.ts
+++ b/packages/language-service/test/semantic_tokens_spec.ts
@@ -8,7 +8,7 @@
 
 import ts from 'typescript';
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import {LanguageServiceTestEnv, OpenBuffer} from '../testing';
 import {TokenEncodingConsts, TokenType, TokenModifier} from '../src/semantic_tokens';
 
diff --git a/packages/language-service/test/signal_input_refactoring_action_spec.ts b/packages/language-service/test/signal_input_refactoring_action_spec.ts
--- a/packages/language-service/test/signal_input_refactoring_action_spec.ts
+++ b/packages/language-service/test/signal_input_refactoring_action_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv} from '../testing';
 
diff --git a/packages/language-service/test/signal_queries_refactoring_action_spec.ts b/packages/language-service/test/signal_queries_refactoring_action_spec.ts
--- a/packages/language-service/test/signal_queries_refactoring_action_spec.ts
+++ b/packages/language-service/test/signal_queries_refactoring_action_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {createModuleAndProjectWithDeclarations, LanguageServiceTestEnv} from '../testing';
 
diff --git a/packages/language-service/test/signature_help_spec.ts b/packages/language-service/test/signature_help_spec.ts
--- a/packages/language-service/test/signature_help_spec.ts
+++ b/packages/language-service/test/signature_help_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import {getText} from '../testing/src/util';
 
 import {LanguageServiceTestEnv, OpenBuffer} from '../testing';
diff --git a/packages/language-service/test/ts_utils_spec.ts b/packages/language-service/test/ts_utils_spec.ts
--- a/packages/language-service/test/ts_utils_spec.ts
+++ b/packages/language-service/test/ts_utils_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {
diff --git a/packages/language-service/test/type_definitions_spec.ts b/packages/language-service/test/type_definitions_spec.ts
--- a/packages/language-service/test/type_definitions_spec.ts
+++ b/packages/language-service/test/type_definitions_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {initMockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {initMockFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {
   assertFileNames,
diff --git a/packages/language-service/testing/BUILD.bazel b/packages/language-service/testing/BUILD.bazel
--- a/packages/language-service/testing/BUILD.bazel
+++ b/packages/language-service/testing/BUILD.bazel
@@ -9,11 +9,8 @@ ts_project(
     deps = [
         "//:node_modules/typescript",
         "//packages/compiler",
-        "//packages/compiler-cli/src/ngtsc/core:api",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/testing",
-        "//packages/compiler-cli/src/ngtsc/typecheck/api",
+        "//packages/compiler-cli",
+        "//packages/compiler-cli/private",
         "//packages/language-service:api",
         "//packages/language-service/src",
     ],
diff --git a/packages/language-service/testing/src/env.ts b/packages/language-service/testing/src/env.ts
--- a/packages/language-service/testing/src/env.ts
+++ b/packages/language-service/testing/src/env.ts
@@ -6,9 +6,8 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {getFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
-import {loadStandardTestFiles} from '@angular/compiler-cli/src/ngtsc/testing';
+import {getFileSystem} from '@angular/compiler-cli';
+import {MockFileSystem, loadStandardTestFiles} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 import {MockServerHost} from './host';
diff --git a/packages/language-service/testing/src/host.ts b/packages/language-service/testing/src/host.ts
--- a/packages/language-service/testing/src/host.ts
+++ b/packages/language-service/testing/src/host.ts
@@ -6,8 +6,8 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {absoluteFrom} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom} from '@angular/compiler-cli';
+import {MockFileSystem} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 const NOOP_FILE_WATCHER: ts.FileWatcher = {
diff --git a/packages/language-service/testing/src/language_service_test_cache.ts b/packages/language-service/testing/src/language_service_test_cache.ts
--- a/packages/language-service/testing/src/language_service_test_cache.ts
+++ b/packages/language-service/testing/src/language_service_test_cache.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {getCachedSourceFile} from '@angular/compiler-cli/src/ngtsc/testing';
+import {getCachedSourceFile} from '@angular/compiler-cli/private/testing';
 import ts from 'typescript';
 
 interface TsProjectWithInternals {
diff --git a/packages/language-service/testing/src/project.ts b/packages/language-service/testing/src/project.ts
--- a/packages/language-service/testing/src/project.ts
+++ b/packages/language-service/testing/src/project.ts
@@ -6,19 +6,20 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {
-  InternalOptions,
-  LegacyNgcOptions,
-  TypeCheckingOptions,
-} from '@angular/compiler-cli/src/ngtsc/core/api';
 import {
   absoluteFrom,
   AbsoluteFsPath,
   FileSystem,
   getFileSystem,
   getSourceFileOrError,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {OptimizeFor, TemplateTypeChecker} from '@angular/compiler-cli/src/ngtsc/typecheck/api';
+  OptimizeFor,
+} from '@angular/compiler-cli';
+import {
+  TemplateTypeChecker,
+  InternalOptions,
+  LegacyNgcOptions,
+  TypeCheckingOptions,
+} from '@angular/compiler-cli/private/language_service';
 import ts from 'typescript';
 
 import {LanguageService} from '../../src/language_service';
diff --git a/packages/localize/tools/test/BUILD.bazel b/packages/localize/tools/test/BUILD.bazel
--- a/packages/localize/tools/test/BUILD.bazel
+++ b/packages/localize/tools/test/BUILD.bazel
@@ -15,9 +15,6 @@ ts_project(
         "//packages:types",
         "//packages/compiler",
         "//packages/compiler-cli/private",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/logging/testing",
         "//packages/localize",
         "//packages/localize/src/utils",
         "//packages/localize/tools",
diff --git a/packages/localize/tools/test/extract/extractor_spec.ts b/packages/localize/tools/test/extract/extractor_spec.ts
--- a/packages/localize/tools/test/extract/extractor_spec.ts
+++ b/packages/localize/tools/test/extract/extractor_spec.ts
@@ -5,8 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {absoluteFrom, getFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockLogger} from '@angular/compiler-cli/src/ngtsc/logging/testing';
+import {absoluteFrom, getFileSystem} from '@angular/compiler-cli';
+import {MockLogger} from '@angular/compiler-cli/private/testing';
 
 import {MessageExtractor} from '../../src/extract/extraction';
 import {runInNativeFileSystem} from '../helpers';
diff --git a/packages/localize/tools/test/extract/integration/BUILD.bazel b/packages/localize/tools/test/extract/integration/BUILD.bazel
--- a/packages/localize/tools/test/extract/integration/BUILD.bazel
+++ b/packages/localize/tools/test/extract/integration/BUILD.bazel
@@ -8,11 +8,8 @@ ts_project(
     ),
     deps = [
         "//packages:types",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/logging",
-        "//packages/compiler-cli/src/ngtsc/logging/testing",
-        "//packages/compiler-cli/src/ngtsc/testing",
+        "//packages/compiler-cli",
+        "//packages/compiler-cli/private",
         "//packages/localize/tools",
         "//packages/localize/tools/test:test_lib",
         "//packages/localize/tools/test/helpers",
diff --git a/packages/localize/tools/test/extract/integration/main_spec.ts b/packages/localize/tools/test/extract/integration/main_spec.ts
--- a/packages/localize/tools/test/extract/integration/main_spec.ts
+++ b/packages/localize/tools/test/extract/integration/main_spec.ts
@@ -12,9 +12,8 @@ import {
   getFileSystem,
   setFileSystem,
   InvalidFileSystem,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockLogger} from '@angular/compiler-cli/src/ngtsc/logging/testing';
-import {loadTestDirectory} from '@angular/compiler-cli/src/ngtsc/testing';
+} from '@angular/compiler-cli';
+import {MockLogger, loadTestDirectory} from '@angular/compiler-cli/private/testing';
 import path from 'path';
 import url from 'url';
 
diff --git a/packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts b/packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts
--- a/packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts
+++ b/packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts
@@ -5,12 +5,7 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  FileSystem,
-  getFileSystem,
-  PathSegment,
-  relativeFrom,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
+import {FileSystem, getFileSystem, PathSegment, relativeFrom} from '@angular/compiler-cli';
 import {ɵParsedMessage} from '../../../../private';
 import {transformSync} from '@babel/core';
 
diff --git a/packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts b/packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts
--- a/packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts
+++ b/packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts
@@ -5,12 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  getFileSystem,
-  PathManipulation,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {getFileSystem, PathManipulation} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 import {ɵParsedMessage} from '../../../../index';
 
 import {ArbTranslationSerializer} from '../../../src/extract/translation_files/arb_translation_serializer';
diff --git a/packages/localize/tools/test/extract/translation_files/mock_message.ts b/packages/localize/tools/test/extract/translation_files/mock_message.ts
--- a/packages/localize/tools/test/extract/translation_files/mock_message.ts
+++ b/packages/localize/tools/test/extract/translation_files/mock_message.ts
@@ -5,7 +5,7 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {absoluteFrom} from '@angular/compiler-cli/src/ngtsc/file_system';
+import {absoluteFrom} from '@angular/compiler-cli';
 import {ɵParsedMessage} from '../../../../index';
 import {MessageId, SourceLocation} from '../../../../src/utils';
 
diff --git a/packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts b/packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts
--- a/packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts
+++ b/packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts
@@ -5,8 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {absoluteFrom} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 import {ɵParsedMessage, ɵSourceLocation} from '../../../../index';
 
 import {FormatOptions} from '../../../src/extract/translation_files/format_options';
diff --git a/packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts b/packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts
--- a/packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts
+++ b/packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts
@@ -5,8 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {absoluteFrom} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 import {ɵParsedMessage, ɵSourceLocation} from '../../../../index';
 
 import {FormatOptions} from '../../../src/extract/translation_files/format_options';
diff --git a/packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts b/packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts
--- a/packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts
+++ b/packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts
@@ -5,12 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  getFileSystem,
-  PathManipulation,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom, getFileSystem, PathManipulation} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 import {ɵParsedMessage, ɵSourceLocation} from '../../../../index';
 
 import {XmbTranslationSerializer} from '../../../src/extract/translation_files/xmb_translation_serializer';
diff --git a/packages/localize/tools/test/helpers/BUILD.bazel b/packages/localize/tools/test/helpers/BUILD.bazel
--- a/packages/localize/tools/test/helpers/BUILD.bazel
+++ b/packages/localize/tools/test/helpers/BUILD.bazel
@@ -8,7 +8,7 @@ ts_project(
     ),
     visibility = ["//packages/localize/tools/test:__subpackages__"],
     deps = [
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
+        "//packages/compiler-cli",
+        "//packages/compiler-cli/private",
     ],
 )
diff --git a/packages/localize/tools/test/helpers/index.ts b/packages/localize/tools/test/helpers/index.ts
--- a/packages/localize/tools/test/helpers/index.ts
+++ b/packages/localize/tools/test/helpers/index.ts
@@ -5,8 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {setFileSystem, InvalidFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockFileSystemNative} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {setFileSystem, InvalidFileSystem} from '@angular/compiler-cli';
+import {MockFileSystemNative} from '@angular/compiler-cli/private/testing';
 
 /**
  * Only run these tests on the "native" file-system.
diff --git a/packages/localize/tools/test/migrate/integration/BUILD.bazel b/packages/localize/tools/test/migrate/integration/BUILD.bazel
--- a/packages/localize/tools/test/migrate/integration/BUILD.bazel
+++ b/packages/localize/tools/test/migrate/integration/BUILD.bazel
@@ -8,11 +8,7 @@ ts_project(
     ),
     deps = [
         "//packages:types",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/logging",
-        "//packages/compiler-cli/src/ngtsc/logging/testing",
-        "//packages/compiler-cli/src/ngtsc/testing",
+        "//packages/compiler-cli/private",
         "//packages/localize/tools",
         "//packages/localize/tools/test:test_lib",
         "//packages/localize/tools/test/helpers",
diff --git a/packages/localize/tools/test/migrate/integration/main_spec.ts b/packages/localize/tools/test/migrate/integration/main_spec.ts
--- a/packages/localize/tools/test/migrate/integration/main_spec.ts
+++ b/packages/localize/tools/test/migrate/integration/main_spec.ts
@@ -6,14 +6,8 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {
-  absoluteFrom,
-  AbsoluteFsPath,
-  FileSystem,
-  getFileSystem,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {MockLogger} from '@angular/compiler-cli/src/ngtsc/logging/testing';
-import {loadTestDirectory} from '@angular/compiler-cli/src/ngtsc/testing';
+import {absoluteFrom, AbsoluteFsPath, FileSystem, getFileSystem} from '@angular/compiler-cli';
+import {MockLogger, loadTestDirectory} from '@angular/compiler-cli/private/testing';
 import path from 'path';
 import url from 'url';
 
diff --git a/packages/localize/tools/test/source_file_utils_spec.ts b/packages/localize/tools/test/source_file_utils_spec.ts
--- a/packages/localize/tools/test/source_file_utils_spec.ts
+++ b/packages/localize/tools/test/source_file_utils_spec.ts
@@ -5,11 +5,7 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  getFileSystem,
-  PathManipulation,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
+import {absoluteFrom, getFileSystem, PathManipulation} from '@angular/compiler-cli';
 import {ɵmakeTemplateObject} from '../../index';
 import babel, {NodePath, TransformOptions, template, types as t} from '@babel/core';
 import _generate from '@babel/generator';
diff --git a/packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts b/packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts
--- a/packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts
+++ b/packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts
@@ -12,8 +12,8 @@ import {
   getFileSystem,
   PathSegment,
   relativeFrom,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {Diagnostics} from '../../../src/diagnostics';
 import {AssetTranslationHandler} from '../../../src/translate/asset_files/asset_translation_handler';
diff --git a/packages/localize/tools/test/translate/integration/BUILD.bazel b/packages/localize/tools/test/translate/integration/BUILD.bazel
--- a/packages/localize/tools/test/translate/integration/BUILD.bazel
+++ b/packages/localize/tools/test/translate/integration/BUILD.bazel
@@ -8,9 +8,8 @@ ts_project(
     ),
     deps = [
         "//packages:types",
-        "//packages/compiler-cli/src/ngtsc/file_system",
-        "//packages/compiler-cli/src/ngtsc/file_system/testing",
-        "//packages/compiler-cli/src/ngtsc/testing",
+        "//packages/compiler-cli",
+        "//packages/compiler-cli/private",
         "//packages/localize/tools",
         "//packages/localize/tools/test/helpers",
     ],
diff --git a/packages/localize/tools/test/translate/integration/main_spec.ts b/packages/localize/tools/test/translate/integration/main_spec.ts
--- a/packages/localize/tools/test/translate/integration/main_spec.ts
+++ b/packages/localize/tools/test/translate/integration/main_spec.ts
@@ -5,13 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  AbsoluteFsPath,
-  FileSystem,
-  getFileSystem,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {loadTestDirectory} from '@angular/compiler-cli/src/ngtsc/testing';
+import {absoluteFrom, AbsoluteFsPath, FileSystem, getFileSystem} from '@angular/compiler-cli';
+import {loadTestDirectory} from '@angular/compiler-cli/private/testing';
 import path from 'path';
 import url from 'url';
 
diff --git a/packages/localize/tools/test/translate/output_path_spec.ts b/packages/localize/tools/test/translate/output_path_spec.ts
--- a/packages/localize/tools/test/translate/output_path_spec.ts
+++ b/packages/localize/tools/test/translate/output_path_spec.ts
@@ -5,12 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  getFileSystem,
-  PathManipulation,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom, getFileSystem, PathManipulation} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {getOutputPathFn} from '../../src/translate/output_path';
 
diff --git a/packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts b/packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts
--- a/packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts
+++ b/packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts
@@ -5,7 +5,7 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {FileSystem, getFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system';
+import {FileSystem, getFileSystem} from '@angular/compiler-cli';
 import {ɵcomputeMsgId, ɵparseTranslation} from '../../../../index';
 import {ɵParsedTranslation} from '../../../../private';
 import {transformSync} from '@babel/core';
diff --git a/packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts b/packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts
--- a/packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts
+++ b/packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts
@@ -5,12 +5,7 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  FileSystem,
-  getFileSystem,
-  PathSegment,
-  relativeFrom,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
+import {FileSystem, getFileSystem, PathSegment, relativeFrom} from '@angular/compiler-cli';
 import {ɵcomputeMsgId, ɵparseTranslation} from '../../../../index';
 import {ɵParsedTranslation} from '../../../../private';
 import {transformSync} from '@babel/core';
diff --git a/packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts b/packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts
--- a/packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts
+++ b/packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts
@@ -12,8 +12,8 @@ import {
   getFileSystem,
   PathSegment,
   relativeFrom,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {Diagnostics} from '../../../src/diagnostics';
 import {SourceFileTranslationHandler} from '../../../src/translate/source_files/source_file_translation_handler';
diff --git a/packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts b/packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts
--- a/packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts
+++ b/packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts
@@ -5,13 +5,8 @@
  * Use of this source code is governed by an MIT-style license that can be
  * found in the LICENSE file at https://angular.dev/license
  */
-import {
-  absoluteFrom,
-  AbsoluteFsPath,
-  FileSystem,
-  getFileSystem,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+import {absoluteFrom, AbsoluteFsPath, FileSystem, getFileSystem} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 import {ɵParsedTranslation, ɵparseTranslation} from '../../../../index';
 
 import {DiagnosticHandlingStrategy, Diagnostics} from '../../../src/diagnostics';
diff --git a/packages/localize/tools/test/translate/translator_spec.ts b/packages/localize/tools/test/translate/translator_spec.ts
--- a/packages/localize/tools/test/translate/translator_spec.ts
+++ b/packages/localize/tools/test/translate/translator_spec.ts
@@ -12,8 +12,8 @@ import {
   getFileSystem,
   PathSegment,
   relativeFrom,
-} from '@angular/compiler-cli/src/ngtsc/file_system';
-import {runInEachFileSystem} from '@angular/compiler-cli/src/ngtsc/file_system/testing';
+} from '@angular/compiler-cli';
+import {runInEachFileSystem} from '@angular/compiler-cli/private/testing';
 
 import {Diagnostics as Diagnostics} from '../../src/diagnostics';
 import {OutputPathFn} from '../../src/translate/output_path';
EOF_114329324912

# Build the testing utilities first to ensure dependencies are compiled
pnpm bazel build //packages/compiler-cli/src/ngtsc/testing:testing //packages/language-service/testing:testing

# Execute the specific test targets
# Run all test targets in a single command to optimize execution
# Note: Using correct target name :legacy instead of :test for legacy tests
pnpm bazel test //packages/language-service/test:test //packages/language-service/test/legacy:legacy //packages/localize/tools/test:test //packages/localize/tools/test/extract/integration:integration //packages/localize/tools/test/migrate/integration:integration //packages/localize/tools/test/translate/integration:integration
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original files
git checkout 5343001835a5aa54bb6bf7e084c5db721b97444c "packages/compiler-cli/private/testing.ts" "packages/compiler-cli/src/ngtsc/testing/BUILD.bazel" "packages/language-service/test/BUILD.bazel" "packages/language-service/test/code_fixes_spec.ts" "packages/language-service/test/compiler_spec.ts" "packages/language-service/test/completions_spec.ts" "packages/language-service/test/definitions_spec.ts" "packages/language-service/test/diagnostic_spec.ts" "packages/language-service/test/get_outlining_spans_spec.ts" "packages/language-service/test/get_template_location_for_component_spec.ts" "packages/language-service/test/gettcb_spec.ts" "packages/language-service/test/legacy/BUILD.bazel" "packages/language-service/test/legacy/language_service_spec.ts" "packages/language-service/test/legacy/mock_host.ts" "packages/language-service/test/quick_info_spec.ts" "packages/language-service/test/references_and_rename_spec.ts" "packages/language-service/test/semantic_tokens_spec.ts" "packages/language-service/test/signal_input_refactoring_action_spec.ts" "packages/language-service/test/signal_queries_refactoring_action_spec.ts" "packages/language-service/test/signature_help_spec.ts" "packages/language-service/test/ts_utils_spec.ts" "packages/language-service/test/type_definitions_spec.ts" "packages/language-service/testing/BUILD.bazel" "packages/language-service/testing/src/env.ts" "packages/language-service/testing/src/host.ts" "packages/language-service/testing/src/language_service_test_cache.ts" "packages/language-service/testing/src/project.ts" "packages/localize/tools/test/BUILD.bazel" "packages/localize/tools/test/extract/extractor_spec.ts" "packages/localize/tools/test/extract/integration/BUILD.bazel" "packages/localize/tools/test/extract/integration/main_spec.ts" "packages/localize/tools/test/extract/source_files/es5_extract_plugin_spec.ts" "packages/localize/tools/test/extract/translation_files/arb_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/mock_message.ts" "packages/localize/tools/test/extract/translation_files/xliff1_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/xliff2_translation_serializer_spec.ts" "packages/localize/tools/test/extract/translation_files/xmb_translation_serializer_spec.ts" "packages/localize/tools/test/helpers/BUILD.bazel" "packages/localize/tools/test/helpers/index.ts" "packages/localize/tools/test/migrate/integration/BUILD.bazel" "packages/localize/tools/test/migrate/integration/main_spec.ts" "packages/localize/tools/test/source_file_utils_spec.ts" "packages/localize/tools/test/translate/asset_files/asset_file_translation_handler_spec.ts" "packages/localize/tools/test/translate/integration/BUILD.bazel" "packages/localize/tools/test/translate/integration/main_spec.ts" "packages/localize/tools/test/translate/output_path_spec.ts" "packages/localize/tools/test/translate/source_files/es2015_translate_plugin_spec.ts" "packages/localize/tools/test/translate/source_files/es5_translate_plugin_spec.ts" "packages/localize/tools/test/translate/source_files/source_file_translation_handler_spec.ts" "packages/localize/tools/test/translate/translation_files/translation_loader_spec.ts" "packages/localize/tools/test/translate/translator_spec.ts"