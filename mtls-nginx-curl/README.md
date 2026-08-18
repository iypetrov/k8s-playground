# mtls-nginx-curl

Mutual TLS (mTLS) is TLS where both sides present a certificate - the client
verifies the server and the server verifies the client, so only clients holding
a cert signed by a trusted CA are allowed to connect.

An nginx server accepts HTTPS only from clients whose cert is signed by our
self-signed CA. A `curl` pod holds a valid client cert and is used to exec in
and test the connection. All certs are generated with openssl into `certs/` and
mounted into the pods.

## Start

```bash
make kind-up                 # create the kind cluster
make generate-certificates   # generate CA/server/client certs + create Secrets
make generate-dummy-cert     # generate an untrusted client cert + Secret (for the failure test)
make mtls-up                 # install stakater/reloader and apply the manifests
make kind-down               # delete kind cluster when you are done
```

## Verify

Exec into the curl pod and hit nginx.

- Valid client cert → HTTP 200:
    ```bash
    kubectl exec deploy/curl-client -- curl -sS \
      --cacert /etc/curl/tls/ca.crt \
      --cert /etc/curl/tls/client.crt \
      --key /etc/curl/tls/client.key \
      https://nginx-server.default.svc.cluster.local
    # -> client cert OK: CN=curl-client
    ```

- No client cert → rejected:
    ```bash
    kubectl exec deploy/curl-client -- curl -sS \
      --cacert /etc/curl/tls/ca.crt \
      https://nginx-server.default.svc.cluster.local
    # -> 400 No required SSL certificate was sent
    ```

- Dummy (untrusted) client cert → rejected:
    ```bash
    kubectl exec deploy/curl-client -- curl -sS \
      --cacert /etc/curl/tls/ca.crt \
      --cert /etc/curl/dummy-tls/client.crt \
      --key /etc/curl/dummy-tls/client.key \
      https://nginx-server.default.svc.cluster.local
    # -> 400 The SSL certificate error
    ```
