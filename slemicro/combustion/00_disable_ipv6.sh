#!/bin/bash
set -euo pipefail

if [ "${DISABLEIPV6}" = true ]; then
	# https://www.suse.com/support/kb/doc/?id=000016980
	cat <<- EOF > /etc/sysctl.d/disable-ipv6.conf
	net.ipv6.conf.all.disable_ipv6 = 1
	net.ipv6.conf.default.disable_ipv6 = 1
	net.ipv6.conf.lo.disable_ipv6 = 1
	EOF

	echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
fi
