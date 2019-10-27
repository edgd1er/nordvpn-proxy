# nordvpn-proxy

This is a NordVPN client docker container that use the recommended NordVPN servers, and opens a SOCKS5 proxy.

## What is this?

This is [bubuntux/nordvpn](https://github.com/bubuntux/nordvpn) with a [Dante](https://www.inet.no/dante/) SOCKS5 proxy.  The usage is the exact same as [bubuntux/nordvpn](https://github.com/bubuntux/nordvpn), except you can then expose port `1080` from the container to access the VPN connection via the SOCKS5 proxy.  In short, this container:
* Opens the best connection to NordVPN using [bubuntux/nordvpn](https://github.com/bubuntux/nordvpn) as a base.
* Starts a SOCKS5 proxy that routes `eth0` to `tun0` with [Dante](https://www.inet.no/dante/).

## Usage

```bash
docker run -it --rm --cap-add NET_ADMIN -p 1080:1080 -e USER=<email> -e PASS='<pass>' -e PROTOCOL=udp twitchax/nordvpn-proxy
```