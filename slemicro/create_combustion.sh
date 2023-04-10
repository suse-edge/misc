#!/bin/bash
set -euo pipefail

die(){
  echo ${1}
  exit ${2}
}

# Get the env
source .env

# Check if EMAIL and REGCODE variables are empty
[ -z "${EMAIL}" ] && die "EMAIL variable not found" 2
[ -z "${REGCODE}" ] && die "REGCODE variable not found" 2

# Create a temp dir to host the assets
TMPDIR=$(mktemp -d)

# Create required folders
mkdir -p ${TMPDIR}/{combustion,ignition}

# Copy the combustion script
envsubst < script > ${TMPDIR}/combustion/script

# Convert the config.fcc yaml file to ignition
butane -p -o ${TMPDIR}/ignition/config.ign config.fcc

# Create an iso
mkisofs -full-iso9660-filenames -o ignition-and-combustion.iso -V ignition ${TMPDIR}

# Remove leftovers
rm -Rf ${TMPDIR}
