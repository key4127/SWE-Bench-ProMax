#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout b137f7c2ec7845faa41a3ec5665ec6aed1c7f1d9 ".github/workflows/tests-storage.yml" ".github/workflows/tests-with-minimum-versions.yml" ".github/workflows/tests.yml" "tests/artifacts_tests/test_boto3.py" "tests/storages_tests/test_cached_storage.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/.github/workflows/tests-storage.yml b/.github/workflows/tests-storage.yml
--- a/.github/workflows/tests-storage.yml
+++ b/.github/workflows/tests-storage.yml
@@ -23,12 +23,10 @@ jobs:
 
     strategy:
       matrix:
-        python-version: ['3.8', '3.9', '3.10', '3.11', '3.12', '3.13']
+        python-version: ['3.9', '3.10', '3.11', '3.12', '3.13']
         test-trigger-type:
           - ${{ (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch') && 'Scheduled' || '' }}
         exclude:
-          - test-trigger-type: ""
-            python-version: "3.9"
           - test-trigger-type: ""
             python-version: "3.10"
           - test-trigger-type: ""
@@ -106,11 +104,6 @@ jobs:
         pip install --progress-bar off .[test] --extra-index-url https://download.pytorch.org/whl/cpu
         pip install --progress-bar off .[optional] --extra-index-url https://download.pytorch.org/whl/cpu
 
-        if [ "${{ matrix.python-version }}" = "3.8" ] ; then
-          # TODO(nabe): Remove this line once Python 3.8 is dropped.
-          pip install --upgrade "fakeredis[lua]<2.30.0"
-        fi
-
     - name: Install DB bindings
       run: |
         pip install --progress-bar off PyMySQL cryptography psycopg2-binary psycopg redis
diff --git a/.github/workflows/tests-with-minimum-versions.yml b/.github/workflows/tests-with-minimum-versions.yml
--- a/.github/workflows/tests-with-minimum-versions.yml
+++ b/.github/workflows/tests-with-minimum-versions.yml
@@ -20,7 +20,7 @@ jobs:
 
     strategy:
       matrix:
-        python-version: ['3.8', '3.9']
+        python-version: ['3.9']
 
     services:
       redis:
@@ -66,20 +66,13 @@ jobs:
         pip install --progress-bar off .[test] --extra-index-url https://download.pytorch.org/whl/cpu
         pip install --progress-bar off .[optional] --extra-index-url https://download.pytorch.org/whl/cpu
 
-        if [ "${{ matrix.python-version }}" = "3.8" ] ; then
-          # TODO(nabe): Remove this line once Python 3.8 is dropped.
-          pip install --upgrade "fakeredis[lua]<2.30.0"
-        fi
-
     - name: Install dependencies with minimum versions
       run: |
         # Install dependencies with minimum versions.
         pip uninstall -y alembic cmaes packaging sqlalchemy plotly scikit-learn pillow
         pip install alembic==1.5.0 cmaes==0.12.0 packaging==20.0 sqlalchemy==1.4.2 tqdm==4.27.0 colorlog==0.3 PyYAML==5.1 'pillow<10.4.0'
         pip uninstall -y matplotlib pandas scipy
-        if [ "${{ matrix.python-version }}" = "3.8" ]; then
-          pip install matplotlib==3.7.5 pandas==2.0.3 scipy==1.10.1 numpy==1.20.3
-        elif [ "${{ matrix.python-version }}" = "3.9" ]; then
+        if [ "${{ matrix.python-version }}" = "3.9" ]; then
           pip install matplotlib==3.8.4 pandas==2.2.2 scipy==1.13.0 numpy==1.26.4
         fi
         pip install plotly==5.0.0 scikit-learn==0.24.2  # optional extras
diff --git a/.github/workflows/tests.yml b/.github/workflows/tests.yml
--- a/.github/workflows/tests.yml
+++ b/.github/workflows/tests.yml
@@ -20,16 +20,16 @@ jobs:
 
     strategy:
       matrix:
-        python-version: ['3.8', '3.9', '3.10', '3.11', '3.12', '3.13']
+        python-version: ['3.9', '3.10', '3.11', '3.12', '3.13']
         test-trigger-type:
           - ${{ (github.event_name == 'schedule' || github.event_name == 'workflow_dispatch') && 'Scheduled' || '' }}
         exclude:
-          - test-trigger-type: ""
-            python-version: "3.9"
           - test-trigger-type: ""
             python-version: "3.10"
           - test-trigger-type: ""
             python-version: "3.11"
+          - test-trigger-type: ""
+            python-version: "3.12"
 
     services:
       redis:
@@ -75,11 +75,6 @@ jobs:
         pip install --progress-bar off .[test] --extra-index-url https://download.pytorch.org/whl/cpu
         pip install --progress-bar off .[optional] --extra-index-url https://download.pytorch.org/whl/cpu
 
-        if [ "${{ matrix.python-version }}" = "3.8" ] ; then
-          # TODO(nabe): Remove this line once Python 3.8 is dropped.
-          pip install --upgrade "fakeredis[lua]<2.30.0"
-        fi
-
     - name: Output installed packages
       run: |
         pip freeze --all
diff --git a/tests/artifacts_tests/test_boto3.py b/tests/artifacts_tests/test_boto3.py
--- a/tests/artifacts_tests/test_boto3.py
+++ b/tests/artifacts_tests/test_boto3.py
@@ -13,11 +13,9 @@
 
 if TYPE_CHECKING:
     from collections.abc import Iterator
+    from typing import Annotated
 
     from mypy_boto3_s3 import S3Client
-    from typing_extensions import Annotated
-
-    # TODO(Shinichi) import Annotated from typing after python 3.8 support is dropped.
 
 
 @pytest.fixture()
diff --git a/tests/storages_tests/test_cached_storage.py b/tests/storages_tests/test_cached_storage.py
--- a/tests/storages_tests/test_cached_storage.py
+++ b/tests/storages_tests/test_cached_storage.py
@@ -103,19 +103,19 @@ def test_read_trials_from_remote_storage() -> None:
         directions=[StudyDirection.MINIMIZE], study_name="test-study"
     )
 
-    storage._read_trials_from_remote_storage(study_id)
+    storage._read_trials_from_remote_storage(study_id, None)
 
     # Non-existent study.
     with pytest.raises(KeyError):
-        storage._read_trials_from_remote_storage(study_id + 1)
+        storage._read_trials_from_remote_storage(study_id + 1, None)
 
     # Create a trial via CachedStorage and update it via backend storage directly.
     trial_id = storage.create_new_trial(study_id)
     base_storage.set_trial_param(
         trial_id, "paramA", 1.2, optuna.distributions.FloatDistribution(-0.2, 2.3)
     )
     base_storage.set_trial_state_values(trial_id, TrialState.COMPLETE, values=[0.0])
-    storage._read_trials_from_remote_storage(study_id)
+    storage._read_trials_from_remote_storage(study_id, None)
     assert storage.get_trial(trial_id).state == TrialState.COMPLETE
 
 
@@ -132,8 +132,8 @@ def test_delete_study() -> None:
     storage.set_trial_state_values(trial_id2, state=TrialState.COMPLETE)
 
     # Update _StudyInfo.finished_trial_ids
-    storage._read_trials_from_remote_storage(study_id1)
-    storage._read_trials_from_remote_storage(study_id2)
+    storage._read_trials_from_remote_storage(study_id1, None)
+    storage._read_trials_from_remote_storage(study_id2, None)
 
     storage.delete_study(study_id1)
     assert storage._get_cached_trial(trial_id1) is None
EOF_114329324912

# Run the target test files
# Note: Only running the actual Python test files, not the workflow YAML files
# Using -v for verbose output and --tb=short for concise tracebacks
# Running in single-process mode for stability in the virtualized environment
pytest tests/artifacts_tests/test_boto3.py tests/storages_tests/test_cached_storage.py -v --tb=short --color=yes
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout b137f7c2ec7845faa41a3ec5665ec6aed1c7f1d9 ".github/workflows/tests-storage.yml" ".github/workflows/tests-with-minimum-versions.yml" ".github/workflows/tests.yml" "tests/artifacts_tests/test_boto3.py" "tests/storages_tests/test_cached_storage.py"