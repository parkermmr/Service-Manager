#!/bin/bash
set -e

CA_DIRECTORY="$HOME/.prometheus/authority"
CERTIFICATES="$HOME/.prometheus/certificates"
mkdir -p $CA_DIRECTORY $CERTIFICATES $CERTIFICATES/server $CERTIFICATES/client

echo '
# Server Certificate Extension File
# Edit this file to customize your server certificate

basicConstraints                   = CA:FALSE
nsCertType                         = server
nsComment                          = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier               = hash
authorityKeyIdentifier             = keyid,issuer:always
keyUsage                           = critical, digitalSignature, keyEncipherment
extendedKeyUsage                   = serverAuth
subjectAltName                     = @alt_names

[alt_names]
# REQUIRED: Minimum 2 DNS names for server certificates
DNS.1 = localhost
DNS.2 = localhost

# Optional: Add IP addresses
IP.1  = 0.0.0.0
# IP.2  = 10.0.0.50
' > $CERTIFICATES/server/server.ext

if [[ ! -d "$CA_DIRECTORY" ]] || [[ -z "$(ls -A "$CA_DIRECTORY")" ]]; then
    CA_DIR="$CA_DIRECTORY" generate-certs --setup-ca
fi

CA_DIR=$CA_DIRECTORY generate-certs --service server --type server --output $CERTIFICATES/server --cleanup
CA_DIR=$CA_DIRECTORY generate-certs --service client --type client --output $CERTIFICATES/client --cleanup