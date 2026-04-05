#!/usr/bin/env python3
"""
用 OPUS 分析 preds.json 对应轨迹：判断每一步 agent 做了什么，并推断
1) 成功/失败原因
2) 实现该 patch 需要的能力（跨文件搜索、写测试、定位、修复等）

依赖: pip install openai
环境变量: CLAUDE_API_KEY 或 OPENAI_API_KEY（用于 OPUS/Claude API，如 aihubmix）
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path


# 单步/单条内容最大字符数，避免超长导致超 token
STEP_ACTION_MAX = 1200
STEP_OBS_MAX = 2500
TASK_PREVIEW_MAX = 2000
SUBMISSION_PREVIEW_MAX = 3000

# 能力标签（供模型参考，可返回子集或扩展）
CAPABILITY_HINTS = [
    "cross_file_search",   # 跨文件搜索/阅读
    "write_test",         # 编写或运行测试
    "locate_bug",         # 定位问题/根因
    "fix_code",           # 修改源码修复
    "refactor_api",       # API/接口重构
    "run_tests",          # 执行测试
    "read_docs",          # 阅读文档/注释
    "debug_output",       # 根据报错/输出调试
    "edit_multiple_files",# 多文件编辑
    "understand_domain",  # 领域/业务理解
    "build_or_install",   # 构建/安装环境
    "other",
]

SYSTEM_PROMPT = """你是一个软件工程分析助手。你会看到一段 agent 完成代码修改任务的轨迹摘要：
- 任务描述（PR description）摘要
- 每一步：agent 的思考(THOUGHT)、执行的命令、以及命令输出（observation）的摘要
- 最终提交的 patch 摘要（若有）
- 本实例是否“有提交”（has_submission：有非空 patch）以及可选的 harness 是否通过（passed，若提供）

请基于轨迹内容完成两件事：

1) **成功/失败原因**（reason_success_failure）  
   用 2–5 句话说明：若成功，主要做对了什么、关键步骤是什么；若失败，主要卡在哪里、缺少哪类能力或决策错误。要结合具体步骤，不要泛泛而谈。

2) **实现该 patch 需要的能力**（capabilities_required）  
   从以下能力中勾选本任务实际用到的（可多选），并可按需增加简短说明。能力列表（可返回子集或扩展）：
   - cross_file_search: 跨文件搜索/阅读
   - write_test: 编写或运行测试
   - locate_bug: 定位问题/根因
   - fix_code: 修改源码修复
   - refactor_api: API/接口重构
   - run_tests: 执行测试
   - read_docs: 阅读文档/注释
   - debug_output: 根据报错/输出调试
   - edit_multiple_files: 多文件编辑
   - understand_domain: 领域/业务理解
   - build_or_install: 构建/安装环境
   - other: 其他（在 capability_notes 中简述）

请**仅**输出一个 JSON 对象，不要 markdown 代码块包裹，格式如下：
{
  "reason_success_failure": "<中文或英文的 2–5 句话>",
  "capabilities_required": ["<能力1>", "<能力2>", ...],
  "capability_notes": "<可选：对 other 或关键能力的简短说明，可空字符串>"
}
"""


def _truncate(s: str, max_len: int, suffix: str = "...") -> str:
    if not s or len(s) <= max_len:
        return s or ""
    return s[: max_len - len(suffix)].rstrip() + suffix


def _extract_bash_command(content: str) -> str:
    """从 assistant 的 content 中抽出 ```bash ... ``` 里的命令。"""
    if not content:
        return ""
    m = re.search(r"```bash\s*\n(.*?)\n```", content, re.DOTALL)
    return m.group(1).strip() if m else ""


def extract_steps_from_traj(traj: dict) -> list[dict]:
    """
    从 traj 的 messages 中提取「步骤」：每个 assistant 消息为一步，紧跟的 user 消息为该步的 observation。
    返回列表，每项为 { "thought_cmd": str, "command": str, "observation_preview": str }。
    """
    messages = traj.get("messages") or []
    steps = []
    i = 0
    while i < len(messages):
        m = messages[i]
        if not isinstance(m, dict):
            i += 1
            continue
        role = m.get("role")
        content = (m.get("content") or "").strip()
        if role == "assistant":
            cmd = _extract_bash_command(content)
            thought_cmd = _truncate(content, STEP_ACTION_MAX)
            obs_preview = ""
            if i + 1 < len(messages) and messages[i + 1].get("role") == "user":
                obs_content = (messages[i + 1].get("content") or "").strip()
                obs_preview = _truncate(obs_content, STEP_OBS_MAX)
                i += 1
            steps.append({
                "thought_cmd": thought_cmd,
                "command": cmd,
                "observation_preview": obs_preview,
            })
        i += 1
    return steps


def get_task_preview_from_traj(traj: dict) -> str:
    """从第一条 user 消息中截取任务描述（通常含 pr_description）。"""
    for m in traj.get("messages") or []:
        if isinstance(m, dict) and m.get("role") == "user":
            return _truncate((m.get("content") or "").strip(), TASK_PREVIEW_MAX)
    return ""


def get_submission_preview_from_traj(traj: dict) -> str:
    """从 info.submission 取最终提交的 patch 摘要。"""
    info = traj.get("info") or {}
    sub = info.get("submission") or ""
    return _truncate(sub, SUBMISSION_PREVIEW_MAX)


def load_preds(preds_path: Path) -> dict:
    """preds.json 为 dict: instance_id -> { model_patch, instance_id, ... }"""
    with open(preds_path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        return {}
    return data


def load_traj(traj_dir: Path, instance_id: str) -> dict | None:
    """traj 路径约定: traj_dir / instance_id / (instance_id).traj.json"""
    traj_file = traj_dir / instance_id / f"{instance_id}.traj.json"
    if not traj_file.is_file():
        return None
    try:
        with open(traj_file, encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def build_user_prompt(
    instance_id: str,
    task_preview: str,
    steps: list[dict],
    submission_preview: str,
    has_submission: bool,
    passed: bool | None,
) -> str:
    parts = [
        f"## instance_id: {instance_id}",
        "",
        "### 任务描述摘要",
        task_preview or "(无)",
        "",
        "### 轨迹步骤（每步：思考+命令 → 观察）",
    ]
    for i, st in enumerate(steps, 1):
        parts.append(f"--- Step {i} ---")
        parts.append("思考与命令:")
        parts.append(st.get("thought_cmd") or "(无)")
        parts.append("执行命令:")
        parts.append(st.get("command") or "(无)")
        parts.append("观察摘要:")
        parts.append(st.get("observation_preview") or "(无)")
        parts.append("")
    parts.append("### 最终提交 patch 摘要")
    parts.append(submission_preview or "(无)")
    parts.append("")
    parts.append(f"has_submission（有非空 patch）: {has_submission}")
    if passed is not None:
        parts.append(f"harness passed: {passed}")
    parts.append("")
    parts.append("请输出上述要求的 JSON。")
    return "\n".join(parts)


def call_opus(
    client,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_retries: int = 3,
) -> dict | None:
    """调用 OPUS/Claude，解析返回的 JSON。"""
    for attempt in range(max_retries):
        try:
            completion = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0.1,
                max_tokens=1500,
            )
            content = (completion.choices[0].message.content or "").strip()
            # 去掉可能的 markdown 代码块
            if content.startswith("```"):
                content = re.sub(r"^```\w*\n?", "", content)
                content = re.sub(r"\n```\s*$", "", content)
            start = content.find("{")
            end = content.rfind("}") + 1
            if start != -1 and end > start:
                content = content[start:end]
            return json.loads(content)
        except json.JSONDecodeError as e:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
                continue
            print(f"  [JSON 解析失败] {e}", file=sys.stderr)
            return None
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
                continue
            print(f"  [API 调用失败] {e}", file=sys.stderr)
            return None
    return None


def load_harness_passed(harness_path: Path | None) -> dict[str, bool]:
    """harness 结果 JSON 为 list of { instance_id, passed }，返回 id -> passed。"""
    if not harness_path or not harness_path.is_file():
        return {}
    with open(harness_path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        return {}
    return {
        item["instance_id"]: bool(item.get("passed"))
        for item in data
        if isinstance(item, dict) and item.get("instance_id") is not None
    }


def main():
    parser = argparse.ArgumentParser(
        description="用 OPUS 分析 preds.json 对应轨迹：推断成功/失败原因与所需能力"
    )
    parser.add_argument(
        "preds",
        type=Path,
        help="preds.json 路径（dict: instance_id -> 条目，含 model_patch）",
    )
    parser.add_argument(
        "-t", "--traj-dir",
        type=Path,
        default=None,
        help="traj 根目录，默认与 preds 同目录（即 preds 的父目录）",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="输出 JSON 路径，默认与 preds 同目录下的 opus_analysis_<preds_stem>.json",
    )
    parser.add_argument(
        "--harness",
        type=Path,
        default=None,
        help="可选：harness 结果 JSON（list 含 instance_id, passed），用于传入 passed 信息",
    )
    parser.add_argument(
        "--model",
        type=str,
        default="claude-sonnet-4-20250514",
        help="模型名，如 claude-sonnet-4-20250514 或 claude-opus-4-6-think",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="只处理前 N 个 instance（用于测试）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只列将要处理的 instance，不调 API",
    )
    args = parser.parse_args()

    preds_path = args.preds.resolve()
    if not preds_path.is_file():
        print(f"Error: preds 不存在: {preds_path}", file=sys.stderr)
        sys.exit(1)

    traj_dir = args.traj_dir
    if traj_dir is None:
        traj_dir = preds_path.parent
    else:
        traj_dir = traj_dir.resolve()

    preds = load_preds(preds_path)
    if not preds:
        print("Error: preds 为空或格式不是 dict", file=sys.stderr)
        sys.exit(1)

    id_to_passed = load_harness_passed(args.harness.resolve() if args.harness else None)

    # 确定要处理的 id 列表（仅存在 traj 的）
    instance_ids = []
    for iid in preds:
        if load_traj(traj_dir, iid) is not None:
            instance_ids.append(iid)
    instance_ids.sort()
    if args.limit is not None:
        instance_ids = instance_ids[: args.limit]

    if not instance_ids:
        print("没有找到任何带 traj 的 instance，退出。", file=sys.stderr)
        sys.exit(0)

    if args.dry_run:
        print(f"dry-run: 将处理 {len(instance_ids)} 个 instance（有 traj）")
        for iid in instance_ids[:20]:
            print(f"  {iid}")
        if len(instance_ids) > 20:
            print(f"  ... 共 {len(instance_ids)} 个")
        return

    # API 客户端
    api_key = os.getenv("CLAUDE_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key or not api_key.strip():
        print("Error: 请设置环境变量 CLAUDE_API_KEY 或 OPENAI_API_KEY", file=sys.stderr)
        sys.exit(1)
    try:
        from openai import OpenAI
    except ImportError:
        print("Error: 请安装 openai: pip install openai", file=sys.stderr)
        sys.exit(1)
    base_url = os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1")
    client = OpenAI(api_key=api_key.strip(), base_url=base_url)

    out_path = args.output
    if out_path is None:
        out_path = preds_path.parent / f"opus_analysis_{preds_path.stem}.json"
    out_path = out_path.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # 断点续跑
    results = {}
    if out_path.is_file():
        try:
            with open(out_path, encoding="utf-8") as f:
                results = json.load(f)
            if isinstance(results, dict):
                print(f"已加载已有结果: {len(results)} 条，将跳过并追加")
            else:
                results = {}
        except Exception:
            results = {}

    to_process = [iid for iid in instance_ids if iid not in results]
    total = len(to_process)
    print(f"待分析: {total} 个 instance，结果写入 {out_path}")

    for idx, instance_id in enumerate(to_process, 1):
        traj = load_traj(traj_dir, instance_id)
        if traj is None:
            results[instance_id] = {"error": "traj_not_found"}
            continue
        entry = preds.get(instance_id) or {}
        model_patch = entry.get("model_patch") or ""
        has_submission = bool(model_patch.strip())
        passed = id_to_passed.get(instance_id)

        task_preview = get_task_preview_from_traj(traj)
        steps = extract_steps_from_traj(traj)
        submission_preview = get_submission_preview_from_traj(traj)

        user_prompt = build_user_prompt(
            instance_id=instance_id,
            task_preview=task_preview,
            steps=steps,
            submission_preview=submission_preview,
            has_submission=has_submission,
            passed=passed,
        )
        analysis = call_opus(client, args.model, SYSTEM_PROMPT, user_prompt)
        if analysis is not None:
            results[instance_id] = {
                "reason_success_failure": analysis.get("reason_success_failure", ""),
                "capabilities_required": analysis.get("capabilities_required") or [],
                "capability_notes": analysis.get("capability_notes", ""),
            }
            caps = results[instance_id]["capabilities_required"]
            print(f"[{idx}/{total}] {instance_id} -> {len(caps)} 项能力")
        else:
            results[instance_id] = {"error": "api_failed"}
            print(f"[{idx}/{total}] {instance_id} -> API 失败", file=sys.stderr)

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        if idx < total:
            time.sleep(0.5)

    print(f"\n完成，结果已写入: {out_path}")


if __name__ == "__main__":
    main()
