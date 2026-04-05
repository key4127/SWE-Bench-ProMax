#!/bin/bash
set -uxo pipefail
cd /testbed

# Don't do initial checkout - the Dockerfile already checked out to the correct commit
# and there may be uncommitted changes that are part of the implementation

# Check current status before applying patch
echo "=== Git status before applying patch ==="
git status

# Apply test patch (includes both implementation changes and test file)
git apply -v - <<'EOF_114329324912'
diff --git a/test/db/cmd/cmd_pp b/test/db/cmd/cmd_pp
new file mode 100644
--- /dev/null
+++ b/test/db/cmd/cmd_pp
@@ -0,0 +1,39 @@
+NAME=pp
+FILE=-
+CMDS=<<EOF
+pp0 4
+pp1 4
+pp2 2
+pp4 1
+pp8 1
+ppf 4
+ppd 4
+ppa 2
+ppn 2
+pp?
+pp0?
+ppz
+EOF
+EXPECT=<<EOF
+00000000
+00010203
+00000001
+00000000
+0000000000000000
+ffffffff
+41414142
+AAAA BAAA 
+0000 1000 
+Usage: pp[0|1|2|4|8|a|d|f|n] [len]  print patterns
+| pp0 [len]      print buffer filled with zeros
+| pp1 [len]      print incremental byte pattern (honors lower bits of current address and block size)
+| pp2 [len]      print incremental word pattern
+| pp4 [len]      print incremental dword pattern
+| pp8 [len]      print incremental qword pattern
+| ppa[lu] [len]  print latin alphabet patterns (lowercase/uppercase)
+| ppd [len]      print debruijn pattern (see ragg2 -P, -q and wopD)
+| ppf [len]      print buffer filled with 0xff
+| ppn [len]      print numeric pin patterns
+| pp0 [len]  print buffer filled with zeros
+EOF
+RUN
EOF_114329324912

# Check status after applying patch
echo "=== Git status after applying patch ==="
git status

# Rebuild radare2 with the implementation changes from the patch
echo "=== Rebuilding radare2 with changes ==="
cd /testbed/build
ninja clean
cd /testbed
ninja -C build
ninja -C build install
ldconfig

# Set environment variables for r2r testing
export R2R_RADARE2=/usr/local/bin/radare2
export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Verify the test file exists
if [ ! -f "test/db/cmd/cmd_pp" ]; then
    echo "ERROR: Test file test/db/cmd/cmd_pp not found after applying patch"
    echo "OMNIGRIL_EXIT_CODE=1"
    exit 1
fi

# Run the specific test file added by the patch using r2r
# Using -L for log mode (better for CI), -j 1 for single process (safe in VM)
echo "=== Running test: test/db/cmd/cmd_pp ==="
r2r -L -j 1 test/db/cmd/cmd_pp
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset to original commit state
cd /testbed
git checkout 9d666f3937bbad17e8dda626454740eaef72ec18