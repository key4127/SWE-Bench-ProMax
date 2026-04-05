#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout de78a7adb5a12c57a2e32dec2f779cd0eb3fd810 "ee/tabby-ui/test/utils/markdown.test.ts" "ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/ee/tabby-ui/test/utils/markdown.test.ts b/ee/tabby-ui/test/utils/markdown.test.ts
--- a/ee/tabby-ui/test/utils/markdown.test.ts
+++ b/ee/tabby-ui/test/utils/markdown.test.ts
@@ -1,6 +1,11 @@
+import { Filepath } from 'tabby-chat-panel/index'
 import { describe, expect, it } from 'vitest'
-import { formatObjectToMarkdownBlock, shouldAddPrefixNewline, shouldAddSuffixNewline } from '../../lib/utils/markdown'
-import { Filepath } from 'tabby-chat-panel/index';
+
+import {
+  formatObjectToMarkdownBlock,
+  shouldAddPrefixNewline,
+  shouldAddSuffixNewline
+} from '../../lib/utils/markdown'
 
 describe('formatObjectToMarkdownBlock - comprehensive tests', () => {
   describe('filepath types with standard content', () => {
@@ -18,53 +23,59 @@ function example() {
 const arrowFunc = () => {
   return Promise.resolve(42);
 };
-`;
+`
 
     it('should format Unix path with git format', () => {
-      const unixGitObj = { 
-        kind: "git", 
-        filepath: '/home/user/projects/example.js', 
-        gitUrl: "https://github.com/tabbyml/tabby" 
-      } as Filepath;
-      
-      const result = formatObjectToMarkdownBlock('file', unixGitObj, jsContent);
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${JSON.stringify(unixGitObj)}`);
-      expect(result).toContain(jsContent);
-      expect(result).toContain('```');
-    });
+      const unixGitObj = {
+        kind: 'git',
+        filepath: '/home/user/projects/example.js',
+        gitUrl: 'https://github.com/tabbyml/tabby'
+      } as Filepath
+
+      const result = formatObjectToMarkdownBlock('file', unixGitObj, jsContent)
+      const expectedMeta = JSON.stringify({ label: 'file', object: unixGitObj })
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedMeta)
+      expect(result).toContain(jsContent)
+      expect(result).toContain('```')
+    })
 
     it('should format Unix path with uri format', () => {
-      const unixUriObj = { 
-        kind: "uri", 
-        uri: '/home/user/projects/example.js' 
-      } as Filepath;
-      
-      const result = formatObjectToMarkdownBlock('file', unixUriObj, jsContent);
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${JSON.stringify(unixUriObj)}`);
-      expect(result).toContain(jsContent);
-      expect(result).toContain('```');
-    });
+      const unixUriObj = {
+        kind: 'uri',
+        uri: '/home/user/projects/example.js'
+      } as Filepath
+
+      const result = formatObjectToMarkdownBlock('file', unixUriObj, jsContent)
+      const expectedMeta = JSON.stringify({ label: 'file', object: unixUriObj })
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedMeta)
+      expect(result).toContain(jsContent)
+      expect(result).toContain('```')
+    })
 
     it('should format Windows path with uri format and backslashes', () => {
-      const winUriObj = { 
-        kind: "uri", 
-        uri: 'C:\\Users\\johndoe\\Projects\\example.js' 
-      } as Filepath;
-      
-      const result = formatObjectToMarkdownBlock('file', winUriObj, jsContent);
-      
-      const expectedJson = JSON.stringify(winUriObj).replace(/\\\\/g, '\\\\\\');
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${expectedJson}`);
-      expect(result).toContain(jsContent);
-      expect(result).toContain('```');
-    });
-  });
+      const winUriObj = {
+        kind: 'uri',
+        uri: 'C:\\Users\\johndoe\\Projects\\example.js'
+      } as Filepath
+
+      const result = formatObjectToMarkdownBlock('file', winUriObj, jsContent)
+
+      // Check for the structure, accounting for potential extra escaping by markdown stringifier
+      const expectedLabelPart = '"label":"file"'
+      const expectedObjectPart =
+        '"object":{"kind":"uri","uri":"C:\\\\\\Users\\\\\\johndoe\\\\\\Projects\\\\\\example.js"}' // Match literal triple backslash
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedLabelPart)
+      expect(result).toContain(expectedObjectPart)
+      expect(result).toContain(jsContent)
+      expect(result).toContain('```')
+    })
+  })
 
   describe('markdown content handling', () => {
     const markdownContent = `# Example Markdown Document
@@ -94,90 +105,121 @@ fn main() {
 * List item 1
 * List item 2
   * Nested list item
-`;
+`
 
     it('should correctly handle markdown with nested code blocks', () => {
-      const gitObj = { 
-        kind: "git", 
-        filepath: '/home/user/docs/README.md', 
-        gitUrl: "https://github.com/tabbyml/tabby" 
-      } as Filepath;
-      
-      const result = formatObjectToMarkdownBlock('file', gitObj, markdownContent);
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${JSON.stringify(gitObj)}`);
-      expect(result).toContain('```javascript');
-      expect(result).toContain('```rust');
-      expect(result).toContain('# Example Markdown Document');
-      expect(result).toContain('```');
-    });
+      const gitObj = {
+        kind: 'git',
+        filepath: '/home/user/docs/README.md',
+        gitUrl: 'https://github.com/tabbyml/tabby'
+      } as Filepath
+
+      const result = formatObjectToMarkdownBlock(
+        'file',
+        gitObj,
+        markdownContent
+      )
+      const expectedMeta = JSON.stringify({ label: 'file', object: gitObj })
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedMeta)
+      expect(result).toContain('```javascript')
+      expect(result).toContain('```rust')
+      expect(result).toContain('# Example Markdown Document')
+      expect(result).toContain('```')
+    })
 
     it('should correctly handle markdown with Windows paths', () => {
-      const winUriObj = { 
-        kind: "uri", 
-        uri: 'C:\\Users\\johndoe\\Documents\\README.md' 
-      } as Filepath;
-      
-      const result = formatObjectToMarkdownBlock('file', winUriObj, markdownContent);
-      
-      const expectedJson = JSON.stringify(winUriObj).replace(/\\\\/g, '\\\\\\');
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${expectedJson}`);
-      expect(result).toContain('```javascript');
-      expect(result).toContain('```rust');
-      expect(result).toContain('```');
-    });
-  });
+      const winUriObj = {
+        kind: 'uri',
+        uri: 'C:\\Users\\johndoe\\Documents\\README.md'
+      } as Filepath
+
+      const result = formatObjectToMarkdownBlock(
+        'file',
+        winUriObj,
+        markdownContent
+      )
+
+      // Check for the structure, accounting for potential extra escaping by markdown stringifier
+      const expectedLabelPart = '"label":"file"'
+      const expectedObjectPart =
+        '"object":{"kind":"uri","uri":"C:\\\\\\Users\\\\\\johndoe\\\\\\Documents\\\\\\README.md"}' // Match literal triple backslash
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedLabelPart)
+      expect(result).toContain(expectedObjectPart)
+      expect(result).toContain('```javascript')
+      expect(result).toContain('```rust')
+      expect(result).toContain('```')
+    })
+  })
 
   describe('special cases', () => {
     it('should handle path with additional metadata', () => {
-      const objWithMetadata = { 
-        kind: "git",
+      const objWithMetadata = {
+        kind: 'git',
         filepath: '/Users/johndoe/Developer/main.rs',
-        gitUrl: "https://github.com/tabbyml/tabby",
+        gitUrl: 'https://github.com/tabbyml/tabby',
         line: 5,
         highlight: true
-      } as Filepath;
-      
+      } as Filepath
+
       const rustContent = `// Example Rust code
 fn main() {
     println!("Hello, Rust!");
-}`;
-      
-      const result = formatObjectToMarkdownBlock('file', objWithMetadata, rustContent);
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${JSON.stringify(objWithMetadata)}`);
-      expect(result).toContain(rustContent);
-      expect(result).toContain('```');
-    });
+}`
+
+      const result = formatObjectToMarkdownBlock(
+        'file',
+        objWithMetadata,
+        rustContent
+      )
+
+      const expectedMeta = JSON.stringify({
+        label: 'file',
+        object: objWithMetadata
+      })
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedMeta)
+      expect(result).toContain(rustContent)
+      expect(result).toContain('```')
+    })
 
     it('should handle special characters in paths', () => {
-      const specialPathObj = { 
-        kind: "git",
+      const specialPathObj = {
+        kind: 'git',
         filepath: '/Users/user/Projects/special-chars/file with spaces.js',
-        gitUrl: "https://github.com/tabbyml/tabby",
+        gitUrl: 'https://github.com/tabbyml/tabby',
         branch: 'feature/new-branch'
-      } as Filepath;
-      
-      const jsContent = 'console.log("Special characters test");';
-      
-      const result = formatObjectToMarkdownBlock('file', specialPathObj, jsContent);
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${JSON.stringify(specialPathObj)}`);
-      expect(result).toContain(jsContent);
-      expect(result).toContain('```');
-    });
+      } as Filepath
+
+      const jsContent = 'console.log("Special characters test");'
+
+      const result = formatObjectToMarkdownBlock(
+        'file',
+        specialPathObj,
+        jsContent
+      )
+
+      const expectedMeta = JSON.stringify({
+        label: 'file',
+        object: specialPathObj
+      })
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedMeta)
+      expect(result).toContain(jsContent)
+      expect(result).toContain('```')
+    })
 
     it('should handle complex content types', () => {
-      const winObj = { 
-        kind: "uri", 
-        uri: 'D:\\Projects\\TypeScript\\interfaces.ts' 
-      } as Filepath;
-      
+      const winObj = {
+        kind: 'uri',
+        uri: 'D:\\Projects\\TypeScript\\interfaces.ts'
+      } as Filepath
+
       const tsContent = `/**
  * User interface representing a person.
  */
@@ -203,119 +245,143 @@ function createUser(name: string, email: string): User {
 // Test the function
 const newUser = createUser("John Doe", "john@example.com");
 console.log(newUser);
-`;
-      
-      const result = formatObjectToMarkdownBlock('file', winObj, tsContent);
-      
-      const expectedJson = JSON.stringify(winObj).replace(/\\\\/g, '\\\\\\');
-      
-      expect(result).toContain('```context label=file');
-      expect(result).toContain(`object=${expectedJson}`);
-      expect(result).toContain(tsContent);
-      expect(result).toContain('```');
-    });
-  });
-});
+`
+
+      const result = formatObjectToMarkdownBlock('file', winObj, tsContent)
+
+      // Check for the structure, accounting for potential extra escaping by markdown stringifier
+      const expectedLabelPart = '"label":"file"'
+      const expectedObjectPart =
+        '"object":{"kind":"uri","uri":"D:\\\\\\Projects\\\\\\TypeScript\\\\\\interfaces.ts"}' // Match literal triple backslash
+
+      expect(result).toContain('```context')
+      expect(result).toContain(expectedLabelPart)
+      expect(result).toContain(expectedObjectPart)
+      expect(result).toContain(tsContent)
+      expect(result).toContain('```')
+    })
+  })
+})
 
 describe('shouldAddPrefixNewline function', () => {
   it('should return false when index is at the start of text', () => {
-    const result = shouldAddPrefixNewline(0, 'Some text here');
-    expect(result).toBe(false);
-  });
+    const result = shouldAddPrefixNewline(0, 'Some text here')
+    expect(result).toBe(false)
+  })
 
   it('should return false when there is a newline character before the index', () => {
-    const result = shouldAddPrefixNewline(6, 'Hello\nworld');
-    expect(result).toBe(false);
-  });
+    const result = shouldAddPrefixNewline(6, 'Hello\nworld')
+    expect(result).toBe(false)
+  })
 
   it('should return true when there is text before the index', () => {
-    const result = shouldAddPrefixNewline(6, 'Hello world');
-    expect(result).toBe(true);
-  });
+    const result = shouldAddPrefixNewline(6, 'Hello world')
+    expect(result).toBe(true)
+  })
 
   it('should return false when there is only whitespace before the index', () => {
-    const result = shouldAddPrefixNewline(3, '   Text');
-    expect(result).toBe(false);
-  });
+    const result = shouldAddPrefixNewline(3, '   Text')
+    expect(result).toBe(false)
+  })
 
   it('should handle mixed whitespace and text properly', () => {
-    const result = shouldAddPrefixNewline(10, 'Hello    world');
-    expect(result).toBe(true);
-  });
-});
+    const result = shouldAddPrefixNewline(10, 'Hello    world')
+    expect(result).toBe(true)
+  })
+})
 
 describe('shouldAddSuffixNewline function', () => {
   it('should return false when index is at the end of text', () => {
-    const text = 'Some text here';
-    const result = shouldAddSuffixNewline(text.length, text);
-    expect(result).toBe(false);
-  });
+    const text = 'Some text here'
+    const result = shouldAddSuffixNewline(text.length, text)
+    expect(result).toBe(false)
+  })
 
   it('should return false when there is a newline character after the index', () => {
-    const result = shouldAddSuffixNewline(5, 'Hello\nworld');
-    expect(result).toBe(false);
-  });
+    const result = shouldAddSuffixNewline(5, 'Hello\nworld')
+    expect(result).toBe(false)
+  })
 
   it('should return true when there is text after the index', () => {
-    const result = shouldAddSuffixNewline(5, 'Hello world');
-    expect(result).toBe(true);
-  });
+    const result = shouldAddSuffixNewline(5, 'Hello world')
+    expect(result).toBe(true)
+  })
 
   it('should return false when there is only whitespace after the index', () => {
-    const result = shouldAddSuffixNewline(4, 'Text   ');
-    expect(result).toBe(false);
-  });
+    const result = shouldAddSuffixNewline(4, 'Text   ')
+    expect(result).toBe(false)
+  })
 
   it('should handle consecutive placeholder scenario correctly', () => {
     // Simulate two placeholders next to each other
-    const text = '[[file:{}]][[file:{}]]';
-    const firstPlaceholderEnd = 11;
-    
-    const result = shouldAddSuffixNewline(firstPlaceholderEnd, text);
-    expect(result).toBe(true);
-  });
-});
+    const text = '[[file:{}]][[file:{}]]'
+    const firstPlaceholderEnd = 11
+
+    const result = shouldAddSuffixNewline(firstPlaceholderEnd, text)
+    expect(result).toBe(true)
+  })
+})
 
 describe('formatObjectToMarkdownBlock with options', () => {
   it('should respect addPrefixNewline and addSuffixNewline options', () => {
-    const unixGitObj = { 
-      kind: "git", 
-      filepath: '/home/user/projects/example.js', 
-      gitUrl: "https://github.com/tabbyml/tabby" 
-    } as Filepath;
-    
-    const jsContent = 'console.log("Hello");';
-    
+    const unixGitObj = {
+      kind: 'git',
+      filepath: '/home/user/projects/example.js',
+      gitUrl: 'https://github.com/tabbyml/tabby'
+    } as Filepath
+
+    const jsContent = 'console.log("Hello");'
+
     // With both newlines
-    const resultBoth = formatObjectToMarkdownBlock('file', unixGitObj, jsContent, {
-      addPrefixNewline: true,
-      addSuffixNewline: true
-    });
-    expect(resultBoth.startsWith('\n')).toBe(true);
-    expect(resultBoth.endsWith('\n')).toBe(true);
-    
+    const resultBoth = formatObjectToMarkdownBlock(
+      'file',
+      unixGitObj,
+      jsContent,
+      {
+        addPrefixNewline: true,
+        addSuffixNewline: true
+      }
+    )
+    expect(resultBoth.startsWith('\n')).toBe(true)
+    expect(resultBoth.endsWith('\n')).toBe(true)
+
     // With no newlines
-    const resultNone = formatObjectToMarkdownBlock('file', unixGitObj, jsContent, {
-      addPrefixNewline: false,
-      addSuffixNewline: false
-    });
-    expect(resultNone.startsWith('\n')).toBe(false);
-    expect(resultNone.endsWith('\n')).toBe(false);
-    
+    const resultNone = formatObjectToMarkdownBlock(
+      'file',
+      unixGitObj,
+      jsContent,
+      {
+        addPrefixNewline: false,
+        addSuffixNewline: false
+      }
+    )
+    expect(resultNone.startsWith('\n')).toBe(false)
+    expect(resultNone.endsWith('\n')).toBe(false)
+
     // With only prefix newline
-    const resultPrefix = formatObjectToMarkdownBlock('file', unixGitObj, jsContent, {
-      addPrefixNewline: true,
-      addSuffixNewline: false
-    });
-    expect(resultPrefix.startsWith('\n')).toBe(true);
-    expect(resultPrefix.endsWith('\n')).toBe(false);
-    
+    const resultPrefix = formatObjectToMarkdownBlock(
+      'file',
+      unixGitObj,
+      jsContent,
+      {
+        addPrefixNewline: true,
+        addSuffixNewline: false
+      }
+    )
+    expect(resultPrefix.startsWith('\n')).toBe(true)
+    expect(resultPrefix.endsWith('\n')).toBe(false)
+
     // With only suffix newline
-    const resultSuffix = formatObjectToMarkdownBlock('file', unixGitObj, jsContent, {
-      addPrefixNewline: false,
-      addSuffixNewline: true
-    });
-    expect(resultSuffix.startsWith('\n')).toBe(false);
-    expect(resultSuffix.endsWith('\n')).toBe(true);
-  });
-});
\ No newline at end of file
+    const resultSuffix = formatObjectToMarkdownBlock(
+      'file',
+      unixGitObj,
+      jsContent,
+      {
+        addPrefixNewline: false,
+        addSuffixNewline: true
+      }
+    )
+    expect(resultSuffix.startsWith('\n')).toBe(false)
+    expect(resultSuffix.endsWith('\n')).toBe(true)
+  })
+})
diff --git a/ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts b/ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts
--- a/ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts
+++ b/ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts
@@ -1,103 +1,128 @@
 import { describe, expect, it } from 'vitest'
-import { createPlaceholderNode, parseCodeBlockMeta } from '../../lib/utils/markdown/remark-codeblock-to-placeholder'
+
+import {
+  createPlaceholderNode,
+  parseCodeBlockMeta
+} from '../../lib/utils/markdown/remark-codeblock-to-placeholder'
 
 describe('parseCodeBlockMeta', () => {
-  it('should parse meta with multiple key-value pairs', () => {
-    const meta = 'label=file object={"filepath": "/test.js"}';
-    const result = parseCodeBlockMeta(meta);
-    
-    expect(result.label).toBe('file');
-    // The function only splits by '=' and doesn't parse the JSON content
-    // So we just check that the string contains the start of the object
-    const objectValue = result.object;
-    expect(objectValue).toBeDefined();
-    expect(objectValue.startsWith('{"filepath"')).toBeTruthy();
-  });
-
-  it('should handle empty meta', () => {
-    const result = parseCodeBlockMeta('');
-    expect(Object.keys(result).length).toBe(0);
-  });
+  it('should parse meta string containing JSON object', () => {
+    const meta = '{"label":"file", "object":{"filepath": "/test.js"}}'
+    const result = parseCodeBlockMeta(meta)
+
+    expect(result.label).toBe('file')
+    expect(result.object).toEqual({ filepath: '/test.js' }) // Expect parsed object
+  })
+
+  it('should handle empty meta string', () => {
+    const result = parseCodeBlockMeta('')
+    expect(Object.keys(result).length).toBe(0)
+  })
 
   it('should handle null meta', () => {
-    const result = parseCodeBlockMeta(null);
-    expect(Object.keys(result).length).toBe(0);
-  });
+    const result = parseCodeBlockMeta(null)
+    expect(Object.keys(result).length).toBe(0)
+  })
 
   it('should handle undefined meta', () => {
-    const result = parseCodeBlockMeta(undefined);
-    expect(Object.keys(result).length).toBe(0);
-  });
-
-  it('should handle meta with only keys (no values)', () => {
-    const meta = 'key1 key2';
-    const result = parseCodeBlockMeta(meta);
-    expect(Object.keys(result).length).toBe(0);
-  });
-
-  it('should handle meta with complex values', () => {
-    const meta = 'label=file object={"complex": {"nested": true, "array": [1,2,3]}}';
-    const result = parseCodeBlockMeta(meta);
-    
-    expect(result.label).toBe('file');
-    // The function only splits by '=' and doesn't parse the JSON content
-    // So we just check that the string contains the start of the object
-    const objectValue = result.object;
-    expect(objectValue).toBeDefined();
-    expect(objectValue.startsWith('{"complex"')).toBeTruthy();
-  });
-});
+    const result = parseCodeBlockMeta(undefined)
+    expect(Object.keys(result).length).toBe(0)
+  })
+
+  it('should handle invalid JSON meta string', () => {
+    const meta = 'label=file object={invalid json' // Invalid JSON
+    const result = parseCodeBlockMeta(meta)
+    // Should return empty object on parse error
+    expect(Object.keys(result).length).toBe(0)
+  })
+
+  it('should parse complex JSON object in meta', () => {
+    const meta =
+      '{"label":"file", "object":{"complex": {"nested": true, "array": [1,2,3]}}}'
+    const result = parseCodeBlockMeta(meta)
+
+    expect(result.label).toBe('file')
+    expect(result.object).toEqual({
+      complex: { nested: true, array: [1, 2, 3] }
+    })
+  })
+
+  it('should correctly parse nested objects from JSON meta', () => {
+    const meta =
+      '{"label":"symbol", "object":{"filepath":{"kind":"git","filepath":"CODE_OF_CONDUCT.md","gitUrl":"https://github.com/TabbyML/tabby"},"range":{"start":1,"end":15},"label":"# Contributor Covenant Code of Conduct"}}'
+    const result = parseCodeBlockMeta(meta)
+
+    expect(result.label).toBe('symbol')
+    expect(result.object).toEqual({
+      filepath: {
+        kind: 'git',
+        filepath: 'CODE_OF_CONDUCT.md',
+        gitUrl: 'https://github.com/TabbyML/tabby'
+      },
+      range: { start: 1, end: 15 },
+      label: '# Contributor Covenant Code of Conduct'
+    })
+  })
+
+  // Removed tests that relied on the old key=value parsing logic
+  // as the function now expects a single JSON string.
+})
 
 describe('createPlaceholderNode', () => {
-  it('should create a file placeholder node', () => {
+  it('should create a file placeholder node with stringified object', () => {
     const fileObject = {
       kind: 'git',
       filepath: '/path/to/file.js',
       gitUrl: 'git@github.com:user/repo.git'
-    };
-    
-    const result = createPlaceholderNode('file', fileObject);
-    
-    expect(result.type).toBe('placeholder');
-    expect(result.placeholderType).toBe('file');
-    expect(result.attributes.object).toEqual(fileObject);
-  });
-
-  it('should create a symbol placeholder node', () => {
+    }
+    const fileObjectString = JSON.stringify(fileObject)
+
+    const result = createPlaceholderNode('file', fileObjectString) // Pass stringified object
+
+    expect(result.type).toBe('placeholder')
+    expect(result.placeholderType).toBe('file')
+    expect(result.attributes.object).toBe(fileObjectString) // Expect the string back
+  })
+
+  it('should create a symbol placeholder node with stringified object', () => {
     const symbolObject = {
       name: 'myFunction',
       type: 'function',
       filepath: '/path/to/file.js'
-    };
-    
-    const result = createPlaceholderNode('symbol', symbolObject);
-    
-    expect(result.type).toBe('placeholder');
-    expect(result.placeholderType).toBe('symbol');
-    expect(result.attributes.object).toEqual(symbolObject);
-  });
+    }
+    const symbolObjectString = JSON.stringify(symbolObject)
+
+    const result = createPlaceholderNode('symbol', symbolObjectString) // Pass stringified object
+
+    expect(result.type).toBe('placeholder')
+    expect(result.placeholderType).toBe('symbol')
+    expect(result.attributes.object).toBe(symbolObjectString) // Expect the string back
+  })
 
   it('should create a contextCommand placeholder node', () => {
-    const result = createPlaceholderNode('contextCommand', 'changes');
-    
-    expect(result.type).toBe('placeholder');
-    expect(result.placeholderType).toBe('contextCommand');
-    expect(result.attributes.object).toBe('changes');
-  });
-
-  it('should handle string object', () => {
-    const result = createPlaceholderNode('file', 'simple-string');
-    
-    expect(result.type).toBe('placeholder');
-    expect(result.placeholderType).toBe('file');
-    expect(result.attributes.object).toBe('simple-string');
-  });
-
-  it('should handle null object', () => {
-    const result = createPlaceholderNode('file', null);
-    
-    expect(result.type).toBe('placeholder');
-    expect(result.placeholderType).toBe('file');
-    expect(result.attributes.object).toBeNull();
-  });
-}); 
\ No newline at end of file
+    const command = 'changes'
+    const result = createPlaceholderNode('contextCommand', command)
+
+    expect(result.type).toBe('placeholder')
+    expect(result.placeholderType).toBe('contextCommand')
+    expect(result.attributes.object).toBe(command)
+  })
+
+  it('should handle simple string object', () => {
+    const simpleString = 'simple-string'
+    const result = createPlaceholderNode('file', simpleString)
+
+    expect(result.type).toBe('placeholder')
+    expect(result.placeholderType).toBe('file')
+    expect(result.attributes.object).toBe(simpleString)
+  })
+
+  it('should handle stringified null object', () => {
+    const nullString = JSON.stringify(null) // Pass 'null' as a string
+    const result = createPlaceholderNode('file', nullString)
+
+    expect(result.type).toBe('placeholder')
+    expect(result.placeholderType).toBe('file')
+    expect(result.attributes.object).toBe(nullString) // Expect 'null' string back
+  })
+})
EOF_114329324912

# Navigate to the tabby-ui directory where tests should be executed
cd /testbed/ee/tabby-ui

# Run the specific test files using the test script defined in package.json
pnpm test test/utils/markdown.test.ts test/utils/remark-codeblock-to-placeholder.test.ts

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to original state
cd /testbed
git checkout de78a7adb5a12c57a2e32dec2f779cd0eb3fd810 "ee/tabby-ui/test/utils/markdown.test.ts" "ee/tabby-ui/test/utils/remark-codeblock-to-placeholder.test.ts"