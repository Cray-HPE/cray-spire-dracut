#!/bin/bash
spire_rootdir="/var/lib/spire"

waitforspire() {
  RETRY=0
  MAX_RETRIES=30
  RETRY_SECONDS=5

  until spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock; do
    if [[ $RETRY -lt $MAX_RETRIES ]]; then
      RETRY="$((RETRY + 1))"
      echo "spire-agent is not ready. Will retry after $RETRY_SECONDS seconds. ($RETRY/$MAX_RETRIES)"
    else
      echo "spire-agent did not start after $(echo "$RETRY_SECONDS" \* "$MAX_RETRIES" | bc) seconds."
      exit 1
    fi
    sleep "$RETRY_SECONDS"
  done
}


info "Start cray-spire-finished"

flag=/tmp/spire-message # flag for printing pass message only once
if [[ ! -f $flag ]]; then
  echo unknown > $flag
fi

# prevent starting again if the agent is already running
if [[ -S ${spire_rootdir}/agent.sock ]]; then
  info "Spire agent is running"
  # check that the spire agent is responding
  spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock
  r=$?
  if [[ $r -ne 0 ]]; then
    warn "Spire-agent healthcheck failed, return code $r"
    echo fail > $flag
  else
    if [[ $(< $flag) != pass ]]; then
      info "Spire-agent healthcheck passed"
      echo pass > $flag
    fi
  fi
  return $r
fi

# $join_token will be set by parse-crayspire. It holds the join token.
if [[ -n $join_token ]]; then
  # this will be used by the spire-agent systemd unit file
  echo join_token="$join_token" > "${spire_rootdir}/conf/join_token"
  if [[ ! -d ${spire_rootdir}/data ]]; then
    mkdir ${spire_rootdir}/data
  fi

  # run chronyd for one time sync before starting spire-agent
  /usr/sbin/chronyd -q
  r=$?
  if [[ $r -ne 0 ]]; then
    # Warning only for chronyd failure, since clock might be okay, try
    # running spire-agent.
    warn "Chronyd failed to sync time before starting Spire-agent $r"
  fi

  /usr/bin/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  waitfo-spire
  if spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock; then
    if [[ $(< $flag) != pass ]]; then
      info "Spire-agent healthcheck passed"
      echo pass > $flag
    else
      warn "Spire-agent healthcheck failed, return code $r"
      echo fail > $flag
    fi
  fi

elif [ "$tpm" = "enable" ]; then
  # run chronyd for one time sync before starting spire-agent
  if ! /usr/sbin/chronyd -q; then
    # Warning only for chronyd failure, since clock might be okay, try
    # running spire-agent.
    warn "Chronyd failed to sync time before starting Spire-agent $r"
  fi

  /usr/bin/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  wait-for-spire
  if spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock; then
    if [[ $(< $flag) != pass ]]; then
      info "Spire-agent healthcheck passed"
      echo pass > $flag
    else
      warn "Spire-agent healthcheck failed, return code $r"
      echo fail > $flag
    fi
  fi
else
  warn "join_token and tpm enable are not set"
fi

if [ "$tpm" = "enroll" ]; then
  info "Enrolling TPM on Spire"
  /usr/bin/tpm-provisioner
  /usr/bin/tpm-blob-clear
  /usr/bin/tpm-blob-store

  killall spire-agent

  # Set spire home
  spire_rootdir="/var/lib/spire"

  ret=$(curl -s -k -o /tmp/spire_bundle -w "%{http_code}" "${mdserver_endpoint}/meta-data")
  if [[ $ret == "200" ]]; then
    spire_domain=$(jq -Mcr '.Global.spire.trustdomain' < /tmp/spire_bundle)
    spire_server=$(jq -Mcr '.Global.spire.fqdn' < /tmp/spire_bundle)
    # Insert root certificate into bundle.crt
    jq -Mcr '.Global."ca-certs".trusted[0]' > ${spire_rootdir}/bundle/bundle.crt < /tmp/spire_bundle
  else
    warn "Unable to retrieve metadata from server"
    return 1
  fi

  cat << EOF > ${spire_rootdir}/conf/spire-agent.conf
agent {
  data_dir = "${spire_rootdir}"
  log_level = "INFO"
  server_address = "${spire_server}"
  server_port = "8081"
  socket_path = "${spire_rootdir}/agent.sock"
  trust_bundle_path = "${spire_rootdir}/bundle/bundle.crt"
  trust_domain = "${spire_domain}"
}

plugins {
  NodeAttestor "tpm_devid" {
    plugin_data {
      devid_cert_path = "/var/lib/tpm-provisioner/devid.crt.pem"
      devid_priv_path = "/var/lib/tpm-provisioner/devid.priv.blob"
      devid_pub_path = "/var/lib/tpm-provisioner/devid.pub.blob"
    }
  }

  KeyManager "disk" {
    plugin_data {
        directory = "${spire_rootdir}/data"
    }
  }

  WorkloadAttestor "unix" {
    plugin_data {
        discover_workload_path = true
    }
  }
}
EOF

  /usr/bin/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  wait-for-spire
  if spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock; then
  if [[ $r -ne 0 ]]; then
    if [[ $(< $flag) != pass ]]; then
      info "Spire-agent healthcheck passed"
      echo pass > $flag
    fi
  else
    warn "Spire-agent healthcheck failed, return code $r"
    echo fail > $flag
  fi
fi

info "End cray-spire-finished"
return $r
