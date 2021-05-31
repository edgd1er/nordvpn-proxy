FROM alpine:3.13
LABEL maintainer=edgd1er@hotmail.com

EXPOSE 1080

ENV OVPN_CONFIG_DIR="/app/ovpn/config" \
  SERVER_RECOMMENDATIONS_URL="https://api.nordvpn.com/v1/servers/recommendations" \
  SERVER_STATS_URL="https://nordvpn.com/api/server/stats/" \
  CRON="*/15 * * * *" \
  CRON_OVPN_FILES="@daily"\
  NORDVPN_USER="" \
  NORDVPN_PASS="" \
  NORDVPN_COUNTRY="" \
  NORDVPN_CATEGORY="" \
  NORDVPN_PROTOCOL="" \
  LOAD=75 \
  RANDOM_TOP="" \
  LOCAL_NETWORK="" \
  DANTE_PORT=1080

COPY ./app /app
COPY ./config /config/

SHELL ["/bin/ash", "-o", "pipefail", "-c"]
#hadolint ignore=DL3018
RUN echo "####### Installing packages #######" && \
    echo "@community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk --no-cache --update add bash wget curl runit tzdata jq ip6tables ufw@community openvpn shadow bind-tools \
    openssh dante-server ca-certificates unzip unbound openvpn dante-server wget ca-certificates unzip unbound runit && \
	mkdir -p /openvpn/ && \
	echo "####### Removing cache #######" && \
	rm -rf /*.zip -- /var/cache/apk/* && \
    echo "####### Changing permissions #######" && \
    find /app -name run -print0 | xargs chmod u+x && \
    find /app -name "*.sh" -print0 | xargs chmod u+x

HEALTHCHECK --interval=5m --timeout=20s --start-period=1m \
  CMD if test $( curl -m 10 -s https://api.nordvpn.com/vpn/check/full | jq -r \'.["status"]\' ) = "Protected" ; then exit 0; else exit 1; fi

CMD ["runsvdir", "/app"]