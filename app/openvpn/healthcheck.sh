#!/usr/bin/env bash
set -e -u -o pipefail

EXIT_WHEN_IP_NOTEXPECTED=${EXIT_WHEN_IP_NOTEXPECTED:=0}
WRITE_OVPN_STATUS=${WRITE_OVPN_STATUS:=0}

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST:-google.com}



#Functions
check_dnssec() {
  msg=""
  dns_servfail_expected=$(dig sigfail.verteiltesysteme.net @127.0.0.1 -p 53 | grep -c SERVFAIL) || true
  dns_ip_expected=$(dig +short sigok.verteiltesysteme.net @127.0.0.1 -p 53)

  if [[ 0 -eq ${dns_servfail_expected} ]]; then
    msg="SERVAIL expected not found."
  fi
  if [[ -z ${dns_ip_expected} ]]; then
    [[ 1 -le ${#msg} ]] && msg="${msg}, " || true
    msg="${msg} ip expected, none"
  fi
  [[ -n ${msg} ]] && log "WARNING: HEALTHCHECK: DNSSEC: ${msg}" || true
}

check_openvpn() {
  OPENVPN=$(pgrep openvpn | wc -l)

  if [[ ${OPENVPN} -ne 1 ]]; then
    log "ERROR: HEALTHCHECK: Openvpn process not running"
    write_status_file NOTCONNECTED
    exit 1
  fi

  ovpnConf=$(find /config/ -type f -iname *.ovpn ! -iname default*)
  nordvpn_hostname=$(basename ${ovpnConf} | sed "s/.ovpn//")
  expectedIp=$(awk '/remote /{print $2}' ${ovpnConf})
  [[ ${expectedIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_expected=${BASH_REMATCH[*]}
  foundIp=$(curl -s https://myexternalip.com/raw)
  [[ ${foundIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_found=${BASH_REMATCH[*]}

  if [[ -n ${foundIp} ]]; then
    # at least be in the same network
    if [[ "${net_found}" != "${net_expected}" ]]; then
      log "WARNING: HEALTHCHECK: ${nordvpn_hostname} : effective network ${net_found} (real IP:${foundIp}) is not the expected one ${net_expected} (expected ip: ${expectedIp})."
      [[ 1 -eq ${EXIT_WHEN_IP_NOTEXPECTED:-1} ]] && log "ERROR: HEALTHCHECK: exiting as requested per EXIT_WHEN_IP_NOTEXPECTED(=${EXIT_WHEN_IP_NOTEXPECTED})" && exit 1
    fi
  fi

  LOAD=$(echo "load-stats" | socat -s - ${SOCKET} | tail -1)
  STATE=$(echo "state" | socat -s - ${SOCKET} | sed -n '2p')
  write_status_file ${STATE}
  if [[ ! ${STATE} =~ CONNECTED ]]; then
    log "INFO: HEALTHCHECK: Openvpn load: ${LOAD}"
    log "ERROR: HEALTHCHECK: Openvpn not connected"
    exit 1
  fi
}


#Main
if [[ -z "$HOST" ]]; then
  log "INFO: HEALTHCHECK:, Host  not set! Set env 'HEALTH_CHECK_HOST'. For now, using default google.com"
  HOST="google.com"
fi

ping -c 2 -w 5 $HOST 1>/dev/null 2>&1 # Get at least 2 responses and timeout after 5 seconds
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
  log "ERROR: HEALTHCHECK:, network is down"
  exit 1
fi

#Service check
check_dnssec

check_openvpn

exit 0