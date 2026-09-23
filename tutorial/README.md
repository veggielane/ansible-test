# Tutorial - Ansible from zero, on the Windchill project

Nine lessons, each about one idea, each pointing at the real files in this
repository and the collection that use it. The lesson playbooks live in
`tutorial/playbooks/` and run against the lab like everything else:

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml
```

| Lesson | You learn | Files |
|---|---|---|
| [00 Control node](00-control-node.md) | why Ansible runs in Docker here, how to run it | `docker/`, `docker-compose.yml`, `bin/` |
| [01 Concepts](01-concepts.md) | the vocabulary and the one big idea (desired state) | |
| [02 Inventory and Windows](02-inventory-and-windows.md) | hosts, groups, environments, WinRM | `inventory/` |
| [03 First playbook](03-first-playbook.md) | plays, tasks, modules, reading output | `tutorial/playbooks/01_ping.yml` |
| [04 Variables, facts, templates](04-variables-facts-templates.md) | where values come from, `register`, `when`, `loop`, Jinja2, handlers | `tutorial/playbooks/02_…`, `03_…`, `04_…` |
| [05 Roles](05-roles.md) | packaging tasks for reuse, dependencies, tags, lint | `../ansible-collection-windchill/roles/` |
| [06 Vault](06-vault.md) | keeping passwords encrypted in git | `inventory/group_vars/*/vault.yml` |
| [07 The OIR role](07-windchill-oir-role.md) | the whole thing end to end, lab and real | `roles/oir`, `roles/types`, `roles/common` (collection) |
| [08 Next roles](08-next-roles.md) | the other Windchill configuration areas, promotion dev → ppe → live | |
| [09 Collection and Artifactory](09-collection-and-artifactory.md) | two repositories, dev mode vs release mode, publishing versions | `requirements-windchill.yml` |

Start at 00 if you have never used Ansible. If you already know it, read 02
(the environments), 07 (how a role here is built) and 09 (how the two
repositories fit), and skim 05 for the data-versus-roles rule.
