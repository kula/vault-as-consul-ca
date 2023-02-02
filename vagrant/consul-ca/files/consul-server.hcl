# Copyright (c) HashiCorp, Inc
# SPDX-License-Identifier: MPL-2.0

datacenter = "dc-consul-ca"
data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
ui_config{
  enabled = true
}
server = true

bind_addr = "0.0.0.0" # Listen on all IPv4
bootstrap_expect=1
connect {
  enabled = true
  ca_provider = "consul"
}
ports {
  grpc = 8502
}

# This is done so we quickly create a Raft snapshot
raft_snapshot_threshold = 256
raft_trailing_logs = 32

pid_file = "/opt/consul/consul-server.pid"
