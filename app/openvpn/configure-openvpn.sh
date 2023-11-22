#!/usr/bin/env bash
#
# get config name based on api recommendation + ENV Vars (NORDVPN_COUNTRY, NORDVPN_PROTOCOL, NORDVPN_CATEGORY)
#
# 2021/09
#
#
# NORDVPN_COUNTRY: code or name
# curl -s "https://api.nordvpn.com/v1/servers/countries" | jq --raw-output '.[] | [.code, .name] | @tsv'
# NORDVPN_PROTOCOL: tcp or upd, tcp if none or unknown. Many technologies are not used as only openvpn_udp and openvpn_tcp are tested.
# Will request api with openvpn_<NORDVPN_PROTOCOL>.
# curl -s "https://api.nordvpn.com/v1/technologies" | jq --raw-output '.[] | [.identifier, .name ] | @tsv' | grep openvpn
# NORDVPN_CATEGORY: default p2p. not all countries have all combination of NORDVPN_PROTOCOL(technologies) and NORDVPN_CATEGORY(groups),
# hence many queries to the api may return no recommended servers.
# curl -s https://api.nordvpn.com/v1/servers/groups | jq .[].identifier
#
#Changes
# 2021/09/15: check ENV values if still supported
# 2021/09/22: store json results, merged configure-openvpn + updateConfigs.sh: OPENVPN_CONFIG is confusing for users. (#1958)
# 2022/01/04: add NORDVPN_SERVER to download the config file based on server's fqdn
# 2023/11/17: escape login and password.

set -e -u -o pipefail

#Variables
MAIN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"/.."
if [ -d /config ]; then
    #load var at runtime
    [[ -f /etc/service/utils.sh ]] && source /etc/service/utils.sh || true
else
    #load var for tests
    [[ -f ${MAIN_DIR}/utils.sh ]] && source ${MAIN_DIR}/utils.sh || true
fi

#remove stored files older than 1 day.
find ${CONFIGDIR} -type f -iname "json_*" -mtime +1 -exec ls -al {} \; -delete 2>/dev/null || true
#remove previous config
find ${CONFIGDIR} -type f -iname "*.ovpn" -mtime +1 -exec ls -al {} \; -delete 2>/dev/null || true
#store json between runs to prevent being blocked by api when testing
for i in json_countries json_groups json_technologies; do
    if [[ -f ${CONFIGDIR}/${i} ]]; then
        log "INFO" "NORDVPN: Using cached values for ${i}"
        declare "${i}=$(<${CONFIGDIR}/${i})"
    else
        declare "${i}="
    fi
done

#Nordvpn has a fetch limit, storing json to prevent hitting the limit.
if [[ -z ${json_countries} ]]; then
    log "INFO" "NORDVPN: Fetching countries from nordvpn"
    json_countries=$(curl -s ${nordvpn_api}/v1/servers/countries)
    echo ${json_countries} >${CONFIGDIR}/json_countries
fi
#groups used for NORDVPN_CATEGORY
if [[ -z ${json_groups} ]]; then
    log "INFO" "NORDVPN: Fetching groups from nordvpn"
    json_groups=$(curl -s ${nordvpn_api}/v1/servers/groups)
    echo ${json_groups} >${CONFIGDIR}/json_groups
fi
#technologies (NORDVPN_PROTOCOL) not used as only openvpn_udp and openvpn_tcp are tested.
if [[ -z ${json_technologies} ]]; then
    log "INFO" "NORDVPN: Fetching technologies from nordvpn"
    json_technologies=$(curl -s ${nordvpn_api}/v1/technologies)
    echo ${json_technologies} >${CONFIGDIR}/json_technologies
fi

# possible values for each vars
possible_categories="$(echo ${json_groups} | jq -r .[].identifier | tr '\n' ', ')"
possible_country_codes="$(echo ${json_countries} | jq -r .[].code | tr '\n' ', ')"
possible_country_names="$(echo ${json_countries} | jq -r .[].name | tr '\n' ', ')"
possible_protocol="$(echo ${json_technologies} | jq -r '.[] | [.identifier, .name ]' | tr '\n' ', ' | grep openvpn)"

# Functions
# TESTS: set values to test API response.
test1NoValues() {
    export NORDVPN_COUNTRY=''
    export NORDVPN_PROTOCOL=''
    export NORDVPN_CATEGORY=''
    log "INFO" "NORDVPN_TESTS: expected <your country code><NN>.nordvpn.com with openvpn_tcp"
    export NORDVPN_REG="[a-z]{2}[0-9]+.nordvpn.com"
}

test2NoCategory() {
    export NORDVPN_COUNTRY='EE'
    export NORDVPN_PROTOCOL='udp'
    export NORDVPN_CATEGORY=''
    log "INFO" "NORDVPN_TESTS: expected ee<NN>.nordvpn.com with openvpn_udp"
    export NORDVPN_REG="ee[0-9]+.nordvpn.com"
}

test3Incompatible_combinations() {
    export NORDVPN_COUNTRY='EE'
    export NORDVPN_PROTOCOL='openvpn_tcp_tls_crypt'
    export NORDVPN_CATEGORY='legacy_obfuscated_servers'
    log "INFO" "NORDVPN_TESTS: expected a config file not respecting country filter. + message: Unable to find a server with the specified parameters, using any recommended server"
    export NORDVPN_REG="[a-z]{2}[0-9]+.nordvpn.com"
}

test4ServerName_given() {
    unset NORDVPN_COUNTRY
    export NORDVPN_PROTOCOL='tcp'
    export NORDVPN_server=''
    #get first server from US (228) with tcp
    export NORDVPN_SERVER=$(curl -s 'https://api.nordvpn.com/v1/servers/recommendations?filters\[country_id\]=228&filters\[servers_technologies\]\[identifier\]=openvpn_tcp&limit=1' | jq -r .[].hostname)
    log "INFO" "NORDVPN_TESTS: expected a config file for server ${NORDVPN_SERVER}"
    export NORDVPN_REG="us[0-9]+.nordvpn.com"
}

fatal_error() {
    printf "\e[41mERROR:\033[0m %b\n" "$*" >&2
    exit 1
}

# check for utils
script_needs() {
    command -v $1 >/dev/null 2>&1 || fatal_error "This script requires $1 but it's not installed. Please install it and run again."
}

script_init() {
    log "INFO" "Checking curl installation"
    script_needs curl
}

country_filter() {
    NORDVPN_COUNTRY=${NORDVPN_COUNTRY:-""}
    local nordvpn_api=$1 country=(${NORDVPN_COUNTRY//[;,]/ })
    local country_id
    if [[ ${#country[@]} -ge 1 ]]; then
        country=${country[0]//_/ }
        country_id=$(echo ${json_countries} | jq --raw-output ".[] |
                          select( (.name|test(\"^${country}$\";\"i\")) or
                                  (.code|test(\"^${country}$\";\"i\")) ) |
                          .id" | head -n 1)
    fi
    if [[ -n ${country_id:-''} ]]; then
        log "INFO" "NORDVPN: Searching for country : ${country} (${country_id})"
        echo "filters\[country_id\]=${country_id}&"
    else
        log "WARNING" "NORDVPN: Empty or invalid NORDVPN_COUNTRY (value=${NORDVPN_COUNTRY}). Ignoring this parameter. Possible values are:${possible_country_codes[*]} or ${possible_country_names[*]}. Please check ${nordvpn_doc}"
    fi
}

group_filter() {
    NORDVPN_CATEGORY=${NORDVPN_CATEGORY:-""}
    local nordvpn_api=$1 category=(${NORDVPN_CATEGORY//[;,]/ })
    local identifier=''
    if [[ ${#category[@]} -ge 1 ]]; then
        #category=${category[0]//_/ }
        identifier=$(echo $json_groups | jq --raw-output ".[] |
                          select( ( .identifier|test(\"${category}\";\"i\")) or
                                  ( .title| test(\"${category}\";\"i\")) ) |
                          .identifier" | head -n 1)
    fi
    if [[ -n ${identifier} ]]; then
        log "INFO" "NORDVPN, searching for group: ${identifier}"
        echo "filters\[servers_groups\]\[identifier\]=${identifier}&"
    else
        log "WARNING" "NORDVPN: Empty or invalid NORDVPN_CATEGORY (value=${NORDVPN_CATEGORY}). ignoring this parameter. Possible values are: ${possible_categories[*]}. Please check ${nordvpn_doc}"
    fi
}

technology_filter() {
    local identifier
    NORDVPN_PROTOCOL=${NORDVPN_PROTOCOL:-tcp}
    if [[ ${NORDVPN_PROTOCOL,,} =~ .*udp.* ]]; then
        identifier="openvpn_udp"
    elif [[ ${NORDVPN_PROTOCOL,,} =~ .*tcp.* ]]; then
        identifier="openvpn_tcp"
    fi

    if [[ -n ${identifier} ]]; then
        log "INFO" "NORDVPN: searching for technology: ${identifier}"
        echo "filters\[servers_technologies\]\[identifier\]=${identifier}&"
    else
        log "WARNING" "NORDVPN: Empty or invalid NORDVPN_PROTOCOL (value=${NORDVPN_PROTOCOL}), expecting tcp or udp. setting to udp. Please read ${nordvpn_doc}"
        echo "filters\[servers_technologies\]\[identifier\]=openvpn_udp&"
        export NORDVPN_PROTOCOL=udp
    fi
}

select_hostname() {
    #TODO return multiples
    local filters hostname

    log "INFO" "Selecting the best server..."
    filters+="$(country_filter ${nordvpn_api})"
    filters+="$(group_filter ${nordvpn_api})"
    filters+="$(technology_filter)"
    vpnserver=""
    i=0
    while [[ -z ${vpnserver} ]] && [ ${i} -lt 10 ]; do
        vpnserver=$(curl -s "${nordvpn_api}/v1/servers/recommendations?${filters}limit=1" | jq --raw-output ".[].hostname")
        ((i++))
        if [[ ${i} -eq 5 ]]; then break; fi
        if [[ -z ${vpnserver} ]]; then
            log "WARNING" "NORDVPN: ${i} trial(s) to get best server from nordvpn api."
        fi
        sleep 5
    done
    if [[ -z ${vpnserver} ]]; then
        log "WARNING" "NORDVPN: unable to find a server with the specified parameters, please review your parameters, NORDVPN_COUNTRY=${NORDVPN_COUNTRY}, NORDVPN_CATEGORY=${NORDVPN_CATEGORY}, NORDVPN_PROTOCOL=${NORDVPN_PROTOCOL}"
        #hostname=$(curl "${nordvpn_api}/v1/servers/recommendations?limit=1" | jq --raw-output ".[].hostname")
        echo ''
    else
        load=$(curl -s ${nordvpn_api}/server/stats/${vpnserver} | jq .percent)
        log "INFO" "OVPN: Best server : ${vpnserver}, load: ${load}"
    fi
    echo ${vpnserver}
}
download_hostname() {
    NORDVPN_PROTOCOL=${NORDVPN_PROTOCOL:-"tcp"}
    #udp ==> https://downloads.nordcdn.com/configs/files/ovpn_udp/servers/nl601.nordvpn.com.udp.ovpn
    #tcp ==> https://downloads.nordcdn.com/configs/files/ovpn_tcp/servers/nl542.nordvpn.com.tcp.ovpn
    local nordvpn_cdn=${nordvpn_cdn}
    # remote filename: which protocol tcp or udp
    if [[ ${NORDVPN_PROTOCOL,,} == udp ]]; then
        nordvpn_cdn="${nordvpn_cdn}/ovpn_udp/servers/${1}.udp.ovpn"
        ovpnName=${1}.ovpn
    elif [[ ${NORDVPN_PROTOCOL,,} == tcp ]]; then
        nordvpn_cdn="${nordvpn_cdn}/ovpn_tcp/servers/${1}.tcp.ovpn"
        ovpnName=${1}.ovpn
    else
        #Defaulting to tcp if neither tcp nor udp given.
        nordvpn_cdn="${nordvpn_cdn}/ovpn_tcp/servers/${1}.tcp.ovpn"
        ovpnName=${1}.ovpn
    fi

    log "INFO" "OVPN: Downloading config: ${ovpnName}"
    log "INFO" "OVPN: Downloading from: ${nordvpn_cdn}"
    # VPN_PROVIDER_HOME defined is openvpn/start.sh
    outfile="-o "${VPN_PROVIDER_HOME}/${ovpnName}
    #when testing script outside of container, display config instead of writing it.
    if [ ! -w ${VPN_PROVIDER_HOME} ]; then
        log "WARNING" "NORDVPN: ${VPN_PROVIDER_HOME} is not writable, outputing ${ovpnName} to stdout"
        outfile=""
    fi
    curl -sSL ${nordvpn_cdn} ${outfile}
}

checkDNS() {
    res=$(dig +short ${nordvpn_dl}) || true
    if [[ ${res} =~ refused ]]; then
        fatal_error "OVPN: no dns resolution, dns server unavailable or network problem"
    else
        log "INFO" "DNS: resolution ok"
    fi
    ret=$(ping -c2 ${nordvpn_dl} 2>&1) || true
    if [[ $ret =~ \ 0%\ packet\ loss ]]; then
        log "INFO" "OVPN: ok, configurations download site reachable"
    else
        fatal_error "ERROR: OVPN: cannot ping ${nordvpn_cdn}, network or internet unavailable. Cannot download NORDVPN configuration files"
    fi
}

# Main
# If the script is called from elsewhere
cd "${0%/*}"
script_init
checkDNS

if [[ -d ${VPN_PROVIDER_HOME} ]]; then
    log "INFO" "NORDVPN: Removing existing configs in ${VPN_PROVIDER_HOME}"
    find ${VPN_PROVIDER_HOME} -type f -name '*.ovpn' -delete
fi

#get config based on server name
NORDVPN_SERVER=${NORDVPN_SERVER:-""}
if [[ -n ${NORDVPN_SERVER} ]]; then
    selected=${NORDVPN_SERVER}
    load=$(curl -s ${nordvpn_api}/server/stats/${NORDVPN_SERVER} | jq .percent 2>/dev/null)
    log "INFO" "OVPN: server : ${NORDVPN_SERVER}, load: ${load:-N/A}"
fi

if [[ -n ${NORDVPN_TESTS} ]]; then
    case ${NORDVPN_TESTS} in
    1)
        #get recommended config when no values are given, use defaults one, display a warning with possible values
        test1NoValues
        ;;
    2)
        #When no category, get recommended config, display warning with possible values
        test2NoCategory
        ;;
    3)
        #When incompatibles combinations, no recommended config is given, exit with error log.
        test3Incompatible_combinations
        ;;
    4)
        #try to download config file for the given servername
        test4ServerName_given
        ;;
    *)
        log "WARNING" "OVPN: tests requested but not found, expected 1,2,3 or 4, got ${NORDVPN_TESTS}"
        exit
        ;;
    esac
fi

#get config based on server name
NORDVPN_SERVER=${NORDVPN_SERVER:-""}
if [[ -n ${NORDVPN_SERVER} ]]; then
    selected=${NORDVPN_SERVER}
    load=$(curl -s ${nordvpn_api}/server/stats/${NORDVPN_SERVER} | jq .percent 2>/dev/null)
    log "INFO" "OVPN: server : ${NORDVPN_SERVER}, load: ${load:-N/A}"
else
    log "INFO" "Checking NORDPVN API responses"
    for po in json_countries json_groups json_technologies; do
        if [[ $(echo ${!po} | grep -c "<html>") -gt 0 ]]; then
            msg=$(echo ${!po} | grep -oP "(?<=title>)[^<]+")
            fatal_error "Unexpected html content from NORDVPN servers: ${msg}"
            sleep 30
            exit
        fi
    done

    possible_categories="$(echo ${json_groups} | jq -r .[].identifier | tr '\n' ', ')"
    possible_country_codes="$(echo ${json_countries} | jq -r .[].code | tr '\n' ', ')"
    possible_country_names="$(echo ${json_countries} | jq -r .[].name | tr '\n' ', ')"
    possible_protocol="$(echo ${json_technologies} | jq -r '.[] | [.identifier, .name ]' | tr '\n' ', ' | grep openvpn)"

    #get server name from api (best recommended for NORDVPN_<> if defined)
    selected="$(select_hostname)"
fi
if [[ -n ${selected} ]]; then
    log "INFO" "NORDVPN: selected: ${selected}, VPN_PROVIDER_HOME: ${VPN_PROVIDER_HOME}"
    download_hostname ${selected}
elif [[ ${NORDVPN_TESTS:-0} -ne 3 ]]; then
    fatal_error "server compliant with your settings not found, review them"
fi

#handle tests results.
if [[ -n ${NORDVPN_TESTS} ]]; then
    msg=""
    error=0
    [[ -f ${VPN_PROVIDER_HOME}/${selected}.ovpn ]] && res=$(<${VPN_PROVIDER_HOME}/${selected}.ovpn)
    case ${NORDVPN_TESTS} in
    1)
        if [[ ${selected} =~ ${NORDVPN_REG} ]]; then
            msg+="\nOVPN/NORDVPN: test 1: OK: ${selected} matching expected ${NORDVPN_REG}"
        else
            error=1
            msg+="\nOVPN/NORDVPN: test 1: KO: ${selected} not matching expected ${NORDVPN_REG}"
        fi
        if [[ $(echo $res | grep -c "proto tcp") -eq 0 ]]; then
            error=1
            msg+="\nOVPN/NORDVPN: test 1: KO: ${selected} is not with tcp protocol"
            msg+="\n"${res}
        else
            msg+="\nOVPN/NORDVPN: test 1: OK: ${selected} is with tcp protocol"
        fi
        ;;
    2)
        if [[ ${selected} =~ ${NORDVPN_REG} ]]; then
            msg+="\nOVPN/NORDVPN: test 2: OK: ${selected} matching expected ${NORDVPN_REG}"
        else
            error=1
            msg+="\nOVPN/NORDVPN: test 2: KO: ${selected} not matching expected ${NORDVPN_REG}"
        fi
        if [[ $(echo $res | grep -oc "proto udp") -eq 0 ]]; then
            error=1
            msg+="\nOVPN/NORDVPN: test 2: KO: ${selected} is not with udp protocol"
            msg+="\n"${res}
        else
            msg+="\nOVPN/NORDVPN: test 2: OK: ${selected} is with udp protocol"
        fi
        ;;
    3)
        if [[ -z ${selected} ]]; then
            msg+="\nOVPN/NORDVPN: test 3: OK: No server selected. expected: no server could fulfill our criteria"
        else
            error=1
            msg+="\nOVPN/NORDVPN: test 3: KO: server ${selected} selected, should be empty as no server could fulfill our criteria."
        fi
        ;;
    4)
        if [[ ${selected} =~ ${NORDVPN_REG} ]]; then
            msg+="\nOVPN/NORDVPN: test 4: OK: ${selected} matching expected ${NORDVPN_REG}"
        else
            error=1
            msg+="\nOVPN/NORDVPN: test 4: KO: ${selected} not matching expected ${NORDVPN_REG}"
        fi
        if [[ $(echo $res | grep -oc "proto tcp") -eq 0 ]]; then
            error=1
            msg+="\nOVPN/NORDVPN: test 4: KO: ${selected} is not with tcp protocol"
            msg+=${res}
        else
            msg+="\nOVPN/NORDVPN: test 4: OK: ${selected} is with tcp protocol"
        fi
        ;;
    *)
        fatal_error "\nOVPN: NORDVPN: ${VPN_PROVIDER_HOME}/${selected}.ovpn not found"
        ;;
    esac
    if [[ $error -eq 1 ]]; then
        fatal_error ${msg}
    else
        log "INFO" ${msg}
    fi
    fatal_error "OVPN: NORDVPN: end of test, container stopped."
    [[ /.dockerinit ]] && pkill dumb_init || true
fi

# fix deprecated ciphers
if [[ -f ${VPN_PROVIDER_HOME}/${selected}.ovpn ]]; then
    #add data ciphers: DEPRECATED OPTION: --cipher set to 'AES-256-CBC' but missing in --data-ciphers (AES-256-GCM:AES-128-GCM).
    if [[ 0 -le $(grep -c "cipher AES-256-CBC" ${VPN_PROVIDER_HOME}/${selected}.ovpn) ]] && [[ 0 -eq $(grep -c "data-ciphers AES-256-CBC" ${VPN_PROVIDER_HOME}/${selected}.ovpn) ]]; then
        sed -i "/cipher AES-256-CBC/a data-ciphers AES-256-CBC" ${VPN_PROVIDER_HOME}/${selected}.ovpn
    fi
fi

export OPENVPN_CONFIG=${selected}

#cd "${0%/*}"