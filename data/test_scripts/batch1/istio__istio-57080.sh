#!/bin/bash
set -uxo pipefail

# Change to the testbed directory
cd /testbed

# Reset test files to the target commit to ensure clean state
git checkout 51c5b65491a2bf693ea01bddfb09c3b5e0a0702c "pilot/pkg/networking/core/gateway_test.go" "pilot/pkg/networking/core/listener_test.go" "pilot/pkg/security/model/authentication_test.go"

# Apply the test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/pilot/pkg/networking/core/gateway_test.go b/pilot/pkg/networking/core/gateway_test.go
--- a/pilot/pkg/networking/core/gateway_test.go
+++ b/pilot/pkg/networking/core/gateway_test.go
@@ -1623,7 +1623,10 @@ func TestBuildGatewayListenerTlsContext(t *testing.T) {
 
 	for _, tc := range testCases {
 		t.Run(tc.name, func(t *testing.T) {
-			ret := buildGatewayListenerTLSContext(tc.mesh, tc.server, &pilot_model.Proxy{
+			push := &pilot_model.PushContext{
+				Mesh: tc.mesh,
+			}
+			ret := buildGatewayListenerTLSContext(push, tc.server, &pilot_model.Proxy{
 				Metadata: &pilot_model.NodeMetadata{},
 			}, tc.transportProtocol)
 			if diff := cmp.Diff(tc.result, ret, protocmp.Transform()); diff != "" {
diff --git a/pilot/pkg/networking/core/listener_test.go b/pilot/pkg/networking/core/listener_test.go
--- a/pilot/pkg/networking/core/listener_test.go
+++ b/pilot/pkg/networking/core/listener_test.go
@@ -3145,7 +3145,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 		name                    string
 		serverTLSSettings       *networking.ServerTLSSettings
 		proxy                   *model.Proxy
-		mesh                    *meshconfig.MeshConfig
+		push                    *model.PushContext
 		transportProtocol       istionetworking.TransportProtocol
 		gatewayTCPServerWithTLS bool
 		expectedCertCount       int
@@ -3160,7 +3160,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       1,
@@ -3175,7 +3175,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       2,
@@ -3191,7 +3191,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       2,
@@ -3207,7 +3207,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       1,
@@ -3231,7 +3231,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       2,
@@ -3248,7 +3248,7 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       1,
@@ -3273,17 +3273,112 @@ func TestBuildListenerTLSContext(t *testing.T) {
 			proxy: &model.Proxy{
 				Metadata: &model.NodeMetadata{},
 			},
-			mesh:                    &meshconfig.MeshConfig{},
+			push:                    &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			transportProtocol:       istionetworking.TransportProtocolTCP,
 			gatewayTCPServerWithTLS: false,
 			expectedCertCount:       2,
 			expectedValidation:      true,
 		},
+		{
+			name: "external SDS provider with credential name",
+			serverTLSSettings: &networking.ServerTLSSettings{
+				Mode:           networking.ServerTLSSettings_SIMPLE,
+				CredentialName: "sds://provider-cert",
+			},
+			proxy: &model.Proxy{
+				Metadata: &model.NodeMetadata{},
+			},
+			push: func() *model.PushContext {
+				pc := &model.PushContext{
+					Mesh: &meshconfig.MeshConfig{
+						ExtensionProviders: []*meshconfig.MeshConfig_ExtensionProvider{
+							{
+								Name: "provider-cert",
+								Provider: &meshconfig.MeshConfig_ExtensionProvider_Sds{
+									Sds: &meshconfig.MeshConfig_ExtensionProvider_SDSProvider{
+										Name:    "provider-cert",
+										Service: "sds-provider-service",
+										Port:    8080,
+									},
+								},
+							},
+						},
+					},
+				}
+				pc.ServiceIndex.HostnameAndNamespace = map[host.Name]map[string]*model.Service{
+					"sds-provider-service": {
+						"": &model.Service{
+							Hostname: "sds-provider-service",
+							Ports: []*model.Port{
+								{
+									Name:     "grpc",
+									Port:     8080,
+									Protocol: protocol.GRPC,
+								},
+							},
+						},
+					},
+				}
+				return pc
+			}(),
+			transportProtocol:       istionetworking.TransportProtocolTCP,
+			gatewayTCPServerWithTLS: false,
+			expectedCertCount:       1,
+			expectedValidation:      false,
+		},
+		{
+			name: "external SDS provider with mutual TLS",
+			serverTLSSettings: &networking.ServerTLSSettings{
+				Mode:            networking.ServerTLSSettings_MUTUAL,
+				CredentialName:  "sds://provider-cert",
+				SubjectAltNames: []string{"test.com"},
+			},
+			proxy: &model.Proxy{
+				Metadata: &model.NodeMetadata{},
+			},
+			push: func() *model.PushContext {
+				pc := &model.PushContext{
+					Mesh: &meshconfig.MeshConfig{
+						ExtensionProviders: []*meshconfig.MeshConfig_ExtensionProvider{
+							{
+								Name: "provider-cert",
+								Provider: &meshconfig.MeshConfig_ExtensionProvider_Sds{
+									Sds: &meshconfig.MeshConfig_ExtensionProvider_SDSProvider{
+										Name:    "provider-cert",
+										Service: "sds-provider-service",
+										Port:    8080,
+									},
+								},
+							},
+						},
+					},
+				}
+				pc.ServiceIndex.HostnameAndNamespace = map[host.Name]map[string]*model.Service{
+					"sds-provider-service": {
+						"": &model.Service{
+							Hostname: "sds-provider-service",
+							Ports: []*model.Port{
+								{
+									Name:     "grpc",
+									Port:     8080,
+									Protocol: protocol.GRPC,
+								},
+							},
+						},
+					},
+				}
+				return pc
+			}(),
+			transportProtocol:       istionetworking.TransportProtocolTCP,
+			gatewayTCPServerWithTLS: false,
+			expectedCertCount:       1,
+			expectedValidation:      true,
+		},
 	}
 
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
-			ctx := BuildListenerTLSContext(tt.serverTLSSettings, tt.proxy, tt.mesh, tt.transportProtocol, tt.gatewayTCPServerWithTLS)
+			ctx := BuildListenerTLSContext(tt.serverTLSSettings, tt.proxy, tt.push, tt.transportProtocol, tt.gatewayTCPServerWithTLS)
 
 			// Check certificate count
 			if len(ctx.CommonTlsContext.TlsCertificateSdsSecretConfigs) != tt.expectedCertCount {
diff --git a/pilot/pkg/security/model/authentication_test.go b/pilot/pkg/security/model/authentication_test.go
--- a/pilot/pkg/security/model/authentication_test.go
+++ b/pilot/pkg/security/model/authentication_test.go
@@ -26,9 +26,11 @@ import (
 	"google.golang.org/protobuf/testing/protocmp"
 	"google.golang.org/protobuf/types/known/durationpb"
 
+	meshconfig "istio.io/api/mesh/v1alpha1"
 	networking "istio.io/api/networking/v1alpha3"
 	"istio.io/istio/pilot/pkg/model"
-	"istio.io/istio/pilot/pkg/model/credentials"
+	"istio.io/istio/pkg/config/host"
+	"istio.io/istio/pkg/config/protocol"
 	"istio.io/istio/pkg/security"
 	"istio.io/istio/pkg/spiffe"
 )
@@ -646,16 +648,76 @@ func TestApplyToCommonTLSContext(t *testing.T) {
 }
 
 func TestConstructSdsSecretConfigForCredential(t *testing.T) {
-	testCases := []struct {
-		credentialSocketExists bool
+	cases := []struct {
 		name                   string
+		credentialSocketExists bool
+		push                   *model.PushContext
 		expected               *auth.SdsSecretConfig
 	}{
 		{
+			name:                   "",
+			credentialSocketExists: false,
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
+			expected:               nil,
+		},
+		{
+			name:                   "builtin://",
+			credentialSocketExists: false,
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
+			expected: &auth.SdsSecretConfig{
+				Name: SDSDefaultResourceName,
+				SdsConfig: &core.ConfigSource{
+					ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
+						ApiConfigSource: &core.ApiConfigSource{
+							ApiType:                   core.ApiConfigSource_GRPC,
+							SetNodeOnFirstMessageOnly: true,
+							TransportApiVersion:       core.ApiVersion_V3,
+							GrpcServices: []*core.GrpcService{
+								{
+									TargetSpecifier: &core.GrpcService_EnvoyGrpc_{
+										EnvoyGrpc: &core.GrpcService_EnvoyGrpc{ClusterName: SDSClusterName},
+									},
+								},
+							},
+						},
+					},
+					ResourceApiVersion:  core.ApiVersion_V3,
+					InitialFetchTimeout: durationpb.New(time.Second * 0),
+				},
+			},
+		},
+		{
+			name:                   "builtin://-cacert",
+			credentialSocketExists: false,
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
+			expected: &auth.SdsSecretConfig{
+				Name: SDSRootResourceName,
+				SdsConfig: &core.ConfigSource{
+					ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
+						ApiConfigSource: &core.ApiConfigSource{
+							ApiType:                   core.ApiConfigSource_GRPC,
+							SetNodeOnFirstMessageOnly: true,
+							TransportApiVersion:       core.ApiVersion_V3,
+							GrpcServices: []*core.GrpcService{
+								{
+									TargetSpecifier: &core.GrpcService_EnvoyGrpc_{
+										EnvoyGrpc: &core.GrpcService_EnvoyGrpc{ClusterName: SDSClusterName},
+									},
+								},
+							},
+						},
+					},
+					ResourceApiVersion:  core.ApiVersion_V3,
+					InitialFetchTimeout: durationpb.New(time.Second * 0),
+				},
+			},
+		},
+		{
+			name:                   "sds://external-cert",
 			credentialSocketExists: true,
-			name:                   "sds://test-credential-uds",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			expected: &auth.SdsSecretConfig{
-				Name: "sds://test-credential-uds",
+				Name: "sds://external-cert",
 				SdsConfig: &core.ConfigSource{
 					ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
 						ApiConfigSource: &core.ApiConfigSource{
@@ -676,35 +738,103 @@ func TestConstructSdsSecretConfigForCredential(t *testing.T) {
 			},
 		},
 		{
+			name:                   "test-cert",
 			credentialSocketExists: false,
-			name:                   "test-credential",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 			expected: &auth.SdsSecretConfig{
-				Name:      credentials.ToResourceName("test-credential"),
+				Name:      "kubernetes://test-cert",
 				SdsConfig: SDSAdsConfig,
 			},
 		},
 		{
+			name:                   "sds://provider-cert",
 			credentialSocketExists: false,
-			name:                   "test-credential-no-prefix-with-socket",
+			push: func() *model.PushContext {
+				pc := &model.PushContext{
+					Mesh: &meshconfig.MeshConfig{
+						ExtensionProviders: []*meshconfig.MeshConfig_ExtensionProvider{
+							{
+								Name: "provider-cert",
+								Provider: &meshconfig.MeshConfig_ExtensionProvider_Sds{
+									Sds: &meshconfig.MeshConfig_ExtensionProvider_SDSProvider{
+										Name:    "provider-cert",
+										Service: "sds-provider-service",
+										Port:    8080,
+									},
+								},
+							},
+						},
+					},
+				}
+				pc.ServiceIndex.HostnameAndNamespace = map[host.Name]map[string]*model.Service{
+					"sds-provider-service": {
+						"": &model.Service{
+							Hostname: "sds-provider-service",
+							Ports: []*model.Port{
+								{
+									Name:     "grpc",
+									Port:     8080,
+									Protocol: protocol.GRPC,
+								},
+							},
+						},
+					},
+				}
+				return pc
+			}(),
 			expected: &auth.SdsSecretConfig{
-				Name:      credentials.ToResourceName("test-credential-no-prefix-with-socket"),
-				SdsConfig: SDSAdsConfig,
+				Name: "sds://provider-cert",
+				SdsConfig: &core.ConfigSource{
+					ConfigSourceSpecifier: &core.ConfigSource_ApiConfigSource{
+						ApiConfigSource: &core.ApiConfigSource{
+							ApiType:                   core.ApiConfigSource_GRPC,
+							SetNodeOnFirstMessageOnly: true,
+							TransportApiVersion:       core.ApiVersion_V3,
+							GrpcServices: []*core.GrpcService{
+								{
+									TargetSpecifier: &core.GrpcService_EnvoyGrpc_{
+										EnvoyGrpc: &core.GrpcService_EnvoyGrpc{ClusterName: "outbound|8080||sds-provider-service"},
+									},
+								},
+							},
+						},
+					},
+					ResourceApiVersion: core.ApiVersion_V3,
+				},
 			},
 		},
 		{
-			credentialSocketExists: true,
-			name:                   "test-credential-no-prefix",
-			expected: &auth.SdsSecretConfig{
-				Name:      credentials.ToResourceName("test-credential-no-prefix"),
-				SdsConfig: SDSAdsConfig,
-			},
+			name:                   "sds://provider-cert",
+			credentialSocketExists: false,
+			push: func() *model.PushContext {
+				pc := &model.PushContext{
+					Mesh: &meshconfig.MeshConfig{
+						ExtensionProviders: []*meshconfig.MeshConfig_ExtensionProvider{
+							{
+								Name: "provider-cert",
+								Provider: &meshconfig.MeshConfig_ExtensionProvider_Sds{
+									Sds: &meshconfig.MeshConfig_ExtensionProvider_SDSProvider{
+										Name:    "provider-cert",
+										Service: "missing-service",
+										Port:    8080,
+									},
+								},
+							},
+						},
+					},
+				}
+				// ServiceIndex is empty, so LookupCluster will fail
+				pc.ServiceIndex.HostnameAndNamespace = map[host.Name]map[string]*model.Service{}
+				return pc
+			}(),
+			expected: nil,
 		},
 	}
 
-	for _, c := range testCases {
+	for _, c := range cases {
 		t.Run(c.name, func(t *testing.T) {
-			if got := ConstructSdsSecretConfigForCredential(c.name, c.credentialSocketExists); !cmp.Equal(got, c.expected, protocmp.Transform()) {
-				t.Errorf("ConstructSdsSecretConfigForSDSEndpoint: got(%#v), want(%#v)\n", got, c.expected)
+			if got := ConstructSdsSecretConfigForCredential(c.name, c.credentialSocketExists, c.push); !cmp.Equal(got, c.expected, protocmp.Transform()) {
+				t.Errorf("ConstructSdsSecretConfigForCredential() = %v, want %v", got, c.expected)
 			}
 		})
 	}
@@ -718,6 +848,7 @@ func TestApplyCredentialSDSToServerCommonTLSContext(t *testing.T) {
 		expectedCertCount      int
 		expectedValidation     bool
 		expectedValidationType string
+		push                   *model.PushContext
 	}{
 		{
 			name: "single certificate with credential name",
@@ -729,6 +860,7 @@ func TestApplyCredentialSDSToServerCommonTLSContext(t *testing.T) {
 			expectedCertCount:      1,
 			expectedValidation:     false,
 			expectedValidationType: "",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 		},
 		{
 			name: "multiple certificates with credential names",
@@ -740,60 +872,39 @@ func TestApplyCredentialSDSToServerCommonTLSContext(t *testing.T) {
 			expectedCertCount:      2,
 			expectedValidation:     false,
 			expectedValidationType: "",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 		},
 		{
-			name: "multiple certificates with mutual TLS",
-			tlsOpts: &networking.ServerTLSSettings{
-				Mode:            networking.ServerTLSSettings_MUTUAL,
-				CredentialNames: []string{"rsa-cert", "ecdsa-cert"},
-				SubjectAltNames: []string{"test.com"},
-			},
-			credentialSocketExist:  false,
-			expectedCertCount:      2,
-			expectedValidation:     true,
-			expectedValidationType: "CombinedValidationContext",
-		},
-		{
-			name: "multiple certificates with subject alt names only",
+			name: "credential name with validation context",
 			tlsOpts: &networking.ServerTLSSettings{
 				Mode:            networking.ServerTLSSettings_SIMPLE,
-				CredentialNames: []string{"rsa-cert", "ecdsa-cert"},
+				CredentialName:  "test-cert",
 				SubjectAltNames: []string{"test.com"},
 			},
 			credentialSocketExist:  false,
-			expectedCertCount:      2,
+			expectedCertCount:      1,
 			expectedValidation:     true,
 			expectedValidationType: "ValidationContext",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 		},
 		{
-			name: "prefer credential names over credential name",
+			name: "credential name with socket",
 			tlsOpts: &networking.ServerTLSSettings{
-				Mode:            networking.ServerTLSSettings_SIMPLE,
-				CredentialName:  "old-cert",
-				CredentialNames: []string{"rsa-cert", "ecdsa-cert"},
-			},
-			credentialSocketExist:  false,
-			expectedCertCount:      2,
-			expectedValidation:     false,
-			expectedValidationType: "",
-		},
-		{
-			name: "external credential socket",
-			tlsOpts: &networking.ServerTLSSettings{
-				Mode:            networking.ServerTLSSettings_SIMPLE,
-				CredentialNames: []string{"external-cert"},
+				Mode:           networking.ServerTLSSettings_SIMPLE,
+				CredentialName: "sds://external-cert",
 			},
 			credentialSocketExist:  true,
 			expectedCertCount:      1,
 			expectedValidation:     false,
 			expectedValidationType: "",
+			push:                   &model.PushContext{Mesh: &meshconfig.MeshConfig{}},
 		},
 	}
 
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
 			tlsContext := &auth.CommonTlsContext{}
-			ApplyCredentialSDSToServerCommonTLSContext(tlsContext, tt.tlsOpts, tt.credentialSocketExist)
+			ApplyCredentialSDSToServerCommonTLSContext(tlsContext, tt.tlsOpts, tt.credentialSocketExist, tt.push)
 
 			// Check certificate count
 			if len(tlsContext.TlsCertificateSdsSecretConfigs) != tt.expectedCertCount {
@@ -822,19 +933,12 @@ func TestApplyCredentialSDSToServerCommonTLSContext(t *testing.T) {
 					if validationCtx.ValidationContext == nil {
 						t.Error("expected ValidationContext to be set")
 					}
+				default:
+					t.Errorf("unexpected validation type: %s", tt.expectedValidationType)
 				}
 			} else if tlsContext.ValidationContextType != nil {
 				t.Error("unexpected validation context")
 			}
-
-			// Check certificate names
-			if tt.expectedCertCount > 0 {
-				for i, cert := range tlsContext.TlsCertificateSdsSecretConfigs {
-					if cert.Name == "" {
-						t.Errorf("certificate %d has empty name", i)
-					}
-				}
-			}
 		})
 	}
 }
EOF_114329324912

# Execute tests at the package level to ensure proper dependencies
# Run networking core package tests (includes gateway_test.go and listener_test.go)
go test -p 1 -v ./pilot/pkg/networking/core/
rc1=$?

# Run security model package tests (includes authentication_test.go)
go test -p 1 -v ./pilot/pkg/security/model/
rc2=$?

# Determine overall exit code (fail if any test failed)
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Echo the exit code for the judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Reset test files back to the target commit to clean up
git checkout 51c5b65491a2bf693ea01bddfb09c3b5e0a0702c "pilot/pkg/networking/core/gateway_test.go" "pilot/pkg/networking/core/listener_test.go" "pilot/pkg/security/model/authentication_test.go"