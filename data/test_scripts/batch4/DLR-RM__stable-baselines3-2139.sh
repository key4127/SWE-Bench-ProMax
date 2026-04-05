#!/bin/bash
set -uxo pipefail

# Activate virtual environment
source /opt/testbed_env/bin/activate

# Navigate to testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 8cd8c62890a2637654662531c4bc9c771d856c96 "tests/test_env_checker.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_env_checker.py b/tests/test_env_checker.py
--- a/tests/test_env_checker.py
+++ b/tests/test_env_checker.py
@@ -23,7 +23,7 @@ def step(self, action):
         info = {}
         return observation, reward, terminated, truncated, info
 
-    def reset(self, seed=None):
+    def reset(self, *, seed=None, options=None):
         return np.array([1.0, 1.5, 0.5], dtype=self.observation_space.dtype), {}
 
     def render(self):
@@ -37,14 +37,15 @@ def test_check_env_dict_action():
         check_env(env=test_env, warn=True)
 
 
-class SequenceObservationEnv(gym.Env):
+class CustomEnv(gym.Env):
     metadata = {"render_modes": [], "render_fps": 2}
 
     def __init__(self, render_mode=None):
+        # Test Sequence obs
         self.observation_space = spaces.Sequence(spaces.Discrete(8))
         self.action_space = spaces.Discrete(4)
 
-    def reset(self, seed=None, options=None):
+    def reset(self, *, seed=None, options=None):
         super().reset(seed=seed)
         return self.observation_space.sample(), {}
 
@@ -53,7 +54,7 @@ def step(self, action):
 
 
 def test_check_env_sequence_obs():
-    test_env = SequenceObservationEnv()
+    test_env = CustomEnv()
 
     with pytest.warns(Warning, match="Sequence.*not supported"):
         check_env(env=test_env, warn=True)
@@ -191,3 +192,34 @@ def test_check_env_single_step_env():
 
     # This should not throw
     check_env(env=test_env, warn=True)
+
+
+class SimpleGraphEnv(CustomEnv):
+    def __init__(self):
+        self.action_space = spaces.Discrete(2)
+        self.observation_space = spaces.Graph(
+            node_space=spaces.Box(low=0, high=1, shape=(2,)),
+            edge_space=spaces.Box(low=0, high=1, shape=(3,)),
+        )
+
+
+class SimpleDictGraphEnv(CustomEnv):
+    def __init__(self):
+        self.action_space = spaces.Discrete(2)
+        self.observation_space = spaces.Dict(
+            {
+                "test": spaces.Graph(
+                    node_space=spaces.Box(low=0, high=1, shape=(2,)),
+                    edge_space=spaces.Box(low=0, high=1, shape=(3,)),
+                )
+            }
+        )
+
+
+def test_check_env_graph_space():
+    # Should emit a warning about Graph space, but not fail
+    with pytest.warns(UserWarning, match="Graph.*not supported"):
+        check_env(SimpleGraphEnv(), warn=True)
+
+    with pytest.warns(UserWarning, match="Graph.*not supported"):
+        check_env(SimpleDictGraphEnv(), warn=True)
EOF_114329324912

# Run the target test file with pytest
# Using single-process mode for safety in virtualized environment
# Setting PYTHONHASHSEED=0 as specified in the configuration
PYTHONHASHSEED=0 pytest -v --no-header -rA --tb=short -p no:cacheprovider tests/test_env_checker.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 8cd8c62890a2637654662531c4bc9c771d856c96 "tests/test_env_checker.py"