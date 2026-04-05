#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 95cc7ca5f71bee8ca9ce05d27ac3bf5719ce6332 "test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java" "test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java b/test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java
--- a/test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java
+++ b/test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java
@@ -16,9 +16,13 @@ public class ProcessSemgrexRequestTest {
    * Build a fake request.  The same query will be repeated N times
    */
   public static CoreNLPProtos.SemgrexRequest buildFakeRequest(int numQueries, int numSemgrex) {
+    return buildFakeRequest(numQueries, numSemgrex, "{}=source >dobj=foo {}=target");
+  }
+
+  public static CoreNLPProtos.SemgrexRequest buildFakeRequest(int numQueries, int numSemgrex, String semgrexPattern) {
     CoreNLPProtos.SemgrexRequest.Builder request = CoreNLPProtos.SemgrexRequest.newBuilder();
     for (int i = 0; i < numSemgrex; ++i) {
-      request.addSemgrex("{}=source >dobj=foo {}=target");
+      request.addSemgrex(semgrexPattern);
     }
 
     for (int i = 0; i < numQueries; ++i) {
@@ -87,7 +91,7 @@ public void testSimpleRequest() {
     CoreNLPProtos.SemgrexResponse response = ProcessSemgrexRequest.processRequest(request);
 
     Assert.assertEquals("Expected exactly 1 reply", 1, response.getResultList().size());
-    checkResult(response, 1, 0);
+    checkResult(response, 1, 0, true);
   }
 
   @Test
@@ -96,39 +100,43 @@ public void testTwoSemgrex() {
     CoreNLPProtos.SemgrexResponse response = ProcessSemgrexRequest.processRequest(request);
 
     Assert.assertEquals("Expected exactly 1 reply", 1, response.getResultList().size());
-    checkResult(response, 2, 0);
+    checkResult(response, 2, 0, true);
   }
 
-  public static void checkResult(CoreNLPProtos.SemgrexResponse response, int numSemgrex, int graphIdx) {
+  public static void checkResult(CoreNLPProtos.SemgrexResponse response, int numSemgrex, int graphIdx, boolean shouldMatch) {
     CoreNLPProtos.SemgrexResponse.GraphResult result = response.getResultList().get(graphIdx);
 
     Assert.assertEquals("Expected exactly " + numSemgrex + " semgrex result(s)", numSemgrex, result.getResultList().size());
 
     int semgrexIdx = 0;
     for (CoreNLPProtos.SemgrexResponse.SemgrexResult semgrexResult : result.getResultList()) {
-      Assert.assertEquals("Expected exactly 1 match", 1, semgrexResult.getMatchList().size());
-      CoreNLPProtos.SemgrexResponse.Match match = semgrexResult.getMatchList().get(0);
-
-      Assert.assertEquals("Match is supposed to be at the root", 1, match.getMatchIndex());
-      Assert.assertEquals("Expected exactly 2 named nodes", 2, match.getNodeList().size());
-      Assert.assertEquals("Expected exactly 1 named reln", 1, match.getRelnList().size());
-      Assert.assertEquals("Expected exactly 1 named edge", 1, match.getEdgeList().size());
-
-      Assert.assertEquals("Node 1 should be source", 1, match.getNodeList().get(0).getMatchIndex());
-      Assert.assertEquals("Node 1 should be source", "source", match.getNodeList().get(0).getName());
-      Assert.assertEquals("Node 2 should be target", 2, match.getNodeList().get(1).getMatchIndex());
-      Assert.assertEquals("Node 2 should be target", "target", match.getNodeList().get(1).getName());
-
-      Assert.assertEquals("Reln dobj should be named foo", "foo", match.getRelnList().get(0).getName());
-      Assert.assertEquals("Reln dobj should be have reln dobj", "dobj", match.getRelnList().get(0).getReln());
-
-      Assert.assertEquals("Edge dobj should be named foo", "foo", match.getEdgeList().get(0).getName());
-      Assert.assertEquals("Edge dobj should have reln dobj", "dobj", match.getEdgeList().get(0).getReln());
-      Assert.assertEquals("Edge dobj source should be 1", 1, match.getEdgeList().get(0).getSource());
-      Assert.assertEquals("Edge dobj source should be 2", 2, match.getEdgeList().get(0).getTarget());
-
-      Assert.assertEquals("Graph count was off", graphIdx, match.getGraphIndex());
-      Assert.assertEquals("Semgrex pattern count was off", semgrexIdx, match.getSemgrexIndex());
+      if (shouldMatch) {
+        Assert.assertEquals("Expected exactly 1 match", 1, semgrexResult.getMatchList().size());
+        CoreNLPProtos.SemgrexResponse.Match match = semgrexResult.getMatchList().get(0);
+
+        Assert.assertEquals("Match is supposed to be at the root", 1, match.getMatchIndex());
+        Assert.assertEquals("Expected exactly 2 named nodes", 2, match.getNodeList().size());
+        Assert.assertEquals("Expected exactly 1 named reln", 1, match.getRelnList().size());
+        Assert.assertEquals("Expected exactly 1 named edge", 1, match.getEdgeList().size());
+
+        Assert.assertEquals("Node 1 should be source", 1, match.getNodeList().get(0).getMatchIndex());
+        Assert.assertEquals("Node 1 should be source", "source", match.getNodeList().get(0).getName());
+        Assert.assertEquals("Node 2 should be target", 2, match.getNodeList().get(1).getMatchIndex());
+        Assert.assertEquals("Node 2 should be target", "target", match.getNodeList().get(1).getName());
+
+        Assert.assertEquals("Reln dobj should be named foo", "foo", match.getRelnList().get(0).getName());
+        Assert.assertEquals("Reln dobj should be have reln dobj", "dobj", match.getRelnList().get(0).getReln());
+
+        Assert.assertEquals("Edge dobj should be named foo", "foo", match.getEdgeList().get(0).getName());
+        Assert.assertEquals("Edge dobj should have reln dobj", "dobj", match.getEdgeList().get(0).getReln());
+        Assert.assertEquals("Edge dobj source should be 1", 1, match.getEdgeList().get(0).getSource());
+        Assert.assertEquals("Edge dobj source should be 2", 2, match.getEdgeList().get(0).getTarget());
+
+        Assert.assertEquals("Graph count was off", graphIdx, match.getGraphIndex());
+        Assert.assertEquals("Semgrex pattern count was off", semgrexIdx, match.getSemgrexIndex());
+      } else {
+        Assert.assertEquals("Expected exactly 0 match", 0, semgrexResult.getMatchList().size());
+      }
       ++semgrexIdx;
     }
   }
@@ -147,8 +155,24 @@ public void testTwoGraphs() {
     CoreNLPProtos.SemgrexResponse response = ProcessSemgrexRequest.processRequest(request);
 
     Assert.assertEquals("Expected exactly 2 replies", 2, response.getResultList().size());
-    checkResult(response, 1, 0);
-    checkResult(response, 1, 1);
+    checkResult(response, 1, 0, true);
+    checkResult(response, 1, 1, true);
+  }
+
+  /**
+   * For this test, only the first graph should have any results for the given pattern
+   *<br>
+   * The uniq operator in the SemgrexPattern will remove the match from the second graph,
+   * since the second graph is identical
+   */
+  @Test
+  public void testTwoGraphsUniq() {
+    CoreNLPProtos.SemgrexRequest request = buildFakeRequest(2, 1, "{}=source >dobj=foo {}=target :: uniq source");
+    CoreNLPProtos.SemgrexResponse response = ProcessSemgrexRequest.processRequest(request);
+
+    Assert.assertEquals("Expected exactly 2 replies", 2, response.getResultList().size());
+    checkResult(response, 1, 0, true);
+    checkResult(response, 1, 1, false);
   }
 
   public byte[] buildRepeatedRequest(int count, boolean closingLength) throws IOException {
@@ -179,7 +203,7 @@ public void checkRepeatedResults(byte[] arr, int count) throws IOException {
       byte[] responseBytes = new byte[len];
       din.read(responseBytes, 0, len);
       CoreNLPProtos.SemgrexResponse response = CoreNLPProtos.SemgrexResponse.parseFrom(responseBytes);
-      checkResult(response, 1, 0);
+      checkResult(response, 1, 0, true);
     }
     int len = din.readInt();
     Assert.assertEquals("Repeated results should be over", 0, len);
diff --git a/test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java b/test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java
--- a/test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java
+++ b/test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java
@@ -589,6 +589,22 @@ public void testMultipleDepths() {
     runTest("{} 6,6<< {word:A}", graph, "I");
   }
 
+  /** After making UNIQ a separate token in the parser, we should verify that "uniq" can be treated as an identifier as well */
+  public void testUniqNamedNode() {
+    SemanticGraph graph = makeComplicatedGraph();
+
+    runTest("{} >obj ({} >expl {})", graph, "A");
+
+    SemgrexPattern pattern =
+      SemgrexPattern.compile("{} >obj ({} >expl {}=uniq)");
+    SemgrexMatcher matcher = pattern.matcher(graph);
+    assertTrue(matcher.find());
+    assertEquals(1, matcher.getNodeNames().size());
+    assertEquals("E", matcher.getNode("uniq").toString());
+    assertEquals("A", matcher.getMatch().toString());
+    assertFalse(matcher.find());
+  }
+
   public void testNamedNode() {
     SemanticGraph graph = makeComplicatedGraph();
 
@@ -1448,31 +1464,39 @@ public void testBrackets() {
             "[ate/VBD subj>Billz/NNP obj>[muffins compound>strawberry]]");
   }
 
+  String[] BATCH_PARSES = {
+    "[foo-1 nmod> bar-2]",
+    "[foo-1 obj> bar-2]",
+    "[bar-1 compound> baz-2]",
+    "[foo-1 nmod> baz-2 obj> bar-3]",
+  };
+
   /**
-   * A simple test of the batch search - should return 3 of the 4 sentences
+   * Build a list of sentences with BasicDependenciesAnnotation
    */
-  public void testBatchSearch() {
-    String[] parses = {
-      "[foo-1 nmod> bar-2]",
-      "[foo-1 obj> bar-2]",
-      "[bar-1 compound> baz-2]",
-      "[foo-1 nmod> baz-2 obj> bar-3]",
-    };
+  public List<CoreMap> buildSmallBatch() {
     List<CoreMap> sentences = new ArrayList<>();
-    for (String parse : parses) {
+    for (String parse : BATCH_PARSES) {
       SemanticGraph graph = SemanticGraph.valueOf(parse);
       CoreMap sentence = new ArrayCoreMap();
       sentence.set(SemanticGraphCoreAnnotations.BasicDependenciesAnnotation.class, graph);
       sentence.set(CoreAnnotations.TextAnnotation.class, parse);
       sentences.add(sentence);
     }
+    return sentences;
+  }
 
+  /**
+   * A simple test of the batch search - should return 3 of the 4 sentences
+   */
+  public void testBatchSearch() {
+    List<CoreMap> sentences = buildSmallBatch();
     SemgrexPattern semgrex = SemgrexPattern.compile("{word:foo}=x > {}=y");
-    List<Pair<CoreMap, List<SemgrexMatch>>> matches = semgrex.matchSentences(sentences);
+    List<Pair<CoreMap, List<SemgrexMatch>>> matches = semgrex.matchSentences(sentences, false);
     String[] expectedMatches = {
-      parses[0],
-      parses[1],
-      parses[3],
+      BATCH_PARSES[0],
+      BATCH_PARSES[1],
+      BATCH_PARSES[3],
     };
     int[] expectedCount = {1, 1, 2};
     assertEquals(expectedMatches.length, matches.size());
@@ -1482,6 +1506,80 @@ public void testBatchSearch() {
     }
   }
 
+  /**
+   * Test that an illegal uniq expression throws an exception
+   *<br>
+   * Specifically, the expectation is for a SemgrexParseException
+   */
+  public void testBrokenUniq() {
+    try {
+      String pattern = "{word:foo}=foo :: uniq bar";
+      SemgrexPattern semgrex = SemgrexPattern.compile(pattern);
+      throw new RuntimeException("This expression should fail because the node name is unknown");
+    } catch (SemgrexParseException e) {
+      // yay
+    }
+  }
+
+  /**
+   * Test that a simple uniq expression is correctly parsed
+   */
+  public void testParsesUniq() {
+    String pattern = "{word:foo}=foo :: uniq foo";
+    SemgrexPattern semgrex = SemgrexPattern.compile(pattern);
+  }
+
+  /**
+   * Test the uniq functionality on a few simple parses
+   */
+  public void testBatchUniq() {
+    List<CoreMap> sentences = buildSmallBatch();
+    SemgrexPattern semgrex = SemgrexPattern.compile("{word:foo}=x > {}=y :: uniq x");
+    List<Pair<CoreMap, List<SemgrexMatch>>> matches = semgrex.matchSentences(sentences, false);
+    // only the first foo sentence should match when using "uniq x"
+    assertEquals(1, matches.size());
+    assertEquals(BATCH_PARSES[0], matches.get(0).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(0).second().size());
+
+    semgrex = SemgrexPattern.compile("{word:foo}=x > {}=y :: uniq");
+    matches = semgrex.matchSentences(sentences, false);
+    // same thing happens when using "uniq" and no nodes - only one match will occur
+    assertEquals(1, matches.size());
+    assertEquals(BATCH_PARSES[0], matches.get(0).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(0).second().size());
+
+    semgrex = SemgrexPattern.compile("{word:foo}=x > {}=y :: uniq y");
+    matches = semgrex.matchSentences(sentences, false);
+    // now it should match both foo>bar and foo>baz
+    assertEquals(2, matches.size());
+    assertEquals(BATCH_PARSES[0], matches.get(0).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(0).second().size());
+    assertEquals(BATCH_PARSES[3], matches.get(1).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(1).second().size());
+
+    semgrex = SemgrexPattern.compile("{}=x > {}=y :: uniq x y");
+    matches = semgrex.matchSentences(sentences, false);
+    // now it should batch each of foo>bar, bar>baz, foo>baz
+    assertEquals(3, matches.size());
+    assertEquals(BATCH_PARSES[0], matches.get(0).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(0).second().size());
+    assertEquals(BATCH_PARSES[2], matches.get(1).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(1).second().size());
+    assertEquals(BATCH_PARSES[3], matches.get(2).first().get(CoreAnnotations.TextAnnotation.class));
+    assertEquals(1, matches.get(2).second().size());
+  }
+
+  public static void outputBatchResults(SemgrexPattern pattern, List<CoreMap> sentences) {
+    List<Pair<CoreMap, List<SemgrexMatch>>> matches = pattern.matchSentences(sentences, false);
+    for (Pair<CoreMap, List<SemgrexMatch>> sentenceMatch : matches) {
+      System.out.println("Pattern matched at:");
+      System.out.println(sentenceMatch.first());
+      for (SemgrexMatch match : sentenceMatch.second()) {
+        System.out.println(match);
+      }
+    }
+  }
+
   public static void outputResults(String pattern, String graph,
                                    String ... ignored) {
     outputResults(SemgrexPattern.compile(pattern),
EOF_114329324912

# Run the target tests using Maven
# Execute both test classes in a single Maven command for efficiency
mvn test -Dtest=ProcessSemgrexRequestTest,SemgrexTest

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 95cc7ca5f71bee8ca9ce05d27ac3bf5719ce6332 "test/src/edu/stanford/nlp/semgraph/semgrex/ProcessSemgrexRequestTest.java" "test/src/edu/stanford/nlp/semgraph/semgrex/SemgrexTest.java"