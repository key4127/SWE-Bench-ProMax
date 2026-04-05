#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout add6f22a6e417b7533edf4543172bd01ea37cd44 "hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java b/hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java
--- a/hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java
+++ b/hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java
@@ -20,6 +20,7 @@
 import static org.junit.Assert.assertEquals;
 import static org.junit.Assert.assertFalse;
 import static org.junit.Assert.assertNotEquals;
+import static org.junit.Assert.assertSame;
 import static org.junit.Assert.assertTrue;
 import static org.junit.Assert.fail;
 
@@ -30,6 +31,8 @@
 import java.net.URI;
 import java.security.PrivilegedExceptionAction;
 import java.util.Properties;
+import java.util.regex.Matcher;
+import java.util.regex.Pattern;
 import javax.net.ssl.SSLException;
 import javax.servlet.http.HttpServletResponse;
 import org.apache.commons.io.FileUtils;
@@ -44,6 +47,7 @@
 import org.apache.hadoop.hbase.http.HttpServer;
 import org.apache.hadoop.hbase.http.log.LogLevel.CLI;
 import org.apache.hadoop.hbase.http.ssl.KeyStoreTestUtil;
+import org.apache.hadoop.hbase.logging.Log4jUtils;
 import org.apache.hadoop.hbase.testclassification.MiscTests;
 import org.apache.hadoop.hbase.testclassification.SmallTests;
 import org.apache.hadoop.hdfs.DFSConfigKeys;
@@ -89,6 +93,32 @@ public class TestLogLevel {
   private static String HTTP_PRINCIPAL = "HTTP/" + LOCALHOST;
   private static HBaseCommonTestingUtil HTU;
   private static File keyTabFile;
+  private static final Pattern EFFECTIVE_LEVEL = Pattern.compile("Effective level:\\s*(\\S+)");
+
+  @FunctionalInterface
+  private interface ThrowingRunnable {
+    void run() throws Exception;
+  }
+
+  @FunctionalInterface
+  private interface ThrowingConsumer {
+    void accept(String url) throws Exception;
+  }
+
+  private enum Protocol {
+    C_HTTP_S_HTTP(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP),
+    C_HTTP_S_HTTPS(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTPS),
+    C_HTTPS_S_HTTP(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTP),
+    C_HTTPS_S_HTTPS(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTPS);
+
+    final String client;
+    final String server;
+
+    Protocol(String client, String server) {
+      this.client = client;
+      this.server = server;
+    }
+  }
 
   @BeforeClass
   public static void setUp() throws Exception {
@@ -264,36 +294,44 @@ private HttpServer createServer(String protocol, boolean isSpnego) throws Except
     return server;
   }
 
-  private void testDynamicLogLevel(final String bindProtocol, final String connectProtocol,
-    final boolean isSpnego) throws Exception {
-    testDynamicLogLevel(bindProtocol, connectProtocol, isSpnego, logName,
-      org.apache.logging.log4j.Level.DEBUG.toString());
+  private void testGetLogLevel(Protocol protocol, boolean isSpnego, String loggerName,
+    String expectedLevel) throws Exception {
+    withLogLevelServer(protocol, isSpnego, (authority) -> {
+      final String level = getLevel(protocol.client, authority, loggerName);
+      assertEquals("Log level not equal to expected: ", expectedLevel, level);
+    });
   }
 
-  private void testDynamicLogLevel(final String bindProtocol, final String connectProtocol,
-    final boolean isSpnego, final String newLevel) throws Exception {
-    testDynamicLogLevel(bindProtocol, connectProtocol, isSpnego, logName, newLevel);
+  private void testSetLogLevel(Protocol protocol, boolean isSpnego, String loggerName,
+    String newLevel) throws Exception {
+    String oldLevel = Log4jUtils.getEffectiveLevel(loggerName);
+    assertNotEquals("New level is same as old level: ", newLevel, oldLevel);
+
+    try {
+      withLogLevelServer(protocol, isSpnego, (authority) -> {
+        setLevel(protocol.client, authority, loggerName, newLevel);
+      });
+    } finally {
+      // restore log level
+      Log4jUtils.setLogLevel(loggerName, oldLevel);
+    }
   }
 
   /**
-   * Run both client and server using the given protocol.
-   * @param bindProtocol    specify either http or https for server
-   * @param connectProtocol specify either http or https for client
-   * @param isSpnego        true if SPNEGO is enabled
-   * @throws Exception if client can't accesss server.
+   * Starts a LogLevel server and executes a client action against it.
+   * @param protocol protocol configuration for client and server
+   * @param isSpnego whether SPNEGO authentication is enabled
+   * @param consumer client action executed with the server authority (host:port)
+   * @throws Exception if server setup or client execution fails
    */
-  private void testDynamicLogLevel(final String bindProtocol, final String connectProtocol,
-    final boolean isSpnego, final String loggerName, final String newLevel) throws Exception {
-    if (!LogLevel.isValidProtocol(bindProtocol)) {
-      throw new Exception("Invalid server protocol " + bindProtocol);
+  private void withLogLevelServer(Protocol protocol, final boolean isSpnego,
+    ThrowingConsumer consumer) throws Exception {
+    if (!LogLevel.isValidProtocol(protocol.server)) {
+      throw new Exception("Invalid server protocol " + protocol.server);
     }
-    if (!LogLevel.isValidProtocol(connectProtocol)) {
-      throw new Exception("Invalid client protocol " + connectProtocol);
+    if (!LogLevel.isValidProtocol(protocol.client)) {
+      throw new Exception("Invalid client protocol " + protocol.client);
     }
-    org.apache.logging.log4j.Logger log = org.apache.logging.log4j.LogManager.getLogger(loggerName);
-    org.apache.logging.log4j.Level oldLevel = log.getLevel();
-    assertNotEquals("Get default Log Level which shouldn't be ERROR.",
-      org.apache.logging.log4j.Level.ERROR, oldLevel);
 
     // configs needed for SPNEGO at server side
     if (isSpnego) {
@@ -308,28 +346,21 @@ private void testDynamicLogLevel(final String bindProtocol, final String connect
       UserGroupInformation.setConfiguration(serverConf);
     }
 
-    final HttpServer server = createServer(bindProtocol, isSpnego);
-    // get server port
+    final HttpServer server = createServer(protocol.server, isSpnego);
     final String authority = NetUtils.getHostPortString(server.getConnectorAddress(0));
-
     String keytabFilePath = keyTabFile.getAbsolutePath();
 
     UserGroupInformation clientUGI =
       UserGroupInformation.loginUserFromKeytabAndReturnUGI(clientPrincipal, keytabFilePath);
     try {
       clientUGI.doAs((PrivilegedExceptionAction<Void>) () -> {
-        // client command line
-        getLevel(connectProtocol, authority, loggerName);
-        setLevel(connectProtocol, authority, loggerName, newLevel);
+        consumer.accept(authority);
         return null;
       });
     } finally {
       clientUGI.logoutUserFromKeytab();
       server.stop();
     }
-
-    // restore log level
-    org.apache.logging.log4j.core.config.Configurator.setLevel(log.getName(), oldLevel);
   }
 
   /**
@@ -338,10 +369,12 @@ private void testDynamicLogLevel(final String bindProtocol, final String connect
    * @param authority daemon's web UI address
    * @throws Exception if unable to connect
    */
-  private void getLevel(String protocol, String authority, String logName) throws Exception {
+  private String getLevel(String protocol, String authority, String logName) throws Exception {
     String[] getLevelArgs = { "-getlevel", authority, logName, "-protocol", protocol };
     CLI cli = new CLI(protocol.equalsIgnoreCase("https") ? sslConf : clientConf);
-    cli.run(getLevelArgs);
+    cli.parseArguments(getLevelArgs);
+    final String response = cli.fetchGetLevelResponse();
+    return extractEffectiveLevel(response);
   }
 
   /**
@@ -354,19 +387,33 @@ private void setLevel(String protocol, String authority, String logName, String
     throws Exception {
     String[] setLevelArgs = { "-setlevel", authority, logName, newLevel, "-protocol", protocol };
     CLI cli = new CLI(protocol.equalsIgnoreCase("https") ? sslConf : clientConf);
-    cli.run(setLevelArgs);
+    cli.parseArguments(setLevelArgs);
+    final String response = cli.fetchSetLevelResponse();
+    final String responseLevel = extractEffectiveLevel(response);
+    final String currentLevel = Log4jUtils.getEffectiveLevel(logName);
+    assertEquals("new level not equal to expected: ", newLevel, currentLevel);
+    assertSame("new level not equal to response level: ", newLevel, responseLevel);
+  }
 
-    org.apache.logging.log4j.Logger logger = org.apache.logging.log4j.LogManager.getLogger(logName);
+  /**
+   * Extract effective log level from server response.
+   * @param response server body response string
+   * @return the effective log level
+   */
+  private String extractEffectiveLevel(String response) {
+    Matcher m = EFFECTIVE_LEVEL.matcher(response);
+    if (m.find()) {
+      return org.apache.logging.log4j.Level.toLevel(m.group(1)).name();
+    }
 
-    assertEquals("new level not equal to expected: ", newLevel.toUpperCase(),
-      logger.getLevel().toString());
+    fail("Cannot find effective log level from response: " + response);
+    return null;
   }
 
   @Test
   public void testSettingProtectedLogLevel() throws Exception {
     try {
-      testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP, true, protectedLogName,
-        "DEBUG");
+      testSetLogLevel(Protocol.C_HTTP_S_HTTP, true, protectedLogName, "DEBUG");
       fail("Expected IO exception due to protected logger");
     } catch (IOException e) {
       assertTrue(e.getMessage().contains("" + HttpServletResponse.SC_PRECONDITION_FAILED));
@@ -375,22 +422,36 @@ public void testSettingProtectedLogLevel() throws Exception {
     }
   }
 
+  @Test
+  public void testGetDebugLogLevel() throws Exception {
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testGetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "DEBUG");
+  }
+
+  @Test
+  public void testGetInfoLogLevel() throws Exception {
+    Log4jUtils.setLogLevel(logName, "INFO");
+    testGetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "INFO");
+  }
+
   /**
    * Test setting log level to "Info".
    * @throws Exception if client can't set log level to INFO.
    */
   @Test
-  public void testInfoLogLevel() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP, true, "INFO");
+  public void testSetInfoLogLevel() throws Exception {
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testSetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "INFO");
   }
 
   /**
    * Test setting log level to "Error".
    * @throws Exception if client can't set log level to ERROR.
    */
   @Test
-  public void testErrorLogLevel() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP, true, "ERROR");
+  public void testSetErrorLogLevel() throws Exception {
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testSetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "ERROR");
   }
 
   /**
@@ -400,10 +461,11 @@ public void testErrorLogLevel() throws Exception {
    */
   @Test
   public void testLogLevelByHttp() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP, false);
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testGetLogLevel(Protocol.C_HTTP_S_HTTP, false, logName, "DEBUG");
     try {
-      testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTPS, false);
-      fail("An HTTPS Client should not have succeeded in connecting to a " + "HTTP server");
+      testGetLogLevel(Protocol.C_HTTPS_S_HTTP, false, logName, "DEBUG");
+      fail("An HTTPS Client should not have succeeded in connecting to a HTTP server");
     } catch (SSLException e) {
       exceptionShouldContains("Unrecognized SSL message", e);
     }
@@ -416,10 +478,11 @@ public void testLogLevelByHttp() throws Exception {
    */
   @Test
   public void testLogLevelByHttpWithSpnego() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTP, true);
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testGetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "DEBUG");
     try {
-      testDynamicLogLevel(LogLevel.PROTOCOL_HTTP, LogLevel.PROTOCOL_HTTPS, true);
-      fail("An HTTPS Client should not have succeeded in connecting to a " + "HTTP server");
+      testGetLogLevel(Protocol.C_HTTPS_S_HTTP, true, logName, "DEBUG");
+      fail("An HTTPS Client should not have succeeded in connecting to a HTTP server");
     } catch (SSLException e) {
       exceptionShouldContains("Unrecognized SSL message", e);
     }
@@ -432,10 +495,11 @@ public void testLogLevelByHttpWithSpnego() throws Exception {
    */
   @Test
   public void testLogLevelByHttps() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTPS, false);
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testGetLogLevel(Protocol.C_HTTPS_S_HTTPS, false, logName, "DEBUG");
     try {
-      testDynamicLogLevel(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTP, false);
-      fail("An HTTP Client should not have succeeded in connecting to a " + "HTTPS server");
+      testGetLogLevel(Protocol.C_HTTP_S_HTTPS, false, logName, "DEBUG");
+      fail("An HTTP Client should not have succeeded in connecting to a HTTPS server");
     } catch (SocketException e) {
       exceptionShouldContains("Unexpected end of file from server", e);
     }
@@ -448,15 +512,56 @@ public void testLogLevelByHttps() throws Exception {
    */
   @Test
   public void testLogLevelByHttpsWithSpnego() throws Exception {
-    testDynamicLogLevel(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTPS, true);
+    Log4jUtils.setLogLevel(logName, "DEBUG");
+    testGetLogLevel(Protocol.C_HTTPS_S_HTTPS, true, logName, "DEBUG");
     try {
-      testDynamicLogLevel(LogLevel.PROTOCOL_HTTPS, LogLevel.PROTOCOL_HTTP, true);
-      fail("An HTTP Client should not have succeeded in connecting to a " + "HTTPS server");
+      testGetLogLevel(Protocol.C_HTTP_S_HTTPS, true, logName, "DEBUG");
+      fail("An HTTP Client should not have succeeded in connecting to a HTTPS server");
     } catch (SocketException e) {
       exceptionShouldContains("Unexpected end of file from server", e);
     }
   }
 
+  /**
+   * Test getting log level in readonly mode.
+   * @throws Exception if a client can't get log level.
+   */
+  @Test
+  public void testGetLogLevelAllowedInReadonlyMode() throws Exception {
+    withMasterUIReadonly(() -> {
+      Log4jUtils.setLogLevel(logName, "DEBUG");
+      testGetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "DEBUG");
+    });
+  }
+
+  /**
+   * Test setting log level in readonly mode.
+   * @throws Exception if a client can set log level.
+   */
+  @Test
+  public void testSetLogLevelDisallowedInReadonlyMode() throws Exception {
+    withMasterUIReadonly(() -> {
+      Log4jUtils.setLogLevel(logName, "DEBUG");
+      try {
+        testSetLogLevel(Protocol.C_HTTP_S_HTTP, true, logName, "INFO");
+        fail("Setting log level should be disallowed in readonly mode.");
+      } catch (IOException e) {
+        exceptionShouldContains("Modification of HBase via the UI is disallowed in configuration.",
+          e);
+      }
+    });
+  }
+
+  private void withMasterUIReadonly(ThrowingRunnable runnable) throws Exception {
+    boolean prev = serverConf.getBoolean(LogLevel.MASTER_UI_READONLY_CONF_KEY, false);
+    serverConf.setBoolean(LogLevel.MASTER_UI_READONLY_CONF_KEY, true);
+    try {
+      runnable.run();
+    } finally {
+      serverConf.setBoolean(LogLevel.MASTER_UI_READONLY_CONF_KEY, prev);
+    }
+  }
+
   /**
    * Assert that a throwable or one of its causes should contain the substr in its message. Ideally
    * we should use {@link GenericTestUtils#assertExceptionContains(String, Throwable)} util method
EOF_114329324912

# Execute the target test using Maven
# Using single test execution with proper Maven Surefire configuration
# Disable fork reuse and use single-process mode for stability in virtualized environment
mvn test -pl hbase-http \
    -Dtest=TestLogLevel \
    -Dsurefire.reuseForks=false \
    -DforkCount=1 \
    -Dmaven.test.failure.ignore=false \
    -Dtest.build.webapps=target/test-classes/webapps \
    -Dcheckstyle.skip=true \
    -Dspotbugs.skip=true \
    -Denforcer.skip=true

# Capture exit code
rc=$?

# Echo exit code for test result evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout add6f22a6e417b7533edf4543172bd01ea37cd44 "hbase-http/src/test/java/org/apache/hadoop/hbase/http/log/TestLogLevel.java"