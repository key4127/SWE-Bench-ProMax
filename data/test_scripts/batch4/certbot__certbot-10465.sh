#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 57d2429e4f42c6617d6bfbd969427d538591ea76 "certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py b/certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py
--- a/certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py
+++ b/certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py
@@ -4,9 +4,6 @@
 
 import pytest
 
-from cryptography import x509
-from cryptography.hazmat.primitives import serialization
-
 from acme import challenges
 from acme import messages
 from certbot import achallenges
@@ -182,7 +179,7 @@ def _test_choose_or_make_vhosts_common(self, name, conf):
                    'ipv6.com': "etc_nginx/sites-enabled/ipv6.com"}
         conf_path = {key: os.path.normpath(value) for key, value in conf_path.items()}
 
-        vhost = self.config.choose_or_make_vhosts(name)[0]
+        vhost = self.config.choose_or_make_vhosts(name, 'key.pem', 'fullchain.pem')[0]
         path = os.path.relpath(vhost.filep, self.temp_dir)
 
         assert conf_names[conf] == vhost.names
@@ -200,34 +197,51 @@ def test_choose_or_make_vhosts_bad(self):
         for name in bad_results:
             with self.subTest(name=name):
                 with pytest.raises(errors.MisconfigurationError):
-                    self.config.choose_or_make_vhosts(name)
+                    self.config.choose_or_make_vhosts(name, 'key.pem', 'fullchain.pem')
 
     def test_choose_or_make_vhosts_keep_ip_address(self):
+        # let's use a simple helper function to set key and fullchain values
+        def choose_or_make_vhosts(domain):
+            return self.config.choose_or_make_vhosts(domain, 'key.pem', 'fullchain.pem')
+
         # no listen on port 80
         # listen       69.50.225.155:9000;
         # listen       127.0.0.1;
-        vhost = self.config.choose_or_make_vhosts('example.com')[0]
+        vhost = choose_or_make_vhosts('example.com')[0]
         assert obj.Addr.fromstring("5001 ssl") in vhost.addrs
 
         # no listens at all
-        vhost = self.config.choose_or_make_vhosts('no-listens.com')[0]
+        vhost = choose_or_make_vhosts('no-listens.com')[0]
         assert obj.Addr.fromstring("5001 ssl") in vhost.addrs
         assert obj.Addr.fromstring("80") in vhost.addrs
 
         # blank addr listen on 80 should result in blank addr ssl
         # listen 80;
         # listen [::]:80;
-        vhost = self.config.choose_or_make_vhosts('ipv6.com')[0]
+        vhost = choose_or_make_vhosts('ipv6.com')[0]
         assert obj.Addr.fromstring("5001 ssl") in vhost.addrs
         assert obj.Addr.fromstring("[::]:5001 ssl") in vhost.addrs
 
         # listen on 80 with ip address should result in copied addr
         # listen 1.2.3.4:80;
         # listen [1:20::300]:80;
-        vhost = self.config.choose_or_make_vhosts('addr-80.com')[0]
+        vhost = choose_or_make_vhosts('addr-80.com')[0]
         assert obj.Addr.fromstring("1.2.3.4:5001 ssl") in vhost.addrs
         assert obj.Addr.fromstring("[1:20::300]:5001 ssl ipv6only=on") in vhost.addrs
 
+    def test_choose_or_make_vhost_ssl_directives(self):
+        conf_path = self.config.parser.abs_path('sites-enabled/example.com')
+        self.config.choose_or_make_vhosts('example.com', 'my-key.pem', 'my-fullchain.pem')
+        self.config.save()
+        self.config.parser.load()
+        parsed_conf = util.filter_comments(self.config.parser.parsed[conf_path])
+
+        expected_directives = [
+            ['ssl_certificate', 'my-fullchain.pem'],
+            ['ssl_certificate_key', 'my-key.pem'],
+        ]
+        for directive in expected_directives:
+            assert util.contains_at_depth(parsed_conf, directive, 2)
 
     def test_ipv6only(self):
         # ipv6_info: (ipv6_active, ipv6only_present)
@@ -238,14 +252,8 @@ def test_ipv6only(self):
     def test_ipv6only_detection(self):
         self.config.version = (1, 3, 1)
 
-        self.config.deploy_cert(
-            "ipv6.com",
-            "example/cert.pem",
-            "example/key.pem",
-            "example/chain.pem",
-            "example/fullchain.pem")
-
-        for addr in self.config.choose_or_make_vhosts("ipv6.com")[0].addrs:
+        vhost = self.config.choose_or_make_vhosts("ipv6.com", "key.pem", "fullchain.pem")[0]
+        for addr in vhost.addrs:
             assert not addr.ipv6only
 
     def test_more_info(self):
@@ -570,16 +578,6 @@ def test_save_throws_error_from_reverter(self, mock_add_to_checkpoint):
         with pytest.raises(errors.PluginError):
             self.config.save()
 
-    def test_get_snakeoil_paths(self):
-        # pylint: disable=protected-access
-        cert, key = self.config._get_snakeoil_paths()
-        assert os.path.exists(cert)
-        assert os.path.exists(key)
-        with open(cert, "rb") as cert_file:
-            x509.load_pem_x509_certificate(cert_file.read())
-        with open(key, "rb") as key_file:
-            serialization.load_pem_private_key(key_file.read(), password=None)
-
     def test_redirect_enhance(self):
         # Test that we successfully add a redirect when there is
         # a listen directive
EOF_114329324912

# Run the target test file
# Note: Running in single-process mode for stability in virtualized environment
python -m pytest certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py -v --tb=short --no-header -rA

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 57d2429e4f42c6617d6bfbd969427d538591ea76 "certbot-nginx/src/certbot_nginx/_internal/tests/configurator_test.py"