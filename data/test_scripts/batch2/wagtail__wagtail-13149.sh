#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 2c74332bf3268443544db2c7db1739e9a48ac32c "wagtail/admin/tests/test_userbar.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/wagtail/admin/tests/test_userbar.py b/wagtail/admin/tests/test_userbar.py
--- a/wagtail/admin/tests/test_userbar.py
+++ b/wagtail/admin/tests/test_userbar.py
@@ -9,7 +9,7 @@
 
 from wagtail import hooks
 from wagtail.admin.staticfiles import versioned_static
-from wagtail.admin.userbar import AccessibilityItem
+from wagtail.admin.userbar import AccessibilityItem, Userbar
 from wagtail.coreutils import get_dummy_request
 from wagtail.models import PAGE_TEMPLATE_VAR, Locale, Page, Site
 from wagtail.test.context_processors import get_call_count, reset_call_count
@@ -730,3 +730,61 @@ def test_page_disallowing_subpages(self):
         soup = self.get_soup(response.content)
         link = soup.find("a", attrs={"href": expected_url})
         self.assertIsNone(link)
+
+
+class TestUserbarComponent(WagtailTestUtils, TestCase):
+    def setUp(self):
+        self.request = get_dummy_request()
+        self.request.user = self.create_superuser(
+            username="test", email="test@email.com", password="password"
+        )
+        self.homepage = Page.objects.get(id=2)
+        self.parent_page = self.homepage.get_parent()
+
+    def test_render_minimal(self):
+        rendered = Userbar().render_html({"request": self.request})
+        soup = self.get_soup(rendered)
+
+        items = soup.select("li")
+        self.assertEqual(len(items), 2)
+
+        admin_url = f"http://localhost{reverse('wagtailadmin_home')}"
+        admin_item = items[0]
+        admin_link = admin_item.select_one("a")
+        self.assertIsNotNone(admin_link)
+        self.assertEqual(admin_link.get("href"), admin_url)
+        self.assertEqual(admin_link.text.strip(), "Go to Wagtail admin")
+
+        accessibility_item = items[-1]
+        button = accessibility_item.select_one("button")
+        self.assertIsNotNone(button)
+        self.assertEqual(
+            button.get_text(separator=" | ", strip=True).strip(),
+            "Issues found | Accessibility",
+        )
+
+    def test_render_with_page(self):
+        rendered = Userbar(object=self.homepage).render_html(
+            {"request": self.request, PAGE_TEMPLATE_VAR: self.homepage}
+        )
+        soup = self.get_soup(rendered)
+
+        links = soup.select("li a")
+        expected_urls = [
+            reverse("wagtailadmin_home"),
+            reverse("wagtailadmin_explore", args=(self.parent_page.id,)),
+            reverse("wagtailadmin_pages:edit", args=(self.homepage.id,)),
+            reverse("wagtailadmin_pages:add_subpage", args=(self.homepage.id,)),
+        ]
+        self.assertEqual(len(links), 4)
+        self.assertEqual(
+            [link.get("href") for link in links],
+            [f"http://localhost{url}" for url in expected_urls],
+        )
+
+        accessibility_button = soup.select_one("li button")
+        self.assertIsNotNone(accessibility_button)
+        self.assertEqual(
+            accessibility_button.get_text(separator=" | ", strip=True).strip(),
+            "Issues found | Accessibility",
+        )
EOF_114329324912

# Run the target test file using the custom runtests.py script
python runtests.py wagtail.admin.tests.test_userbar
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 2c74332bf3268443544db2c7db1739e9a48ac32c "wagtail/admin/tests/test_userbar.py"