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

# Find private key
pe "sudo strings /opt/consul/data/raft/raft.db /opt/consul/data/raft/snapshots/${LAST_SNAP}/state.bin| awk '/-----BEGIN EC PRIVATE KEY-----/ {flag=1;}; /-----END EC PRIVATE KEY-----/ {flag=0; print}; flag'"

# Get corresponding pub key
pe "sudo strings /opt/consul/data/raft/raft.db /opt/consul/data/raft/snapshots/${LAST_SNAP}/state.bin| awk '/-----BEGIN EC PRIVATE KEY-----/ {flag=1;}; /-----END EC PRIVATE KEY-----/ {flag=0; print}; flag' | openssl ec -text -noout 2>/dev/null  | awk '/^pub:/ {flag=1}; flag'"

# And compare to pub key in Root Connect CA cert
# we use demo-magic's 'p' instead of 'pe' here because for some reason with
# 'pe' and this command sed doesn't strip the leading spaces :shrug:
p "curl -s  http://127.0.0.1:8500/v1/agent/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -noout -text | awk '/pub:/ {flag=1}; /X509v3 extensions:/ {flag=0}; flag' | sed 's/^                //' "
curl -s  http://127.0.0.1:8500/v1/agent/connect/ca/roots | jq -r '.Roots[0].RootCert' | openssl x509 -noout -text | awk '/pub:/ {flag=1}; /X509v3 extensions:/ {flag=0}; flag' | sed 's/^                //' 

