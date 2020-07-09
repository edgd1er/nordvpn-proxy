FROM bubuntux/nordvpn

RUN apt-get update \
    && apt-get install -y dante-server \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
  CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r \'.["status"]\' ) = "Protected" ; then exit 0; else exit 1; fi

COPY sockd.conf /etc/sockd.conf
COPY start.sh .
RUN chmod 777 start.sh

EXPOSE 1080

ENTRYPOINT [ "/start.sh" ]
