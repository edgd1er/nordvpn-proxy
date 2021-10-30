#!/usr/bin/env bash

. /app/date.sh --source-only

#Wait 10 seconds for openvpn to finish resolv.conf modification
sleep 10
[[ ${DEBUG:-0} -eq 1 ]] && set -x
for s in unbound dante
  do
    echo "$(adddate) INFO: OPENVPN: up: starting ${s}"
    sv start ${s}
done
