#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2ebd776f1bec94d1480e417e5f4e293671fad0e5 "spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java b/spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java
--- a/spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java
+++ b/spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java
@@ -19,6 +19,7 @@
 import java.util.Map;
 
 import org.junit.jupiter.api.Test;
+import reactor.core.publisher.Mono;
 
 import org.springframework.beans.factory.annotation.Value;
 import org.springframework.boot.SpringBootConfiguration;
@@ -30,8 +31,12 @@
 import org.springframework.context.annotation.Bean;
 import org.springframework.context.annotation.Import;
 import org.springframework.http.HttpHeaders;
+import org.springframework.http.HttpStatus;
 import org.springframework.http.MediaType;
+import org.springframework.http.ResponseEntity;
 import org.springframework.test.annotation.DirtiesContext;
+import org.springframework.web.bind.annotation.ControllerAdvice;
+import org.springframework.web.bind.annotation.ExceptionHandler;
 
 import static org.assertj.core.api.Assertions.assertThat;
 import static org.springframework.boot.test.context.SpringBootTest.WebEnvironment.RANDOM_PORT;
@@ -42,10 +47,10 @@
  */
 @SpringBootTest(webEnvironment = RANDOM_PORT)
 @DirtiesContext
-public class RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests extends BaseWebClientTests {
+class RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests extends BaseWebClientTests {
 
 	@Test
-	public void removeJsonAttributeRootWorks() {
+	void removeJsonAttributeRootWorks() {
 		testClient.post()
 			.uri("/post")
 			.header("Host", "www.removejsonattributes.org")
@@ -70,8 +75,7 @@ public void removeJsonAttributeRootWorks() {
 	}
 
 	@Test
-	public void removeJsonAttributeRecursivelyWorks() {
-
+	void removeJsonAttributeRecursivelyWorks() {
 		testClient.post()
 			.uri("/post")
 			.header("Host", "www.removejsonattributesrecursively.org")
@@ -93,8 +97,7 @@ public void removeJsonAttributeRecursivelyWorks() {
 	}
 
 	@Test
-	public void removeJsonAttributeNoMatchesWorks() {
-
+	void removeJsonAttributeNoMatchesWorks() {
 		testClient.post()
 			.uri("/post")
 			.header("Host", "www.removejsonattributesnomatches.org")
@@ -113,6 +116,21 @@ public void removeJsonAttributeNoMatchesWorks() {
 			});
 	}
 
+	@Test
+	void raisedWhenRemoveJsonAttributes() {
+		testClient.post()
+			.uri("/post")
+			.header("Host", "www.raisederrorwhenremovejsonattributes.org")
+			.header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
+			.exchange()
+			.expectStatus()
+			.is5xxServerError()
+			.expectBody(String.class)
+			.consumeWith(result -> {
+				assertThat(result.getResponseBody()).isEqualTo("Failed to process JSON of response body.");
+			});
+	}
+
 	@EnableAutoConfiguration
 	@SpringBootConfiguration
 	@Import(DefaultTestConfig.class)
@@ -142,9 +160,27 @@ public RouteLocator testRouteLocator(RouteLocatorBuilder builder) {
 							.host("{sub}.removejsonattributesnomatches.org")
 							.filters(f -> f.removeJsonAttributes("test"))
 							.uri(uri))
+				.route("raised_error_when_remove_json_attributes",
+						r -> r.path("/post")
+							.and()
+							.host("{sub}.raisederrorwhenremovejsonattributes.org")
+							.filters(f -> f.removeJsonAttributes("test")
+								.modifyResponseBody(String.class, String.class,
+										(exchange, response) -> Mono.just("{\"invalid_json\": test")))
+							.uri(uri))
 				.build();
 		}
 
+		@ControllerAdvice
+		public class GlobalExceptionHandler {
+
+			@ExceptionHandler(IllegalStateException.class)
+			public ResponseEntity<String> handleIllegalException(IllegalStateException ex) {
+				return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(ex.getMessage());
+			}
+
+		}
+
 	}
 
 }
EOF_114329324912

# Set Maven options for optimal performance (removed MaxPermSize which is not valid in Java 17)
export MAVEN_OPTS="-Xmx2048m"

# Execute the specific test file using Maven
# Using -Dtest to run only the target test class
# -B for batch mode (non-interactive)
# -Pspring to use the Spring profile
# -Dmaven.test.redirectTestOutputToFile=false to see output in console
./mvnw test -B -Pspring \
    -Dtest=RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests \
    -pl spring-cloud-gateway-server \
    -Dmaven.wagon.http.pool=false \
    -Dmaven.wagon.httpconnectionManager.ttlSeconds=120

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 2ebd776f1bec94d1480e417e5f4e293671fad0e5 "spring-cloud-gateway-server/src/test/java/org/springframework/cloud/gateway/filter/factory/RemoveJsonAttributesResponseBodyGatewayFilterFactoryTests.java"