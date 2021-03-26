#!/bin/sh

GLUON_CERT_STATE_FILE=/tmp/gluon-acme/state

if [ "$(uci get acme.gluon_cert.enabled)" -eq 0 ]; then
	exit 0
fi

gluon_is_staging() {
	[ "$(uci get acme.gluon_cert.use_staging)" -eq 1 ]
}

gluon_check_letsencrypt_reachability() {
	ping -c 1 letsencrypt.org -w 1 > /dev/null 2>/dev/null
}

gluon_set_cert_state() {
	echo "$1" > "$GLUON_CERT_STATE_FILE"
}

mkdir -p "$(dirname "$GLUON_CERT_STATE_FILE")"
gluon_set_cert_state unknown

INCLUDE_ONLY=1
source /usr/share/uacme/run-uacme
INCLUDE_ONLY=

GLUON_STATE_DIR="$STATE_DIR";

while true; do

	# Wait until letsencrypt.org becomes reachable.
	#
	# This makes sense to leave the state "unknown". If we would continue here
	# before we can reach the letsencrypt servers, we would end up in errors
	# and change the state to "error". This wouldn't really make sense because
	# the cert might actually be valid and up to date.
	if ! gluon_check_letsencrypt_reachability; then
		echo gluon-fast-acme.sh: letsencrypt.org is not reachable. Waiting until it is reachable.
		gluon_set_cert_state unknown
	fi
	while ! gluon_check_letsencrypt_reachability; do :; done

	# TODO: This is very hacky! issue_cert overrides the value of the global
	# variable STATE_DIR in case of a staging certificate. However this is one
	# way. If we want to obtain a production certificate, it is not corrected
	# back to it's original value. So we reset it to its initial value here.
	STATE_DIR="$GLUON_STATE_DIR"
	issue_cert gluon_cert; ret=$?

	if [ "$ret" -eq 0 ] || [ "$ret" -eq 1 ]; then
		# the issue_cert was successful or time for renew has not come yet.

		if gluon_is_staging; then
			# staging was successful, so we switch to production environment
			uci set acme.gluon_cert.use_staging=0
			uci commit acme
			echo gluon-fast-acme.sh: Staging certificate obtained. Continuing with production server.
			gluon_set_cert_state staging_obtained
			continue
		else
			# Production cert is obtained, so we are done here.
			echo gluon-fast-acme.sh: Production certificate obtained. Exiting.
			gluon_set_cert_state obtained
			exit 0
		fi
	else
		gluon_set_cert_state error
	fi

	if gluon_is_staging; then
		# The "Failed Validations" limit of LetsEncrypt is 60 per hour. This
		# means one failure every minute. Here we wait 2 minutes to be within
		# limits for sure.
		sleeptime=120
	else
		# There is a "Failed Validation" limit of LetsEncrypt is 5 failures per
		# account, per hostname, per hour. This means one failure every 12
		# minutes. Here we wait 25 minutes to be within limits for sure.
		sleeptime=1500
	fi

	if [ "$ret" -eq 2 ] && ! gluon_is_staging; then
		# ret=2 means there was an error during the certificate issueing.

		echo gluon-fast-acme.sh: An error happened. Switching to staging server.
		uci set acme.gluon_cert.use_staging=1
		uci commit acme
	fi

	echo gluon-fast-acme.sh: Certificate could not be obtained. Retrying in $sleeptime seconds.
	sleep $sleeptime
done
