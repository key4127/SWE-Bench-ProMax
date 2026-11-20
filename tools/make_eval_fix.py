"""Make build failures fatal in eval scripts.

Some eval scripts run a build step and then a prebuilt test binary, without checking the
build's exit status. If the build fails, the script runs the stale binary from the image.
For deskflow__deskflow-c_5fa70d0 and bloomberg__blazingmq-827 that stale binary passes with
no patch at all. This appends a guard to each unchecked build line so a failed build ends
the script with OMNIGRIL_EXIT_CODE=1.
"""
import json, re, sys
src, dst = sys.argv[1], sys.argv[2]
e = json.load(open(src))
G = re.compile(r'^\s*(cmake --build\b.*|ninja -C build( install)?\s*$|ninja -v\s*$|make -j\S*( \d+)?\s*$|\./gradlew .*compileTestJava.*)$')
GUARD = ' || { echo "ERROR: build failed"; echo "OMNIGRIL_EXIT_CODE=1"; exit 1; }'
# Not guarded: the full build fails on an unrelated target even with the reference patch
# (LMMS: plugins/OpulenZ, -Werror=unused-variable), while the test target still builds and the
# empty patch already fails the tests. A guard here would fail the reference patch.
SKIP = {"LMMS__lmms-7454"}
changed = {}
for iid, v in e.items():
    if iid in SKIP:
        continue
    L = v['eval_script'].split('\n')
    for i, l in enumerate(L):
        if not G.match(l) or '||' in l or '&&' in l or '|' in l:
            continue
        nxt = next((x for x in L[i+1:] if x.strip()), '')
        if re.search(r'\w+_rc=\$', nxt):   # script already checks this build's status
            continue
        L[i] = l.rstrip() + GUARD
        changed.setdefault(iid, []).append(l.strip())
    v['eval_script'] = '\n'.join(L)
json.dump(e, open(dst, 'w'), indent=None, ensure_ascii=False)
json.dump(changed, open('changed.json', 'w'), indent=1)
print(len(changed), 'scripts,', sum(map(len, changed.values())), 'lines')
