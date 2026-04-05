import argparse
import json
import os


def main(input_path: str, output_dir: str, chunk_size: int = 1000) -> None:
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    os.makedirs(output_dir, exist_ok=True)

    for i in range(0, len(data), chunk_size):
        chunk = data[i : i + chunk_size]
        filename = f"batch5_result_{i // chunk_size + 1}.json"
        output_path = os.path.join(output_dir, filename)
        with open(output_path, "w", encoding="utf-8") as out_f:
            json.dump(chunk, out_f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="将大 JSON 数组按块拆分写入多文件")
    ap.add_argument("--input", default="./scale/docker/batch5/result/result.json")
    ap.add_argument("--output-dir", default="./scale/docker/batch5/result/")
    ap.add_argument("--chunk-size", type=int, default=1000)
    args = ap.parse_args()
    main(args.input, args.output_dir, args.chunk_size)
