#!/usr/bin/env bash

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#execute up/down scripts if present
[[ -f /etc/openvpn/down.sh ]] && bash -x /etc/openvpn/down.sh

for s in dante tinyproxy unbound
  do
    log "INFO: OPENVPN: down: stopping ${s}"
    sv stop ${s}
done