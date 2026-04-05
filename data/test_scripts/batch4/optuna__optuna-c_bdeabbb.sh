#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 90a0b791c3e9398f4eaba5066a3b48cbeda72a95 "optuna/testing/storages.py" "tests/gp_tests/test_batched_lbfgsb.py" "tests/samplers_tests/test_cmaes.py" "tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py" "tests/samplers_tests/tpe_tests/test_truncnorm.py" "tests/storages_tests/journal_tests/test_journal.py" "tests/study_tests/test_study.py" "tests/trial_tests/test_trial.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/optuna/testing/storages.py b/optuna/testing/storages.py
--- a/optuna/testing/storages.py
+++ b/optuna/testing/storages.py
@@ -86,6 +86,8 @@ def __init__(self, storage_specifier: str, **kwargs: Any) -> None:
         self.server: grpc.Server | None = None
         self.thread: threading.Thread | None = None
         self.proxy: GrpcStorageProxy | None = None
+        self.storage: BaseStorage | None = None
+        self.backend_storage: BaseStorage | None = None
 
     def __enter__(
         self,
@@ -99,7 +101,7 @@ def __enter__(
         if self.storage_specifier == "inmemory":
             if len(self.extra_args) > 0:
                 raise ValueError("InMemoryStorage does not accept any arguments!")
-            return optuna.storages.InMemoryStorage()
+            self.storage = optuna.storages.InMemoryStorage()
         elif "sqlite" in self.storage_specifier:
             self.tempfile = NamedTemporaryFilePool().tempfile()
             url = "sqlite:///{}".format(self.tempfile.name)
@@ -108,7 +110,7 @@ def __enter__(
                 engine_kwargs={"connect_args": {"timeout": SQLITE3_TIMEOUT}},
                 **self.extra_args,
             )
-            return (
+            self.storage = (
                 optuna.storages._CachedStorage(rdb_storage)
                 if "cached" in self.storage_specifier
                 else rdb_storage
@@ -120,29 +122,34 @@ def __enter__(
             journal_redis_storage._redis = self.extra_args.get(
                 "redis", fakeredis.FakeStrictRedis()
             )
-            return optuna.storages.JournalStorage(journal_redis_storage)
+            self.storage = optuna.storages.JournalStorage(journal_redis_storage)
         elif self.storage_specifier == "grpc_journal_file":
             self.tempfile = self.extra_args.get("file", NamedTemporaryFilePool().tempfile())
             assert self.tempfile is not None
             storage = optuna.storages.JournalStorage(
                 optuna.storages.journal.JournalFileBackend(self.tempfile.name)
             )
-            return self._create_proxy(storage, thread_pool=self.extra_args.get("thread_pool"))
+            self.storage = self._create_proxy(
+                storage, thread_pool=self.extra_args.get("thread_pool")
+            )
         elif "journal" in self.storage_specifier:
             self.tempfile = self.extra_args.get("file", NamedTemporaryFilePool().tempfile())
             assert self.tempfile is not None
             file_storage = JournalFileBackend(self.tempfile.name)
-            return optuna.storages.JournalStorage(file_storage)
+            self.storage = optuna.storages.JournalStorage(file_storage)
         elif self.storage_specifier == "grpc_rdb":
             self.tempfile = NamedTemporaryFilePool().tempfile()
             url = "sqlite:///{}".format(self.tempfile.name)
-            return self._create_proxy(optuna.storages.RDBStorage(url))
+            self.backend_storage = optuna.storages.RDBStorage(url)
+            self.storage = self._create_proxy(self.backend_storage)
         elif self.storage_specifier == "grpc_proxy":
             assert "base_storage" in self.extra_args
-            return self._create_proxy(self.extra_args["base_storage"])
+            self.storage = self._create_proxy(self.extra_args["base_storage"])
         else:
             assert False
 
+        return self.storage
+
     def _create_proxy(
         self, storage: BaseStorage, thread_pool: ThreadPoolExecutor | None = None
     ) -> GrpcStorageProxy:
@@ -163,6 +170,16 @@ def __exit__(
         exc_val: BaseException | None,
         exc_tb: TracebackType | None,
     ) -> None:
+        # Unit tests create many short-lived Engine objects, so the connections created by the
+        # engine should be explicitly closed.
+        if isinstance(self.storage, optuna.storages.RDBStorage):
+            self.storage.engine.dispose()
+        elif isinstance(self.storage, optuna.storages._CachedStorage):
+            self.storage._backend.engine.dispose()
+        elif self.storage_specifier == "grpc_rdb":
+            assert isinstance(self.backend_storage, optuna.storages.RDBStorage)
+            self.backend_storage.engine.dispose()
+
         if self.tempfile:
             self.tempfile.close()
 
diff --git a/tests/gp_tests/test_batched_lbfgsb.py b/tests/gp_tests/test_batched_lbfgsb.py
--- a/tests/gp_tests/test_batched_lbfgsb.py
+++ b/tests/gp_tests/test_batched_lbfgsb.py
@@ -9,11 +9,13 @@
 import pytest
 from scipy.optimize import fmin_l_bfgs_b
 
+from optuna._gp.batched_lbfgsb import batched_lbfgsb
+
 
 RADIUS = 5.12
 
 
-def rastrigin_and_grad(x: np.ndarray, batch_indices: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
+def rastrigin_and_grad(x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
     if x.ndim == 1:
         x = x[None]
     A = 10.0
@@ -25,9 +27,7 @@ def rastrigin_and_grad(x: np.ndarray, batch_indices: np.ndarray) -> tuple[np.nda
     return fval, grad
 
 
-def styblinski_tang_and_grad(
-    x: np.ndarray, batch_indices: np.ndarray
-) -> tuple[np.ndarray, np.ndarray]:
+def styblinski_tang_and_grad(x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
     # Styblinski-Tang function, which has multiple local minima.
     if x.ndim == 1:
         x = x[None]
@@ -58,11 +58,8 @@ def _verify_results(
     xs_opt2 = []
     fvals_opt2 = []
     n_iters2 = []
-    batch_indices = np.array([])
     for x0 in X0:
-        x_opt, fval, info = fmin_l_bfgs_b(
-            func=func_and_grad, args=(batch_indices,), x0=x0, **kwargs_scipy
-        )
+        x_opt, fval, info = fmin_l_bfgs_b(func=func_and_grad, x0=x0, **kwargs_scipy)
         xs_opt2.append(x_opt)
         fvals_opt2.append(float(fval))
         n_iters2.append(info["nit"])
@@ -120,3 +117,37 @@ def test_batched_lbfgsb(
         kwargs_scipy,
         batched_lbfgsb_func=optimization_module.batched_lbfgsb,
     )
+
+
+def test_batched_lbfgsb_invalid_input() -> None:
+    batch_size = 3
+    dimension = 2
+    x0_batched = np.random.rand(batch_size, dimension)
+
+    # x0_batched validation
+    with pytest.raises(ValueError):
+        batched_lbfgsb(
+            func_and_grad=lambda x: (np.sum(x, axis=1), np.ones_like(x)),
+            x0_batched=x0_batched[0],  # not 2D
+        )
+
+    # batched_args validation
+    def dummy_func_and_grad(x: np.ndarray, _arg: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
+        return np.sum(x, axis=1), np.ones_like(x)
+
+    with pytest.raises(AssertionError):
+        batched_lbfgsb(
+            func_and_grad=dummy_func_and_grad,
+            x0_batched=x0_batched,
+            batched_args=([0] * (batch_size + 1),),  # wrong length
+        )
+
+    # bounds validation
+    invalid_bounds = [(0.0, 1.0)]  # length is not equal to dimension
+    with pytest.raises(AssertionError):
+        batched_lbfgsb(
+            func_and_grad=dummy_func_and_grad,
+            x0_batched=x0_batched,
+            batched_args=(list(range(batch_size)),),
+            bounds=invalid_bounds,
+        )
diff --git a/tests/samplers_tests/test_cmaes.py b/tests/samplers_tests/test_cmaes.py
--- a/tests/samplers_tests/test_cmaes.py
+++ b/tests/samplers_tests/test_cmaes.py
@@ -285,11 +285,12 @@ def objective(t: optuna.Trial) -> float:
 
     # The independent sampler is used for Trial#0 (FAILED), Trial#1 (COMPLETE)
     # and Trial#2 (COMPLETE). The CMA-ES is used for Trial#3 (COMPLETE).
-    with patch.object(
-        independent_sampler, "sample_independent", wraps=independent_sampler.sample_independent
-    ) as mock_independent, patch.object(
-        sampler, "sample_relative", wraps=sampler.sample_relative
-    ) as mock_relative:
+    with (
+        patch.object(
+            independent_sampler, "sample_independent", wraps=independent_sampler.sample_independent
+        ) as mock_independent,
+        patch.object(sampler, "sample_relative", wraps=sampler.sample_relative) as mock_relative,
+    ):
         study.optimize(objective, n_trials=4, catch=(Exception,))
         assert mock_independent.call_count == 6  # The objective function has two parameters.
         assert mock_relative.call_count == 4
diff --git a/tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py b/tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py
--- a/tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py
+++ b/tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py
@@ -29,14 +29,18 @@ def suggest(
     past_trials: list[optuna.trial.FrozenTrial],
 ) -> float:
     attrs = MockSystemAttr()
-    with patch.object(study._storage, "get_all_trials", return_value=past_trials), patch.object(
-        study._storage, "set_trial_system_attr", side_effect=attrs.set_trial_system_attr
-    ), patch.object(study._storage, "get_trial", return_value=trial), patch(
-        "optuna.trial.Trial.system_attrs", new_callable=PropertyMock
-    ) as mock1, patch(
-        "optuna.trial.FrozenTrial.system_attrs",
-        new_callable=PropertyMock,
-    ) as mock2:
+    with (
+        patch.object(study._storage, "get_all_trials", return_value=past_trials),
+        patch.object(
+            study._storage, "set_trial_system_attr", side_effect=attrs.set_trial_system_attr
+        ),
+        patch.object(study._storage, "get_trial", return_value=trial),
+        patch("optuna.trial.Trial.system_attrs", new_callable=PropertyMock) as mock1,
+        patch(
+            "optuna.trial.FrozenTrial.system_attrs",
+            new_callable=PropertyMock,
+        ) as mock2,
+    ):
         mock1.return_value = attrs.value
         mock2.return_value = attrs.value
         suggestion = sampler.sample_independent(study, trial, "param-a", distribution)
@@ -89,22 +93,23 @@ def _suggest_and_return_call_count(
         past_trials: list[optuna.trial.FrozenTrial],
     ) -> int:
         attrs = MockSystemAttr()
-        with patch.object(
-            study._storage, "get_all_trials", return_value=past_trials
-        ), patch.object(
-            study._storage, "set_trial_system_attr", side_effect=attrs.set_trial_system_attr
-        ), patch.object(
-            study._storage, "get_trial", return_value=trial
-        ), patch(
-            "optuna.trial.Trial.system_attrs", new_callable=PropertyMock
-        ) as mock1, patch(
-            "optuna.trial.FrozenTrial.system_attrs",
-            new_callable=PropertyMock,
-        ) as mock2, patch.object(
-            optuna.samplers.RandomSampler,
-            "sample_independent",
-            return_value=1.0,
-        ) as sample_method:
+        with (
+            patch.object(study._storage, "get_all_trials", return_value=past_trials),
+            patch.object(
+                study._storage, "set_trial_system_attr", side_effect=attrs.set_trial_system_attr
+            ),
+            patch.object(study._storage, "get_trial", return_value=trial),
+            patch("optuna.trial.Trial.system_attrs", new_callable=PropertyMock) as mock1,
+            patch(
+                "optuna.trial.FrozenTrial.system_attrs",
+                new_callable=PropertyMock,
+            ) as mock2,
+            patch.object(
+                optuna.samplers.RandomSampler,
+                "sample_independent",
+                return_value=1.0,
+            ) as sample_method,
+        ):
             mock1.return_value = attrs.value
             mock2.return_value = attrs.value
             sampler.sample_independent(study, trial, "param-a", dist)
diff --git a/tests/samplers_tests/tpe_tests/test_truncnorm.py b/tests/samplers_tests/tpe_tests/test_truncnorm.py
--- a/tests/samplers_tests/tpe_tests/test_truncnorm.py
+++ b/tests/samplers_tests/tpe_tests/test_truncnorm.py
@@ -26,7 +26,7 @@ def test_ppf(a: float, b: float) -> None:
     ):
         assert truncnorm_ours.ppf(x, a, b) == pytest.approx(
             truncnorm_scipy.ppf(x, a, b), nan_ok=True
-        ), f"ppf(x={x}, a={a}, b={b})"
+        ), f"ppf({x=}, {a=}, {b=})"
 
 
 @pytest.mark.filterwarnings("ignore::RuntimeWarning")
@@ -42,7 +42,7 @@ def test_logpdf(a: float, b: float, loc: float, scale: float) -> None:
     ):
         assert truncnorm_ours.logpdf(x, a, b, loc, scale) == pytest.approx(
             truncnorm_scipy.logpdf(x, a, b, loc, scale), nan_ok=True
-        ), f"logpdf(x={x}, a={a}, b={b})"
+        ), f"logpdf({x=}, {a=}, {b=})"
 
 
 @pytest.mark.skipif(
@@ -57,7 +57,7 @@ def test_log_gass_mass(a: float, b: float) -> None:
     a_arr, b_arr = np.array([a]), np.array([b])
     assert truncnorm_ours._log_gauss_mass(a_arr, b_arr) == pytest.approx(
         _log_gauss_mass_scipy(a_arr, b_arr), nan_ok=True
-    ), f"_log_gauss_mass(a={a}, b={b})"
+    ), f"_log_gauss_mass({a=}, {b=})"
 
 
 @pytest.mark.skipif(
diff --git a/tests/storages_tests/journal_tests/test_journal.py b/tests/storages_tests/journal_tests/test_journal.py
--- a/tests/storages_tests/journal_tests/test_journal.py
+++ b/tests/storages_tests/journal_tests/test_journal.py
@@ -70,7 +70,7 @@ def __enter__(self) -> optuna.storages.journal.BaseJournalBackend:
             journal_redis_storage._redis = FakeStrictRedis()
             return journal_redis_storage
         else:
-            raise RuntimeError("Unknown log storage type: {}".format(self.storage_type))
+            raise RuntimeError(f"Unknown log storage type: {self.storage_type}")
 
     def __exit__(
         self, exc_type: type[BaseException], exc_val: BaseException, exc_tb: TracebackType
@@ -94,7 +94,7 @@ def test_concurrent_append_logs_for_multi_processes(
         with ProcessPoolExecutor(num_executors) as pool:
             pool.map(storage.append_logs, [[record] for _ in range(num_records)], timeout=20)
 
-        assert len(storage.read_logs(0)) == num_records
+        assert len(list(storage.read_logs(0))) == num_records
         assert all(record == r for r in storage.read_logs(0))
 
 
@@ -110,7 +110,7 @@ def test_concurrent_append_logs_for_multi_threads(
         with ThreadPoolExecutor(num_executors) as pool:
             pool.map(storage.append_logs, [[record] for _ in range(num_records)], timeout=20)
 
-        assert len(storage.read_logs(0)) == num_records
+        assert len(list(storage.read_logs(0))) == num_records
         assert all(record == r for r in storage.read_logs(0))
 
 
diff --git a/tests/study_tests/test_study.py b/tests/study_tests/test_study.py
--- a/tests/study_tests/test_study.py
+++ b/tests/study_tests/test_study.py
@@ -468,9 +468,10 @@ def test_delete_study(storage_mode: str) -> None:
 @pytest.mark.parametrize("from_storage_mode", STORAGE_MODES)
 @pytest.mark.parametrize("to_storage_mode", STORAGE_MODES)
 def test_copy_study(from_storage_mode: str, to_storage_mode: str) -> None:
-    with StorageSupplier(from_storage_mode) as from_storage, StorageSupplier(
-        to_storage_mode
-    ) as to_storage:
+    with (
+        StorageSupplier(from_storage_mode) as from_storage,
+        StorageSupplier(to_storage_mode) as to_storage,
+    ):
         from_study = create_study(storage=from_storage, directions=["maximize", "minimize"])
         from_study._storage.set_study_system_attr(from_study._study_id, "foo", "bar")
         from_study.set_user_attr("baz", "qux")
@@ -498,9 +499,10 @@ def test_copy_study(from_storage_mode: str, to_storage_mode: str) -> None:
 @pytest.mark.parametrize("from_storage_mode", STORAGE_MODES)
 @pytest.mark.parametrize("to_storage_mode", STORAGE_MODES)
 def test_copy_study_to_study_name(from_storage_mode: str, to_storage_mode: str) -> None:
-    with StorageSupplier(from_storage_mode) as from_storage, StorageSupplier(
-        to_storage_mode
-    ) as to_storage:
+    with (
+        StorageSupplier(from_storage_mode) as from_storage,
+        StorageSupplier(to_storage_mode) as to_storage,
+    ):
         from_study = create_study(study_name="foo", storage=from_storage)
         _ = create_study(study_name="foo", storage=to_storage)
 
diff --git a/tests/trial_tests/test_trial.py b/tests/trial_tests/test_trial.py
--- a/tests/trial_tests/test_trial.py
+++ b/tests/trial_tests/test_trial.py
@@ -241,9 +241,12 @@ def test_suggest_discrete_uniform(storage_mode: str) -> None:
 @pytest.mark.filterwarnings("ignore::FutureWarning")
 @pytest.mark.parametrize("storage_mode", STORAGE_MODES)
 def test_suggest_low_equals_high(storage_mode: str) -> None:
-    with patch.object(
-        distributions, "_get_single_value", wraps=distributions._get_single_value
-    ) as mock_object, StorageSupplier(storage_mode) as storage:
+    with (
+        patch.object(
+            distributions, "_get_single_value", wraps=distributions._get_single_value
+        ) as mock_object,
+        StorageSupplier(storage_mode) as storage,
+    ):
         study = create_study(storage=storage, sampler=samplers.TPESampler(n_startup_trials=0))
 
         trial = study.ask()
@@ -314,9 +317,10 @@ def test_suggest_discrete_uniform_range(storage_mode: str, range_config: dict[st
     # Check upper endpoints.
     mock = Mock()
     mock.side_effect = lambda study, trial, param_name, distribution: distribution.high
-    with patch.object(sampler, "sample_independent", mock) as mock_object, StorageSupplier(
-        storage_mode
-    ) as storage:
+    with (
+        patch.object(sampler, "sample_independent", mock) as mock_object,
+        StorageSupplier(storage_mode) as storage,
+    ):
         study = create_study(storage=storage, sampler=sampler)
         trial = study.ask()
 
@@ -330,9 +334,10 @@ def test_suggest_discrete_uniform_range(storage_mode: str, range_config: dict[st
     # Check lower endpoints.
     mock = Mock()
     mock.side_effect = lambda study, trial, param_name, distribution: distribution.low
-    with patch.object(sampler, "sample_independent", mock) as mock_object, StorageSupplier(
-        storage_mode
-    ) as storage:
+    with (
+        patch.object(sampler, "sample_independent", mock) as mock_object,
+        StorageSupplier(storage_mode) as storage,
+    ):
         study = create_study(storage=storage, sampler=sampler)
         trial = study.ask()
 
@@ -384,9 +389,10 @@ def test_suggest_int_range(storage_mode: str, range_config: dict[str, int]) -> N
     # Check upper endpoints.
     mock = Mock()
     mock.side_effect = lambda study, trial, param_name, distribution: distribution.high
-    with patch.object(sampler, "sample_independent", mock) as mock_object, StorageSupplier(
-        storage_mode
-    ) as storage:
+    with (
+        patch.object(sampler, "sample_independent", mock) as mock_object,
+        StorageSupplier(storage_mode) as storage,
+    ):
         study = create_study(storage=storage, sampler=sampler)
         trial = study.ask()
 
@@ -400,9 +406,10 @@ def test_suggest_int_range(storage_mode: str, range_config: dict[str, int]) -> N
     # Check lower endpoints.
     mock = Mock()
     mock.side_effect = lambda study, trial, param_name, distribution: distribution.low
-    with patch.object(sampler, "sample_independent", mock) as mock_object, StorageSupplier(
-        storage_mode
-    ) as storage:
+    with (
+        patch.object(sampler, "sample_independent", mock) as mock_object,
+        StorageSupplier(storage_mode) as storage,
+    ):
         study = create_study(storage=storage, sampler=sampler)
         trial = study.ask()
 
EOF_114329324912

# Set environment variables (already set in Dockerfile, but ensuring they're set)
export SQLALCHEMY_WARN_20=1
export OMP_NUM_THREADS=1

# Run the target test files with controlled parallelism (max 4 processes for safety)
pytest \
  optuna/testing/storages.py \
  tests/gp_tests/test_batched_lbfgsb.py \
  tests/samplers_tests/test_cmaes.py \
  tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py \
  tests/samplers_tests/tpe_tests/test_truncnorm.py \
  tests/storages_tests/journal_tests/test_journal.py \
  tests/study_tests/test_study.py \
  tests/trial_tests/test_trial.py \
  -m "not slow" \
  -n 4 \
  -v --color=yes --tb=short

rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 90a0b791c3e9398f4eaba5066a3b48cbeda72a95 "optuna/testing/storages.py" "tests/gp_tests/test_batched_lbfgsb.py" "tests/samplers_tests/test_cmaes.py" "tests/samplers_tests/tpe_tests/test_multi_objective_sampler.py" "tests/samplers_tests/tpe_tests/test_truncnorm.py" "tests/storages_tests/journal_tests/test_journal.py" "tests/study_tests/test_study.py" "tests/trial_tests/test_trial.py"