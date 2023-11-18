#!/usr/bin/env bash
set -e -u -o pipefail

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

ovpnConf=$(find /etc/service/openvpn/nordvpn/ -type f -iname *.ovpn ! -iname default*)

nordvpn_hostname=$(basename ${ovpnConf} | sed "s/.ovpn//")
server_load=$(curl -s $SERVER_STATS_URL$nordvpn_hostname | jq -r '.[]')

#Check serverload value is not empty
if [ -z "$server_load" ];then
    log "WARNING" "STATUS-SERVER: ERROR: No response from NordVPN API to get server load. This check to restart OpenVPN will be ignored."
    sv restart openvpn
fi

#Check serverload with expected load
if [ $server_load -gt $LOAD ]; then
    log "WARNING" "STATUS-SERVER: Load on $nordvpn_hostname is to high! Current load is $server_load and expected is $LOAD"
    log "WARNING" "STATUS-SERVER: OpenVPN will be restarted!"
    sv stop openvpn
    sv stop unbound
else
    log "INFO" "STATUS-SERVER: The current load of $server_load on $nordvpn_hostname is okay"
fi;