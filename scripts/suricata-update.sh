#!/bin/sh

SURI=$(pidof Suricata-Main 2>/dev/null)

if [ ! "$SURI" ]; then
  exit
fi

suricata-update --fail --no-test || exit $?
/usr/sbin/ips-rule-policy.sh || exit $?
# suricata-update --fail --no-test || exit $?

kill -USR2 $SURI
