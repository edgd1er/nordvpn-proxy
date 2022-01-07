#!/bin/bash

DEBUG=${DEBUG:-"0"}
[[ ${DEBUG} != "0" ]] && set -x || true

SOCKET="unix-connect:/run/openvpn.sock"
OVPN_STATUS_FILE=/var/tmp/ovpn_status

log() {
  printf "%b\n" "$*" >/dev/stderr
}

fatal_error() {
  printf "\e[41mERROR:\033[0m %b\n" "$*" >&2
  exit 1
}

write_status_file() {
  STATUS=$(echo ${1} | grep -oE "(NOT|)CONNECTED")
  if [[ ${WRITE_OVPN_STATUS} -ne 0 ]]; then
    echo ${STATUS} >${OVPN_STATUS_FILE}
    log "HEALTHCHECK: OVPN status (${STATUS}) written to ${OVPN_STATUS_FILE}"
  fi
}
