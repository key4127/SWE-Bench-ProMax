# `src/` 脚本分类（仅文档，不移动文件）

## 你要用这份文档干什么

按**职责 / 工作流**找入口：同一类事涉及的脚本可能分散在 `origin/deploy/`、`origin/for_agent/`、`collection_related/` 等不同目录里，**本来就应该跨目录归到同一节**，方便回答「我要做 X，该开哪些脚本」，而不是「这个文件夹里都有啥」。

目录结构可以长期不变；分类是**逻辑上的**，与磁盘文件夹是否同名、是否在同一棵子树无关。

以下 **`pipeline/`**、**`evaluation/`** 仍按你的约定单独列出，不在前面各节里细拆。


## 1. 数据采集与 GitHub 辅助（非 pipeline）

`collection_related/` 里部分脚本偏**统计**或**按 instance 合并 harness JSON**，已分列 §5、§6；本节只保留「拉数、并文件、抽样、按字段删行」一类。

| 脚本（相对 `src/`） |
|---------------------|
| `collection_related/fetch_the_same_jsons.py` |
| `collection_related/remove_commits.py` |
| `collection_related/random_select.py` |
| `origin/tmp/scripts/fetch_the_same_jsons.py` |
| `origin/tmp/scripts/split_result.py` |
| `origin/tmp/scripts/collect_batch_results.py` |

---

## 2. 从 Issue/PR 构建实例与发布（Deploy 管线）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/deploy/get_issues.py` |
| `origin/deploy/get_pr.py` |
| `origin/deploy/get_issue_detail.py` |
| `origin/deploy/get_raw.py` |
| `origin/deploy/extract_test_patch.py` |
| `origin/deploy/generate_hints_text.py` |
| `origin/deploy/filter_result.py` |
| `origin/deploy/update_value.py` |
| `origin/deploy/add_value.py` |
| `origin/deploy/handle_issue.py` |
| `origin/deploy/test_patch.py` |
| `origin/deploy/change_date_type.py` |
| `origin/deploy/build_push_docker.py` |

---

## 3. 过滤、清洗与格式转换（Filters）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/filters/detail_filter.py` |
| `origin/filters/docker_filter.py` |
| `origin/filters/result_filter.py` |
| `origin/filters/test_filter.py` |
| `origin/filters/github_refactor_filter.py` |
| `origin/filters/extract_swe_format_from_preds.py` |
| `origin/filters/filter_multi_from_swt-refactor.py` |
| `origin/filters/final/stat_pass_rate_from_a_txt.py` |
| `origin/filters/final/stat_pass_rate_exclude_discard.py` |
| `origin/filters/final/exclude_instances.py` |
| `origin/filters/final/reapply_log_parser.py` |
| `origin/filter/final/remove_discard_instances.py` |

---

## 4. 面向评测 / Agent 的产物（常与 Deploy 配合，路径分散）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/for_agent/add_value.py` |
| `origin/for_agent/filter_docker_pass.py` |
| `origin/for_agent/generate_dockerfile.py` |
| `origin/for_agent/generate_eval_file.py` |
| `origin/for_agent/add_workdir_from_dockerfile.py` |
| `origin/for_agent/stat_data.py` |

（与实例字段、Docker、评测 JSON 相关的脚本在 `deploy/` 与 `for_agent/` 两侧都有，按任务跨目录一起用即可。）

---

## 5. 结果合并、元数据与实例汇总（Result）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/result/merge_swe_detail.py` |
| `origin/result/json_to_jsonl.py` |
| `origin/result/update_loc_in_jsons.py` |
| `origin/result/filter_low_loc_and_files.py` |
| `origin/result/extract_instance_ids.py` |
| `origin/result/count_language_instances.py` |
| `origin/result/collect_qualified_instances.py` |
| `collection_related/merge_gemini_limit.py` |

（**collection_related/merge_gemini_limit.py**：按 preds 中的 `instance_id` 在两份 harness JSON 间择条合并，属结果拼装而非爬虫。）

---

## 6. 统计与模型侧分析（数字表 / 报告，非作图）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/stat/stat_by_language.py` |
| `origin/stat/stat_traj_steps_by_pass.py` |
| `origin/stat/stat_passed_by_num_files.py` |
| `origin/stat/stat_env_resolve_by_lang.py` |
| `origin/stat/analyze_preds_by_opus.py` |
| `origin/stat/generate_model_stats.py` |
| `collection_related/github.py` |
| `collection_related/compare_pass_rate.py` |
| `collection_related/scale_min_repo_stars.py` |

说明（避免与同目录其它脚本混淆）：

- **collection_related/github.py**：名不副实，实为读 commit JSON，**统计每条涉及文件数**（均值、中位数、最值等），无 GitHub API。
- **collection_related/compare_pass_rate.py**：对比两份 pass_rate JSON（互斥通过集、可写出差集）。
- **collection_related/scale_min_repo_stars.py**：扫各 batch 的 `result.json` 汇总仓库，调 GitHub API 取 star，按语言给出**最低 star 等汇总**（偏报表/阈值摸底，与 pipeline 大规模采集不同用途）。

---

## 7. 图表与可视化（Figures）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/image/plot_benchmark.py` |
| `origin/image/plot_cdf_single.py` |
| `origin/image/plot_cdf_4subplots.py` |
| `origin/image/plot_cdf_gold_vs_model_files.py` |
| `origin/image/plot_language_pie.py` |
| `origin/image/plot_model_stats.py` |
| `origin/image/plot_model_pass_rate.py` |
| `origin/image/plot_multi_model_comparison.py` |
| `origin/image/plot_pass_rate_bar.py` |
| `origin/image/plot_pass_rate_comparison.py` |
| `origin/image/plot_polar_language_comparison.py` |
| `origin/image/plot_repo_pass_rate.py` |
| `origin/image/plot_resolution.py` |
| `origin/image/plot_results_comparison.py` |
| `origin/image/plot_steps_by_status.py` |
| `origin/image/plot_traj_steps_cdf.py` |
| `origin/image/plot_traj_steps_hist.py` |
| `vis/categorize/plot_categorization.py` |
| `origin/yl_ui/stat_preds.py` |
| `origin/yl_ui/stat_preds_cdf.py` |
| `origin/yl_ui/stat_breakdown_side_by_side.py` |

---

## 8. 任务分类与 LLM 标注（Categorization）

| 脚本（相对 `src/`） |
|---------------------|
| `vis/categorize/categorize_task_by_llm.py` |
| `origin/yl_ui/categorize_tasks.py` |

---

## 9. 交互式浏览与数据合并（UI / Ops）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/yl_ui/app.py` |
| `origin/yl_ui/merge_data.py` |
| `origin/yl_ui/old/data_inspector.py` |
| `origin/yl_ui/old/merge_to_json.py` |

---

## 10. 测试补丁判定与通过批次（Test / Patch）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/test/patch/judge_patch.py` |
| `origin/test/patch/judge_patch_fail_only.py` |
| `origin/test/patch/judge_patch_fail_only_v2_retry.py` |
| `origin/test/patch/judge_patch_overwide_retry.py` |
| `origin/test/patch/explain_over_narrow_test_patch.py` |
| `origin/test/patch/explain_over_narrow_retry_failed.py` |
| `origin/test/patch/build_narrow_stat.py` |
| `origin/test/patch/build_success_swe_stat.py` |
| `origin/test/patch/add_language_to_narrow_stat.py` |
| `origin/test/patch/add_language_to_judge_fail_only_v2.py` |
| `origin/test/patch/stat_judge.py` |
| `origin/test/patch/merge_fail_over_narrow.py` |
| `origin/test/patch/output_narrow_len_all.py` |
| `origin/test/pass/stat_pass.py` |
| `origin/test/pass/stat_pass_server.py` |
| `origin/test/pass/merge_batches.py` |

---

## 11. 强化数据与 problem statement 实验（Tmp / strengthen）

| 脚本（相对 `src/`） |
|---------------------|
| `origin/tmp/strengthen/annotate_bash_only_pass_traj_capabilities.py` |
| `origin/tmp/strengthen/annotate_pass_traj_capabilities.py` |
| `origin/tmp/strengthen/annotate_instance_reasoning_capabilities.py` |
| `origin/tmp/strengthen/merge_pass_traj_phases.py` |
| `origin/tmp/strengthen/analyze_kimi_traj_failure_opus.py` |
| `origin/tmp/strengthen/fuzzy_problem_statement_v3.py` |
| `origin/tmp/strengthen/sample_by_language.py` |
| `origin/tmp/strengthen/enhance_problem_statement.py` |
| `origin/tmp/strengthen/enhance_problem_statement_v2.py` |
| `origin/tmp/strengthen/compare_problem_statement_len_v2_v3.py` |
| `origin/tmp/strengthen/check_problem_statement_required_content_v3.py` |
| `origin/tmp/strengthen/check_problem_statement_test_patch_alignment_v3.py` |
| `origin/tmp/strengthen/analyze_pass_diff_by_problem_statement_v2_v3.py` |
| `origin/tmp/strengthen/build_basic_from_harness.py` |
| `origin/tmp/strengthen/collect_strengthen_eval_golden.py` |

---

## 12. Shell 辅助（非 `.py`）

| 文件（相对 `src/`） |
|---------------------|
| `origin/yl_ui/gen_nl_figs.sh` |
| `origin/tmp/strengthen/nl.sh` |
| `origin/tmp/strengthen/mkd.sh` |

---

## 13. Pipeline 与 Evaluation（单独约定）

| 脚本（相对 `src/`） |
|---------------------|
| `pipeline/bulk_collect.py` |
| `pipeline/collection/__init__.py` |
| `pipeline/collection/curl_commits.py` |
| `pipeline/collection/curl_data.py` |
| `pipeline/collection/format_data.py` |
| `evaluation/parse_pass_rate.py` |
| `evaluation/log_parse.py` |
| `evaluation/harness/__init__.py` |
| `evaluation/harness/log_parsers/__init__.py` |
| `evaluation/harness/constants.py` |
| `evaluation/harness/test_run.py` |
| `evaluation/harness/utils.py` |
| `evaluation/harness/log_parsers/c.py` |
| `evaluation/harness/log_parsers/cpp.py` |
| `evaluation/harness/log_parsers/go.py` |
| `evaluation/harness/log_parsers/java.py` |
| `evaluation/harness/log_parsers/python.py` |
| `evaluation/harness/log_parsers/rust.py` |
| `evaluation/harness/log_parsers/typescript.py` |

---

## 数据资产（非脚本）

各目录下的 `.json` / `.jsonl` / `origin/test/patch/tmp/` 等，如需与代码分离，可迁到仓库外或统一 `data/`、`artifacts/`。

---

## 路径参数化（备忘）

- 不少入口已支持 `argparse` 或环境变量（如 `origin/yl_ui/app.py` 的 `YL_UI_*`）。
- **`pipeline/`、`evaluation/`** 未做路径参数化改动。
- `origin/tmp/strengthen/`、`origin/test/patch/`、`vis/categorize/` 等仍有脚本以相对路径为默认，可通过 `--input` / `--output` 等覆盖。
