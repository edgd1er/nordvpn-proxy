#!/usr/bin/env bash

#Variables
. /etc/service/date.sh --source-only
[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#execute up/down scripts if present
[[ -f /etc/openvpn/down.sh ]] && bash -x /etc/openvpn/down.sh

for s in unbound dante tinyproxy
  do
    log "INFO: OPENVPN: down: stopping ${s}"
    sv stop ${s}
done