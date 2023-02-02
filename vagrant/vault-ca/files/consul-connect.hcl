# Copyright (c) HashiCorp, Inc
# SPDX-License-Identifier: MPL-2.0

connect {
  enabled = true
  ca_provider = "vault"
  ca_config {
    address = "http://127.0.0.1:8200"
    token = "%%VAULT_TOKEN%%"
    root_pki_path = "connect_dc_vault_ca_root"
    intermediate_pki_path = "connect_dc_vault_ca_inter"
    leaf_cert_ttl = "1h"
    root_cert_ttl = "6h"
    intermediate_cert_ttl = "3h"
  }
}
