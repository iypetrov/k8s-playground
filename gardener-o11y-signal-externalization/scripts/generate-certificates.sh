#!/usr/bin/env bash

set -e

_SCRIPT_NAME="${0##*/}"
_SCRIPT_DIR=$( dirname "$( readlink -f -- "${0}" )" )
_PROJECT_DIR="${_SCRIPT_DIR}/.."
_CERTS_DIR="${_SCRIPT_DIR}/../certs"
_CLICKSTACK_OTEL_COLLECTOR_PUB_DNS="otel-collector.clickstack.ip812.com"
_CLICKSTACK_OTEL_COLLECTOR_SVC_DNS="clickstack-otel-collector.clickstack.svc.cluster.local"

# Main entrypoint
function _main() {
    mkdir -p "${_CERTS_DIR}"

    # CA
    openssl req -x509 -newkey rsa:4096 -nodes -days 3650 \
        -keyout "${_CERTS_DIR}/ca.key" \
        -out "${_CERTS_DIR}/ca.crt" \
        -subj "/CN=otelcol-test-ca"

    # ClickStack server cert
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/clickstack-server.key" \
        -out "${_CERTS_DIR}/clickstack-server.csr" \
        -subj "/CN=clickstack-otel"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/clickstack-server.csr" \
        -out "${_CERTS_DIR}/clickstack-server.crt" \
        -CA "${_CERTS_DIR}/ca.crt" \
        -CAkey "${_CERTS_DIR}/ca.key" \
        -extfile <( printf "subjectAltName=DNS:%s,DNS:%s" "${_CLICKSTACK_OTEL_COLLECTOR_PUB_DNS}" "${_CLICKSTACK_OTEL_COLLECTOR_SVC_DNS}" )

    # ClickStack client cert
    openssl req -newkey rsa:4096 -nodes \
        -keyout "${_CERTS_DIR}/clickstack-client.key" \
        -out "${_CERTS_DIR}/clickstack-client.csr" \
        -subj "/CN=gardener-shoot-otelcol"
    openssl x509 -req -CAcreateserial -days 825 \
        -in "${_CERTS_DIR}/clickstack-client.csr" \
        -out "${_CERTS_DIR}/clickstack-client.crt" \
        -CA "${_CERTS_DIR}/ca.crt" \
        -CAkey "${_CERTS_DIR}/ca.key"

    # Clean up intermediate artifacts; the certs and keys are all we need.
    rm -rf "${_CERTS_DIR}"/*.csr "${_CERTS_DIR}"/ca.srl
}

_main "$@"
