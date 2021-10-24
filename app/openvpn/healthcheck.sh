#!/usr/bin/env bash
set -e -u -o pipefail

[[ ${DEBUG:-0} -eq 1 ]] && set -x
#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST:-google.com}

. /app/date.sh --source-only

if [[ -z "$HOST" ]]; then
  echo "$(adddate) HEALTHCHECK: INFO, Host  not set! Set env 'HEALTH_CHECK_HOST'. For now, using default google.com"
  HOST="google.com"
fi

ping -c 2 -w 5 $HOST 1>/dev/null 2>&1  # Get at least 2 responses and timeout after 5 seconds
STATUS=$?
if [[ ${STATUS} -ne 0 ]]; then
  echo "$(adddate) HEALTHCHECK: ERROR, network is down"
  exit 1
fi

echo "$(adddate) HEALTHCHECK: INFO, Network is up"

#Service check
#Expected output is 2 for both checks, 1 for process and 1 for grep
OPENVPN=$(pgrep openvpn | wc -l)

if [[ ${OPENVPN} -ne 1 ]]; then
  echo "$(adddate) HEALTHCHECK: ERROR: Openvpn process not running"
  exit 1
fi

ovpnConf=$(find /app/openvpn/nordvpn/ -type f -iname *.ovpn ! -iname default*)
nordvpn_hostname=$(basename ${ovpnConf} | sed "s/.ovpn//")
expectedIp=$(awk '/remote /{print $2}' ${ovpnConf})
[[ ${expectedIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_expected=${BASH_REMATCH[*]}
foundIp=$(curl -s https://myexternalip.com/raw)
[[ ${foundIp} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\. ]] && net_found=${BASH_REMATCH[*]}

if [[ -n ${foundIp} ]]; then
  # at least be in the same network
  if [[ "${net_found}" != "${net_expected}" ]]; then
    echo "$(adddate) HEALTHCHECK: WARNING: ${nordvpn_hostname} : effective network ${net_found} (real IP:${foundIp}) is not the expected one ${net_expected} (expected ip: ${expectedIp})."
    [[ 1 -eq ${EXIT_WHEN_IP_NOTEXPECTED:-1} ]] && echo "$(adddate) HEALTHCHECK: ERROR: exiting as requested per EXIT_WHEN_IP_NOTEXPECTED" && exit 1
  fi
fi

echo "$(adddate) HEALTHCHECK: INFO: Openvpn processes are running"
exit 0
