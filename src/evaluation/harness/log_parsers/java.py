import re
import xml.etree.ElementTree as ET 

from harness.constants import TestStatus
from harness.constants import TestSpec


def parse_log_maven(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Parser for test logs generated with 'mvn test'.
    Annoyingly maven will not print the tests that have succeeded. For this log
    parser to work, each test must be run individually, and then we look for
    BUILD (SUCCESS|FAILURE) in the logs.

    Handles race conditions where multiple test commands appear before their
    BUILD results due to concurrent output from shell tracing and Maven.

    Args:
        log (str): log content
    Returns:
        dict: test case to test status mapping
    """
    print("[Parse Maven Log]")

    test_status_map = {}
    pending_tests: list[str] = []
    unmatched_results: list[str] = []

    # Get the test name from the command used to execute the test.
    # Assumes we run evaluation with set -x
    test_name_pattern = r"^.*-Dtest=(\S+).*$"
    result_pattern = r"^.*BUILD (SUCCESS|FAILURE)$"

    for line in log.split("\n"):
        test_name_match = re.match(test_name_pattern, line.strip())
        if test_name_match:
            pending_tests.append(test_name_match.groups()[0])

        result_match = re.match(result_pattern, line.strip())
        if result_match:
            status = result_match.groups()[0]
            if pending_tests:
                test_name = pending_tests.pop(0)
                if status == "SUCCESS":
                    test_status_map[test_name] = TestStatus.PASSED.value
                elif status == "FAILURE":
                    test_status_map[test_name] = TestStatus.FAILED.value
            else:
                # Track unmatched results for later matching
                unmatched_results.append(status)

    # Match any remaining pending tests with unmatched results (FIFO order)
    # This handles cases where BUILD results appear after other output
    while pending_tests and unmatched_results:
        test_name = pending_tests.pop(0)
        status = unmatched_results.pop(0)
        if status == "SUCCESS":
            test_status_map[test_name] = TestStatus.PASSED.value
        elif status == "FAILURE":
            test_status_map[test_name] = TestStatus.FAILED.value

    # Warn if there are still pending tests without results
    if pending_tests:
        print(
            f"[WARNING] Maven log parser: {len(pending_tests)} test(s) had no BUILD result: "
            f"{pending_tests}"
        )

    return test_status_map


def parse_log_ant(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Java Ant Log]")

    test_status_map = {}

    pattern = r"^\s*\[junit\]\s+\[(PASS|FAIL|ERR)\]\s+(.*)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name = match.groups()
            if status == "PASS":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status in ["FAIL", "ERR"]:
                test_status_map[test_name] = TestStatus.FAILED.value

    return test_status_map


def parse_log_gradle_custom(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Parser for test logs generated with 'gradle test'. Assumes that the
    pre-install script to update the gradle config has run.

    Handles race conditions where test name and status appear on different lines
    due to interleaved log output from concurrent processes.
    """
    print("[Parse Gradle Log]")

    test_status_map = {}

    # Pattern for normal case: test name and status on the same line
    # e.g., "com.example.Test > testMethod PASSED"
    # [^>] ensures we don't match lines starting with > (shell prompts, etc.)
    full_pattern = r"^([^>].+)\s+(PASSED|FAILED)$"

    # Pattern for test name without status (race condition case)
    # e.g., "com.example.Test > testMethod" followed by warnings, then "PASSED"
    # Must also start with [^>] for consistency
    test_name_pattern = r"^([^>]\S*\s+>\s+\S+)$"

    # Pattern for standalone status line
    status_only_pattern = r"^(PASSED|FAILED)$"

    pending_test_name = None

    for line in log.split("\n"):
        stripped = line.strip()

        # Check for full match (test name + status on same line)
        match = re.match(full_pattern, stripped)
        if match:
            test_name, status = match.groups()
            if status == "PASSED":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAILED":
                test_status_map[test_name] = TestStatus.FAILED.value
            pending_test_name = None
            continue

        # Check for test name without status
        test_name_match = re.match(test_name_pattern, stripped)
        if test_name_match:
            pending_test_name = test_name_match.group(1)
            continue

        # Check for standalone status (applies to pending test name)
        if pending_test_name:
            status_match = re.match(status_only_pattern, stripped)
            if status_match:
                status = status_match.group(1)
                if status == "PASSED":
                    test_status_map[pending_test_name] = TestStatus.PASSED.value
                elif status == "FAILED":
                    test_status_map[pending_test_name] = TestStatus.FAILED.value
                pending_test_name = None

    # Warn if there's a pending test without a result
    if pending_test_name:
        print(
            f"[WARNING] Gradle log parser: test had no status result: {pending_test_name}"
        )

    return test_status_map


def parse_log_bazel(log: str, test_spec: TestSpec) -> dict[str, str]:  
    print("[Parse Bazel Log]")  
  
    test_status_map: dict[str, str] = {}  
  
    console_pattern = re.compile(  
        r"^(?P<target>//[^\s]+)\s+(?P<status>PASSED|FAILED|FLAKY)(?:\s+in\s+[\d.]+s)?"  
    )  
  
    log_passed_pattern = re.compile(r"^\s*(?P<test_name>\S+)\s+PASSED\s*$")  
    log_failed_pattern = re.compile(r"^\s*(?P<test_name>\S+)\s+(FAILED|ERROR)\s*$")  
  
    for line in log.splitlines():  
        line = line.strip()  
        m = console_pattern.match(line)  
        if m:  
            target = m.group("target")  
            status = m.group("status")  
            if status == "PASSED":  
                test_status_map[target] = TestStatus.PASSED.value  
            elif status == "FAILED":  
                test_status_map[target] = TestStatus.FAILED.value  
            elif status == "FLAKY":  
                test_status_map[target] = TestStatus.FAILED.value  
            continue  
  
        m_passed = log_passed_pattern.match(line)  
        if m_passed:  
            test_name = m_passed.group("test_name")  
            test_status_map[test_name] = TestStatus.PASSED.value  
            continue  
        m_failed = log_failed_pattern.match(line)  
        if m_failed:  
            test_name = m_failed.group("test_name")  
            test_status_map[test_name] = TestStatus.FAILED.value  
            continue  
  
    if not test_status_map:    
        if "<testsuite" in log:  
            root = ET.fromstring(log)  
            for case in root.iter("testcase"):  
                name = case.get("name", "")  
                # Determine status based on failure/error elements  
                if case.find("failure") is not None or case.find("error") is not None:  
                    test_status_map[name] = TestStatus.FAILED.value  
                else:  
                    test_status_map[name] = TestStatus.PASSED.value  
    return test_status_map


MAP_REPO_TO_PARSER_JAVA = {
    "alibaba/nacos": parse_log_maven,
    "spring-projects/spring-boot": parse_log_gradle_custom,
    "gocd/gocd": parse_log_ant,
    "bazelbuild/bazel": parse_log_bazel,
    "apache/pinot": parse_log_maven,
    "stanfordnlp/CoreNLP": parse_log_ant,
    "apache/hbase": parse_log_maven,
    "apache/fesod": parse_log_maven,
    "geoserver/geoserver": parse_log_maven,
    "apache/calcite": parse_log_gradle_custom,
    "MuntashirAkon/AppManager": parse_log_gradle_custom,
    "dromara/Sa-Token": parse_log_maven,
    "apache/maven": parse_log_maven,
    "spring-projects/spring-security": parse_log_gradle_custom,
    "hibernate/hibernate-orm": parse_log_gradle_custom,
    "plantuml/plantuml": parse_log_gradle_custom,
    "google/gson": parse_log_maven,
    "spring-cloud/spring-cloud-gateway": parse_log_maven,
    "swagger-api/swagger-core": parse_log_maven,
    "apache/iceberg": parse_log_gradle_custom
}