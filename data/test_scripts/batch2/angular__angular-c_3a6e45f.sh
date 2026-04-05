#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout c74b168382ae5bc260331c0d3f6378e0eda0018f \
  "packages/compiler/test/ml_parser/util/util.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/ml_parser/util/util.ts b/packages/compiler/test/ml_parser/util/util.ts
--- a/packages/compiler/test/ml_parser/util/util.ts
+++ b/packages/compiler/test/ml_parser/util/util.ts
@@ -11,13 +11,13 @@ import {getHtmlTagDefinition} from '../../../src/ml_parser/html_tags';
 
 class _SerializerVisitor implements html.Visitor {
   visitElement(element: html.Element, context: any): any {
+    const attrs = `${this._visitAll(element.attrs, ' ', ' ')}${this._visitAll(element.directives, ' ', ' ')}`;
+
     if (getHtmlTagDefinition(element.name).isVoid) {
-      return `<${element.name}${this._visitAll(element.attrs, ' ', ' ')}/>`;
+      return `<${element.name}${attrs}/>`;
     }
 
-    return `<${element.name}${this._visitAll(element.attrs, ' ', ' ')}>${this._visitAll(
-      element.children,
-    )}</${element.name}>`;
+    return `<${element.name}${attrs}>${this._visitAll(element.children)}</${element.name}>`;
   }
 
   visitAttribute(attribute: html.Attribute, context: any): any {
@@ -54,6 +54,15 @@ class _SerializerVisitor implements html.Visitor {
     return `@let ${decl.name} = ${decl.value};`;
   }
 
+  visitComponent(node: html.Component, context: any): any {
+    const attrs = `${this._visitAll(node.attrs, ' ', ' ')}${this._visitAll(node.directives, ' ', ' ')}`;
+    return `<${node.fullName}${attrs}>${this._visitAll(node.children)}</${node.fullName}>`;
+  }
+
+  visitDirective(directive: html.Directive, context: any) {
+    return `@${directive.name}${this._visitAll(directive.attrs, ' ', ' ')}`;
+  }
+
   private _visitAll(nodes: html.Node[], separator = '', prefix = ''): string {
     return nodes.length > 0 ? prefix + nodes.map((a) => a.visit(this, null)).join(separator) : '';
   }
EOF_114329324912

# Run the specified test using Bazel
# The test target is //packages/compiler/test/ml_parser:ml_parser (Node.js Jasmine tests)
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# Limiting parallelism with --jobs=4 for stability in virtualized environment
bazelisk test \
  //packages/compiler/test/ml_parser:ml_parser \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout c74b168382ae5bc260331c0d3f6378e0eda0018f \
  "packages/compiler/test/ml_parser/util/util.ts"