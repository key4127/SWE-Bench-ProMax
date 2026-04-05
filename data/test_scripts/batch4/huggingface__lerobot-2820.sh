#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout fe068df711dd5d08aa04c577b40d31ec61245f22 "tests/async_inference/test_policy_server.py" "tests/rl/test_actor.py" "tests/rl/test_actor_learner.py" "tests/rl/test_learner_service.py" "tests/transport/test_transport_utils.py" "tests/utils.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/async_inference/test_policy_server.py b/tests/async_inference/test_policy_server.py
--- a/tests/async_inference/test_policy_server.py
+++ b/tests/async_inference/test_policy_server.py
@@ -62,7 +62,7 @@ def model(self, batch: dict) -> torch.Tensor:
 
 
 @pytest.fixture
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def policy_server():
     """Fresh `PolicyServer` instance with a stubbed-out policy model."""
     # Import only when the test actually runs (after decorator check)
diff --git a/tests/rl/test_actor.py b/tests/rl/test_actor.py
--- a/tests/rl/test_actor.py
+++ b/tests/rl/test_actor.py
@@ -64,7 +64,7 @@ def close_service_stub(channel, server):
     server.stop(None)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_establish_learner_connection_success():
     from lerobot.rl.actor import establish_learner_connection
 
@@ -81,7 +81,7 @@ def test_establish_learner_connection_success():
     close_service_stub(channel, server)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_establish_learner_connection_failure():
     from lerobot.rl.actor import establish_learner_connection
 
@@ -100,7 +100,7 @@ def test_establish_learner_connection_failure():
     close_service_stub(channel, server)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_push_transitions_to_transport_queue():
     from lerobot.rl.actor import push_transitions_to_transport_queue
     from lerobot.transport.utils import bytes_to_transitions
@@ -135,7 +135,7 @@ def test_push_transitions_to_transport_queue():
         assert_transitions_equal(deserialized_transition, transitions[i])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_transitions_stream():
     from lerobot.rl.actor import transitions_stream
@@ -167,7 +167,7 @@ def test_transitions_stream():
     assert streamed_data[2].data == b"transition_data_3"
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_interactions_stream():
     from lerobot.rl.actor import interactions_stream
diff --git a/tests/rl/test_actor_learner.py b/tests/rl/test_actor_learner.py
--- a/tests/rl/test_actor_learner.py
+++ b/tests/rl/test_actor_learner.py
@@ -88,7 +88,7 @@ def cfg():
     return cfg
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(10)  # force cross-platform watchdog
 def test_end_to_end_transitions_flow(cfg):
     from lerobot.rl.actor import (
@@ -150,7 +150,7 @@ def test_end_to_end_transitions_flow(cfg):
         assert_transitions_equal(transition, input_transitions[i])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(10)
 def test_end_to_end_interactions_flow(cfg):
     from lerobot.rl.actor import (
@@ -223,7 +223,7 @@ def test_end_to_end_interactions_flow(cfg):
         assert received == expected
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.parametrize("data_size", ["small", "large"])
 @pytest.mark.timeout(10)
 def test_end_to_end_parameters_flow(cfg, data_size):
diff --git a/tests/rl/test_learner_service.py b/tests/rl/test_learner_service.py
--- a/tests/rl/test_learner_service.py
+++ b/tests/rl/test_learner_service.py
@@ -39,7 +39,7 @@ def learner_service_stub():
     close_learner_service_stub(channel, server)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def create_learner_service_stub(
     shutdown_event: Event,
     parameters_queue: Queue,
@@ -75,7 +75,7 @@ def create_learner_service_stub(
     return services_pb2_grpc.LearnerServiceStub(channel), channel, server
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def close_learner_service_stub(channel, server):
     channel.close()
     server.stop(None)
@@ -91,7 +91,7 @@ def test_ready_method(learner_service_stub):
     assert response == services_pb2.Empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_send_interactions():
     from lerobot.transport import services_pb2
@@ -135,7 +135,7 @@ def mock_interactions_stream():
     assert interactions == [b"123", b"4", b"5", b"678"]
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_send_transitions():
     from lerobot.transport import services_pb2
@@ -181,7 +181,7 @@ def mock_transitions_stream():
     assert transitions == [b"transition_1transition_2transition_3", b"batch_1batch_2"]
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_send_transitions_empty_stream():
     from lerobot.transport import services_pb2
@@ -209,7 +209,7 @@ def empty_stream():
     assert transitions_queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(10)  # force cross-platform watchdog
 def test_stream_parameters():
     import time
@@ -267,7 +267,7 @@ def test_stream_parameters():
     assert time_diff == pytest.approx(seconds_between_pushes, abs=0.1)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_stream_parameters_with_shutdown():
     from lerobot.transport import services_pb2
@@ -319,7 +319,7 @@ def producer():
     assert received_params == [b"param_batch_1", b"stop"]
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 @pytest.mark.timeout(3)  # force cross-platform watchdog
 def test_stream_parameters_waits_and_retries_on_empty_queue():
     import threading
diff --git a/tests/transport/test_transport_utils.py b/tests/transport/test_transport_utils.py
--- a/tests/transport/test_transport_utils.py
+++ b/tests/transport/test_transport_utils.py
@@ -26,7 +26,7 @@
 from tests.utils import require_cuda, require_package
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_bytes_buffer_size_empty_buffer():
     from lerobot.transport.utils import bytes_buffer_size
 
@@ -37,7 +37,7 @@ def test_bytes_buffer_size_empty_buffer():
     assert buffer.tell() == 0
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_bytes_buffer_size_small_buffer():
     from lerobot.transport.utils import bytes_buffer_size
 
@@ -47,7 +47,7 @@ def test_bytes_buffer_size_small_buffer():
     assert buffer.tell() == 0
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_bytes_buffer_size_large_buffer():
     from lerobot.transport.utils import CHUNK_SIZE, bytes_buffer_size
 
@@ -58,7 +58,7 @@ def test_bytes_buffer_size_large_buffer():
     assert buffer.tell() == 0
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_send_bytes_in_chunks_empty_data():
     from lerobot.transport.utils import send_bytes_in_chunks, services_pb2
 
@@ -68,7 +68,7 @@ def test_send_bytes_in_chunks_empty_data():
     assert len(chunks) == 0
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_single_chunk_small_data():
     from lerobot.transport.utils import send_bytes_in_chunks, services_pb2
 
@@ -82,7 +82,7 @@ def test_single_chunk_small_data():
     assert chunks[0].transfer_state == services_pb2.TransferState.TRANSFER_END
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_not_silent_mode():
     from lerobot.transport.utils import send_bytes_in_chunks, services_pb2
 
@@ -94,7 +94,7 @@ def test_not_silent_mode():
     assert chunks[0].data == b"Some data"
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_send_bytes_in_chunks_large_data():
     from lerobot.transport.utils import CHUNK_SIZE, send_bytes_in_chunks, services_pb2
 
@@ -111,7 +111,7 @@ def test_send_bytes_in_chunks_large_data():
     assert chunks[2].transfer_state == services_pb2.TransferState.TRANSFER_END
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_send_bytes_in_chunks_large_data_with_exact_chunk_size():
     from lerobot.transport.utils import CHUNK_SIZE, send_bytes_in_chunks, services_pb2
 
@@ -124,7 +124,7 @@ def test_send_bytes_in_chunks_large_data_with_exact_chunk_size():
     assert chunks[0].transfer_state == services_pb2.TransferState.TRANSFER_END
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_empty_data():
     from lerobot.transport.utils import receive_bytes_in_chunks
 
@@ -138,7 +138,7 @@ def test_receive_bytes_in_chunks_empty_data():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_single_chunk():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -157,7 +157,7 @@ def test_receive_bytes_in_chunks_single_chunk():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_single_not_end_chunk():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -175,7 +175,7 @@ def test_receive_bytes_in_chunks_single_not_end_chunk():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_multiple_chunks():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -199,7 +199,7 @@ def test_receive_bytes_in_chunks_multiple_chunks():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_multiple_messages():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -235,7 +235,7 @@ def test_receive_bytes_in_chunks_multiple_messages():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_shutdown_during_receive():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -259,7 +259,7 @@ def test_receive_bytes_in_chunks_shutdown_during_receive():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_only_begin_chunk():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -279,7 +279,7 @@ def test_receive_bytes_in_chunks_only_begin_chunk():
     assert queue.empty()
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_missing_begin():
     from lerobot.transport.utils import receive_bytes_in_chunks, services_pb2
 
@@ -303,7 +303,7 @@ def test_receive_bytes_in_chunks_missing_begin():
 
 
 # Tests for state_to_bytes and bytes_to_state_dict
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_state_to_bytes_empty_dict():
     from lerobot.transport.utils import bytes_to_state_dict, state_to_bytes
 
@@ -314,7 +314,7 @@ def test_state_to_bytes_empty_dict():
     assert reconstructed == state_dict
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_bytes_to_state_dict_empty_data():
     from lerobot.transport.utils import bytes_to_state_dict
 
@@ -323,7 +323,7 @@ def test_bytes_to_state_dict_empty_data():
         bytes_to_state_dict(b"")
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_state_to_bytes_simple_dict():
     from lerobot.transport.utils import bytes_to_state_dict, state_to_bytes
 
@@ -347,7 +347,7 @@ def test_state_to_bytes_simple_dict():
         assert torch.allclose(state_dict[key], reconstructed[key])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_state_to_bytes_various_dtypes():
     from lerobot.transport.utils import bytes_to_state_dict, state_to_bytes
 
@@ -372,7 +372,7 @@ def test_state_to_bytes_various_dtypes():
             assert torch.allclose(state_dict[key], reconstructed[key])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_bytes_to_state_dict_invalid_data():
     from lerobot.transport.utils import bytes_to_state_dict
 
@@ -382,7 +382,7 @@ def test_bytes_to_state_dict_invalid_data():
 
 
 @require_cuda
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_state_to_bytes_various_dtypes_cuda():
     from lerobot.transport.utils import bytes_to_state_dict, state_to_bytes
 
@@ -407,7 +407,7 @@ def test_state_to_bytes_various_dtypes_cuda():
             assert torch.allclose(state_dict[key], reconstructed[key])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_python_object_to_bytes_none():
     from lerobot.transport.utils import bytes_to_python_object, python_object_to_bytes
 
@@ -439,7 +439,7 @@ def test_python_object_to_bytes_none():
         (1, 2, 3),
     ],
 )
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_python_object_to_bytes_simple_types(obj):
     from lerobot.transport.utils import bytes_to_python_object, python_object_to_bytes
 
@@ -450,7 +450,7 @@ def test_python_object_to_bytes_simple_types(obj):
     assert type(reconstructed) is type(obj)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_python_object_to_bytes_with_tensors():
     from lerobot.transport.utils import bytes_to_python_object, python_object_to_bytes
 
@@ -475,7 +475,7 @@ def test_python_object_to_bytes_with_tensors():
     assert torch.equal(obj["nested"]["tensor2"], reconstructed["nested"]["tensor2"])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_transitions_to_bytes_empty_list():
     from lerobot.transport.utils import bytes_to_transitions, transitions_to_bytes
 
@@ -487,7 +487,7 @@ def test_transitions_to_bytes_empty_list():
     assert isinstance(reconstructed, list)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_transitions_to_bytes_single_transition():
     from lerobot.transport.utils import bytes_to_transitions, transitions_to_bytes
 
@@ -509,7 +509,7 @@ def test_transitions_to_bytes_single_transition():
     assert_transitions_equal(transitions[0], reconstructed[0])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def assert_transitions_equal(t1: Transition, t2: Transition):
     """Helper to assert two transitions are equal."""
     assert_observation_equal(t1["state"], t2["state"])
@@ -519,15 +519,15 @@ def assert_transitions_equal(t1: Transition, t2: Transition):
     assert_observation_equal(t1["next_state"], t2["next_state"])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def assert_observation_equal(o1: dict, o2: dict):
     """Helper to assert two observations are equal."""
     assert set(o1.keys()) == set(o2.keys())
     for key in o1:
         assert torch.allclose(o1[key], o2[key])
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_transitions_to_bytes_multiple_transitions():
     from lerobot.transport.utils import bytes_to_transitions, transitions_to_bytes
 
@@ -551,7 +551,7 @@ def test_transitions_to_bytes_multiple_transitions():
         assert_transitions_equal(original, reconstructed_item)
 
 
-@require_package("grpc")
+@require_package("grpcio", "grpc")
 def test_receive_bytes_in_chunks_unknown_state():
     from lerobot.transport.utils import receive_bytes_in_chunks
 
diff --git a/tests/utils.py b/tests/utils.py
--- a/tests/utils.py
+++ b/tests/utils.py
@@ -167,15 +167,15 @@ def wrapper(*args, **kwargs):
     return wrapper
 
 
-def require_package(package_name):
+def require_package(package_name, import_name=None):
     """
     Decorator that skips the test if the specified package is not installed.
     """
 
     def decorator(func):
         @wraps(func)
         def wrapper(*args, **kwargs):
-            if not is_package_available(package_name):
+            if not is_package_available(pkg_name=package_name, import_name=import_name):
                 pytest.skip(f"{package_name} not installed")
             return func(*args, **kwargs)
 
EOF_114329324912

# Set required environment variables
export PYTHONPATH=/testbed/src:$PYTHONPATH
export LEROBOT_TEST_DEVICE=cpu

# Execute the target test files using pytest
# Running all test files in a single command for efficiency
# Using -v for verbose output and --tb=short for concise tracebacks
pytest tests/async_inference/test_policy_server.py \
       tests/rl/test_actor.py \
       tests/rl/test_actor_learner.py \
       tests/rl/test_learner_service.py \
       tests/transport/test_transport_utils.py \
       tests/utils.py \
       -v --tb=short --no-header -rA

# Capture the exit code
rc=$?

# Echo the exit code for the judge to process
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout fe068df711dd5d08aa04c577b40d31ec61245f22 "tests/async_inference/test_policy_server.py" "tests/rl/test_actor.py" "tests/rl/test_actor_learner.py" "tests/rl/test_learner_service.py" "tests/transport/test_transport_utils.py" "tests/utils.py"