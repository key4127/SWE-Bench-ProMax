import argparse
import json
import re
from pathlib import Path


def extract_workdir(dockerfile_path: Path) -> str | None:
    """从单个 Dockerfile 中提取 WORKDIR 的绝对路径。"""
    try:
        text = dockerfile_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None

    # 匹配所有 WORKDIR，取最后一个（Docker 里最后一个生效）
    matches = re.findall(r"^\s*WORKDIR\s+([^\s\n]+)", text, re.MULTILINE | re.IGNORECASE)
    if not matches:
        return None
    path = matches[-1].strip("'\"").rstrip("/")
    if not path.startswith("/"):
        return None
    return path.rstrip("/") or "/"


def build_instance_workdir_map(docker_root: str = "dockerfile") -> dict[str, str]:
    """遍历 dockerfile 目录，构建 {instance_id: working_dir 绝对路径} 映射。"""
    root = Path(docker_root)
    mapping: dict[str, str] = {}

    if not root.exists():
        return mapping

    for dockerfile in root.rglob("*_Dockerfile"):
        instance_id = dockerfile.name[: -len("_Dockerfile")]
        workdir = extract_workdir(dockerfile)
        if workdir:
            mapping[instance_id] = workdir

    return mapping


def add_workdir_to_swe_json(
    input_path: str,
    output_path: str | None = None,
    *,
    docker_root: str = "dockerfile",
) -> None:
    input_file = Path(input_path)
    if not input_file.exists():
        raise FileNotFoundError(f"input json not found: {input_path}")

    with input_file.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise ValueError("expect swe-format json to be a list of objects")

    instance_workdir = build_instance_workdir_map(docker_root)

    for item in data:
        if not isinstance(item, dict):
            continue
        instance_id = item.get("instance_id")
        if not instance_id:
            continue
        workdir = instance_workdir.get(instance_id)
        if workdir is not None:
            item["working_dir"] = workdir

    output_file = Path(output_path) if output_path else input_file
    with output_file.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "遍历 dockerfile/* 下的 Dockerfile，解析每个 WORKDIR 的绝对路径，"
            "写回 swe-format json 的 working_dir 字段。"
        )
    )
    parser.add_argument(
        "--input",
        "-i",
        required=True,
        help="输入 swe-format json 路径，例如 result/strengthen/v2/all_nl_enhanced.json",
    )
    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="输出 json 路径，默认覆盖输入文件",
    )
    parser.add_argument(
        "--docker-root",
        default="dockerfile",
        help="存放 *_Dockerfile 的根目录（默认: dockerfile）",
    )

    args = parser.parse_args()
    add_workdir_to_swe_json(args.input, args.output, docker_root=args.docker_root)


if __name__ == "__main__":
    main()

