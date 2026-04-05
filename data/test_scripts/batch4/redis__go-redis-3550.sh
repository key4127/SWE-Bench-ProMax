#!/bin/bash
set -uxo pipefail

# Navigate to the testbed root
cd /testbed

# Checkout the original test file to ensure clean state
git checkout a15e76394c80a8053d2790058d439fc5dd59c112 "extra/redisotel/tracing_test.go"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/extra/redisotel/tracing_test.go b/extra/redisotel/tracing_test.go
--- a/extra/redisotel/tracing_test.go
+++ b/extra/redisotel/tracing_test.go
@@ -156,7 +156,7 @@ func TestWithCommandFilter(t *testing.T) {
 		hook := newTracingHook(
 			"",
 			WithTracerProvider(provider),
-			WithCommandFilter(BasicCommandFilter),
+			WithCommandFilter(DefaultCommandFilter),
 		)
 		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
 		cmd := redis.NewCmd(ctx, "auth", "test-password")
@@ -181,7 +181,7 @@ func TestWithCommandFilter(t *testing.T) {
 		hook := newTracingHook(
 			"",
 			WithTracerProvider(provider),
-			WithCommandFilter(BasicCommandFilter),
+			WithCommandFilter(DefaultCommandFilter),
 		)
 		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
 		cmd := redis.NewCmd(ctx, "hello", 3, "AUTH", "test-user", "test-password")
@@ -206,7 +206,7 @@ func TestWithCommandFilter(t *testing.T) {
 		hook := newTracingHook(
 			"",
 			WithTracerProvider(provider),
-			WithCommandFilter(BasicCommandFilter),
+			WithCommandFilter(DefaultCommandFilter),
 		)
 		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
 		cmd := redis.NewCmd(ctx, "hello", 3)
@@ -227,6 +227,120 @@ func TestWithCommandFilter(t *testing.T) {
 	})
 }
 
+func TestWithCommandsFilter(t *testing.T) {
+	t.Run("filter out ping and info commands", func(t *testing.T) {
+		provider := sdktrace.NewTracerProvider()
+		hook := newTracingHook(
+			"",
+			WithTracerProvider(provider),
+			WithCommandsFilter(func(cmds []redis.Cmder) bool {
+				for _, cmd := range cmds {
+					if cmd.Name() == "ping" || cmd.Name() == "info" {
+						return true
+					}
+				}
+				return false
+			}),
+		)
+
+		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
+		cmds := []redis.Cmder{
+			redis.NewCmd(ctx, "ping"),
+			redis.NewCmd(ctx, "info"),
+		}
+		defer span.End()
+
+		processPipelineHook := hook.ProcessPipelineHook(func(ctx context.Context, cmds []redis.Cmder) error {
+			innerSpan := trace.SpanFromContext(ctx).(sdktrace.ReadOnlySpan)
+			if innerSpan.Name() != "redis-test" || innerSpan.Name() == "redis.pipeline ping\ninfo" {
+				t.Fatalf("ping and info commands should not be traced")
+			}
+			return nil
+		})
+		err := processPipelineHook(ctx, cmds)
+		if err != nil {
+			t.Fatal(err)
+		}
+	})
+
+	t.Run("do not filter ping and info commands", func(t *testing.T) {
+		provider := sdktrace.NewTracerProvider()
+		hook := newTracingHook(
+			"",
+			WithTracerProvider(provider),
+			WithCommandsFilter(func(cmds []redis.Cmder) bool {
+				return false // never filter
+			}),
+		)
+		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
+		cmds := []redis.Cmder{
+			redis.NewCmd(ctx, "ping"),
+			redis.NewCmd(ctx, "info"),
+		}
+		defer span.End()
+		processPipelineHook := hook.ProcessPipelineHook(func(ctx context.Context, cmds []redis.Cmder) error {
+			innerSpan := trace.SpanFromContext(ctx).(sdktrace.ReadOnlySpan)
+			if innerSpan.Name() != "redis.pipeline ping info" {
+				t.Fatalf("ping and info commands should be traced")
+			}
+
+			return nil
+		})
+
+		err := processPipelineHook(ctx, cmds)
+		if err != nil {
+			t.Fatal(err)
+		}
+	})
+}
+
+func TestWithDialFilter(t *testing.T) {
+	t.Run("filter out dial", func(t *testing.T) {
+		provider := sdktrace.NewTracerProvider()
+		hook := newTracingHook(
+			"",
+			WithTracerProvider(provider),
+			WithDialFilter(true),
+		)
+		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
+		defer span.End()
+		dialHook := hook.DialHook(func(ctx context.Context, network, addr string) (conn net.Conn, err error) {
+			innerSpan := trace.SpanFromContext(ctx).(sdktrace.ReadOnlySpan)
+			if innerSpan.Name() == "redis.dial" {
+				t.Fatalf("dial should not be traced")
+			}
+			return nil, nil
+		})
+
+		_, err := dialHook(ctx, "tcp", "localhost:6379")
+		if err != nil {
+			t.Fatal(err)
+		}
+	})
+
+	t.Run("do not filter dial", func(t *testing.T) {
+		provider := sdktrace.NewTracerProvider()
+		hook := newTracingHook(
+			"",
+			WithTracerProvider(provider),
+			WithDialFilter(false),
+		)
+		ctx, span := provider.Tracer("redis-test").Start(context.TODO(), "redis-test")
+		defer span.End()
+		dialHook := hook.DialHook(func(ctx context.Context, network, addr string) (conn net.Conn, err error) {
+			innerSpan := trace.SpanFromContext(ctx).(sdktrace.ReadOnlySpan)
+			if innerSpan.Name() != "redis.dial" {
+				t.Fatalf("dial should be traced")
+			}
+			return nil, nil
+		})
+		_, err := dialHook(ctx, "tcp", "localhost:6379")
+		if err != nil {
+			t.Fatal(err)
+		}
+	})
+}
+
 func TestTracingHook_DialHook(t *testing.T) {
 	imsb := tracetest.NewInMemoryExporter()
 	provider := sdktrace.NewTracerProvider(sdktrace.WithSyncer(imsb))
EOF_114329324912

# Navigate to the test directory
cd /testbed/extra/redisotel

# Run the target test file
# Using -v for verbose output and running the specific test file
go test -v -run TestTracingHook
rc=$?

# Echo the exit code for the judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
cd /testbed
git checkout a15e76394c80a8053d2790058d439fc5dd59c112 "extra/redisotel/tracing_test.go"