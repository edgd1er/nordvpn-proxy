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
if [[ ! -d ${CONFIGDIR} ]]; then
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

getExtIp() {
    ip -j -4 addr show tun0 | jq -r .[].addr_info[0].local
}

getEthIp() {
    ip -j -4 a show eth0 | jq -r .[].addr_info[0].local
}

getEthCidr() {
    ip -j -4 a show eth0 | jq -r '.[].addr_info[0]|"\( .broadcast)/\(.prefixlen)"' | sed 's/255/0/g'
}

write_status_file() {
    STATUS=$(echo ${1} | grep -oE "(NOT|)CONNECTED")
    if [[ ${WRITE_OVPN_STATUS} -ne 0 ]]; then
        echo ${STATUS} >${OVPN_STATUS_FILE}
        log "HEALTHCHECK: OVPN status (${STATUS}) written to ${OVPN_STATUS_FILE}"
    fi
}

check_dns_service() {
    unbound_resolv=$(grep -c "127.0.0.1" /etc/resolv.conf)
    ubound_status=$(sv status unbound | grep -c "run")
    still_using_unbound=$(expr ${unbound_resolv} + ${ubound_status})
    if [ 2 -ne ${still_using_unbound:-0} ]; then
        log "RESOLVCHECK: ERROR: Not using unbound.restarting it."
        sv restart unbound
    fi
}

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

defaultRoute() {
    #sauvegarde du fichier
    [[ -f ${CONFIGDIR}/etc_resolv.conf ]] && cp -vf /etc/resolv.conf ${CONFIGDIR}/etc_resolv.conf
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
    grep -v ^# ${CONFIGDIR}/tinyproxy.conf | sed "/^$/d"
}

getDanteConf() {
    grep -v ^# ${CONFIGDIR}/dante.conf | sed "/^$/d"
}

getTinyListen() {
    grep -E "Listen [0-9]+" ${CONFIGDIR}/tinyproxy.conf | cut -d' ' -f2
}

changeTinyListenAddress() {
    listen_ip4=$(getTinyListen)
    current_ip4=$(getEthIp)
    if [[ ! -z ${listen_ip4} ]] && [[ ! -z ${current_ip4} ]] && [[ ${listen_ip4} != ${current_ip4} ]]; then
        #dante ecoute sur le nom de l'interface eth0
        echo "Tinyproxy: changing listening address from ${listen_ip4} to ${current_ip4}"
        sv stop tinyproxy
        sed -i "s/${listen_ip4}/${current_ip4}/" ${CONFIGDIR}/tinyproxy.conf
        sv start tinyproxy
    fi
}

## tests functions
testhproxy() {
    TCF=/run/secrets/TINY_CREDS
    if [[ -f ${TCF} ]]; then
        TCREDS="$(head -1 ${TCF}):$(tail -1 ${TCF})@"
    else
        TCREDS=""
    fi
    IP=$(curl -4 -sm 10 -x http://${TCREDS}${HOSTNAME}:${TINY_PORT:-8888} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]]; then
        echo "IP is ${IP}"
    else
        echo "curl through http proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
}

testsproxy() {
    TCF=/run/secrets/TINY_CREDS
    if [[ -f ${TCF} ]]; then
        TCREDS="$(head -1 ${TCF}):$(tail -1 ${TCF})@"
    else
        TCREDS=""
    fi
    IP=$(curl -m5 -sqx socks5://${TCREDS}${HOSTNAME}:${DANTE_PORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]]; then
        echo "IP is ${IP}"
    else
        echo "curl through socks proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
}

checkproxies() {
    #disable output if -s arg is given
    if [[ $* =~ -s ]]; then
        log() { true; }
    fi
    FAILED=0
    #check tinyproxy
    IP=$(
        TCF=/run/secrets/TINY_CREDS
        [[ -f ${TCF} ]] && TCREDS="$(head -1 ${TCF}):$(tail -1 ${TCF})@" || TCREDS=""
        curl -4 -sm 10 -x http://${TCREDS}${HOSTNAME}:${TINY_PORT:-8888} "https://ifconfig.me/ip"
    )
    if [[ $? -eq 0 ]]; then
        log "INFO: IP is ${IP} for http proxy"
    else
        log "WARNING: curl through http proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
    #check socks
    IP=$(
        TCF=/run/secrets/TINY_CREDS
        [[ -f ${TCF} ]] && TCREDS="$(head -1 ${TCF}):$(tail -1 ${TCF})@" || TCREDS=""
        curl -4 -sm10 -x socks5h://${TCREDS}${HOSTNAME}:1080 "https://ifconfig.me/ip"
    )
    if [[ $? -eq 0 ]]; then
        log "INFO: IP is ${IP} for socks proxy"
    else
        log "WARNING: curl through socks proxy to https://ifconfig.me/ip failed"
        ((FAILED += 1))
    fi
    return ${FAILED}
}

getStatusFromNordvpn() {
    nvpn_status="$(curl -s 'https://nordvpn.com/wp-admin/admin-ajax.php?action=get_user_info_data')"
    status=$(echo $nvpn_status | jq -r .status)
    myip=$(echo $nvpn_status | jq -r .host.ip_address)
    if [[ "false" == ${status} ]]; then
        log "WARNING: not protected, status is ${status}, ip ${myip}"
        return 1
    fi
    return 0
}

getStatusFromNordvpn2() {
    nvpn_status="$(curl -s 'https://api.nordvpn.com/v1/helpers/ips/insights')"
    status=$(echo $nvpn_status | jq -r .protected)
    myip=$(echo $nvpn_status | jq -r .ip)
    country=$(echo $nvpn_status | jq -r .country)
    if [[ "false" == ${status} ]]; then
        log "WARNING: not protected, status: ${status}, ip: ${myip}, country: ${country}"
        return 1
    fi
    return 0
}
