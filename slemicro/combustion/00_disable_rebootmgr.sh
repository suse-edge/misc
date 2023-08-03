#!/bin/bash
set -euo pipefail

if [ "${REBOOTMGR}" = false ]; then
	sed -ie 's/strategy=best-effort/strategy=off/g' /etc/rebootmgr.conf
	systemctl disable rebootmgr
	systemctl mask rebootmgr
fi