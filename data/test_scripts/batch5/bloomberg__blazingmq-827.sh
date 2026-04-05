#!/bin/bash
set -uxo pipefail

# Set up environment variables
export VCPKG_ROOT=/opt/vcpkg
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/opt/bb/lib64/pkgconfig
export PATH=${PATH}:/workspace/srcs/bde-tools/bin

cd /testbed

# Checkout the target file to ensure clean state
git checkout a95eb967f3f3986dba072d34c91484078f3367d8 "src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp b/src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp
--- a/src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp
+++ b/src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp
@@ -470,7 +470,13 @@ void QueueEngineTester::init(const mqbconfm::Domain& domainConfig,
 
     // Register queue in domain
     bslma::ManagedPtr<mqbi::Queue> queueMp(d_mockQueue_sp.managedPtr());
-    rc = d_mockDomain_mp->registerQueue(errorDescription, queueMp);
+
+    rc = queueMp->configure(errorDescription,
+                            false,  // isReconfigure
+                            true);  // wait
+    BSLS_ASSERT_OPT(rc == 0);
+
+    rc = d_mockDomain_mp->registerQueue(queueMp);
     BSLS_ASSERT_OPT(rc == 0);
 
     // VALIDATION
EOF_114329324912

# Configure CMake build with required flags
cd /testbed
cmake -S . -B build/blazingmq -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=/workspace/srcs/bde-tools/BdeBuildSystem/toolchains/linux/gcc-default.cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DBDE_BUILD_TARGET_SAFE=ON \
    -DBDE_BUILD_TARGET_64=ON \
    -DBDE_BUILD_TARGET_CPP17=ON \
    -DCMAKE_PREFIX_PATH=/workspace/srcs/bde-tools/BdeBuildSystem \
    -DCMAKE_INSTALL_LIBDIR=lib64

# Build the mqbblp library and its tests (this will compile mqbblp_queueenginetester.cpp)
# Using limited parallelism for stability in virtualized environment
cmake --build build/blazingmq --parallel 4 --target mqbblp

# Build all unit tests that may use the queueenginetester utility
cmake --build build/blazingmq --parallel 4 --target all.t

# Run unit tests in the mqbblp group to verify the utility works correctly
cd build/blazingmq
ctest --output-on-failure -L ^unit$ -R mqbblp --parallel 1
rc=$?

echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original file
cd /testbed
git checkout a95eb967f3f3986dba072d34c91484078f3367d8 "src/groups/mqb/mqbblp/mqbblp_queueenginetester.cpp"