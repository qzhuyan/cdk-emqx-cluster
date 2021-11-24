#!/usr/bin/env bash
###############################################################################
# 1. Grab all dashboards
# 2. Fetch each dashboard with uid
# 3. snapshot each dashboard
# note, this does not work since the data points are missing.
###############################################################################
set -euo pipefail

die() {
    echo "$@" >&2
    exit 1
}

name=$1
if [ -z "$name" ]; then
  die "Usage: $0 <name> <from> <host:port>"
fi
from=${2:-"now-2h"}
target=${3:-"localhost:13000"}
login="admin:admin"

for d in $( curl -s  -X GET ${login}@${target}/api/search | jq -r '.[]|.uid')
do
    echo "snapshot dashboard $d"
    j=$(curl -s ${login}@${target}/api/dashboards/uid/$d | jq ".dashboard | del(.__requires) | .time.from=\"$from\"")
    dname=$(echo $j | jq -r '.title') #| sed 's/ /_/g')
    curl -s -X POST ${login}@${target}/api/snapshots \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        --data-binary @- << EOF
  {
      "dashboard": $j,
      "expires": 3600,
      "name": "$name-$dname"
  }
EOF
done
