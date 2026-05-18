# Description

This role deploys an Ethereum [validator client](https://nimbus.guide/validator-client.html) written by [Nimbus Team](https://nimbus.team/) that should run together with a [beacon node](https://nimbus.guide/quick-start.html).

# Introduction

The role will:

* Checkout a branch from the [nimbus-eth2](https://github.com/status-im/nimbus-eth2) repo
* Build it using the [`build.sh`](./templates/scripts/build.sh.j2) Bash script
* Schedule regular builds using [Systemd timers](https://www.freedesktop.org/software/systemd/man/systemd.timer.html)
* Start a node by defining a [Systemd service](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

# Ports

The service exposes three ports by default:

* `5052` - Keymanager API port. Must __NEVER__ be public.
* `8108` - Prometheus metrics port. Should not be public.

# Installation

Add to your `requirements.yml` file:
```yaml
- name: infra-role-validator-client
  src: git+git@github.com:status-im/infra-role-validator-client.git
  scm: git
```

# Configuration

The crucial settings are:
```yaml
validator_client_service_name: 'validator-client-{{ validator_client_network }}-{{ validator_client_network }}'
validator_client_network: 'mainnet'
validator_client_repo_branch: 'stable'
validator_client_beacon_node_url: ['http://127.0.0.1:5052']
validator_client_suggested_fee_recipient: '0xChangeMeToAddrThatWillReceiveTrasnactionFeeRewards'
```
You might want to change logging level or enable payload builder if beacon node has it:
```yaml
validator_client_log_level: 'INFO'
validator_client_payload_builder_enabled: true
```
To enable the keymanager API a token needs to be specified.
```yaml
validator_client_keymanager_enabled: true
validator_client_keymanager_token: '{{lookup("bitwarden", "nimbus/keymanager", field="token")}}'
```

# Management

## Service

Assuming the `stable` branch was built you can manage the service with:
```sh
sudo systemctl start validator-client-mainnet-stable
sudo systemctl status validator-client-mainnet-stable
sudo systemctl stop validator-client-mainnet-stable
```
You can view logs under:
```sh
tail -f /data/validator-client-mainnet-stable/logs/service.log
```
All node data is located in `/data/validator-client-mainnet-stable/data`.

## Builds

A timer will be installed to build the image:
```sh
 > sudo systemctl list-units --type=service '*validator-client-*'
  UNIT                                LOAD   ACTIVE SUB     DESCRIPTION
  validator-client-mainnet-stable.service   loaded active running Validator Client on mainnet network (stable)
  validator-client-mainnet-testing.service  loaded active running Validator Client on mainnet network (testing)
  validator-client-mainnet-unstable.service loaded active running Validator Client on mainnet network (unstable)
```
To rebuild the image:
```sh
 > sudo systemctl start update-validator-client-mainnet-stable
 > sudo systemctl status update-validator-client-mainnet-stable
○ update-validator-client-mainnet-unstable.service - Update validator-client-mainnet-unstable
     Loaded: loaded (/etc/systemd/system/update-validator-client-mainnet-unstable.service; static)
     Active: inactive (dead) since Mon 2026-05-18 14:50:09 UTC; 29min ago
TriggeredBy: ● update-validator-client-mainnet-unstable.timer
       Docs: https://github.com/status-im/infra-role-systemd-timer
    Process: 3502060 ExecStart=/nix/var/nix/profiles/default/bin/nix build --no-write-lock-file --refresh git+https://github.com/status-im/nimbus-eth2?submodules=1&ref=unstable#validator_client_gcc11 (code=exited, status=0/SUCCESS)
    Process: 3508582 ExecStartPost=/bin/systemctl restart validator-client-mainnet-unstable.service (code=exited, status=0/SUCCESS)
   Main PID: 3502060 (code=exited, status=0/SUCCESS)
        CPU: 8.770s

May 18 14:43:59 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: Pass '--accept-flake-config' to trust it
May 18 14:43:59 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: warning: ignoring untrusted flake configuration setting 'extra-trusted-public-keys'.
May 18 14:43:59 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: Pass '--accept-flake-config' to trust it
May 18 14:43:59 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: warning: not writing modified lock file of flake 'git+https://github.com/status-im/nimbus-eth2?ref=unstable&submodules=1':
May 18 14:44:11 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: this derivation will be built:
May 18 14:44:11 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]:   /nix/store/9ffxqqvdllqvb210hid0jd1db6dcp3zz-nimbus-eth2-26.5.0-00000000.drv
May 18 14:44:11 geth-04.ih-eu-mda1.nimbus.mainnet nix[3502060]: building '/nix/store/9ffxqqvdllqvb210hid0jd1db6dcp3zz-nimbus-eth2-26.5.0-00000000.drv'...
May 18 14:50:09 geth-04.ih-eu-mda1.nimbus.mainnet systemd[1]: update-validator-client-mainnet-unstable.service: Deactivated successfully.
May 18 14:50:09 geth-04.ih-eu-mda1.nimbus.mainnet systemd[1]: Finished Update validator-client-mainnet-unstable.
May 18 14:50:09 geth-04.ih-eu-mda1.nimbus.mainnet systemd[1]: update-validator-client-mainnet-unstable.service: Consumed 8.770s CPU time.

```
To check full build logs use:
```sh
journalctl -u update-validator-client-mainnet-stable.service
```

# Requirements

Due to being part of Status infra this role assumes availability of certain things:

* The `iptables-persistent` module
* Nix
