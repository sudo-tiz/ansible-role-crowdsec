<!--
SPDX-FileCopyrightText: 2026 sudo-Tiz

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Configuring CrowdSec

The role runs the CrowdSec Security Engine and Local API in one Docker container. It persists `/etc/crowdsec` and `/var/lib/crowdsec/data`; the Local API is not published on a host port.

## Log sources

CrowdSec uses the Debian image variant because the `journalctl` acquisition source needs `journalctl` and the host journal mounted into the container. The role selects an existing host journal directory from `crowdsec_journal_host_paths` and mounts it read-only.

Acquisitions are YAML mappings in `crowdsec_acquisitions_auto` and `crowdsec_acquisitions_custom`. Each mapping needs a `source` and parser `labels.type`. For example:

```yaml
crowdsec_acquisitions_custom:
  - source: journalctl
    journalctl_filter:
      - "SYSLOG_IDENTIFIER=sshd"
    labels:
      type: syslog
```

Install the matching CrowdSec collection in `crowdsec_collections_custom`. The MASH component enables the Linux and SSH collections and adds Traefik acquisition when playbook-managed Traefik is enabled.

## Traefik bouncer

When `crowdsec_traefik_bouncer_enabled` is true, the role seeds the `traefik` bouncer from `crowdsec_bouncer_key` via CrowdSec's `BOUNCER_KEY_traefik` environment variable and writes the key to a restricted-permission file in Traefik's configuration directory. Traefik already mounts that directory read-only. The MASH component derives this key from the playbook's generic secret.

`crowdsec_traefik_bouncer_stream_startup_block_enabled` defaults to `false` so an unavailable Local API does not block all traffic during Traefik startup. Set it to `true` for fail-closed startup behavior.

## Persistence and secrets

Do not delete `crowdsec_base_path` unless you intend to erase CrowdSec's local database, credentials, and hub data. `crowdsec_data_deletion_enabled` defaults to false. Do not expose port 8080 or commit bouncer/enrollment keys.
