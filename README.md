# cray-spire-dracut

SPIRE is an implementation of the SPIFFE APIs that performs node and workload
attestation in order to securely issue SVIDs to workloads, and verify the SVIDs
of other workloads, based on a predefined set of conditions.

This is a dracut module that starts the spire-agent for use while running in the
initrd. After the root filesystem is mounted, and before pivot, the data files
are copied to the root filesystem for use there.

NOTE: COS config file /etc/opt/cray/cos/cos-config is installed from here to
make sure that spire and other API GW access can pickup configuration data such
as API GW hostname and spire agent version.

## Usage

The following items are parsed from the boot parameters

- `spire_join_token=${SPIRE_JOIN_TOKEN}`
- `ds=nocloud-net;s=http://metadata-server:8888/`
