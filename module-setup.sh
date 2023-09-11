#!/bin/bash
spire_rootdir="/var/lib/spire"

# called by dracut
check() {
  return 0
}

# called by dracut
depends() {
  echo network
  return 0
}

# called by dracut
install() {
  inst_hook cmdline 19 "$moddir/parse-crayspire-mdserver.sh"
  inst_hook cmdline 20 "$moddir/parse-crayspire.sh"
  inst_hook initqueue/finished 20 "$moddir/cray-spire-mdserver-finished.sh"
  inst_hook initqueue/finished 21 "$moddir/cray-spire-finished.sh"
  inst_hook emergency 20 "$moddir/cray-dump-spire-log.sh"
  inst_hook pre-pivot 20 "$moddir/cray-spire-pre-pivot.sh"
  inst /usr/bin/killall
  inst /usr/bin/spire-agent
  inst /usr/bin/curl
  inst /usr/bin/jq
  inst /usr/bin/sleep
  inst ${spire_rootdir}/bundle/bundle.crt
  inst ${spire_rootdir}/conf/spire-agent.conf
  inst ${spire_rootdir}/data
  if [[ -f /etc/opt/cray/cos/cos-config ]]; then
    # spire and all API GW needs COS config to pickup API GW hostname
    inst /etc/opt/cray/cos/cos-config
  fi
}
