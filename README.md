# SWE-Cascade

多语言 SWE-bench 风格代码评测基准的构建、评测与分析项目。核心流程：GitHub 爬取 commit → 格式化为评测实例 → Docker 环境运行测试 → 模型生成 patch → 评估通过率 → 统计分析与可视化。

整个流程中，使用过四版 problem_statement：
- **v0**：原始的 commit message
- **v1**：LLM 重写，分为 prd（markdown）格式和自然语言两种。prd 在 v2/3 中弃用
- **v2**：对 v1 的自然语言版本进行了扩充，解决了过宽过窄测试问题
- **v3**：对 v2 的 problem_statement 做了模糊处理，提高难度（效果不佳，暂未启用）

---

# src

存放项目中所有代码。

### `pipeline/`

- **`bulk_collect.py`**：按语言、star、许可证等条件批量调用 `collection` 中的爬取与格式化逻辑，直至收集足够数量的 commit。
- **`collection/`**：单仓库数据 pipeline（说明见该目录 `README.md`）。`curl_data.py` 为 CLI 入口，串联 commit 拉取与格式化；`curl_commits.py` 通过 GraphQL/REST 拉取提交历史、语言、CI 状态并做筛选；`format_data.py` 将 commit/PR 信息整理为实例化记录（含 PR 关联、patch 拼装、可选 LLM 步骤）。

### `evaluation/`

- **`harness/`**：核心评测框架。`constants.py` 定义实例字段名与解析状态常量；`utils.py` 提供工具函数（如去除 ANSI 转义）；`test_run.py` 负责 Docker/子进程跑测、汇总 pass 率；`log_parsers/` 下按语言（python / java / go / c / cpp / rust / typescript）注册日志解析函数。
- **`log_parse.py`**：对 harness 结果 JSON 中的单条记录调用 log parser，得到结构化测试结论。
- **`parse_pass_rate.py`**：从 `pass_rate.json` 的 stdout 离线复用 log_parsers（不启动完整 `test_run` 流程）。
- **`reapply_log_parser.py`**：按语言对 harness/pass_rate JSON 重跑 log parser。

### `analysis/`

- **`analyze_preds_by_opus.py`**：用 Claude/OPUS API 逐步分析 agent 轨迹，标注能力标签与成败原因。
- **`analyze_kimi_traj_failure_opus.py`**：用 Opus 专门分析 Kimi 模型的失败案例。
- **`analyze_pass_diff_by_problem_statement_v2_v3.py`**：对比 v2/v3 描述与通过率差异。
- **`annotate_pass_traj_capabilities.py`**：对通过的轨迹做能力标注。
- **`annotate_bash_only_pass_traj_capabilities.py`**：对纯 bash 通过的轨迹标注能力。
- **`annotate_instance_reasoning_capabilities.py`**：对实例标注所需推理能力。
- **`merge_pass_traj_phases.py`**：合并轨迹的分阶段标注结果。
- **`build_basic_from_harness.py`**：与指定 harness 结果求交生成 baseline JSON。
- **`categorize_task_by_llm.py`**：用 LLM 对 patch + problem_statement 做多标签任务分类。
- **`categorize_tasks.py`**：通过 HTTP Chat Completions 对数据集做 LLM 分类。
- **`check_problem_statement_required_content_v3.py`**：检查 v3 描述是否包含必要内容。
- **`check_problem_statement_test_patch_alignment_v3.py`**：检查 v3 描述与 test patch 的对齐性。
- **`compare_pass_rate.py`**：对比两份 pass 结果并导出差异条目。
- **`wide_or_narrrow_or_fuzzy/`**：测试过宽/过窄自动评判子目录。
  - `judge_patch.py` / `judge_patch_fail_only.py` / `judge_patch_fail_only_v2_retry.py` / `judge_patch_overwide_retry.py`：LLM 判断 test patch 合理性的各版本。
  - `explain_over_narrow_test_patch.py` / `explain_over_narrow_retry_failed.py`：解释过窄测试的原因。
  - `build_narrow_stat.py` / `merge_fail_over_narrow.py` / `output_narrow_len_all.py` / `stat_judge.py`：对 judge 输出做聚合统计。

### `strengthen/`

- **`enhance_problem_statement.py`**：调用 LLM 生成/增强自然语言问题描述（v1）。
- **`enhance_problem_statement_v2.py`**：v2 版本增强，解决过宽/过窄问题。
- **`fuzzy_problem_statement.py`**：由 v2 生成 v3 fuzzy 版，提高难度。
- **`update_loc_in_jsons.py`**：递归扫描含 `loc` 的 JSON 并重算 loc/文件统计。

### `figures/`

- **`data_for_fig/`**：供绘图使用的静态数据 JSON（`model_stats.json`、`language.json`、`benchmark_detail.json`、`model_pass_rate.json`、`cdf/` 下各基准数据）。
- **`plot_pass_rate_bar.py`**：pass 率柱状图。
- **`plot_pass_rate_comparison.py`**：pass 率对比图。
- **`plot_cdf_single.py`**：单张 CDF 图。
- **`plot_cdf_4subplots.py`**：4 子图 CDF。
- **`plot_cdf_gold_vs_model_files.py`**：gold patch 与模型修改文件数的 CDF 对比。
- **`plot_language_pie.py`**：语言分布饼图。
- **`plot_polar_language_comparison.py`**：极坐标语言对比图。
- **`plot_repo_pass_rate.py`**：仓库级 pass 率图。
- **`plot_traj_steps_hist.py`**：轨迹步数分布直方图。
- **`plot_steps_by_status.py`**：按通过/失败分组的步数图。
- **`plot_multi_model_comparison.py`**：多模型对比图。
- **`plot_model_pass_rate.py`**：模型通过率图。
- **`plot_model_stats.py`**：模型调用/成本统计图。
- **`plot_benchmark.py`**：对比多个 benchmark 的 loc 与修改文件数。
- **`plot_categorization.py`**：类别分布、多标签数量、能力分布与共现热力图。
- **`stat_preds.py`** / **`stat_preds_cdf.py`** / **`stat_breakdown_side_by_side.py`**：preds 的 LOC/文件数 breakdown、CDF、并列 PDF 图。

### `stat/`

- **`stat_by_language.py`**：按 batch/语言统计成功数与成功率。
- **`stat_env_resolve_by_lang.py`**：各语言环境 resolve 成功率。
- **`stat_passed_by_num_files.py`**：按修改文件数分桶统计通过实例。
- **`stat_traj_steps_by_pass.py`**：按通过/失败分组统计轨迹 assistant 步数。
- **`generate_model_stats.py`**：从 preds 目录汇总 API 调用与 cost，写入 `figures/data_for_fig/model_stats.json`。
- **`count_language_instances.py`**：按语言计数实例。
- **`github_files_num_stat.py`**：统计 commit 涉及文件数分布。
- **`scale_min_repo_stars.py`**：汇总各 batch 出现仓库的 star 并求语言内最低 star。
- **`stat_raw_language.py`**：统计原始数据的语言分布。
- **`compare_problem_statement_len_v2_v3.py`**：对比 v2/v3 问题描述长度。

### `filters/`

- **`docker_filter.py`**：将 resolve 实例 ID 与 commits/pulls 对齐输出。
- **`filter_multi_from_swt-refactor.py`**：从含 `diffLocations` 的结构中筛多文件重构。
- **`extract_swe_format_from_preds.py`**：按 preds 中的 instance_id 导出 swe-format。
- **`exclude_instances.py`**：对 pass_rate 统计时排除写死的 discard instance_id。
- **`remove_discard_instances.py`**：从 JSON 剔除 `discard==true` 的实例。
- **`collect_strengthen_eval_golden.py`**：按 strengthen 列表从 eval/swe-format 拼出评估与 golden JSON。
- **`filter_low_loc_and_files.py`**：按语言去掉 loc/num_files 最低的若干实例。
- **`sample_by_language.py`**：按语言抽样实例。

### `docker_related/`

- **`generate_dockerfile.py`**：从 docker 配置 JSON 为每个通过实例写出 Dockerfile。
- **`generate_eval_file.py`**：写出 per-instance 评测 shell 脚本。
- **`filter_docker_pass.py`**：按 resolved 列表从 scale 结果中筛出 golden JSON。
- **`build_push_docker.py`**：遍历目录内 Dockerfile 执行 build/push/rmi。
- **`add_workdir_from_dockerfile.py`**：从 Dockerfile 解析 WORKDIR 写回 JSON。

### `collection_related/`

- **`collect_batch_results.py`**：扫描 batch 目录，合并各类 JSON 为 result/raw/detail 文件。
- **`fetch_the_same_jsons.py`**：递归合并目录下指定后缀的 JSON。
- **`merge_batches.py`**：合并多份 batch 结果 JSON。
- **`merge_gemini_limit.py`**：按 preds 是否在集合内合并 gemini 与 gemini_limit_origin 条目。
- **`random_select.py`**：随机抽取若干 html_url。
- **`remove_commits.py`**：按键值过滤 JSON 数组。
- **`split_result.py`**：将较大 result.json 按固定条数切分。

### `result_related/`

- **`merge_swe_detail.py`**：将 swe-format 与 detail.json 按 base_commit 对齐合并，统计 loc/文件数。
- **`collect_qualified_instances.py`**：从各模型 harness 结果按规则筛选并合并合格实例。

### `ui/`

- **`app.py`**：Gradio 应用，加载数据集，与 SWE-bench Verified/Pro 对照，loc/修改文件数统计，读写 `annotations.json` 做人工标注。
- **`merge_data.py`**：合并 `raw_data.jsonl` 与 merged JSON，生成 `raw_latest.json`。
- **`merge_to_json.py`**：旧数据合并脚本。
- **`data_inspector.py`**：Streamlit 应用，合并 golden/eval/swe-format 做人工检查。
- **`data/`**：UI 所需的输入/中间数据文件（`annotations.json`、`raw_latest.json`、`swebench_pro.json` 等）。

---

# swe-cascade

数据集各版本的最终产出，每个 JSON 含 299 条实例，字段包括 `instance_id`、`repo`、`base_commit`、`patch`、`test_patch`、`problem_statement`、`hints_text`、`language`、`image_name`、`loc`、`num_files` 等。其中 `discard=true` 的数据被忽略，不计入最终基准。

| 文件 | 说明 | discard 数 | 有效实例 |
|---|---|---|---|
| `v1_mkd.json` | v1 problem_statement，markdown/PRD 格式 | 0 | 299 |
| `v1_nl.json` | v1 problem_statement，自然语言格式 | 0 | 299 |
| `v2.json` | v2 对 v1 自然语言扩充，解决过宽/过窄问题 | 103 | 196 |
| `v3.json` | v3 对 v2 做模糊处理提高难度（暂未启用） | 103 | 196 |

---

# result

存放各类测试结果，包含分析结果、模型预测结果和重新评测的 harness 结果。

### `analysis_result/` — 分析结果

- **`v1/explain_over_narrow_result.json`**：v1 过窄测试的解释结果。
- **`v2/test/judge_result.json`**：v2 test patch 合理性的 LLM 判断结果。
- **`v2/test/judge_fail_only_result_v2.json`**：v2 仅失败案例的判断结果。
- **`v2/stat/narrow_stat.json`**：v2 过窄统计。
- **`v2/stat/narrow_len_all.json`**：v2 过窄长度统计。
- **`v2/narrow_stat_v2.json`**：v2 过窄统计（另一版本）。
- **`v2/success_swe_stat.json`**：v2 成功实例的 SWE 统计。
- **`v3/categorization_results.json`**：v3 任务分类结果。
- **`v3/problem_statement_required_content_check.json`**：v3 描述必要内容检查。
- **`v3/problem_statement_test_patch_alignment_check.json`**：v3 描述与 test patch 对齐检查。
- **`v3/kimi_fail_traj_opus_analysis.jsonl`**：用 Opus 分析 Kimi 失败轨迹。

### `preds_result/` — 模型预测结果

每个模型目录下按 `instance_id` 分子文件夹，包含 `*.traj.json`（agent 轨迹）和 `preds.json`（预测 patch 汇总），含在原始机器上的 pass_rate（可能有误）。

### `harness_result/` — 重新评测的 pass rate

其中某些pass_rate是由之前版本的harness计算的，可能不会特别精确。

---

# data

存放数据集构建各阶段数据，均按 `batch1`~`batch5` 分批存放。

| 目录 | 说明 |
|---|---|
| `raw_file/` | **最初从 GitHub 爬取的原始数据**（`detail.json`、`raw.json`、`result.json` 等），是整个流水线的起点 |
| `dockerfile/` | 由 swe-factory 生成的 per-instance Dockerfile，用于构建评测 Docker 镜像 |
| `docker_metadata/` | 由 swe-factory 生成的 Docker 元数据（`merged_docker_config_report.json`、`resolved_commits.json`、`resolved_instances.json` 等） |
| `test_scripts/` | 由 swe-factory 生成的 per-instance 测试脚本（`.sh` 文件），在 Docker 容器中运行评测 |
