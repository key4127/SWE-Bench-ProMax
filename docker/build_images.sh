#!/bin/bash
# Rebuild the SWE-Bench-ProMax task images.
#
#   bash docker/build_images.sh <target-repo> [instance_id ...]
#
# For every instance (or the ones given), builds <target-repo>:<instance_id> from the original image
# named in data/swe-bench-promax.json:
#   1. the 11 instances under docker/warmup/ first get their offline test dependencies (Bazel, Gradle
#      jars) filled in, with network on, by running the eval script once with the empty patch;
#   2. then docker/strip_future_history.sh removes all upstream history newer than the base commit.
# Builds run one at a time with the classic builder: Docker 20.10's built-in BuildKit can resolve FROM to
# the wrong tag when several tags of one local repository are built concurrently.
set -euo pipefail
TARGET=${1:?usage: build_images.sh <target-repo> [instance_id ...]}; shift || true
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ids=("$@")
[ ${#ids[@]} -eq 0 ] && mapfile -t ids < <(python3 -c "import json;[print(r['instance_id']) for r in json.load(open('$ROOT/data/swe-bench-promax.json'))]")
for iid in "${ids[@]}"; do
  src=$(python3 -c "import json,sys;print({r['instance_id']:r['image_name'] for r in json.load(open('$ROOT/data/swe-bench-promax.json'))}[sys.argv[1]])" "$iid")
  base=$src
  if [ -d "$ROOT/docker/warmup/$iid" ]; then
    base="promax-warm:$(echo "$iid" | tr 'A-Z' 'a-z')"
    DOCKER_BUILDKIT=0 docker build -t "$base" "$ROOT/docker/warmup/$iid"
  fi
  DOCKER_BUILDKIT=0 docker build --network none --build-arg BASE="$base" -t "$TARGET:$iid" -f "$ROOT/docker/Dockerfile.clean" "$ROOT/docker"
done
