# Data Collection Overview

The pipeline can collect swe-factory format data for refactor bench.

1. Set Path Variable

- export GITHUB_TOKEN path to curl lots of data from Github.
- export OPENAI url and api-key

If token is not provided, the pipeline will also run properly, but the data may be incomplete.

Example:

```bash
export GITHUB_TOKEN=<your token>
```

2. Run the Script

Example:

```bash
python curl_data.py --owner apache --repo zookeeper --output ./resources --time 2025-01-01T00:00:00Z
```

Where:

- ``--owner``: The repository owner. (Required)  

- ``--repo``: The repository name. (Required)

- ``--output``: The path for outputs. (default: './')

- ``--time``: The oldest time of commit. The pipeline will only collect commits later than the input time. The input is UTC, and it must be in ISO 8601 format. 