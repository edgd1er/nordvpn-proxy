FROM rust as builder

RUN cargo install --git https://github.com/twitchax/rusty_socks

FROM bubuntux/nordvpn:latest

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
  CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r \'.["status"]\' ) = "Protected" ; then exit 0; else exit 1; fi


COPY --from=builder /usr/local/cargo/bin/rusty_socks .
COPY rusty.toml .
RUN chmod 777 rusty_socks

COPY start.sh .
RUN chmod 777 start.sh

EXPOSE 1080

ENTRYPOINT [ "/start.sh" ]