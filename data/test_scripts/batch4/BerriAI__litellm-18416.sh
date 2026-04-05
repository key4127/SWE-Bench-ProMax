#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 8a3d4967edc3f428ebca80433cf854061a4fbc7e "ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts" "ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx" "ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx" "ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx" "ui/litellm-dashboard/tests/setupTests.ts"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts b/ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts
--- a/ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts
+++ b/ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts
@@ -5,6 +5,9 @@ import { afterEach, describe, expect, it, vi } from "vitest";
 import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
 import useAuthorized from "./useAuthorized";
 
+// Unmock useAuthorized to test the actual implementation
+vi.unmock("@/app/(dashboard)/hooks/useAuthorized");
+
 const { replaceMock, clearTokenCookiesMock, getProxyBaseUrlMock, getUiConfigMock } = vi.hoisted(() => ({
   replaceMock: vi.fn(),
   clearTokenCookiesMock: vi.fn(),
diff --git a/ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx b/ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx
--- a/ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx
+++ b/ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx
@@ -37,19 +37,6 @@ vi.mock("@/app/(dashboard)/models-and-endpoints/components/ModelAnalyticsTab/Mod
   default: () => null,
 }));
 
-vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
-  default: () => ({
-    token: "123",
-    accessToken: "123",
-    userId: "user-1",
-    userEmail: "user@example.com",
-    userRole: "Admin",
-    premiumUser: false,
-    disabledPersonalKeyCreation: null,
-    showSSOBanner: false,
-  }),
-}));
-
 vi.mock("@/app/(dashboard)/hooks/useTeams", () => ({
   default: () => ({
     teams: [],
diff --git a/ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx b/ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx
--- a/ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx
+++ b/ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx
@@ -71,7 +71,9 @@ describe("MCPToolPermissions", () => {
     });
 
     // Verify API calls
-    expect(networking.fetchMCPServers).toHaveBeenCalledWith(mockAccessToken);
+    // Note: useMCPServers uses useAuthorized() internally, which returns "123" from global mock
+    expect(networking.fetchMCPServers).toHaveBeenCalledWith("123");
+    // listMCPTools uses the accessToken prop directly
     expect(networking.listMCPTools).toHaveBeenCalledWith(mockAccessToken, mockServerId);
   });
 
diff --git a/ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx b/ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx
--- a/ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx
+++ b/ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx
@@ -32,7 +32,7 @@ const createQueryClient = () =>
 
 describe("MCPServers", () => {
   const defaultProps = {
-    accessToken: "test-token",
+    accessToken: "123",
     userRole: "Admin",
     userID: "admin-user-id",
   };
@@ -120,6 +120,7 @@ describe("MCPServers", () => {
     expect(getByText("test-server-2")).toBeInTheDocument();
 
     // Verify the API was called
-    expect(networking.fetchMCPServers).toHaveBeenCalledWith("test-token");
+    // Note: useMCPServers uses useAuthorized() internally, which returns "123" from global mock
+    expect(networking.fetchMCPServers).toHaveBeenCalledWith("123");
   });
 });
diff --git a/ui/litellm-dashboard/tests/setupTests.ts b/ui/litellm-dashboard/tests/setupTests.ts
--- a/ui/litellm-dashboard/tests/setupTests.ts
+++ b/ui/litellm-dashboard/tests/setupTests.ts
@@ -33,6 +33,20 @@ vi.mock("@tremor/react", async (importOriginal) => {
   };
 });
 
+// Global mock for useAuthorized hook to avoid repeating the same mock in every test file
+vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
+  default: () => ({
+    token: "123",
+    accessToken: "123",
+    userId: "user-1",
+    userEmail: "user@example.com",
+    userRole: "Admin",
+    premiumUser: false,
+    disabledPersonalKeyCreation: null,
+    showSSOBanner: false,
+  }),
+}));
+
 afterEach(() => {
   cleanup();
 });
EOF_114329324912

# Navigate to the UI dashboard directory
cd /testbed/ui/litellm-dashboard/

# Run the specific test files using vitest
# Using npx vitest run to execute tests in non-watch mode
# Passing all test files in a single command for efficiency
npx vitest run \
  src/app/\(dashboard\)/hooks/useAuthorized.test.ts \
  src/app/\(dashboard\)/models-and-endpoints/ModelsAndEndpointsView.test.tsx \
  src/components/mcp_server_management/MCPToolPermissions.test.tsx \
  src/components/mcp_tools/mcp_servers.test.tsx

# Capture exit code
rc=$?

# Echo exit code for test result evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
cd /testbed
git checkout 8a3d4967edc3f428ebca80433cf854061a4fbc7e "ui/litellm-dashboard/src/app/(dashboard)/hooks/useAuthorized.test.ts" "ui/litellm-dashboard/src/app/(dashboard)/models-and-endpoints/ModelsAndEndpointsView.test.tsx" "ui/litellm-dashboard/src/components/mcp_server_management/MCPToolPermissions.test.tsx" "ui/litellm-dashboard/src/components/mcp_tools/mcp_servers.test.tsx" "ui/litellm-dashboard/tests/setupTests.ts"