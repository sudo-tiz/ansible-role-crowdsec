<!--
SPDX-FileCopyrightText: 2026 sudo-Tiz

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# CrowdSec Ansible role

Install [CrowdSec](https://www.crowdsec.net/) as a Docker container managed by systemd. The Debian image variant supports reading the host's systemd journal; the role persists CrowdSec's configuration and database and keeps the Local API on its Docker network.

The role does not install a firewall bouncer. It can seed a Traefik bouncer key for the MASH integration; keep that key private.

See [`docs/configuring-crowdsec.md`](docs/configuring-crowdsec.md) for role variables and log acquisition examples. The full list of defaults is in [`defaults/main.yml`](defaults/main.yml).

## Development

Install the pinned tools with `just mise install`, then run the checks with `just prek-run-on-all`. See [`molecule/README.md`](molecule/README.md) for the service smoke test.

## Releases

The autotag workflow uses `bin/compute-next-tag.sh` and `crowdsec_version` to create the next `v<version>-N` tag. `bin/test-compute-next-tag.sh` tests the release calculation.
