#!/bin/bash

DEBUG=${DEBUG:-"0"}
[[ ${DEBUG} != "0" ]] && set -x || true

SOCKET="unix-connect:/run/openvpn.sock"
OVPN_STATUS_FILE=/var/tmp/ovpn_status

write_status_file() {
  STATUS=$(echo ${1} | grep -oE "(NOT|)CONNECTED")
  [[ ${WRITE_OVPN_STATUS} -ne 0 ]] && echo ${STATUS} >${OVPN_STATUS_FILE} || true
  log "HEALTHCHECK: writing ${STATUS} to ${OVPN_STATUS_FILE}"
}