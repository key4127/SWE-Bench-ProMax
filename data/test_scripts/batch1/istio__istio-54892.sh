#!/bin/bash
set -uxo pipefail
cd /testbed

# Reset the target test file to the original commit state
git checkout 757281770445eae71e62413ace4e19d06941af22 "pilot/pkg/networking/core/envoyfilter/rc_patch_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pilot/pkg/networking/core/envoyfilter/rc_patch_test.go b/pilot/pkg/networking/core/envoyfilter/rc_patch_test.go
--- a/pilot/pkg/networking/core/envoyfilter/rc_patch_test.go
+++ b/pilot/pkg/networking/core/envoyfilter/rc_patch_test.go
@@ -94,6 +94,129 @@ func Test_virtualHostMatch(t *testing.T) {
 			},
 			want: false,
 		},
+		{
+			name: "domain name match",
+			args: args{
+				vh: &route.VirtualHost{
+					Domains: []string{
+						"*.scooby",
+						"*.com",
+					},
+					Name: "scoobydoo",
+				},
+				cp: &model.EnvoyFilterConfigPatchWrapper{
+					Match: &networking.EnvoyFilter_EnvoyConfigObjectMatch{
+						ObjectTypes: &networking.EnvoyFilter_EnvoyConfigObjectMatch_RouteConfiguration{
+							RouteConfiguration: &networking.EnvoyFilter_RouteConfigurationMatch{
+								Vhost: &networking.EnvoyFilter_RouteConfigurationMatch_VirtualHostMatch{
+									DomainName: "*.scooby",
+								},
+							},
+						},
+					},
+				},
+			},
+			want: true,
+		},
+		{
+			name: "vhost name match and domain name match",
+			args: args{
+				vh: &route.VirtualHost{
+					Domains: []string{
+						"*.scooby",
+						"*.com",
+					},
+					Name: "scoobydoo",
+				},
+				cp: &model.EnvoyFilterConfigPatchWrapper{
+					Match: &networking.EnvoyFilter_EnvoyConfigObjectMatch{
+						ObjectTypes: &networking.EnvoyFilter_EnvoyConfigObjectMatch_RouteConfiguration{
+							RouteConfiguration: &networking.EnvoyFilter_RouteConfigurationMatch{
+								Vhost: &networking.EnvoyFilter_RouteConfigurationMatch_VirtualHostMatch{
+									DomainName: "*.scooby",
+									Name:       "scoobydoo",
+								},
+							},
+						},
+					},
+				},
+			},
+			want: true,
+		},
+		{
+			name: "domain name mismatch",
+			args: args{
+				vh: &route.VirtualHost{
+					Domains: []string{
+						"*.scooby",
+						"*.com",
+					},
+					Name: "scoobydoo",
+				},
+				cp: &model.EnvoyFilterConfigPatchWrapper{
+					Match: &networking.EnvoyFilter_EnvoyConfigObjectMatch{
+						ObjectTypes: &networking.EnvoyFilter_EnvoyConfigObjectMatch_RouteConfiguration{
+							RouteConfiguration: &networking.EnvoyFilter_RouteConfigurationMatch{
+								Vhost: &networking.EnvoyFilter_RouteConfigurationMatch_VirtualHostMatch{
+									DomainName: "*.in",
+								},
+							},
+						},
+					},
+				},
+			},
+			want: false,
+		},
+		{
+			name: "vhost name mismatch and domain name match",
+			args: args{
+				vh: &route.VirtualHost{
+					Domains: []string{
+						"*.scooby",
+						"*.com",
+					},
+					Name: "scoobydoo",
+				},
+				cp: &model.EnvoyFilterConfigPatchWrapper{
+					Match: &networking.EnvoyFilter_EnvoyConfigObjectMatch{
+						ObjectTypes: &networking.EnvoyFilter_EnvoyConfigObjectMatch_RouteConfiguration{
+							RouteConfiguration: &networking.EnvoyFilter_RouteConfigurationMatch{
+								Vhost: &networking.EnvoyFilter_RouteConfigurationMatch_VirtualHostMatch{
+									DomainName: "*.scooby",
+									Name:       "scooby",
+								},
+							},
+						},
+					},
+				},
+			},
+			want: false,
+		},
+		{
+			name: "vhost name match but domain name mismatch",
+			args: args{
+				vh: &route.VirtualHost{
+					Domains: []string{
+						"*.scooby",
+						"*.com",
+					},
+					Name: "scoobydoo",
+				},
+				cp: &model.EnvoyFilterConfigPatchWrapper{
+					Match: &networking.EnvoyFilter_EnvoyConfigObjectMatch{
+						ObjectTypes: &networking.EnvoyFilter_EnvoyConfigObjectMatch_RouteConfiguration{
+							RouteConfiguration: &networking.EnvoyFilter_RouteConfigurationMatch{
+								Vhost: &networking.EnvoyFilter_RouteConfigurationMatch_VirtualHostMatch{
+									DomainName: "*.in",
+									Name:       "scoobydoo",
+								},
+							},
+						},
+					},
+				},
+			},
+			want: false,
+		},
 	}
 	for _, tt := range tests {
 		t.Run(tt.name, func(t *testing.T) {
EOF_114329324912

# Run all tests in the envoyfilter package with race detection
# This will execute all test functions in the rc_patch_test.go file
go test -race -v ./pilot/pkg/networking/core/envoyfilter/
rc=$?

# Output the exit code for evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 757281770445eae71e62413ace4e19d06941af22 "pilot/pkg/networking/core/envoyfilter/rc_patch_test.go"