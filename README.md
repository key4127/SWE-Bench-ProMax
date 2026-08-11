# SWE-Bench-ProMax

SWE-Bench-ProMax is a multi-language benchmark for repository-level software issue resolution. Each instance provides a task description, repository metadata, a reference patch, an evaluation test patch, and container-oriented metadata for running patch-based checks.

SWE-Bench-ProMax has been accepted to COLM 2026.

## Repository Contents

- `swe-bench-promax.json`: benchmark instances.
- `data/eval.json`: evaluation scripts keyed by `instance_id`.
- `src/evaluation/test_run.py`: Docker-based evaluation runner for model patches.
- `src/pipeline/`: data collection utilities used to build the benchmark.

## Dataset Summary

- **Total instances**: 170
- **Programming languages**: C, C++, Go, Java, Python, Rust, TypeScript
- **Main split**: `test`
- **Primary data file**: `swe-bench-promax.json`
- **Evaluation metadata**: `data/eval.json`, keyed by `instance_id`

## Language Coverage

| Language | Instances |
| --- | ---: |
| C | 20 |
| C++ | 22 |
| Go | 23 |
| Java | 26 |
| Python | 29 |
| Rust | 22 |
| TypeScript | 28 |

## Quick Start

Load the benchmark records from the local JSON file:

```python
import json

with open("swe-bench-promax.json", encoding="utf-8") as f:
    dataset = json.load(f)

print(len(dataset))
print(dataset[0]["instance_id"])
```

Load the evaluation metadata:

```python
import json

with open("data/eval.json", encoding="utf-8") as f:
    eval_metadata = json.load(f)

first_instance_id = next(iter(eval_metadata))
print(first_instance_id)
print(eval_metadata[first_instance_id]["eval_script"])
```

## Evaluation

The evaluation runner compares model patches against the reference patches and writes a pass-rate report. It expects Docker to be available because each instance is evaluated inside its task container.

Prepare a predictions file such as `preds.json`:

```json
[
  {
    "instance_id": "example_instance_id",
    "model_patch": "diff --git ..."
  }
]
```

Run the evaluator:

```bash
python src/evaluation/test_run.py \
  --pred ./preds.json \
  --golden ./swe-bench-promax.json \
  --eval ./data/eval.json \
  --output ./pass_rate.json \
  --workers 1
```

Use `--workers` to evaluate multiple instances in parallel. Add `--cleanup` if you want the runner to remove Docker images after evaluation.

## Data Structure

Each benchmark record includes the core fields below:

- `instance_id`: unique identifier for the task.
- `repo`: GitHub repository in `owner/name` form.
- `language`: primary programming language for the task.
- `problem_statement`: natural-language issue or task description.
- `hints_text`: optional guidance associated with the task.
- `base_commit`: repository commit before the target fix.
- `environment_setup_commit`: commit used for environment preparation.
- `patch`: reference solution patch.
- `test_patch`: test patch used during evaluation.
- `image_name`: container image name for the task environment.
- `working_dir`: repository path inside the evaluation environment.
- `created_at`: source timestamp as Unix seconds.

Each `data/eval.json` entry is keyed by the same `instance_id` and contains:

- `instance_id`: matching benchmark instance identifier.
- `eval_script`: shell script used to run the task-specific evaluation.

## Data Collection

The collection utilities live under `src/pipeline/`. See `src/pipeline/collection/README.md` for the collection workflow and required environment variables.
