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
validator_client_build_repo_branch: 'stable'
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
  validator-client-mainnet-stable.service   loaded active running Nimbus Beacon Node on mainnet network (stable)
  validator-client-mainnet-testing.service  loaded active running Nimbus Beacon Node on mainnet network (testing)
  validator-client-mainnet-unstable.service loaded active running Nimbus Beacon Node on mainnet network (unstable)
```
To rebuild the image:
```sh
 > sudo systemctl start build-validator-client-mainnet-stable
 > sudo systemctl status build-validator-client-mainnet-stable
 ● build-validator-client-mainnet-stable.service - Build validator-client-mainnet-stable
     Loaded: loaded (/etc/systemd/system/build-validator-client-mainnet-stable.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Wed 2021-09-29 12:00:12 UTC; 2h 15min ago
TriggeredBy: ● build-validator-client-mainnet-stable.timer
       Docs: https://github.com/status-im/infra-role-systemd-timer
    Process: 1212987 ExecStart=/data/validator-client-mainnet-stable/build.sh (code=exited, status=0/SUCCESS)
   Main PID: 1212987 (code=exited, status=0/SUCCESS)

Sep 29 12:00:12 build.sh[1213054]: HEAD is now at 0b21ebfe readme: update toc
Sep 29 12:00:12 build.sh[1212987]:  >>> Binary already built
Sep 29 12:00:12 systemd[1]: build-validator-client-mainnet-stable.service: Succeeded.
Sep 29 12:00:12 systemd[1]: Finished Build validator-client-mainnet-stable.
```
To check full build logs use:
```sh
journalctl -u build-validator-client-mainnet-stable.service
```

# Requirements

Due to being part of Status infra this role assumes availability of certain things:

* The `iptables-persistent` module
