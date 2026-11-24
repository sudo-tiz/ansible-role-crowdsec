<!--
SPDX-FileCopyrightText: 2026 sudo-Tiz

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule testing

The `default` scenario installs CrowdSec in a systemd-enabled Docker instance, seeds an acquisition file, and verifies that CrowdSec starts, registers the configured Traefik bouncer, and installs its key file.

Run with:

```sh
molecule test --scenario-name default
```
