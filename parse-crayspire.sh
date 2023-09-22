#!/bin/sh

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

info "Start parse-cray-spire"

if [ "$(getarg tpm=)" = "enable" ]; then
  tpm=enable
  export tpm
  warn "TPM is set to Enable"
  getarg xname= > /etc/cray/xname
else
  if [ "$(getarg tpm=)" = "enroll" ]; then
    tpm=enroll
    export tpm
    warn "TPM is set to Enroll"
    getarg xname= > /etc/cray/xname
  fi

  [ -z "$join_token" ] && join_token=$(getarg spire_join_token=)

  # token must be set
  if [ -z "$join_token" ]; then
    warn "The spire_join_token= parameter is not set. Spire will not be started".
    return 1
  fi

  export join_token
fi

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

info "End of parse-cray-spire"
