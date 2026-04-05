import argparse
import json
from pathlib import Path


def main(
    instances_json: str,
    harness_glob: str,
    preds_root_template: str,
    out_json: str,
    models: list[str],
) -> None:
    with open(instances_json, encoding="utf-8") as f:
        all_instances = json.load(f)
    valid_ids = {inst["instance_id"] for inst in all_instances if not inst.get("discard", False)}

    result = {}

    for model in models:
        harness_path = harness_glob.format(model=model)
        with open(harness_path, encoding="utf-8") as f:
            harness = {item["instance_id"]: item["passed"] for item in json.load(f)}

        pass_data, fail_data = [], []
        preds_dir = Path(preds_root_template.format(model=model))

        for instance_dir in preds_dir.iterdir():
            if not instance_dir.is_dir():
                continue
            instance_id = instance_dir.name
            if instance_id not in valid_ids:
                continue

            traj_file = instance_dir / f"{instance_id}.traj.json"
            if not traj_file.exists():
                continue

            with open(traj_file, encoding="utf-8") as f:
                traj = json.load(f)

            stats = traj["info"]["model_stats"]
            data = {"api_call": stats["api_calls"], "cost": stats["instance_cost"]}

            if harness.get(instance_id, False):
                pass_data.append(data)
            else:
                fail_data.append(data)

        result[model] = {"model": model, "pass": pass_data, "fail": fail_data}

    out_path = Path(out_json)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="汇总各模型 traj 统计写入 model_stats.json")
    ap.add_argument(
        "--instances",
        default="result/strengthen/v2/all_nl_enhanced.json",
        help="含 discard 字段的实例列表 JSON",
    )
    ap.add_argument(
        "--harness-template",
        default="result/harness_result/strengthen/v2/{model}.json",
        help="harness 路径模板，含 {model} 占位符",
    )
    ap.add_argument(
        "--preds-root-template",
        default="result/preds_result/strengthen/v2/{model}",
        help="preds 根目录模板，含 {model}",
    )
    ap.add_argument(
        "--output",
        default="src/image/data/model_stats.json",
        help="输出 JSON 路径",
    )
    ap.add_argument(
        "--models",
        nargs="*",
        default=["glm", "kimi", "gemini", "claude"],
    )
    args = ap.parse_args()
    main(
        args.instances,
        args.harness_template,
        args.preds_root_template,
        args.output,
        list(args.models),
    )
