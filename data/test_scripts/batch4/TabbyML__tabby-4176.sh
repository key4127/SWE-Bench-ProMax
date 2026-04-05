#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9266e3f9dd726c6c0deb318d5fa7896058edb77c \
  "clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeByBracketStack.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeBySemiColon.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeByBracketStack.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeByBracketStack.test.ts
deleted file mode 100644
--- a/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeByBracketStack.test.ts
+++ /dev/null
@@ -1,183 +0,0 @@
-import { documentContext, inline, assertFilterResult, assertFilterResultNotEqual } from "./testUtils";
-import { calculateReplaceRangeByBracketStack } from "./calculateReplaceRangeByBracketStack";
-
-describe("postprocess", () => {
-  describe("calculateReplaceRangeByBracketStack", () => {
-    const filter = calculateReplaceRangeByBracketStack;
-    it("should handle auto closing quotes", async () => {
-      const context = documentContext`
-        const hello = "║"
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                       ├hello";┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                       ├hello";┤
-        `,
-        replaceSuffix: '"',
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle auto closing quotes", async () => {
-      const context = documentContext`
-        let htmlMarkup = \`║\`
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                           ├<h1>\${message}</h1>\`;┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                           ├<h1>\${message}</h1>\`;┤
-        `,
-        replaceSuffix: "`",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle multiple auto closing brackets", async () => {
-      const context = documentContext`
-        process.on('data', (data) => {║})
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                      ├
-          console.log(data);
-        });┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                                      ├
-          console.log(data);
-        });┤
-        `,
-        replaceSuffix: "})",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle multiple auto closing brackets", async () => {
-      const context = documentContext`
-        let mat: number[][][] = [[[║]]]
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                   ├1, 2], [3, 4]], [[5, 6], [7, 8]]];┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                                   ├1, 2], [3, 4]], [[5, 6], [7, 8]]];┤
-        `,
-        replaceSuffix: "]]]",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle html tags", async () => {
-      const context = documentContext`
-        <html></h║>
-      `;
-      context.language = "html";
-      const completion = {
-        text: inline`
-                 ├tml>┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                 ├tml>┤
-        `,
-        replaceSuffix: ">",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle jsx tags", async () => {
-      const context = documentContext`
-        root.render(
-          <React.StrictMode>
-            <App m║/>
-          </React.StrictMode>
-        );
-      `;
-      context.language = "javascriptreact";
-      const completion = {
-        text: inline`
-                  ├essage={message} />┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                  ├essage={message} />┤
-        `,
-        replaceSuffix: "/>",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-    it("should handle bracket case with semicolon", async () => {
-      const context = documentContext`
-        console.log("║");
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                       ├hello world");┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                       ├hello world");┤
-        `,
-        replaceSuffix: '");',
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-    it("should handle bracket case with semicolon", async () => {
-      const context = documentContext`
-        console.log(║);
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                       ├a + b);┤
-        `,
-      };
-      const expected = {
-        text: inline`
-                       ├a + b);┤
-        `,
-        replaceSuffix: ");",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-  });
-  describe("calculateReplaceRangeByBracketStack: bad cases", () => {
-    const filter = calculateReplaceRangeByBracketStack;
-    it("cannot handle the case of completion bracket stack is same with suffix but should not be replaced", async () => {
-      const context = documentContext`
-        function clamp(n: number, max: number, min: number): number {
-          return Math.max(Math.min(║);
-        }
-      `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                   ├n, max), min┤
-        `,
-      };
-      const expected = completion;
-      await assertFilterResultNotEqual(filter, context, completion, expected);
-    });
-  });
-});
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeBySemiColon.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeBySemiColon.test.ts
deleted file mode 100644
--- a/clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeBySemiColon.test.ts
+++ /dev/null
@@ -1,123 +0,0 @@
-import { documentContext, inline, assertFilterResult } from "./testUtils";
-import { calculateReplaceRangeBySemiColon } from "./calculateReplaceRangeBySemiColon";
-
-describe("postprocess", () => {
-  describe("calculateReplaceRangeBySemiColon", () => {
-    const filter = calculateReplaceRangeBySemiColon;
-
-    it("should handle semicolon in string concatenation", async () => {
-      const context = documentContext`
-          const content = "hello world";
-          const a = "nihao" + ║;
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├content;┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├content;┤
-          `,
-        replaceSuffix: ";",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle semicolon at the end of a statement", async () => {
-      const context = documentContext`
-          const content = "hello world"║;
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├;┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├;┤
-          `,
-        replaceSuffix: ";",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should not handle any semicolon at the end of a statement", async () => {
-      const context = documentContext`
-          const content = "hello world"║
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├┤
-          `,
-        replaceSuffix: "",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should not modify if no semicolon in completion text", async () => {
-      const context = documentContext`
-          const content = "hello world"║
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├content┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├content┤
-          `,
-        replaceSuffix: "",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle multiple semicolons in completion text", async () => {
-      const context = documentContext`
-          const content = "hello world"║;
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├content;;┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├content;;┤
-          `,
-        replaceSuffix: ";",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-
-    it("should handle semicolon in the middle of a statement", async () => {
-      const context = documentContext`
-          const content = "hello; world"║;
-        `;
-      context.language = "typescript";
-      const completion = {
-        text: inline`
-                                 ├content;┤
-          `,
-      };
-      const expected = {
-        text: inline`
-                                 ├content;┤
-          `,
-        replaceSuffix: ";",
-      };
-      await assertFilterResult(filter, context, completion, expected);
-    });
-  });
-});
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts
@@ -1,38 +1,36 @@
 import { documentContext, inline, assertFilterResult } from "./testUtils";
 import { dropDuplicated } from "./dropDuplicated";
-import { CompletionItem } from "../solution";
+import { CompletionResultItem } from "../solution";
 
 describe("postprocess", () => {
   describe("dropDuplicated", () => {
     const filter = dropDuplicated();
     it("should drop completion duplicated with suffix", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let sum = (a, b) => {
           ║return a + b;
         };
       `;
-      context.language = "javascript";
       // completion give a `;` at end but context have not
       const completion = inline`
           ├return a + b;┤
       `;
-      const expected = CompletionItem.createBlankItem(context);
+      const expected = new CompletionResultItem("");
       await assertFilterResult(filter, context, completion, expected);
     });
 
     it("should drop completion similar to suffix", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let sum = (a, b) => {
           return a + b;
           ║
         };
       `;
-      context.language = "javascript";
       // the difference is a `\n`
       const completion = inline`
           ├}┤
       `;
-      const expected = CompletionItem.createBlankItem(context);
+      const expected = new CompletionResultItem("");
       await assertFilterResult(filter, context, completion, expected);
     });
   });
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts
@@ -1,17 +1,16 @@
 import { dropMinimum } from "./dropMinimum";
 import { documentContext, assertFilterResult } from "./testUtils";
-import { CompletionItem } from "../solution";
+import { CompletionResultItem } from "../solution";
 
 describe("postprocess", () => {
   describe("dropMinimum", () => {
     const filter = dropMinimum({ limitScope: null, minCompletionChars: 4, calculateReplaceRange: null });
     const context = documentContext`
       dummy║
     `;
-    context.language = "plaintext";
 
     it("should return null if input is < 4 non-whitespace characters", async () => {
-      const expected = CompletionItem.createBlankItem(context);
+      const expected = new CompletionResultItem("");
       await assertFilterResult(filter, context, "\n", expected);
       await assertFilterResult(filter, context, "\t\n", expected);
       await assertFilterResult(filter, context, "ab\t\n", expected);
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts
@@ -5,45 +5,42 @@ describe("postprocess", () => {
   describe("formatIndentation", () => {
     const filter = formatIndentation();
     it("should format indentation if first line of completion is over indented.", async () => {
-      const context = documentContext`
+      const context = documentContext`typescript
         function clamp(n: number, max: number, min: number): number {
           ║
         }
       `;
-      context.indentation = "  ";
-      context.language = "typescript";
+      const indentation = "  ";
       const completion = inline`
           ├  return Math.max(Math.min(n, max), min);┤
       `;
       const expected = inline`
           ├return Math.max(Math.min(n, max), min);┤
       `;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
 
     it("should format indentation if first line of completion is wrongly indented.", async () => {
-      const context = documentContext`
+      const context = documentContext`typescript
         function clamp(n: number, max: number, min: number): number {
         ║
         }
       `;
-      context.indentation = "    ";
-      context.language = "typescript";
+      const indentation = "    ";
       const completion = inline`
         ├  return Math.max(Math.min(n, max), min);┤
       `;
       const expected = inline`
         ├    return Math.max(Math.min(n, max), min);┤
       `;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
 
     it("should format indentation if completion lines is over indented.", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def findMax(arr):║
       `;
-      context.indentation = "  ";
-      context.language = "python";
+      const indentation = "  ";
       const completion = inline`
                          ├
             max = arr[0]
@@ -62,15 +59,14 @@ describe("postprocess", () => {
           return max
         }┤
       `;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
 
     it("should format indentation if completion lines is wrongly indented.", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def findMax(arr):║
       `;
-      context.indentation = "    ";
-      context.language = "python";
+      const indentation = "    ";
       const completion = inline`
                          ├
           max = arr[0]
@@ -89,15 +85,14 @@ describe("postprocess", () => {
             return max
         }┤
       `;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
 
     it("should keep it unchanged if it no indentation specified.", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def findMax(arr):║
       `;
-      context.indentation = undefined;
-      context.language = "python";
+      const indentation = undefined;
       const completion = inline`
                           ├
             max = arr[0]
@@ -108,18 +103,17 @@ describe("postprocess", () => {
         }┤
       `;
       const expected = completion;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: indentation }, completion, expected);
     });
 
     it("should keep it unchanged if there is indentation in the context.", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def hello():
             return "world"
 
         def findMax(arr):║
       `;
-      context.indentation = "\t";
-      context.language = "python";
+      const indentation = "\t";
       const completion = inline`
                           ├
             max = arr[0]
@@ -130,15 +124,14 @@ describe("postprocess", () => {
         }┤
       `;
       const expected = completion;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
 
     it("should keep it unchanged if it is well indented.", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def findMax(arr):║
       `;
-      context.indentation = "    ";
-      context.language = "python";
+      const indentation = "    ";
       const completion = inline`
                           ├
             max = arr[0]
@@ -149,7 +142,7 @@ describe("postprocess", () => {
         }┤
       `;
       const expected = completion;
-      await assertFilterResult(filter, context, completion, expected);
+      await assertFilterResult(filter, { ...context, editorOptions: { indentation } }, completion, expected);
     });
   });
 });
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts
@@ -5,10 +5,9 @@ describe("postprocess", () => {
   describe("limitScopeByIndentation", () => {
     const filter = limitScopeByIndentation();
     it("should limit scope at sentence end, when completion is continuing uncompleted sentence in the prefix.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let a =║
       `;
-      context.language = "javascript";
       const completion = inline`
                ├ 1;
         let b = 2;┤
@@ -20,7 +19,7 @@ describe("postprocess", () => {
     });
 
     it("should limit scope at sentence end, when completion is continuing uncompleted sentence in the prefix.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function safeParse(json) {
           try {
             console.log║
@@ -30,7 +29,6 @@ describe("postprocess", () => {
           }
         }
       `;
-      context.language = "javascript";
       const completion = inline`
                         ├("Parsing", { json });
             return JSON.parse(json);
@@ -46,10 +44,9 @@ describe("postprocess", () => {
     });
 
     it("should limit scope at next indent level, including closing line, when completion is starting a new indent level in next line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function findMax(arr) {║}
       `;
-      context.language = "javascript";
       const completion = inline`
                                ├
           let max = arr[0];
@@ -77,13 +74,12 @@ describe("postprocess", () => {
     });
 
     it("should limit scope at next indent level, including closing line, when completion is continuing uncompleted sentence in the prefix, and starting a new indent level in next line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function findMax(arr) {
           let max = arr[0];
           for║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
              ├ (let i = 1; i < arr.length; i++) {
             if (arr[i] > max) {
@@ -106,12 +102,11 @@ describe("postprocess", () => {
     });
 
     it("should limit scope at current indent level, including closing line, when completion starts new sentences at same indent level.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function findMax(arr) {
           let max = arr[0];║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
                            ├
           for (let i = 1; i < arr.length; i++) {
@@ -127,14 +122,13 @@ describe("postprocess", () => {
     });
 
     it("should allow only one level closing bracket", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function safeParse(json) {
           try {
             return JSON.parse(json);
           } catch (e) {
             return null;║
       `;
-      context.language = "javascript";
       const completion = inline`
                         ├
           }
@@ -149,12 +143,11 @@ describe("postprocess", () => {
     });
 
     it("should allow level closing bracket at current line, it looks same as starts new sentences", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function helloworld() {
           console.log("hello");
           ║
       `;
-      context.language = "javascript";
       const completion = inline`
           ├}┤
       `;
@@ -163,13 +156,12 @@ describe("postprocess", () => {
     });
 
     it("should not allow level closing bracket, when the suffix lines have same indent level", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function helloworld() {
           console.log("hello");║
           console.log("world");
         }
       `;
-      context.language = "javascript";
       const completion = inline`
                                ├
         }┤
@@ -180,14 +172,13 @@ describe("postprocess", () => {
     });
 
     it("should use indent level of previous line, when current line is empty.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function safeParse(json) {
           try {
             ║
           }
         }
       `;
-      context.language = "javascript";
       const completion = inline`
             ├return JSON.parse(json);
           } catch (e) {
@@ -209,15 +200,14 @@ describe("postprocess", () => {
   describe("limitScopeByIndentation: bad cases", () => {
     const filter = limitScopeByIndentation();
     it("cannot handle the case of indent that does'nt have a close line, e.g. chaining call", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function sortWords(input) {
           const output = input.trim()
             .split("\n")
             .map((line) => line.split(" "))
             ║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
             ├.flat()
             .sort()
@@ -239,11 +229,10 @@ describe("postprocess", () => {
     });
 
     it("cannot handle the case of indent that does'nt have a close line, e.g. python def function", async () => {
-      const context = documentContext`
+      const context = documentContext`python
         def findMax(arr):
           ║
       `;
-      context.language = "python";
       const completion = inline`
           ├max = arr[0]
           for i in range(1, len(arr)):
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts
@@ -1,3 +1,4 @@
+import { TextDocument } from "vscode-languageserver-textdocument";
 import path from "path";
 import fs from "fs-extra";
 import { v4 as uuid } from "uuid";
@@ -7,15 +8,14 @@ import { expect } from "chai";
 import { deepmerge } from "deepmerge-ts";
 import { ConfigData } from "../../config/type";
 import { defaultConfigData } from "../../config/default";
-import { CompletionItem } from "../solution";
-import { CompletionContext } from "../contexts";
+import { CompletionResultItem } from "../solution";
+import { buildCompletionContext, CompletionContext, CompletionExtraContexts } from "../contexts";
 import { preCacheProcess, postCacheProcess } from "./index";
 
 type PostprocessConfig = ConfigData["postprocess"];
 
 type DocumentContext = {
   prefix: string;
-  replacePrefix: string;
   completion: string;
   replaceSuffix: string;
   suffix: string;
@@ -24,39 +24,39 @@ type DocumentContext = {
 function parseDocContext(text: string): DocumentContext {
   const insertStart = text.indexOf("├");
   const insertEnd = text.lastIndexOf("┤");
-  let replaceStart = text.indexOf("╠");
-  if (replaceStart < 0) {
-    replaceStart = insertStart;
-  }
   let replaceEnd = text.lastIndexOf("╣");
   if (replaceEnd < 0) {
     replaceEnd = insertEnd;
   }
   return {
-    prefix: text.slice(0, replaceStart),
-    replacePrefix: text.slice(replaceStart + 1, insertStart),
+    prefix: text.slice(0, insertStart),
     completion: text.slice(insertStart + 1, insertEnd),
     replaceSuffix: text.slice(insertEnd + 1, replaceEnd),
     suffix: text.slice(replaceEnd + 1),
   };
 }
 
 function getDoc(context: DocumentContext): string {
-  return context.prefix + context.replacePrefix + context.replaceSuffix + context.suffix;
+  return context.prefix + context.replaceSuffix + context.suffix;
 }
 
 function getPosition(context: DocumentContext): number {
-  return context.prefix.length + context.replacePrefix.length;
+  return context.prefix.length;
 }
 
-function getCompletionFullText(context: DocumentContext): string {
-  return context.replacePrefix + context.completion;
+function getCompletionText(context: DocumentContext): string {
+  return context.completion;
 }
 
 describe("postprocess golden test", () => {
-  const postprocess = async (item: CompletionItem, config: PostprocessConfig): Promise<CompletionItem> => {
-    let processed = await preCacheProcess([item], config);
-    processed = await postCacheProcess(processed, config);
+  const postprocess = async (
+    item: CompletionResultItem,
+    context: CompletionContext,
+    extraContext: CompletionExtraContexts,
+    config: PostprocessConfig,
+  ): Promise<CompletionResultItem> => {
+    let processed = await preCacheProcess([item], context, extraContext, config);
+    processed = await postCacheProcess(processed, context, extraContext, config);
     return processed[0]!;
   };
 
@@ -67,23 +67,23 @@ describe("postprocess golden test", () => {
     it(testCase["description"] ?? file, async () => {
       const config = deepmerge(defaultConfigData["postprocess"], testCase["config"] ?? {}) as PostprocessConfig;
       const docContext = parseDocContext(testCase["context"]?.["text"] ?? "");
-      const context = new CompletionContext({
-        filepath: testCase["context"]?.["filepath"] ?? uuid(),
-        language: testCase["context"]?.["language"] ?? "plaintext",
-        text: getDoc(docContext),
-        position: getPosition(docContext),
-        indentation: testCase["context"]?.["indentation"],
-      });
-      const completionItem = new CompletionItem(
-        context,
-        getCompletionFullText(docContext),
-        docContext.replacePrefix,
-        docContext.replaceSuffix,
+      const textDocument = TextDocument.create(
+        testCase["context"]?.["filepath"] ?? uuid(),
+        testCase["context"]?.["language"] ?? "plaintext",
+        0,
+        getDoc(docContext),
       );
+      const context = buildCompletionContext(textDocument, textDocument.positionAt(getPosition(docContext)));
+      const completionItem = new CompletionResultItem(getCompletionText(docContext));
       const unchanged = completionItem;
-      const output = await postprocess(completionItem, config);
+      const output = await postprocess(
+        completionItem,
+        context,
+        { editorOptions: { indentation: testCase["context"]?.["indentation"] } },
+        config,
+      );
 
-      const checkExpected = (expected: CompletionItem) => {
+      const checkExpected = (expected: CompletionResultItem) => {
         if (testCase["expected"]?.["notEqual"]) {
           expect(output).to.not.deep.equal(expected);
         } else {
@@ -94,16 +94,11 @@ describe("postprocess golden test", () => {
       if (testCase["expected"]?.["unchanged"]) {
         checkExpected(unchanged);
       } else if (testCase["expected"]?.["discard"]) {
-        const expected = CompletionItem.createBlankItem(context);
+        const expected = new CompletionResultItem("");
         checkExpected(expected);
       } else {
         const expectedContext = parseDocContext(testCase["expected"]?.["text"] ?? "");
-        const expected = new CompletionItem(
-          context,
-          getCompletionFullText(expectedContext),
-          expectedContext.replacePrefix,
-          expectedContext.replaceSuffix,
-        );
+        const expected = new CompletionResultItem(getCompletionText(expectedContext));
         checkExpected(expected);
       }
     });
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts
@@ -5,12 +5,11 @@ describe("postprocess", () => {
   describe("removeDuplicatedBlockClosingLine", () => {
     const filter = removeDuplicatedBlockClosingLine();
     it("should remove duplicated block closing line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function hello() {
           ║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
           ├console.log("hello");
         }┤
@@ -23,7 +22,7 @@ describe("postprocess", () => {
     });
 
     it("should remove duplicated block closing line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function check(condition) {
           if (!condition) {
             ║
@@ -32,7 +31,6 @@ describe("postprocess", () => {
           }
         }
       `;
-      context.language = "javascript";
       const completion = inline`
             ├throw new Error("check not passed");
           }┤
@@ -46,13 +44,12 @@ describe("postprocess", () => {
     });
 
     it("should not remove non-duplicated block closing line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function check(condition) {
           if (!condition) {
             ║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
             ├throw new Error("check not passed");
           }┤
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts
@@ -1,28 +1,26 @@
-import { CompletionItem } from "../solution";
+import { CompletionResultItem } from "../solution";
 import { documentContext, inline, assertFilterResult } from "./testUtils";
 import { removeLineEndsWithRepetition } from "./removeLineEndsWithRepetition";
 
 describe("postprocess", () => {
   describe("removeLineEndsWithRepetition", () => {
     const filter = removeLineEndsWithRepetition();
     it("should drop one line completion ends with repetition", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let foo = ║
       `;
-      context.language = "javascript";
       const completion = inline`
                   ├foo = foo = foo = foo = foo = foo = foo =┤
       `;
-      const expected = CompletionItem.createBlankItem(context);
+      const expected = new CompletionResultItem("");
       await assertFilterResult(filter, context, completion, expected);
     });
 
     it("should remove last line that ends with repetition", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let largeNumber = 1000000
         let veryLargeNumber = ║
       `;
-      context.language = "javascript";
       const completion = inline`
                               ├1000000000
         let superLargeNumber = 1000000000000000000000000000000000000000000000┤
@@ -34,11 +32,10 @@ describe("postprocess", () => {
     });
 
     it("should keep repetition less than threshold", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let largeNumber = 1000000
         let veryLargeNumber = ║
       `;
-      context.language = "javascript";
       const completion = inline`
                               ├1000000000000┤
       `;
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts
@@ -5,14 +5,13 @@ describe("postprocess", () => {
   describe("removeRepetitiveBlocks", () => {
     const filter = removeRepetitiveBlocks();
     it("should remove repetitive blocks", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function myFuncA() {
           console.log("myFuncA called.");
         }
 
         ║
       `;
-      context.language = "javascript";
       const completion = inline`
         ├function myFuncB() {
           console.log("myFuncB called.");
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts
@@ -5,15 +5,14 @@ describe("postprocess", () => {
   describe("removeRepetitiveLines", () => {
     const filter = removeRepetitiveLines();
     it("should remove repetitive lines", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function hello() {
           console.log("hello");
         }
         hello();
         hello();
         ║
       `;
-      context.language = "javascript";
       const completion = inline`
         ├hello();
         hello();
@@ -33,11 +32,10 @@ describe("postprocess", () => {
     });
 
     it("should remove repetitive lines with patterns", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         const a = 1;
         ║
       `;
-      context.language = "javascript";
       const completion = inline`
         ├const b = 1;
         const c = 1;
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts b/clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts
@@ -1,19 +1,20 @@
+import { TextDocument } from "vscode-languageserver-textdocument";
 import type { PostprocessFilter } from "./base";
 import dedent from "dedent";
 import { expect, AssertionError } from "chai";
 import { v4 as uuid } from "uuid";
-import { CompletionContext } from "../contexts";
-import { CompletionItem } from "../solution";
+import { buildCompletionContext, CompletionContext, CompletionExtraContexts } from "../contexts";
+import { CompletionResultItem } from "../solution";
+import { splitLines } from "../../utils/string";
 
 // `║` is the cursor position
 export function documentContext(literals: TemplateStringsArray, ...placeholders: any[]): CompletionContext {
   const doc = dedent(literals, ...placeholders);
-  return new CompletionContext({
-    filepath: uuid(),
-    language: "",
-    text: doc.replace(/║/, ""),
-    position: doc.indexOf("║"),
-  });
+  const lines = splitLines(doc);
+  const language = lines[0]?.trim() ?? "plaintext";
+  const text = "\n" + lines.slice(1).join("");
+  const textDocument = TextDocument.create(uuid(), language, 0, text.replace(/║/, ""));
+  return buildCompletionContext(textDocument, textDocument.positionAt(text.indexOf("║")));
 }
 
 // `├` start of the inline completion to insert
@@ -25,30 +26,26 @@ export function inline(literals: TemplateStringsArray, ...placeholders: any[]):
   return inline.slice(inline.indexOf("├") + 1, inline.lastIndexOf("┤"));
 }
 
-type TestCompletionItem = CompletionItem | string | { text: string; replacePrefix?: string; replaceSuffix?: string };
+type TestCompletionItem = CompletionResultItem | string;
 
 export async function assertFilterResult(
   filter: PostprocessFilter,
-  context: CompletionContext,
+  context: CompletionContext & CompletionExtraContexts,
   input: TestCompletionItem,
   expected: TestCompletionItem,
 ) {
-  const wrapTestCompletionItem = (testItem: TestCompletionItem): CompletionItem => {
-    let item: CompletionItem;
-    if (testItem instanceof CompletionItem) {
+  const wrapTestCompletionItem = (testItem: TestCompletionItem): CompletionResultItem => {
+    let item: CompletionResultItem;
+    if (testItem instanceof CompletionResultItem) {
       item = testItem;
-    } else if (typeof testItem === "string") {
-      item = new CompletionItem(context, testItem);
     } else {
-      item = new CompletionItem(context, testItem.text, testItem.replacePrefix, testItem.replaceSuffix);
+      item = new CompletionResultItem(testItem);
     }
     return item;
   };
-  const output = await filter(wrapTestCompletionItem(input));
+  const output = await filter(wrapTestCompletionItem(input), context, context);
   const expectedOutput = wrapTestCompletionItem(expected);
   expect(output.text).to.equal(expectedOutput.text);
-  expect(output.replacePrefix).to.equal(expectedOutput.replacePrefix);
-  expect(output.replaceSuffix).to.equal(expectedOutput.replaceSuffix);
 }
 
 export async function assertFilterResultNotEqual(
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts
@@ -1,30 +1,28 @@
-import { CompletionItem } from "../solution";
+import { CompletionResultItem } from "../solution";
 import { documentContext, inline, assertFilterResult } from "./testUtils";
 import { trimMultiLineInSingleLineMode } from "./trimMultiLineInSingleLineMode";
 
 describe("postprocess", () => {
   describe("trimMultiLineInSingleLineMode", () => {
     const filter = trimMultiLineInSingleLineMode();
     it("should trim multiline completions, when the suffix have non-auto-closed chars in the current line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let error = new Error("Something went wrong");
         console.log(║message);
       `;
-      context.language = "javascript";
       const completion = inline`
                     ├message);
         throw error;┤
       `;
-      const expected = CompletionItem.createBlankItem(context);
+      const expected = new CompletionResultItem("");
       await assertFilterResult(filter, context, completion, expected);
     });
 
     it("should trim multiline completions, when the suffix have non-auto-closed chars in the current line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let error = new Error("Something went wrong");
         console.log(║message);
       `;
-      context.language = "javascript";
       const completion = inline`
                     ├error, message);
         throw error;┤
@@ -36,11 +34,10 @@ describe("postprocess", () => {
     });
 
     it("should allow singleline completions, when the suffix have non-auto-closed chars in the current line.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let error = new Error("Something went wrong");
         console.log(║message);
       `;
-      context.language = "javascript";
       const completion = inline`
                     ├error, ┤
       `;
@@ -49,10 +46,9 @@ describe("postprocess", () => {
     });
 
     it("should allow multiline completions, when the suffix only have auto-closed chars that will be replaced in the current line, such as `)]}`.", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function findMax(arr) {║}
       `;
-      context.language = "javascript";
       const completion = inline`
                                ├
           let max = arr[0];
diff --git a/clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts b/clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts
--- a/clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts
+++ b/clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts
@@ -5,10 +5,9 @@ describe("postprocess", () => {
   describe("trimSpace", () => {
     const filter = trimSpace();
     it("should remove trailing space", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let foo = new ║
       `;
-      context.language = "javascript";
       const completion = inline`
                       ├Foo(); ┤
         `;
@@ -19,10 +18,9 @@ describe("postprocess", () => {
     });
 
     it("should not remove trailing space if filling in line", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let foo = sum(║baz)
       `;
-      context.language = "javascript";
       const completion = inline`
                       ├bar, ┤
       `;
@@ -31,10 +29,9 @@ describe("postprocess", () => {
     });
 
     it("should remove trailing space if filling in line with suffix starts with space", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let foo = sum(║ baz)
       `;
-      context.language = "javascript";
       const completion = inline`
                       ├bar, ┤
       `;
@@ -45,12 +42,11 @@ describe("postprocess", () => {
     });
 
     it("should not remove leading space if current line is blank", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         function sum(a, b) {
         ║
         }
       `;
-      context.language = "javascript";
       const completion = inline`
         ├  return a + b;┤
       `;
@@ -59,10 +55,9 @@ describe("postprocess", () => {
     });
 
     it("should remove leading space if current line is not blank and ends with space", async () => {
-      const context = documentContext`
+      const context = documentContext`javascript
         let foo = ║
       `;
-      context.language = "javascript";
       const completion = inline`
                   ├ sum(bar, baz);┤
       `;
EOF_114329324912

# Navigate to the tabby-agent client directory where tests should be executed
cd /testbed/clients/tabby-agent

# Run the specific test files using pnpm and vitest
# Using the postprocess directory pattern to run all tests in that folder
pnpm test -- src/codeCompletion/postprocess/

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to original state
cd /testbed
git checkout 9266e3f9dd726c6c0deb318d5fa7896058edb77c \
  "clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeByBracketStack.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/calculateReplaceRangeBySemiColon.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/dropDuplicated.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/dropMinimum.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/formatIndentation.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/limitScopeByIndentation.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/postprocess.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeDuplicatedBlockClosingLine.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeLineEndsWithRepetition.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveBlocks.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/removeRepetitiveLines.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/testUtils.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/trimMultiLineInSingleLineMode.test.ts" \
  "clients/tabby-agent/src/codeCompletion/postprocess/trimSpace.test.ts"