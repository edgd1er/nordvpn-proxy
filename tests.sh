#!/usr/bin/env bash


set -e -u -o pipefail
#var
PROXY_HOST="localhost"
HTTP_PORT=88$(grep -oP '(?<=\- "88)[^:]+' docker-compose.yml)
SOCK_PORT=10$(grep -oP '(?<=\- "10)[^:]+' docker-compose.yml)
FAILED=0
INTERVAL=4

#Functions
buildAndWait() {
  echo "Stopping and removing running containers"
  docker compose down -v
  echo "Building and starting image"
  docker compose -f docker-compose.yml up -d --build
  echo "Waiting for the container to be up.(every ${INTERVAL} sec)"
  logs=""
  n=0
  while [ 0 -eq $(echo $logs | grep -c "Initialization Sequence Completed") ]; do
    logs="$(docker compose logs)"
    sleep ${INTERVAL}
    ((n+=1))
    echo "loop: ${n}"
    [[ ${n} -eq 15 ]] && break || true
  done
  docker compose logs
}

#Main
[[ -z $(which nc) ]] && echo "No nc found" && exit || true

if [[ ${HTTP_PORT} -eq 88 ]] || [[ ${SOCK_PORT} -eq 10 ]]; then
    echo no docker-compose.yml found
    exit
fi

if [[ "-t" != ${1:-''} ]]; then
    [[ "localhost" == ${PROXY_HOST} ]] && buildAndWait
fi
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

IP=$(curl -sqx http://${PROXY_HOST}:${HTTP_PORT} "https://ifconfig.me/ip")
if [[ $? -eq 0 ]]; then
  echo "IP is ${IP}"
else
  echo "curl through http proxy to https://ifconfig.me/ip failed"
  ((FAILED += 1))
fi

IP=$(curl -sqx socks5://${PROXY_HOST}:${SOCK_PORT} "https://ifconfig.me/ip")
if [[ $? -eq 0 ]]; then
  echo "IP is ${IP}"
else
  echo "curl through socks proxy to https://ifconfig.me/ip failed"
  ((FAILED += 1))
fi

if [[ "-t" != ${1:-''} ]]; then
    [[ "localhost" == ${PROXY_HOST} ]] && docker compose down
fi

echo "# failed tests: ${FAILED}"
exit ${FAILED}