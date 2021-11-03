#!/usr/bin/env bash

. /etc/service/date.sh --source-only

[[ ${DEBUG:-0} -eq 1 ]] && set -x
#execute up/down scripts if present
[[ -f /etc/openvpn/up.sh ]] && /etc/openvpn/up.sh

#start services.
for s in unbound dante tinyproxy; do
  log "INFO: OPENVPN: up: starting ${s}"
  sv start ${s}
done
