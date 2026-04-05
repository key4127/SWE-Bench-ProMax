#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original files before applying patch
git checkout 36cc99a70c525bc7add56e4357b815305b24cc15 "sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-test/pom.xml" "sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java"

# Apply the test patch (this may include changes to core modules and demo modules)
git apply -v - <<'EOF_114329324912'
diff --git a/sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java b/sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java
--- a/sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java
+++ b/sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java
@@ -1,6 +1,7 @@
 package com.pj.test;
 
 import cn.dev33.satoken.context.SaHolder;
+import cn.dev33.satoken.servlet.util.SaTokenContextUtil;
 import cn.dev33.satoken.spring.SpringMVCUtil;
 import cn.dev33.satoken.util.SaResult;
 import org.springframework.web.bind.annotation.RequestMapping;
@@ -18,7 +19,9 @@ public class TestController {
 	// 测试   浏览器访问： http://localhost:8081/test/test
 	@RequestMapping("test")
 	public SaResult test() {
-		System.out.println("------------进来了"); 
+		System.out.println("------------进来了");
+		System.out.println(SpringMVCUtil.getRequest());
+		System.out.println(SaTokenContextUtil.getRequest());
 		return SaResult.ok();
 	}
 	
diff --git a/sa-token-demo/sa-token-demo-test/pom.xml b/sa-token-demo/sa-token-demo-test/pom.xml
--- a/sa-token-demo/sa-token-demo-test/pom.xml
+++ b/sa-token-demo/sa-token-demo-test/pom.xml
@@ -73,8 +73,12 @@
 			<artifactId>spring-boot-configuration-processor</artifactId>
 			<optional>true</optional>
 		</dependency>
+        <dependency>
+            <groupId>org.springframework.boot</groupId>
+            <artifactId>spring-boot-starter-actuator</artifactId>
+        </dependency>
 
-	</dependencies>
+    </dependencies>
 
 	<!-- 构建配置 -->
 	<build>
diff --git a/sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java b/sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java
--- a/sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java
+++ b/sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java
@@ -1,6 +1,7 @@
 package com.pj.test;
 
-import cn.dev33.satoken.stp.StpUtil;
+import cn.dev33.satoken.servlet.util.SaTokenContextUtil;
+import cn.dev33.satoken.spring.SpringMVCUtil;
 import cn.dev33.satoken.util.SaResult;
 import org.springframework.web.bind.annotation.RequestMapping;
 import org.springframework.web.bind.annotation.RestController;
@@ -17,9 +18,12 @@ public class Test2Controller {
 	@RequestMapping("/test")
 	public SaResult test2() {
 
-		StpUtil.login(30003);
-		System.out.println(StpUtil.getSession().timeout());
-		System.out.println(StpUtil.getStpLogic().getTokenSession(false));
+		System.out.println(SpringMVCUtil.getRequest());
+		System.out.println(SaTokenContextUtil.getRequest());
+
+//		StpUtil.login(30003);
+//		System.out.println(StpUtil.getSession().timeout());
+//		System.out.println(StpUtil.getStpLogic().getTokenSession(false));
 
 		return SaResult.ok();
 	}
diff --git a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java
--- a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java
+++ b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java
@@ -1,5 +1,8 @@
 package com.pj.test;
 
+import cn.dev33.satoken.reactor.context.SaReactorSyncHolder;
+import cn.dev33.satoken.stp.StpUtil;
+import cn.dev33.satoken.util.SaResult;
 import org.springframework.context.annotation.Bean;
 import org.springframework.context.annotation.Configuration;
 import org.springframework.http.MediaType;
@@ -8,10 +11,6 @@
 import org.springframework.web.reactive.function.server.RouterFunctions;
 import org.springframework.web.reactive.function.server.ServerResponse;
 
-import com.pj.util.AjaxJson;
-
-import cn.dev33.satoken.stp.StpUtil;
-
 @Configuration
 public class DefineRoutes {
 
@@ -23,12 +22,11 @@ public class DefineRoutes {
 	@Bean
 	public RouterFunction<ServerResponse> getRoutes() {
 		return RouterFunctions.route(RequestPredicates.GET("/fun"), req -> {
-			// 测试打印 
-			System.out.println("是否登录：" + StpUtil.isLogin());
-			
-			// 返回结果 
-			AjaxJson aj = AjaxJson.getSuccessData(StpUtil.getTokenInfo());
-			return ServerResponse.ok().contentType(MediaType.APPLICATION_JSON_UTF8).syncBody(aj);
+			return SaReactorSyncHolder.setContext(req.exchange(), () -> {
+				System.out.println("是否登录：" + StpUtil.isLogin());
+				SaResult res = SaResult.data(StpUtil.getTokenInfo());
+				return ServerResponse.ok().contentType(MediaType.APPLICATION_JSON_UTF8).syncBody(res);
+			});
 		});	
 	}
 	
diff --git a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java
--- a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java
+++ b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java
@@ -1,52 +1,19 @@
 package com.pj.test;
 
-import org.springframework.web.bind.annotation.ControllerAdvice;
+import cn.dev33.satoken.util.SaResult;
 import org.springframework.web.bind.annotation.ExceptionHandler;
-import org.springframework.web.bind.annotation.ResponseBody;
-
-import com.pj.util.AjaxJson;
-
-import cn.dev33.satoken.exception.DisableServiceException;
-import cn.dev33.satoken.exception.NotLoginException;
-import cn.dev33.satoken.exception.NotPermissionException;
-import cn.dev33.satoken.exception.NotRoleException;
+import org.springframework.web.bind.annotation.RestControllerAdvice;
 
 /**
  * 全局异常处理 
  */
-@ControllerAdvice // 可指定包前缀，比如：(basePackages = "com.pj.admin")
+@RestControllerAdvice
 public class GlobalException {
 
-	// 全局异常拦截（拦截项目中的所有异常）
-	@ResponseBody
 	@ExceptionHandler
-	public AjaxJson handlerException(Exception e)
-			throws Exception {
-
-		// 打印堆栈，以供调试
-		System.out.println("全局异常---------------");
-		e.printStackTrace(); 
-
-		// 不同异常返回不同状态码 
-		AjaxJson aj = null;
-		if (e instanceof NotLoginException) {	// 如果是未登录异常
-			NotLoginException ee = (NotLoginException) e;
-			aj = AjaxJson.getNotLogin().setMsg(ee.getMessage());
-		} else if(e instanceof NotRoleException) {		// 如果是角色异常
-			NotRoleException ee = (NotRoleException) e;
-			aj = AjaxJson.getNotJur("无此角色：" + ee.getRole());
-		} else if(e instanceof NotPermissionException) {	// 如果是权限异常
-			NotPermissionException ee = (NotPermissionException) e;
-			aj = AjaxJson.getNotJur("无此权限：" + ee.getPermission());
-		} else if(e instanceof DisableServiceException) {	// 如果是被封禁异常
-			DisableServiceException ee = (DisableServiceException) e;
-			aj = AjaxJson.getNotJur("账号被封禁：" + ee.getDisableTime() + "秒后解封");
-		} else {	// 普通异常, 输出：500 + 异常信息
-			aj = AjaxJson.getError(e.getMessage());
-		}
-		
-		// 返回给前端
-		return aj;
+	public SaResult handlerException(Exception e) {
+		e.printStackTrace();
+		return SaResult.error(e.getMessage());
 	}
 	
 }
diff --git a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java
--- a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java
+++ b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java
@@ -1,17 +1,19 @@
 package com.pj.test;
 
-import java.time.Duration;
-
+import cn.dev33.satoken.reactor.context.SaReactorHolder;
+import cn.dev33.satoken.reactor.context.SaReactorSyncHolder;
+import cn.dev33.satoken.stp.StpUtil;
+import cn.dev33.satoken.util.SaResult;
+import org.springframework.beans.factory.annotation.Autowired;
+import org.springframework.web.bind.annotation.CookieValue;
 import org.springframework.web.bind.annotation.RequestMapping;
 import org.springframework.web.bind.annotation.RequestParam;
 import org.springframework.web.bind.annotation.RestController;
-
-import com.pj.util.AjaxJson;
-
-import cn.dev33.satoken.reactor.context.SaReactorHolder;
-import cn.dev33.satoken.stp.StpUtil;
+import org.springframework.web.server.ServerWebExchange;
 import reactor.core.publisher.Mono;
 
+import java.time.Duration;
+
 /**
  * 测试专用Controller 
  * @author click33
@@ -21,60 +23,93 @@
 @RequestMapping("/test/")
 public class TestController {
 
-	// 测试登录接口 [同步模式]， 浏览器访问： http://localhost:8081/test/login
+	@Autowired
+	UserService userService;
+
+	// 登录测试：Controller 里调用 Sa-Token API   --- http://localhost:8081/test/login
 	@RequestMapping("login")
-	public AjaxJson login(@RequestParam(defaultValue="10001") String id) {
-		StpUtil.login(id);			
-		return AjaxJson.getSuccess("登录成功");
+	public Mono<SaResult> login(@RequestParam(defaultValue="10001") String id) {
+		return SaReactorHolder.sync(() -> {
+			StpUtil.login(id);
+			return SaResult.ok("登录成功");
+		});
 	}
-	
-	// API测试 [同步模式]， 浏览器访问： http://localhost:8081/test/isLogin
+
+	// API测试：手动设置上下文、try-finally 形式     	--- http://localhost:8081/test/isLogin
 	@RequestMapping("isLogin")
-	public AjaxJson isLogin() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public SaResult isLogin(ServerWebExchange exchange) {
+		try {
+			SaReactorSyncHolder.setContext(exchange);
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			return SaResult.data(StpUtil.getTokenInfo());
+		} finally {
+			SaReactorSyncHolder.clearContext();
+		}
 	}
 
-	// API测试 [异步模式]， 浏览器访问： http://localhost:8081/test/isLogin2
+	// API测试：手动设置上下文、lambda 表达式形式    	--- http://localhost:8081/test/isLogin2
 	@RequestMapping("isLogin2")
-	public Mono<AjaxJson> isLogin2() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		AjaxJson aj = AjaxJson.getSuccessData(StpUtil.getTokenInfo());
-		return Mono.just(aj);
+	public SaResult isLogin2(ServerWebExchange exchange) {
+		SaResult res = SaReactorSyncHolder.setContext(exchange, ()->{
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			return SaResult.data(StpUtil.getTokenInfo());
+		});
+		return SaResult.data(res);
 	}
 
-	// API测试 [异步模式, 同一线程]， 浏览器访问： http://localhost:8081/test/isLogin3
+	// API测试：自动设置上下文、lambda 表达式形式    	--- http://localhost:8081/test/isLogin3
 	@RequestMapping("isLogin3")
-	public Mono<AjaxJson> isLogin3() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		// 异步方式 
-		return SaReactorHolder.getContext().map(e -> {
-			System.out.println("当前会话是否登录2：" + StpUtil.isLogin());
-			return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public Mono<SaResult> isLogin3() {
+		return SaReactorHolder.sync(() -> {
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			userService.isLogin();
+			return SaResult.data(StpUtil.getTokenInfo());
 		});
 	}
 
-	// API测试 [异步模式, 不同线程]， 浏览器访问： http://localhost:8081/test/isLogin4
+	// API测试：自动设置上下文、调用 userService Mono 方法     	--- http://localhost:8081/test/isLogin4
 	@RequestMapping("isLogin4")
-	public Mono<AjaxJson> isLogin4() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		System.out.println("线程id-----" + Thread.currentThread().getId());
-		return Mono.delay(Duration.ofSeconds(1)).flatMap(r->{
-			return SaReactorHolder.getContext().map(rr->{
-				System.out.println("线程id---内--" + Thread.currentThread().getId());
-				System.out.println("当前会话是否登录2：" + StpUtil.isLogin());
-				return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public Mono<SaResult> isLogin4() {
+		return userService.findUserIdByNamePwd("ZhangSan", "123456").flatMap(userId -> {
+			return SaReactorHolder.sync(() -> {
+				StpUtil.login(userId);
+				return SaResult.data(StpUtil.getTokenInfo());
 			});
 		});
 	}
-	
+
+	// API测试：切换线程、复杂嵌套调用 	--- http://localhost:8081/test/isLogin5
+	@RequestMapping("isLogin5")
+	public Mono<SaResult> isLogin5() {
+		System.out.println("线程id-----" + Thread.currentThread().getId());
+		// 要点：在流里调用 Sa-Token API 之前，必须用 SaReactorHolder.sync( () -> {} ) 进行包裹
+		return Mono.delay(Duration.ofSeconds(1))
+				.doOnNext(r-> System.out.println("线程id-----" + Thread.currentThread().getId()))
+				.map(r-> SaReactorHolder.sync( () -> userService.isLogin() ))
+				.map(r-> userService.findUserIdByNamePwd("ZhangSan", "123456"))
+				.map(r-> SaReactorHolder.sync( () -> userService.isLogin() ))
+				.flatMap(isLogin -> {
+					System.out.println("是否登录 " + isLogin);
+					return SaReactorHolder.sync(() -> {
+						System.out.println("是否登录 " + StpUtil.isLogin());
+						return SaResult.data(StpUtil.getTokenInfo());
+					});
+				});
+	}
+
+	// API测试：使用上下文无关的API 	--- http://localhost:8081/test/isLogin6
+	@RequestMapping("isLogin6")
+	public SaResult isLogin6(@CookieValue("satoken") String satoken) {
+		System.out.println("token 为：" + satoken);
+		System.out.println("登录人：" + StpUtil.getLoginIdByToken(satoken));
+		return SaResult.ok("登录人：" + StpUtil.getLoginIdByToken(satoken));
+	}
+
 	// 测试   浏览器访问： http://localhost:8081/test/test
 	@RequestMapping("test")
-	public AjaxJson test() {
-		System.out.println("线程id-----------Controller--" + Thread.currentThread().getId() + "\t\t");
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public SaResult test() {
+		System.out.println("线程id------- " + Thread.currentThread().getId());
+		return SaResult.ok();
 	}
-	
 
 }
diff --git a/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/UserService.java b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/UserService.java
new file mode 100644
--- /dev/null
+++ b/sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/UserService.java
@@ -0,0 +1,25 @@
+package com.pj.test;
+
+import cn.dev33.satoken.stp.StpUtil;
+import org.springframework.stereotype.Service;
+import reactor.core.publisher.Mono;
+
+/**
+ * 模拟 Service 方法
+ * @author click33
+ * @since 2025/4/6
+ */
+@Service
+public class UserService {
+
+    public boolean isLogin() {
+        System.out.println("UserService 里调用 API 测试，是否登录：" + StpUtil.isLogin());
+        return StpUtil.isLogin();
+    }
+
+    public Mono<Long> findUserIdByNamePwd(String name, String pwd) {
+        // ...
+        return Mono.just(10001L);
+    }
+
+}
\ No newline at end of file
diff --git a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java
--- a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java
+++ b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java
@@ -1,5 +1,8 @@
 package com.pj.test;
 
+import cn.dev33.satoken.reactor.context.SaReactorSyncHolder;
+import cn.dev33.satoken.stp.StpUtil;
+import cn.dev33.satoken.util.SaResult;
 import org.springframework.context.annotation.Bean;
 import org.springframework.context.annotation.Configuration;
 import org.springframework.http.MediaType;
@@ -8,10 +11,6 @@
 import org.springframework.web.reactive.function.server.RouterFunctions;
 import org.springframework.web.reactive.function.server.ServerResponse;
 
-import com.pj.util.AjaxJson;
-
-import cn.dev33.satoken.stp.StpUtil;
-
 @Configuration
 public class DefineRoutes {
 
@@ -23,12 +22,11 @@ public class DefineRoutes {
 	@Bean
 	public RouterFunction<ServerResponse> getRoutes() {
 		return RouterFunctions.route(RequestPredicates.GET("/fun"), req -> {
-			// 测试打印 
-			System.out.println("是否登录：" + StpUtil.isLogin());
-			
-			// 返回结果 
-			AjaxJson aj = AjaxJson.getSuccessData(StpUtil.getTokenInfo());
-			return ServerResponse.ok().contentType(MediaType.APPLICATION_JSON_UTF8).syncBody(aj);
+			return SaReactorSyncHolder.setContext(req.exchange(), () -> {
+				System.out.println("是否登录：" + StpUtil.isLogin());
+				SaResult res = SaResult.data(StpUtil.getTokenInfo());
+				return ServerResponse.ok().contentType(MediaType.APPLICATION_JSON_UTF8).syncBody(res);
+			});
 		});	
 	}
 	
diff --git a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java
--- a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java
+++ b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java
@@ -1,52 +1,19 @@
 package com.pj.test;
 
-import org.springframework.web.bind.annotation.ControllerAdvice;
+import cn.dev33.satoken.util.SaResult;
 import org.springframework.web.bind.annotation.ExceptionHandler;
-import org.springframework.web.bind.annotation.ResponseBody;
-
-import com.pj.util.AjaxJson;
-
-import cn.dev33.satoken.exception.DisableServiceException;
-import cn.dev33.satoken.exception.NotLoginException;
-import cn.dev33.satoken.exception.NotPermissionException;
-import cn.dev33.satoken.exception.NotRoleException;
+import org.springframework.web.bind.annotation.RestControllerAdvice;
 
 /**
  * 全局异常处理 
  */
-@ControllerAdvice // 可指定包前缀，比如：(basePackages = "com.pj.admin")
+@RestControllerAdvice
 public class GlobalException {
 
-	// 全局异常拦截（拦截项目中的所有异常）
-	@ResponseBody
 	@ExceptionHandler
-	public AjaxJson handlerException(Exception e)
-			throws Exception {
-
-		// 打印堆栈，以供调试
-		System.out.println("全局异常---------------");
-		e.printStackTrace(); 
-
-		// 不同异常返回不同状态码 
-		AjaxJson aj = null;
-		if (e instanceof NotLoginException) {	// 如果是未登录异常
-			NotLoginException ee = (NotLoginException) e;
-			aj = AjaxJson.getNotLogin().setMsg(ee.getMessage());
-		} else if(e instanceof NotRoleException) {		// 如果是角色异常
-			NotRoleException ee = (NotRoleException) e;
-			aj = AjaxJson.getNotJur("无此角色：" + ee.getRole());
-		} else if(e instanceof NotPermissionException) {	// 如果是权限异常
-			NotPermissionException ee = (NotPermissionException) e;
-			aj = AjaxJson.getNotJur("无此权限：" + ee.getPermission());
-		} else if(e instanceof DisableServiceException) {	// 如果是被封禁异常
-			DisableServiceException ee = (DisableServiceException) e;
-			aj = AjaxJson.getNotJur("账号被封禁：" + ee.getDisableTime() + "秒后解封");
-		} else {	// 普通异常, 输出：500 + 异常信息
-			aj = AjaxJson.getError(e.getMessage());
-		}
-		
-		// 返回给前端
-		return aj;
+	public SaResult handlerException(Exception e) {
+		e.printStackTrace();
+		return SaResult.error(e.getMessage());
 	}
 	
 }
diff --git a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java
--- a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java
+++ b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java
@@ -1,11 +1,15 @@
 package com.pj.test;
 
 import cn.dev33.satoken.reactor.context.SaReactorHolder;
+import cn.dev33.satoken.reactor.context.SaReactorSyncHolder;
 import cn.dev33.satoken.stp.StpUtil;
-import com.pj.util.AjaxJson;
+import cn.dev33.satoken.util.SaResult;
+import org.springframework.beans.factory.annotation.Autowired;
+import org.springframework.web.bind.annotation.CookieValue;
 import org.springframework.web.bind.annotation.RequestMapping;
 import org.springframework.web.bind.annotation.RequestParam;
 import org.springframework.web.bind.annotation.RestController;
+import org.springframework.web.server.ServerWebExchange;
 import reactor.core.publisher.Mono;
 
 import java.time.Duration;
@@ -19,60 +23,93 @@
 @RequestMapping("/test/")
 public class TestController {
 
-	// 测试登录接口 [同步模式]， 浏览器访问： http://localhost:8081/test/login
+	@Autowired
+	UserService userService;
+
+	// 登录测试：Controller 里调用 Sa-Token API   --- http://localhost:8081/test/login
 	@RequestMapping("login")
-	public AjaxJson login(@RequestParam(defaultValue="10001") String id) {
-		StpUtil.login(id);			
-		return AjaxJson.getSuccess("登录成功");
+	public Mono<SaResult> login(@RequestParam(defaultValue="10001") String id) {
+		return SaReactorHolder.sync(() -> {
+			StpUtil.login(id);
+			return SaResult.ok("登录成功");
+		});
 	}
-	
-	// API测试 [同步模式]， 浏览器访问： http://localhost:8081/test/isLogin
+
+	// API测试：手动设置上下文、try-finally 形式     	--- http://localhost:8081/test/isLogin
 	@RequestMapping("isLogin")
-	public AjaxJson isLogin() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public SaResult isLogin(ServerWebExchange exchange) {
+		try {
+			SaReactorSyncHolder.setContext(exchange);
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			return SaResult.data(StpUtil.getTokenInfo());
+		} finally {
+			SaReactorSyncHolder.clearContext();
+		}
 	}
 
-	// API测试 [异步模式]， 浏览器访问： http://localhost:8081/test/isLogin2
+	// API测试：手动设置上下文、lambda 表达式形式    	--- http://localhost:8081/test/isLogin2
 	@RequestMapping("isLogin2")
-	public Mono<AjaxJson> isLogin2() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		AjaxJson aj = AjaxJson.getSuccessData(StpUtil.getTokenInfo());
-		return Mono.just(aj);
+	public SaResult isLogin2(ServerWebExchange exchange) {
+		SaResult res = SaReactorSyncHolder.setContext(exchange, ()->{
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			return SaResult.data(StpUtil.getTokenInfo());
+		});
+		return SaResult.data(res);
 	}
 
-	// API测试 [异步模式, 同一线程]， 浏览器访问： http://localhost:8081/test/isLogin3
+	// API测试：自动设置上下文、lambda 表达式形式    	--- http://localhost:8081/test/isLogin3
 	@RequestMapping("isLogin3")
-	public Mono<AjaxJson> isLogin3() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		// 异步方式 
-		return SaReactorHolder.getContext().map(e -> {
-			System.out.println("当前会话是否登录2：" + StpUtil.isLogin());
-			return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public Mono<SaResult> isLogin3() {
+		return SaReactorHolder.sync(() -> {
+			System.out.println("是否登录：" + StpUtil.isLogin());
+			userService.isLogin();
+			return SaResult.data(StpUtil.getTokenInfo());
 		});
 	}
 
-	// API测试 [异步模式, 不同线程]， 浏览器访问： http://localhost:8081/test/isLogin4
+	// API测试：自动设置上下文、调用 userService Mono 方法     	--- http://localhost:8081/test/isLogin4
 	@RequestMapping("isLogin4")
-	public Mono<AjaxJson> isLogin4() {
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		System.out.println("线程id-----" + Thread.currentThread().getId());
-		return Mono.delay(Duration.ofSeconds(1)).flatMap(r->{
-			return SaReactorHolder.getContext().map(rr->{
-				System.out.println("线程id---内--" + Thread.currentThread().getId());
-				System.out.println("当前会话是否登录2：" + StpUtil.isLogin());
-				return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public Mono<SaResult> isLogin4() {
+		return userService.findUserIdByNamePwd("ZhangSan", "123456").flatMap(userId -> {
+			return SaReactorHolder.sync(() -> {
+				StpUtil.login(userId);
+				return SaResult.data(StpUtil.getTokenInfo());
 			});
 		});
 	}
-	
+
+	// API测试：切换线程、复杂嵌套调用 	--- http://localhost:8081/test/isLogin5
+	@RequestMapping("isLogin5")
+	public Mono<SaResult> isLogin5() {
+		System.out.println("线程id-----" + Thread.currentThread().getId());
+		// 要点：在流里调用 Sa-Token API 之前，必须用 SaReactorHolder.sync( () -> {} ) 进行包裹
+		return Mono.delay(Duration.ofSeconds(1))
+				.doOnNext(r-> System.out.println("线程id-----" + Thread.currentThread().getId()))
+				.map(r-> SaReactorHolder.sync( () -> userService.isLogin() ))
+				.map(r-> userService.findUserIdByNamePwd("ZhangSan", "123456"))
+				.map(r-> SaReactorHolder.sync( () -> userService.isLogin() ))
+				.flatMap(isLogin -> {
+					System.out.println("是否登录 " + isLogin);
+					return SaReactorHolder.sync(() -> {
+						System.out.println("是否登录 " + StpUtil.isLogin());
+						return SaResult.data(StpUtil.getTokenInfo());
+					});
+				});
+	}
+
+	// API测试：使用上下文无关的API 	--- http://localhost:8081/test/isLogin6
+	@RequestMapping("isLogin6")
+	public SaResult isLogin6(@CookieValue("satoken") String satoken) {
+		System.out.println("token 为：" + satoken);
+		System.out.println("登录人：" + StpUtil.getLoginIdByToken(satoken));
+		return SaResult.ok("登录人：" + StpUtil.getLoginIdByToken(satoken));
+	}
+
 	// 测试   浏览器访问： http://localhost:8081/test/test
 	@RequestMapping("test")
-	public AjaxJson test() {
-		System.out.println("线程id-----------Controller--" + Thread.currentThread().getId() + "\t\t");
-		System.out.println("当前会话是否登录：" + StpUtil.isLogin());
-		return AjaxJson.getSuccessData(StpUtil.getTokenInfo());
+	public SaResult test() {
+		System.out.println("线程id------- " + Thread.currentThread().getId());
+		return SaResult.ok();
 	}
-	
 
 }
diff --git a/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/UserService.java b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/UserService.java
new file mode 100644
--- /dev/null
+++ b/sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/UserService.java
@@ -0,0 +1,25 @@
+package com.pj.test;
+
+import cn.dev33.satoken.stp.StpUtil;
+import org.springframework.stereotype.Service;
+import reactor.core.publisher.Mono;
+
+/**
+ * 模拟 Service 方法
+ * @author click33
+ * @since 2025/4/6
+ */
+@Service
+public class UserService {
+
+    public boolean isLogin() {
+        System.out.println("UserService 里调用 API 测试，是否登录：" + StpUtil.isLogin());
+        return StpUtil.isLogin();
+    }
+
+    public Mono<Long> findUserIdByNamePwd(String name, String pwd) {
+        // ...
+        return Mono.just(10001L);
+    }
+
+}
\ No newline at end of file
EOF_114329324912

# Check if patch was applied successfully
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to apply test patch"
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    exit $rc
fi

# Start Redis server (required for some demo modules)
/usr/local/bin/start-redis.sh
sleep 2

# Verify Redis is running
redis-cli ping || echo "Warning: Redis may not be running properly"

# Set environment variables
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export MAVEN_HOME=/opt/maven
export PATH=$JAVA_HOME/bin:$MAVEN_HOME/bin:$PATH
export MAVEN_OPTS="-Xms256m -Xmx2048m"

echo "=========================================="
echo "Rebuilding entire project with patched changes..."
echo "=========================================="

# Rebuild the entire project to ensure core module changes are compiled first
cd /testbed
mvn clean install -DskipTests -Dmaven.test.skip=true

if [ $? -ne 0 ]; then
    echo "ERROR: Project rebuild failed after applying patch"
    rc=1
    echo "OMNIGRIL_EXIT_CODE=$rc"
    git checkout 36cc99a70c525bc7add56e4357b815305b24cc15 "sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-test/pom.xml" "sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java"
    exit $rc
fi

echo "=========================================="
echo "Verifying affected demo modules..."
echo "=========================================="

# Track overall success
overall_rc=0

# Module 1: sa-token-demo-test (Spring Boot 2.x, requires Redis DB 0)
echo ">>> Verifying sa-token-demo-test"
cd /testbed/sa-token-demo/sa-token-demo-test
mvn clean compile
if [ $? -ne 0 ]; then
    echo "ERROR: sa-token-demo-test compilation failed"
    overall_rc=1
else
    echo "SUCCESS: sa-token-demo-test compiled successfully"
fi

# Module 2: sa-token-demo-springboot3-redis (Spring Boot 3.x, requires Redis DB 1)
echo ">>> Verifying sa-token-demo-springboot3-redis"
cd /testbed/sa-token-demo/sa-token-demo-springboot3-redis
mvn clean compile
if [ $? -ne 0 ]; then
    echo "ERROR: sa-token-demo-springboot3-redis compilation failed"
    overall_rc=1
else
    echo "SUCCESS: sa-token-demo-springboot3-redis compiled successfully"
fi

# Module 3: sa-token-demo-webflux-springboot3 (Spring Boot 3.x, WebFlux)
echo ">>> Verifying sa-token-demo-webflux-springboot3"
cd /testbed/sa-token-demo/sa-token-demo-webflux-springboot3
mvn clean compile
if [ $? -ne 0 ]; then
    echo "ERROR: sa-token-demo-webflux-springboot3 compilation failed"
    overall_rc=1
else
    echo "SUCCESS: sa-token-demo-webflux-springboot3 compiled successfully"
fi

# Module 4: sa-token-demo-webflux (Spring Boot 2.x, WebFlux)
echo ">>> Verifying sa-token-demo-webflux"
cd /testbed/sa-token-demo/sa-token-demo-webflux
mvn clean compile
if [ $? -ne 0 ]; then
    echo "ERROR: sa-token-demo-webflux compilation failed"
    overall_rc=1
else
    echo "SUCCESS: sa-token-demo-webflux compiled successfully"
fi

# Set final exit code
rc=$overall_rc

echo "=========================================="
echo "Evaluation complete"
echo "=========================================="
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 36cc99a70c525bc7add56e4357b815305b24cc15 "sa-token-demo/sa-token-demo-springboot3-redis/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-test/pom.xml" "sa-token-demo/sa-token-demo-test/src/main/java/com/pj/test/Test2Controller.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux-springboot3/src/main/java/com/pj/test/TestController.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/DefineRoutes.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/GlobalException.java" "sa-token-demo/sa-token-demo-webflux/src/main/java/com/pj/test/TestController.java"