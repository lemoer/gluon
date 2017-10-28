#!/bin/sh

domain=$(uci get gluon.system.domain)

[ -f /lib/gluon/domains/${domain}.json ] || (echo "file not found: /lib/gluon/domains/${domain}.json" >&2; exit 1) || exit 1

for s in /lib/gluon/upgrade/*; do
	echo -n ${s}:
	(${s} && echo " ok") || ( echo " error" && exit 1 ) || exit 1
done
