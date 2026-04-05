# src

存放项目中所有代码。


### `pipeline/`

- **`bulk_collect.py`**：按语言、star、许可证等条件批量调用 `collection` 中的爬取与格式化逻辑，直至收集足够数量的 commit。
- **`collection/`**：单仓库数据pipeline（说明见该目录 **`README.md`**）。**`curl_data.py`**：CLI 入口，串联 commit 拉取与格式化。**`curl_commits.py`**：通过 GraphQL/REST 拉取提交历史、语言、CI 状态等并做筛选。**`format_data.py`**：将 commit/PR 信息整理为实例化记录（含 PR 关联、patch 拼装、可选 LLM 等步骤）。

### `evaluation/`

- **`harness/`**：评测 harness：**`constants.py`** 定义实例字段、解析状态等常量；**`utils.py`**（如去除 ANSI）；**`test_run.py`** 负责 Docker/子进程跑测、汇总 pass 率；**`log_parsers/`** 下按语言分文件，为各仓库注册测试日志解析函数。
- **`log_parse.py`**：对 harness 结果 JSON 中的单条记录套用 log parser，得到结构化测试结论。
- **`parse_pass_rate.py`**：仅从 `pass_rate.json` 等中的 stdout 离线复用 log_parsers（不启动完整 `test_run` 流程）。


# data

存放数据集构建各阶段数据；包含github获取的元数据、swe-factory中间结果等。

# result

存放各种测试结果：包含agent生成的preds result、评测产生的harness result和其它脚本测试结果等。

整个流程中，使用过四版problem_statement：
- v0：原始的commit message
- v1：llm重写，分为prd（markdown）格式和自然语言两种。prd在v2/3中弃用。
- v2：对v1的自然语言版本进行了扩充，解决了openai提到的过宽过窄测试问题。
- v3：对v2的problem statment做了模糊处理，提高难度（效果不佳，暂未启用）

preds_result存放model生成的patch及相关信息，包含在原始机器上的pass_rate（可能有误）。
harness_result存放重新评测后的pass_rate。

---

## src 子目录与脚本说明（增量追加）

以下仅描述仓库内 `src/` 下的代码目录与脚本用途；未改动上文「# src」「# data」「# result」各节的含义。




### `deploy/`

从 GitHub 与中间 JSON 构造/清洗部署用数据：**`get_issues.py`**、**`get_pr.py`**、**`get_issue_detail.py`** 拉取 PR/issue 详情；**`handle_issue.py`** 将 issue JSON 折叠为 `problem_statement` 与 `hints_text`；**`extract_test_patch.py`** 由 API 文件条目生成 unified diff；**`test_patch.py`** 用 `git apply --check` 校验 patch；**`get_raw.py`**、**`update_value.py`**、**`change_date_type.py`**、**`add_value.py`**、**`filter_result.py`** 等对字段做合并、删除、时间戳化、白名单字段导出；**`generate_hints_text.py`** 调用 DeepSeek 根据 message/patch 生成 hints；**`build_push_docker.py`** 遍历目录内 Dockerfile 执行 build/push/rmi（路径与镜像前缀在脚本内硬编码）。

### `scripts/`

GitHub 与结果文件的辅助工具：**`github.py`** 统计提交涉及文件数分布；**`fetch_commit.py`** 按 sha 拉取 commit JSON；**`curl_from_github.py`** GraphQL 分页拉取默认分支提交历史并可增量合并；**`curl_from_action.py`** 根据 Actions 运行结论过滤 CI；**`fetch_the_same_jsons.py`** 递归合并目录下指定后缀的 JSON；**`compare_pass_rate.py`** 对比两份 pass 结果并导出「仅一方通过」的条目；**`random_select.py`** 随机抽取若干 `html_url`；**`remove_commits.py`** 按键值过滤 JSON 数组；**`scale_min_repo_stars.py`** 汇总 scale 各 batch 出现仓库的 star 并求语言内最低 star；**`merge_gemini_limit.py`** 按 preds 是否在集合内合并 `gemini` 与 `gemini_limit_origin` 条目；**`stat_github_origin.py`** 当前为空实现占位。

### `result/`（指 `src/result/` 下的工具脚本，非仓库根目录 `result/` 数据文件夹）

面向统计产物的处理：**`merge_swe_detail.py`** 将 `data_for_agent/swe-format` 与 `scale/docker/.../detail.json` 按 `base_commit` 对齐合并，并统计 loc、文件数等；**`collect_qualified_instances.py`** 从各模型 harness 结果中按规则（如 C/C++ 或 golden 全通过）筛选并合并；**`json_to_jsonl.py`** 将 JSON 数组转为 JSONL；**`update_loc_in_jsons.py`** 递归扫描含 `loc` 的 JSON 并重算 loc/文件统计；**`filter_low_loc_and_files.py`** 按语言去掉 loc 与 `num_files` 最低的若干实例；**`extract_instance_ids.py`** 从各 batch 的 `raw.json` 生成 `id.json`；**`count_language_instances.py`** 按 `language` 计数。

### `stat/`

报表与轨迹分析：**`stat_by_language.py`** 结合 `scale/docker` 与 `auto_env_config_report` 按 batch、语言统计成功数与成功率；**`stat_env_resolve_by_lang.py`** 统计各语言环境 resolve 成功率；**`stat_passed_by_num_files.py`** 按 `num_files` 分桶统计 harness 通过实例数；**`stat_traj_steps_by_pass.py`** 统计 traj 中 assistant 步数并按是否通过分组绘图；**`generate_model_stats.py`** 从 preds 目录 traj 与 harness 汇总 api 调用与 cost，写入 `src/image/data/model_stats.json`；**`analyze_preds_by_opus.py`** 用 Claude/OPUS API 逐步分析轨迹并标注能力标签与成败因。

### `image/`

- **`data/`**：供绘图使用的静态 JSON（如 `model_stats.json`、`language.json`、`benchmark_detail.json`、`cdf/` 下各基准数据等）。
- **`plot_*.py`**：一组 `matplotlib` 脚本，生成 pass 率柱状/对比图、CDF（单图与子图）、语言饼图、极坐标对比、仓库 pass 率、轨迹步数分布、多模型对比等（数据路径多在脚本内或指向 `image/data`）。**`plot_benchmark.py`** 对比多个 benchmark 的 loc 与修改文件数。

### `filters/`

历史与流水线过滤：**`github_refactor_filter.py`** 按 commit message 是否含 refactor 过滤；**`detail_filter.py`** 按日期阈值过滤；**`docker_filter.py`** 将 resolve 实例 id 与 commits/pulls 对齐输出记录；**`filter_multi_from_swt-refactor.py`** 从含 `diffLocations` 的结构中筛多文件重构；**`test_filter.py`** 保留涉及路径含 `test` 的文件的提交；**`extract_swe_format_from_preds.py`** 按 preds 中的 `instance_id` 从增强集导出 swe-format 到 `data_for_agent/swe-format/<subdir>/`；**`result_filter.py`** 简单统计单父提交数量。**`final/exclude_instances.py`**：对 pass_rate 统计时排除脚本内写死的 discard `instance_id`；**`final/reapply_log_parser.py`**：按语言对 harness/pass_rate JSON 重跑 log parser；**`final/stat_pass_rate_from_a_txt.py`**：用根目录 `a.txt` 与 `all_nl_enhanced` 的 discard 信息计算通过率；**`final/stat_pass_rate_exclude_discard.py`**：读取 pass_rate 并排除 discard，可选排除空 `model_patch`。

### `filter/`

- **`final/remove_discard_instances.py`**：从 `all_nl_enhanced.json` 剔除 `discard==true` 的实例，输出新文件。

### `for_agent/`

生成评测与 Docker 相关产物：**`generate_dockerfile.py`** 从 docker 配置类 JSON 为每个通过实例写出 Dockerfile；**`generate_eval_file.py`** 写出 per-instance 评测 shell；**`filter_docker_pass.py`** 按 resolved 列表从 scale 结果中筛出 golden JSON；**`add_value.py`** 为 golden 补 `image_name`、`environment_setup_commit`、`PASS_TO_PASS`/`FAIL_TO_PASS` 等并写 swe-format；**`add_workdir_from_dockerfile.py`** 扫描 `dockerfile` 目录下 `*_Dockerfile` 解析 `WORKDIR` 写回 JSON；**`stat_data.py`** 含按 passes 合并报告的草稿逻辑（部分分支注释掉）。

### `categorize/`

- **`categorize_task_by_llm.py`**：用 LLM 对 patch + `problem_statement` 做多标签任务分类与推理能力标注（默认数据源为 strengthen v3 fuzzy 等）。
- **`plot_categorization.py`**：读取 `categorization_results.json` 绘制类别分布、多标签数量、能力分布与共现热力图。

### `test/pass/`

- **`stat_pass.py`**、**`stat_pass_server.py`**：不依赖完整 harness 包、以子进程+启发式规则解析测试输出的轻量统计脚本。
- **`merge_batches.py`**：合并多份 batch 结果 JSON。

### `test/patch/`

围绕「问题描述与 test patch 是否合理、测试过宽/过窄」的自动评判与二次统计（说明见该目录 **`README.md`**）：**`judge_patch.py`** 及 **`judge_patch_fail_only.py`**、**`judge_patch_fail_only_v2_retry.py`**、**`judge_patch_overwide_retry.py`** 等变体；**`explain_over_narrow_test_patch.py`**、**`explain_over_narrow_retry_failed.py`**；**`build_narrow_stat.py`**、**`build_success_swe_stat.py`**、**`add_language_to_narrow_stat.py`**、**`add_language_to_judge_fail_only_v2.py`**、**`merge_fail_over_narrow.py`**、**`output_narrow_len_all.py`**、**`stat_judge.py`** 等对 judge 输出聚合或按语言补全。子目录 **`tmp/`** 等为运行产生的中间文件（diff、json）。

### `yl_ui/`

- **`app.py`**：Gradio 应用：加载 `raw_latest.json`、与 SWE-bench Verified/Pro 数据对照、loc/修改文件数统计与小图，读写 **`annotations.json`** 做人工标注。
- **`merge_data.py`**：将 `raw_data.jsonl` 与 `swe-bench-promax-merged.json` 按 `instance_id` 合并额外字段，生成 `raw_latest.json`。
- **`categorize_tasks.py`**：通过 HTTP Chat Completions 对数据集做 LLM 分类（内含绝对路径配置，需按环境修改）。
- **`stat_preds.py`**、**`stat_preds_cdf.py`**、**`stat_breakdown_side_by_side.py`**：针对 strengthen 下 mkd/nlp preds 的 LOC、文件数 breakdown 与 CDF、并列 PDF 图。
- **`gen_nl_figs.sh`**：调用上述统计/绘图脚本的 shell。
- **`old/data_inspector.py`**：Streamlit 合并 `golden.json`/`eval.json`/swe-format 做人工检查；**`merge_to_json.py`** 等旧脚本；**`old/swe-format/`** 等为历史示例数据。
- 目录内 **`*.json`**、**`raw_data.jsonl`** 等为 UI 或统计脚本的输入/中间数据（非通用库代码）。

### `tmp/scripts/`

- **`split_result.py`**：将较大的 `result.json` 按固定条数切分为多个文件。
- **`collect_batch_results.py`**：扫描 batch 目录，将 `*_docker.json`、`raw_*`、其余 JSON 分别合并为 `result.json`、`raw*.json`、`detail*.json`（大列表按块拆分）。
- **`fetch_the_same_jsons.py`**：与 `scripts/fetch_the_same_jsons.py` 类似的合并逻辑副本。

### `tmp/strengthen/`

数据集强化与实验分析：**`enhance_problem_statement.py`**、**`enhance_problem_statement_v2.py`**：调用 OpenAI 兼容 API 生成/增强自然语言问题描述；**`fuzzy_problem_statement_v3.py`**：由 v2 增强集与 explain 字段生成 v3 fuzzy 版；**`check_problem_statement_test_patch_alignment_v3.py`**、**`check_problem_statement_required_content_v3.py`**：检查描述与 test patch 或必填内容一致性；**`analyze_pass_diff_by_problem_statement_v2_v3.py`**、**`compare_problem_statement_len_v2_v3.py`**：对比 v2/v3 描述与通过差异或长度；**`annotate_pass_traj_capabilities.py`**、**`annotate_bash_only_pass_traj_capabilities.py`**、**`annotate_instance_reasoning_capabilities.py`**、**`merge_pass_traj_phases.py`**：对轨迹做能力标注或分阶段合并；**`analyze_kimi_traj_failure_opus.py`**：用 Opus 分析 Kimi 失败案例；**`sample_by_language.py`**：按语言抽样实例；**`collect_strengthen_eval_golden.py`**：按 strengthen 列表从 eval/swe-format 拼出评估与 golden JSON；**`build_basic_from_harness.py`**：与指定 harness 结果求交生成 baseline JSON；**`nl.sh`**、**`mkd.sh`**：批处理入口。部分脚本内项目根路径注释可能与实际目录层级不一致，以代码为准。