# SWE-Bench-ProMax

<p align="center">
  <a href="https://arxiv.org/abs/2608.09802"><img src="https://img.shields.io/badge/arXiv-2608.09802-b31b1b.svg" alt="arXiv"></a>
  <img src="https://img.shields.io/badge/COLM-2026-blue.svg" alt="COLM 2026">
  <img src="https://img.shields.io/badge/Languages-7-green.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Instances-170-orange.svg" alt="Instances">
</p>

**SWE-Bench-ProMax** is a multi-language benchmark for repository-level software issue resolution, accepted to **COLM 2026**. All task instances are collected from real-world GitHub issues created **after 2025**, substantially reducing the risk of training-data contamination for contemporary language models. Each instance provides a task description, repository metadata, a reference patch, an evaluation test patch, and container-oriented metadata for reproducible, patch-based evaluation.

We are actively maintaining this benchmark: a **v2 release is under preparation**, featuring a significantly larger set of tasks collected from issues created **after 2026**, and we will continue to refresh the benchmark over time to keep it contamination-resistant and up to date.

## 📰 News & Timeline

- **[Ongoing]** 🚧 **v2** in preparation — a larger-scale benchmark built from post-2026 issues, with continuous updates planned. **If you are interested in collaborating, we would love to hear from you** — feel free to reach out via [email](mailto:yuling.shi@sjtu.edu.cn) or open an issue.
- **[2026-07]** 🎉 SWE-Bench-ProMax is accepted to **COLM 2026**.
- **[2026-04]** ✅ Benchmark construction completed; dataset and evaluation harness released.

## Repository Contents

- `data/swe-bench-promax.json`: benchmark instances.
- `data/eval.json`: evaluation scripts keyed by `instance_id`.
- `src/evaluation/test_run.py`: Docker-based evaluation runner for model patches.
- `src/pipeline/`: data collection utilities used to build the benchmark.

## Dataset Summary

- **Total instances**: 170
- **Programming languages**: C, C++, Go, Java, Python, Rust, TypeScript
- **Issue creation date**: after 2025 (contamination-resistant by construction)
- **Main split**: `test`
- **Primary data file**: `data/swe-bench-promax.json`
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

with open("data/swe-bench-promax.json", encoding="utf-8") as f:
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
  --golden ./data/swe-bench-promax.json \
  --eval ./data/eval.json \
  --output ./pass_rate.json \
  --workers 1
```

Use `--workers` to evaluate multiple instances in parallel. Add `--cleanup` if you want the runner to remove Docker images after evaluation.

## Data Structure

Each benchmark record includes the core fields below:

| Field | Description |
| --- | --- |
| `instance_id` | Unique identifier for the task. |
| `repo` | GitHub repository in `owner/name` form. |
| `language` | Primary programming language for the task. |
| `problem_statement` | Natural-language issue or task description. |
| `hints_text` | Optional guidance associated with the task. |
| `base_commit` | Repository commit before the target fix. |
| `environment_setup_commit` | Commit used for environment preparation. |
| `patch` | Reference solution patch. |
| `test_patch` | Test patch used during evaluation. |
| `image_name` | Container image name for the task environment. |
| `working_dir` | Repository path inside the evaluation environment. |
| `created_at` | Source timestamp as Unix seconds. |

Each `data/eval.json` entry is keyed by the same `instance_id` and contains:

| Field | Description |
| --- | --- |
| `instance_id` | Matching benchmark instance identifier. |
| `eval_script` | Shell script used to run the task-specific evaluation. |

## Data Collection

The collection utilities live under `src/pipeline/`. See `src/pipeline/collection/README.md` for the collection workflow and required environment variables.

## Roadmap

- [x] v1 release: 170 instances across 7 languages, built from post-2025 issues.
- [ ] v2 release: larger-scale benchmark built from post-2026 issues.
- [ ] Continuous updates to keep the benchmark contamination-resistant.

## Citation

If you find SWE-Bench-ProMax useful, please cite:

```bibtex
@misc{shi2026swe,
      title={SWE-Bench ProMax: Benchmarking Agents on Large-Scale Multilingual Code Refactoring}, 
      author={Yuling Shi and Jinghan Xu and Kelin Fu and Wenhao Zeng and Shilin He and Lei Zhang and Yue Liu and Zelin Zhao and Terry Yue Zhuo and Jialun Cao and Siyu Ye and Tianyu Liu and Kai Cai and Shing-Chi Cheung and Xiaodong Gu},
      year={2026},
      eprint={2608.09802},
      archivePrefix={arXiv},
      primaryClass={cs.CL},
      url={https://arxiv.org/abs/2608.09802}, 
}
```
