#!/bin/bash

set -e

/usr/bin/start_vpn.sh > /dev/stdout 2> /dev/stdout &

while true; do
  if [ "$(ip tuntap)" = "" ]; then
    sleep 1
  else
    break
  fi
done

# Yeah, this is lazy, but sometimes the VPN interface doesn't have an IP yet.
# Give it a moment.
sleep 1

/rusty_socks /rusty.toml