# SWE-Cascade

A multilingual, SWE-bench–style benchmark for building instances, running tests in Docker, scoring model-generated patches, and analyzing outcomes. End-to-end story: collect commits from GitHub → format evaluation instances → run tests in containerized environments → apply patches → parse logs for pass/fail.

---

## `src/`

All code for this repository lives under `src/`.

### `pipeline/`

- **`bulk_collect.py`**: Batch driver that applies the collection stack (language, stars, license filters, etc.) until enough commits are gathered.
- **`collection/`**: Single-repository data pipeline. See [`src/pipeline/collection/README.md`](src/pipeline/collection/README.md) for CLI usage and environment variables. `curl_data.py` is the main entry; it chains commit fetching and formatting. `curl_commits.py` pulls history, languages, and CI signals via GraphQL/REST and filters candidates. `format_data.py` turns commit/PR metadata into instance records (PR linkage, patch assembly, optional LLM steps).

### `evaluation/`

- **`harness/`**: Core harness. `constants.py` defines instance field names and parse-status constants; `utils.py` has helpers (e.g. stripping ANSI escapes); `test_run.py` runs Docker/subprocess tests and aggregates pass rates; `log_parsers/` registers per-language parsers (Python, Java, Go, C, C++, Rust, TypeScript).
- **`log_parse.py`**: Runs the harness log parser on a single harness JSON record.
- **`parse_pass_rate.py`**: Reuses log parsers offline from `pass_rate.json` stdout without a full `test_run`.
- **`reapply_log_parser.py`**: Re-runs log parsers on harness or pass-rate JSON by language.

---

## Benchmark

**`swe-cascade.json`** in the repository root contains all 196 instances.

Each record includes: `instance_id`, `repo`, `base_commit`, `environment_setup_commit`, `patch`, `test_patch`, `problem_statement`, `hints_text`, `created_at`, `language`, `image_name`, and `working_dir`. Some instances also include `pull_number` or `issue_numbers` when that metadata is available.