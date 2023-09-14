#!/bin/bash
set -euo pipefail

if [ "${TRANSACTIONALUPDATES}" = false ]; then
	systemctl disable transactional-update.timer transactional-update-cleanup.timer
	systemctl mask transactional-update.timer transactional-update-cleanup.timer
fi