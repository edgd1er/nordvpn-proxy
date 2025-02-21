# nordvpn-proxy

[![lint dockerfile](https://github.com/edgd1er/nordvpn-proxy/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/edgd1er/nordvpn-proxy/actions/workflows/lint.yml)

[![build multi-arch images](https://github.com/edgd1er/nordvpn-proxy/actions/workflows/buildPush.yml/badge.svg?branch=main)](https://github.com/edgd1er/nordvpn-proxy/actions/workflows/buildPush.yml)

![Docker Size](https://badgen.net/docker/size/edgd1er/nordvpn-proxy?icon=docker&label=Size)
![Docker Pulls](https://badgen.net/docker/pulls/edgd1er/nordvpn-proxy?icon=docker&label=Pulls)
![Docker Stars](https://badgen.net/docker/stars/edgd1er/nordvpn-proxy?icon=docker&label=Stars)
![ImageLayers](https://badgen.net/docker/layers/edgd1er/nordvpn-proxy?icon=docker&label=Layers)


This is a NordVPN client docker container using openvpn that use the recommended NordVPN servers, and opens a SOCKS5 (dante server) and http proxy (tinyproxy).

VPN servers selection is performed through nordnvpn API.(country, technology, protocol)

Added docker image version for amd64,arm64, arm/v7, arm/v6  

Whenever the connection is lost the unbound, tinyproxy and sock daemons are killed, disconnecting all active connections (tunnel down event).

Healtcheck tests dns resolution, openvpn status (connected), tinyproxy listening address, https/socks proxies.

Protected status was checked through nordvpn api, as the endpoint was removed, this image does not test its protected status.
As long as openvpn returns a connected status, vpn is up.

Please note that an image called `edgd1er/nordlynx-proxy` exists also.
* PRO: can use wireguard or openvpn, much higher rates when connecting using wireguard
* CON: nordvpn client is proprietary. image is much bigger (7x).

## What is this?

This image is largely based on [jeroenslot/nordvpn-proxy](https://github.com/Joentje/nordvpn-proxy) with dante free socks server added. 
you can then expose port `1080` from the container to access the VPN connection via the SOCKS5 proxy.

To sum up, this container:
* Opens the best connection to NordVPN using openvpn and the conf downloaded using NordVpn API according to your criteria.
* Starts a HTTP proxy that route `eth0:8888` to `eth0:1080` (socks server) with [tinyproxy](https://tinyproxy.github.io/)
* Starts a SOCKS5 proxy that routes `eth0:1080` to `tun0/nordlynx` with [dante-server](https://www.inet.no/dante/).
* Starts unbound as dnssec querying specified DNS. 

The main advantage is that you get the best recommendation for each selection.

## Usage

### Step 1 - Get NordVPN service username and password (NOT your email and pw)

Nordvpn openvpn credentials are to be found following that procedure:
* Go to NordVPN website and log in
* Under accounts - Services - click NordVPN
* Click - Set up NordVPN manually - at the bottom right of the page.
    * You will receive a verification code in your email that you use for NordVPN services. Type the code in the popup window the preceded the email check.
* Copy the credentials using the “Copy” buttons on the right for your new encrypted user name and password and paste them in nordvpn_creds

### Step 2 - Start the container

#### Option 1 - interactive on the command line (for testing and running temporarily)

Make sure you customise the parameters:
* correct LOCAL_NETWORK mask otherwise the proxy is only available localhost
* correct NORDVPN_USER (see Step 1)
* correct NORDVPN_PASS (see Step 1)
* your preferred NORDVPN_COUNTRY

```
docker run -it --rm -p 1081:1080 -p 8888:8888 --cap-add NET_ADMIN -e LOCAL_NETWORK=10.0.0.0/24 -e NORDVPN_USER=xxxSOME_SERVICE_USERNAMExxx -e NORDVPN_PASS=xxxSOME_SERVICE_PASSWORDxxx -e NORDVPN_COUNTRY=Australia -e NORDVPN_PROTOCOL=udp -e NORDVPN_CATEGORY=p2p -e DEBUG=0 edgd1er/nordvpn-proxy
```

#### Option 2 - set up the container

[Script](https://github.com/haugene/docker-transmission-openvpn/blob/master/openvpn/nordvpn/updateConfigs.sh) for OpenVpn config download is base on the one developped for [haugene](https://github.com/haugene/docker-transmission-openvpn) 's docker transmission openvpn
https://haugene.github.io/docker-transmission-openvpn/provider-specific/

The container is expecting three parameters to select the vpn server:
* [NORDVPN_COUNTRY](https://api.nordvpn.com/v1/servers/countries) define the exit country.
* [NORDVPN_PROTOCOL](https://api.nordvpn.com/v1/technologies) although many protocols are possible, only tcp or udp are available.
* [NORDVPN_CATEGORY](https://api.nordvpn.com/v1/servers/groups) although many categories are possible, p2p seems more adapted.

> NOTE: This container works best using the `p2p` technology.
> 
> NOTE: At the moment, this container has no kill switch... meaning that when the VPN connection is down, the connection will be rerouted through your provider. although, on tunnel down event, the socks server is stopped preventing to relay unprotected requests, and defaults route through eth0 (not vpn) are deleted.   
>
> NOTE: as of 22/03/28, NORDVPN_LOGIN and NORDVPN_PASS secrets file are replaced with a single file, NORDVPN_CREDS, having login at first line and password as the second line.


* DNS to uses external DNS, if none given: "1.1.1.1@853#cloudflare-dns.com 1.0.0.1@853#cloudflare-dns.com"
* NORDVPN_USER=email or service user
* NORDVPN_PASS=pass or service pass
* EXIT_WHEN_IP_NOTEXPECTED=(0|1) # stop container when detected network is not as expected (based on /24 networks)
* [NORDVPN_SERVER](https://nordvpn.com/api/server/stats)=<country><#>.nordvpn.com: eg: nl568.nordvpn.com, get configuration based on server's fqdn, bypassing all api's recommendations. Connection may fail when the server is offline or overloaded. has precedence over NORDVPN_COUNTRY and NORDVPN_CATEGORY.
* NORDVPN_TESTS=[1-4], simple tests to test basic api filtering functions. 
* WRITE_OVPN_STATUS=(0|1): write openvpn status (CONNECTED/NOTCONNECTED) to /var/tmp/ovpn_status. you may mount the file to get the openvpn status outside the container.
* WAITSEC=30, default value, time to wait between two vpn login.

#### How to run the container

* Just copy/paste the grey text block starting with version 3.8. to a file named compose.yml
* Set values for NORDVPN_TECHNOLOGY, NORDVPN_PROTOCOL, NORDVPN_COUNTRY
* adapt if needed LOCAL_NETWORK, TZ
* create file nordvpn_creds containing your login in the first line and your password in the second line.

nordvpn_creds:
```
thisismyusername
thisismypassword
```

* start the container: docker compose up -d

once the container is started, you will see in the logs these two lines, indicating that both socks and http proxies are up.
```
nordvpn-proxy  | INFO: OPENVPN: up: starting tinyproxy
.....
nordvpn-proxy  | ok: run: tinyproxy: (pid 103) 1s, normally down

see docker-compose-dist.yml for an example to setup and run this image. 

```yaml
services:
  proxy:
    image: edgd1er/nordvpn-proxy:latest
    restart: unless-stopped
    ports:
      - "1081:1080" # socks port udp or tcp
      - "8888:8888/tcp" # http proxy tcp.
#    devices:
#      - /dev/net/tun #Optional, will be created if not preset
    sysctls:
      - net.ipv4.conf.all.rp_filter=2
    cap_add:
      - NET_ADMIN
    environment:
      - TZ=America/Chicago
      - DNS=1.1.1.1@853#cloudflare-dns.com 1.0.0.1@853#cloudflare-dns.com
      - NORDVPN_COUNTRY=germany #Optional, by default, servers in user's country.
      - NORDVPN_PROTOCOL=udp #Optional, udp by default, udp or tcp
      - NORDVPN_CATEGORY=p2p #Optional, Africa_The_Middle_East_And_India, Asia_Pacific, Europe, Onion_Over_VPN, P2P, Standard_VPN_Servers, The_Americas
      - NORDVPN_USER=<email> #Not required if using secrets
      - NORDVPN_PASS=<pass> #Not required if using secrets
      - OPENVPN_PARAMETERS= #optional, empty by default, overrides openvpn config file with parameters
      - OPENVPN_LOGLEVEL= #Optional, define openvpn verbose level 0-9
      - EXIT_WHEN_IP_NOTASEXPECTED=0 # when detected ip is not belonging to remote vpn network
      - LOCAL_NETWORK=192.168.0.0/24 # allow network access for socks and tinyproxy.
      - TINYPORT=8888 #define tinyport inside the container, optional, 8888 by default,
      - TINY_LOGLEVEL=Error #Critical (least verbose), Error, Warning, Notice, Connect (to log connections without Info's noise), Info
      - DANTE_LOGLEVEL="error" #Optional, error by default, available values: connect disconnect error data
      - DANTE_ERRORLOG=/dev/stdout #Optional, /dev/null by default
      - CRON_LOGLEVEL=9 #optional, from 0 to 9, 8 default, 9 quiet.
      - DEBUG=0 #(0/1) activate debug mode for scripts, dante, nginx, tinproxy
      - TINYUSER=username #define http/socks proxy password, not required if using secrets
      - TINYPASS=password #define http/socks proxy password, not required if using secrets
    secrets:
        - NORDVPN_CREDS
        - TINY_CREDS
    volumes:
      - ./myconfig/:/config/

secrets:
    NORDVPN_CREDS:
        file: ./nordvpn_creds
    TINY_CREDS:
    file: ./tiny_creds
```
# Healthcheck

script checks for:
* proper dnssec resolution
* openvpn service being up
* openvpn being connected
* warns if openvpn remote ip seems not coherent

if any of these fail, services are restarted.
!
dockerfile healtcheck:
* dns check
* check openvpn status
* check if eth0 ip has changed, change tinyproxy listen address if needed.
* check ip through proxies

## Debugging

if ever the container is not running healthy, there are few aliases defined for first tests:
* checkip: get external ip ( ip should be different from your isp'ip )
* checkhttp: get external ip through http proxy (ip should be different from your isp'ip)
* checksocks: get external ip throuch socks proxy ( ip should be different from your isp'ip)
* gettiny: show http proxy conf ( check listen address )
* getdante: show socks prox conf ( check listen address )
* dltest: download a 100M file to check download rate.

run in the container:
```
source /etc/service/utils.sh
# echo should return 0 meaning vpn is up.
getStatusFromNordvpn
echo $?
getStatusFromNordvpn2
echo $?
#should return external ip (vpn) not yours
checkip
#should return the same ip as checkip 
testhproxy
testsproxy
# Display listen ip for http proxy
getTinyListen
# get tiny credentials if any
getTinyCred
# get http and socks proxy conf
getTinyConf
getDanteConf
```


# Kill switch
When vpn interface (tun) is up, default route through unprotected interface (eth0) is removed.
To ensure that little or no traffic is forwarded unprotected, services are stopped on any of these events:

- when the api returns that the status is not protected, the container stops.(every 5min)
- when openvpn returns a status NOTCONNECTED, all services are stopped, openvpn is restarted. when ok, dante and tinyproxy are started.(checked every 5 minutes)
- when openvpn service is stopped, the down phase (runit feature) stops all other services.
- when the tun interface is disconnected, openvpn fires the down.sh script, stopping all services. 


# Other image

Another image is available using nordvpn's client. Openvpn and wireguard (nordlynx) protocols are available. better speed may be achieved with wireguard.

| names          | links                                                  |
|----------------|--------------------------------------------------------|
| nordlynx-proxy | image: https://hub.docker.com/r/edgd1er/nordlynx-proxy |
| nordlynx-proxy | github: https://github.com/edgd1er/nordlynx-proxy      |
