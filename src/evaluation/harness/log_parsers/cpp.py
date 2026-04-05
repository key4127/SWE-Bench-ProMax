import re
from typing import Dict

from harness.constants import TestStatus
from harness.constants import TestSpec


def parse_log_catch2(log: str, test_spec) -> Dict[str, str]:
    import re
    test_status_map = {}
    lines = log.split('\n')
    current_test = None
    for line in lines:
        stripped = line.strip()
        if re.match(r'^[\w.]+:$', stripped):
            current_test = stripped[:-1]
        elif current_test is not None:
            cleaned = re.sub(r'\x1b\[[0-9;]*m', '', stripped)
            if 'Results matched' in cleaned:
                test_status_map[current_test] = TestStatus.PASSED.value
                current_test = None
            elif 'Results differed' in cleaned:
                test_status_map[current_test] = TestStatus.FAILED.value
                current_test = None
    return test_status_map


def parse_log_googletest(log: str, test_spec) -> Dict[str, TestStatus]:
    test_status_map: Dict[str, TestStatus] = {}
    pattern = r'^\[\s*(OK|FAILED|SKIPPED|ERROR|XFAIL)\s*\]\s+(.+?)(?:\s+\(\d+ ms\))?$'
    status_map = {
        'OK': TestStatus.PASSED,
        'FAILED': TestStatus.FAILED,
        'SKIPPED': TestStatus.SKIPPED,
        'ERROR': TestStatus.ERROR,
        'XFAIL': TestStatus.XFAIL
    }

    for line in log.split('\n'):
        line = line.strip()
        match = re.match(pattern, line)
        if match:
            status_key = match.group(1)
            test_name = match.group(2).strip()
            test_status_map[test_name] = status_map[status_key]

    return test_status_map


def parse_log_deskflow(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}

    # 检测编译/构建失败（如 [17/30] FAILED: ...）
    if re.search(r'^.*\[\d+/\d+\]\s+FAILED:', log, re.MULTILINE):
        test_status_map["<build>"] = TestStatus.FAILED.value
        return test_status_map

    # 匹配 Google Test 单测结果行
    # 格式：[       OK ] TestName (时间)  或  [  FAILED  ] TestName (时间)
    gtest_pattern = re.compile(
        r'^\s*\[\s+(OK|FAILED|SKIPPED)\s+\]\s+([^\s(]+)',
        re.MULTILINE
    )

    for match in gtest_pattern.finditer(log):
        raw_status = match.group(1).upper()   # OK, FAILED, SKIPPED
        test_name = match.group(2)

        if raw_status == "OK":
            mapped = TestStatus.PASSED.value
        elif raw_status == "FAILED":
            mapped = TestStatus.FAILED.value
        elif raw_status == "SKIPPED":
            mapped = TestStatus.SKIPPED.value
        else:
            mapped = raw_status  # 备用

        test_status_map[test_name] = mapped

    return test_status_map



def parse_log_fprime(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}

    run_pattern = r"^\[\s+RUN\s+\]\s+(\S+\.\S+)$"
    failure_pattern = r"^(\S+:\d+):\s+Failure$"
    success_pattern = r"^\[\s+OK\s+\]\s+(\S+\.\S+)$"
    skipped_pattern = r"^\[\s+SKIPPED\s+\]\s+(\S+\.\S+)$"
    error_pattern = r"^\[\s+ERROR\s+\]\s+(\S+\.\S+)$"
    xfail_pattern = r"^\[\s+XFAIL\s+\]\s+(\S+\.\S+)$"
    prefix_pattern = r"^\d+:\s*(.*)$"

    current_test = None

    for line in log.split("\n"):
        line = line.strip()
        m = re.match(prefix_pattern, line)
        if m:
            cleaned_line = m.group(1)
        else:
            cleaned_line = line

        run_match = re.match(run_pattern, cleaned_line)
        if run_match:
            current_test = run_match.group(1)
            continue

        failure_match = re.match(failure_pattern, cleaned_line)
        if failure_match and current_test:
            test_status_map[current_test] = TestStatus.FAILED.value
            continue

        success_match = re.match(success_pattern, cleaned_line)
        if success_match:
            test_name = success_match.group(1)
            test_status_map[test_name] = TestStatus.PASSED.value
            current_test = None
            continue

        skipped_match = re.match(skipped_pattern, cleaned_line)
        if skipped_match:
            test_name = skipped_match.group(1)
            test_status_map[test_name] = TestStatus.SKIPPED.value
            current_test = None
            continue

        error_match = re.match(error_pattern, cleaned_line)
        if error_match:
            test_name = error_match.group(1)
            test_status_map[test_name] = TestStatus.ERROR.value
            current_test = None
            continue

        xfail_match = re.match(xfail_pattern, cleaned_line)
        if xfail_match:
            test_name = xfail_match.group(1)
            test_status_map[test_name] = TestStatus.XFAIL.value
            current_test = None

    return test_status_map


def parse_log_wasmedge(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}

    # Patterns for Google Test output
    ok_pattern = re.compile(r'^\[\s+OK\s+\]\s+(\S+\.\S+)\s+\(\d+\s+ms\)$')
    failed_pattern = re.compile(r'^\[\s+FAILED\s+\]\s+(\S+\.\S+)\s+\(\d+\s+ms\)$')
    skipped_pattern = re.compile(r'^\[\s+SKIPPED\s+\]\s+(\S+\.\S+)\s+\(\d+\s+ms\)$')

    for line in log.splitlines():
        line = line.rstrip()

        match = ok_pattern.match(line)
        if match:
            test_name = match.group(1)
            test_status_map[test_name] = TestStatus.PASSED.value
            continue

        match = failed_pattern.match(line)
        if match:
            test_name = match.group(1)
            test_status_map[test_name] = TestStatus.FAILED.value
            continue

        match = skipped_pattern.match(line)
        if match:
            test_name = match.group(1)
            test_status_map[test_name] = TestStatus.SKIPPED.value
            continue

    return test_status_map


def parse_log_openorienteering(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}
    pattern = re.compile(r"^\s*\d+/\d+\s+Test\s+#\d+:\s+([^\.]+)\.+\s+(\w+)")
    
    status_map = {
        "Passed": TestStatus.PASSED,
        "Failed": TestStatus.FAILED,
        "Skipped": TestStatus.SKIPPED,
        "Not Run": TestStatus.SKIPPED,
        "XFAIL": TestStatus.XFAIL
    }
    
    for line in log.splitlines():
        match = pattern.match(line)
        if match:
            test_name = match.group(1).strip()
            status_raw = match.group(2)
            test_status_map[test_name] = status_map.get(status_raw, TestStatus.ERROR).value
    
    return test_status_map


def parse_log_etl(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}
    pattern = r"test_(\w+)\.cpp"
    for line in log.split("\n"):
        match = re.search(pattern, line)
        if match:
            test_name = match.group(1)
            test_status_map[test_name] = TestStatus.PASSED.value
    return test_status_map


def parse_log_lmms(log: str, test_spec) -> dict[str, str]:
    test_status_map = {}
    pattern = re.compile(r'\d+/\d+ Test\s+#\d+:\s+(\S+)\s+\.+\s+(\S+)')
    for line in log.splitlines():
        match = pattern.search(line)
        if match:
            test_name = match.group(1)
            status_str = match.group(2)
            if status_str == 'Passed':
                status = TestStatus.PASSED.value
            elif status_str == 'Failed':
                status = TestStatus.FAILED.value
            elif status_str == 'Skipped':
                status = TestStatus.SKIPPED.value
            else:
                status = TestStatus.ERROR.value
            test_status_map[test_name] = status
    return test_status_map


def parse_log_blazingmq(log: str, test_spec) -> Dict[str, str]:
    test_status_map = {}

    if re.search(r"^\s*FAILED:\s+", log, re.MULTILINE):
        return {"<build>": TestStatus.FAILED.value}

    pattern = r"^\d+/\d+ Test #\d+: (\S+) \.+ +(\S+) +[\d.]+ sec"
    for line in log.splitlines():
        line = line.strip()
        match = re.match(pattern, line)
        if match:
            test_name = match.group(1)
            status_str = match.group(2).upper()
            if "PASSED" in status_str:
                status = TestStatus.PASSED.value
            elif "FAILED" in status_str:
                status = TestStatus.FAILED.value
            elif "SKIPPED" in status_str:
                status = TestStatus.SKIPPED.value
            else:
                status = TestStatus.ERROR.value
            test_status_map[test_name] = status

    return test_status_map


def _strip_ansi_icinga2(line: str) -> str:
    """Remove ANSI escape sequences so Boost.Test lines can be matched."""
    return re.sub(r"\033\[[0-9;]*m", "", line)


def parse_log_icinga2(log: str, test_spec: TestSpec) -> Dict[str, str]:
    """
    Parse Icinga2 test log. Icinga2 uses Boost.Test; output is HRF (Human Readable Format)
    with lines like:
      - "Test suite \"...\" is skipped because disabled"
      - "Entering test case \"...\""
      - "info: check ... has passed" / "has failed"
      - "error in \"test_name\": ..."
    When no Boost-style lines match, we do NOT rely on exit code only: if the log
    contains global failure signals we still mark failed.
    """
    print("[Parse Icinga2 Log]")

    test_status_map: Dict[str, str] = {}

    # Build/runner failure (e.g. CTest FAILED:)
    if re.search(r"^\s*FAILED:\s+", log, re.MULTILINE):
        test_status_map["<build>"] = TestStatus.FAILED.value
        return test_status_map

    # Boost.Test summary failure (e.g. "*** N failures are detected")
    if re.search(r"failures?\s+are\s+detected|failure\s+in\s+", log, re.IGNORECASE):
        test_status_map["<boost>"] = TestStatus.FAILED.value
        return test_status_map

    current_test: str | None = None
    current_suite: str | None = None

    # Patterns for CTest/other runners (keep for compatibility)
    ok_pattern = re.compile(r"^\[\s*OK\s*\]\s+(\w+\.\w+)")
    failed_pattern = re.compile(r"^\[\s*FAILED\s*\]\s+(\w+\.\w+)")
    skipped_pattern = re.compile(r"^\[\s*SKIPPED\s*\]\s+(\w+\.\w+)")
    pass_pattern = re.compile(r"^\s*(PASS|PASS\s*:\s*\S+)")
    fail_pattern = re.compile(r"^\s*(FAIL|FAIL\s*:\s*\S+)")

    # Boost.Test HRF patterns (ANSI may wrap lines)
    entering_case = re.compile(r'Entering test case\s+"([^"]+)"')
    leaving_case = re.compile(r'Leaving test case\s+"([^"]+)"')
    suite_skipped = re.compile(r'Test suite\s+"([^"]+)"\s+is skipped because disabled')
    error_in = re.compile(r'error in\s+"([^"]+)"')

    for raw_line in log.split("\n"):
        line = _strip_ansi_icinga2(raw_line).strip()
        if not line:
            continue

        # CTest-style [ OK ] / [ FAILED ] / [ SKIPPED ]
        m = ok_pattern.match(line)
        if m:
            test_status_map[m.group(1)] = TestStatus.PASSED.value
            continue
        m = failed_pattern.match(line)
        if m:
            test_status_map[m.group(1)] = TestStatus.FAILED.value
            continue
        m = skipped_pattern.match(line)
        if m:
            test_status_map[m.group(1)] = TestStatus.SKIPPED.value
            continue
        if pass_pattern.match(line):
            test_status_map[f"test_{len(test_status_map)}"] = TestStatus.PASSED.value
            continue
        if fail_pattern.match(line):
            test_status_map[f"test_{len(test_status_map)}"] = TestStatus.FAILED.value
            continue

        # Boost.Test: suite skipped
        m = suite_skipped.search(line)
        if m:
            name = m.group(1)
            test_status_map[name] = TestStatus.SKIPPED.value
            continue

        # Boost.Test: entering test case
        m = entering_case.search(line)
        if m:
            current_test = m.group(1)
            if current_suite:
                name = f"{current_suite}::{current_test}"
            else:
                name = current_test
            if name not in test_status_map:
                test_status_map[name] = TestStatus.PASSED.value
            continue

        # Boost.Test: error in "test_name" (failure)
        m = error_in.search(line)
        if m:
            name = m.group(1)
            if current_suite and current_test and name == current_test:
                test_status_map[f"{current_suite}::{name}"] = TestStatus.FAILED.value
            else:
                test_status_map[name] = TestStatus.FAILED.value
            current_test = None
            continue

        # Boost.Test: "has failed" in this line → current test failed
        if "has failed" in line:
            if current_test:
                key = f"{current_suite}::{current_test}" if current_suite else current_test
                test_status_map[key] = TestStatus.FAILED.value
            else:
                test_status_map["<boost>"] = TestStatus.FAILED.value
            current_test = None
            continue

        # Boost.Test: "Entering test suite" to track suite for case names
        if 'Entering test suite "' in line:
            m = re.search(r'Entering test suite\s+"([^"]+)"', line)
            if m:
                current_suite = m.group(1)
        if 'Leaving test suite "' in line:
            current_suite = None

        m = leaving_case.search(line)
        if m:
            current_test = None
            continue

        # "info: check ... has passed" → keep current test as passed (already default)
        # No need to change status
    return test_status_map


def parse_log_cppcheck(log: str, test_spec: TestSpec) -> Dict[str, str]:
    print("[Parse Cppcheck Unit Test Log]")
    
    test_status_map: Dict[str, str] = {}
    
    if re.search(r"error:", log, re.IGNORECASE) and not re.search(r"Number of tests:", log):
        if not re.search(r"Testing Complete", log):
            test_status_map["<build>"] = TestStatus.FAILED.value
            return test_status_map
    
    test_case_pattern = r"^([a-zA-Z0-9_]+::[a-zA-Z0-9_]+)$"
    
    for line in log.split("\n"):
        line = line.strip()
        
        if not line:
            continue
            
        test_match = re.match(test_case_pattern, line)
        if test_match:
            test_name = test_match.group(1)
            test_status_map[test_name] = TestStatus.PASSED.value
        
        if "OMNIGRIL_EXIT_CODE=" in line:
            try:
                exit_code = int(line.split("=")[1].strip())
                if exit_code != 0:
                    test_status_map.clear()
                    test_status_map["<build>"] = TestStatus.FAILED.value
                    return test_status_map
            except (ValueError, IndexError):
                test_status_map["<build>"] = TestStatus.FAILED.value
                return test_status_map
    
    if not test_status_map and "Testing Complete" in log:
        test_status_map["<build>"] = TestStatus.PASSED.value
    
    return test_status_map


def parse_not_index(log: str, test_spec: TestSpec):
    return {
        'Test': TestStatus.FAILED.value
    }


MAP_REPO_TO_PARSER_CPP = {
    "catchorg/Catch2": parse_log_catch2,
    "google/googletest": parse_log_googletest,
    "deskflow/deskflow": parse_log_deskflow,
    "nasa/fprime": parse_log_fprime,
    "WasmEdge/WasmEdge": parse_log_wasmedge,
    "at-wat/mcl_3dl": parse_not_index,
    "OpenOrienteering/mapper": parse_log_openorienteering,
    "ETLCPP/etl": parse_log_etl,
    "QuEST-Kit/QuEST": parse_not_index,
    "LMMS/lmms": parse_log_lmms,
    "bloomberg/blazingmq": parse_log_blazingmq,
    "Icinga/icinga2": parse_log_icinga2,
    "danmar/cppcheck": parse_log_cppcheck
}