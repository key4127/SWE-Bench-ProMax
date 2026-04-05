#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the specific test file to ensure clean state
git checkout 3f70f95ad835f42eb62eee1952f27e196a8df14e "test/unit/test_agraph.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/unit/test_agraph.c b/test/unit/test_agraph.c
--- a/test/unit/test_agraph.c
+++ b/test/unit/test_agraph.c
@@ -33,7 +33,7 @@ bool test_graph_to_agraph(void) {
 		.get_title = _graph_node_info_get_title,
 		.get_body = _graph_node_info_get_body
 	};
-	RAGraph *agraph = r_agraph_new_from_graph (graph, &cbs, NULL);
+	RAGraph *agraph = r_agraph_new_from_graph (core->cons, graph, &cbs, NULL);
 	mu_assert_notnull (agraph, "Couldn't create the graph");
 	mu_assert_eq (agraph->graph->nodes->length, 4, "Wrong node count");
 
EOF_114329324912

# First, check what tests are available to find the correct test name
echo "Available tests:"
meson test -C build --list

# Run the specific agraph test using the correct test name
echo "Running agraph test:"
meson test -C build agraph --verbose
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Clean up and revert changes
cd /testbed
git checkout 3f70f95ad835f42eb62eee1952f27e196a8df14e "test/unit/test_agraph.c"