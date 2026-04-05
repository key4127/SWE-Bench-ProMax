import argparse
import json


def main(
    resolved_path: str,
    pulls_path: str,
    commits_path: str,
    output_path: str,
) -> None:
    with open(resolved_path, "r", encoding="utf-8") as f:
        resolved = json.load(f)

    with open(pulls_path, "r", encoding="utf-8") as f:
        pulls = json.load(f)

    with open(commits_path, "r", encoding="utf-8") as f:
        commits = json.load(f)

    outputs = []

    for id in resolved:
        parts = id.split("-")
        commit_id = parts[-1]

        sha = None

        if commit_id[0] == "c":
            parts = commit_id.split("_")
            commit_id = parts[-1]

            for pull in commits:
                if commit_id in pull["sha"]:
                    sha = pull["sha"]
                    break
        else:
            for pull in pulls:
                if commit_id in str(pull["pr_number"]):
                    sha = pull["sha"]
                    break

        if not sha:
            print(f"sha is None, id is {id}")
        else:
            for commit in commits:
                if commit["sha"] == sha:
                    outputs.append(
                        {
                            "id": id,
                            "commit": commit,
                        }
                    )
                    break

    print(len(outputs))

    for output in outputs:
        print(f"id: {output['id']}")

        filename_set = set()
        file_count = 0

        files = output["commit"]["files"]
        for file in files:
            if file["filename"] not in filename_set:
                filename_set.add(file["filename"])
                file_count += 1

        print(f"count: {file_count}\n")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(outputs, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--resolved", default="./auto_env_config_report/resolved_instances3.json")
    ap.add_argument("--pulls", default="./auto_env_config_report/batch3_result.json")
    ap.add_argument("--commits", default="./scale/docker/raw.json")
    ap.add_argument("--output", default="./auto_env_config_report/resolved_commits3.json")
    args = ap.parse_args()
    main(args.resolved, args.pulls, args.commits, args.output)
