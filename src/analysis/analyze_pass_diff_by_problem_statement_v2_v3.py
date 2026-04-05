#!/usr/bin/env python3
"""
分析 v2 / v3 problem_statement 变化与通过率变化的关系（按 instance_id 对齐）。

默认输入：
- result/harness_result/strengthen/v2/kimi.json
- result/harness_result/strengthen/v3/stat/kimi.json
- result/strengthen/v2/all_nl_enhanced.json
- result/strengthen/v3/all_nl_fuzzy.json

输出：
1) 终端打印总体统计、分组统计与代表样例
2) JSON 报告（默认 result/harness_result/strengthen/v3/stat/kimi_v2_v3_ps_analysis.json）
"""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import time
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_V2_PASS = ROOT / "result" / "harness_result" / "strengthen" / "v2" / "kimi.json"
DEFAULT_V3_PASS = ROOT / "result" / "harness_result" / "strengthen" / "v3" / "stat" / "kimi.json"
DEFAULT_V2_PS = ROOT / "result" / "strengthen" / "v2" / "all_nl_enhanced.json"
DEFAULT_V3_PS = ROOT / "result" / "strengthen" / "v3" / "all_nl_fuzzy.json"
DEFAULT_OUT = ROOT / "result" / "harness_result" / "strengthen" / "v3" / "stat" / "kimi_v2_v3_ps_analysis.json"

_WORD_RE = re.compile(r"[a-zA-Z_][a-zA-Z0-9_+\-./]*")
_HEAD_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.+?)\s*$", re.MULTILINE)
_BULLET_RE = re.compile(r"^\s*[-*+]\s+", re.MULTILINE)
_CODE_RE = re.compile(r"`[^`]+`")
_DIGIT_RE = re.compile(r"\d")

REASON_HINT_KEYWORDS = (
    "exact",
    "must",
    "should",
    "expected",
    "error message",
    "return code",
    "path",
    "root cause",
    "unit test",
    "test",
    "failing",
    "regression",
    "compile",
    "build",
    "timeout",
    "not run",
)

LLM_SYSTEM_PROMPT = """你是软件修复评测分析助手。请基于以下输入：
1) v2/v3 的 problem_statement；
2) 同一实例在 v2/v3 的 passed 布尔值；
3) 基础文本统计特征；
判断“题述变化为什么可能导致通过状态变化（或不变化）”。

只返回 JSON 对象，格式：
{
  "reason": "2-5 句中文结论，聚焦可观察依据，避免臆测",
  "factors": ["最多 5 个短标签"],
  "confidence": 0.0
}
confidence 取值 [0,1]。
"""


@dataclass
class PsFeatures:
    length: int
    word_count: int
    heading_count: int
    bullet_count: int
    code_span_count: int
    has_digits: bool
    keyword_hits: int
    unique_word_count: int
    words: set[str]


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_pass_map(path: Path) -> dict[str, dict]:
    data = load_json(path)
    if not isinstance(data, list):
        raise SystemExit(f"期望数组 JSON: {path}")
    out: dict[str, dict] = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if not iid:
            continue
        out[str(iid)] = item
    return out


def load_ps_map(path: Path) -> dict[str, str]:
    data = load_json(path)
    if not isinstance(data, list):
        raise SystemExit(f"期望数组 JSON: {path}")
    out: dict[str, str] = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if not iid:
            continue
        ps = item.get("problem_statement")
        out[str(iid)] = ps if isinstance(ps, str) else ""
    return out


def extract_features(text: str) -> PsFeatures:
    words = [w.lower() for w in _WORD_RE.findall(text)]
    word_set = set(words)
    lower_text = text.lower()
    hits = sum(1 for kw in REASON_HINT_KEYWORDS if kw in lower_text)
    return PsFeatures(
        length=len(text),
        word_count=len(words),
        heading_count=len(_HEAD_RE.findall(text)),
        bullet_count=len(_BULLET_RE.findall(text)),
        code_span_count=len(_CODE_RE.findall(text)),
        has_digits=bool(_DIGIT_RE.search(text)),
        keyword_hits=hits,
        unique_word_count=len(word_set),
        words=word_set,
    )


def overlap_ratio(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 1.0
    union = a | b
    if not union:
        return 0.0
    return len(a & b) / len(union)


def seq_ratio(a: str, b: str) -> float:
    if not a and not b:
        return 1.0
    return SequenceMatcher(None, a, b).ratio()


def status_bucket(v2_passed: bool, v3_passed: bool) -> str:
    if (not v2_passed) and v3_passed:
        return "improved"
    if v2_passed and (not v3_passed):
        return "regressed"
    if v2_passed and v3_passed:
        return "both_passed"
    return "both_failed"


def as_bool(value) -> bool:
    return bool(value is True)


def summarize_group(rows: list[dict]) -> dict:
    if not rows:
        return {
            "count": 0,
            "avg_len_delta": 0.0,
            "avg_word_delta": 0.0,
            "avg_keyword_delta": 0.0,
            "avg_seq_similarity": 0.0,
            "avg_word_overlap": 0.0,
            "v3_longer_ratio": 0.0,
        }
    len_d = [r["len_delta"] for r in rows]
    word_d = [r["word_delta"] for r in rows]
    kw_d = [r["keyword_delta"] for r in rows]
    seq_s = [r["seq_similarity"] for r in rows]
    ov_s = [r["word_overlap"] for r in rows]
    longer = sum(1 for d in len_d if d > 0)
    return {
        "count": len(rows),
        "avg_len_delta": round(statistics.mean(len_d), 3),
        "avg_word_delta": round(statistics.mean(word_d), 3),
        "avg_keyword_delta": round(statistics.mean(kw_d), 3),
        "avg_seq_similarity": round(statistics.mean(seq_s), 4),
        "avg_word_overlap": round(statistics.mean(ov_s), 4),
        "v3_longer_ratio": round(longer / len(rows), 4),
    }


def choose_examples(rows: list[dict], k: int) -> list[dict]:
    if not rows or k <= 0:
        return []
    ranked = sorted(
        rows,
        key=lambda r: (
            abs(r["len_delta"]) + 12 * abs(r["keyword_delta"]),
            1 - r["seq_similarity"],
        ),
        reverse=True,
    )
    return ranked[:k]


def truncate(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    half = max_chars // 2
    return text[:half] + "\n...[truncated]...\n" + text[-half:]


def call_llm_json(client, model: str, user_content: str) -> dict | None:
    completion = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": LLM_SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
        temperature=0.1,
    )
    content = (completion.choices[0].message.content or "").strip()
    if content.startswith("```"):
        content = re.sub(r"^```\w*\n?", "", content)
        content = re.sub(r"\n```\s*$", "", content)
    start = content.find("{")
    end = content.rfind("}") + 1
    if start != -1 and end > start:
        content = content[start:end]
    try:
        obj = json.loads(content)
    except json.JSONDecodeError:
        return None
    if not isinstance(obj, dict):
        return None
    return obj


def build_llm_user_prompt(row: dict, v2_ps: str, v3_ps: str) -> str:
    return (
        f"instance_id: {row['instance_id']}\n"
        f"bucket: {row['bucket']}\n"
        f"v2_passed: {row['v2_passed']}\n"
        f"v3_passed: {row['v3_passed']}\n"
        f"language_v2: {row.get('language_v2', '')}\n"
        f"language_v3: {row.get('language_v3', '')}\n"
        f"len_delta: {row['len_delta']}\n"
        f"keyword_delta: {row['keyword_delta']}\n"
        f"seq_similarity: {row['seq_similarity']}\n"
        "\n[v2 problem_statement]\n"
        f"{truncate(v2_ps, 7000)}\n"
        "\n[v3 problem_statement]\n"
        f"{truncate(v3_ps, 7000)}\n"
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="分析 v2/v3 problem_statement 对通过结果的影响")
    ap.add_argument("--v2-pass", default=str(DEFAULT_V2_PASS), help="v2 pass 文件路径")
    ap.add_argument("--v3-pass", default=str(DEFAULT_V3_PASS), help="v3 pass 文件路径")
    ap.add_argument("--v2-ps", default=str(DEFAULT_V2_PS), help="v2 problem_statement 文件路径")
    ap.add_argument("--v3-ps", default=str(DEFAULT_V3_PS), help="v3 problem_statement 文件路径")
    ap.add_argument("--output", "-o", default=str(DEFAULT_OUT), help="输出分析 JSON")
    ap.add_argument("--examples", type=int, default=8, help="每个类别输出多少条代表样例")
    ap.add_argument("--no-llm", action="store_true", help="禁用 LLM（默认启用；不建议）")
    ap.add_argument("--llm-model", default="claude-sonnet-4-20250514", help="LLM 模型名")
    ap.add_argument("--llm-max-instances", type=int, default=60, help="最多调用 LLM 分析多少条")
    ap.add_argument(
        "--llm-only-bucket",
        choices=["all", "changed", "improved", "regressed"],
        default="changed",
        help="LLM 分析哪些 bucket（默认 changed=improved+regressed）",
    )
    ap.add_argument("--llm-base-url", default=os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1"), help="OpenAI 兼容 base_url")
    ap.add_argument("--llm-sleep", type=float, default=0.3, help="每次 LLM 调用后 sleep 秒数")
    args = ap.parse_args()

    v2_pass_path = Path(args.v2_pass)
    v3_pass_path = Path(args.v3_pass)
    v2_ps_path = Path(args.v2_ps)
    v3_ps_path = Path(args.v3_ps)
    out_path = Path(args.output)

    for p in (v2_pass_path, v3_pass_path, v2_ps_path, v3_ps_path):
        if not p.is_file():
            raise SystemExit(f"缺少输入文件: {p}")

    v2_pass_map = load_pass_map(v2_pass_path)
    v3_pass_map = load_pass_map(v3_pass_path)
    v2_ps_map = load_ps_map(v2_ps_path)
    v3_ps_map = load_ps_map(v3_ps_path)

    common_ids = sorted(set(v2_pass_map) & set(v3_pass_map))
    only_v2 = sorted(set(v2_pass_map) - set(v3_pass_map))
    only_v3 = sorted(set(v3_pass_map) - set(v2_pass_map))

    rows: list[dict] = []
    for iid in common_ids:
        v2_item = v2_pass_map[iid]
        v3_item = v3_pass_map[iid]
        v2_ps = v2_ps_map.get(iid, "")
        v3_ps = v3_ps_map.get(iid, "")
        f2 = extract_features(v2_ps)
        f3 = extract_features(v3_ps)

        v2_passed = as_bool(v2_item.get("passed"))
        v3_passed = as_bool(v3_item.get("passed"))
        bucket = status_bucket(v2_passed, v3_passed)

        row = {
            "instance_id": iid,
            "language_v2": v2_item.get("language", ""),
            "language_v3": v3_item.get("language", ""),
            "v2_passed": v2_passed,
            "v3_passed": v3_passed,
            "bucket": bucket,
            "len_v2": f2.length,
            "len_v3": f3.length,
            "len_delta": f3.length - f2.length,
            "word_v2": f2.word_count,
            "word_v3": f3.word_count,
            "word_delta": f3.word_count - f2.word_count,
            "keyword_v2": f2.keyword_hits,
            "keyword_v3": f3.keyword_hits,
            "keyword_delta": f3.keyword_hits - f2.keyword_hits,
            "heading_delta": f3.heading_count - f2.heading_count,
            "bullet_delta": f3.bullet_count - f2.bullet_count,
            "code_span_delta": f3.code_span_count - f2.code_span_count,
            "unique_word_delta": f3.unique_word_count - f2.unique_word_count,
            "seq_similarity": round(seq_ratio(v2_ps, v3_ps), 4),
            "word_overlap": round(overlap_ratio(f2.words, f3.words), 4),
        }
        rows.append(row)

    by_bucket: dict[str, list[dict]] = {
        "improved": [r for r in rows if r["bucket"] == "improved"],
        "regressed": [r for r in rows if r["bucket"] == "regressed"],
        "both_passed": [r for r in rows if r["bucket"] == "both_passed"],
        "both_failed": [r for r in rows if r["bucket"] == "both_failed"],
    }

    summary = {
        "input_files": {
            "v2_pass": str(v2_pass_path),
            "v3_pass": str(v3_pass_path),
            "v2_problem_statement": str(v2_ps_path),
            "v3_problem_statement": str(v3_ps_path),
        },
        "counts": {
            "v2_pass_items": len(v2_pass_map),
            "v3_pass_items": len(v3_pass_map),
            "common_instance_ids": len(common_ids),
            "only_in_v2": len(only_v2),
            "only_in_v3": len(only_v3),
        },
        "bucket_summary": {k: summarize_group(v) for k, v in by_bucket.items()},
        "examples": {
            k: choose_examples(v, args.examples) for k, v in by_bucket.items()
        },
        "only_in_v2_samples": only_v2[:30],
        "only_in_v3_samples": only_v3[:30],
    }

    llm_done = 0
    llm_failed = 0
    if not args.no_llm:
        api_key = os.getenv("OPENAI_API_KEY") or os.getenv("CLAUDE_API_KEY")
        if not api_key:
            raise SystemExit("需要环境变量 OPENAI_API_KEY 或 CLAUDE_API_KEY")
        from openai import OpenAI

        client = OpenAI(api_key=api_key, base_url=args.llm_base_url, timeout=900.0)
        if args.llm_only_bucket == "all":
            llm_candidates = rows
        elif args.llm_only_bucket == "changed":
            llm_candidates = [r for r in rows if r["bucket"] in ("improved", "regressed")]
        else:
            llm_candidates = [r for r in rows if r["bucket"] == args.llm_only_bucket]
        llm_candidates = llm_candidates[: args.llm_max_instances]

        for r in llm_candidates:
            iid = r["instance_id"]
            prompt = build_llm_user_prompt(r, v2_ps_map.get(iid, ""), v3_ps_map.get(iid, ""))
            try:
                obj = call_llm_json(client, args.llm_model, prompt)
            except Exception:
                obj = None
            if obj is None:
                r["llm_analysis"] = {
                    "reason": "",
                    "factors": [],
                    "confidence": 0.0,
                    "error": "llm_parse_or_api_failed",
                }
                llm_failed += 1
            else:
                r["llm_analysis"] = {
                    "reason": str(obj.get("reason", "")),
                    "factors": obj.get("factors") if isinstance(obj.get("factors"), list) else [],
                    "confidence": float(obj.get("confidence", 0.0) or 0.0),
                }
                llm_done += 1
            if args.llm_sleep > 0:
                time.sleep(args.llm_sleep)

        summary["llm"] = {
            "enabled": True,
            "model": args.llm_model,
            "base_url": args.llm_base_url,
            "only_bucket": args.llm_only_bucket,
            "requested_max_instances": args.llm_max_instances,
            "analyzed": llm_done,
            "failed": llm_failed,
        }
    else:
        summary["llm"] = {"enabled": False, "note": "已禁用 LLM；未生成归因"}

    out = {
        "summary": summary,
        "rows": rows,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"交集实例数: {len(common_ids)}")
    print(
        "分类计数: "
        f"improved={len(by_bucket['improved'])}, "
        f"regressed={len(by_bucket['regressed'])}, "
        f"both_passed={len(by_bucket['both_passed'])}, "
        f"both_failed={len(by_bucket['both_failed'])}"
    )
    print("各组平均特征（len_delta / keyword_delta / seq_similarity）:")
    for key in ("improved", "regressed", "both_passed", "both_failed"):
        g = summary["bucket_summary"][key]
        print(
            f"  - {key:<11} "
            f"len_delta={g['avg_len_delta']:+.1f}, "
            f"kw_delta={g['avg_keyword_delta']:+.2f}, "
            f"seq_sim={g['avg_seq_similarity']:.4f}"
        )
    if not args.no_llm:
        print(f"LLM 分析: success={llm_done}, failed={llm_failed}, model={args.llm_model}")
    print(f"分析已写入: {out_path}")


if __name__ == "__main__":
    main()
