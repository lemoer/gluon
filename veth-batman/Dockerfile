FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       iproute2 iptables wireguard-tools tcpdump netcat-openbsd iperf3 iputils-ping ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Einfach nur laufen lassen; Konfiguration erfolgt über init.sh via docker exec
CMD ["sleep", "infinity"]
