#!/usr/bin/env bash

set -e

_SCRIPT_NAME="${0##*/}"
_SCRIPT_DIR=$( dirname "$( readlink -f -- "${0}" )" )
_PROJECT_DIR="${_SCRIPT_DIR}/.."
_CERTS_DIR="${_SCRIPT_DIR}/../certs"
_NGINX_SAN="DNS:nginx-server,DNS:nginx-server.default.svc,DNS:nginx-server.default.svc.cluster.local"

# Main entrypoint
function _main() {
    mkdir -p "${_CERTS_DIR}"

    # CA
    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -keyout "${_CERTS_DIR}/ca.key" \
        -out "${_CERTS_DIR}/ca.crt" \
        -subj "/CN=mtls-nginx-ca"

    # nginx server cert
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/nginx-server.key" \
        -out "${_CERTS_DIR}/nginx-server.csr" \
        -subj "/CN=nginx-server"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/nginx-server.csr" \
        -out "${_CERTS_DIR}/nginx-server.crt" \
        -CA "${_CERTS_DIR}/ca.crt" \
        -CAkey "${_CERTS_DIR}/ca.key" \
        -extfile <( printf "subjectAltName=%s" "${_NGINX_SAN}" )

    # curl client cert
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/curl-client.key" \
        -out "${_CERTS_DIR}/curl-client.csr" \
        -subj "/CN=curl-client"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/curl-client.csr" \
        -out "${_CERTS_DIR}/curl-client.crt" \
        -CA "${_CERTS_DIR}/ca.crt" \
        -CAkey "${_CERTS_DIR}/ca.key"

    # Clean up intermediate artifacts; the certs and keys are all we need.
    rm -rf "${_CERTS_DIR}"/*.csr "${_CERTS_DIR}"/ca.srl
}

_main "$@"
