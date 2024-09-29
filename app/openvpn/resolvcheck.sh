#!/usr/bin/env bash

#Variables

[[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true

#Main
check_dns_service

check_dnssec