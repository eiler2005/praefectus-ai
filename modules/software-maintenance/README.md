# Software maintenance

This module owns reviewed **host** container-runtime upgrades. Routing and other
application images remain under their application owner's deployment workflow.

```sh
python3 modules/software-maintenance/tests/test-runtime-packages.py
python3 modules/software-maintenance/tests/test-software-inventory.py
cd ansible
ansible-playbook --syntax-check playbooks/42-runtime-packages.yml
ansible-playbook playbooks/42-runtime-packages.yml --check --diff
```

The default is a read-only candidate/removal simulation. Activation requires
explicit operator approval for container-runtime restarts and both variables:

```sh
ansible-playbook playbooks/42-runtime-packages.yml \
  --limit <inventory-host> \
  -e software_maintenance_apply=true \
  -e software_maintenance_restart_approved=true
```

Use one host at a time and a fresh `software_maintenance_backup_dir` for each
maintenance window. The script records the package plan and container/config
snapshot privately, downloads the previous exact packages, validates a merged
Docker configuration, enables live restore by daemon reload, then upgrades only
the fixed Docker package set from the official repository. It does not upgrade
the OS release, prune images/volumes, rewrite application Compose files or reboot.

Live restore reduces disruption; it is not a zero-downtime guarantee across
skipped or non-patch daemon releases. Preserve the reviewed existing bridge,
storage driver and routing-owned systemd guard. After activation, verify the
daemon version, every previously running container, process continuity and the
application owner's authenticated end-to-end gate. Restore missing services only
from the captured runtime definition and coordinate with their owner.

For rollback, retain the previous package files, daemon configuration, package
logs and snapshots under the private backup directory. Review the failure before
using `apt-get install --allow-downgrades` with those exact local packages; a
package downgrade does not roll back container data or schema migrations.
Application rollback must restore its pre-migration database and previous image
together, using the application's own instructions.

Ubuntu security patches remain restricted to the configured security origins.
Run an unattended-upgrade dry run before applying them. Reboot markers and
running-kernel state are separate acceptance facts and require explicit reboot
approval. Do not infer patch currency from an old upstream OpenSSL/Python number:
record the distribution package revision and candidate version.

Keep all host names, endpoints, container identities, package logs, database
snapshots and backup fingerprints in ignored reports or encrypted backups.

`bin/software-inventory.py --role <symbolic-role>` collects software versions
without publishing endpoints, names, environment variables or container IDs.
The reviewed fleet registry is `configs/software-inventory.json`; an unknown
panel version remains `null` rather than being inferred from its bundled core.
Keep application compatibility holds and ownership exclusions with that record.
