#!/usr/bin/env bash

set -uo pipefail
#var
HTTP_PORT=88$(grep -oP '(?<=\- "88)[^:]+' compose.yml)
SOCK_PORT=10$(grep -oP '(?<=\- "10)[^:]+' compose.yml)
PROXY_HOST="localhost"
FAILED=0
INTERVAL=4
CONTAINER=$(grep -A1 services compose.yml | grep -oP "(?<=  )[a-zA-Z]+")
CURLOPTS="-4s"

#Functions
buildAndWait() {
    echo "Stopping and removing running containers"
    docker compose down -v
    echo "Building and starting image"
    docker compose -f compose.yml up -d --build
    echo "Waiting for the container to be up.(every ${INTERVAL} sec)"
    logs=""
    n=0
    while [ 0 -eq $(echo $logs | grep -c "Initialization Sequence Completed") ]; do
        logs="$(docker compose logs)"
        sleep ${INTERVAL}
        ((n += 1))
        echo "loop: ${n}"
        [[ ${n} -eq 15 ]] && break || true
    done
    docker compose logs
}

areProxiesPortOpened() {
    for PORT in ${HTTP_PORT} ${SOCK_PORT}; do
        msg="Test connection to port ${PORT}: "
        if [ 0 -eq $(echo "" | nc -v -q 2 ${PROXY_HOST} ${PORT} 2>&1 | grep -c "] succeeded") ]; then
            msg+=" Failed"
            ((FAILED += 1))
        else
            msg+=" OK"
        fi
        echo -e "$msg"
    done
}

testProxies() {
    FAILED=0
    if [[ -n $(which nc) ]]; then
        areProxiesPortOpened
    fi
    if [[ -f ./tiny_creds ]]; then
        usertiny=$(head -1 ./tiny_creds)
        passtiny=$(tail -1 ./tiny_creds)
        echo "Getting tinyCreds from file: ${usertiny}:${passtiny}"
        TCREDS="${usertiny}:${passtiny}@"
        DCREDS=${TCREDS}
    else
        usertiny=$(grep -oP "(?<=- TINYUSER=)[^ ]+" compose.yml)
        passtiny=$(grep -oP "(?<=- TINYPASS=)[^ ]+" compose.yml)
        echo "Getting tinyCreds from compose: ${usertiny}:${passtiny}"
        TCREDS="${usertiny}:${passtiny}@"
        DCREDS=${TCREDS}
    fi
    if [[ -z ${usertiny:-''} ]]; then
        echo "No tinyCreds"
        TCREDS=""
        DCREDS=""
    fi
    vpnIP=$(curl ${CURLOPTS} -m5 -x http://${TCREDS}${PROXY_HOST}:${HTTP_PORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]] && [[ ${myIp} != "${vpnIP}" ]] && [[ ${#vpnIP} -gt 0 ]]; then
        echo "http proxy: IP is ${vpnIP}, mine is ${myIp}"
    else
        echo "Error, curl through http proxy to https://ifconfig.me/ip failed"
        echo "or IP (${myIp}) == vpnIP (${vpnIP})"
        ((FAILED += 1))
    fi

    #check detected ips
    vpnIP=$(curl ${CURLOPTS} -m5 -x socks5://${DCREDS}${PROXY_HOST}:${SOCK_PORT} "https://ifconfig.me/ip")
    if [[ $? -eq 0 ]] && [[ ${myIp} != "${vpnIP}" ]] && [[ ${#vpnIP} -gt 0 ]]; then
        echo "socks proxy: IP is ${vpnIP}, mine is ${myIp}"
    else
        echo "Error, curl through socks proxy to https://ifconfig.me/ip failed"
        echo "or IP (${myIp}) == vpnIP (${vpnIP})"
        ((FAILED += 1))
    fi

    echo "# failed tests: ${FAILED}"
    return ${FAILED}
}

getInterfacesInfo() {
    docker compose exec ${CONTAINER} bash -c "ip -j a |jq  '.[]|select(.ifname|test(\"wg0|tun|nordlynx\"))|.ifname'"
    docker compose exec ${CONTAINER} echo -e "eth0: $(ip -j a | jq -r '.[] |select(.ifname=="eth0")| .addr_info[].local')\n wg0: $(ip -j a | jq -r '.[] |select(.ifname=="wg0")| .addr_info[].local')\nnordlynx: $(ip -j a | jq -r '.[] |select(.ifname=="nordlynx")| .addr_info[].local')"
    docker compose exec ${CONTAINER} bash -c 'echo "nordlynx conf: $(wg showconf nordlynx 2>/dev/null)"'
    docker compose exec ${CONTAINER} bash -c 'echo "wg conf: $(wg showconf wg0 2>/dev/null)"'
}

#Main
[[ ${1:-''} == "-t" ]] && BUILD=0 || BUILD=1
[[ -z $(which nc) ]] && echo "No nc found" && exit || true

myIp=$(curl ${CURLOPTS} -m5 -q https://ifconfig.me/ip)

if [[ "localhost" == "${PROXY_HOST}" ]] && [[ 1 -eq ${BUILD} ]]; then
  buildAndWait
  echo "***************************************************"
  echo "Testing container"
  echo "***************************************************"
  # check returned IP through http and socks proxy
  testProxies
  getInterfacesInfo
  [[ 1 -eq ${BUILD} ]] && docker compose down
else
  echo "***************************************************"
  echo "Testing container"
  echo "***************************************************"
  # check returned IP through http and socks proxy
  testProxies
  getInterfacesInfo
fi