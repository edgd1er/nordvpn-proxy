FROM bubuntux/nordvpn

RUN apt-get update \
    && apt-get install -y dante-server \
    && rm -rf /var/lib/apt/lists/*

COPY sockd.conf /etc/sockd.conf
COPY start.sh .
RUN chmod 777 start.sh

EXPOSE 1080

ENTRYPOINT [ "/start.sh" ]