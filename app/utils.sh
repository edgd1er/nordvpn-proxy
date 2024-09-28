#!/usr/bin/env bash

DEBUG=${DEBUG:-0}
if [[ ${DEBUG,,} =~ (true|1) ]]; then
    DEBUG=1
    set -x
fi

SOCKET="unix-connect:/run/openvpn.sock"
OVPN_STATUS_FILE=/var/tmp/ovpn_status

MAIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"/.."
TIME_FORMAT=$(date "+%Y-%m-%d %H:%M:%S")
nordvpn_api="https://api.nordvpn.com"
nordvpn_dl=downloads.nordcdn.com
nordvpn_cdn="https://${nordvpn_dl}/configs/files"
nordvpn_doc="https://haugene.github.io/docker-transmission-openvpn/provider-specific/#nordvpn"
possible_protocol="tcp, udp"
NORDVPN_TESTS=${NORDVPN_TESTS:-''}
CONFIGDIR=/config

#standalone tests for api
if [[ ! -d /config ]]; then
    export CONFIGDIR=/tmp/config
    mkdir -p ${CONFIGDIR}
fi
#easier reuse of a multi project script
export VPN_PROVIDER_HOME=${CONFIGDIR}

log() {
    level=$1
    shift +1
    msg=$@
    TIME_FORMAT=$(date "+%Y-%m-%d %H:%M:%S")
    printf "${TIME_FORMAT}: ${level^^}: %b\n" "$msg" >/dev/stderr
}

fatal_error() {
    printf "ERROR: %b\n" "$*" >&2
    sleep 30
    exit 1
}

write_status_file() {
    STATUS=$(echo ${1} | grep -oE "(NOT|)CONNECTED")
    if [[ ${WRITE_OVPN_STATUS} -ne 0 ]]; then
        echo ${STATUS} >${OVPN_STATUS_FILE}
        log "HEALTHCHECK: OVPN status (${STATUS}) written to ${OVPN_STATUS_FILE}"
    fi
}

defaultRoute() {
    #sauvegarde du fichier
    [[ -f /config/etc_resolv.conf ]] && cp -vf /etc/resolv.conf /config/etc_resolv.conf
    currentIp=$(ip -j a | jq -r '.[]|select(.ifname|contains("eth0"))| .addr_info[0].local')
    GW=${currentIp%%[0-9]}1
    while [ 0 -ne $(route -n | grep -c ^0.0.0.0) ]; do
        route del default
    done
    /sbin/ip route add default via "${GW}" dev eth0
}

getCurrentIp() {
    ip1=$(curl -sq "https://nordvpn.com/wp-admin/admin-ajax.php?action=get_user_info_data" | jq -r ".host.ip_address")
    if [[ ${ip1} =~ ^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$ ]]; then
        echo ${ip1}
    else
        ip2=$(curl --max-time 1 -s --socks5 localhost:1080 http://checkip.amazonaws.com)
        echo ${ip2}
    fi
}

getTinyConf() {
  grep -v ^# /config/tinyproxy.conf | sed "/^$/d"
}

getDanteConf() {
  grep -v ^# /config/dante.conf | sed "/^$/d"
}

getTinyListen() {
    grep -E  "Listen [0-9]+" /config/tinyproxy.conf | cut -d' ' -f2
}

changeTinyListenAddress() {
  listen_ip4=$(getTinyListen)
  current_ip4=$(getEthIp)
  if [[ ! -z ${listen_ip4} ]] && [[ ! -z ${current_ip4} ]] && [[ ${listen_ip4} != ${current_ip4} ]]; then
    #dante ecoute sur le nom de l'interface eth0
    echo "Tinyproxy: changing listening address from ${listen_ip4} to ${current_ip4}"
    sed -i "s/${listen_ip4}/${current_ip4}/" /etc/tinyproxy/tinyproxy.conf
    supervisorctl restart tinyproxy
  fi
}


checkproxies() {
    #disable output if -s arg is given
    if [[ $* =~ -s ]]; then
        log(){ true; }
    fi
    FAILED=0
    #check tinyproxy
    IP=$(curl -sqx http://$(getTinyListen):${TINYPORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]]; then
        log "INFO: IP is ${IP}"
    else
        log "WARNING: curl through http proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
    #check socks
    IP=$(curl -sqx socks5://localhost:${DANTE_PORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]]; then
        log "INFO: IP is ${IP}"
    else
        log "WARNING: curl through socks proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
    return ${FAILED}
}
