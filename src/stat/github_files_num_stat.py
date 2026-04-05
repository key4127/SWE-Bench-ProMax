import json
import statistics
from pathlib import Path


def main(paths):
    for path in paths:
        with open(path, "r", encoding='utf-8') as f:
            data = json.load(f)

            print(f"\n{'='*80}")
            print(f"分析文件: {path}")
            print(f"{'='*80}")
            
            file_counts = []
            
            if isinstance(data, list):
                for commit in data:
                    if "files" in commit:
                        unique_files = set()
                        for file_info in commit["files"]:
                            filename = file_info["filename"]
                            unique_files.add(filename)
                        num_files = len(unique_files)
                        file_counts.append(num_files)
            elif isinstance(data, dict):
                if "files" in data:
                    unique_files = set()
                    for file_info in commit["files"]:
                        filename = file_info["filename"]
                        unique_files.add(filename)
                    num_files = len(unique_files)
                    file_counts.append(num_files)

            if len(file_counts) != 0:
                print(f"总提交数: {len(file_counts)}")
                print(f"平均文件数: {round(statistics.mean(file_counts), 2)}")
                print(f"中位数: {statistics.median(file_counts)}")
                print(f"最小跨文件数: {min(file_counts)}")
                print(f"最大跨文件数: {max(file_counts)}")
            else:
                print(f"总提交数: {len(file_counts)}")


if __name__ == "__main__":
    # dir_path = Path("./filtered_data/test/")
    # paths = []

    # for item in dir_path.rglob('*'):
    #     paths.append(item)

    paths = [
        "./filtered_data/test/langchain.json",
        "./filtered_data/test/vllm.json",
        "./filtered_data/test/airflow.json",
        "./filtered_data/test/textual.json",
        "./filtered_data/test/reflex.json",
        "./filtered_data/test/searxng.json",
        "./filtered_data/test/saleor.json",
        "./filtered_data/test/wagtail.json",
        "./filtered_data/test/pipenv.json",
        "./filtered_data/test/scipy.json"
    ]

    main(paths)