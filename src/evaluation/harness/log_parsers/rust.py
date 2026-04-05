import re

from harness.constants import TestStatus
from harness.constants import TestSpec


def parse_log_cargo(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Args:
        log (str): log content
    Returns:
        dict: test case to test status mapping
    """
    print("[Parse Cargo Log]")

    test_status_map = {}

    pattern = r"^test\s+(\S+)\s+\.\.\.\s+(\w+)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            test_name, outcome = match.groups()
            if outcome == "ok":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif outcome == "FAILED":
                test_status_map[test_name] = TestStatus.FAILED.value

    return test_status_map


MAP_REPO_TO_PARSER_RUST = {
    "openai/codex": parse_log_cargo,
    "fish-shell/fish-shell": parse_log_cargo,
    "qdrant/qdrant": parse_log_cargo,
    "tracel-ai/burn": parse_log_cargo,
    "YaLTeR/niri": parse_log_cargo,
    "TabbyML/tabby": parse_log_cargo,
    "jj-vcs/jj": parse_log_cargo,
    "rustfs/rustfs": parse_log_cargo,
    "firecracker-microvm/firecracker": parse_log_cargo,
    "astral-sh/ruff": parse_log_cargo,
    "rust-lang/cargo": parse_log_cargo,
}