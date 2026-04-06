# SWE-Cascade

A multilingual, SWE-bench–style benchmark for building instances, running tests in Docker, scoring model-generated patches, and analyzing outcomes. End-to-end story: collect commits from GitHub → format evaluation instances → run tests in containerized environments → apply patches → parse logs for pass/fail.

Across the pipeline we used four generations of `problem_statement`:

- **v0**: raw commit message
- **v1**: LLM-rewritten text, in both PRD-style markdown and plain natural language (PRD-style was dropped in later stages)
- **v2**: expanded from the v1 natural-language form to reduce overly broad or narrow tests
- **v3**: intentionally fuzzed v2 statements to raise difficulty (experimental; not enabled by default)

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

## `swe-cascade/`

Released dataset JSON files. Each file has **299** rows. Typical fields include `instance_id`, `repo`, `base_commit`, `patch`, `test_patch`, `problem_statement`, `hints_text`, `language`, `image_name`, `loc`, `num_files`, and related metadata.

**Current benchmark:** use **`v2.json` excluding rows with `discard: true`**—that is the active evaluation split (**196** instances). Other files are for ablations or archival comparison; `v3.json` remains experimental and is not the default.

| File | Description | `discard` count | Effective instances |
| --- | --- | --- | --- |
| `v1_mkd.json` | v1 `problem_statement`, PRD-style markdown | 0 | 299 |
| `v1_nl.json` | v1 `problem_statement`, natural language | 0 | 299 |
| `v2.json` | v2 expansion of v1 NL (addresses broad/narrow tests) | 103 | 196 |
| `v3.json` | v3 fuzzed v2 (experimental; not enabled by default) | 103 | 196 |
