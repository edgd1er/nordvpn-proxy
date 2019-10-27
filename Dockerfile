FROM bubuntux/nordvpn

RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted add dante-server && \
    rm -rf /tmp/*

COPY sockd.conf /etc/sockd.conf
COPY start.sh .
RUN chmod 777 start.sh

EXPOSE 1080

ENTRYPOINT [ "/start.sh" ]