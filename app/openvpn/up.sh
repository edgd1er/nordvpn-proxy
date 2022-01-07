#!/usr/bin/env bash

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#execute up/down scripts if present
[[ -f /etc/openvpn/up.sh ]] && /etc/openvpn/up.sh

#start services.
for s in unbound dante tinyproxy; do
  log "INFO: OPENVPN: up: starting ${s}"
  sv start ${s}
done
