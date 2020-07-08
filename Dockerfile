FROM bubuntux/nordvpn

RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted add dante-server && \
    rm -rf /tmp/*

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
  CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r '.["status"]' ) = "Protected" ; then exit 0; else nordvpn connect ${CONNECT} ; exit $?; fi

COPY sockd.conf /etc/sockd.conf
COPY start.sh .
RUN chmod 777 start.sh

EXPOSE 1080

ENTRYPOINT [ "/start.sh" ]
