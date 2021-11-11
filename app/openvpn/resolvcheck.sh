#!/usr/bin/env bash

. /etc/service/date.sh --source-only
[[ ${DEBUG:-0} -eq 1 ]] && set -x

#Functions
check_dnssec(){
  msg=""
  dns_servfail_expected=$(dig sigfail.verteiltesysteme.net @127.0.0.1 -p 53 | grep -c SERVFAIL) || true
  dns_ip_expected=$(dig +short sigok.verteiltesysteme.net @127.0.0.1 -p 53)

  if [[ 0 -eq ${dns_servfail_expected} ]]; then
    msg="SERVAIL expected not found."
  fi
  if [[ -z ${dns_ip_expected} ]]; then
    [[ 0 -le ${#msg} ]]  && msg="${msg}, "
    msg="${msg}ip expected, none"
  fi
  [[ -n ${msg} ]] && log "RESOLVCHECK: WARNING: DNSSEC: ${msg}"
}

check_dns_service(){
  unbound_resolv=$(grep -c "127.0.0.1" /etc/resolv.conf)
  ubound_status=$(sv status unbound | grep -c "run")
  still_using_unbound=$(expr ${unbound_resolv} + ${ubound_status} )
  if [ 2 -ne ${still_using_unbound:-0} ]; then
        log "RESOLVCHECK: ERROR: Not using unbound.restarting it."
        sv restart unbound
  fi
}

#Main
check_dns_service

check_dnssec