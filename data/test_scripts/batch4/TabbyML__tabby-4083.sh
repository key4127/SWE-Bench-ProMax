#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 4d5781e74abf070cd6eef52bec5f3d4da8a95a4e "clients/vscode/src/inline-edit/util.test.ts"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/clients/vscode/src/inline-edit/util.test.ts b/clients/vscode/src/inline-edit/util.test.ts
--- a/clients/vscode/src/inline-edit/util.test.ts
+++ b/clients/vscode/src/inline-edit/util.test.ts
@@ -1,6 +1,6 @@
 import { describe } from "mocha";
 import { expect } from "chai";
-import { parseUserCommand, InlineEditParseResult } from "./util";
+import { parseUserCommand, InlineEditParseResult, MentionType } from "./util";
 
 describe("parseInput", () => {
   it("should parse input correctly", () => {
@@ -17,7 +17,7 @@ describe("parseInput", () => {
     const input = `@file1`;
 
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1"],
+      mentions: [{ text: "file1", type: MentionType.File }],
       mentionQuery: "file1",
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -57,7 +57,7 @@ describe("parseInput", () => {
     const input = ` @file1`;
 
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1"],
+      mentions: [{ text: "file1", type: MentionType.File }],
       mentionQuery: "file1",
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -67,7 +67,7 @@ describe("parseInput", () => {
     const input = `@file1 `;
 
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1"],
+      mentions: [{ text: "file1", type: MentionType.File }],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -76,7 +76,10 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = `@file1 @file2`;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1", "file2"],
+      mentions: [
+        { text: "file1", type: MentionType.File },
+        { text: "file2", type: MentionType.File },
+      ],
       mentionQuery: "file2",
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -85,7 +88,10 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = `@file1 @file2 `;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1", "file2"],
+      mentions: [
+        { text: "file1", type: MentionType.File },
+        { text: "file2", type: MentionType.File },
+      ],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -94,7 +100,10 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = ` @file1 @file2 this is a user command`;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1", "file2"],
+      mentions: [
+        { text: "file1", type: MentionType.File },
+        { text: "file2", type: MentionType.File },
+      ],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -103,7 +112,10 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = ` @file1 @file2 this is a user command@file3`;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1", "file2"],
+      mentions: [
+        { text: "file1", type: MentionType.File },
+        { text: "file2", type: MentionType.File },
+      ],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -112,7 +124,11 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = ` @file1 @file2 this is a user command @file3`;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file1", "file2", "file3"],
+      mentions: [
+        { text: "file1", type: MentionType.File },
+        { text: "file2", type: MentionType.File },
+        { text: "file3", type: MentionType.File },
+      ],
       mentionQuery: "file3",
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -121,7 +137,7 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = ` this is a user command @file3 `;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file3"],
+      mentions: [{ text: "file3", type: MentionType.File }],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
@@ -130,7 +146,7 @@ describe("parseInput", () => {
   it("should parse input correctly", () => {
     const input = ` this is a @file3  user command `;
     const parseResult: InlineEditParseResult = {
-      mentions: ["file3"],
+      mentions: [{ text: "file3", type: MentionType.File }],
       mentionQuery: undefined,
     };
     expect(parseUserCommand(input)).to.deep.equal(parseResult);
EOF_114329324912

# Navigate to the VSCode client directory where tests should be executed
cd /testbed/clients/vscode

# Run the specific test file using mocha
pnpm mocha src/inline-edit/util.test.ts

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test file to original state
cd /testbed
git checkout 4d5781e74abf070cd6eef52bec5f3d4da8a95a4e "clients/vscode/src/inline-edit/util.test.ts"