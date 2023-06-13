#!/bin/sh

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

info "Start parse-cray-spire-mdserver"

[ -z "$cloud_mdserver" ] && cloud_mdserver=$(getarg ds=)

# ds=nocloud-net;key=value where value == URL for the metadata server
# This string parser assumes that the metadata server will be the last
# option on the cloud-init 'ds=' string. Currently it is the only one.
[ -z "$mdserver_endpoint" ] && mdserver_endpoint=${cloud_mdserver##*=} && mdserver_endpoint=${mdserver_endpoint%/}

if [ -z "$mdserver_endpoint" ]; then
  warn "The ds= parameter is not set. Spire Agent configuration cannot be determined."
  return 1
fi

export mdserver_endpoint

info "End parse-cray-spire-mdserver"
