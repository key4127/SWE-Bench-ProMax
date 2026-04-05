#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 0351e33b18e7235fe040ae6b131cd9b1ac951659 \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java
@@ -32,7 +32,7 @@
 import org.springframework.boot.buildpack.platform.docker.DockerApi.VolumeApi;
 import org.springframework.boot.buildpack.platform.docker.DockerLog;
 import org.springframework.boot.buildpack.platform.docker.TotalProgressPullListener;
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerRegistryAuthentication;
 import org.springframework.boot.buildpack.platform.docker.transport.DockerEngineException;
 import org.springframework.boot.buildpack.platform.docker.type.Binding;
 import org.springframework.boot.buildpack.platform.docker.type.ContainerReference;
@@ -49,6 +49,7 @@
 import static org.assertj.core.api.Assertions.assertThatIllegalStateException;
 import static org.assertj.core.api.Assertions.assertThatNoException;
 import static org.mockito.ArgumentMatchers.any;
+import static org.mockito.ArgumentMatchers.argThat;
 import static org.mockito.ArgumentMatchers.eq;
 import static org.mockito.ArgumentMatchers.isNull;
 import static org.mockito.BDDMockito.given;
@@ -66,6 +67,15 @@
  */
 class BuilderTests {
 
+	private static final ImageReference PAKETO_BUILDPACKS_BUILDER = ImageReference
+		.of("gcr.io/paketo-buildpacks/builder");
+
+	private static final ImageReference LATEST_PAKETO_BUILDPACKS_BUILDER = PAKETO_BUILDPACKS_BUILDER.inTaggedForm();
+
+	private static final ImageReference DEFAULT_BUILDER = ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF);
+
+	private static final ImageReference BASE_CNB = ImageReference.of("docker.io/cloudfoundry/run:base-cnb");
+
 	@Test
 	void createWhenLogIsNullThrowsException() {
 		assertThatIllegalArgumentException().isThrownBy(() -> new Builder((BuildLog) null))
@@ -108,24 +118,18 @@ void buildInvokesBuilder() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest();
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
 		ArgumentCaptor<ImageArchive> archive = ArgumentCaptor.forClass(ImageArchive.class);
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull());
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull());
+		then(docker.image()).should().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull());
+		then(docker.image()).should().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull());
 		then(docker.image()).should().load(archive.capture(), any());
 		then(docker.image()).should().remove(archive.getValue().getTag(), true);
 		then(docker.image()).shouldHaveNoMoreInteractions();
@@ -137,32 +141,25 @@ void buildInvokesBuilderAndPublishesImage() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		DockerConfiguration dockerConfiguration = new DockerConfiguration()
-			.withBuilderRegistryTokenAuthentication("builder token")
-			.withPublishRegistryTokenAuthentication("publish token");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+		DockerRegistryAuthentication builderToken = DockerRegistryAuthentication.token("builder token");
+		DockerRegistryAuthentication publishToken = DockerRegistryAuthentication.token("publish token");
+		BuilderDockerConfiguration dockerConfiguration = new BuilderDockerConfiguration()
+			.withBuilderRegistryAuthentication(builderToken)
+			.withPublishRegistryAuthentication(publishToken);
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, dockerConfiguration);
 		BuildRequest request = getTestRequest().withPublish(true);
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
 		ArgumentCaptor<ImageArchive> archive = ArgumentCaptor.forClass(ImageArchive.class);
+		then(docker.image()).should().pull(eq(DEFAULT_BUILDER), isNull(), any(), regAuthEq(builderToken));
 		then(docker.image()).should()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()));
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()));
-		then(docker.image()).should()
-			.push(eq(request.getName()), any(),
-					eq(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()));
+			.pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), regAuthEq(builderToken));
+		then(docker.image()).should().push(eq(request.getName()), any(), regAuthEq(publishToken));
 		then(docker.image()).should().load(archive.capture(), any());
 		then(docker.image()).should().remove(archive.getValue().getTag(), true);
 		then(docker.image()).shouldHaveNoMoreInteractions();
@@ -174,15 +171,14 @@ void buildInvokesBuilderWithDefaultImageTags() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image-with-no-run-image-tag.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of("gcr.io/paketo-buildpacks/builder:latest")), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(LATEST_PAKETO_BUILDPACKS_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
 		given(docker.image()
 			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:latest")), eq(ImagePlatform.from(builderImage)),
 					any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
-		BuildRequest request = getTestRequest().withBuilder(ImageReference.of("gcr.io/paketo-buildpacks/builder"));
+		BuildRequest request = getTestRequest().withBuilder(PAKETO_BUILDPACKS_BUILDER);
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
@@ -197,8 +193,7 @@ void buildInvokesBuilderWithRunImageInDigestForm() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image-with-run-image-digest.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
 		given(docker.image()
 			.pull(eq(ImageReference
@@ -221,15 +216,12 @@ void buildInvokesBuilderWithNoStack() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image-with-empty-stack.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of("gcr.io/paketo-buildpacks/builder:latest")), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(LATEST_PAKETO_BUILDPACKS_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
-		BuildRequest request = getTestRequest().withBuilder(ImageReference.of("gcr.io/paketo-buildpacks/builder"));
+		BuildRequest request = getTestRequest().withBuilder(PAKETO_BUILDPACKS_BUILDER);
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
@@ -244,8 +236,7 @@ void buildInvokesBuilderWithRunImageFromRequest() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
 		given(docker.image()
 			.pull(eq(ImageReference.of("example.com/custom/run:latest")), eq(ImagePlatform.from(builderImage)), any(),
@@ -267,17 +258,12 @@ void buildInvokesBuilderWithNeverPullPolicy() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
-		given(docker.image().inspect(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF))))
-			.willReturn(builderImage);
-		given(docker.image().inspect(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb"))))
-			.willReturn(runImage);
+		given(docker.image().inspect(eq(DEFAULT_BUILDER))).willReturn(builderImage);
+		given(docker.image().inspect(eq(BASE_CNB))).willReturn(runImage);
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest().withPullPolicy(PullPolicy.NEVER);
 		builder.build(request);
@@ -296,17 +282,12 @@ void buildInvokesBuilderWithAlwaysPullPolicy() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
-		given(docker.image().inspect(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF))))
-			.willReturn(builderImage);
-		given(docker.image().inspect(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb"))))
-			.willReturn(runImage);
+		given(docker.image().inspect(eq(DEFAULT_BUILDER))).willReturn(builderImage);
+		given(docker.image().inspect(eq(BASE_CNB))).willReturn(runImage);
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest().withPullPolicy(PullPolicy.ALWAYS);
 		builder.build(request);
@@ -325,18 +306,15 @@ void buildInvokesBuilderWithIfNotPresentPullPolicy() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
-		given(docker.image().inspect(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF))))
+		given(docker.image().inspect(eq(DEFAULT_BUILDER)))
 			.willThrow(
 					new DockerEngineException("docker://localhost/", new URI("example"), 404, "NOT FOUND", null, null))
 			.willReturn(builderImage);
-		given(docker.image().inspect(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb"))))
+		given(docker.image().inspect(eq(BASE_CNB)))
 			.willThrow(
 					new DockerEngineException("docker://localhost/", new URI("example"), 404, "NOT FOUND", null, null))
 			.willReturn(runImage);
@@ -358,12 +336,9 @@ void buildInvokesBuilderWithTags() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest().withTags(ImageReference.of("my-application:1.2.3"));
@@ -383,37 +358,31 @@ void buildInvokesBuilderWithTagsAndPublishesImageAndTags() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		DockerConfiguration dockerConfiguration = new DockerConfiguration()
-			.withBuilderRegistryTokenAuthentication("builder token")
-			.withPublishRegistryTokenAuthentication("publish token");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+		DockerRegistryAuthentication builderToken = DockerRegistryAuthentication.token("builder token");
+		DockerRegistryAuthentication publishToken = DockerRegistryAuthentication.token("publish token");
+		BuilderDockerConfiguration dockerConfiguration = new BuilderDockerConfiguration()
+			.withBuilderRegistryAuthentication(builderToken)
+			.withPublishRegistryAuthentication(publishToken);
+		ImageReference defaultBuilderImageReference = DEFAULT_BUILDER;
+		given(docker.image().pull(eq(defaultBuilderImageReference), isNull(), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(builderImage));
+		ImageReference baseImageReference = BASE_CNB;
 		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+			.pull(eq(baseImageReference), eq(ImagePlatform.from(builderImage)), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, dockerConfiguration);
-		BuildRequest request = getTestRequest().withPublish(true).withTags(ImageReference.of("my-application:1.2.3"));
+		ImageReference builtImageReference = ImageReference.of("my-application:1.2.3");
+		BuildRequest request = getTestRequest().withPublish(true).withTags(builtImageReference);
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
 		assertThat(out.toString()).contains("Successfully created image tag 'docker.io/library/my-application:1.2.3'");
-
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()));
+		then(docker.image()).should().pull(eq(defaultBuilderImageReference), isNull(), any(), regAuthEq(builderToken));
 		then(docker.image()).should()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()));
-		then(docker.image()).should()
-			.push(eq(request.getName()), any(),
-					eq(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()));
-		then(docker.image()).should().tag(eq(request.getName()), eq(ImageReference.of("my-application:1.2.3")));
-		then(docker.image()).should()
-			.push(eq(ImageReference.of("my-application:1.2.3")), any(),
-					eq(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()));
+			.pull(eq(baseImageReference), eq(ImagePlatform.from(builderImage)), any(), regAuthEq(builderToken));
+		then(docker.image()).should().push(eq(request.getName()), any(), regAuthEq(publishToken));
+		then(docker.image()).should().tag(eq(request.getName()), eq(builtImageReference));
+		then(docker.image()).should().push(eq(builtImageReference), any(), regAuthEq(publishToken));
 		ArgumentCaptor<ImageArchive> archive = ArgumentCaptor.forClass(ImageArchive.class);
 		then(docker.image()).should().load(archive.capture(), any());
 		then(docker.image()).should().remove(archive.getValue().getTag(), true);
@@ -427,22 +396,17 @@ void buildInvokesBuilderWithPlatform() throws Exception {
 		DockerApi docker = mockDockerApi(platform);
 		Image builderImage = loadImage("image-with-platform.json");
 		Image runImage = loadImage("run-image-with-platform.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), eq(platform), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), eq(platform), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(platform), any(), isNull()))
-			.willAnswer(withPulledImage(runImage));
+		given(docker.image().pull(eq(BASE_CNB), eq(platform), any(), isNull())).willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest().withImagePlatform("linux/arm64/v1");
 		builder.build(request);
 		assertThat(out.toString()).contains("Running creator");
 		assertThat(out.toString()).contains("Successfully built image 'docker.io/library/my-application:latest'");
 		ArgumentCaptor<ImageArchive> archive = ArgumentCaptor.forClass(ImageArchive.class);
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), eq(platform), any(), isNull());
-		then(docker.image()).should()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(platform), any(), isNull());
+		then(docker.image()).should().pull(eq(DEFAULT_BUILDER), eq(platform), any(), isNull());
+		then(docker.image()).should().pull(eq(BASE_CNB), eq(platform), any(), isNull());
 		then(docker.image()).should().load(archive.capture(), any());
 		then(docker.image()).should().remove(archive.getValue().getTag(), true);
 		then(docker.image()).shouldHaveNoMoreInteractions();
@@ -454,12 +418,9 @@ void buildWhenStackIdDoesNotMatchThrowsException() throws Exception {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image-with-bad-stack.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest();
@@ -474,12 +435,9 @@ void buildWhenBuilderReturnsErrorThrowsException() throws Exception {
 		DockerApi docker = mockDockerApiLifecycleError();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest();
@@ -492,11 +450,11 @@ void buildWhenDetectedRunImageInDifferentAuthenticatedRegistryThrowsException()
 		TestPrintStream out = new TestPrintStream();
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image-with-run-image-different-registry.json");
-		DockerConfiguration dockerConfiguration = new DockerConfiguration()
-			.withBuilderRegistryTokenAuthentication("builder token");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), any(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+		DockerRegistryAuthentication builderToken = DockerRegistryAuthentication.token("builder token");
+		BuilderDockerConfiguration dockerConfiguration = new BuilderDockerConfiguration()
+			.withBuilderRegistryAuthentication(builderToken);
+		ImageReference builderImageReference = DEFAULT_BUILDER;
+		given(docker.image().pull(eq(builderImageReference), any(), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(builderImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, dockerConfiguration);
 		BuildRequest request = getTestRequest();
@@ -510,11 +468,10 @@ void buildWhenRequestedRunImageInDifferentAuthenticatedRegistryThrowsException()
 		TestPrintStream out = new TestPrintStream();
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
-		DockerConfiguration dockerConfiguration = new DockerConfiguration()
-			.withBuilderRegistryTokenAuthentication("builder token");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), any(), any(),
-					eq(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader())))
+		DockerRegistryAuthentication builderToken = DockerRegistryAuthentication.token("builder token");
+		BuilderDockerConfiguration dockerConfiguration = new BuilderDockerConfiguration()
+			.withBuilderRegistryAuthentication(builderToken);
+		given(docker.image().pull(eq(DEFAULT_BUILDER), any(), any(), regAuthEq(builderToken)))
 			.willAnswer(withPulledImage(builderImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, dockerConfiguration);
 		BuildRequest request = getTestRequest().withRunImage(ImageReference.of("example.com/custom/run:latest"));
@@ -529,11 +486,9 @@ void buildWhenRequestedBuildpackNotInBuilderThrowsException() throws Exception {
 		DockerApi docker = mockDockerApiLifecycleError();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), any(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), any(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image().pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), any(), any(), isNull()))
-			.willAnswer(withPulledImage(runImage));
+		given(docker.image().pull(eq(BASE_CNB), any(), any(), isNull())).willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildpackReference reference = BuildpackReference.of("urn:cnb:builder:example/buildpack@1.2.3");
 		BuildRequest request = getTestRequest().withBuildpacks(reference);
@@ -548,12 +503,9 @@ void logsWarningIfBindingWithSensitiveTargetIsDetected() throws IOException {
 		DockerApi docker = mockDockerApi();
 		Image builderImage = loadImage("image.json");
 		Image runImage = loadImage("run-image.json");
-		given(docker.image()
-			.pull(eq(ImageReference.of(BuildRequest.DEFAULT_BUILDER_IMAGE_REF)), isNull(), any(), isNull()))
+		given(docker.image().pull(eq(DEFAULT_BUILDER), isNull(), any(), isNull()))
 			.willAnswer(withPulledImage(builderImage));
-		given(docker.image()
-			.pull(eq(ImageReference.of("docker.io/cloudfoundry/run:base-cnb")), eq(ImagePlatform.from(builderImage)),
-					any(), isNull()))
+		given(docker.image().pull(eq(BASE_CNB), eq(ImagePlatform.from(builderImage)), any(), isNull()))
 			.willAnswer(withPulledImage(runImage));
 		Builder builder = new Builder(BuildLog.to(out), docker, null);
 		BuildRequest request = getTestRequest().withBindings(Binding.from("/host", "/cnb"));
@@ -611,7 +563,10 @@ private Answer<Image> withPulledImage(Image image) {
 			listener.onFinish();
 			return image;
 		};
+	}
 
+	private static String regAuthEq(DockerRegistryAuthentication authentication) {
+		return argThat(authentication.getAuthHeader()::equals);
 	}
 
 	static class TestPrintStream extends PrintStream {
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2024 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -42,7 +42,7 @@
 import org.springframework.boot.buildpack.platform.docker.DockerApi.ContainerApi;
 import org.springframework.boot.buildpack.platform.docker.DockerApi.ImageApi;
 import org.springframework.boot.buildpack.platform.docker.DockerApi.VolumeApi;
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 import org.springframework.boot.buildpack.platform.docker.configuration.ResolvedDockerHost;
 import org.springframework.boot.buildpack.platform.docker.type.Binding;
 import org.springframework.boot.buildpack.platform.docker.type.ContainerConfig;
@@ -362,7 +362,8 @@ void executeWithDockerHostAndRemoteAddressExecutesPhases(boolean trustBuilder) t
 		given(this.docker.container().create(any(), isNull(), any())).willAnswer(answerWithGeneratedContainerId());
 		given(this.docker.container().wait(any())).willReturn(ContainerStatus.of(0, null));
 		BuildRequest request = getTestRequest(trustBuilder);
-		createLifecycle(request, ResolvedDockerHost.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376")))
+		createLifecycle(request,
+				ResolvedDockerHost.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376")))
 			.execute();
 		if (trustBuilder) {
 			assertPhaseWasRun("creator", withExpectedConfig("lifecycle-creator-inherit-remote.json"));
@@ -384,7 +385,7 @@ void executeWithDockerHostAndLocalAddressExecutesPhases(boolean trustBuilder) th
 		given(this.docker.container().create(any(), isNull(), any())).willAnswer(answerWithGeneratedContainerId());
 		given(this.docker.container().wait(any())).willReturn(ContainerStatus.of(0, null));
 		BuildRequest request = getTestRequest(trustBuilder);
-		createLifecycle(request, ResolvedDockerHost.from(DockerHostConfiguration.forAddress("/var/alt.sock")))
+		createLifecycle(request, ResolvedDockerHost.from(new DockerConnectionConfiguration.Host("/var/alt.sock")))
 			.execute();
 		if (trustBuilder) {
 			assertPhaseWasRun("creator", withExpectedConfig("lifecycle-creator-inherit-local.json"));
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2021 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -26,6 +26,7 @@
  * @author Wei Jiang
  * @author Scott Frederick
  */
+@SuppressWarnings("removal")
 class DockerConfigurationTests {
 
 	@Test
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2024 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -31,8 +31,6 @@
 import org.junit.jupiter.api.condition.OS;
 import org.junit.jupiter.api.io.TempDir;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
-
 import static org.assertj.core.api.Assertions.assertThat;
 
 /**
@@ -75,17 +73,6 @@ void resolveWhenUsingDefaultContextReturnsWindowsDefault() {
 		assertThat(dockerHost.getCertificatePath()).isNull();
 	}
 
-	@Test
-	@DisabledOnOs(OS.WINDOWS)
-	void resolveWhenDockerHostAddressIsNullReturnsLinuxDefault() throws Exception {
-		this.environment.put("DOCKER_CONFIG", pathToResource("with-default-context/config.json"));
-		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress(null));
-		assertThat(dockerHost.getAddress()).isEqualTo("/var/run/docker.sock");
-		assertThat(dockerHost.isSecure()).isFalse();
-		assertThat(dockerHost.getCertificatePath()).isNull();
-	}
-
 	@Test
 	@DisabledOnOs(OS.WINDOWS)
 	void resolveWhenUsingDefaultContextReturnsLinuxDefault() {
@@ -100,7 +87,7 @@ void resolveWhenUsingDefaultContextReturnsLinuxDefault() {
 	void resolveWhenDockerHostAddressIsLocalReturnsAddress(@TempDir Path tempDir) throws IOException {
 		String socketFilePath = Files.createTempFile(tempDir, "remote-transport", null).toAbsolutePath().toString();
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress(socketFilePath));
+				new DockerConnectionConfiguration.Host(socketFilePath));
 		assertThat(dockerHost.isLocalFileReference()).isTrue();
 		assertThat(dockerHost.isRemote()).isFalse();
 		assertThat(dockerHost.getAddress()).isEqualTo(socketFilePath);
@@ -112,7 +99,7 @@ void resolveWhenDockerHostAddressIsLocalReturnsAddress(@TempDir Path tempDir) th
 	void resolveWhenDockerHostAddressIsLocalWithSchemeReturnsAddress(@TempDir Path tempDir) throws IOException {
 		String socketFilePath = Files.createTempFile(tempDir, "remote-transport", null).toAbsolutePath().toString();
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("unix://" + socketFilePath));
+				new DockerConnectionConfiguration.Host("unix://" + socketFilePath));
 		assertThat(dockerHost.isLocalFileReference()).isTrue();
 		assertThat(dockerHost.isRemote()).isFalse();
 		assertThat(dockerHost.getAddress()).isEqualTo(socketFilePath);
@@ -123,7 +110,7 @@ void resolveWhenDockerHostAddressIsLocalWithSchemeReturnsAddress(@TempDir Path t
 	@Test
 	void resolveWhenDockerHostAddressIsHttpReturnsAddress() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("http://docker.example.com"));
+				new DockerConnectionConfiguration.Host("http://docker.example.com"));
 		assertThat(dockerHost.isLocalFileReference()).isFalse();
 		assertThat(dockerHost.isRemote()).isTrue();
 		assertThat(dockerHost.getAddress()).isEqualTo("http://docker.example.com");
@@ -134,7 +121,7 @@ void resolveWhenDockerHostAddressIsHttpReturnsAddress() {
 	@Test
 	void resolveWhenDockerHostAddressIsHttpsReturnsAddress() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("https://docker.example.com", true, "/cert-path"));
+				new DockerConnectionConfiguration.Host("https://docker.example.com", true, "/cert-path"));
 		assertThat(dockerHost.isLocalFileReference()).isFalse();
 		assertThat(dockerHost.isRemote()).isTrue();
 		assertThat(dockerHost.getAddress()).isEqualTo("https://docker.example.com");
@@ -145,7 +132,7 @@ void resolveWhenDockerHostAddressIsHttpsReturnsAddress() {
 	@Test
 	void resolveWhenDockerHostAddressIsTcpReturnsAddress() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("tcp://192.168.99.100:2376", true, "/cert-path"));
+				new DockerConnectionConfiguration.Host("tcp://192.168.99.100:2376", true, "/cert-path"));
 		assertThat(dockerHost.isLocalFileReference()).isFalse();
 		assertThat(dockerHost.isRemote()).isTrue();
 		assertThat(dockerHost.getAddress()).isEqualTo("tcp://192.168.99.100:2376");
@@ -158,7 +145,7 @@ void resolveWhenEnvironmentAddressIsLocalReturnsAddress(@TempDir Path tempDir) t
 		String socketFilePath = Files.createTempFile(tempDir, "remote-transport", null).toAbsolutePath().toString();
 		this.environment.put("DOCKER_HOST", socketFilePath);
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("/unused"));
+				new DockerConnectionConfiguration.Host("/unused"));
 		assertThat(dockerHost.isLocalFileReference()).isTrue();
 		assertThat(dockerHost.isRemote()).isFalse();
 		assertThat(dockerHost.getAddress()).isEqualTo(socketFilePath);
@@ -171,7 +158,7 @@ void resolveWhenEnvironmentAddressIsLocalWithSchemeReturnsAddress(@TempDir Path
 		String socketFilePath = Files.createTempFile(tempDir, "remote-transport", null).toAbsolutePath().toString();
 		this.environment.put("DOCKER_HOST", "unix://" + socketFilePath);
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("/unused"));
+				new DockerConnectionConfiguration.Host("/unused"));
 		assertThat(dockerHost.isLocalFileReference()).isTrue();
 		assertThat(dockerHost.isRemote()).isFalse();
 		assertThat(dockerHost.getAddress()).isEqualTo(socketFilePath);
@@ -185,7 +172,7 @@ void resolveWhenEnvironmentAddressIsTcpReturnsAddress() {
 		this.environment.put("DOCKER_TLS_VERIFY", "1");
 		this.environment.put("DOCKER_CERT_PATH", "/cert-path");
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forAddress("tcp://1.1.1.1"));
+				new DockerConnectionConfiguration.Host("tcp://1.1.1.1"));
 		assertThat(dockerHost.isLocalFileReference()).isFalse();
 		assertThat(dockerHost.isRemote()).isTrue();
 		assertThat(dockerHost.getAddress()).isEqualTo("tcp://192.168.99.100:2376");
@@ -197,7 +184,7 @@ void resolveWhenEnvironmentAddressIsTcpReturnsAddress() {
 	void resolveWithDockerHostContextReturnsAddress() throws Exception {
 		this.environment.put("DOCKER_CONFIG", pathToResource("with-default-context/config.json"));
 		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(this.environment::get,
-				DockerHostConfiguration.forContext("test-context"));
+				new DockerConnectionConfiguration.Context("test-context"));
 		assertThat(dockerHost.getAddress()).isEqualTo("/home/user/.docker/docker.sock");
 		assertThat(dockerHost.isSecure()).isTrue();
 		assertThat(dockerHost.getCertificatePath()).isNotNull();
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2023 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -23,7 +23,7 @@
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.api.io.TempDir;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 
 import static org.assertj.core.api.Assertions.assertThat;
 
@@ -37,21 +37,21 @@ class HttpTransportTests {
 
 	@Test
 	void createWhenDockerHostVariableIsAddressReturnsRemote() {
-		HttpTransport transport = HttpTransport.create(DockerHostConfiguration.forAddress("tcp://192.168.1.0"));
+		HttpTransport transport = HttpTransport.create(new DockerConnectionConfiguration.Host("tcp://192.168.1.0"));
 		assertThat(transport).isInstanceOf(RemoteHttpClientTransport.class);
 	}
 
 	@Test
 	void createWhenDockerHostVariableIsFileReturnsLocal(@TempDir Path tempDir) throws IOException {
 		String dummySocketFilePath = Files.createTempFile(tempDir, "http-transport", null).toAbsolutePath().toString();
-		HttpTransport transport = HttpTransport.create(DockerHostConfiguration.forAddress(dummySocketFilePath));
+		HttpTransport transport = HttpTransport.create(new DockerConnectionConfiguration.Host(dummySocketFilePath));
 		assertThat(transport).isInstanceOf(LocalHttpClientTransport.class);
 	}
 
 	@Test
 	void createWhenDockerHostVariableIsUnixSchemePrefixedFileReturnsLocal(@TempDir Path tempDir) throws IOException {
 		String dummySocketFilePath = "unix://" + Files.createTempFile(tempDir, "http-transport", null).toAbsolutePath();
-		HttpTransport transport = HttpTransport.create(DockerHostConfiguration.forAddress(dummySocketFilePath));
+		HttpTransport transport = HttpTransport.create(new DockerConnectionConfiguration.Host(dummySocketFilePath));
 		assertThat(transport).isInstanceOf(LocalHttpClientTransport.class);
 	}
 
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2023 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -24,7 +24,7 @@
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.api.io.TempDir;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 import org.springframework.boot.buildpack.platform.docker.configuration.ResolvedDockerHost;
 
 import static org.assertj.core.api.Assertions.assertThat;
@@ -39,7 +39,7 @@ class LocalHttpClientTransportTests {
 	@Test
 	void createWhenDockerHostIsFileReturnsTransport(@TempDir Path tempDir) throws IOException {
 		String socketFilePath = Files.createTempFile(tempDir, "remote-transport", null).toAbsolutePath().toString();
-		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(DockerHostConfiguration.forAddress(socketFilePath));
+		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(new DockerConnectionConfiguration.Host(socketFilePath));
 		LocalHttpClientTransport transport = LocalHttpClientTransport.create(dockerHost);
 		assertThat(transport).isNotNull();
 		assertThat(transport.getHost().toHostString()).isEqualTo(socketFilePath);
@@ -48,7 +48,7 @@ void createWhenDockerHostIsFileReturnsTransport(@TempDir Path tempDir) throws IO
 	@Test
 	void createWhenDockerHostIsFileThatDoesNotExistReturnsTransport(@TempDir Path tempDir) {
 		String socketFilePath = Paths.get(tempDir.toString(), "dummy").toAbsolutePath().toString();
-		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(DockerHostConfiguration.forAddress(socketFilePath));
+		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(new DockerConnectionConfiguration.Host(socketFilePath));
 		LocalHttpClientTransport transport = LocalHttpClientTransport.create(dockerHost);
 		assertThat(transport).isNotNull();
 		assertThat(transport.getHost().toHostString()).isEqualTo(socketFilePath);
@@ -57,7 +57,7 @@ void createWhenDockerHostIsFileThatDoesNotExistReturnsTransport(@TempDir Path te
 	@Test
 	void createWhenDockerHostIsAddressReturnsTransport() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376"));
+			.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376"));
 		LocalHttpClientTransport transport = LocalHttpClientTransport.create(dockerHost);
 		assertThat(transport).isNotNull();
 		assertThat(transport.getHost().toHostString()).isEqualTo("tcp://192.168.1.2:2376");
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java
@@ -23,7 +23,7 @@
 import org.apache.hc.core5.http.HttpHost;
 import org.junit.jupiter.api.Test;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 import org.springframework.boot.buildpack.platform.docker.configuration.ResolvedDockerHost;
 import org.springframework.boot.buildpack.platform.docker.ssl.SslContextFactory;
 
@@ -42,38 +42,31 @@ class RemoteHttpClientTransportTests {
 
 	@Test
 	void createIfPossibleWhenDockerHostIsNotSetReturnsNull() {
-		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(null);
-		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost);
-		assertThat(transport).isNull();
-	}
-
-	@Test
-	void createIfPossibleWhenDockerHostIsDefaultReturnsNull() {
-		ResolvedDockerHost dockerHost = ResolvedDockerHost.from(DockerHostConfiguration.forAddress(null));
+		ResolvedDockerHost dockerHost = ResolvedDockerHost.from((DockerConnectionConfiguration) null);
 		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost);
 		assertThat(transport).isNull();
 	}
 
 	@Test
 	void createIfPossibleWhenDockerHostIsFileReturnsNull() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("unix:///var/run/socket.sock"));
+			.from(new DockerConnectionConfiguration.Host("unix:///var/run/socket.sock"));
 		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost);
 		assertThat(transport).isNull();
 	}
 
 	@Test
 	void createIfPossibleWhenDockerHostIsAddressReturnsTransport() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376"));
+			.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376"));
 		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost);
 		assertThat(transport).isNotNull();
 	}
 
 	@Test
 	void createIfPossibleWhenNoTlsVerifyUsesHttp() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376"));
+			.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376"));
 		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost);
 		assertThat(transport.getHost()).satisfies(hostOf("http", "192.168.1.2", 2376));
 	}
@@ -83,15 +76,15 @@ void createIfPossibleWhenTlsVerifyUsesHttps() throws Exception {
 		SslContextFactory sslContextFactory = mock(SslContextFactory.class);
 		given(sslContextFactory.forDirectory("/test-cert-path")).willReturn(SSLContext.getDefault());
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376", true, "/test-cert-path"));
+			.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376", true, "/test-cert-path"));
 		RemoteHttpClientTransport transport = RemoteHttpClientTransport.createIfPossible(dockerHost, sslContextFactory);
 		assertThat(transport.getHost()).satisfies(hostOf("https", "192.168.1.2", 2376));
 	}
 
 	@Test
 	void createIfPossibleWhenTlsVerifyWithMissingCertPathThrowsException() {
 		ResolvedDockerHost dockerHost = ResolvedDockerHost
-			.from(DockerHostConfiguration.forAddress("tcp://192.168.1.2:2376", true, null));
+			.from(new DockerConnectionConfiguration.Host("tcp://192.168.1.2:2376", true, null));
 		assertThatIllegalStateException().isThrownBy(() -> RemoteHttpClientTransport.createIfPossible(dockerHost))
 			.withMessageContaining("Docker host TLS verification requires trust material");
 	}
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java b/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2023 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -24,8 +24,8 @@
 import org.junit.jupiter.api.Test;
 import org.junit.jupiter.api.io.TempDir;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration;
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.build.BuilderDockerConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 import org.springframework.boot.gradle.junit.GradleProjectBuilder;
 
 import static org.assertj.core.api.Assertions.assertThat;
@@ -52,10 +52,10 @@ void prepareDockerSpec(@TempDir File temp) {
 
 	@Test
 	void asDockerConfigurationWithDefaults() {
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		assertThat(dockerConfiguration.getHost()).isNull();
-		assertThat(dockerConfiguration.getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		assertThat(dockerConfiguration.connection()).isNull();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -67,15 +67,14 @@ void asDockerConfigurationWithHostConfiguration() {
 		this.dockerSpec.getHost().set("docker.example.com");
 		this.dockerSpec.getTlsVerify().set(true);
 		this.dockerSpec.getCertPath().set("/tmp/ca-cert");
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getAddress()).isEqualTo("docker.example.com");
-		assertThat(host.isSecure()).isTrue();
-		assertThat(host.getCertificatePath()).isEqualTo("/tmp/ca-cert");
-		assertThat(host.getContext()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isFalse();
-		assertThat(this.dockerSpec.asDockerConfiguration().getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		DockerConnectionConfiguration.Host host = (DockerConnectionConfiguration.Host) dockerConfiguration.connection();
+		assertThat(host.address()).isEqualTo("docker.example.com");
+		assertThat(host.secure()).isTrue();
+		assertThat(host.certificatePath()).isEqualTo("/tmp/ca-cert");
+		assertThat(dockerConfiguration.bindHostToBuilder()).isFalse();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -85,15 +84,14 @@ void asDockerConfigurationWithHostConfiguration() {
 	@Test
 	void asDockerConfigurationWithHostConfigurationNoTlsVerify() {
 		this.dockerSpec.getHost().set("docker.example.com");
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getAddress()).isEqualTo("docker.example.com");
-		assertThat(host.isSecure()).isFalse();
-		assertThat(host.getCertificatePath()).isNull();
-		assertThat(host.getContext()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isFalse();
-		assertThat(this.dockerSpec.asDockerConfiguration().getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		DockerConnectionConfiguration.Host host = (DockerConnectionConfiguration.Host) dockerConfiguration.connection();
+		assertThat(host.address()).isEqualTo("docker.example.com");
+		assertThat(host.secure()).isFalse();
+		assertThat(host.certificatePath()).isNull();
+		assertThat(dockerConfiguration.bindHostToBuilder()).isFalse();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -103,15 +101,13 @@ void asDockerConfigurationWithHostConfigurationNoTlsVerify() {
 	@Test
 	void asDockerConfigurationWithContextConfiguration() {
 		this.dockerSpec.getContext().set("test-context");
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getContext()).isEqualTo("test-context");
-		assertThat(host.getAddress()).isNull();
-		assertThat(host.isSecure()).isFalse();
-		assertThat(host.getCertificatePath()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isFalse();
-		assertThat(this.dockerSpec.asDockerConfiguration().getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		DockerConnectionConfiguration.Context host = (DockerConnectionConfiguration.Context) dockerConfiguration
+			.connection();
+		assertThat(host.context()).isEqualTo("test-context");
+		assertThat(dockerConfiguration.bindHostToBuilder()).isFalse();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -130,14 +126,14 @@ void asDockerConfigurationWithHostAndContextFails() {
 	void asDockerConfigurationWithBindHostToBuilder() {
 		this.dockerSpec.getHost().set("docker.example.com");
 		this.dockerSpec.getBindHostToBuilder().set(true);
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getAddress()).isEqualTo("docker.example.com");
-		assertThat(host.isSecure()).isFalse();
-		assertThat(host.getCertificatePath()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isTrue();
-		assertThat(this.dockerSpec.asDockerConfiguration().getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		DockerConnectionConfiguration.Host host = (DockerConnectionConfiguration.Host) dockerConfiguration.connection();
+		assertThat(host.address()).isEqualTo("docker.example.com");
+		assertThat(host.secure()).isFalse();
+		assertThat(host.certificatePath()).isNull();
+		assertThat(dockerConfiguration.bindHostToBuilder()).isTrue();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -158,18 +154,18 @@ void asDockerConfigurationWithUserAuth() {
 			registry.getUrl().set("https://docker2.example.com");
 			registry.getEmail().set("docker2@example.com");
 		});
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		assertThat(decoded(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		assertThat(decoded(dockerConfiguration.builderRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"user1\"")
 			.contains("\"password\" : \"secret1\"")
 			.contains("\"email\" : \"docker1@example.com\"")
 			.contains("\"serveraddress\" : \"https://docker1.example.com\"");
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"user2\"")
 			.contains("\"password\" : \"secret2\"")
 			.contains("\"email\" : \"docker2@example.com\"")
 			.contains("\"serveraddress\" : \"https://docker2.example.com\"");
-		assertThat(this.dockerSpec.asDockerConfiguration().getHost()).isNull();
+		assertThat(dockerConfiguration.connection()).isNull();
 	}
 
 	@Test
@@ -198,10 +194,10 @@ void asDockerConfigurationWithIncompletePublishUserAuthFails() {
 	void asDockerConfigurationWithTokenAuth() {
 		this.dockerSpec.builderRegistry((registry) -> registry.getToken().set("token1"));
 		this.dockerSpec.publishRegistry((registry) -> registry.getToken().set("token2"));
-		DockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
-		assertThat(decoded(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = this.dockerSpec.asDockerConfiguration();
+		assertThat(decoded(dockerConfiguration.builderRegistryAuthentication().getAuthHeader()))
 			.contains("\"identitytoken\" : \"token1\"");
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"identitytoken\" : \"token2\"");
 	}
 
diff --git a/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java b/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java
--- a/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java
+++ b/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java
@@ -1,5 +1,5 @@
 /*
- * Copyright 2012-2024 the original author or authors.
+ * Copyright 2012-2025 the original author or authors.
  *
  * Licensed under the Apache License, Version 2.0 (the "License");
  * you may not use this file except in compliance with the License.
@@ -20,8 +20,8 @@
 
 import org.junit.jupiter.api.Test;
 
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration;
-import org.springframework.boot.buildpack.platform.docker.configuration.DockerConfiguration.DockerHostConfiguration;
+import org.springframework.boot.buildpack.platform.build.BuilderDockerConfiguration;
+import org.springframework.boot.buildpack.platform.docker.configuration.DockerConnectionConfiguration;
 
 import static org.assertj.core.api.Assertions.assertThat;
 import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;
@@ -37,10 +37,10 @@ class DockerTests {
 	@Test
 	void asDockerConfigurationWithDefaults() {
 		Docker docker = new Docker();
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		assertThat(dockerConfiguration.getHost()).isNull();
-		assertThat(dockerConfiguration.getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		assertThat(dockerConfiguration.connection()).isNull();
+		assertThat(dockerConfiguration.builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -53,15 +53,14 @@ void asDockerConfigurationWithHostConfiguration() {
 		docker.setHost("docker.example.com");
 		docker.setTlsVerify(true);
 		docker.setCertPath("/tmp/ca-cert");
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getAddress()).isEqualTo("docker.example.com");
-		assertThat(host.isSecure()).isTrue();
-		assertThat(host.getCertificatePath()).isEqualTo("/tmp/ca-cert");
-		assertThat(host.getContext()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isFalse();
-		assertThat(createDockerConfiguration(docker).getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		DockerConnectionConfiguration.Host host = (DockerConnectionConfiguration.Host) dockerConfiguration.connection();
+		assertThat(host.address()).isEqualTo("docker.example.com");
+		assertThat(host.secure()).isTrue();
+		assertThat(host.certificatePath()).isEqualTo("/tmp/ca-cert");
+		assertThat(dockerConfiguration.bindHostToBuilder()).isFalse();
+		assertThat(createDockerConfiguration(docker).builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -72,15 +71,13 @@ void asDockerConfigurationWithHostConfiguration() {
 	void asDockerConfigurationWithContextConfiguration() {
 		Docker docker = new Docker();
 		docker.setContext("test-context");
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getContext()).isEqualTo("test-context");
-		assertThat(host.getAddress()).isNull();
-		assertThat(host.isSecure()).isFalse();
-		assertThat(host.getCertificatePath()).isNull();
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isFalse();
-		assertThat(createDockerConfiguration(docker).getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		DockerConnectionConfiguration.Context context = (DockerConnectionConfiguration.Context) dockerConfiguration
+			.connection();
+		assertThat(context.context()).isEqualTo("test-context");
+		assertThat(dockerConfiguration.bindHostToBuilder()).isFalse();
+		assertThat(createDockerConfiguration(docker).builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -103,14 +100,14 @@ void asDockerConfigurationWithBindHostToBuilder() {
 		docker.setTlsVerify(true);
 		docker.setCertPath("/tmp/ca-cert");
 		docker.setBindHostToBuilder(true);
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		DockerHostConfiguration host = dockerConfiguration.getHost();
-		assertThat(host.getAddress()).isEqualTo("docker.example.com");
-		assertThat(host.isSecure()).isTrue();
-		assertThat(host.getCertificatePath()).isEqualTo("/tmp/ca-cert");
-		assertThat(dockerConfiguration.isBindHostToBuilder()).isTrue();
-		assertThat(createDockerConfiguration(docker).getBuilderRegistryAuthentication()).isNull();
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		DockerConnectionConfiguration.Host host = (DockerConnectionConfiguration.Host) dockerConfiguration.connection();
+		assertThat(host.address()).isEqualTo("docker.example.com");
+		assertThat(host.secure()).isTrue();
+		assertThat(host.certificatePath()).isEqualTo("/tmp/ca-cert");
+		assertThat(dockerConfiguration.bindHostToBuilder()).isTrue();
+		assertThat(createDockerConfiguration(docker).builderRegistryAuthentication()).isNull();
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"\"")
 			.contains("\"password\" : \"\"")
 			.contains("\"email\" : \"\"")
@@ -124,13 +121,13 @@ void asDockerConfigurationWithUserAuth() {
 				new Docker.DockerRegistry("user1", "secret1", "https://docker1.example.com", "docker1@example.com"));
 		docker.setPublishRegistry(
 				new Docker.DockerRegistry("user2", "secret2", "https://docker2.example.com", "docker2@example.com"));
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		assertThat(decoded(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		assertThat(decoded(dockerConfiguration.builderRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"user1\"")
 			.contains("\"password\" : \"secret1\"")
 			.contains("\"email\" : \"docker1@example.com\"")
 			.contains("\"serveraddress\" : \"https://docker1.example.com\"");
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"username\" : \"user2\"")
 			.contains("\"password\" : \"secret2\"")
 			.contains("\"email\" : \"docker2@example.com\"")
@@ -160,19 +157,19 @@ void asDockerConfigurationWithIncompletePublishUserAuthDoesNotFailIfPublishIsDis
 		Docker docker = new Docker();
 		docker.setPublishRegistry(
 				new Docker.DockerRegistry("user", null, "https://docker.example.com", "docker@example.com"));
-		DockerConfiguration dockerConfiguration = docker.asDockerConfiguration(false);
-		assertThat(dockerConfiguration.getPublishRegistryAuthentication()).isNull();
+		BuilderDockerConfiguration dockerConfiguration = docker.asDockerConfiguration(false);
+		assertThat(dockerConfiguration.publishRegistryAuthentication()).isNull();
 	}
 
 	@Test
 	void asDockerConfigurationWithTokenAuth() {
 		Docker docker = new Docker();
 		docker.setBuilderRegistry(new Docker.DockerRegistry("token1"));
 		docker.setPublishRegistry(new Docker.DockerRegistry("token2"));
-		DockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
-		assertThat(decoded(dockerConfiguration.getBuilderRegistryAuthentication().getAuthHeader()))
+		BuilderDockerConfiguration dockerConfiguration = createDockerConfiguration(docker);
+		assertThat(decoded(dockerConfiguration.builderRegistryAuthentication().getAuthHeader()))
 			.contains("\"identitytoken\" : \"token1\"");
-		assertThat(decoded(dockerConfiguration.getPublishRegistryAuthentication().getAuthHeader()))
+		assertThat(decoded(dockerConfiguration.publishRegistryAuthentication().getAuthHeader()))
 			.contains("\"identitytoken\" : \"token2\"");
 	}
 
@@ -196,13 +193,12 @@ void asDockerConfigurationWithUserAndTokenAuthDoesNotFailIfPublishingIsDisabled(
 		dockerRegistry.setToken("token");
 		Docker docker = new Docker();
 		docker.setPublishRegistry(dockerRegistry);
-		DockerConfiguration dockerConfiguration = docker.asDockerConfiguration(false);
-		assertThat(dockerConfiguration.getPublishRegistryAuthentication()).isNull();
+		BuilderDockerConfiguration dockerConfiguration = docker.asDockerConfiguration(false);
+		assertThat(dockerConfiguration.publishRegistryAuthentication()).isNull();
 	}
 
-	private DockerConfiguration createDockerConfiguration(Docker docker) {
+	private BuilderDockerConfiguration createDockerConfiguration(Docker docker) {
 		return docker.asDockerConfiguration(true);
-
 	}
 
 	String decoded(String value) {
EOF_114329324912

# Ensure gradlew is executable
chmod +x /testbed/gradlew

# Clean previous test results to ensure fresh run
rm -rf /testbed/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/build/test-results/
rm -rf /testbed/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/build/test-results/
rm -rf /testbed/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/build/test-results/

# Run tests for spring-boot-buildpack-platform module
echo "=========================================="
echo "Running spring-boot-buildpack-platform tests..."
echo "=========================================="
./gradlew :spring-boot-project:spring-boot-tools:spring-boot-buildpack-platform:test \
    --tests org.springframework.boot.buildpack.platform.build.BuilderTests \
    --tests org.springframework.boot.buildpack.platform.build.LifecycleTests \
    --tests org.springframework.boot.buildpack.platform.docker.configuration.DockerConfigurationTests \
    --tests org.springframework.boot.buildpack.platform.docker.configuration.ResolvedDockerHostTests \
    --tests org.springframework.boot.buildpack.platform.docker.transport.HttpTransportTests \
    --tests org.springframework.boot.buildpack.platform.docker.transport.LocalHttpClientTransportTests \
    --tests org.springframework.boot.buildpack.platform.docker.transport.RemoteHttpClientTransportTests \
    --no-daemon --console=plain --rerun-tasks

rc1=$?

# Run tests for spring-boot-gradle-plugin module
echo "=========================================="
echo "Running spring-boot-gradle-plugin tests..."
echo "=========================================="
./gradlew :spring-boot-project:spring-boot-tools:spring-boot-gradle-plugin:test \
    --tests org.springframework.boot.gradle.tasks.bundling.DockerSpecTests \
    --no-daemon --console=plain --rerun-tasks

rc2=$?

# Run tests for spring-boot-maven-plugin module
echo "=========================================="
echo "Running spring-boot-maven-plugin tests..."
echo "=========================================="
./gradlew :spring-boot-project:spring-boot-tools:spring-boot-maven-plugin:test \
    --tests org.springframework.boot.maven.DockerTests \
    --no-daemon --console=plain --rerun-tasks

rc3=$?

# Combine exit codes - if any test fails, overall should fail
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ] || [ $rc3 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Display test results summary
echo "=========================================="
echo "Test Execution Complete"
echo "spring-boot-buildpack-platform Exit Code: $rc1"
echo "spring-boot-gradle-plugin Exit Code: $rc2"
echo "spring-boot-maven-plugin Exit Code: $rc3"
echo "Overall Exit Code: $rc"
echo "=========================================="

# Check and display test result files for buildpack-platform
echo "=========================================="
echo "Checking buildpack-platform test results..."
echo "=========================================="
if [ -d "/testbed/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/build/test-results/test/" ]; then
    for xml_file in /testbed/spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/build/test-results/test/*.xml; do
        if [ -f "$xml_file" ]; then
            echo "Content of $xml_file:"
            cat "$xml_file"
            echo ""
        fi
    done
fi

# Check and display test result files for gradle-plugin
echo "=========================================="
echo "Checking gradle-plugin test results..."
echo "=========================================="
if [ -d "/testbed/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/build/test-results/test/" ]; then
    for xml_file in /testbed/spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/build/test-results/test/*.xml; do
        if [ -f "$xml_file" ]; then
            echo "Content of $xml_file:"
            cat "$xml_file"
            echo ""
        fi
    done
fi

# Check and display test result files for maven-plugin
echo "=========================================="
echo "Checking maven-plugin test results..."
echo "=========================================="
if [ -d "/testbed/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/build/test-results/test/" ]; then
    for xml_file in /testbed/spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/build/test-results/test/*.xml; do
        if [ -f "$xml_file" ]; then
            echo "Content of $xml_file:"
            cat "$xml_file"
            echo ""
        fi
    done
fi

# Echo exit code for judge
echo "=========================================="
echo "OMNIGRIL_EXIT_CODE=$rc"
echo "=========================================="

# Restore original test files
git checkout 0351e33b18e7235fe040ae6b131cd9b1ac951659 \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/BuilderTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/build/LifecycleTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/DockerConfigurationTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/configuration/ResolvedDockerHostTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/HttpTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/LocalHttpClientTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-buildpack-platform/src/test/java/org/springframework/boot/buildpack/platform/docker/transport/RemoteHttpClientTransportTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-gradle-plugin/src/test/java/org/springframework/boot/gradle/tasks/bundling/DockerSpecTests.java" \
    "spring-boot-project/spring-boot-tools/spring-boot-maven-plugin/src/test/java/org/springframework/boot/maven/DockerTests.java"