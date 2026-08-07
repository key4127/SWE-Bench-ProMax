# SWE-Cascade

A multilingual, SWE-bench style benchmark for building instances, running
tests in Docker, scoring model-generated patches, and analyzing outcomes.

## Data

`swe-cascade.json` contains the benchmark instances. Its content is updated
from `../swe-cascade/handout/data/swe-cascade-pure.json`.

`data/eval.json` contains the evaluation bundle updated from
`../swe-cascade/handout/data/eval.json`. It is keyed by `instance_id`; each
entry contains the Docker/evaluation metadata used by the harness, including
`eval_script`.

The current benchmark contains 170 instances. The eval bundle is filtered to
the same 170 `instance_id` values.

## Evaluation

Evaluation code lives under `src/evaluation`.

Evaluate model predictions:

```bash
python3 -B src/evaluation/harness/test_run.py \
  --pred /abs/path/to/preds.json \
  --golden swe-cascade.json \
  --eval data/eval.json \
  --output /abs/path/to/pass_rate.json \
  --workers 2
```

Run the base commit / base image check without applying model patches:

```bash
python3 -B src/evaluation/check_base_pass.py \
  --benchmark swe-cascade.json \
  --eval data/eval.json \
  --output result/base_pass_results.json \
  --workers 2
```

By default, base checks only use local Docker images. Add `--pull` to allow the
script to pull missing images.

The original collection utilities remain under `src/pipeline`.
