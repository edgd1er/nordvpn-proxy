#!/usr/bin/env bash

. /app/date.sh --source-only
[[ ${DEBUG:-0} -eq 1 ]] && set -x

unbound_resolv=$(grep -c "127.0.0.1" /etc/resolv.conf)
ubound_status=$(sv status unbound | grep -c "run")
still_using_unbound=$(expr ${unbound_resolv} + ${ubound_status} )
if [ 2 -ne ${still_using_unbound:-0} ]; then
      echo "$(adddate) ERROR: Not using unbound.restarting it."
      sv restart unbound
fi