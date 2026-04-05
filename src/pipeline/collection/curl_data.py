import argparse
import os

from curl_commits import curl_filtered_commits as curl_func
from format_data import format_data as format_func


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--owner', type=str, required=True, help='Repository Owner')
    parser.add_argument('--repo', type=str, required=True, help='Repository Name')
    parser.add_argument(
        '-output', type=str, required=False,
        help='Path to output files')
    parser.add_argument(
        '--time', type=str, required=False,
        help='The oldest time of commit. Please input in ISO 8601 format.'
    )
    args = parser.parse_args()
    
    token = os.environ.get('GITHUB_TOKEN')
    if not token:
        print('Warning: Github Token Not Found.')
    
    commits_data = curl_func(
        owner=args.owner,
        repo=args.repo,
        output_path=args.output,
        since_time=args.time,
        token=token
    )
    format_func(data=commits_data, token=token)

if __name__ == '__main__':
    main()