#!/bin/bash
set -uxo pipefail

# Change to the testbed directory
cd /testbed

# Reset the target test file to the original commit state
git checkout 618675778038ec1317e8ad8103029cccf0d7b714 "test/recipes/25-test_verify_store.t"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/recipes/25-test_verify_store.t b/test/recipes/25-test_verify_store.t
--- a/test/recipes/25-test_verify_store.t
+++ b/test/recipes/25-test_verify_store.t
@@ -14,7 +14,7 @@ use OpenSSL::Test::Utils;
 
 setup("test_verify_store");
 
-plan tests => 10;
+plan tests => 11;
 
 my $dummycnf = srctop_file("apps", "openssl.cnf");
 my $cakey = srctop_file("test", "certs", "ca-key.pem");
@@ -23,6 +23,7 @@ my $ukey = srctop_file("test", "certs", "ee-key.pem");
 my $cnf = srctop_file("test", "ca-and-certs.cnf");
 my $CAkey = "keyCA.ss";
 my $CAcert="certCA.ss";
+my $CAobjects="objectsCA.ss"; # DH params, public key, private key, certificate
 my $CAserial="certCA.srl";
 my $CAreq="reqCA.ss";
 my $CAreq2="req2CA.ss"; # temp
@@ -38,7 +39,7 @@ SKIP: {
          -key          => $cakey,
          -keyout       => $CAkey );
 
-    skip 'failure', 8 unless
+    skip 'failure', 9 unless
         x509( 'convert request into self-signed cert',
               qw(-req -CAcreateserial -days 30),
               qw(-extensions v3_ca),
@@ -47,30 +48,45 @@ SKIP: {
               -signkey  => $CAkey,
               -extfile  => $cnf );
 
-    skip 'failure', 7 unless
+    skip 'failure', 8 unless
         x509( 'convert cert into a cert request',
               qw(-x509toreq),
               -in       => $CAcert,
               -out      => $CAreq2,
               -signkey  => $CAkey );
 
-    skip 'failure', 6 unless
+    skip 'failure', 7 unless
         req( 'verify request 1',
              qw(-verify -noout -section userreq),
              -config    => $dummycnf,
              -in        => $CAreq );
 
-    skip 'failure', 5 unless
+    skip 'failure', 6 unless
         req( 'verify request 2',
              qw(-verify -noout -section userreq),
              -config    => $dummycnf,
              -in        => $CAreq2 );
 
-    skip 'failure', 4 unless
-        verify( 'verify signature',
+    skip 'failure', 5 unless
+        verify( 'verify cert using CAstore including just the cert',
                 -CAstore => $CAcert,
                 $CAcert );
 
+    open(my $out, '>', $CAobjects) or die $!;
+    my $pubkey = qx(openssl x509 -pubkey -noout -in $CAcert);
+    print $out $pubkey;
+    my @files;
+    push @files, srctop_file("test", "certs", "dhp2048.pem")
+        unless disabled("dh");
+    push @files, ($CAkey, $CAcert);
+    print $out do { local @ARGV = @files; <> };
+    close $out or die $!;
+
+    skip 'failure', 4 unless
+        verify( 'verify cert using CAstore including cert and extra stuff',
+                -CAstore => $CAobjects,
+                $CAcert );
+
     skip 'failure', 3 unless
         req( 'make a user cert request',
              qw(-new -section userreq),
EOF_114329324912

# Execute the specific test using OpenSSL's test framework
# Note: OpenSSL tests use a recipe-based system, we run just the specific test
make TESTS="test_verify_store" test
rc=$?

# Output the exit code for the test execution
echo "OMNIGRIL_EXIT_CODE=$rc"

# Reset the test file back to the original state
git checkout 618675778038ec1317e8ad8103029cccf0d7b714 "test/recipes/25-test_verify_store.t"