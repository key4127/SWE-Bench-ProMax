#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout e7970c25175ceef480b02bb692c7a9e210290f9e \
    "internal/client/config_test.go" \
    "internal/client/testdata/config.1" \
    "internal/config/alias_test.go" \
    "internal/config/testdata/configs/default.yaml" \
    "internal/dao/alias_test.go" \
    "internal/dao/rbac_policy_test.go" \
    "internal/model/stack_test.go" \
    "internal/port/pfs_test.go" \
    "internal/render/cronjob_test.go" \
    "internal/render/dp_test.go" \
    "internal/render/ds_test.go" \
    "internal/render/job_test.go" \
    "internal/render/node_int_test.go" \
    "internal/render/pod_test.go" \
    "internal/render/rs_test.go" \
    "internal/render/sts_test.go" \
    "internal/ui/app_test.go" \
    "internal/ui/crumbs_test.go" \
    "internal/ui/prompt_test.go" \
    "internal/ui/table_helper_test.go" \
    "internal/view/app_test.go" \
    "internal/view/cmd/args_test.go" \
    "internal/view/cmd/interpreter_test.go" \
    "internal/view/command_test.go" \
    "internal/view/table_int_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/internal/client/config_test.go b/internal/client/config_test.go
--- a/internal/client/config_test.go
+++ b/internal/client/config_test.go
@@ -32,7 +32,7 @@ func TestCallTimeout(t *testing.T) {
 			e: 1 * time.Minute,
 		},
 		"default": {
-			e: 15 * time.Second,
+			e: client.DefaultCallTimeoutDuration,
 		},
 	}
 
diff --git a/internal/client/testdata/config.1 b/internal/client/testdata/config.1
--- a/internal/client/testdata/config.1
+++ b/internal/client/testdata/config.1
@@ -15,5 +15,4 @@ contexts:
   name: blee
 current-context: blee
 kind: Config
-preferences: {}
 users: null
diff --git a/internal/config/alias_test.go b/internal/config/alias_test.go
--- a/internal/config/alias_test.go
+++ b/internal/config/alias_test.go
@@ -13,6 +13,7 @@ import (
 	"github.com/derailed/k9s/internal/client"
 	"github.com/derailed/k9s/internal/config"
 	"github.com/derailed/k9s/internal/config/data"
+	"github.com/derailed/k9s/internal/view/cmd"
 	"github.com/stretchr/testify/assert"
 	"github.com/stretchr/testify/require"
 )
@@ -129,6 +130,131 @@ func TestAliasesSave(t *testing.T) {
 	assert.Len(t, a.Alias, c)
 }
 
+func TestAliasResolve(t *testing.T) {
+	uu := map[string]struct {
+		exp string
+		ok  bool
+		gvr *client.GVR
+		cmd *cmd.Interpreter
+	}{
+		"gvr": {
+			exp: "v1/pods",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods"),
+		},
+
+		"kind": {
+			exp: "pod",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods"),
+		},
+
+		"plural": {
+			exp: "pods",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods"),
+		},
+
+		"short-name": {
+			exp: "po",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods"),
+		},
+
+		"short-name-with-args": {
+			exp: "po 'a in (b,c)' @zorb bozo",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods 'a in (b,c)' @zorb bozo"),
+		},
+
+		"alias": {
+			exp: "pipo",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods"),
+		},
+
+		"toast-command": {
+			exp: "zorg",
+		},
+
+		"alias-no-args": {
+			exp: "wkl",
+			ok:  true,
+			gvr: client.WkGVR,
+			cmd: cmd.NewInterpreter("workloads"),
+		},
+
+		"alias-ns-arg": {
+			exp: "pp",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods default"),
+		},
+
+		"multi-alias-ns-inception": {
+			exp: "ppo",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods a=b,b=c default"),
+		},
+
+		"full-alias": {
+			exp: "ppc",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods @fred app=fred default"),
+		},
+
+		"plain-filter": {
+			exp: "po /fred @bozo ns-1",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods /fred @bozo ns-1"),
+		},
+
+		"alias-filter": {
+			exp: "pipo /fred @bozo ns-1",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods /fred @bozo ns-1"),
+		},
+
+		"complex-filter": {
+			exp: "ppc /fred @bozo ns-1",
+			ok:  true,
+			gvr: client.PodGVR,
+			cmd: cmd.NewInterpreter("v1/pods @bozo /fred app=fred ns-1"),
+		},
+	}
+
+	a := config.NewAliases()
+	a.Define(client.PodGVR, "po", "pipo", "pod")
+	a.Define(client.PodGVR, client.PodGVR.String())
+	a.Define(client.PodGVR, client.PodGVR.AsResourceName())
+	a.Define(client.WkGVR, client.WkGVR.String(), "workload", "wkl")
+	a.Define(client.NewGVR("pod default"), "pp")
+	a.Define(client.NewGVR("pipo a=b,b=c default"), "ppo")
+	a.Define(client.NewGVR("pod default app=fred @fred"), "ppc")
+	for k := range uu {
+		u := uu[k]
+		t.Run(k, func(t *testing.T) {
+			p := cmd.NewInterpreter(u.exp)
+			gvr, ok := a.Resolve(p)
+			assert.Equal(t, u.ok, ok)
+			if ok {
+				assert.Equal(t, u.gvr, gvr)
+				assert.Equal(t, u.cmd.GetLine(), p.GetLine())
+			}
+		})
+	}
+}
+
 // Helpers...
 
 var (
diff --git a/internal/config/testdata/configs/default.yaml b/internal/config/testdata/configs/default.yaml
--- a/internal/config/testdata/configs/default.yaml
+++ b/internal/config/testdata/configs/default.yaml
@@ -3,7 +3,7 @@ k9s:
   gpuVendors: {}
   screenDumpDir: /tmp/k9s-test/screen-dumps
   refreshRate: 2
-  apiServerTimeout: 15s
+  apiServerTimeout: 2m0s
   maxConnRetry: 5
   readOnly: false
   noExitOnCtrlC: false
diff --git a/internal/dao/alias_test.go b/internal/dao/alias_test.go
--- a/internal/dao/alias_test.go
+++ b/internal/dao/alias_test.go
@@ -16,91 +16,6 @@ import (
 	"github.com/stretchr/testify/require"
 )
 
-func TestAsGVR(t *testing.T) {
-	a := dao.NewAlias(makeFactory())
-	a.Define(client.PodGVR, "po", "pipo", "pod")
-	a.Define(client.PodGVR, client.PodGVR.String())
-	a.Define(client.PodGVR, client.PodGVR.AsResourceName())
-	a.Define(client.WkGVR, client.WkGVR.String(), "workload", "wkl")
-	a.Define(client.NewGVR("pod default"), "pp")
-	a.Define(client.NewGVR("pipo default"), "ppo")
-	a.Define(client.NewGVR("pod default app=fred @fred"), "ppc")
-
-	uu := map[string]struct {
-		cmd string
-		ok  bool
-		gvr *client.GVR
-		exp string
-	}{
-		"gvr": {
-			cmd: "v1/pods",
-			ok:  true,
-			gvr: client.PodGVR,
-		},
-
-		"r": {
-			cmd: "pods",
-			ok:  true,
-			gvr: client.PodGVR,
-		},
-
-		"alias1": {
-			cmd: "po",
-			ok:  true,
-			gvr: client.PodGVR,
-		},
-
-		"alias-2": {
-			cmd: "pipo",
-			ok:  true,
-			gvr: client.PodGVR,
-		},
-
-		"missing": {
-			cmd: "zorg",
-		},
-
-		"no-args": {
-			cmd: "wkl",
-			ok:  true,
-			gvr: client.WkGVR,
-		},
-
-		"ns-arg": {
-			cmd: "pp",
-			ok:  true,
-			gvr: client.PodGVR,
-			exp: "default",
-		},
-
-		"ns-inception": {
-			cmd: "ppo",
-			ok:  true,
-			gvr: client.PodGVR,
-			exp: "default",
-		},
-
-		"full-alias": {
-			cmd: "ppc",
-			ok:  true,
-			gvr: client.PodGVR,
-			exp: "default app=fred @fred",
-		},
-	}
-
-	for k := range uu {
-		u := uu[k]
-		t.Run(k, func(t *testing.T) {
-			gvr, exp, ok := a.AsGVR(u.cmd)
-			assert.Equal(t, u.ok, ok)
-			if u.ok {
-				assert.Equal(t, u.gvr, gvr)
-				assert.Equal(t, u.exp, exp)
-			}
-		})
-	}
-}
-
 func TestAliasList(t *testing.T) {
 	a := dao.Alias{}
 	a.Init(makeFactory(), client.AliGVR)
diff --git a/internal/dao/rbac_policy_test.go b/internal/dao/rbac_policy_test.go
--- a/internal/dao/rbac_policy_test.go
+++ b/internal/dao/rbac_policy_test.go
@@ -27,6 +27,7 @@ func TestIsSameSubject(t *testing.T) {
 			},
 			want: true,
 		},
+
 		"name-does-not-match": {
 			kind: rbacv1.UserKind,
 			name: "foo",
@@ -36,6 +37,7 @@ func TestIsSameSubject(t *testing.T) {
 			},
 			want: false,
 		},
+
 		"kind-does-not-match": {
 			kind: rbacv1.GroupKind,
 			name: "foo",
@@ -45,6 +47,7 @@ func TestIsSameSubject(t *testing.T) {
 			},
 			want: false,
 		},
+
 		"serviceAccount-all-match": {
 			kind:      rbacv1.ServiceAccountKind,
 			name:      "foo",
@@ -56,6 +59,7 @@ func TestIsSameSubject(t *testing.T) {
 			},
 			want: true,
 		},
+
 		"serviceAccount-namespace-no-match": {
 			kind:      rbacv1.ServiceAccountKind,
 			name:      "foo",
@@ -72,7 +76,7 @@ func TestIsSameSubject(t *testing.T) {
 	for k := range uu {
 		u := uu[k]
 		t.Run(k, func(t *testing.T) {
-			same := isSameSubject(u.kind, u.namespace, u.name, &u.subject)
+			same := isSameSubject(u.kind, u.namespace, u.namespace, u.name, &u.subject)
 			assert.Equal(t, u.want, same)
 		})
 	}
diff --git a/internal/model/stack_test.go b/internal/model/stack_test.go
--- a/internal/model/stack_test.go
+++ b/internal/model/stack_test.go
@@ -305,13 +305,13 @@ func (c) InputHandler() func(*tcell.EventKey, func(tview.Primitive)) { return ni
 func (c) MouseHandler() func(action tview.MouseAction, event *tcell.EventMouse, setFocus func(p tview.Primitive)) (consumed bool, capture tview.Primitive) {
 	return nil
 }
-func (c) SetRect(int, int, int, int)       {}
-func (c) GetRect() (a, b, c, d int)        { return 0, 0, 0, 0 }
-func (c) GetFocusable() tview.Focusable    { return nil }
-func (c) Focus(func(tview.Primitive))      {}
-func (c) Blur()                            {}
-func (c) Start()                           {}
-func (c) Stop()                            {}
-func (c) Init(context.Context) error       { return nil }
-func (c) SetFilter(string)                 {}
-func (c) SetLabelSelector(labels.Selector) {}
+func (c) SetRect(int, int, int, int)             {}
+func (c) GetRect() (a, b, c, d int)              { return 0, 0, 0, 0 }
+func (c) GetFocusable() tview.Focusable          { return nil }
+func (c) Focus(func(tview.Primitive))            {}
+func (c) Blur()                                  {}
+func (c) Start()                                 {}
+func (c) Stop()                                  {}
+func (c) Init(context.Context) error             { return nil }
+func (c) SetFilter(string, bool)                 {}
+func (c) SetLabelSelector(labels.Selector, bool) {}
diff --git a/internal/port/pfs_test.go b/internal/port/pfs_test.go
--- a/internal/port/pfs_test.go
+++ b/internal/port/pfs_test.go
@@ -4,6 +4,7 @@
 package port_test
 
 import (
+	"context"
 	"errors"
 	"testing"
 
@@ -93,7 +94,7 @@ func TestPFsToTunnel(t *testing.T) {
 		},
 	}
 
-	f := func(port.PortTunnel) bool {
+	f := func(context.Context, port.PortTunnel) bool {
 		return true
 	}
 
diff --git a/internal/render/cronjob_test.go b/internal/render/cronjob_test.go
--- a/internal/render/cronjob_test.go
+++ b/internal/render/cronjob_test.go
@@ -18,5 +18,5 @@ func TestCronJobRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "cj"), "", &r))
 	assert.Equal(t, "default/hello", r.ID)
-	assert.Equal(t, model1.Fields{"default", "hello", "0", "*/1 * * * *", "false", "0"}, r.Fields[:6])
+	assert.Equal(t, model1.Fields{"default", "hello", "n/a", "*/1 * * * *", "false", "0"}, r.Fields[:6])
 }
diff --git a/internal/render/dp_test.go b/internal/render/dp_test.go
--- a/internal/render/dp_test.go
+++ b/internal/render/dp_test.go
@@ -18,7 +18,7 @@ func TestDpRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "dp"), "", &r))
 	assert.Equal(t, "icx/icx-db", r.ID)
-	assert.Equal(t, model1.Fields{"icx", "icx-db", "0", "1/1", "1", "1"}, r.Fields[:6])
+	assert.Equal(t, model1.Fields{"icx", "icx-db", "n/a", "1/1", "1", "1"}, r.Fields[:6])
 }
 
 func BenchmarkDpRender(b *testing.B) {
diff --git a/internal/render/ds_test.go b/internal/render/ds_test.go
--- a/internal/render/ds_test.go
+++ b/internal/render/ds_test.go
@@ -18,5 +18,5 @@ func TestDaemonSetRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "ds"), "", &r))
 	assert.Equal(t, "kube-system/fluentd-gcp-v3.2.0", r.ID)
-	assert.Equal(t, model1.Fields{"kube-system", "fluentd-gcp-v3.2.0", "0", "2", "2", "2", "2", "2"}, r.Fields[:8])
+	assert.Equal(t, model1.Fields{"kube-system", "fluentd-gcp-v3.2.0", "n/a", "2", "2", "2", "2", "2"}, r.Fields[:8])
 }
diff --git a/internal/render/job_test.go b/internal/render/job_test.go
--- a/internal/render/job_test.go
+++ b/internal/render/job_test.go
@@ -18,5 +18,5 @@ func TestJobRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "job"), "", &r))
 	assert.Equal(t, "default/hello-1567179180", r.ID)
-	assert.Equal(t, model1.Fields{"default", "hello-1567179180", "0", "1/1", "8s", "controller-uid=7473e6d0-cb3b-11e9-990f-42010a800218", "c1", "blang/busybox-bash"}, r.Fields[:8])
+	assert.Equal(t, model1.Fields{"default", "hello-1567179180", "n/a", "1/1", "8s", "controller-uid=7473e6d0-cb3b-11e9-990f-42010a800218", "c1", "blang/busybox-bash"}, r.Fields[:8])
 }
diff --git a/internal/render/node_int_test.go b/internal/render/node_int_test.go
--- a/internal/render/node_int_test.go
+++ b/internal/render/node_int_test.go
@@ -10,6 +10,70 @@ import (
 	mv1beta1 "k8s.io/metrics/pkg/apis/metrics/v1beta1"
 )
 
+func Test_extractNodeGPU(t *testing.T) {
+	uu := map[string]struct {
+		rl     v1.ResourceList
+		main   *resource.Quantity
+		shared *resource.Quantity
+	}{
+		"empty": {},
+
+		"nvidia": {
+			rl: v1.ResourceList{
+				v1.ResourceCPU:                    resource.MustParse("3"),
+				v1.ResourceMemory:                 resource.MustParse("4Gi"),
+				v1.ResourceName("nvidia.com/gpu"): resource.MustParse("2"),
+			},
+			main: makeQ(t, "2"),
+		},
+
+		"nvidia-shared": {
+			rl: v1.ResourceList{
+				v1.ResourceCPU:                           resource.MustParse("3"),
+				v1.ResourceMemory:                        resource.MustParse("4Gi"),
+				v1.ResourceName("nvidia.com/gpu.shared"): resource.MustParse("2"),
+			},
+			shared: makeQ(t, "2"),
+		},
+
+		"nvidia-both": {
+			rl: v1.ResourceList{
+				v1.ResourceCPU:                           resource.MustParse("3"),
+				v1.ResourceMemory:                        resource.MustParse("4Gi"),
+				v1.ResourceName("nvidia.com/gpu.shared"): resource.MustParse("2"),
+				v1.ResourceName("nvidia.com/gpu"):        resource.MustParse("5"),
+			},
+			main:   makeQ(t, "5"),
+			shared: makeQ(t, "2"),
+		},
+
+		"intel": {
+			rl: v1.ResourceList{
+				v1.ResourceCPU:                        resource.MustParse("3"),
+				v1.ResourceMemory:                     resource.MustParse("4Gi"),
+				v1.ResourceName("gpu.intel.com/i915"): resource.MustParse("5"),
+			},
+			main: makeQ(t, "5"),
+		},
+
+		"unknown-vendor": {
+			rl: v1.ResourceList{
+				v1.ResourceCPU:              resource.MustParse("3"),
+				v1.ResourceMemory:           resource.MustParse("4Gi"),
+				v1.ResourceName("bozo/gpu"): resource.MustParse("2"),
+			},
+		},
+	}
+
+	for k, u := range uu {
+		t.Run(k, func(t *testing.T) {
+			m, s := extractNodeGPU(u.rl)
+			assert.Equal(t, u.main, m)
+			assert.Equal(t, u.shared, s)
+		})
+	}
+}
+
 func Test_gatherNodeMX(t *testing.T) {
 	uu := map[string]struct {
 		node   v1.Node
@@ -125,3 +189,12 @@ func Test_gatherNodeMX(t *testing.T) {
 		})
 	}
 }
+
+func makeQ(t *testing.T, v string) *resource.Quantity {
+	q, err := resource.ParseQuantity(v)
+	if err != nil {
+		t.Fatal(err)
+	}
+
+	return &q
+}
diff --git a/internal/render/pod_test.go b/internal/render/pod_test.go
--- a/internal/render/pod_test.go
+++ b/internal/render/pod_test.go
@@ -164,7 +164,7 @@ func TestPodRender(t *testing.T) {
 	require.NoError(t, err)
 
 	assert.Equal(t, "default/nginx", r.ID)
-	e := model1.Fields{"default", "nginx", "0", "●", "1/1", "Running", "0", "<unknown>", "100", "100:0", "100", "n/a", "50", "70:170", "71", "29", "0:0", "172.17.0.6", "minikube", "default", "<none>"}
+	e := model1.Fields{"default", "nginx", "n/a", "●", "1/1", "Running", "0", "<unknown>", "100", "100:0", "100", "n/a", "50", "70:170", "71", "29", "0:0", "172.17.0.6", "minikube", "default", "<none>"}
 	assert.Equal(t, e, r.Fields[:21])
 }
 
@@ -195,7 +195,7 @@ func TestPodInitRender(t *testing.T) {
 	require.NoError(t, err)
 
 	assert.Equal(t, "default/nginx", r.ID)
-	e := model1.Fields{"default", "nginx", "0", "●", "1/1", "Init:0/1", "0", "<unknown>", "10", "100:0", "10", "n/a", "10", "70:170", "14", "5", "0:0", "172.17.0.6", "minikube", "default", "<none>"}
+	e := model1.Fields{"default", "nginx", "n/a", "●", "1/1", "Init:0/1", "0", "<unknown>", "10", "100:0", "10", "n/a", "10", "70:170", "14", "5", "0:0", "172.17.0.6", "minikube", "default", "<none>"}
 	assert.Equal(t, e, r.Fields[:21])
 }
 
@@ -211,7 +211,7 @@ func TestPodSidecarRender(t *testing.T) {
 	require.NoError(t, err)
 
 	assert.Equal(t, "default/sleep", r.ID)
-	e := model1.Fields{"default", "sleep", "0", "●", "2/2", "Running", "0", "<unknown>", "100", "50:250", "200", "40", "40", "50:80", "80", "50", "0:0", "10.244.0.8", "kind-control-plane", "default", "<none>"}
+	e := model1.Fields{"default", "sleep", "n/a", "●", "2/2", "Running", "0", "<unknown>", "100", "50:250", "200", "40", "40", "50:80", "80", "50", "0:0", "10.244.0.8", "kind-control-plane", "default", "<none>"}
 	assert.Equal(t, e, r.Fields[:21])
 }
 
diff --git a/internal/render/rs_test.go b/internal/render/rs_test.go
--- a/internal/render/rs_test.go
+++ b/internal/render/rs_test.go
@@ -18,5 +18,5 @@ func TestReplicaSetRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "rs"), "", &r))
 	assert.Equal(t, "icx/icx-db-7d4b578979", r.ID)
-	assert.Equal(t, model1.Fields{"icx", "icx-db-7d4b578979", "0", "1", "1", "1"}, r.Fields[:6])
+	assert.Equal(t, model1.Fields{"icx", "icx-db-7d4b578979", "n/a", "1", "1", "1"}, r.Fields[:6])
 }
diff --git a/internal/render/sts_test.go b/internal/render/sts_test.go
--- a/internal/render/sts_test.go
+++ b/internal/render/sts_test.go
@@ -18,5 +18,5 @@ func TestStatefulSetRender(t *testing.T) {
 
 	require.NoError(t, c.Render(load(t, "sts"), "", &r))
 	assert.Equal(t, "default/nginx-sts", r.ID)
-	assert.Equal(t, model1.Fields{"default", "nginx-sts", "0", "4/4", "app=nginx-sts", "nginx-sts", "nginx", "k8s.gcr.io/nginx-slim:0.8", "app=nginx-sts", ""}, r.Fields[:len(r.Fields)-1])
+	assert.Equal(t, model1.Fields{"default", "nginx-sts", "n/a", "4/4", "app=nginx-sts", "nginx-sts", "nginx", "k8s.gcr.io/nginx-slim:0.8", "app=nginx-sts", ""}, r.Fields[:len(r.Fields)-1])
 }
diff --git a/internal/ui/app_test.go b/internal/ui/app_test.go
--- a/internal/ui/app_test.go
+++ b/internal/ui/app_test.go
@@ -14,15 +14,15 @@ import (
 func TestAppGetCmd(t *testing.T) {
 	a := ui.NewApp(mock.NewMockConfig(t), "")
 	a.Init()
-	a.CmdBuff().SetText("blee", "")
+	a.CmdBuff().SetText("blee", "", true)
 
 	assert.Equal(t, "blee", a.GetCmd())
 }
 
 func TestAppInCmdMode(t *testing.T) {
 	a := ui.NewApp(mock.NewMockConfig(t), "")
 	a.Init()
-	a.CmdBuff().SetText("blee", "")
+	a.CmdBuff().SetText("blee", "", true)
 	assert.False(t, a.InCmdMode())
 
 	a.CmdBuff().SetActive(false)
@@ -32,7 +32,7 @@ func TestAppInCmdMode(t *testing.T) {
 func TestAppResetCmd(t *testing.T) {
 	a := ui.NewApp(mock.NewMockConfig(t), "")
 	a.Init()
-	a.CmdBuff().SetText("blee", "")
+	a.CmdBuff().SetText("blee", "", true)
 
 	a.ResetCmd()
 
@@ -46,7 +46,7 @@ func TestAppHasCmd(t *testing.T) {
 	a.ActivateCmd(true)
 	assert.False(t, a.HasCmd())
 
-	a.CmdBuff().SetText("blee", "")
+	a.CmdBuff().SetText("blee", "", true)
 	assert.True(t, a.InCmdMode())
 }
 
diff --git a/internal/ui/crumbs_test.go b/internal/ui/crumbs_test.go
--- a/internal/ui/crumbs_test.go
+++ b/internal/ui/crumbs_test.go
@@ -52,13 +52,13 @@ func (c) InputHandler() func(*tcell.EventKey, func(tview.Primitive)) { return ni
 func (c) MouseHandler() func(action tview.MouseAction, event *tcell.EventMouse, setFocus func(p tview.Primitive)) (consumed bool, capture tview.Primitive) {
 	return nil
 }
-func (c) SetRect(int, int, int, int)       {}
-func (c) GetRect() (a, b, c, d int)        { return 0, 0, 0, 0 }
-func (c c) GetFocusable() tview.Focusable  { return c }
-func (c) Focus(func(tview.Primitive))      {}
-func (c) Blur()                            {}
-func (c) Start()                           {}
-func (c) Stop()                            {}
-func (c) Init(context.Context) error       { return nil }
-func (c) SetFilter(string)                 {}
-func (c) SetLabelSelector(labels.Selector) {}
+func (c) SetRect(int, int, int, int)             {}
+func (c) GetRect() (a, b, c, d int)              { return 0, 0, 0, 0 }
+func (c c) GetFocusable() tview.Focusable        { return c }
+func (c) Focus(func(tview.Primitive))            {}
+func (c) Blur()                                  {}
+func (c) Start()                                 {}
+func (c) Stop()                                  {}
+func (c) Init(context.Context) error             { return nil }
+func (c) SetFilter(string, bool)                 {}
+func (c) SetLabelSelector(labels.Selector, bool) {}
diff --git a/internal/ui/prompt_test.go b/internal/ui/prompt_test.go
--- a/internal/ui/prompt_test.go
+++ b/internal/ui/prompt_test.go
@@ -68,7 +68,7 @@ func TestCmdUpdate(t *testing.T) {
 	v.SetModel(m)
 
 	m.AddListener(v)
-	m.SetText("blee", "")
+	m.SetText("blee", "", true)
 	m.Add('!')
 
 	assert.Equal(t, "\x00\x00 [::b]blee!\n", v.GetText(false))
diff --git a/internal/ui/table_helper_test.go b/internal/ui/table_helper_test.go
--- a/internal/ui/table_helper_test.go
+++ b/internal/ui/table_helper_test.go
@@ -34,7 +34,7 @@ func TestTruncate(t *testing.T) {
 	}
 }
 
-func TestTrimLabelSelector(t *testing.T) {
+func TestExtractLabelSelector(t *testing.T) {
 	sel, _ := labels.Parse("app=fred,env=blee")
 	uu := map[string]struct {
 		sel string
@@ -55,7 +55,7 @@ func TestTrimLabelSelector(t *testing.T) {
 	for k := range uu {
 		u := uu[k]
 		t.Run(k, func(t *testing.T) {
-			sel, err := TrimLabelSelector(u.sel)
+			sel, err := ExtractLabelSelector(u.sel)
 			assert.Equal(t, u.err, err)
 			assert.Equal(t, u.e, sel)
 		})
diff --git a/internal/view/app_test.go b/internal/view/app_test.go
--- a/internal/view/app_test.go
+++ b/internal/view/app_test.go
@@ -15,5 +15,5 @@ func TestAppNew(t *testing.T) {
 	a := view.NewApp(mock.NewMockConfig(t))
 	_ = a.Init("blee", 10)
 
-	assert.Equal(t, 15, a.GetActions().Len())
+	assert.Equal(t, 14, a.GetActions().Len())
 }
diff --git a/internal/view/cmd/args_test.go b/internal/view/cmd/args_test.go
--- a/internal/view/cmd/args_test.go
+++ b/internal/view/cmd/args_test.go
@@ -71,7 +71,7 @@ func TestFlagsNew(t *testing.T) {
 		"label-toast": {
 			i:  NewInterpreter("po"),
 			aa: []string{"="},
-			ll: make(args),
+			ll: args{labelKey: "="},
 		},
 
 		"multi-labels": {
diff --git a/internal/view/cmd/interpreter_test.go b/internal/view/cmd/interpreter_test.go
--- a/internal/view/cmd/interpreter_test.go
+++ b/internal/view/cmd/interpreter_test.go
@@ -4,6 +4,7 @@
 package cmd_test
 
 import (
+	"errors"
 	"testing"
 
 	"github.com/derailed/k9s/internal/view/cmd"
@@ -219,45 +220,59 @@ func TestFilterCmd(t *testing.T) {
 func TestLabelCmd(t *testing.T) {
 	uu := map[string]struct {
 		cmd    string
-		ok     bool
-		labels map[string]string
+		err    error
+		labels string
 	}{
 		"empty": {},
+
 		"plain": {
 			cmd:    "pod fred=blee",
-			ok:     true,
-			labels: map[string]string{"fred": "blee"},
+			labels: "fred=blee",
 		},
+
 		"multi": {
 			cmd:    "pod fred=blee,zorg=duh",
-			ok:     true,
-			labels: map[string]string{"fred": "blee", "zorg": "duh"},
+			labels: "fred=blee,zorg=duh",
+		},
+
+		"complex-lbls": {
+			cmd:    "pod 'fred in (blee,zorg),blee notin (zorg)'",
+			labels: "blee notin (zorg),fred in (blee,zorg)",
+		},
+
+		"no-lbls": {
+			cmd: "pod ns-1",
 		},
+
 		"multi-ns": {
 			cmd:    "pod fred=blee,zorg=duh ns1",
-			ok:     true,
-			labels: map[string]string{"fred": "blee", "zorg": "duh"},
+			labels: "fred=blee,zorg=duh",
 		},
+
 		"l-arg-spaced": {
 			cmd:    "pod   fred=blee   ",
-			ok:     true,
-			labels: map[string]string{"fred": "blee"},
+			labels: "fred=blee",
 		},
+
 		"l-arg-caps": {
 			cmd:    "POD  FRED=BLEE   ",
-			ok:     true,
-			labels: map[string]string{"fred": "blee"},
+			labels: "fred=blee",
+		},
+
+		"toast-labels": {
+			cmd: "pod =blee",
+			err: errors.New("found '=', expected: !, identifier, or 'end of string'"),
 		},
 	}
 
 	for k := range uu {
 		u := uu[k]
 		t.Run(k, func(t *testing.T) {
 			p := cmd.NewInterpreter(u.cmd)
-			ll, ok := p.LabelsArg()
-			assert.Equal(t, u.ok, ok)
-			if u.ok {
-				assert.Equal(t, u.labels, ll)
+			ll, err := p.LabelsSelector()
+			assert.Equal(t, u.err, err)
+			if err == nil {
+				assert.Equal(t, u.labels, ll.String())
 			}
 		})
 	}
@@ -595,3 +610,49 @@ func TestArgs(t *testing.T) {
 		})
 	}
 }
+
+func Test_grokLabels(t *testing.T) {
+	uu := map[string]struct {
+		cmd  string
+		err  error
+		lbls string
+	}{
+		"empty": {},
+
+		"no-labels": {
+			cmd: "po @fred",
+		},
+
+		"plain-label": {
+			cmd:  "po a=b,b=c @fred",
+			lbls: "a=b,b=c",
+		},
+
+		"label-quotes": {
+			cmd:  "po 'a=b,b=c' @fred",
+			lbls: "a=b,b=c",
+		},
+
+		"partial-quotes-label": {
+			cmd:  "po 'a=b @fred",
+			lbls: "",
+		},
+
+		"complex": {
+			cmd:  "po 'a in (b,c),b notin (c,z)' fred'",
+			lbls: "a in (b,c),b notin (c,z)",
+		},
+	}
+
+	for k := range uu {
+		u := uu[k]
+		t.Run(k, func(t *testing.T) {
+			p := cmd.NewInterpreter(u.cmd)
+			sel, err := p.LabelsSelector()
+			assert.Equal(t, u.err, err)
+			if err == nil {
+				assert.Equal(t, u.lbls, sel.String())
+			}
+		})
+	}
+}
diff --git a/internal/view/command_test.go b/internal/view/command_test.go
--- a/internal/view/command_test.go
+++ b/internal/view/command_test.go
@@ -15,6 +15,7 @@ func Test_viewMetaFor(t *testing.T) {
 	uu := map[string]struct {
 		cmd string
 		gvr *client.GVR
+		p   *cmd.Interpreter
 		err error
 	}{
 		"empty": {
@@ -23,27 +24,37 @@ func Test_viewMetaFor(t *testing.T) {
 			err: errors.New("`` command not found"),
 		},
 
-		"toast-cmd": {
+		"toast": {
 			cmd: "v1/pd",
 			gvr: client.PodGVR,
 			err: errors.New("`v1/pd` command not found"),
 		},
 
-		"gvr-cmd": {
+		"gvr": {
 			cmd: "v1/pods",
 			gvr: client.PodGVR,
+			p:   cmd.NewInterpreter("v1/pods"),
 			err: errors.New("blah"),
 		},
 
-		"alias-cmd": {
+		"short-name": {
 			cmd: "po",
 			gvr: client.PodGVR,
+			p:   cmd.NewInterpreter("v1/pods"),
 			err: errors.New("blee"),
 		},
 
-		"full-cmd": {
+		"custom-alias": {
 			cmd: "pdl",
 			gvr: client.PodGVR,
+			p:   cmd.NewInterpreter("v1/pods @fred app=blee default"),
+			err: errors.New("blee"),
+		},
+
+		"inception": {
+			cmd: "pdal blee",
+			gvr: client.PodGVR,
+			p:   cmd.NewInterpreter("v1/pods @fred app=blee blee"),
 			err: errors.New("blee"),
 		},
 	}
@@ -55,16 +66,18 @@ func Test_viewMetaFor(t *testing.T) {
 	}
 	c.alias.Define(client.PodGVR, "po", "pod", "pods", client.PodGVR.String())
 	c.alias.Define(client.NewGVR("pod default"), "pd")
-	c.alias.Define(client.NewGVR("pod default app=blee @fred"), "pdl")
+	c.alias.Define(client.NewGVR("pod @fred app=blee default"), "pdl")
+	c.alias.Define(client.NewGVR("pdl"), "pdal")
 
 	for k, u := range uu {
 		t.Run(k, func(t *testing.T) {
 			p := cmd.NewInterpreter(u.cmd)
-			gvr, _, err := c.viewMetaFor(p)
+			gvr, _, acmd, err := c.viewMetaFor(p)
 			if err != nil {
 				assert.Equal(t, u.err.Error(), err.Error())
 			} else {
 				assert.Equal(t, u.gvr, gvr)
+				assert.Equal(t, u.p, acmd)
 			}
 		})
 	}
diff --git a/internal/view/table_int_test.go b/internal/view/table_int_test.go
--- a/internal/view/table_int_test.go
+++ b/internal/view/table_int_test.go
@@ -80,7 +80,7 @@ func TestTableViewFilter(t *testing.T) {
 	v.Refresh()
 
 	v.CmdBuff().SetActive(true)
-	v.CmdBuff().SetText("blee", "")
+	v.CmdBuff().SetText("blee", "", true)
 
 	assert.Equal(t, 5, v.GetRowCount())
 }
EOF_114329324912

# Clear test cache to ensure fresh test execution
go clean -testcache

# Execute the target tests
# Running tests for all specified test files in their respective packages
# Using -v for verbose output to help with debugging
go test -v \
    ./internal/client \
    ./internal/config \
    ./internal/dao \
    ./internal/model \
    ./internal/port \
    ./internal/render \
    ./internal/ui \
    ./internal/view/... \
    -run "Test"

# Capture the exit code immediately
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e7970c25175ceef480b02bb692c7a9e210290f9e \
    "internal/client/config_test.go" \
    "internal/client/testdata/config.1" \
    "internal/config/alias_test.go" \
    "internal/config/testdata/configs/default.yaml" \
    "internal/dao/alias_test.go" \
    "internal/dao/rbac_policy_test.go" \
    "internal/model/stack_test.go" \
    "internal/port/pfs_test.go" \
    "internal/render/cronjob_test.go" \
    "internal/render/dp_test.go" \
    "internal/render/ds_test.go" \
    "internal/render/job_test.go" \
    "internal/render/node_int_test.go" \
    "internal/render/pod_test.go" \
    "internal/render/rs_test.go" \
    "internal/render/sts_test.go" \
    "internal/ui/app_test.go" \
    "internal/ui/crumbs_test.go" \
    "internal/ui/prompt_test.go" \
    "internal/ui/table_helper_test.go" \
    "internal/view/app_test.go" \
    "internal/view/cmd/args_test.go" \
    "internal/view/cmd/interpreter_test.go" \
    "internal/view/command_test.go" \
    "internal/view/table_int_test.go"