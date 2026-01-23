#!/usr/bin/env bash

set -euo pipefail

# Minimaler Helper: startet zwei Docker-Container via docker-compose
# und konfiguriert darin einen WireGuard-Tunnel per docker exec.

DOCKER_COMPOSE_FILE="docker-compose.yml"

WG_C1="wg1"
WG_C2="wg2"
WG_C1_IP="10.200.0.2"
WG_C2_IP="10.200.0.3"

WG_TUN_IP1="10.10.0.1/24"
WG_TUN_IP2="10.10.0.2/24"
WG_PORT1=51820
WG_PORT2=51821

if ! sudo iptables -S FORWARD | grep -q "^-P FORWARD ACCEPT"; then
	sudo iptables -P FORWARD ACCEPT
	sudo iptables -F FORWARD
fi

docker_up() {
	if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
		echo "[!] ${DOCKER_COMPOSE_FILE} nicht gefunden – bitte im Projektverzeichnis ausführen." >&2
		return 1
	fi

	echo "[+] Starte Docker-Stack aus ${DOCKER_COMPOSE_FILE}"
	docker compose -f "${DOCKER_COMPOSE_FILE}" up -d

	echo "[+] Generiere WireGuard-Schlüsselpaare für Container-Setup"
	KEYDIR=$(mktemp -d)
	umask 077
	wg genkey | tee  "${KEYDIR}/priv1" | wg pubkey > "${KEYDIR}/pub1"
	wg genkey | tee  "${KEYDIR}/priv2" | wg pubkey > "${KEYDIR}/pub2"

	PRIV1=$(<"${KEYDIR}/priv1")
	PUB1=$(<"${KEYDIR}/pub1")
	PRIV2=$(<"${KEYDIR}/priv2")
	PUB2=$(<"${KEYDIR}/pub2")

	echo "[+] Konfiguriere WireGuard in Containern ${WG_C1} und ${WG_C2}"

	docker exec -e PRIV1="${PRIV1}" -e PUB2="${PUB2}" "${WG_C1}" \
		sh -c '
		set -e
		ip link del wg0 2>/dev/null || true
		ip link add dev wg0 type wireguard
			ip addr add dev wg0 '"${WG_TUN_IP1}"'
			ip link set wg0 up
		printf "%s\n" "$PRIV1" >/tmp/wgkey && chmod 600 /tmp/wgkey
		wg set wg0 private-key /tmp/wgkey listen-port '"${WG_PORT1}"' peer "$PUB2" allowed-ips '"${WG_TUN_IP2}"' endpoint '"${WG_C2_IP}:${WG_PORT2}"'
		ip link set wg0 up
		rm -f /tmp/wgkey
		'

	docker exec -e PRIV2="${PRIV2}" -e PUB1="${PUB1}" "${WG_C2}" \
		sh -c '
		set -e
		ip link del wg0 2>/dev/null || true
		ip link add dev wg0 type wireguard
		ip addr add '"${WG_TUN_IP2}"' dev wg0 || true
		printf "%s\n" "$PRIV2" >/tmp/wgkey && chmod 600 /tmp/wgkey
		wg set wg0 private-key /tmp/wgkey listen-port '"${WG_PORT2}"' peer "$PUB1" allowed-ips '"${WG_TUN_IP1}"' endpoint '"${WG_C1_IP}:${WG_PORT1}"'
		ip link set wg0 up
		rm -f /tmp/wgkey
		'

	echo "[+] Docker-WireGuard-Setup fertig. Beispiele zum Testen:"
	echo "    docker exec ${WG_C1} ping -c2 10.10.0.2"
	echo "    docker exec ${WG_C1} iperf3 -c 10.10.0.2 -t 10"
}

docker_down() {
	if [[ -f "${DOCKER_COMPOSE_FILE}" ]]; then
		echo "[+] Stoppe Docker-Stack aus ${DOCKER_COMPOSE_FILE}"
		docker compose -f "${DOCKER_COMPOSE_FILE}" down -v || true
	fi
}

usage() {
	echo "Usage: $0 [up|down|restart]" >&2
}

cmd="${1-up}"

case "${cmd}" in
	up)
		docker_up
		;;
	down)
		docker_down
		;;
	restart)
		docker_down
		docker_up
		;;
	*)
		usage
		exit 1
		;;
esac

