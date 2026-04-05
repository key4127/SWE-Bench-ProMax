#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 710ae2f1ce688f2847484b27c5a3dcb9deca0800 \
    "ui/litellm-dashboard/src/components/all_keys_table.test.tsx" \
    "ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx" \
    "ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/ui/litellm-dashboard/src/components/all_keys_table.test.tsx b/ui/litellm-dashboard/src/components/VirtualKeysPage/VirtualKeysTable.test.tsx
rename from ui/litellm-dashboard/src/components/all_keys_table.test.tsx
rename to ui/litellm-dashboard/src/components/VirtualKeysPage/VirtualKeysTable.test.tsx
--- a/ui/litellm-dashboard/src/components/all_keys_table.test.tsx
+++ b/ui/litellm-dashboard/src/components/VirtualKeysPage/VirtualKeysTable.test.tsx
@@ -1,13 +1,13 @@
 import { screen, waitFor } from "@testing-library/react";
 import { vi, it, expect } from "vitest";
-import { renderWithProviders } from "../../tests/test-utils";
-import { AllKeysTable } from "./all_keys_table";
-import { KeyResponse, Team } from "./key_team_helpers/key_list";
-import { Organization } from "./networking";
+import { renderWithProviders } from "../../../tests/test-utils";
+import { VirtualKeysTable } from "./VirtualKeysTable";
+import { KeyResponse, Team } from "../key_team_helpers/key_list";
+import { Organization } from "../networking";
 
 // Mock network calls
 vi.mock("./networking", async (importOriginal) => {
-  const actual = await importOriginal<typeof import("./networking")>();
+  const actual = await importOriginal<typeof import("../networking")>();
   return {
     ...actual,
     userListCall: vi.fn().mockResolvedValue({
@@ -131,7 +131,7 @@ const mockOrganization: Organization = {
   members: [],
 };
 
-it("should render AllKeysTable component", () => {
+it("should render VirtualKeysTable component", () => {
   const mockProps = {
     keys: [mockKey],
     setKeys: vi.fn(),
@@ -156,7 +156,7 @@ it("should render AllKeysTable component", () => {
     premiumUser: false,
   };
 
-  renderWithProviders(<AllKeysTable {...mockProps} />);
+  renderWithProviders(<VirtualKeysTable {...mockProps} />);
 
   expect(screen.getByText("Test Key Alias")).toBeInTheDocument();
 });
@@ -186,7 +186,7 @@ it("should display key information correctly", async () => {
     premiumUser: false,
   };
 
-  renderWithProviders(<AllKeysTable {...mockProps} />);
+  renderWithProviders(<VirtualKeysTable {...mockProps} />);
 
   await waitFor(() => {
     expect(screen.getByText("Test Key Alias")).toBeInTheDocument();
@@ -220,7 +220,7 @@ it("should display user email correctly", async () => {
     premiumUser: false,
   };
 
-  renderWithProviders(<AllKeysTable {...mockProps} />);
+  renderWithProviders(<VirtualKeysTable {...mockProps} />);
 
   await waitFor(() => {
     expect(screen.getByText("user@example.com")).toBeInTheDocument();
diff --git a/ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx b/ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx
--- a/ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx
+++ b/ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx
@@ -2,15 +2,21 @@ import { fireEvent, render, screen, waitFor } from "@testing-library/react";
 import { beforeEach, describe, expect, it, vi } from "vitest";
 
 // ---- Hoisted shared mocks (safe to use inside vi.mock factories) ----
-const { keyUpdateCallMock, keyDeleteCallMock } = vi.hoisted(() => {
+const { keyUpdateCallMock, keyDeleteCallMock, mockUseAuthorized } = vi.hoisted(() => {
   return {
     keyUpdateCallMock: vi.fn().mockResolvedValue({}),
     keyDeleteCallMock: vi.fn().mockResolvedValue({}),
+    mockUseAuthorized: vi.fn(),
   };
 });
 
 // ---- Module mocks ----
 
+// Mock useAuthorized hook FIRST (before component imports it)
+vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
+  default: mockUseAuthorized,
+}));
+
 // Networking: wire the hoisted fns so we can assert calls later
 vi.mock("../networking", () => {
   return {
@@ -29,12 +35,12 @@ vi.mock("../molecules/notifications_manager", () => {
   return { default: Notifications };
 });
 
-// Roles: ensure 'admin' has write access and include all role helper functions
+// Roles: ensure 'Admin' has write access and include all role helper functions
 vi.mock("../../utils/roles", async (importOriginal) => {
   const actual = await importOriginal<typeof import("../../utils/roles")>();
   return {
     ...actual,
-    rolesWithWriteAccess: ["admin"],
+    rolesWithWriteAccess: ["Admin"],
   };
 });
 
@@ -243,20 +249,6 @@ vi.mock("@/app/(dashboard)/hooks/useTeams", () => ({
   })),
 }));
 
-// Mock useAuthorized hook to avoid Next.js router dependency
-vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
-  default: vi.fn(() => ({
-    accessToken: "access_abc",
-    userId: "user_1",
-    userRole: "admin",
-    premiumUser: true,
-    token: "token_123",
-    userEmail: "test@example.com",
-    disabledPersonalKeyCreation: false,
-    showSSOBanner: false,
-  })),
-}));
-
 // KeyEditView mock: triggers onSubmit with our injected form values
 vi.mock("./key_edit_view", async () => {
   const React = await import("react");
@@ -302,21 +294,29 @@ const baseKeyData = {
   next_rotation_at: null as any,
 };
 
-const renderView = (premiumUser: boolean) =>
-  render(
+const renderView = (premiumUser: boolean) => {
+  // Configure the mock for this test
+  mockUseAuthorized.mockReturnValue({
+    accessToken: "access_abc",
+    userId: "user_1",
+    userRole: "Admin",
+    premiumUser,
+    token: "token_123",
+    userEmail: "test@example.com",
+    disabledPersonalKeyCreation: false,
+    showSSOBanner: false,
+  });
+
+  return render(
     <KeyInfoView
       keyId="tok_123"
       onClose={() => {}}
       keyData={baseKeyData as any}
       onKeyDataUpdate={() => {}}
-      accessToken="access_abc"
-      userID="user_1"
-      userRole="admin"
       teams={[]}
-      premiumUser={premiumUser}
-      setAccessToken={() => {}}
     />,
   );
+};
 
 beforeEach(() => {
   vi.clearAllMocks();
@@ -328,6 +328,7 @@ describe("KeyInfoView handleKeyUpdate premium guard", () => {
   it("removes guardrails & prompts for non-premium users and prevents metadata.guardrails", async () => {
     renderView(false); // premiumUser = false
 
+    fireEvent.click(screen.getByText("Settings"));
     fireEvent.click(screen.getByText("Edit Settings"));
     (globalThis as any).__TEST_FORM_VALUES = {
       token: "tok_123",
@@ -352,6 +353,7 @@ describe("KeyInfoView handleKeyUpdate premium guard", () => {
   it("preserves guardrails & prompts for premium users and includes metadata.guardrails", async () => {
     renderView(true); // premiumUser = true
 
+    fireEvent.click(screen.getByText("Settings"));
     fireEvent.click(screen.getByText("Edit Settings"));
     (globalThis as any).__TEST_FORM_VALUES = {
       token: "tok_123",
@@ -378,6 +380,7 @@ describe("KeyInfoView handleKeyUpdate empty strings", () => {
     it(`maps empty strings to null for ${limit}`, async () => {
       renderView(true); // premiumUser = true
 
+      fireEvent.click(screen.getByText("Settings"));
       fireEvent.click(screen.getByText("Edit Settings"));
       (globalThis as any).__TEST_FORM_VALUES = {
         token: "tok_123",
diff --git a/ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx b/ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx
--- a/ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx
+++ b/ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx
@@ -1,4 +1,5 @@
 import useTeams from "@/app/(dashboard)/hooks/useTeams";
+import useAuthorized from "@/app/(dashboard)/hooks/useAuthorized";
 import { render, screen, waitFor } from "@testing-library/react";
 import { beforeEach, describe, expect, it, vi } from "vitest";
 import { KeyResponse, Team } from "../key_team_helpers/key_list";
@@ -8,6 +9,10 @@ vi.mock("@/app/(dashboard)/hooks/useTeams", () => ({
   default: vi.fn(),
 }));
 
+vi.mock("@/app/(dashboard)/hooks/useAuthorized", () => ({
+  default: vi.fn(),
+}));
+
 describe("KeyInfoView", () => {
   beforeEach(() => {
     vi.mocked(useTeams).mockReturnValue({
@@ -85,17 +90,27 @@ describe("KeyInfoView", () => {
     key_rotation_at: undefined,
   };
 
+  // Base mock for useAuthorized hook
+  const baseUseAuthorizedMock = {
+    accessToken: "test-token",
+    userId: "test-user",
+    userRole: "admin",
+    premiumUser: true,
+    token: "test-token",
+    userEmail: null,
+    disabledPersonalKeyCreation: null,
+    showSSOBanner: false,
+  };
+
   it("should render tags", async () => {
+    vi.mocked(useAuthorized).mockReturnValue(baseUseAuthorizedMock);
+
     const { getByText } = render(
       <KeyInfoView
         keyData={MOCK_KEY_DATA}
         onClose={() => {}}
         keyId={"test-key-id"}
         onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={"test-user"}
-        userRole={"admin"}
-        premiumUser={true}
         teams={[]}
       />,
     );
@@ -105,16 +120,14 @@ describe("KeyInfoView", () => {
   });
 
   it("should not render tags in metadata textarea", async () => {
+    vi.mocked(useAuthorized).mockReturnValue(baseUseAuthorizedMock);
+
     const { container, getByText } = render(
       <KeyInfoView
         keyData={MOCK_KEY_DATA}
         onClose={() => {}}
         keyId={"test-key-id"}
         onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={"test-user"}
-        userRole={"admin"}
-        premiumUser={true}
         teams={[]}
       />,
     );
@@ -132,19 +145,15 @@ describe("KeyInfoView", () => {
       setTeams: vi.fn(),
     });
 
+    vi.mocked(useAuthorized).mockReturnValue({
+      ...baseUseAuthorizedMock,
+      userId: "proxy-admin-user",
+      userRole: "proxy_admin",
+    });
+
     const keyData = { ...MOCK_KEY_DATA, user_id: "other-user-id" };
     render(
-      <KeyInfoView
-        keyData={keyData}
-        onClose={() => {}}
-        keyId={"test-key-id"}
-        onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={"proxy-admin-user"}
-        userRole={"proxy_admin"}
-        premiumUser={true}
-        teams={[]}
-      />,
+      <KeyInfoView keyData={keyData} onClose={() => {}} keyId={"test-key-id"} onKeyDataUpdate={() => {}} teams={[]} />,
     );
 
     await waitFor(() => {
@@ -180,19 +189,15 @@ describe("KeyInfoView", () => {
       setTeams: vi.fn(),
     });
 
+    vi.mocked(useAuthorized).mockReturnValue({
+      ...baseUseAuthorizedMock,
+      userId: teamAdminUserId,
+      userRole: "user",
+    });
+
     const keyData = { ...MOCK_KEY_DATA, team_id: teamId, user_id: "other-user-id" };
     render(
-      <KeyInfoView
-        keyData={keyData}
-        onClose={() => {}}
-        keyId={"test-key-id"}
-        onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={teamAdminUserId}
-        userRole={"user"}
-        premiumUser={true}
-        teams={[]}
-      />,
+      <KeyInfoView keyData={keyData} onClose={() => {}} keyId={"test-key-id"} onKeyDataUpdate={() => {}} teams={[]} />,
     );
 
     await waitFor(() => {
@@ -207,20 +212,16 @@ describe("KeyInfoView", () => {
       setTeams: vi.fn(),
     });
 
+    vi.mocked(useAuthorized).mockReturnValue({
+      ...baseUseAuthorizedMock,
+      userId: "owner-user-id",
+      userRole: "user",
+    });
+
     const ownerUserId = "owner-user-id";
     const keyData = { ...MOCK_KEY_DATA, user_id: ownerUserId };
     render(
-      <KeyInfoView
-        keyData={keyData}
-        onClose={() => {}}
-        keyId={"test-key-id"}
-        onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={ownerUserId}
-        userRole={"user"}
-        premiumUser={true}
-        teams={[]}
-      />,
+      <KeyInfoView keyData={keyData} onClose={() => {}} keyId={"test-key-id"} onKeyDataUpdate={() => {}} teams={[]} />,
     );
 
     await waitFor(() => {
@@ -235,19 +236,15 @@ describe("KeyInfoView", () => {
       setTeams: vi.fn(),
     });
 
+    vi.mocked(useAuthorized).mockReturnValue({
+      ...baseUseAuthorizedMock,
+      userId: "other-user-id",
+      userRole: "user",
+    });
+
     const keyData = { ...MOCK_KEY_DATA, user_id: "owner-user-id" };
     render(
-      <KeyInfoView
-        keyData={keyData}
-        onClose={() => {}}
-        keyId={"test-key-id"}
-        onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={"other-user-id"}
-        userRole={"user"}
-        premiumUser={true}
-        teams={[]}
-      />,
+      <KeyInfoView keyData={keyData} onClose={() => {}} keyId={"test-key-id"} onKeyDataUpdate={() => {}} teams={[]} />,
     );
 
     await waitFor(() => {
@@ -262,20 +259,16 @@ describe("KeyInfoView", () => {
       setTeams: vi.fn(),
     });
 
+    vi.mocked(useAuthorized).mockReturnValue({
+      ...baseUseAuthorizedMock,
+      userId: "internal-viewer-user-id",
+      userRole: "Internal Viewer",
+    });
+
     const ownerUserId = "internal-viewer-user-id";
     const keyData = { ...MOCK_KEY_DATA, user_id: ownerUserId };
     render(
-      <KeyInfoView
-        keyData={keyData}
-        onClose={() => {}}
-        keyId={"test-key-id"}
-        onKeyDataUpdate={() => {}}
-        accessToken={"test-token"}
-        userID={ownerUserId}
-        userRole={"Internal Viewer"}
-        premiumUser={true}
-        teams={[]}
-      />,
+      <KeyInfoView keyData={keyData} onClose={() => {}} keyId={"test-key-id"} onKeyDataUpdate={() => {}} teams={[]} />,
     );
 
     await waitFor(() => {
EOF_114329324912

# Navigate to the UI dashboard directory
cd /testbed/ui/litellm-dashboard

# Set environment variables for testing
export NODE_ENV=test
export CI=true

# Run the target test files using vitest
# Note: all_keys_table.test.tsx is renamed to VirtualKeysTable.test.tsx by the patch
# Execute all three test files in a single command for efficiency
npx vitest run \
    src/components/VirtualKeysPage/VirtualKeysTable.test.tsx \
    src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx \
    src/components/templates/key_info_view.test.tsx

# Capture exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Navigate back to testbed root
cd /testbed

# Restore the original test files to clean state
git checkout 710ae2f1ce688f2847484b27c5a3dcb9deca0800 \
    "ui/litellm-dashboard/src/components/all_keys_table.test.tsx" \
    "ui/litellm-dashboard/src/components/templates/KeyInfoView.handleKeyUpdate.test.tsx" \
    "ui/litellm-dashboard/src/components/templates/key_info_view.test.tsx"

# Exit with the captured return code
exit $rc