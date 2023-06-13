#!/bin/bash
info "Start cray-spire-mdserver-finished"

spire_rootdir="/var/lib/spire"

# prevent recreating config file if the agent is already running
if [[ -S ${spire_rootdir}/agent.sock ]]; then
  warn "Spire agent is already running. Will not recreate spire-agent.conf file"
  return 0
fi

# mdserver_endpoint is set by parse-crayspire-mdserver.
if [[ -z $mdserver_endpoint ]]; then
  warn "mdserver_endpoint is not set. Unable to generate SPIRE Agent config file."
  return 0
fi

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

# Populate the spire configuration file
if [[ $tpm == "enable" ]]; then
  /usr/bin/tpm-blob-retrieve
  warn "Retrieved tpm blob: $(ls /var/lib/tpm-provisioner)"
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

else
  cat << EOF > ${spire_rootdir}/conf/spire-agent.conf
agent {
  data_dir = "${spire_rootdir}"
  log_level = "INFO"
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
fi

info "End cray-spire-mdserver-finished"
