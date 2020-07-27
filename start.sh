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

/rusty_socks /rusty.toml