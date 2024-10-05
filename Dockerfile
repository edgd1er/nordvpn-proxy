ARG VER=3.20
FROM alpine:${VER}
LABEL maintainer=edgd1er

ENV OVPN_CONFIG_DIR="/config" \
  OPENVPN_LOGELEVEL=3 \
  SERVER_RECOMMENDATIONS_URL="https://api.nordvpn.com/v1/servers/recommendations" \
  SERVER_STATS_URL="https://nordvpn.com/api/server/stats/" \
  CRON="*/15 * * * *" \
  CRON_OVPN_FILES="@daily"\
  NORDVPN_USER="**None**" \
  NORDVPN_PASS="**None**" \
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


#hadolint ignore=DL3018,DL4006
RUN echo "####### Installing packages #######"  \
    && echo "@community https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk --no-cache --update add bash bash-completion wget curl runit tzdata jq ip6tables ufw@community openvpn shadow \
       bind-tools openssh dante-server ca-certificates unzip unbound socat vim tinyproxy \
	&& mkdir -p /openvpn/ -p /etc/service/openvpn /etc/service/dante /etc/service/crond /etc/service/unbound \
    && touch /etc/service/dante/down /etc/service/unbound/down \
    && curl -s https://www.internic.net/domain/named.cache -o /etc/unbound/root.hints \
    && echo "alias checkip='curl -sm 10 \"https://zx2c4.com/ip\";echo'" | tee -a ~/.bashrc \
    && echo "alias checkhttp='TCF=/run/secrets/TINY_CREDS; [[ -f \${TCF} ]] && TCREDS=\"\$(head -1 \${TCF}):\$(tail -1 \${TCF})@\" || TCREDS=\"\";curl -4 -sm 10 -x http://\${TCREDS}\${HOSTNAME}:\${TINY_PORT:-8888} \"https://ifconfig.me/ip\";echo'" | tee -a ~/.bashrc \
    && echo "alias checksocks='TCF=/run/secrets/TINY_CREDS; [[ -f \${TCF} ]] && TCREDS=\"\$(head -1 \${TCF}):\$(tail -1 \${TCF})@\" || TCREDS=\"\";curl -4 -sm10 -x socks5h://\${TCREDS}\${HOSTNAME}:1080 \"https://ifconfig.me/ip\";echo'" | tee -a ~/.bashrc \
    && echo "alias gettiny='grep -v ^# /config/tinyproxy.conf | sed \"/^$/d\"'" | tee -a ~/.bashrc \
    && echo "alias getdante='grep -v ^# /config/dante.conf | sed \"/^$/d\"'" | tee -a ~/.bashrc \
    && echo "alias dltest='curl http://appliwave.testdebit.info/100M.iso -o /dev/null'" | tee -a ~/.bashrc \
	&& echo "####### Removing cache #######" \
	&& rm -rf /*.zip -- /var/cache/apk/*
COPY baseconfig /baseconfig/
COPY ./app /etc/service/
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN    echo "####### Changing permissions #######" && \
    find /etc/service/ -type f -exec chmod u+x {} \; && \
    touch /etc/service/unbound/down /etc/service/dante/down

HEALTHCHECK --interval=1m --timeout=30s --start-period=1m --retries=10 CMD /etc/service/openvpn/healthcheck.sh

WORKDIR /etc/service

VOLUME /config/

CMD ["runsvdir", "/etc/service/"]