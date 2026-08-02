#!/usr/bin/env bash

env | grep '^CNI_' >> /var/log/foo-cni.log 2>&1
echo >> /var/log/foo-cni.log 2>&1

# Report a minimal valid result back to the CRI.
echo '{"cniVersion":"1.0.0"}'
