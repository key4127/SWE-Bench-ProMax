#!/bin/bash
# Check task images: /testbed HEAD must be the instance's base commit, and no commit outside HEAD's
# history may be reachable or present in the object store.
#   bash docker/check_images.sh <repo>     (images <repo>:<instance_id>)
REPO=${1:?usage: check_images.sh <repo>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
python3 -c "import json;[print(r['instance_id'], r['base_commit']) for r in json.load(open('$ROOT/data/swe-bench-promax.json'))]" |
while read -r iid base; do
  out=$(docker run --rm --network none --entrypoint "" "$REPO:$iid" bash -c 'cd /testbed &&
    echo "$(git rev-parse HEAD) $(git rev-list --all --not HEAD | wc -l) $(git cat-file --batch-all-objects --batch-check="%(objecttype)" | grep -c "^commit") $(git rev-list --all HEAD | wc -l)"')
  read -r head future objs reach <<<"$out"
  [ "$head" = "$base" ] && [ "$future" = 0 ] && [ "$objs" = "$reach" ] && s=OK || s=FAIL
  echo "$iid $s head=${head:0:10} future=$future commit_objects=$objs reachable=$reach"
done
