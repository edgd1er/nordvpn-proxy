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

ping -c 2 -w 5 $HOST # Get at least 2 responses and timeout after 5 seconds
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
foundIp=$(curl -s https://myexternalip.com/raw)

if [[ -n ${foundIp} ]]; then
  # at least be in the same network
  if [[ "${foundIp::-3}" != "${expectedIp::-3}" ]]; then
    echo "$(adddate) HEALTHCHECK: ERROR: effective ip (${foundIp}) if not the expected one (${expectedIp})."
    exit 1
  fi
fi

echo "$(adddate) HEALTHCHECK: INFO: Openvpn processes are running"
exit 0
