#!/bin/bash

set -e

/usr/bin/nordVpn.sh > /dev/stdout 2> /dev/stdout &

while true; do
  if [ "$(ip tuntap)" = "" ]; then
    sleep 1
  else
    break
  fi
done

sockd