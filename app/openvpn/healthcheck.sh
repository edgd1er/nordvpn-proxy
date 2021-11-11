#!/usr/bin/env bash
set -e -u -o pipefail

SOCKET="unix-connect:/run/openvpn.sock"
EXIT_WHEN_IP_NOTEXPECTED=${EXIT_WHEN_IP_NOTEXPECTED:=0}

[[ ${DEBUG:-0} -eq 1 ]] && set -x
#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST:-google.com}

. /etc/service/date.sh --source-only

#Functions
check_dnssec() {
  msg=""
  dns_servfail_expected=$(dig sigfail.verteiltesysteme.net @127.0.0.1 -p 53 | grep -c SERVFAIL) || true
  dns_ip_expected=$(dig +short sigok.verteiltesysteme.net @127.0.0.1 -p 53)

  if [[ 0 -eq ${dns_servfail_expected} ]]; then
    msg="SERVAIL expected not found."
  fi
  if [[ -z ${dns_ip_expected} ]]; then
    [[ 0 -le ${#msg} ]] && msg="${msg}, "
    msg="${msg}ip expected, none"
  fi
  [[ -n ${msg} ]] && log "HEALTHCHECK: WARNING: DNSSEC: ${msg}"
}

check_openvpn() {
  OPENVPN=$(pgrep openvpn | wc -l)

  if [[ ${OPENVPN} -ne 1 ]]; then
    log "HEALTHCHECK: ERROR: Openvpn process not running"
    exit 1
  fi

  ovpnConf=$(find /etc/service/openvpn/nordvpn/ -type f -iname *.ovpn ! -iname default*)
  nordvpn_hostname=$(basename ${ovpnConf} | sed "s/.ovpn//")
  expectedIp=$(awk '/remote /{print $2}' ${ovpnConf})
  [[ ${expectedIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_expected=${BASH_REMATCH[*]}
  foundIp=$(curl -s https://myexternalip.com/raw)
  [[ ${foundIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_found=${BASH_REMATCH[*]}

  if [[ -n ${foundIp} ]]; then
    # at least be in the same network
    if [[ "${net_found}" != "${net_expected}" ]]; then
      log "HEALTHCHECK: WARNING: ${nordvpn_hostname} : effective network ${net_found} (real IP:${foundIp}) is not the expected one ${net_expected} (expected ip: ${expectedIp})."
      [[ 1 -eq ${EXIT_WHEN_IP_NOTEXPECTED:-1} ]] && log "HEALTHCHECK: ERROR: exiting as requested per EXIT_WHEN_IP_NOTEXPECTED(=${EXIT_WHEN_IP_NOTEXPECTED})" && exit 1
    fi
  fi

  LOAD=$(echo "load-stats" | socat -s - ${SOCKET} | tail -1)
  STATE=$(echo "state" | socat -s - ${SOCKET} | sed -n '2p')

  if [[ ! ${STATE} =~ CONNECTED ]]; then
    log "HEALTHCHECK: INFO: Openvpn load: ${LOAD}"
    log "HEALTHCHECK: ERROR: Openvpn not connected"
    exit 1
  fi
}

#Main
if [[ -z "$HOST" ]]; then
  log "HEALTHCHECK: INFO, Host  not set! Set env 'HEALTH_CHECK_HOST'. For now, using default google.com"
  HOST="google.com"
fi

ping -c 2 -w 5 $HOST 1>/dev/null 2>&1 # Get at least 2 responses and timeout after 5 seconds
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
  log "HEALTHCHECK: ERROR, network is down"
  exit 1
fi

#Service check
check_dnssec

check_openvpn

exit 0
