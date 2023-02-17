# Why You Should Use Vault as Your Consul Certificate Authority

Presented at [HashiTalks 2023](https://www.youtube.com/watch?v=PnuTD3pKfH0)

## Demo Environments

During the presentation, two demo environments are used which are based on 
[Vagrant](https://www.vagrantup.com/): `consul-ca` and `vault-ca`, which 
are environments where the built-in ConsuL CA and an external Vault CA are
used, respectively. These are located in the `vagrant` folder. The 
`vagrant/common` directory includes files which are the same to both
environments.

You can start a given environment by navigating to the `vagrant/consul-ca`
or `vagrant/vault-ca` directories, and running `vagrant up`. Once provisioning
is done, `vagrant ssh` will get you into the environment.

Within each demo environment is a [`screen(1)`](https://www.gnu.org/software/screen/)
session which can be attached by running `screen -d -r demo`. You will not need to
know `screen` to run this demo as you'll be in the proper window to run the 
demonstration, but briefly `<Cntl-a> 0` will switch to window 0, `<Cntl-a> 1` will
switch to window 1, etc.

In `consul-ca` there are two windows:

0. The Consul server process
1. The demo

In `vault-ca` there are three windows:

0. The Consul server process
1. The Vault server process
2. The demo

The demo uses [`demo-magic`](https://github.com/paxtonhare/demo-magic) to
"type" for you, you hit `<enter>` or `<return>` to step through the demonstration.

## Consul Demo

1. Ask Consul for the Consul Root CA certificate, with special attention being paid
to the public key section.
2. Consul stores its entire state in a [Raft](https://developer.hashicorp.com/consul/docs/architecture/consensus)
log and some number of potential snapshots; the latest snapshot plus the Raft log
hold everything on Consul which doens't live in server configuration files. If we
use the built-in Consul CA, that CA certificates and keys live in the Raft state.
In Consul's use, there's a `raft.db` file, and within snapshots, a `state.bin` file,
which we show.
3. We do need to know the format of thoses files (and in fact, during the presentation
we don't care), rather, we simply brute force use `strings` to search for stuff which
*looks* like a private key, which we find.
4. But while we have something which is a private key, we don't know, yet, what it is
used for. We can use an `openssl` command to print out the public key for that private
key we found. Remember, there is a one-to-one mapping between public and private keys:
a given private key has one and only one public key, and that public key belongs to one
and only one private key. If we find one, we know it corresponds to the other.
5. So that's what the demo does, shows that the public key of the private key we found
in the Consul Raft state matches exactly the public key embedded in the Consul Root CA
certificate, which means we have found the private key used to ultimately sign all 
paths of trust within the Consul Service Mesh and the certificates it uses.

## Vault Demo
1. Starts off much like the Consul Demo, asking for the Consul Root CA certificate.
2. We trawl through the Consul Raft state, but this time, we do not find anything 
which looks like a private key. This makes sense, because by selecting Vault as the
Consul CA, all of the certificate operations are handled by Vault, and all of the
keying material lives in Vault.
3. But how does Vault store that key? We make a series of Vault API calls to gather
some information: given a PKI secret mount point (which Consul uses) we find that
there is only one issuer, which means there's XXX set of keyXXX which will sign
certificates in that mount point. With the UUID of the PKI secret mount point, we can
ask Vault to show us some internal state.
4. This part of the demonstration uses the Vault [`sys/raw`](https://developer.hashicorp.com/vault/api-docs/system/raw)
endpoint, which is off by default in a Vault deployment, for very good reason. The `sys/raw`
endpoint allows data to escape Vault's [encryption barrier](https://developer.hashicorp.com/vault/docs/concepts/seal).
So not only do you have to explicitly enable this endpoint in a Vault server, but you are
also required to supply a highly-privileged Vault token. We do this to show that the 
private key is in fact in Vault's storage, and later on try to find it unencrypted on disk.
You are not expected to know what these raw paths in Vault's storage backend are, but if
you dig through the [Vault PKI Engine Source Code](https://github.com/hashicorp/vault/tree/main/builtin/logical/pki)
you can figure out where things are stored.
5. Each certificate issuer in Vault has a configuration, part of which is a `key_id` for
the actual key used for signing operations. Once we have the `key_id` we know where to look
for data about that key, including the private key. We then demonstrate, much like we did
in the Consul CA demo, that this key corresponds to the Consul Root CA certificate public
key, which means we've found that certificate's private key.
6. But we had to take very special effort to get Vault to tell us that information, using
a highly-privileged Vault token and a special Vault API endpoint which is disabled by default.
What can we do if we look in Vault's underlying physical storage? In this demo environment we
have configured Vault to store data on the local disk, and given the raw path in Vault's
storage backend we can translate that to the path on disk in which that data is stored. When
we look at it, we see that it is a bit of JSON with one key, `Value`. We do a few things to
look at it, base64 decoding it, finding that it looks like a binary blob of data. In case we're
being tricky we ask openssl to decode it as if it were a DER-encoded key blob, but it isn't. We're
unsuccessful because of Vault's encryption barrier: all data Vault persists in storage goes through
that encrypted barrier, so everything stored in durable storage is encrypted. Reading that data
requires access to the keying material required to [unseal a Vault server](https://developer.hashicorp.com/vault/docs/concepts/seal#unsealing).
