#!/bin/bash
home_dir="/var/lib"
spire_rootdir="${home_dir}/spire"

info "Start cray-spire-pre-pivot"
info "newroot=${NEWROOT}"

# Copy the spire directory to the new root, so the agent can be re-started
# using the current data files.
killall spire-agent
cp -rp ${spire_rootdir} "${NEWROOT}${home_dir}"
if [[ -f /var/lib/tpm-provisioner/devid.crt.pem || -f /var/lib/tpm-provisioner/devid.priv.blob || -f /var/lib/tpm-provisioner/devid.pub.blob ]]; then
  cp -rp /var/lib/tpm-provisioner/* "${NEWROOT}/var/lib/tpm-provisioner/"
fi

info "End cray-spire-pre-pivot"
