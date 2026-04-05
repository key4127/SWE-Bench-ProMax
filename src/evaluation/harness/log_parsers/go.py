import re

from harness.constants import TestStatus
from harness.constants import TestSpec


def parse_log_gotest(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Parser for test logs generated with 'go test'

    Args:
        log (str): log content
        test_spec (TestSpec): test spec (unused)
    Returns:
        dict: test case to test status mapping
    """
    print("[Parse Go Log]")

    test_status_map = {}

    # Pattern to match test result lines
    pattern = r"^--- (PASS|FAIL|SKIP): (.+) \((.+)\)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name, _duration = match.groups()
            if status == "PASS":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAIL":
                test_status_map[test_name] = TestStatus.FAILED.value
            elif status == "SKIP":
                test_status_map[test_name] = TestStatus.SKIPPED.value

    return test_status_map


MAP_REPO_TO_PARSER_GO = {
    "caddyserver/caddy": parse_log_gotest,
    "istio/istio": parse_log_gotest,
    "kubernetes/kubernetes": parse_log_gotest,
    "rclone/rclone": parse_log_gotest,
    "prometheus/prometheus": parse_log_gotest,
    "gohugoio/hugo": parse_log_gotest,
    "gin-gonic/gin": parse_log_gotest,
    "cli/cli": parse_log_gotest,
    "pingcap/tidb": parse_log_gotest,
    "moby/moby": parse_log_gotest,
    "go-gitea/gitea": parse_log_gotest,
    "jesseduffield/lazygit": parse_log_gotest,
    "charmbracelet/crush": parse_log_gotest,
    "restic/restic": parse_log_gotest,
    "TecharoHQ/anubis": parse_log_gotest,
    "trufflesecurity/trufflehog": parse_log_gotest,
    "samber/lo": parse_log_gotest,
    "redis/go-redis": parse_log_gotest,
    "OpenListTeam/OpenList": parse_log_gotest,
    "antonmedv/fx": parse_log_gotest,
    "cockroachdb/cockroach": parse_log_gotest,
    "spf13/viper": parse_log_gotest,
    "hashicorp/nomad": parse_log_gotest,
    "terrastruct/d2": parse_log_gotest,
    "syncthing/syncthing": parse_log_gotest,
    "spf13/cobra": parse_log_gotest,
    "containers/podman": parse_log_gotest,
    "grpc/grpc-go": parse_log_gotest,
    "go-kratos/kratos": parse_log_gotest,
    "livekit/livekit": parse_log_gotest,
    "henrygd/beszel": parse_log_gotest,
    "gitleaks/gitleaks": parse_log_gotest,
    "dolthub/dolt": parse_log_gotest,
    "derailed/k9s": parse_log_gotest,
    "rqlite/rqlite": parse_log_gotest,
}