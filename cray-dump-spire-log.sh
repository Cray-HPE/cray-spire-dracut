#!/bin/bash
# cray-dump-spire-log - A simple script to pull the spire log
# dump it to the console in the initramfs environment. To aid in debugging.

spire_rootdir="/var/lib/spire"

if [[ -f ${spire_rootdir}/spire-agent.log ]]; then
  while read -r line; do
    echo "$line" > /dev/kmsg
  done < ${spire_rootdir}/spire-agent.log
fi
