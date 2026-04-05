import requests
import time
import json


def curl_language(owner, repo, token):
    url = f"https://api.github.com/repos/{owner}/{repo}/languages"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    response = requests.get(url, headers=headers)
    response.raise_for_status()

    languages_data = response.json()

    return next(iter(languages_data))


def curl_all_messages(owner, repo, since_time, token):
    url = "https://api.github.com/graphql"

    all_commits = []
    has_next_page = True
    cursor = None

    curl_num = 0

    while has_next_page:
        query = """
        query($owner: String!, $name: String!, $since: GitTimestamp, $cursor: String) {
          repository(owner: $owner, name: $name) {
            defaultBranchRef {
              target {
                ... on Commit {
                  history(first: 100, since: $since, after: $cursor) {
                    pageInfo {
                      endCursor
                      hasNextPage
                    }
                    nodes {
                      oid
                      message
                      changedFiles
                      statusCheckRollup {
                        state
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

        variables = {
            'owner': owner,
            'name': repo,
            'since': since_time,
            'cursor': cursor
        }

        payload = {
            'query': query,
            'variables': variables
        }
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }

        try:
            response = requests.post(url, json=payload, headers=headers)

            if response.status_code != 200:
                print(response.status_code)

            data = response.json()
            if 'errors' in data:
                print(data)
                break

            history = data["data"]["repository"]["defaultBranchRef"]["target"]["history"]
            commits = history["nodes"]
            page_info = history["pageInfo"]

            if not commits:
                break

            all_commits.extend(commits)
            cursor = page_info["endCursor"]
            has_next_page = page_info["hasNextPage"]

            time.sleep(0.5)

            curl_num += len(commits)
            print(f'curl 100, total {curl_num}')

        except Exception as e:
            print(str(e))
            break

    filtered_shas = []
    for commit in all_commits:
        if commit.get('message') is not None and \
            commit.get('changedFiles') is not None:
            message = commit['message']
            changedNum = commit['changedFiles']
            
            rollup = commit.get('statusCheckRollup')
            if rollup:
                state = rollup.get('state')
                if state is None or state == 'SUCCESS':
                    ci_passed = True
                else:
                    ci_passed = False
            else:
                ci_passed = True

            if 'refactor' in message.lower() and 'bug fix' not in message.lower():
                if changedNum >= 2 and commit.get('oid') is not None:
                    if ci_passed:
                        filtered_shas.append(commit['oid'])

    return filtered_shas


def curl_commit_details(owner, repo, shas: list[str], token):
    commits = []

    url = f"https://api.github.com/repos/{owner}/{repo}/commits/"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json"
    }

    for sha in shas:
        complete_url = url + sha

        try:
            response = requests.get(complete_url, headers=headers)
            if response.status_code == 200:
                commit_data = response.json()
                commits.append(commit_data)
        except Exception as e:
            pass

    return commits


def filter_commits_details(commits):
    filtered_commits = []

    for commit in commits:
        files = commit.get('files')

        has_test = False
        has_chore = False

        for file in files:
            if file.get('filename') is None:
                continue
            if 'test' in file['filename']:
                has_test = True
            else:
                has_chore = True

        if has_test and has_chore:
            filtered_commits.append(commit)

    return filtered_commits


def curl_filtered_commits(
    owner,
    repo,
    output_path = './scale/docker',
    since_time = '2025-01-01T00:00:00Z', 
    token = None
):
    """
    获取对应repo中符合以下要求的commit具体信息

    1. commit提交时间在since_time之后
    2. commit message中含有refactor字段
    3. commit message中不含bug fix字段
    4. commit处理文件数量大于等于2
    5. 如果仓库设置了CI，commit/所属pr对应的CI通过

    符合以上5条要求的结果存在 output_path + 'raw_repo.json'

    对raw_commit进行进一步筛选，要求

    6. commit files中，有包含“test”字段的文件
    7. commit files中，有不包含“test”字段的文件
    （即筛去无测试/只有测试的commit）

    符合以上所有7条要求的结果存在 output_path + 'repo.json' 的commits字段下。
    
    commit.json的结构如下：
    {
        "owner": xxx,
        "repo": xxx, 
        "language": xxx,
        "commits": xxx 
    }
    """

    commit_output = f'{output_path}/{repo}.json'

    language = curl_language(owner, repo, token)

    filtered_shas = curl_all_messages(owner, repo, since_time, token)
    raw_commits = curl_commit_details(owner, repo, filtered_shas, token)
    print(f'curl commit num: {len(raw_commits)}')

    commits = filter_commits_details(raw_commits)
    print(f'filtered commit num: {len(commits)}')

    commits_data = {
        'owner': owner,
        'repo': repo,
        'language': language.lower(),
        'commits': commits
    }

    with open(commit_output, 'w', encoding='utf-8') as f:
        json.dump(commits_data, f, indent=2, ensure_ascii=False)

    return commits_data


# test
if __name__ == '__main__':
    import os

    owner = 'tstack'
    repo = 'lnav'
    token = (os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or "").strip() or None
    curl_filtered_commits(owner, repo, token=token)