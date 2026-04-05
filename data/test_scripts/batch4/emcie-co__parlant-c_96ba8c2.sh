#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 74d7445696b0e8b1b1dc479b17b4a296917c33ed "tests/sdk/test_guidelines.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/sdk/test_guidelines.py b/tests/sdk/test_guidelines.py
--- a/tests/sdk/test_guidelines.py
+++ b/tests/sdk/test_guidelines.py
@@ -14,12 +14,12 @@ async def setup(self, server: p.Server) -> None:
         self.g1 = await self.agent.create_guideline(condition="Condition 1", action="Action 1")
         self.g2 = await self.agent.create_guideline(condition="Condition 2", action="Action 2")
 
-        self.priority_id = await self.g1.prioritize_over(self.g2)
+        self.priority = await self.g1.prioritize_over(self.g2)
 
     async def run(self, ctx: Context) -> None:
         relationship_store = ctx.container[RelationshipStore]
 
-        rel_priority = await relationship_store.read_relationship(id=self.priority_id)
+        rel_priority = await relationship_store.read_relationship(id=self.priority.id)
         assert rel_priority.kind == GuidelineRelationshipKind.PRIORITY
 
 
@@ -33,12 +33,12 @@ async def setup(self, server: p.Server) -> None:
         self.g1 = await self.agent.create_guideline(condition="Condition 1", action="Action 1")
         self.g3 = await self.agent.create_guideline(condition="Condition 3", action="Action 3")
 
-        self.entail_id = await self.g1.entail(self.g3)
+        self.entailment = await self.g1.entail(self.g3)
 
     async def run(self, ctx: Context) -> None:
         relationship_store = ctx.container[RelationshipStore]
 
-        rel_entail = await relationship_store.read_relationship(id=self.entail_id)
+        rel_entail = await relationship_store.read_relationship(id=self.entailment.id)
         assert rel_entail.kind == GuidelineRelationshipKind.ENTAILMENT
 
 
@@ -52,19 +52,19 @@ async def setup(self, server: p.Server) -> None:
         self.g2 = await self.agent.create_guideline(condition="Condition 2", action="Action 2")
         self.g3 = await self.agent.create_guideline(condition="Condition 3", action="Action 3")
 
-        self.depend_id = await self.g2.depend_on(self.g3)
+        self.dependency = await self.g2.depend_on(self.g3)
 
     async def run(self, ctx: Context) -> None:
         relationship_store = ctx.container[RelationshipStore]
 
-        rel_depend = await relationship_store.read_relationship(id=self.depend_id)
+        rel_depend = await relationship_store.read_relationship(id=self.dependency.id)
         assert rel_depend.kind == GuidelineRelationshipKind.DEPENDENCY
 
 
 class Test_that_guideline_disambiguation_creates_relationships(SDKTest):
     async def setup(self, server: p.Server) -> None:
         self.agent = await server.create_agent(
-            name="Disambig Agent",
+            name="Disambiguation Agent",
             description="Agent for disambiguation",
         )
 
EOF_114329324912

# Ensure environment variables are set
export PYTHONPATH=/testbed/src
export PARLANT_HOME=/testbed/data

# Create data directory if it doesn't exist
mkdir -p /testbed/data

# Run the target test file
pytest --no-header -rA --tb=short -p no:cacheprovider tests/sdk/test_guidelines.py
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 74d7445696b0e8b1b1dc479b17b4a296917c33ed "tests/sdk/test_guidelines.py"