#!/bin/bash

add_route="$(ip route | grep 'default')" ; add_route="$(sed "s|default|$HOST_NETWORK|g" <<< $add_route)"
ip route add $add_route
echo "[info] Added route $add_route"

echo '[info] Block everything (unless unblock explicitly)'
iptables -P INPUT  DROP
#iptables -P FORWARD DROP
iptables -P OUTPUT DROP

echo '[info] Unblock loopback'
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

echo '[info] Unblock tunnel'
iptables -A INPUT  -i tun0 -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT

echo "[info] Unblock $ETH0_NET"
iptables -A INPUT  -s $ETH0_NET -d $ETH0_NET -j ACCEPT
iptables -A OUTPUT -s $ETH0_NET -d $ETH0_NET -j ACCEPT

echo "[info] Unblock $HOST_NETWORK"
iptables -A INPUT  -s ${HOST_NETWORK} -j ACCEPT
iptables -A OUTPUT -d ${HOST_NETWORK} -j ACCEPT

echo "[info] Unblock traffic between $ETH0_NET and host"
iptables -A INPUT  -s ${HOST_NETWORK} -d $ETH0_NET -i eth0 -p tcp -j ACCEPT
iptables -A OUTPUT -s $ETH0_NET -d ${HOST_NETWORK} -o eth0 -p tcp -j ACCEPT

echo '[info] Unblock icpm outgoing (pings)'
iptables -A INPUT  -p icmp -m state --state ESTABLISHED,RELATED     -j ACCEPT
iptables -A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

echo "[info] Unblock OpenVPN outgoing on $OPENVPN_PROTO $OPENVPN_PORT"
iptables -A INPUT  -p $OPENVPN_PROTO --sport $OPENVPN_PORT -j ACCEPT
iptables -A OUTPUT -p $OPENVPN_PROTO --dport $OPENVPN_PORT -j ACCEPT

echo "[info] Unblock DNS inbound from eth0 on $DNS_PORT"
iptables -A INPUT  -i eth0 -p tcp --dport $DNS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $DNS_PORT -m state --state ESTABLISHED     -j ACCEPT
iptables -A INPUT  -i eth0 -p udp --dport $DNS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p udp --sport $DNS_PORT -m state --state ESTABLISHED     -j ACCEPT

echo "[info] Unblock dante inbound from eth0 on $DANTE_PORT"
iptables -A INPUT  -i eth0 -p tcp --dport $DANTE_PORT -m state --state NEW,ESTABLISHED     -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $DANTE_PORT -m state --state ESTABLISHED         -j ACCEPT
iptables -A OUTPUT -o eth0                            -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "[info] Unblock tinyproxy inbound from eth0 on $TINYPROXY_PORT"
iptables -A INPUT  -i eth0 -p tcp --dport $TINYPROXY_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $TINYPROXY_PORT -m state --state ESTABLISHED     -j ACCEPT

echo "[info] Unblock torsocks inbound from eth0 on $TORSOCKS_PORT"
iptables -A INPUT  -i eth0 -p tcp --dport $TORSOCKS_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $TORSOCKS_PORT -m state --state ESTABLISHED     -j ACCEPT

echo "[info] Unblock privoxy inbound from eth0 on $PRIVOXY_PORT"
iptables -A INPUT  -i eth0 -p tcp --dport $PRIVOXY_PORT -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport $PRIVOXY_PORT -m state --state ESTABLISHED     -j ACCEPT
