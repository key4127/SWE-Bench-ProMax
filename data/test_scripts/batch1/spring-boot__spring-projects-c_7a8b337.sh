#!/bin/bash
set -xeo pipefail

# Source SDKMAN to ensure Java is available
source /root/.sdkman/bin/sdkman-init.sh

# Ensure SPRING_PROFILES_ACTIVE is unset as required
unset SPRING_PROFILES_ACTIVE

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 11c5a8c4048d4d61f969eb378a48b5cafc287cd7 "module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java" "module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/module/spring-boot-http-client/src/test/java/org/springframework/boot/http/client/autoconfigure/service/ConditionalOnMissingHttpServiceProxyBeanTests.java b/module/spring-boot-http-client/src/test/java/org/springframework/boot/http/client/autoconfigure/service/ConditionalOnMissingHttpServiceProxyBeanTests.java
new file mode 100644
--- /dev/null
+++ b/module/spring-boot-http-client/src/test/java/org/springframework/boot/http/client/autoconfigure/service/ConditionalOnMissingHttpServiceProxyBeanTests.java
@@ -0,0 +1,82 @@
+/*
+ * Copyright 2012-present the original author or authors.
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *      https://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+
+package org.springframework.boot.http.client.autoconfigure.service;
+
+import org.junit.jupiter.api.Test;
+
+import org.springframework.boot.test.context.runner.ApplicationContextRunner;
+import org.springframework.context.annotation.Bean;
+import org.springframework.context.annotation.Configuration;
+import org.springframework.test.util.ReflectionTestUtils;
+import org.springframework.web.service.annotation.GetExchange;
+import org.springframework.web.service.registry.AbstractHttpServiceRegistrar;
+import org.springframework.web.service.registry.ImportHttpServices;
+
+import static org.assertj.core.api.Assertions.assertThat;
+
+/**
+ * Tests for
+ * {@link ConditionalOnMissingHttpServiceProxyBean @ConditionalOnMissingHttpServiceProxyBean}.
+ *
+ * @author Phillip Webb
+ */
+class ConditionalOnMissingHttpServiceProxyBeanTests {
+
+	@Test
+	void attributeNameMatchesSpringFramework() {
+		assertThat(OnMissingHttpServiceProxyBeanCondition.HTTP_SERVICE_GROUP_NAME_ATTRIBUTE).isEqualTo(
+				ReflectionTestUtils.getField(AbstractHttpServiceRegistrar.class, "HTTP_SERVICE_GROUP_NAME_ATTRIBUTE"));
+	}
+
+	@Test
+	void getOutcomeWhenNoHttpServiceProxyMatches() {
+		new ApplicationContextRunner().withUserConfiguration(TestConfiguration.class)
+			.run((context) -> assertThat(context).hasBean("test"));
+	}
+
+	@Test
+	void getOutcomeWhenHasHttpServiceProxyDoesNotMatch() {
+		new ApplicationContextRunner()
+			.withUserConfiguration(HttpServiceProxyConfiguration.class, TestConfiguration.class)
+			.run((context) -> assertThat(context).hasSingleBean(TestHttpService.class).doesNotHaveBean("test"));
+	}
+
+	@Configuration(proxyBeanMethods = false)
+	@ImportHttpServices(TestHttpService.class)
+	static class HttpServiceProxyConfiguration {
+
+	}
+
+	@Configuration(proxyBeanMethods = false)
+	static class TestConfiguration {
+
+		@Bean
+		@ConditionalOnMissingHttpServiceProxyBean
+		String test() {
+			return "test";
+		}
+
+	}
+
+	interface TestHttpService {
+
+		@GetExchange("/test")
+		String test();
+
+	}
+
+}
diff --git a/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java b/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java
--- a/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java
+++ b/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java
@@ -27,13 +27,15 @@
 import org.junit.jupiter.api.Test;
 
 import org.springframework.aop.Advisor;
+import org.springframework.boot.autoconfigure.AutoConfigurationPackage;
 import org.springframework.boot.autoconfigure.AutoConfigurations;
 import org.springframework.boot.http.client.ClientHttpRequestFactoryBuilder;
 import org.springframework.boot.http.client.ClientHttpRequestFactorySettings;
 import org.springframework.boot.http.client.HttpRedirects;
 import org.springframework.boot.http.client.autoconfigure.HttpClientAutoConfiguration;
 import org.springframework.boot.restclient.RestClientCustomizer;
 import org.springframework.boot.restclient.autoconfigure.RestClientAutoConfiguration;
+import org.springframework.boot.restclient.autoconfigure.service.scan.TestHttpServiceClient;
 import org.springframework.boot.test.context.runner.ApplicationContextRunner;
 import org.springframework.context.annotation.Bean;
 import org.springframework.context.annotation.Configuration;
@@ -155,6 +157,18 @@ void whenHasNoHttpServiceProxyRegistryBean() {
 			.run((context) -> assertThat(context).doesNotHaveBean(HttpServiceProxyRegistry.class));
 	}
 
+	@Test
+	void registerHttpServiceAnnotatedInterfacesInPackages() {
+		this.contextRunner.withUserConfiguration(ScanConfiguration.class)
+			.run((context) -> assertThat(context).hasSingleBean(TestHttpServiceClient.class));
+	}
+
+	@Test
+	void whenHasImportAnnotationDoesNotRegisterHttpServiceAnnotatedInterfacesInPackages() {
+		this.contextRunner.withUserConfiguration(ScanConfiguration.class, HttpClientConfiguration.class)
+			.run((context) -> assertThat(context).doesNotHaveBean(TestHttpServiceClient.class));
+	}
+
 	private HttpClient getJdkHttpClient(Object proxy) {
 		return (HttpClient) Extractors.byName("clientRequestFactory.httpClient").apply(getRestClient(proxy));
 	}
@@ -237,6 +251,12 @@ RestClientHttpServiceGroupConfigurer restClientHttpServiceGroupConfigurer() {
 
 	}
 
+	@Configuration(proxyBeanMethods = false)
+	@AutoConfigurationPackage(basePackageClasses = TestHttpServiceClient.class)
+	static class ScanConfiguration {
+
+	}
+
 	interface TestClientOne {
 
 		@GetExchange("/hello")
diff --git a/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/scan/TestHttpServiceClient.java b/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/scan/TestHttpServiceClient.java
new file mode 100644
--- /dev/null
+++ b/module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/scan/TestHttpServiceClient.java
@@ -0,0 +1,33 @@
+/*
+ * Copyright 2012-present the original author or authors.
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *      https://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+
+package org.springframework.boot.restclient.autoconfigure.service.scan;
+
+import org.springframework.web.service.annotation.GetExchange;
+import org.springframework.web.service.registry.HttpServiceClient;
+
+/**
+ * Test HTTP service used with scanning.
+ *
+ * @author Phillip Webb
+ */
+@HttpServiceClient("test")
+public interface TestHttpServiceClient {
+
+	@GetExchange("/hello")
+	String hello();
+
+}
diff --git a/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java b/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java
--- a/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java
+++ b/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java
@@ -27,6 +27,7 @@
 import org.junit.jupiter.api.Test;
 
 import org.springframework.aop.Advisor;
+import org.springframework.boot.autoconfigure.AutoConfigurationPackage;
 import org.springframework.boot.autoconfigure.AutoConfigurations;
 import org.springframework.boot.http.client.HttpRedirects;
 import org.springframework.boot.http.client.autoconfigure.reactive.ClientHttpConnectorAutoConfiguration;
@@ -35,6 +36,7 @@
 import org.springframework.boot.test.context.runner.ReactiveWebApplicationContextRunner;
 import org.springframework.boot.webclient.WebClientCustomizer;
 import org.springframework.boot.webclient.autoconfigure.WebClientAutoConfiguration;
+import org.springframework.boot.webclient.autoconfigure.service.scan.TestHttpServiceClient;
 import org.springframework.context.annotation.Bean;
 import org.springframework.context.annotation.Configuration;
 import org.springframework.http.HttpHeaders;
@@ -137,6 +139,18 @@ void whenHasNoHttpServiceProxyRegistryBean() {
 			.run((context) -> assertThat(context).doesNotHaveBean(HttpServiceProxyRegistry.class));
 	}
 
+	@Test
+	void registerHttpServiceAnnotatedInterfacesInPackages() {
+		this.contextRunner.withUserConfiguration(ScanConfiguration.class)
+			.run((context) -> assertThat(context).hasSingleBean(TestHttpServiceClient.class));
+	}
+
+	@Test
+	void whenHasImportAnnotationDoesNotRegisterHttpServiceAnnotatedInterfacesInPackages() {
+		this.contextRunner.withUserConfiguration(ScanConfiguration.class, HttpClientConfiguration.class)
+			.run((context) -> assertThat(context).doesNotHaveBean(TestHttpServiceClient.class));
+	}
+
 	private HttpClient getJdkHttpClient(Object proxy) {
 		return (HttpClient) Extractors.byName("builder.connector.httpClient").apply(getWebClient(proxy));
 	}
@@ -206,6 +220,12 @@ WebClientHttpServiceGroupConfigurer restClientHttpServiceGroupConfigurer() {
 
 	}
 
+	@Configuration(proxyBeanMethods = false)
+	@AutoConfigurationPackage(basePackageClasses = TestHttpServiceClient.class)
+	static class ScanConfiguration {
+
+	}
+
 	interface TestClientOne {
 
 		@GetExchange("/hello")
diff --git a/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/scan/TestHttpServiceClient.java b/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/scan/TestHttpServiceClient.java
new file mode 100644
--- /dev/null
+++ b/module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/scan/TestHttpServiceClient.java
@@ -0,0 +1,33 @@
+/*
+ * Copyright 2012-present the original author or authors.
+ *
+ * Licensed under the Apache License, Version 2.0 (the "License");
+ * you may not use this file except in compliance with the License.
+ * You may obtain a copy of the License at
+ *
+ *      https://www.apache.org/licenses/LICENSE-2.0
+ *
+ * Unless required by applicable law or agreed to in writing, software
+ * distributed under the License is distributed on an "AS IS" BASIS,
+ * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+ * See the License for the specific language governing permissions and
+ * limitations under the License.
+ */
+
+package org.springframework.boot.webclient.autoconfigure.service.scan;
+
+import org.springframework.web.service.annotation.GetExchange;
+import org.springframework.web.service.registry.HttpServiceClient;
+
+/**
+ * Test HTTP service used with scanning.
+ *
+ * @author Phillip Webb
+ */
+@HttpServiceClient("test")
+public interface TestHttpServiceClient {
+
+	@GetExchange("/hello")
+	String hello();
+
+}
EOF_114329324912

# Execute the specific test files for both modules
# Using --info for detailed test output
# Using --no-daemon to avoid daemon issues in containerized environment
# Using --stacktrace for better error visibility
echo "=========================================="
echo "Running target tests with detailed output"
echo "=========================================="

./gradlew \
    :module:spring-boot-restclient:test --tests "org.springframework.boot.restclient.autoconfigure.service.HttpServiceClientAutoConfigurationTests" \
    :module:spring-boot-webclient:test --tests "org.springframework.boot.webclient.autoconfigure.service.ReactiveHttpServiceClientAutoConfigurationTests" \
    --info --no-daemon --stacktrace

# Capture exit code
rc=$?

echo "=========================================="
echo "Test execution completed with exit code: $rc"
echo "=========================================="

# Display test results from XML reports
echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="

# Check and display restclient test results
if [ -d "module/spring-boot-restclient/build/test-results/test" ]; then
    echo ""
    echo "--- RestClient Module Test Results ---"
    find module/spring-boot-restclient/build/test-results/test -name "*.xml" -exec echo "Found: {}" \; -exec grep -E "(testcase|testsuite)" {} \; 2>/dev/null || echo "No test results found"
fi

# Check and display webclient test results
if [ -d "module/spring-boot-webclient/build/test-results/test" ]; then
    echo ""
    echo "--- WebClient Module Test Results ---"
    find module/spring-boot-webclient/build/test-results/test -name "*.xml" -exec echo "Found: {}" \; -exec grep -E "(testcase|testsuite)" {} \; 2>/dev/null || echo "No test results found"
fi

echo ""
echo "=========================================="

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 11c5a8c4048d4d61f969eb378a48b5cafc287cd7 "module/spring-boot-restclient/src/test/java/org/springframework/boot/restclient/autoconfigure/service/HttpServiceClientAutoConfigurationTests.java" "module/spring-boot-webclient/src/test/java/org/springframework/boot/webclient/autoconfigure/service/ReactiveHttpServiceClientAutoConfigurationTests.java"