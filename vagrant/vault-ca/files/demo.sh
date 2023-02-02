#!/bin/bash

# Copyright (c) HashiCorp, Inc
# SPDX-License-Identifier: MPL-2.0

# Include demo-magic

. /home/vagrant/.demo/demo-magic.sh
export TYPE_SPEED=100

clear

# Consul: Examine Root Certificate
pe "curl -s  http://127.0.0.1:8500/v1/agent/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -noout -text"

# Dig through consul raft log and snapshot for useful things
pe "clear"
pe "ls -l /opt/consul/data/raft/raft.db"
pe "ls -ltr /opt/consul/data/raft/snapshots/"

# Find last snapshot
LAST_SNAP=$(ls /opt/consul/data/raft/snapshots/ | sort | tail -1)
pe "ls -l /opt/consul/data/raft/snapshots/${LAST_SNAP}"
pe "sudo strings /opt/consul/data/raft/raft.db /opt/consul/data/raft/snapshots/${LAST_SNAP}/state.bin| awk '/-----BEGIN EC PRIVATE KEY-----/ {flag=1;}; /-----END EC PRIVATE KEY-----/ {flag=0; print}; flag'"
pe "clear"

# Private Key in Consul?
PKEY=$(sudo strings /opt/consul/data/raft/raft.db /opt/consul/data/raft/snapshots/${LAST_SNAP}/state.bin| awk '/-----BEGIN EC PRIVATE KEY-----/ {flag=1;}; /-----END EC PRIVATE KEY-----/ {flag=0; print}; flag')

# Look in Vault
# We only have one issuer
ISSUER=$(curl -s --header "X-Vault-Token ${VAULT_TOKEN}" --request LIST http://127.0.0.1:8200/v1/connect_dc_vault_ca_root/issuers | jq -r .data.keys[0])
pe 'curl -s --header "X-Vault-Token ${VAULT_TOKEN}" --request LIST http://127.0.0.1:8200/v1/connect_dc_vault_ca_root/issuers | jq -r .'

# Get mountpoint uuid
ROOT_PKI_UUID=$(vault secrets list -format json | jq -r '."connect_dc_vault_ca_root/".uuid')
pe "vault secrets list -format json | jq -r '.\"connect_dc_vault_ca_root/\".uuid'"

# Get issuer key id
ISSUER_KEYID=$(curl -s --header "X-Vault-Token: ${VAULT_TOKEN}"  http://127.0.0.1:8200/v1/sys/raw/logical/${ROOT_PKI_UUID}/config/issuer/${ISSUER} | jq -r .data.value | jq -r .key_id)
pe "curl -s --header \"X-Vault-Token: ${VAULT_TOKEN}\"  http://127.0.0.1:8200/v1/sys/raw/logical/${ROOT_PKI_UUID}/config/issuer/${ISSUER} | jq -r .data.value | jq -r ."

# Read key
pe "curl -s --header \"X-Vault-Token: ${VAULT_TOKEN}\" http://127.0.0.1:8200/v1/sys/raw/logical/${ROOT_PKI_UUID}/config/key/${ISSUER_KEYID} | jq -r .data.value | jq -r .private_key"

# Decode
pe "curl -s --header \"X-Vault-Token: ${VAULT_TOKEN}\" http://127.0.0.1:8200/v1/sys/raw/logical/${ROOT_PKI_UUID}/config/key/${ISSUER_KEYID} | jq -r .data.value | jq -r .private_key | openssl ec -text -noout | awk \"/pub:/ { flag=1 }; flag\""

# And compare to pub key in Root Connect CA cert
# we use demo-magic's 'p' instead of 'pe' here because for some reason with
# 'pe' and this command sed doesn't strip the leading spaces :shrug:
p "curl -s  http://127.0.0.1:8500/v1/agent/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -noout -text | awk '/pub:/ {flag=1}; /X509v3 extensions:/ {flag=0}; flag' | sed 's/^                //' "
curl -s  http://127.0.0.1:8500/v1/agent/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -noout -text | awk '/pub:/ {flag=1}; /X509v3 extensions:/ {flag=0}; flag' | sed 's/^                //'

# But look in Vault's storage
pe "sudo jq -r . /opt/vault/data/logical/${ROOT_PKI_UUID}/config/key/_${ISSUER_KEYID}"
pe "sudo jq -r .Value /opt/vault/data/logical/${ROOT_PKI_UUID}/config/key/_${ISSUER_KEYID} | base64 -d | od -c "
pe "sudo jq -r .Value /opt/vault/data/logical/${ROOT_PKI_UUID}/config/key/_${ISSUER_KEYID} | base64 -d  | openssl ec -text -noout -inform DER "

# We start this as a command in screen, run bash to leave us at an interactive shell
/bin/bash
