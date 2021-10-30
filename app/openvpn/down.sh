#!/usr/bin/env bash

. /app/date.sh --source-only

[[ ${DEBUG:-0} -eq 1 ]] && set -x
for s in unbound dante
  do
    echo "$(adddate) INFO: OPENVPN: down: stopping ${s}"
    sv stop ${s}
done