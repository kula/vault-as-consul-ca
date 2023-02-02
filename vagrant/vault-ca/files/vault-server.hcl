# Copyright (c) HashiCorp, Inc
# SPDX-License-Identifier: MPL-2.0

storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = "true"
}

ui = "true"
api_addr = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
pid_file = "/opt/vault/vault.pid"
raw_storage_endpoint = "true"
