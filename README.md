# Ansible for Windchill

Learn Ansible from zero by putting the configuration of PTC Windchill servers
(dev, PPE, live) under version control. Two things in one repository:

1. **A course**: `docs/00` to `docs/09`. Each lesson explains one idea and
   points at the real files that use it.
2. **A working project**: a Docker control node, a multi-environment
   inventory, a lab you can run on your own PC without any Windchill, and
   the configuration data for the first role, `acme.windchill.oir` (object
   initialization rules via `LoadFromFile`).

The roles themselves live in a sibling repository,
`../ansible-collection-windchill`, as the Ansible collection `acme.windchill`,
built and published to Artifactory by GitLab CI. This repository pins a
version of it (lesson 09).

## Quick start (15 minutes, no Windchill needed)

```powershell
# 0. Both repositories side by side
#    C:\git\ansible                        (this one)
#    C:\git\ansible-collection-windchill   (the roles; mounted into the container in dev mode)

# 1. Control node (Docker Desktop must be running)
docker compose build
.\bin\ansible.ps1 ansible --version

# 2. Let Ansible reach this PC over WinRM: docs/02-inventory-and-windows.md, "Prepare a Windows target"
#    then set your Windows user/password in inventory/group_vars/lab/vault.yml
.\bin\ansible.ps1 ansible-playbook playbooks/01_ping.yml

# 3. Install the fake Windchill on this PC and load the lab rules into it
.\bin\ansible.ps1 ansible-playbook playbooks/lab_setup.yml
.\bin\ansible.ps1 ansible-playbook playbooks/windchill_oir.yml
```

No WinRM yet? `playbooks/lab_render_oir.yml` renders the load files into
`build/oir/` entirely on the control node.

If a `docker compose run` seems to hang, Docker Desktop is waiting for you to
allow sharing `C:\git\ansible` (see lesson 00).

## Learning path

| Lesson | You learn | Files |
|---|---|---|
| [00 Control node](docs/00-control-node.md) | why Ansible runs in Docker here, how to run it | `docker/`, `docker-compose.yml`, `bin/` |
| [01 Concepts](docs/01-concepts.md) | the vocabulary and the one big idea (desired state) | |
| [02 Inventory and Windows](docs/02-inventory-and-windows.md) | hosts, groups, environments, WinRM | `inventory/` |
| [03 First playbook](docs/03-first-playbook.md) | plays, tasks, modules, reading output | `playbooks/01_ping.yml` |
| [04 Variables, facts, templates](docs/04-variables-facts-templates.md) | where values come from, `register`, `when`, `loop`, Jinja2, handlers | `playbooks/02_…`, `03_…`, `04_…` |
| [05 Roles](docs/05-roles.md) | packaging tasks for reuse, dependencies, tags, lint | `../ansible-collection-windchill/roles/` |
| [06 Vault](docs/06-vault.md) | keeping passwords encrypted in git | `inventory/group_vars/*/vault.yml` |
| [07 The OIR role](docs/07-windchill-oir-role.md) | the whole thing end to end, lab and real | `roles/oir`, `roles/common` (collection) |
| [08 Next roles](docs/08-next-roles.md) | the other Windchill configuration areas, promotion dev → ppe → live | |
| [09 Collection and Artifactory](docs/09-collection-and-artifactory.md) | two repositories, dev mode vs release mode, publishing versions | `requirements-windchill.yml` |

## How the pieces fit

```
ansible/  (this repo)        WHO and WHAT
  inventory/                   hosts per environment + the configuration data
    hosts.yml                    lab / dev / ppe / live groups under "windchill"
    group_vars/windchill/        shared settings and the rule list (all environments)
    group_vars/<env>/            what differs per environment + that environment's secrets
  config/                      the configuration CONTENT (OIR bodies, ...), shared by all environments
  playbooks/                   entry points: which roles run on which environment
  requirements-windchill.yml   which version of the collection
  lab/                         a fake Windchill for practising on your own PC
  docs/                        the lessons

ansible-collection-windchill/  HOW: the acme.windchill collection, no environment-specific values inside
  roles/common/                  checks + the generic "LoadFromFile if changed" step
  roles/oir/                     object initialization rules
  .gitlab-ci.yml                 lint, test, build, publish to Artifactory on a tag
```

Roles never contain a hostname, password, path or rule: those all come from
`inventory/` and `config/`. That is what lets one collection serve four
environments, and what makes it publishable as a versioned artifact.

## Everyday commands

```powershell
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml                       # lab (default)
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=dev         # a real environment
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=live --check --diff
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=ppe --tags oir
.\bin\ansible.ps1 ansible-lint                                              # style and bug check (this repo)
.\bin\ansible.ps1 ansible-inventory --graph                                 # who is in which group
```

Verified so far: syntax, lint, local rendering and the fake Windchill. The
roles have not yet been run against a real Windchill, so lesson 07 lists the
five things to confirm on your dev server first.
