#!/bin/bash

# Create a temp dir to host the assets
TMPDIR=$(mktemp -d)

# Create required folders
mkdir -p ${TMPDIR}/{combustion,ignition}

# Copy the combustion script
cp script ${TMPDIR}/combustion/script

# Convert the config.fcc yaml file to ignition
butane -p -o ${TMPDIR}/ignition/config.ign config.fcc

# Create an iso
mkisofs -full-iso9660-filenames -o ignition-and-combustion.iso -V ignition ${TMPDIR}

# Remove leftovers
rm -Rf ${TMPDIR}
