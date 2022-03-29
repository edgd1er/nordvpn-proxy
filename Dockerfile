FROM alpine:3.15
LABEL maintainer=edgd1er

ENV OVPN_CONFIG_DIR="/app/openvpn/config" \
  OPENVPN_LOGELEVEL=3 \
  SERVER_RECOMMENDATIONS_URL="https://api.nordvpn.com/v1/servers/recommendations" \
  SERVER_STATS_URL="https://nordvpn.com/api/server/stats/" \
  CRON="*/15 * * * *" \
  CRON_OVPN_FILES="@daily"\
  NORDVPN_USER="" \
  NORDVPN_PASS="" \
  NORDVPN_COUNTRY="" \
  NORDVPN_SERVER="" \
  NORDVPN_CATEGORY="" \
  NORDVPN_PROTOCOL="openvpn_tcp" \
  LOAD=75 \
  RANDOM_TOP="" \
  LOCAL_NETWORK="" \
  DANTE_PORT=1080 \
  TINY_PORT=8888

EXPOSE ${DANTE_PORT}
EXPOSE ${TINY_PORT}

SHELL ["/bin/ash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3018
RUN echo "####### Installing packages #######" && \
    echo "@community https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk --no-cache --update add bash wget curl runit tzdata jq ip6tables ufw@community openvpn shadow bind-tools \
    openssh dante-server ca-certificates unzip unbound socat vim tinyproxy && \
	mkdir -p /openvpn/ -p /etc/service/openvpn /etc/service/dante /etc/service/crond /etc/service/unbound && \
    touch /etc/service/dante/down /etc/service/unbound/down && \
    curl -s https://www.internic.net/domain/named.cache -o /etc/unbound/root.hints && \
	echo "####### Removing cache #######" && \
	rm -rf /*.zip -- /var/cache/apk/*
COPY ./config /config/
COPY ./app /etc/service/
RUN    echo "####### Changing permissions #######" && \
    find /etc/service/ -type f -exec chmod u+x {} \; && \
    touch /etc/service/unbound/down /etc/service/dante/down

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
  CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r '.["status"]' ) = "Protected" ; then exit 0; else exit 1; fi

WORKDIR /etc/service

CMD ["runsvdir", "/etc/service/"]