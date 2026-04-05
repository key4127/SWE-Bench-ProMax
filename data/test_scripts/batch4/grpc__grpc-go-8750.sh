#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e78c0a5e3cd6a1a175bccc144292c7be716ca769 "internal/xds/balancer/clusterresolver/configbuilder_test.go" "internal/xds/xdsclient/tests/eds_watchers_test.go" "internal/xds/xdsclient/tests/federation_watchers_test.go" "internal/xds/xdsclient/tests/resource_update_test.go" "internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/xds/balancer/clusterresolver/configbuilder_test.go b/internal/xds/balancer/clusterresolver/configbuilder_test.go
--- a/internal/xds/balancer/clusterresolver/configbuilder_test.go
+++ b/internal/xds/balancer/clusterresolver/configbuilder_test.go
@@ -95,10 +95,12 @@ func init() {
 			endpoints = append(endpoints, resolver.Endpoint{Addresses: []resolver.Address{{Addr: addr}}})
 			ends = append(ends, xdsresource.Endpoint{
 				HealthStatus: xdsresource.EndpointHealthStatusHealthy,
-				Addresses: []string{
-					addr,
-					fmt.Sprintf("addr-%d-%d-additional-1", i, j),
-					fmt.Sprintf("addr-%d-%d-additional-2", i, j),
+				ResolverEndpoint: resolver.Endpoint{
+					Addresses: []resolver.Address{
+						{Addr: addr},
+						{Addr: fmt.Sprintf("addr-%d-%d-additional-1", i, j)},
+						{Addr: fmt.Sprintf("addr-%d-%d-additional-2", i, j)},
+					},
 				},
 			})
 		}
@@ -315,8 +317,8 @@ func TestBuildClusterImplConfigForDNS(t *testing.T) {
 			Name: "pick_first",
 		},
 	}
-	e1 := resolver.Endpoint{Addresses: []resolver.Address{{Addr: testEndpoints[0][0].Addresses[0]}}}
-	e2 := resolver.Endpoint{Addresses: []resolver.Address{{Addr: testEndpoints[0][1].Addresses[0]}}}
+	e1 := resolver.Endpoint{Addresses: []resolver.Address{{Addr: testEndpoints[0][0].ResolverEndpoint.Addresses[0].Addr}}}
+	e2 := resolver.Endpoint{Addresses: []resolver.Address{{Addr: testEndpoints[0][1].ResolverEndpoint.Addresses[0].Addr}}}
 	wantEndpoints := []resolver.Endpoint{
 		hierarchy.SetInEndpoint(e1, []string{"priority-3"}),
 		hierarchy.SetInEndpoint(e2, []string{"priority-3"}),
@@ -417,14 +419,14 @@ func TestBuildClusterImplConfigForEDS(t *testing.T) {
 		},
 	}
 	wantEndpoints := []resolver.Endpoint{
-		testEndpointWithAttrs(testEndpoints[0][0].Addresses, 20, 1, "priority-2-0", &testLocalityIDs[0]),
-		testEndpointWithAttrs(testEndpoints[0][1].Addresses, 20, 1, "priority-2-0", &testLocalityIDs[0]),
-		testEndpointWithAttrs(testEndpoints[1][0].Addresses, 80, 1, "priority-2-0", &testLocalityIDs[1]),
-		testEndpointWithAttrs(testEndpoints[1][1].Addresses, 80, 1, "priority-2-0", &testLocalityIDs[1]),
-		testEndpointWithAttrs(testEndpoints[2][0].Addresses, 20, 1, "priority-2-1", &testLocalityIDs[2]),
-		testEndpointWithAttrs(testEndpoints[2][1].Addresses, 20, 1, "priority-2-1", &testLocalityIDs[2]),
-		testEndpointWithAttrs(testEndpoints[3][0].Addresses, 80, 1, "priority-2-1", &testLocalityIDs[3]),
-		testEndpointWithAttrs(testEndpoints[3][1].Addresses, 80, 1, "priority-2-1", &testLocalityIDs[3]),
+		testEndpointWithAttrs(testEndpoints[0][0].ResolverEndpoint, 20, 1, "priority-2-0", &testLocalityIDs[0]),
+		testEndpointWithAttrs(testEndpoints[0][1].ResolverEndpoint, 20, 1, "priority-2-0", &testLocalityIDs[0]),
+		testEndpointWithAttrs(testEndpoints[1][0].ResolverEndpoint, 80, 1, "priority-2-0", &testLocalityIDs[1]),
+		testEndpointWithAttrs(testEndpoints[1][1].ResolverEndpoint, 80, 1, "priority-2-0", &testLocalityIDs[1]),
+		testEndpointWithAttrs(testEndpoints[2][0].ResolverEndpoint, 20, 1, "priority-2-1", &testLocalityIDs[2]),
+		testEndpointWithAttrs(testEndpoints[2][1].ResolverEndpoint, 20, 1, "priority-2-1", &testLocalityIDs[2]),
+		testEndpointWithAttrs(testEndpoints[3][0].ResolverEndpoint, 80, 1, "priority-2-1", &testLocalityIDs[3]),
+		testEndpointWithAttrs(testEndpoints[3][1].ResolverEndpoint, 80, 1, "priority-2-1", &testLocalityIDs[3]),
 	}
 
 	if diff := cmp.Diff(gotNames, wantNames); diff != "" {
@@ -547,16 +549,32 @@ func TestPriorityLocalitiesToClusterImpl(t *testing.T) {
 		localities: []xdsresource.Locality{
 			{
 				Endpoints: []xdsresource.Endpoint{
-					{Addresses: []string{"addr-1-1"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 90},
-					{Addresses: []string{"addr-1-2"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 10},
+					{
+						ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-1"}}},
+						Weight:           90,
+						HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+					},
+					{
+						ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-2"}}},
+						Weight:           10,
+						HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+					},
 				},
 				ID:     clients.Locality{Zone: "test-zone-1"},
 				Weight: 20,
 			},
 			{
 				Endpoints: []xdsresource.Endpoint{
-					{Addresses: []string{"addr-2-1"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 90},
-					{Addresses: []string{"addr-2-2"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 10},
+					{
+						ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-1"}}},
+						Weight:           90,
+						HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+					},
+					{
+						ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-2"}}},
+						Weight:           10,
+						HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+					},
 				},
 				ID:     clients.Locality{Zone: "test-zone-2"},
 				Weight: 80,
@@ -576,27 +594,43 @@ func TestPriorityLocalitiesToClusterImpl(t *testing.T) {
 			ChildPolicy:    &iserviceconfig.BalancerConfig{Name: roundrobin.Name},
 		},
 		wantEndpoints: []resolver.Endpoint{
-			testEndpointWithAttrs([]string{"addr-1-1"}, 20, 90, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
-			testEndpointWithAttrs([]string{"addr-1-2"}, 20, 10, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
-			testEndpointWithAttrs([]string{"addr-2-1"}, 80, 90, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
-			testEndpointWithAttrs([]string{"addr-2-2"}, 80, 10, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
+			testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-1"}}}, 20, 90, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
+			testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-2"}}}, 20, 10, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
+			testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-1"}}}, 80, 90, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
+			testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-2"}}}, 80, 10, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
 		},
 	},
 		{
 			name: "ring_hash as child",
 			localities: []xdsresource.Locality{
 				{
 					Endpoints: []xdsresource.Endpoint{
-						{Addresses: []string{"addr-1-1"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 90},
-						{Addresses: []string{"addr-1-2"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 10},
+						{
+							ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-1"}}},
+							Weight:           90,
+							HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+						},
+						{
+							ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-2"}}},
+							Weight:           10,
+							HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+						},
 					},
 					ID:     clients.Locality{Zone: "test-zone-1"},
 					Weight: 20,
 				},
 				{
 					Endpoints: []xdsresource.Endpoint{
-						{Addresses: []string{"addr-2-1"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 90},
-						{Addresses: []string{"addr-2-2"}, HealthStatus: xdsresource.EndpointHealthStatusHealthy, Weight: 10},
+						{
+							ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-1"}}},
+							Weight:           90,
+							HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+						},
+						{
+							ResolverEndpoint: resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-2"}}},
+							Weight:           10,
+							HealthStatus:     xdsresource.EndpointHealthStatusHealthy,
+						},
 					},
 					ID:     clients.Locality{Zone: "test-zone-2"},
 					Weight: 80,
@@ -612,10 +646,10 @@ func TestPriorityLocalitiesToClusterImpl(t *testing.T) {
 				},
 			},
 			wantEndpoints: []resolver.Endpoint{
-				testEndpointWithAttrs([]string{"addr-1-1"}, 20, 90, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
-				testEndpointWithAttrs([]string{"addr-1-2"}, 20, 10, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
-				testEndpointWithAttrs([]string{"addr-2-1"}, 80, 90, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
-				testEndpointWithAttrs([]string{"addr-2-2"}, 80, 10, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
+				testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-1"}}}, 20, 90, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
+				testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-1-2"}}}, 20, 10, "test-priority", &clients.Locality{Zone: "test-zone-1"}),
+				testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-1"}}}, 80, 90, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
+				testEndpointWithAttrs(resolver.Endpoint{Addresses: []resolver.Address{{Addr: "addr-2-2"}}}, 80, 10, "test-priority", &clients.Locality{Zone: "test-zone-2"}),
 			},
 		},
 	}
@@ -635,11 +669,7 @@ func TestPriorityLocalitiesToClusterImpl(t *testing.T) {
 	}
 }
 
-func testEndpointWithAttrs(addrStrs []string, localityWeight, endpointWeight uint32, priority string, lID *clients.Locality) resolver.Endpoint {
-	endpoint := resolver.Endpoint{}
-	for _, a := range addrStrs {
-		endpoint.Addresses = append(endpoint.Addresses, resolver.Address{Addr: a})
-	}
+func testEndpointWithAttrs(endpoint resolver.Endpoint, localityWeight, endpointWeight uint32, priority string, lID *clients.Locality) resolver.Endpoint {
 	path := []string{priority}
 	if lID != nil {
 		path = append(path, xdsinternal.LocalityString(*lID))
diff --git a/internal/xds/xdsclient/tests/eds_watchers_test.go b/internal/xds/xdsclient/tests/eds_watchers_test.go
--- a/internal/xds/xdsclient/tests/eds_watchers_test.go
+++ b/internal/xds/xdsclient/tests/eds_watchers_test.go
@@ -36,6 +36,7 @@ import (
 	"google.golang.org/grpc/internal/xds/clients"
 	"google.golang.org/grpc/internal/xds/xdsclient"
 	"google.golang.org/grpc/internal/xds/xdsclient/xdsresource"
+	"google.golang.org/grpc/resolver"
 	"google.golang.org/protobuf/types/known/wrapperspb"
 
 	v3endpointpb "github.com/envoyproxy/go-control-plane/envoy/config/endpoint/v3"
@@ -176,7 +177,12 @@ func (s) TestEDSWatch(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -199,7 +205,12 @@ func (s) TestEDSWatch(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -338,7 +349,12 @@ func (s) TestEDSWatch_TwoWatchesForSameResourceName(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -354,7 +370,12 @@ func (s) TestEDSWatch_TwoWatchesForSameResourceName(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost2, edsPort2)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost2, edsPort2)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -376,7 +397,12 @@ func (s) TestEDSWatch_TwoWatchesForSameResourceName(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -392,7 +418,12 @@ func (s) TestEDSWatch_TwoWatchesForSameResourceName(t *testing.T) {
 				update: xdsresource.EndpointsUpdate{
 					Localities: []xdsresource.Locality{
 						{
-							Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost2, edsPort2)}, Weight: 1}},
+							Endpoints: []xdsresource.Endpoint{{
+								ResolverEndpoint: resolver.Endpoint{
+									Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost2, edsPort2)}},
+								},
+								Weight: 1,
+							}},
 							ID: clients.Locality{
 								Region:  "region-1",
 								Zone:    "zone-1",
@@ -590,7 +621,12 @@ func (s) TestEDSWatch_ThreeWatchesForDifferentResourceNames(t *testing.T) {
 		update: xdsresource.EndpointsUpdate{
 			Localities: []xdsresource.Locality{
 				{
-					Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+					Endpoints: []xdsresource.Endpoint{{
+						ResolverEndpoint: resolver.Endpoint{
+							Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+						},
+						Weight: 1,
+					}},
 					ID: clients.Locality{
 						Region:  "region-1",
 						Zone:    "zone-1",
@@ -681,7 +717,12 @@ func (s) TestEDSWatch_ResourceCaching(t *testing.T) {
 		update: xdsresource.EndpointsUpdate{
 			Localities: []xdsresource.Locality{
 				{
-					Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+					Endpoints: []xdsresource.Endpoint{{
+						ResolverEndpoint: resolver.Endpoint{
+							Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+						},
+						Weight: 1,
+					}},
 					ID: clients.Locality{
 						Region:  "region-1",
 						Zone:    "zone-1",
@@ -813,7 +854,12 @@ func (s) TestEDSWatch_ValidResponseCancelsExpiryTimerBehavior(t *testing.T) {
 		update: xdsresource.EndpointsUpdate{
 			Localities: []xdsresource.Locality{
 				{
-					Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+					Endpoints: []xdsresource.Endpoint{{
+						ResolverEndpoint: resolver.Endpoint{
+							Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+						},
+						Weight: 1,
+					}},
 					ID: clients.Locality{
 						Region:  "region-1",
 						Zone:    "zone-1",
@@ -976,7 +1022,12 @@ func (s) TestEDSWatch_PartialValid(t *testing.T) {
 		update: xdsresource.EndpointsUpdate{
 			Localities: []xdsresource.Locality{
 				{
-					Endpoints: []xdsresource.Endpoint{{Addresses: []string{fmt.Sprintf("%s:%d", edsHost1, edsPort1)}, Weight: 1}},
+					Endpoints: []xdsresource.Endpoint{{
+						ResolverEndpoint: resolver.Endpoint{
+							Addresses: []resolver.Address{{Addr: fmt.Sprintf("%s:%d", edsHost1, edsPort1)}},
+						},
+						Weight: 1,
+					}},
 					ID: clients.Locality{
 						Region:  "region-1",
 						Zone:    "zone-1",
diff --git a/internal/xds/xdsclient/tests/federation_watchers_test.go b/internal/xds/xdsclient/tests/federation_watchers_test.go
--- a/internal/xds/xdsclient/tests/federation_watchers_test.go
+++ b/internal/xds/xdsclient/tests/federation_watchers_test.go
@@ -29,6 +29,7 @@ import (
 	"google.golang.org/grpc/internal/xds/clients"
 	"google.golang.org/grpc/internal/xds/xdsclient"
 	"google.golang.org/grpc/internal/xds/xdsclient/xdsresource"
+	"google.golang.org/grpc/resolver"
 
 	v3clusterpb "github.com/envoyproxy/go-control-plane/envoy/config/cluster/v3"
 	v3endpointpb "github.com/envoyproxy/go-control-plane/envoy/config/endpoint/v3"
@@ -291,8 +292,13 @@ func (s) TestFederation_EndpointsResourceContextParamOrder(t *testing.T) {
 		update: xdsresource.EndpointsUpdate{
 			Localities: []xdsresource.Locality{
 				{
-					Endpoints: []xdsresource.Endpoint{{Addresses: []string{"localhost:666"}, Weight: 1}},
-					Weight:    1,
+					Endpoints: []xdsresource.Endpoint{{
+						ResolverEndpoint: resolver.Endpoint{
+							Addresses: []resolver.Address{{Addr: "localhost:666"}},
+						},
+						Weight: 1,
+					}},
+					Weight: 1,
 					ID: clients.Locality{
 						Region:  "region-1",
 						Zone:    "zone-1",
diff --git a/internal/xds/xdsclient/tests/resource_update_test.go b/internal/xds/xdsclient/tests/resource_update_test.go
--- a/internal/xds/xdsclient/tests/resource_update_test.go
+++ b/internal/xds/xdsclient/tests/resource_update_test.go
@@ -36,6 +36,7 @@ import (
 	"google.golang.org/grpc/internal/xds/clients"
 	"google.golang.org/grpc/internal/xds/xdsclient"
 	"google.golang.org/grpc/internal/xds/xdsclient/xdsresource"
+	"google.golang.org/grpc/resolver"
 	"google.golang.org/protobuf/proto"
 	"google.golang.org/protobuf/testing/protocmp"
 	"google.golang.org/protobuf/types/known/anypb"
@@ -1089,16 +1090,26 @@ func (s) TestHandleEndpointsResponseFromManagementServer(t *testing.T) {
 			wantUpdate: xdsresource.EndpointsUpdate{
 				Localities: []xdsresource.Locality{
 					{
-						Endpoints: []xdsresource.Endpoint{{Addresses: []string{"addr1:314"}, Weight: 1}},
-						ID:        clients.Locality{SubZone: "locality-1"},
-						Priority:  1,
-						Weight:    1,
+						Endpoints: []xdsresource.Endpoint{{
+							ResolverEndpoint: resolver.Endpoint{
+								Addresses: []resolver.Address{{Addr: "addr1:314"}},
+							},
+							Weight: 1,
+						}},
+						ID:       clients.Locality{SubZone: "locality-1"},
+						Priority: 1,
+						Weight:   1,
 					},
 					{
-						Endpoints: []xdsresource.Endpoint{{Addresses: []string{"addr2:159"}, Weight: 1}},
-						ID:        clients.Locality{SubZone: "locality-2"},
-						Priority:  0,
-						Weight:    1,
+						Endpoints: []xdsresource.Endpoint{{
+							ResolverEndpoint: resolver.Endpoint{
+								Addresses: []resolver.Address{{Addr: "addr2:159"}},
+							},
+							Weight: 1,
+						}},
+						ID:       clients.Locality{SubZone: "locality-2"},
+						Priority: 0,
+						Weight:   1,
 					},
 				},
 			},
@@ -1123,16 +1134,26 @@ func (s) TestHandleEndpointsResponseFromManagementServer(t *testing.T) {
 			wantUpdate: xdsresource.EndpointsUpdate{
 				Localities: []xdsresource.Locality{
 					{
-						Endpoints: []xdsresource.Endpoint{{Addresses: []string{"addr1:314"}, Weight: 1}},
-						ID:        clients.Locality{SubZone: "locality-1"},
-						Priority:  1,
-						Weight:    1,
+						Endpoints: []xdsresource.Endpoint{{
+							ResolverEndpoint: resolver.Endpoint{
+								Addresses: []resolver.Address{{Addr: "addr1:314"}},
+							},
+							Weight: 1,
+						}},
+						ID:       clients.Locality{SubZone: "locality-1"},
+						Priority: 1,
+						Weight:   1,
 					},
 					{
-						Endpoints: []xdsresource.Endpoint{{Addresses: []string{"addr2:159"}, Weight: 1}},
-						ID:        clients.Locality{SubZone: "locality-2"},
-						Priority:  0,
-						Weight:    1,
+						Endpoints: []xdsresource.Endpoint{{
+							ResolverEndpoint: resolver.Endpoint{
+								Addresses: []resolver.Address{{Addr: "addr2:159"}},
+							},
+							Weight: 1,
+						}},
+						ID:       clients.Locality{SubZone: "locality-2"},
+						Priority: 0,
+						Weight:   1,
 					},
 				},
 			},
diff --git a/internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go b/internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go
--- a/internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go
+++ b/internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go
@@ -34,12 +34,23 @@ import (
 	"google.golang.org/grpc/internal/testutils"
 	"google.golang.org/grpc/internal/xds/clients"
 	"google.golang.org/grpc/internal/xds/xdsclient/xdsresource/version"
+	"google.golang.org/grpc/resolver"
 	"google.golang.org/protobuf/proto"
 	"google.golang.org/protobuf/types/known/anypb"
 	"google.golang.org/protobuf/types/known/structpb"
 	"google.golang.org/protobuf/types/known/wrapperspb"
 )
 
+func buildResolverEndpoint(addr []string, hostname string) resolver.Endpoint {
+	address := []resolver.Address{}
+	for _, a := range addr {
+		address = append(address, resolver.Address{Addr: a})
+	}
+	resolverEndpoint := resolver.Endpoint{Addresses: address}
+	resolverEndpoint = setHostname(resolverEndpoint, hostname)
+	return resolverEndpoint
+}
+
 func (s) TestEDSParseRespProto(t *testing.T) {
 	tests := []struct {
 		name    string
@@ -94,14 +105,10 @@ func (s) TestEDSParseRespProto(t *testing.T) {
 			m: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
 				endpoints1 := []endpointOpts{{addrWithPort: "addr1:314"}}
-				locOption1 := &addLocalityOptions{
-					Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_HEALTHY},
-				}
+				locOption1 := &addLocalityOptions{Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_HEALTHY}}
 				clab0.addLocality("locality-1", 0, 1, endpoints1, locOption1)
 				endpoints2 := []endpointOpts{{addrWithPort: "addr2:159"}}
-				locOption2 := &addLocalityOptions{
-					Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_HEALTHY},
-				}
+				locOption2 := &addLocalityOptions{Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_HEALTHY}}
 				clab0.addLocality("locality-2", 0, 0, endpoints2, locOption2)
 				return clab0.Build()
 			}(),
@@ -153,21 +160,19 @@ func (s) TestEDSParseRespProto(t *testing.T) {
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnhealthy,
-							Weight:       271,
-							Hostname:     "addr1",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnhealthy,
+							Weight:           271,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 1,
 						Weight:   1,
 					},
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr2:159"},
-							HealthStatus: EndpointHealthStatusDraining,
-							Weight:       828,
-							Hostname:     "addr2",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr2:159"}, "addr2"),
+							HealthStatus:     EndpointHealthStatusDraining,
+							Weight:           828,
 						}},
 						ID:       clients.Locality{SubZone: "locality-2"},
 						Priority: 0,
@@ -201,21 +206,19 @@ func (s) TestEDSParseRespProto(t *testing.T) {
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnhealthy,
-							Weight:       271,
-							Hostname:     "addr1",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnhealthy,
+							Weight:           271,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 1,
 						Weight:   1,
 					},
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr2:159"},
-							HealthStatus: EndpointHealthStatusDraining,
-							Weight:       828,
-							Hostname:     "addr2",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr2:159"}, "addr2"),
+							HealthStatus:     EndpointHealthStatusDraining,
+							Weight:           828,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -298,13 +301,13 @@ func (s) TestEDSParseRespProtoAdditionalAddrs(t *testing.T) {
 			name: "multiple localities",
 			m: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints1 := []endpointOpts{{addrWithPort: "addr1:997", additionalAddrWithPorts: []string{"addr1:1000"}}}
+				endpoints1 := []endpointOpts{{addrWithPort: "addr1:997", additionalAddrWithPorts: []string{"addr1:1000"}, hostname: "addr1"}}
 				locOption1 := &addLocalityOptions{
 					Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_UNHEALTHY},
 					Weight: []uint32{271},
 				}
 				clab0.addLocality("locality-1", 1, 1, endpoints1, locOption1)
-				endpoints2 := []endpointOpts{{addrWithPort: "addr2:998", additionalAddrWithPorts: []string{"addr2:1000"}}}
+				endpoints2 := []endpointOpts{{addrWithPort: "addr2:998", additionalAddrWithPorts: []string{"addr2:1000"}, hostname: "addr2"}}
 				locOption2 := &addLocalityOptions{
 					Health: []v3corepb.HealthStatus{v3corepb.HealthStatus_HEALTHY},
 					Weight: []uint32{828},
@@ -317,19 +320,19 @@ func (s) TestEDSParseRespProtoAdditionalAddrs(t *testing.T) {
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:997", "addr1:1000"},
-							HealthStatus: EndpointHealthStatusUnhealthy,
-							Weight:       271,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:997", "addr1:1000"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnhealthy,
+							Weight:           271,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 1,
 						Weight:   1,
 					},
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr2:998", "addr2:1000"},
-							HealthStatus: EndpointHealthStatusHealthy,
-							Weight:       828,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr2:998", "addr2:1000"}, "addr2"),
+							HealthStatus:     EndpointHealthStatusHealthy,
+							Weight:           828,
 						}},
 						ID:       clients.Locality{SubZone: "locality-2"},
 						Priority: 0,
@@ -541,21 +544,19 @@ func (s) TestUnmarshalEndpoints(t *testing.T) {
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnhealthy,
-							Weight:       271,
-							Hostname:     "addr1",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnhealthy,
+							Weight:           271,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 1,
 						Weight:   1,
 					},
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr2:159"},
-							HealthStatus: EndpointHealthStatusDraining,
-							Weight:       828,
-							Hostname:     "addr2",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr2:159"}, "addr2"),
+							HealthStatus:     EndpointHealthStatusDraining,
+							Weight:           828,
 						}},
 						ID:       clients.Locality{SubZone: "locality-2"},
 						Priority: 0,
@@ -574,21 +575,19 @@ func (s) TestUnmarshalEndpoints(t *testing.T) {
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnhealthy,
-							Weight:       271,
-							Hostname:     "addr1",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnhealthy,
+							Weight:           271,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 1,
 						Weight:   1,
 					},
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr2:159"},
-							HealthStatus: EndpointHealthStatusDraining,
-							Weight:       828,
-							Hostname:     "addr2",
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr2:159"}, "addr2"),
+							HealthStatus:     EndpointHealthStatusDraining,
+							Weight:           828,
 						}},
 						ID:       clients.Locality{SubZone: "locality-2"},
 						Priority: 0,
@@ -643,6 +642,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 							}),
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -651,9 +651,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 							Metadata: map[string]any{
 								"test-key": ProxyAddressMetadataValue{
 									Address: "1.2.3.4:1111",
@@ -684,6 +684,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 							},
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -692,9 +693,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 							Metadata: map[string]any{
 								"test-key": StructMetadataValue{Data: map[string]any{
 									"key": float64(123),
@@ -712,7 +713,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 			name: "typed_filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						TypedFilterMetadata: map[string]*anypb.Any{
@@ -735,9 +736,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -755,7 +756,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 			name: "filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						FilterMetadata: map[string]*structpb.Struct{
@@ -776,9 +777,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -820,6 +821,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 							},
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -828,9 +830,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 							Metadata: map[string]any{
 								"test-key": ProxyAddressMetadataValue{
 									Address: "1.2.3.4:1111",
@@ -848,7 +850,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 			name: "typed_filter_metadata_over_filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						TypedFilterMetadata: map[string]*anypb.Any{
@@ -880,9 +882,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -924,6 +926,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 							},
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -932,9 +935,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 							Metadata: map[string]any{
 								"test-key": ProxyAddressMetadataValue{
 									Address: "1.2.3.4:1111",
@@ -955,7 +958,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 			name: "both_filter_and_typed_filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						TypedFilterMetadata: map[string]*anypb.Any{
@@ -987,9 +990,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOn(t *testing.T
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1048,6 +1051,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 							}),
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -1056,9 +1060,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1084,6 +1088,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 							},
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -1092,9 +1097,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1107,7 +1112,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 			name: "typed_filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						TypedFilterMetadata: map[string]*anypb.Any{
@@ -1130,9 +1135,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1145,7 +1150,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 			name: "filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						FilterMetadata: map[string]*structpb.Struct{
@@ -1166,9 +1171,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1205,6 +1210,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 							},
 						},
 					},
+					hostname: "addr1",
 				}}
 				clab0.addLocality("locality-1", 1, 0, endpoints, nil)
 				return clab0.Build()
@@ -1213,9 +1219,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1228,7 +1234,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 			name: "both_filter_and_typed_filter_metadata_in_locality",
 			endpointProto: func() *v3endpointpb.ClusterLoadAssignment {
 				clab0 := newClaBuilder("test", nil)
-				endpoints := []endpointOpts{{addrWithPort: "addr1:314"}}
+				endpoints := []endpointOpts{{addrWithPort: "addr1:314", hostname: "addr1"}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
 						TypedFilterMetadata: map[string]*anypb.Any{
@@ -1260,9 +1266,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
@@ -1288,6 +1294,7 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 							}),
 						},
 					},
+					hostname: "addr1",
 				}}
 				locOption := &addLocalityOptions{
 					Metadata: &v3corepb.Metadata{
@@ -1309,9 +1316,9 @@ func (s) TestEDSParseRespProto_HTTP_Connect_CustomMetadata_EnvVarOff(t *testing.
 				Localities: []Locality{
 					{
 						Endpoints: []Endpoint{{
-							Addresses:    []string{"addr1:314"},
-							HealthStatus: EndpointHealthStatusUnknown,
-							Weight:       1,
+							ResolverEndpoint: buildResolverEndpoint([]string{"addr1:314"}, "addr1"),
+							HealthStatus:     EndpointHealthStatusUnknown,
+							Weight:           1,
 						}},
 						ID:       clients.Locality{SubZone: "locality-1"},
 						Priority: 0,
EOF_114329324912

# Execute tests for each package containing the target test files
# Using -cpu 1,4 and -timeout 7m as specified in the context retrieval
# Running tests package by package to ensure proper execution

echo "=========================================="
echo "Running tests for internal/xds/balancer/clusterresolver"
echo "=========================================="
go test -cpu 1,4 -timeout 7m ./internal/xds/balancer/clusterresolver/ -v
test1_rc=$?

echo "=========================================="
echo "Running tests for internal/xds/xdsclient/tests"
echo "=========================================="
go test -cpu 1,4 -timeout 7m ./internal/xds/xdsclient/tests/ -v
test2_rc=$?

echo "=========================================="
echo "Running tests for internal/xds/xdsclient/xdsresource"
echo "=========================================="
go test -cpu 1,4 -timeout 7m ./internal/xds/xdsclient/xdsresource/ -v
test3_rc=$?

# Determine overall exit code (non-zero if any test failed)
if [ $test1_rc -ne 0 ] || [ $test2_rc -ne 0 ] || [ $test3_rc -ne 0 ]; then
    rc=1
else
    rc=0
fi

echo "=========================================="
echo "Test execution summary:"
echo "  internal/xds/balancer/clusterresolver: exit code $test1_rc"
echo "  internal/xds/xdsclient/tests: exit code $test2_rc"
echo "  internal/xds/xdsclient/xdsresource: exit code $test3_rc"
echo "=========================================="

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout e78c0a5e3cd6a1a175bccc144292c7be716ca769 "internal/xds/balancer/clusterresolver/configbuilder_test.go" "internal/xds/xdsclient/tests/eds_watchers_test.go" "internal/xds/xdsclient/tests/federation_watchers_test.go" "internal/xds/xdsclient/tests/resource_update_test.go" "internal/xds/xdsclient/xdsresource/unmarshal_eds_test.go"