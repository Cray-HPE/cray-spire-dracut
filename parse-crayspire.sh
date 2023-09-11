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

info "End of parse-cray-spire"
