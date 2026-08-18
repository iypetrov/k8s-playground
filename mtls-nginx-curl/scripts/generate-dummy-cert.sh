#!/usr/bin/env bash

# Generate a "dummy" client cert that is NOT signed by our trusted CA.
# nginx has `ssl_verify_client on` and only trusts certs/ca.crt, so presenting
# this cert must fail the mTLS handshake — use it to prove verification works.

set -e

_SCRIPT_DIR=$( dirname "$( readlink -f -- "${0}" )" )
_CERTS_DIR="${_SCRIPT_DIR}/../certs"

function _main() {
    mkdir -p "${_CERTS_DIR}"

    # A rogue CA, unrelated to the one nginx trusts.
    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -keyout "${_CERTS_DIR}/dummy-ca.key" \
        -out "${_CERTS_DIR}/dummy-ca.crt" \
        -subj "/CN=dummy-ca"

    # Client cert signed by the rogue CA.
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/dummy-client.key" \
        -out "${_CERTS_DIR}/dummy-client.csr" \
        -subj "/CN=dummy-client"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/dummy-client.csr" \
        -out "${_CERTS_DIR}/dummy-client.crt" \
        -CA "${_CERTS_DIR}/dummy-ca.crt" \
        -CAkey "${_CERTS_DIR}/dummy-ca.key"

    rm -rf "${_CERTS_DIR}"/*.csr "${_CERTS_DIR}"/dummy-ca.srl

    echo "Load it into the curl-client pod with:"
    echo "  kubectl create secret generic dummy-client-tls \\"
    echo "    --from-file=client.crt=${_CERTS_DIR}/dummy-client.crt \\"
    echo "    --from-file=client.key=${_CERTS_DIR}/dummy-client.key \\"
    echo "    --dry-run=client -o yaml | kubectl apply -f -"
}

_main "$@"
