#!/bin/bash
# Set the rootdir used for all spire related config
spire_rootdir="/var/lib/spire"

# Get metadata from the spire server
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
rm -f /tmp/spire_bundle

waitforspire() {
  RETRY=0
  MAX_RETRIES=30
  RETRY_SECONDS=5

  until /opt/cray/cray-spire/spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock; do
    if [[ $RETRY -lt $MAX_RETRIES ]]; then
      RETRY="$((RETRY + 1))"
      warn "spire-agent is not ready. Will retry after $RETRY_SECONDS seconds. ($RETRY/$MAX_RETRIES)"
    else
      error "spire-agent did not start after $(echo "$RETRY_SECONDS" \* "$MAX_RETRIES" | bc) seconds."
      exit 1
    fi
    sleep "$RETRY_SECONDS"
  done
}

spirehealth() {
  /opt/cray/cray-spire/spire-agent healthcheck -socketPath ${spire_rootdir}/agent.sock
  r=$?
  if [[ $r -ne 0 ]]; then
    warn "Spire-agent healthcheck failed, return code $r"
    return 1
  else
    info "Spire-agent healthcheck passed"
    return 0
  fi
  return 1
}

info "Start cray-spire-finished"

# prevent starting again if the agent is already running
if [[ -S ${spire_rootdir}/agent.sock ]]; then
  info "Spire agent is running"
  spirehealth
  return $?
fi

# $join_token will be set by parse-crayspire. It holds the join token.
if [[ -n $join_token ]]; then
  # this will be used by the spire-agent systemd unit file
  echo join_token="$join_token" > "${spire_rootdir}/conf/join_token"
  if [[ ! -d ${spire_rootdir}/data ]]; then
    mkdir ${spire_rootdir}/data
  fi

  # Setup the spire config
  cat << EOF > ${spire_rootdir}/conf/spire-agent.conf
agent {
  data_dir = "${spire_rootdir}"
  log_level = "WARN"
  server_address = "${spire_server}"
  server_port = "8081"
  socket_path = "${spire_rootdir}/agent.sock"
  trust_bundle_path = "${spire_rootdir}/bundle/bundle.crt"
  trust_domain = "${spire_domain}"
  join_token = "\$join_token"
}

plugins {
  NodeAttestor "join_token" {
    plugin_data {}
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

  # run chronyd for one time sync before starting spire-agent
  /usr/sbin/chronyd -q
  r=$?
  if [[ $r -ne 0 ]]; then
    # Warning only for chronyd failure, since clock might be okay, try
    # running spire-agent.
    warn "Chronyd failed to sync time before starting Spire-agent $r"
  fi

  # Start the spire agent
  /opt/cray/cray-spire/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  # Wait for spire agent to start and check for spire health
  waitforspire
  spirehealth

elif { [ "$tpm" = "enable" ]; }; then
  # run chronyd for one time sync before starting spire-agent
  if ! /usr/sbin/chronyd -q; then
    # Warning only for chronyd failure, since clock might be okay, try
    # running spire-agent.
    warn "Chronyd failed to sync time before starting Spire-agent"
  fi

  # Setup the spire config
  mkdir /var/lib/tpm-provisioner
  /usr/bin/tpm-blob-retrieve
  info "Retrieved tpm blob: $(ls /var/lib/tpm-provisioner)"
  cat << EOF > ${spire_rootdir}/conf/spire-agent.conf
agent {
  data_dir = "${spire_rootdir}"
  log_level = "WARN"
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

  # Start the spire agent
  /opt/cray/cray-spire/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  # Wait for spire agent to start and check for health
  waitforspire
  spirehealth
else
  warn "join_token and tpm enable are not set"
fi

if { [ "$tpm" = "enroll" ]; }; then
  info "Enrolling TPM on Spire"
  mkdir /var/lib/tpm-provisioner
  /opt/cray/cray-spire/tpm-provisioner-client
  /usr/bin/tpm-blob-clear
  /usr/bin/tpm-blob-store

  killall spire-agent

  # Setup the spire-agent config
  cat << EOF > ${spire_rootdir}/conf/spire-agent.conf
agent {
  data_dir = "${spire_rootdir}"
  log_level = "WARN"
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

  # Start the spire agent
  /opt/cray/cray-spire/spire-agent run -expandEnv \
    -config ${spire_rootdir}/conf/spire-agent.conf &

  # Wait for spire agent to start and check for health
  waitforspire
  spirehealth
fi

info "End cray-spire-finished"
