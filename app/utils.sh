#!/bin/bash

DEBUG=${DEBUG:-0}
[[ ${DEBUG} -ne 0 ]] && set -x || true

SOCKET="unix-connect:/run/openvpn.sock"
OVPN_STATUS_FILE=/var/tmp/ovpn_status

MAIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"/.."
TIME_FORMAT=$(date "+%Y-%m-%d %H:%M:%S")
nordvpn_api="https://api.nordvpn.com"
nordvpn_dl=downloads.nordcdn.com
nordvpn_cdn="https://${nordvpn_dl}/configs/files"
nordvpn_doc="https://haugene.github.io/docker-transmission-openvpn/provider-specific/#nordvpn"
possible_protocol="tcp, udp"
VPN_PROVIDER_HOME=${VPN_PROVIDER_HOME:-${MAIN_DIR}/nordvpn}
NORDVPN_TESTS=${NORDVPN_TESTS:-''}


log() {
  level=$1
  shift +1
  msg=$@
  TIME_FORMAT=$(date "+%Y-%m-%d %H:%M:%S")
  printf "${TIME_FORMAT}: ${level^^}: %b\n" "$msg" >/dev/stderr
}

fatal_error() {
  printf "ERROR: %b\n" "$*" >&2
  exit 1
}

write_status_file() {
  STATUS=$(echo ${1} | grep -oE "(NOT|)CONNECTED")
  if [[ ${WRITE_OVPN_STATUS} -ne 0 ]]; then
    echo ${STATUS} >${OVPN_STATUS_FILE}
    log "HEALTHCHECK: OVPN status (${STATUS}) written to ${OVPN_STATUS_FILE}"
  fi
}