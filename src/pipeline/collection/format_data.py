import os
import json
import requests
from datetime import datetime


DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

os.environ.pop('HTTP_PROXY', None)
os.environ.pop('HTTPS_PROXY', None)
os.environ.pop('http_proxy', None)
os.environ.pop('https_proxy', None)


def curl_pull_number(owner, repo, sha, token=None):
    """给定 commit sha，请求 GitHub API 返回该 commit 关联的 PR number（若有）。"""
    url = f"https://api.github.com/repos/{owner}/{repo}/commits/{sha}/pulls"

    headers = {
        'Accept': 'application/vnd.github+json',
    }

    if token:
        headers['Authorization'] = f'Bearer {token}'

    response = requests.get(url, headers=headers)
    response.raise_for_status()

    pr_list = response.json()

    if not pr_list:
        return None
    else:
        merged_prs = [pr for pr in pr_list if pr.get('merged_at') is not None]
        if merged_prs:
            pr = merged_prs[0]
        else:
            pr = pr_list[0]

    pull_number = pr.get('number')
    return pull_number


def curl_pr_merge_sha(owner, repo, pull_number, token=None):
    """
    给定 owner, repo, pull_number，请求 GitHub API 返回该 PR 对应的 merge commit sha（或 head sha）。
    用于从 swe-format 的 PR 型 instance_id 反查 detail 中的 commit。
    返回: 完整 sha 字符串，若无法获取则返回 None。
    """
    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pull_number}"
    headers = {'Accept': 'application/vnd.github+json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    pr = response.json()
    # 优先用 merge_commit_sha（已合并），否则用 head.sha
    merge_sha = pr.get('merge_commit_sha')
    if merge_sha:
        return merge_sha
    head = pr.get('head') or {}
    sha = head.get('sha')
    return sha


def curl_issues(owner, repo, pull_number, token = None):
    """
    输出的issues格式：

    [
        {
            'number': 'xxx',
            'title': 'xxx',
            'body': 'xxx'
        },
        ...
    ]
    """

    url = "https://api.github.com/graphql"
    headers = {"Authorization": f"Bearer {token}"}
    
    query = """
    query($owner: String!, $name: String!, $pr_num: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $pr_num) {
          commits {
            totalCount
          }
          closingIssuesReferences(first: 10) {
            nodes {
              number
            }
          }
        }
      }
    }
    """
    
    variables = {
        "owner": owner,
        "name": repo,
        "pr_num": int(pull_number)
    }
    
    response = requests.post(url, json={'query': query, 'variables': variables}, headers=headers)
    response.raise_for_status()
    result = response.json()
    
    pr_data = result.get('data', {}).get('repository', {}).get('pullRequest')
    if not pr_data:
        return None, []

    commit_count = pr_data['commits']['totalCount']
    issue_numbers = [issue['number'] for issue in pr_data['closingIssuesReferences']['nodes']]
    
    if commit_count != 1:
        return []
    
    issues = []

    base_url = "https://api.github.com"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Python-GitHub-API-Client"
    }

    if token:
        headers["Authorization"] = f"token {token}"

    for number in issue_numbers:
        issue_url = f"{base_url}/repos/{owner}/{repo}/issues/{number}"

        response = requests.get(issue_url, headers=headers)
        response.raise_for_status()
        
        issue_data = response.json()

        title = issue_data.get("title", "")
        body = issue_data.get("body", "")

        issues.append({
            'number': number,
            'title': title,
            'body': body
        })

    return issues


def extract_patch_from_file(file):
    filename = file['filename']
    patch_content = file.get('patch', '')
    
    if file['status'] == 'added':
        patch = f"""diff --git a/{filename} b/{filename}
new file mode 100644
--- /dev/null
+++ b/{filename}
{patch_content}"""
    elif file['status'] == 'removed':
        patch = f"""diff --git a/{filename} b/{filename}
deleted file mode 100644
--- a/{filename}
+++ /dev/null
{patch_content}"""
    elif file['status'] == 'modified':
        patch = f"""diff --git a/{filename} b/{filename}
--- a/{filename}
+++ b/{filename}
{patch_content}"""
    elif file['status'] == 'renamed':
        old_name = file.get('previous_filename', filename)
        patch = f"""diff --git a/{old_name} b/{filename}
rename from {old_name}
rename to {filename}
--- a/{old_name}
+++ b/{filename}
{patch_content}"""
    else:
        raise KeyError

    return patch


def generate_hints_text(message: str, patch: str) -> str:
    patch = patch[:20000]

    prompt = f"""You are a senior developer participating in an early-stage technical grooming session. Your goal is to generate "hints_text" by analyzing the provided code patch and reverse-engineering the technical uncertainty it addresses.

[Input]
Message: {message}
Patch: {patch}

[Context]
The provided patch is merely a reference for you to identify the affected logic. You must NOT treat this as a "fix" or a "final state." Instead, imagine you are looking at the codebase BEFORE any changes were made, and you are trying to brainstorm potential areas of concern based on the symptoms.

[Instructions]
1. Neutral Perspective: DO NOT assume the current code is broken or that the patch is a "fix". Treat the patch as a signal that the logic in these specific areas is evolving. Your hint should reflect a proactive inquiry into these areas.
2. Reverse-Engineering the Hint:
   - Identify the modules or functions touched by the patch.
   - Formulate a technical hypothesis or a "what-if" scenario that leads toward those areas.
   - For example, if the patch changes a loop's exit condition, the hint should be: "We should examine how the iterator behaves at the boundaries, as there might be a logic gap when the collection is nearly exhausted."
3. Content Style: Use investigative and collaborative phrasing. It is perfectly fine to use technical terms like "error", "check", or "logic", but use them to describe a **potential area for investigation**, not a **completed correction**.
   - Use: "It would be worth checking if...", "There is a suspicion that...", "The coordination between X and Y might need closer look regarding...".
4. Strict Non-Disclosure of the Answer:
   - DO NOT describe what the patch actually does (e.g., avoid "Added a null check", "Changed timeout to 60").
   - Describe the "Question", not the "Answer".
5. Format:
   - Plain text only. No Markdown, no hashtags, no bolding.
   - Start directly with the technical discussion. No introductory phrases like "The guidance is...".

[Goal]
The output must sound like a senior engineer's intuitive lead or a peer's suggestion during a brainstorming session. It should point the Agent to the "territory" and the "logic path" without revealing the "solution".
"""
    
    url = "https://aihubmix.com/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.6,
        "max_tokens": 800
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=60)
        response.raise_for_status()
        return response.json().get("choices", [{}])[0].get("message", {}).get("content", "")
    except Exception as e:
        print(f"DeepSeek API 错误: {e}")
        return ""


def format_patch(commit):
    if commit.get('files') is None:
        return ''

    gold_patch = ''
    test_patch = ''

    for file in commit['files']:
        patch = extract_patch_from_file(file)
        if 'test' in file['filename'].lower():
            test_patch = test_patch + patch + '\n'
        else:
            gold_patch = gold_patch + patch + '\n'
    
    return gold_patch, test_patch


def format_data(data, output, token = None):
    """
    swe-factory所需参数如下：

    instance_id        格式为 owner__repo_PR-number
    repo               格式为 owner/repo
    pull_number
    issue_numbers
    base_commit
    patch
    test_patch
    problem_statement
    hints_text
    created_at         类型为timestamp[s]
    language

    commit对应格式：

    owner
    repo
    language
    commits
    ├── sha
    ├── pull_number
    ├── parents
    │   └── sha
    ├── commit
    │   ├── committer
    │   │   └── date
    │   └── message
    ├── files
    │   ├── filename
    │   ├── status
    │   └── patch
    """

    owner = data.get('owner')
    repo = data.get('repo')
    language = data.get('language')
    commits = data.get('commits')

    formated_datas = []

    ids = set()

    for commit in commits:
        sha = commit.get('sha')
        pull_number = curl_pull_number(owner, repo, sha, token)
        
        if pull_number:
            instance_id = f'{owner}__{repo}-{pull_number}'
        else:
            instance_id = f'{owner}__{repo}-c_{sha[:7]}'

        if instance_id in ids:
            instance_id = f'{owner}__{repo}-c_{sha[:7]}'

        ids.add(instance_id)

        data_repo = f'{owner}/{repo}'

        issues = curl_issues(owner, repo, pull_number, token) \
            if pull_number else []
        issue_numbers = len(issues)

        parents = commit.get('parents')
        base_commit = parents[0].get('sha') if len(parents) else None

        patch, test_patch = format_patch(commit)

        commit_info = commit.get('commit')
        
        message = commit_info.get('message') if commit_info else None

        if issues:
            problem_statement = ''
            hints_text = ''

            for idx, issue in enumerate(issues):
                cur_problem_statement = f"{issue.get('title')}\n\n{issue.get('body')}"
                comments_list = data.get("comments", [])
    
                hint_bodies = [comment.get("body", "") for comment in comments_list]
                cur_hints_text = "\n\n".join(hint_bodies).strip()

                if issue_numbers == 1:
                    problem_statement = cur_problem_statement
                    hints_text = cur_hints_text
                else:
                    problem_statement = problem_statement + '\n\n' + \
                         f'Issue {idx + 1}: {cur_problem_statement}'
                    hints_text = hints_text + '\n\n' + \
                         f'Issue {idx + 1}: {cur_hints_text}'
        else:
            problem_statement = message
            hints_text = generate_hints_text(message, patch)

        committer = commit_info.get('committer') if commit_info else None
        date = committer.get('date') if committer else None
        dt = datetime.fromisoformat(date.replace('Z', '+00:00'))
        created_at = int(dt.timestamp())

        if not (
            instance_id and owner and repo and base_commit and 
            patch and test_patch
            ):
            continue

        formated_data = {
            'instance_id': instance_id,
            'repo': data_repo,
            'base_commit': base_commit,
            'patch': patch,
            'test_patch': test_patch,
            'problem_statement': problem_statement,
            'hints_text': hints_text,
            'created_at': created_at,
            'language': language
        }

        if pull_number:
            formated_data['pull_number'] = pull_number
        if issues:
            formated_data['issue_numbers'] = [str(issue.get('number')) for issue in issues]

        formated_datas.append(formated_data)

    path = f'{output}/{repo}_docker.json'
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(formated_datas, f, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    repo = 'browser-use'

    input_path = f'./scale/docker/batch4/{repo}.json'
    output_path = f'./scale/docker/batch4'

    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    _gh = (os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or "").strip() or None
    format_data(data, output=output_path, token=_gh)
    
    print(f'{repo} complete')
