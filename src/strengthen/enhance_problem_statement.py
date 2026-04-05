#!/usr/bin/env python3
"""
读取 result/final_stat_result/result/strengthen.json，调用 BASE_URL 的 model，按默认 prompt 增强每条 problem_statement，
写回同目录下的 0226.json。API Key 从环境变量读取（优先级：OPENAI_API_KEY > QWEN_API_KEY > API_KEY）；可选 OPENAI_BASE_URL、OPENAI_MODEL。
"""

import json
import os
import sys
import time
from pathlib import Path

from openai import OpenAI

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

EXCLUDE = "result/strengthen/first_nl.json"
INPUT_REL = "result/strengthen/0226.json"
OUTPUT_NAME = "0227_nl.json"
SLEEP = 0.5
TIMEOUT = 120
CHECKPOINT_EVERY = 10

NATURL_SYSTEM_PROMPT = """
You are given a commit message and a golden patch (diff) for a software issue. Your task is to create a clear, natural language problem description that explains the issue to a developer who needs to understand the context and the bug.

Based only on these inputs, write a cohesive narrative that describes the problem without using structured headers (like "Expected Behavior" or "Steps to Reproduce"). Instead, present it as a professional technical report or a GitHub issue description.

Your description should:
- Clearly explain the context of where and when the issue occurs.
- Describe the discrepancy between the expected behavior and the actual observed behavior (e.g., specific errors, incorrect output, or crashes).
- Flow logically from the background to the specific symptoms of the bug.
- **Strictly avoid** revealing the specific implementation of the fix or referring to the code changes in the patch.
- Use a professional, technical, yet conversational tone similar to how developers communicate in issue trackers.

**Output Format:**
Provide only the natural language text. Do not use Markdown headers, bullet points, or bold labels. The output should be a multi-paragraph narrative that sounds like a human-written bug report.
"""


# System prompt 包含完整的任务说明
SYSTEM_PROMPT = """You are given a commit message and a golden patch (diff) for a software issue. Your task is to create a clear, well-structured problem statement that describes the issue to a developer who needs to understand and fix it.

The commit message may be brief or technical. The patch shows what code was changed to fix the issue.

Based only on these inputs, write an enhanced problem statement that:
- Clearly describes what the problem is
- Explains what the expected behavior should be
- Provides context about when/where the issue occurs
- Does NOT reveal the specific implementation of the fix

Use this markdown format:

## Issue: [Brief title]

### Description
[Clear explanation of the problem and its context]

### Expected Behavior
[What should happen when the system works correctly]

### Actual Behavior
[What actually happens (error, incorrect output, crash, etc.)]

### Environment (if applicable)
[Any relevant version, OS, or configuration details]


You should output only the markdown above.
"""

# User prompt 只包含输入数据
USER_PROMPT_TPL = """Input:
- Commit Message: {commit_message}
- Golden Patch: {golden_patch}
"""


def call_with_openai_client(client: OpenAI, model: str, messages: list, stream: bool = True) -> str:
    """流式调用，仅收集 answer 的 content（不含 reasoning_content）。"""
    completion = client.chat.completions.create(
        model=model,
        messages=messages,
        stream=stream,
        extra_body={"enable_thinking": True},
    )
    answer_content = ""
    for chunk in completion:
        if not chunk.choices:
            continue
        delta = chunk.choices[0].delta
        if hasattr(delta, "content") and delta.content:
            answer_content += delta.content
    return answer_content.strip()


def main():
    base = Path(__file__).resolve().parents[3]
    input_path = base / INPUT_REL
    if not input_path.exists():
        print(f"Error: 文件不存在: {input_path}", file=sys.stderr)
        sys.exit(1)

    base_url = os.getenv("OPENAI_BASE_URL") or "https://dashscope.aliyuncs.com/compatible-mode/v1"
    api_key = (
        os.getenv("OPENAI_API_KEY")
        or os.getenv("QWEN_API_KEY")
        or os.getenv("API_KEY")
        or ""
    ).strip()
    model = os.getenv("OPENAI_MODEL") or "qwen3-max"

    if not api_key:
        print(
            "Error: 未设置 API Key。请设置环境变量 OPENAI_API_KEY、QWEN_API_KEY 或 API_KEY。",
            file=sys.stderr,
        )
        print("  例如: export OPENAI_API_KEY='sk-xxx'", file=sys.stderr)
        sys.exit(1)

    client = OpenAI(api_key=api_key, base_url=base_url)
    out_path = input_path.parent / OUTPUT_NAME

    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        print("Error: 输入 JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    # 加载 exclude 文件：这些 instance_id 不调用 API，直接使用 exclude 文件中的整条内容写入输出
    exclude_path = base / EXCLUDE
    exclude_ids = set()
    exclude_map = {}
    if exclude_path.exists():
        with open(exclude_path, "r", encoding="utf-8") as f:
            exclude_data = json.load(f)
        if isinstance(exclude_data, list):
            for obj in exclude_data:
                iid = obj.get("instance_id")
                if iid:
                    exclude_ids.add(iid)
                    exclude_map[iid] = obj
        print(f"已加载 exclude 文件: {exclude_path}，共 {len(exclude_ids)} 条将直接写入输出")
    else:
        print(f"Exclude 文件不存在（跳过）: {exclude_path}")

    total = len(data)
    for i, item in enumerate(data):
        id = item.get("instance_id")
        if id in exclude_ids:
            # 直接使用 exclude 文件中的整条内容，不调用 API
            data[i] = exclude_map[id]
            print(f"[{i + 1}/{total}] {id} (exclude，已用 exclude 文件内容)")
            if (i + 1) % CHECKPOINT_EVERY == 0:
                with open(out_path, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                print(f"--- Checkpoint: 已保存至 {out_path} ({i + 1}/{total}) ---")
            continue

        # 构建消息列表，system和user分开
        messages = [
            {"role": "system", "content": NATURL_SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TPL.format(
                commit_message=item.get("problem_statement", ""),
                golden_patch=item.get("patch", "")
            )}
        ]
        
        try:
            enhanced = call_with_openai_client(client, model, messages)
            if enhanced:
                item["problem_statement"] = enhanced
            print(f"[{i + 1}/{total}] {item.get('instance_id', i)}")
        except Exception as e:
            print(f"[{i + 1}/{total}] 请求失败: {e}", file=sys.stderr)

        if SLEEP > 0:
            time.sleep(SLEEP)

        if (i + 1) % CHECKPOINT_EVERY == 0:
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--- Checkpoint: 已保存至 {out_path} ({i + 1}/{total}) ---")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"已写入 {total} 条 -> {out_path}")


if __name__ == "__main__":
    main()