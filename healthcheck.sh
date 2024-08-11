#!/bin/bash

IP_FILE="/ip.txt"
CONTAINER_IP=$(curl --max-time 1 -s --socks5 localhost:1080 http://checkip.amazonaws.com)
if echo "$CONTAINER_IP" | grep -q '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$'; then
    echo $CONTAINER_IP > $IP_FILE
    exit 0
else
    [ -f $IP_FILE ] && rm $IP_FILE
    exit 1
fi