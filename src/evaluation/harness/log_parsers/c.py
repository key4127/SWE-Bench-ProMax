import re
import xml.etree.ElementTree as ET

from harness.constants import TestStatus
from harness.constants import TestSpec


def parse_log_redis(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Args:
        log (str): log content
    Returns:
        dict: test case to test status mapping
    """
    print("[Parse Redis Log]")

    test_status_map = {}

    pattern = r"^\[(ok|err|skip|ignore)\]:\s(.+?)(?:\s\((\d+\s*m?s)\))?$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name, _duration = match.groups()
            if status == "ok":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "err":
                # Strip out file path information from failed test names
                test_name = re.sub(r"\s+in\s+\S+$", "", test_name)
                test_status_map[test_name] = TestStatus.FAILED.value
            elif status == "skip" or status == "ignore":
                test_status_map[test_name] = TestStatus.SKIPPED.value

    return test_status_map


def parse_log_jq(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Args:
        log (str): log content
    Returns:
        dict: test case to test status mapping
    """
    print("[Parse Jq Log]")

    test_status_map = {}

    pattern = r"^\s*(PASS|FAIL):\s(.+)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name = match.groups()
            if status == "PASS":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAIL":
                test_status_map[test_name] = TestStatus.FAILED.value
    return test_status_map


def parse_log_doctest(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Assumes test binary runs with -s -r=xml.
    """
    print("[Parse Doctest Log]")

    test_status_map = {}

    # Extract XML content
    start_tag = "<doctest"
    end_tag = "</doctest>"
    start_index = log.find(start_tag)
    end_index = (
        log.find(end_tag, start_index) + len(end_tag) if start_index != -1 else -1
    )

    if start_index != -1 and end_index != -1:
        xml_string = log[start_index:end_index]
        root = ET.fromstring(xml_string)

        for testcase in root.findall(".//TestCase"):
            testcase_name = testcase.get("name")
            for subcase in testcase.findall(".//SubCase"):
                subcase_name = subcase.get("name")
                name = f"{testcase_name} > {subcase_name}"

                expressions = subcase.findall(".//Expression")
                subcase_passed = all(
                    expr.get("success") == "true" for expr in expressions
                )

                if subcase_passed:
                    test_status_map[name] = TestStatus.PASSED.value
                else:
                    test_status_map[name] = TestStatus.FAILED.value

    return test_status_map


def parse_log_micropython_test(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Micropython Log]")
    
    test_status_map = {}

    pattern = r"^(pass|FAIL|skip)\s+(.+)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name = match.groups()
            if status == "pass":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAIL":
                test_status_map[test_name] = TestStatus.FAILED.value
            elif status == "skip":
                test_status_map[test_name] = TestStatus.SKIPPED.value

    return test_status_map


def parse_log_googletest(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Googletest Log]")
    
    test_status_map = {}

    pattern = r"^.*\[\s*(OK|FAILED)\s*\]\s(.*)\s\(.*\)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name = match.groups()
            if status == "OK":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAILED":
                test_status_map[test_name] = TestStatus.FAILED.value

    return test_status_map


def parse_log_openssl(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Openssl Log]")
    test_status_map = {}
    # 匹配测试结果行，例如：
    #   00-prep_fipsmodule_cnf.t .. skipped: FIPS module config file only supported in a fips build
    #   25-test_verify_store.t .. ok
    pattern = re.compile(r'^([^ ]+\.t) \.\.[ \t]+([a-zA-Z]+)(?::.*)?$')
    for line in log.split("\n"):
        line = _strip_ansi(line.strip())
        m = pattern.match(line)
        if m:
            test_name, status = m.groups()
            status_lower = status.lower()
            if status_lower == 'ok':
                test_status_map[test_name] = "passed"
            elif status_lower == 'skipped':
                test_status_map[test_name] = "skipped"
            elif status_lower in ('failed', 'fail'):
                test_status_map[test_name] = "failed"
            else:
                test_status_map[test_name] = status_lower  # 保留其他状态
    return test_status_map


def _strip_ansi(line: str) -> str:
    """Remove ANSI escape sequences (e.g. \\033[32m, \\033[0m) so meson test lines can be matched."""
    return re.sub(r"\033\[[0-9;]*m", "", line)


def parse_log_r2r(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Parse radare2 test runner logs into a mapping of test name -> status.
    Handles:
    1) r2r format: "test_name OK" / "test_name XX" (line ends with tag).
    2) Meson unit test format: "1/1 codemeta OK 0.03s" and ANSI-wrapped lines
       like "[1mtest_r_codemeta_new[0m [32mOK[0m"; also "Fail: 0" summary.
    3) New observed format: 
       "[1/0] /testbed/test/db/cmd/cmd_pp        1 OK         0 BR        0 XX        0 SK        0 FX"
    """
    print("[Parse Radare2 Log]")

    test_status_map: dict[str, str] = {}
    tag_to_status = {"OK": "passed", "XX": "failed", "BR": "broken", "FX": "fixed"}

    # 1) Classic r2r: line ends with exactly OK|XX|BR|FX
    pattern_r2r = re.compile(r"^(.+)\s+(OK|XX|BR|FX)\s*$")
    # 2) Meson: optional trailing duration (e.g. " OK 0.03s") and ANSI-stripped lines
    pattern_meson = re.compile(r"^(.+?)\s+(OK|XX|BR|FX)(?:\s+[\d.]+s)?\s*$")
    # 3) New format: [index/total] test_path   <counts> (capture test_path and counts)
    pattern_new = re.compile(r"^\s*\[\d+/\d+\]\s+(\S+)\s+(\d+)\s+OK\s+(\d+)\s+BR\s+(\d+)\s+XX\s+(\d+)\s+SK\s+(\d+)\s+FX\s*$")

    for line in log.split("\n"):
        raw_stripped = line.strip()
        if not raw_stripped:
            continue

        # Try new format first (most specific)
        m_new = pattern_new.match(raw_stripped) or pattern_new.match(_strip_ansi(raw_stripped))
        if m_new:
            test_path, ok_count, br_count, xx_count, sk_count, fx_count = m_new.groups()
            # Determine overall status based on counts
            if int(xx_count) > 0:
                status = "failed"
            elif int(br_count) > 0:
                status = "broken"
            elif int(ok_count) > 0:
                # If any OK and no failures/broken, consider passed
                status = "passed"
            elif int(fx_count) > 0:
                # FX might indicate fixed (expected failure passed) – treat as passed? Usually fixed is a success.
                status = "fixed"  # or "passed"? Map to fixed as defined.
            else:
                status = "unknown"
            # Clean test name: remove leading /testbed/ if present to get relative path
            test_name = test_path.lstrip('/').replace('testbed/', '', 1) if test_path.startswith('/testbed/') else test_path
            test_status_map[test_name] = status
            continue

        # Try other formats (r2r and meson)
        for candidate in (raw_stripped, _strip_ansi(raw_stripped)):
            m = pattern_r2r.match(candidate) or pattern_meson.match(candidate)
            if m:
                test_name, tag = m.groups()
                test_name = test_name.strip()
                if not test_name:
                    continue
                status = tag_to_status.get(tag, "unknown")
                test_status_map[test_name] = status
                break

    # 3) Meson summary only: no per-test lines matched but exit 0 and "Fail: 0"
    if not test_status_map and "OMNIGRIL_EXIT_CODE=0" in log:
        if re.search(r"Fail:\s*0\s", log) or re.search(r"Fail:\s*0\s*$", log, re.MULTILINE):
            test_status_map["meson"] = "passed"

    return test_status_map


def parse_log_esp_idf(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse ESP-IDF Log]")

    test_status_map = {}

    if "OMNIGRIL_EXIT_CODE=0" in log:
        if "Project build complete" in log or "ledc_test.bin" in log or "Successfully created ESP32 image" in log:
            test_status_map["build"] = TestStatus.PASSED.value
            return test_status_map

    unity_pattern = r"^(.+?)\.\.\.(PASS|FAIL|IGNORE)(?:\s+\((\d+)\s*ms\))?$"
    summary_pattern = r"(\d+)\s+Tests\s+(\d+)\s+Failures\s+(\d+)\s+Ignored"
    test_case_pattern = r"^Running\s+(.+?)\.\.\.$"
    pytest_result_pattern = r"^(PASS|FAIL|SKIP|IGNORE)\s+(.+)$"
    
    current_test = None
    
    for line in log.split("\n"):
        line = line.strip()
        if not line:
            continue
            
        test_match = re.match(test_case_pattern, line)
        if test_match:
            current_test = test_match.group(1)
            continue
            
        unity_match = re.match(unity_pattern, line)
        if unity_match:
            test_name, status, _duration = unity_match.groups()
            if status == "PASS":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAIL":
                test_status_map[test_name] = TestStatus.FAILED.value
            elif status == "IGNORE":
                test_status_map[test_name] = TestStatus.SKIPPED.value
            current_test = None
            continue
            
        pytest_match = re.match(pytest_result_pattern, line)
        if pytest_match:
            status, test_name = pytest_match.groups()
            if status == "PASS":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAIL":
                test_status_map[test_name] = TestStatus.FAILED.value
            elif status in ["SKIP", "IGNORE"]:
                test_status_map[test_name] = TestStatus.SKIPPED.value
            current_test = None
            continue
            
        if current_test:
            if line == "PASS":
                test_status_map[current_test] = TestStatus.PASSED.value
                current_test = None
            elif line == "FAIL":
                test_status_map[current_test] = TestStatus.FAILED.value
                current_test = None
            elif line in ["IGNORE", "SKIP"]:
                test_status_map[current_test] = TestStatus.SKIPPED.value
                current_test = None
                
        summary_match = re.search(summary_pattern, line)
        if summary_match and not test_status_map:
            total, failed, ignored = map(int, summary_match.groups())
            if failed == 0:
                test_status_map["all_tests"] = TestStatus.PASSED.value
            elif failed > 0:
                test_status_map["all_tests"] = TestStatus.FAILED.value
                
    if not test_status_map and "OMNIGRIL_EXIT_CODE=0" in log:
        if "Project build complete" in log or "ledc_test.bin" in log:
            test_status_map["build"] = TestStatus.PASSED.value
        
    return test_status_map


def parse_log_libyang(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Libyang Log]")

    test_status_map = {}

    # 匹配 CTest 输出的测试结果行
    # 格式示例: "1/2 Test #13: utest_yang_types .................   Passed    0.04 sec"
    pattern = r'^\d+/\d+ Test #\d+: (.*?)\.*\s+(Passed|Failed|Skipped|Disabled)'

    for line in log.split("\n"):
        line = line.strip()
        m = re.match(pattern, line)
        if m:
            test_name, status = m.groups()
            test_name = test_name.rstrip('. ')
            if status == "Passed":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "Skipped":
                test_status_map[test_name] = TestStatus.SKIPPED.value
            else:
                test_status_map[test_name] = TestStatus.FAILED.value

    return test_status_map


def parse_log_krep(log: str, test_spec: TestSpec) -> dict[str, str]:  
    print("[Parse Krep Log]")  
  
    test_status_map = {}  
  
    pattern = r"^\s*(✓ PASS|✗ FAIL):\s(.+)$"  
  
    for line in log.split("\n"):  
        match = re.match(pattern, line.strip())  
        if match:  
            status, test_name = match.groups()  
            if status == "✓ PASS":  
                test_status_map[test_name] = TestStatus.PASSED.value  
            elif status == "✗ FAIL":  
                test_status_map[test_name] = TestStatus.FAILED.value  
  
    return test_status_map


def parse_not_inex(log: str, test_spec: TestSpec) -> dict[str, str]:
    return {
        "Test": TestStatus.FAILED.value
    }


def parse_log_iso14229(log: str, test_spec: TestSpec) -> dict[str, str]:  
    print("[Parse ISO14229 Log]")  
      
    test_status_map = {}  
      
    patterns = [  
        r"^\[\s*OK\s*\]\s+(.+)$",  
        r"^\[\s*FAILED\s*\]\s+(.+)$",  
        r"^\[\s*PASS\s*\]\s+(.+)$",  
        r"^\[\s*ERROR\s*\]\s+(.+)$",  
        r"^\[\s*SKIP\s*\]\s+(.+)$"  
    ]  
      
    for line in log.split("\n"):  
        line = line.strip()  
        for pattern in patterns:  
            match = re.match(pattern, line)  
            if match:  
                test_name = match.groups()[0]  
                if "OK" in line or "PASS" in line:  
                    test_status_map[test_name] = TestStatus.PASSED.value  
                elif "FAILED" in line or "ERROR" in line:  
                    test_status_map[test_name] = TestStatus.FAILED.value  
                elif "SKIP" in line:  
                    test_status_map[test_name] = TestStatus.SKIPPED.value  
                break  
      
    return test_status_map


def parse_log_betaflight(log: str, test_spec: TestSpec) -> dict[str, str]:
    print("[Parse Betaflight Log]")

    test_status_map = {}

    pattern = r"^\[\s*(OK|FAILED)\s*\]\s+(.+?)\s+\(\d+\s*ms\)$"

    for line in log.split("\n"):
        match = re.match(pattern, line.strip())
        if match:
            status, test_name = match.groups()
            if status == "OK":
                test_status_map[test_name] = TestStatus.PASSED.value
            elif status == "FAILED":
                test_status_map[test_name] = TestStatus.FAILED.value

    return test_status_map


def parse_log_bluezalsa(log: str, test_spec) -> dict[str, str]:
    print("[Parse BlueALSA Log]")
    test_status_map = {}
    
    lines = log.split("\n")
    current_suite = None
    
    for line in lines:
        line = line.strip()
        
        suite_match = re.match(r"Running suite\(s\):\s+(.+)$", line)
        if suite_match:
            current_suite = suite_match.group(1).strip()
            continue
        
        result_match = re.match(r"\d+%:\s+Checks:\s+(\d+),\s+Failures:\s+(\d+),\s+Errors:\s+(\d+)", line)
        if result_match and current_suite:
            checks, failures, errors = map(int, result_match.groups())
            if failures == 0 and errors == 0:
                test_status_map[current_suite] = TestStatus.PASSED.value
            else:
                test_status_map[current_suite] = TestStatus.FAILED.value
            current_suite = None
    
    return test_status_map


def parse_log_s2n_tls(log: str, test_spec: TestSpec) -> dict[str, str]:
    """
    Parse s2n-tls test log into test name -> status mapping.
    Supports:
    1) CTest format: "  1/200 Test  #1: s2n_xxx_test ..... Passed  0.01 sec" or "***Failed"
    2) s2n_test.h runner: "Running <file> ... " followed by "PASSED N tests" / "SKIPPED ALL tests" / "FAILED test N"
    3) Rust test output: "test <name> ... ok" or "test <name> ... FAILED"
    """
    print("[Parse s2n-tls Log]")
    test_status_map: dict[str, str] = {}

    lines = log.split("\n")
    current_test: str | None = None

    # CTest: "    1/200 Test  #1: s2n_abc_test .....................   Passed    0.01 sec" or "....***Failed"
    ctest_pattern = re.compile(
        r"^\s*\d+/\d+\s+Test\s+#\d+:\s+(.+?)\s+\.+\s*(Passed|\*+Failed|Failed|Not Run)\s+"
    )
    # s2n "Running <path> ... "
    running_pattern = re.compile(r"^Running\s+(.+?)\s+\.\.\.\s*$")
    # ANSI or plain
    passed_line_pattern = re.compile(r"^(?:\033\[32;1mPASSED\033\[0m|PASSED)\s+\d+\s+tests\s*$")
    skipped_line_pattern = re.compile(r"^(?:\033\[33;1mSKIPPED\033\[0m ALL tests|SKIPPED ALL tests)\s*$")
    failed_line_pattern = re.compile(r"^FAILED test \d+")
    # Rust test output: "test <name> ... ok" or "test <name> ... FAILED"
    rust_test_pattern = re.compile(r"^test\s+(\S+)\s+\.\.\.\s+(ok|FAILED)\s*$")

    for line in lines:
        ctest_match = ctest_pattern.match(line)
        if ctest_match:
            name, status = ctest_match.groups()
            name = name.strip()
            if status == "Passed":
                test_status_map[name] = TestStatus.PASSED.value
            elif "Failed" in status:
                test_status_map[name] = TestStatus.FAILED.value
            elif status == "Not Run":
                test_status_map[name] = TestStatus.SKIPPED.value
            current_test = None
            continue

        stripped = line.strip()

        rust_match = rust_test_pattern.match(stripped)
        if rust_match:
            name, result = rust_match.groups()
            if result == "ok":
                test_status_map[name] = TestStatus.PASSED.value
            else:  # FAILED
                test_status_map[name] = TestStatus.FAILED.value
            continue

        running_match = running_pattern.match(stripped)
        if running_match:
            current_test = running_match.group(1).strip()
            if "/" in current_test:
                current_test = current_test.rsplit("/", 1)[-1]
            elif "\\" in current_test:
                current_test = current_test.rsplit("\\", 1)[-1]
            continue

        if current_test is not None:
            if passed_line_pattern.match(stripped):
                test_status_map[current_test] = TestStatus.PASSED.value
                current_test = None
            elif skipped_line_pattern.match(stripped):
                test_status_map[current_test] = TestStatus.SKIPPED.value
                current_test = None
            elif failed_line_pattern.match(stripped):
                test_status_map[current_test] = TestStatus.FAILED.value
                current_test = None

    return test_status_map


MAP_REPO_TO_PARSER_C = {
    "redis/redis": parse_log_redis,
    "jqlang/jq": parse_log_jq,
    "nlohmann/json": parse_log_doctest,
    "micropython/micropython": parse_log_micropython_test,
    "valkey-io/valkey": parse_log_redis,
    "fmtlib/fmt": parse_log_googletest,
    "openssl/openssl": parse_log_openssl,
    "radareorg/radare2": parse_log_r2r,
    "espressif/esp-idf": parse_log_esp_idf,
    "CESNET/libyang": parse_log_libyang,
    "davidesantangelo/krep": parse_log_krep,
    "adafruit/tinyuf2": parse_not_inex,
    "driftregion/iso14229": parse_log_iso14229,
    "betaflight/betaflight": parse_log_betaflight,
    "aviggiano/redis-roaring": parse_not_inex,
    "aws/s2n-tls": parse_log_s2n_tls,
    "arkq/bluez-alsa": parse_log_bluezalsa
}