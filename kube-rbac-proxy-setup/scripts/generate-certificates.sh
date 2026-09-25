#!/usr/bin/env bash

set -e

_SCRIPT_NAME="${0##*/}"
_SCRIPT_DIR=$( dirname "$( readlink -f -- "${0}" )" )
_PROJECT_DIR="${_SCRIPT_DIR}/.."
_CERTS_DIR="${_SCRIPT_DIR}/../certs"

# Main entrypoint
function _main() {
    mkdir -p "${_CERTS_DIR}"

    # CA
    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -keyout "${_CERTS_DIR}/ca.key" \
        -out "${_CERTS_DIR}/ca.crt" \
        -subj "/CN=kube-rbac-proxy-setup-ca"

    # CERT & KEY
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/server.key" \
        -out "${_CERTS_DIR}/server.csr" \
        -subj "/CN=otel-receiver"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/server.csr" \
        -out "${_CERTS_DIR}/server.crt" \
        -CA "${_CERTS_DIR}/ca.crt" \
        -CAkey "${_CERTS_DIR}/ca.key" \
        -extfile <(printf "subjectAltName=DNS:otel-receiver.experiment.svc.cluster.local,DNS:otel-receiver.experiment.svc,DNS:localhost")
    rm -rf "${_CERTS_DIR}"/*.csr "${_CERTS_DIR}"/ca.srl
}

_main "$@"
