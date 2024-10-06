#!/usr/bin/env bash
set -e -u -o pipefail

#Variables
EXIT_WHEN_IP_NOTEXPECTED=${EXIT_WHEN_IP_NOTEXPECTED:=0}
WRITE_OVPN_STATUS=${WRITE_OVPN_STATUS:=0}
IP_FILE="/tmp/ip.txt"
ARGS="${*}"

#Functions
[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

if [[ ! ${ARGS} =~ -v ]]; then
    log(){ true; }
fi
#Network check
# Ping uses both exit codes 1 and 2. Exit code 2 cannot be used for docker health checks,
# therefore we use this script to catch error code 2
HOST=${HEALTH_CHECK_HOST:-google.com}

#Functions
checkWriteIp() {
    myip=${1:-}
    if [[ -z ${myip} ]]; then
        log "Warning: No ip to write with ip"
    elif [[ ! -f ${IP_FILE} ]]; then
        echo "$myip" >${IP_FILE}
        log "Warning: no ip file, writing it = ${myip}"
    elif [[ ${myip} != $(<${IP_FILE}) ]]; then
        log "Warning: no ip file or ip changed: ${myip} / $(<${IP_FILE})"
        echo "$myip" >${IP_FILE}
    fi
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

#check openvpn status
check_openvpn

#check if eth0 ip has changed, change tinyproxy listen address if needed.
changeTinyListenAddress

#check ip
checkproxies ${1:-"-s"}

if [[ $? -gt 0 ]]; then
    log "ERROR: proxies check failed"
    exit 1
fi

if [[ 1 -eq ${EXIT_WHEN_IP_NOTASEXPECTED:-0} ]] && ! getStatusFromNordvpn2 ; then
    exit 1
fi

exit 0
