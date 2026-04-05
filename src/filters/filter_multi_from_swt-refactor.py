import argparse
import json
import sys
from typing import List, Dict, Any


def filter_multi_file_refactorings(data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    从重构数据中筛选出改变多个文件的操作

    Args:
        data: 原始重构数据列表

    Returns:
        涉及多个文件的重构操作列表
    """
    multi_file_refactorings = []

    max_file_count = 0

    for item in data:
        # 检查 diffLocations 字段是否存在且为数组
        if 'diffLocations' in item and isinstance(item['diffLocations'], list):
            # 收集所有唯一的文件路径
            file_paths = set()
            for location in item['diffLocations']:
                if 'filePath' in location and location['filePath']:
                    file_paths.add(location['filePath'])

            # 如果有多个不同的文件路径，则为多文件重构
            if len(file_paths) > 1:
                # 添加文件路径信息到结果中
                item_with_files = item.copy()
                item_with_files['affectedFiles'] = list(file_paths)
                item_with_files['fileCount'] = len(file_paths)
                multi_file_refactorings.append(item_with_files)
                max_file_count = max(max_file_count, len(file_paths))

    return multi_file_refactorings, max_file_count


def main(input_file: str, output_file: str):
    """
    主函数：读取JSON文件，筛选多文件重构，并输出结果。除了筛选多文件外不做任何修改。
    """

    try:
        print("正在读取重构数据文件...")
        with open(input_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        print(f"总共找到 {len(data)} 个重构操作")

        # 筛选多文件重构
        print("正在筛选多文件重构...")
        multi_file_refactorings, max_file_count = filter_multi_file_refactorings(data)

        print(f"找到 {len(multi_file_refactorings)} 个改变多个文件的重构操作")

        print(f"最多涉及 {max_file_count} 个文件")

        # 显示统计信息
        print("\n多文件重构统计:")
        type_counts = {}
        for ref in multi_file_refactorings:
            ref_type = ref.get('type', 'Unknown')
            type_counts[ref_type] = type_counts.get(ref_type, 0) + 1

        for ref_type, count in sorted(type_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"  {ref_type}: {count} 个")

        # 保存结果到新文件
        print(f"\n正在保存结果到 {output_file}...")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(multi_file_refactorings, f, indent=2, ensure_ascii=False)

        print("完成！多文件重构数据已保存。")

        # 显示前几个示例
        if multi_file_refactorings:
            print("\n前3个多文件重构示例:")
            for i, ref in enumerate(multi_file_refactorings[:3], 1):
                print(f"\n{i}. 类型: {ref.get('type', 'Unknown')}")
                print(f"   文件数量: {ref['fileCount']}")
                print(f"   涉及文件: {ref['affectedFiles']}")
                desc = ref.get('description', '')[:100]
                print(f"   描述: {desc}{'...' if len(ref.get('description', '')) > 100 else ''}")

    except FileNotFoundError:
        print(f"错误：找不到文件 {input_file}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"错误：JSON文件格式错误 - {e}")
        sys.exit(1)
    except Exception as e:
        print(f"错误：{e}")
        sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="./original_data/swe-refactor.json")
    ap.add_argument("--output", default="./multi_file_data/swe-refactor.json")
    args = ap.parse_args()
    main(args.input, args.output)
