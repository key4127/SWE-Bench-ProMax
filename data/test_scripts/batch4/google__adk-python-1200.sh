#!/bin/bash
set -uxo pipefail

# Activate the conda environment
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate testbed

# Navigate to the testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 1551bd4f4d7042fffb497d9308b05f92d45d818f "tests/unittests/evaluation/test_gcs_eval_sets_manager.py" "tests/unittests/evaluation/test_local_eval_set_results_manager.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/evaluation/mock_gcs_utils.py b/tests/unittests/evaluation/mock_gcs_utils.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/evaluation/mock_gcs_utils.py
@@ -0,0 +1,117 @@
+from typing import Optional
+from typing import Union
+
+
+class MockBlob:
+  """Mocks a GCS Blob object.
+
+  This class provides mock implementations for a few common GCS Blob methods,
+  allowing the user to test code that interacts with GCS without actually
+  connecting to a real bucket.
+  """
+
+  def __init__(self, name: str) -> None:
+    """Initializes a MockBlob.
+
+    Args:
+        name: The name of the blob.
+    """
+    self.name = name
+    self.content: Optional[bytes] = None
+    self.content_type: Optional[str] = None
+    self._exists: bool = False
+
+  def upload_from_string(
+      self, data: Union[str, bytes], content_type: Optional[str] = None
+  ) -> None:
+    """Mocks uploading data to the blob (from a string or bytes).
+
+    Args:
+        data: The data to upload (string or bytes).
+        content_type:  The content type of the data (optional).
+    """
+    if isinstance(data, str):
+      self.content = data.encode("utf-8")
+    elif isinstance(data, bytes):
+      self.content = data
+    else:
+      raise TypeError("data must be str or bytes")
+
+    if content_type:
+      self.content_type = content_type
+    self._exists = True
+
+  def download_as_text(self) -> str:
+    """Mocks downloading the blob's content as text.
+
+    Returns:
+        str: The content of the blob as text.
+
+    Raises:
+        Exception: If the blob doesn't exist (hasn't been uploaded to).
+    """
+    if self.content is None:
+      return b""
+    return self.content
+
+  def delete(self) -> None:
+    """Mocks deleting a blob."""
+    self.content = None
+    self.content_type = None
+    self._exists = False
+
+  def exists(self) -> bool:
+    """Mocks checking if the blob exists."""
+    return self._exists
+
+
+class MockBucket:
+  """Mocks a GCS Bucket object."""
+
+  def __init__(self, name: str) -> None:
+    """Initializes a MockBucket.
+
+    Args:
+        name: The name of the bucket.
+    """
+    self.name = name
+    self.blobs: dict[str, MockBlob] = {}
+
+  def blob(self, blob_name: str) -> MockBlob:
+    """Mocks getting a Blob object (doesn't create it in storage).
+
+    Args:
+        blob_name: The name of the blob.
+
+    Returns:
+        A MockBlob instance.
+    """
+    if blob_name not in self.blobs:
+      self.blobs[blob_name] = MockBlob(blob_name)
+    return self.blobs[blob_name]
+
+  def list_blobs(self, prefix: Optional[str] = None) -> list[MockBlob]:
+    """Mocks listing blobs in a bucket, optionally with a prefix."""
+    if prefix:
+      return [
+          blob for name, blob in self.blobs.items() if name.startswith(prefix)
+      ]
+    return list(self.blobs.values())
+
+  def exists(self) -> bool:
+    """Mocks checking if the bucket exists."""
+    return True
+
+
+class MockClient:
+  """Mocks the GCS Client."""
+
+  def __init__(self) -> None:
+    """Initializes MockClient."""
+    self.buckets: dict[str, MockBucket] = {}
+
+  def bucket(self, bucket_name: str) -> MockBucket:
+    """Mocks getting a Bucket object."""
+    if bucket_name not in self.buckets:
+      self.buckets[bucket_name] = MockBucket(bucket_name)
+    return self.buckets[bucket_name]
diff --git a/tests/unittests/evaluation/test_gcs_eval_set_results_manager.py b/tests/unittests/evaluation/test_gcs_eval_set_results_manager.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/evaluation/test_gcs_eval_set_results_manager.py
@@ -0,0 +1,191 @@
+# Copyright 2025 Google LLC
+#
+# Licensed under the Apache License, Version 2.0 (the "License");
+# you may not use this file except in compliance with the License.
+# You may obtain a copy of the License at
+#
+#     http://www.apache.org/licenses/LICENSE-2.0
+#
+# Unless required by applicable law or agreed to in writing, software
+# distributed under the License is distributed on an "AS IS" BASIS,
+# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+# See the License for the specific language governing permissions and
+# limitations under the License.
+
+from google.adk.errors.not_found_error import NotFoundError
+from google.adk.evaluation._eval_set_results_manager_utils import _sanitize_eval_set_result_name
+from google.adk.evaluation._eval_set_results_manager_utils import create_eval_set_result
+from google.adk.evaluation.eval_case import Invocation
+from google.adk.evaluation.eval_metrics import EvalMetricResult
+from google.adk.evaluation.eval_metrics import EvalMetricResultPerInvocation
+from google.adk.evaluation.eval_result import EvalCaseResult
+from google.adk.evaluation.evaluator import EvalStatus
+from google.adk.evaluation.gcs_eval_set_results_manager import GcsEvalSetResultsManager
+from google.genai import types as genai_types
+import pytest
+
+from .mock_gcs_utils import MockBucket
+from .mock_gcs_utils import MockClient
+
+
+def _get_test_eval_case_results():
+  # Create mock Invocation objects
+  actual_invocation_1 = Invocation(
+      invocation_id="actual_1",
+      user_content=genai_types.Content(
+          parts=[genai_types.Part(text="input_1")]
+      ),
+  )
+  expected_invocation_1 = Invocation(
+      invocation_id="expected_1",
+      user_content=genai_types.Content(
+          parts=[genai_types.Part(text="expected_input_1")]
+      ),
+  )
+  actual_invocation_2 = Invocation(
+      invocation_id="actual_2",
+      user_content=genai_types.Content(
+          parts=[genai_types.Part(text="input_2")]
+      ),
+  )
+  expected_invocation_2 = Invocation(
+      invocation_id="expected_2",
+      user_content=genai_types.Content(
+          parts=[genai_types.Part(text="expected_input_2")]
+      ),
+  )
+
+  eval_metric_result_1 = EvalMetricResult(
+      metric_name="metric",
+      threshold=0.8,
+      score=1.0,
+      eval_status=EvalStatus.PASSED,
+  )
+  eval_metric_result_2 = EvalMetricResult(
+      metric_name="metric",
+      threshold=0.8,
+      score=0.5,
+      eval_status=EvalStatus.FAILED,
+  )
+  eval_metric_result_per_invocation_1 = EvalMetricResultPerInvocation(
+      actual_invocation=actual_invocation_1,
+      expected_invocation=expected_invocation_1,
+      eval_metric_results=[eval_metric_result_1],
+  )
+  eval_metric_result_per_invocation_2 = EvalMetricResultPerInvocation(
+      actual_invocation=actual_invocation_2,
+      expected_invocation=expected_invocation_2,
+      eval_metric_results=[eval_metric_result_2],
+  )
+  return [
+      EvalCaseResult(
+          eval_set_id="eval_set",
+          eval_id="eval_case_1",
+          final_eval_status=EvalStatus.PASSED,
+          overall_eval_metric_results=[eval_metric_result_1],
+          eval_metric_result_per_invocation=[
+              eval_metric_result_per_invocation_1
+          ],
+          session_id="session_1",
+      ),
+      EvalCaseResult(
+          eval_set_id="eval_set",
+          eval_id="eval_case_2",
+          final_eval_status=EvalStatus.FAILED,
+          overall_eval_metric_results=[eval_metric_result_2],
+          eval_metric_result_per_invocation=[
+              eval_metric_result_per_invocation_2
+          ],
+          session_id="session_2",
+      ),
+  ]
+
+
+class TestGcsEvalSetResultsManager:
+
+  @pytest.fixture
+  def gcs_eval_set_results_manager(self, mocker):
+    mock_storage_client = MockClient()
+    bucket_name = "test_bucket"
+    mock_bucket = MockBucket(bucket_name)
+    mocker.patch.object(mock_storage_client, "bucket", return_value=mock_bucket)
+    mocker.patch(
+        "google.cloud.storage.Client", return_value=mock_storage_client
+    )
+    return GcsEvalSetResultsManager(bucket_name=bucket_name)
+
+  def test_save_eval_set_result(self, gcs_eval_set_results_manager, mocker):
+    mocker.patch("time.time", return_value=12345678)
+    app_name = "test_app"
+    eval_set_id = "test_eval_set"
+    eval_case_results = _get_test_eval_case_results()
+    eval_set_result = create_eval_set_result(
+        app_name, eval_set_id, eval_case_results
+    )
+    blob_name = gcs_eval_set_results_manager._get_eval_set_result_blob_name(
+        app_name, eval_set_result.eval_set_result_id
+    )
+    mock_write_eval_set_result = mocker.patch.object(
+        gcs_eval_set_results_manager,
+        "_write_eval_set_result",
+    )
+    gcs_eval_set_results_manager.save_eval_set_result(
+        app_name, eval_set_id, eval_case_results
+    )
+    mock_write_eval_set_result.assert_called_once_with(
+        blob_name,
+        eval_set_result,
+    )
+
+  def test_get_eval_set_result_not_found(
+      self, gcs_eval_set_results_manager, mocker
+  ):
+    mocker.patch("time.time", return_value=12345678)
+    app_name = "test_app"
+    with pytest.raises(NotFoundError) as e:
+      gcs_eval_set_results_manager.get_eval_set_result(
+          app_name, "non_existent_id"
+      )
+
+  def test_get_eval_set_result(self, gcs_eval_set_results_manager, mocker):
+    mocker.patch("time.time", return_value=12345678)
+    app_name = "test_app"
+    eval_set_id = "test_eval_set"
+    eval_case_results = _get_test_eval_case_results()
+    gcs_eval_set_results_manager.save_eval_set_result(
+        app_name, eval_set_id, eval_case_results
+    )
+    eval_set_result = create_eval_set_result(
+        app_name, eval_set_id, eval_case_results
+    )
+    retrieved_eval_set_result = (
+        gcs_eval_set_results_manager.get_eval_set_result(
+            app_name, eval_set_result.eval_set_result_id
+        )
+    )
+    assert retrieved_eval_set_result == eval_set_result
+
+  def test_list_eval_set_results(self, gcs_eval_set_results_manager, mocker):
+    mocker.patch("time.time", return_value=123)
+    app_name = "test_app"
+    eval_set_ids = ["test_eval_set_1", "test_eval_set_2", "test_eval_set_3"]
+    for eval_set_id in eval_set_ids:
+      eval_case_results = _get_test_eval_case_results()
+      gcs_eval_set_results_manager.save_eval_set_result(
+          app_name, eval_set_id, eval_case_results
+      )
+    retrieved_eval_set_result_ids = (
+        gcs_eval_set_results_manager.list_eval_set_results(app_name)
+    )
+    assert retrieved_eval_set_result_ids == [
+        "test_app_test_eval_set_1_123",
+        "test_app_test_eval_set_2_123",
+        "test_app_test_eval_set_3_123",
+    ]
+
+  def test_list_eval_set_results_empty(self, gcs_eval_set_results_manager):
+    app_name = "test_app"
+    retrieved_eval_set_result_ids = (
+        gcs_eval_set_results_manager.list_eval_set_results(app_name)
+    )
+    assert retrieved_eval_set_result_ids == []
diff --git a/tests/unittests/evaluation/test_gcs_eval_sets_manager.py b/tests/unittests/evaluation/test_gcs_eval_sets_manager.py
--- a/tests/unittests/evaluation/test_gcs_eval_sets_manager.py
+++ b/tests/unittests/evaluation/test_gcs_eval_sets_manager.py
@@ -12,130 +12,16 @@
 # See the License for the specific language governing permissions and
 # limitations under the License.
 
-from typing import Optional
-from typing import Union
-
 from google.adk.errors.not_found_error import NotFoundError
 from google.adk.evaluation.eval_case import EvalCase
 from google.adk.evaluation.eval_set import EvalSet
 from google.adk.evaluation.gcs_eval_sets_manager import _EVAL_SET_FILE_EXTENSION
 from google.adk.evaluation.gcs_eval_sets_manager import GcsEvalSetsManager
 import pytest
 
-
-class MockBlob:
-  """Mocks a GCS Blob object.
-
-  This class provides mock implementations for a few common GCS Blob methods,
-  allowing the user to test code that interacts with GCS without actually
-  connecting to a real bucket.
-  """
-
-  def __init__(self, name: str) -> None:
-    """Initializes a MockBlob.
-
-    Args:
-        name: The name of the blob.
-    """
-    self.name = name
-    self.content: Optional[bytes] = None
-    self.content_type: Optional[str] = None
-    self._exists: bool = False
-
-  def upload_from_string(
-      self, data: Union[str, bytes], content_type: Optional[str] = None
-  ) -> None:
-    """Mocks uploading data to the blob (from a string or bytes).
-
-    Args:
-        data: The data to upload (string or bytes).
-        content_type:  The content type of the data (optional).
-    """
-    if isinstance(data, str):
-      self.content = data.encode("utf-8")
-    elif isinstance(data, bytes):
-      self.content = data
-    else:
-      raise TypeError("data must be str or bytes")
-
-    if content_type:
-      self.content_type = content_type
-    self._exists = True
-
-  def download_as_text(self) -> str:
-    """Mocks downloading the blob's content as text.
-
-    Returns:
-        str: The content of the blob as text.
-
-    Raises:
-        Exception: If the blob doesn't exist (hasn't been uploaded to).
-    """
-    if self.content is None:
-      return b""
-    return self.content
-
-  def delete(self) -> None:
-    """Mocks deleting a blob."""
-    self.content = None
-    self.content_type = None
-    self._exists = False
-
-  def exists(self) -> bool:
-    """Mocks checking if the blob exists."""
-    return self._exists
-
-
-class MockBucket:
-  """Mocks a GCS Bucket object."""
-
-  def __init__(self, name: str) -> None:
-    """Initializes a MockBucket.
-
-    Args:
-        name: The name of the bucket.
-    """
-    self.name = name
-    self.blobs: dict[str, MockBlob] = {}
-
-  def blob(self, blob_name: str) -> MockBlob:
-    """Mocks getting a Blob object (doesn't create it in storage).
-
-    Args:
-        blob_name: The name of the blob.
-
-    Returns:
-        A MockBlob instance.
-    """
-    if blob_name not in self.blobs:
-      self.blobs[blob_name] = MockBlob(blob_name)
-    return self.blobs[blob_name]
-
-  def list_blobs(self, prefix: Optional[str] = None) -> list[MockBlob]:
-    """Mocks listing blobs in a bucket, optionally with a prefix."""
-    if prefix:
-      return [
-          blob for name, blob in self.blobs.items() if name.startswith(prefix)
-      ]
-    return list(self.blobs.values())
-
-  def exists(self) -> bool:
-    """Mocks checking if the bucket exists."""
-    return True
-
-
-class MockClient:
-  """Mocks the GCS Client."""
-
-  def __init__(self) -> None:
-    """Initializes MockClient."""
-    self.buckets: dict[str, MockBucket] = {}
-
-  def bucket(self, bucket_name: str) -> MockBucket:
-    """Mocks getting a Bucket object."""
-    if bucket_name not in self.buckets:
-      self.buckets[bucket_name] = MockBucket(bucket_name)
-    return self.buckets[bucket_name]
+from .mock_gcs_utils import MockBlob
+from .mock_gcs_utils import MockBucket
+from .mock_gcs_utils import MockClient
 
 
 class TestGcsEvalSetsManager:
diff --git a/tests/unittests/evaluation/test_local_eval_set_results_manager.py b/tests/unittests/evaluation/test_local_eval_set_results_manager.py
--- a/tests/unittests/evaluation/test_local_eval_set_results_manager.py
+++ b/tests/unittests/evaluation/test_local_eval_set_results_manager.py
@@ -21,24 +21,17 @@
 import time
 from unittest.mock import patch
 
+from google.adk.errors.not_found_error import NotFoundError
+from google.adk.evaluation._eval_set_results_manager_utils import _sanitize_eval_set_result_name
 from google.adk.evaluation.eval_result import EvalCaseResult
 from google.adk.evaluation.eval_result import EvalSetResult
 from google.adk.evaluation.evaluator import EvalStatus
 from google.adk.evaluation.local_eval_set_results_manager import _ADK_EVAL_HISTORY_DIR
 from google.adk.evaluation.local_eval_set_results_manager import _EVAL_SET_RESULT_FILE_EXTENSION
-from google.adk.evaluation.local_eval_set_results_manager import _sanitize_eval_set_result_name
 from google.adk.evaluation.local_eval_set_results_manager import LocalEvalSetResultsManager
 import pytest
 
 
-def test_sanitize_eval_set_result_name():
-  assert _sanitize_eval_set_result_name("app/name") == "app_name"
-  assert _sanitize_eval_set_result_name("app_name") == "app_name"
-  assert _sanitize_eval_set_result_name("app/name/with/slashes") == (
-      "app_name_with_slashes"
-  )
-
-
 class TestLocalEvalSetResultsManager:
 
   @pytest.fixture(autouse=True)
@@ -115,11 +108,9 @@ def test_get_eval_set_result(self, mock_time):
   def test_get_eval_set_result_not_found(self, mock_time):
     mock_time.return_value = self.timestamp
 
-    with pytest.raises(ValueError) as e:
+    with pytest.raises(NotFoundError) as e:
       self.manager.get_eval_set_result(self.app_name, "non_existent_id")
 
-    assert "does not exist" in str(e.value)
-
   @patch("time.time")
   def test_list_eval_set_results(self, mock_time):
     mock_time.return_value = self.timestamp
EOF_114329324912

# Execute the target test files using pytest
# Running in single-process mode for safety in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider \
    tests/unittests/evaluation/test_gcs_eval_sets_manager.py \
    tests/unittests/evaluation/test_local_eval_set_results_manager.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 1551bd4f4d7042fffb497d9308b05f92d45d818f "tests/unittests/evaluation/test_gcs_eval_sets_manager.py" "tests/unittests/evaluation/test_local_eval_set_results_manager.py"