#!/bin/bash
home_dir="/var/lib"
spire_rootdir="${home_dir}/spire"

info "Start cray-spire-pre-pivot"
info "newroot=${NEWROOT}"

# Copy the spire directory to the new root, so the agent can be re-started
# using the current data files.
killall spire-agent
cp -rp ${spire_rootdir} "${NEWROOT}${home_dir}"
cp -rp /var/lib/tpm-provisioner/* "${NEWROOT}/var/lib/tpm-provisioner/"

info "End cray-spire-pre-pivot"
