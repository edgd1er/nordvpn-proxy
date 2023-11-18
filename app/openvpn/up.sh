#!/usr/bin/env bash

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#execute up/down scripts if present
[[ -x /etc/openvpn/up.sh ]] && /etc/openvpn/up.sh

#when vpn is up, delete default route going through eth0
route del default eth0

#start services.
for s in unbound dante tinyproxy; do
  log "INFO: OPENVPN: up: starting ${s}"
  sv start ${s}
done

echo "Initialization Sequence Completed"
