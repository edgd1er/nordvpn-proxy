#!/usr/bin/env bash

. /etc/service/date.sh --source-only
[[ ${DEBUG:-0} -eq 1 ]] && set -x

#execute up/down scripts if present
[[ -f /etc/openvpn/down.sh ]] && bash -x /etc/openvpn/down.sh

for s in unbound dante tinyproxy
  do
    log "INFO: OPENVPN: down: stopping ${s}"
    sv stop ${s}
done