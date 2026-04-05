#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout f28691cede4c66bcf106271be530667c448e31fa ".github/workflows/test_paid.yml" "tests/main.cpp" "tests/unit/environment.cpp" "tests/unit/paulis.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/.github/workflows/test_paid.yml b/.github/workflows/test_paid.yml
--- a/.github/workflows/test_paid.yml
+++ b/.github/workflows/test_paid.yml
@@ -257,12 +257,15 @@ jobs:
           -DCMAKE_CUDA_ARCHITECTURES=${{ env.cuda_arch }}
           -DTEST_ALL_DEPLOYMENTS=${{ env.test_all_deploys }}
           -DTEST_NUM_MIXED_DEPLOYMENT_REPETITIONS=${{ env.test_repetitions }}
-          -DPERMIT_NODES_TO_SHARE_GPU=${{ env.mpi_share_gpu }}
           -DCMAKE_CXX_FLAGS=${{ matrix.mpi == 'ON' && matrix.cuda == 'ON' && '-fno-lto' || '' }}
 
       - name: Compile
         run: cmake --build ${{ env.build_dir }} --parallel
 
+      # permit use of single GPU by multiple MPI processes (detriments performance)
+      - name: Set env-var to permit GPU sharing
+        run: echo "PERMIT_NODES_TO_SHARE_GPU=${{ env.mpi_share_gpu }}" >> $GITHUB_ENV
+
       # cannot use ctests when distributed, grr!
       - name: Run GPU + distributed v4 mixed tests (4 nodes sharing 1 GPU)
         run: |
diff --git a/tests/main.cpp b/tests/main.cpp
--- a/tests/main.cpp
+++ b/tests/main.cpp
@@ -88,13 +88,14 @@ class startListener : public Catch::EventListenerBase {
         QuESTEnv env = getQuESTEnv();
         std::cout << std::endl;
         std::cout << "QuEST execution environment:" << std::endl;
-        std::cout << "  precision:       " << FLOAT_PRECISION        << std::endl;
-        std::cout << "  multithreaded:   " << env.isMultithreaded    << std::endl;
-        std::cout << "  distributed:     " << env.isDistributed      << std::endl;
-        std::cout << "  GPU-accelerated: " << env.isGpuAccelerated   << std::endl;
-        std::cout << "  cuQuantum:       " << env.isCuQuantumEnabled << std::endl;
-        std::cout << "  num nodes:       " << env.numNodes           << std::endl;
-        std::cout << "  num qubits:      " << getNumCachedQubits()   << std::endl;
+        std::cout << "  precision:       " << FLOAT_PRECISION         << std::endl;
+        std::cout << "  multithreaded:   " << env.isMultithreaded     << std::endl;
+        std::cout << "  distributed:     " << env.isDistributed       << std::endl;
+        std::cout << "  GPU-accelerated: " << env.isGpuAccelerated    << std::endl;
+        std::cout << "  GPU-sharing ok:  " << env.isGpuSharingEnabled << std::endl;
+        std::cout << "  cuQuantum:       " << env.isCuQuantumEnabled  << std::endl;
+        std::cout << "  num nodes:       " << env.numNodes            << std::endl;
+        std::cout << "  num qubits:      " << getNumCachedQubits()    << std::endl;
         std::cout << "  num qubit perms: " << TEST_MAX_NUM_QUBIT_PERMUTATIONS << std::endl;
         std::cout << std::endl;
 
diff --git a/tests/unit/environment.cpp b/tests/unit/environment.cpp
--- a/tests/unit/environment.cpp
+++ b/tests/unit/environment.cpp
@@ -54,6 +54,13 @@ TEST_CASE( "initQuESTEnv", TEST_CATEGORY ) {
     SECTION( LABEL_VALIDATION ) {
 
         REQUIRE_THROWS_WITH( initQuESTEnv(), ContainsSubstring( "already been initialised") );
+
+        // cannot automatically check other validations, such as:
+        // - has env been previously initialised then finalised?
+        // - is env distributed over power-of-2 nodes?
+        // - are environment-variables valid?
+        // - is max 1 MPI process bound to each GPU?
+        // - is GPU compatible with cuQuantum (if enabled)?
     }
 }
 
@@ -133,10 +140,11 @@ TEST_CASE( "getQuESTEnv", TEST_CATEGORY ) {
 
         QuESTEnv env = getQuESTEnv();
 
-        REQUIRE( (env.isMultithreaded    == 0 || env.isMultithreaded    == 1) );
-        REQUIRE( (env.isGpuAccelerated   == 0 || env.isGpuAccelerated   == 1) );
-        REQUIRE( (env.isDistributed      == 0 || env.isDistributed      == 1) );
-        REQUIRE( (env.isCuQuantumEnabled == 0 || env.isCuQuantumEnabled == 1) );
+        REQUIRE( (env.isMultithreaded     == 0 || env.isMultithreaded     == 1) );
+        REQUIRE( (env.isGpuAccelerated    == 0 || env.isGpuAccelerated    == 1) );
+        REQUIRE( (env.isDistributed       == 0 || env.isDistributed       == 1) );
+        REQUIRE( (env.isCuQuantumEnabled  == 0 || env.isCuQuantumEnabled  == 1) );
+        REQUIRE( (env.isGpuSharingEnabled == 0 || env.isGpuSharingEnabled == 1) );
         
         REQUIRE( env.rank     >= 0 );
         REQUIRE( env.numNodes >= 0 );
diff --git a/tests/unit/paulis.cpp b/tests/unit/paulis.cpp
--- a/tests/unit/paulis.cpp
+++ b/tests/unit/paulis.cpp
@@ -362,8 +362,9 @@ TEST_CASE( "createInlinePauliStrSum", TEST_CATEGORY ) {
 
         SECTION( "coefficient parsing" ) {
 
-            vector<std::string> strs = {"1 X", "0 X", "0.1 X", "5E2-1i X", "-1E-50i X",  "1 - 6E-5i X", "-1.5E-15  -   5.123E-30i  0"};
-            vector<qcomp> coeffs     = { 1,     0,     0.1,     5E2-1_i,   -(1E-50)*1_i,  1 -(6E-5)*1_i, qcomp(-1.5E-15, -5.123E-30) };
+            // beware that when FLOAT_PRECISION=1, qcomp cannot store smaller than 1E-37 (triggering a validation error)
+            vector<std::string> strs = {"1 X", "0 X", "0.1 X", "5E2-1i X", "-1E-25i X",  "1 - 6E-5i X", "-1.5E-15  -   5.123E-30i  0"};
+            vector<qcomp> coeffs     = { 1,     0,     0.1,     5E2-1_i,   -(1E-25)*1_i,  1 -(6E-5)*1_i, qcomp(-1.5E-15, -5.123E-30) };
 
             size_t i = GENERATE_REF( range(0, (int) strs.size()) );
             CAPTURE( strs[i], coeffs[i] );
@@ -377,7 +378,7 @@ TEST_CASE( "createInlinePauliStrSum", TEST_CATEGORY ) {
 
             PauliStrSum sum = createInlinePauliStrSum(R"(
                 + 5E2-1i     XYZ 
-                - 1E-50i     IXY 
+                - 1E-20i     IXY 
                 + 1 - 6E-5i  IIX 
                   0          III 
                   5.         XXX 
@@ -416,6 +417,12 @@ TEST_CASE( "createInlinePauliStrSum", TEST_CATEGORY ) {
             REQUIRE_NOTHROW( createInlinePauliStrSum("1 2 3") ); // = 1 * YZ and is legal
         }
 
+        SECTION( "out of range" ) {
+
+            // the max/min qcomp depend upon FLOAT_PRECISION but we'll lazily use something even quad-prec cannot store
+            REQUIRE_THROWS_WITH( createInlinePauliStrSum("-1E-9999 XYZ"), ContainsSubstring("exceeds the range which can be stored in a qcomp") );
+        }
+
         SECTION( "inconsistent number of qubits" ) {
 
             REQUIRE_THROWS_WITH( createInlinePauliStrSum("3 XYZ \n 2 YX"), ContainsSubstring("inconsistent") );
@@ -444,7 +451,7 @@ TEST_CASE( "createPauliStrSumFromFile", TEST_CATEGORY ) {
             file.open(fn);
             file << R"(
                 + 5E2-1i     XYZ 
-                - 1E-50i     IXY 
+                - 1E-20i     IXY 
                 + 1 - 6E-5i  IIX 
                 0            III 
                 5.           IXX
@@ -497,7 +504,7 @@ TEST_CASE( "createPauliStrSumFromReversedFile", TEST_CATEGORY ) {
             file.open(fn);
             file << R"(
                 + 5E2-1i     XYZ 
-                - 1E-50i     IXY 
+                - 1E-20i     IXY 
                 + 1 - 6E-5i  IIX 
                 0            III 
                 5.           IXX
EOF_114329324912

# Navigate to build directory
cd /testbed/build

# Configure CMake with testing enabled
cmake .. \
    -DENABLE_TESTING=ON \
    -DFLOAT_PRECISION=2 \
    -DENABLE_DEPRECATED_API=OFF \
    -DENABLE_MULTITHREADING=OFF \
    -DENABLE_DISTRIBUTION=OFF \
    -DENABLE_CUDA=OFF \
    -DTEST_ALL_DEPLOYMENTS=OFF \
    -DTEST_MAX_NUM_QUBIT_PERMUTATIONS=10

# Build the project (limit parallelism to 4 jobs for stability)
cmake --build . --parallel 4

# Run the tests - the test executable includes all unit tests
# Since we're testing specific files (environment.cpp, paulis.cpp), 
# and these are compiled into the test binary, we run the full test suite
# Catch2 will execute all tests defined in the compiled test files
./tests/tests

# Capture exit code
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
cd /testbed
git checkout f28691cede4c66bcf106271be530667c448e31fa ".github/workflows/test_paid.yml" "tests/main.cpp" "tests/unit/environment.cpp" "tests/unit/paulis.cpp"