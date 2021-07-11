![build nordvpn-proxy multi-arch images](https://github.com/edgd1er/nordvpn-proxy/workflows/build%20nordvpn-proxy%20multi-arch%20images/badge.svg)

# nordvpn-proxy

This is a NordVPN client docker container that use the recommended NordVPN servers, and opens a SOCKS5 proxy.

Added docker image version for raspberry.  

Whenever the connection is lost the unbound and sock daemon are killed, disconnecting all active connections.

## What is this?

This image is largely based on [jeroenslot/nordvpn-proxy](https://github.com/Joentje/nordvpn-proxy) with dante free socks server added. 
you can then expose port `1080` from the container to access the VPN connection via the SOCKS5 proxy.

In short, this container:
* Opens the best connection to NordVPN using openvpn and the conf downloaded using NordVpn API according to your criteria.
* Start a dns server for container resolution
* Starts a SOCKS5 proxy that routes `eth0` to `tun0` with [dante-server](https://www.inet.no/dante/).

The main advantage is that you get the best recommendation for each selection.

## Usage

[Script](https://github.com/haugene/docker-transmission-openvpn/blob/master/openvpn/nordvpn/updateConfigs.sh) for OpenVpn config download is base on the one developped for [haugene](https://github.com/haugene/docker-transmission-openvpn) 's docker transmission openvpn
https://haugene.github.io/docker-transmission-openvpn/provider-specific/

The container is expecting three informations to select the vpn server:
* [NORDVPN_COUNTRY](https://api.nordvpn.com/v1/servers/countries) define the exit country.
* [NORDVPN_PROTOCOL](https://api.nordvpn.com/v1/technologies) although many protocols are possible, only tcp or udp are available.
* [NORDVPN_CATEGORY](https://api.nordvpn.com/v1/servers/groups) although many categories are possible, p2p seems more adapted.
 
> NOTE: This container works best using the `p2p` technology.
> 
> NOTE: At the moment, this container has no kill switch... meaning that when the VPN connection is down, the connection will be rerouted through your provider.

* DNS to uses external DNS, if none given: "1.1.1.1@853#cloudflare-dns.com 1.0.0.1@853#cloudflare-dns.com"
* NORDVPN_USER=email
* NORDVPN_PASS=pass

```bash
docker run -it --rm --cap-add NET_ADMIN -p 1080:1080 -e NORDVPN_USER=<email> -e NORDVPN_PASS='<pass>' -e NORDVPN_COUNTRY=Poland
 -e NORDVPN_PROTOCOL=udp -e NORDVPN_CATEGORY=p2p   edgd1er/nordvpn-proxy
```