#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the specific test file to ensure clean state
git checkout eb940d9c3b94ae86de8cc06652d8009cbfbc15ed "discovery/kubernetes/endpointslice_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/discovery/kubernetes/endpointslice_test.go b/discovery/kubernetes/endpointslice_test.go
--- a/discovery/kubernetes/endpointslice_test.go
+++ b/discovery/kubernetes/endpointslice_test.go
@@ -1194,11 +1194,12 @@ func TestEndpointSliceInfIndexersCount(t *testing.T) {
 		t.Run(tc.name, func(t *testing.T) {
 			t.Parallel()
 			var (
-				n                    *Discovery
-				mainInfIndexersCount int
+				n *Discovery
+				// service indexer is enabled by default
+				mainInfIndexersCount = 1
 			)
 			if tc.withNodeMetadata {
-				mainInfIndexersCount = 1
+				mainInfIndexersCount++
 				n, _ = makeDiscoveryWithMetadata(RoleEndpointSlice, NamespaceDiscovery{}, AttachMetadataConfig{Node: true})
 			} else {
 				n, _ = makeDiscovery(RoleEndpointSlice, NamespaceDiscovery{})
EOF_114329324912

# Execute the test as part of the kubernetes discovery package to ensure proper compilation
# with all package dependencies. The test will run all tests in the package but will focus
# on the specific test file due to the patch applied.
GO_ONLY=1 go test -v -p 1 ./discovery/kubernetes/
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout eb940d9c3b94ae86de8cc06652d8009cbfbc15ed "discovery/kubernetes/endpointslice_test.go"