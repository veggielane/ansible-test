# Ansible for Windchill

Configuration of PTC Windchill servers (dev, PPE, live) as code. This
repository holds the **configuration**: which servers, which environment
values, which soft types and rules to load, and the files they come from.
The **roles** that do the loading are the Ansible collection
`acme.windchill` in the sibling repository
[`ansible-collection-windchill`](https://github.com/veggielane/ansible-collection-windchill),
pinned here by version.

New to Ansible? The `tutorial/` folder is a course built on this project.

## Layout

```
inventory/                  WHO and WHAT
  hosts.yml                   lab / dev / ppe / live groups under "windchill"
  group_vars/windchill/       shared settings + the lists of what to load (types.yml, oir.yml)
  group_vars/<env>/           what differs per environment + that environment's vault
config/                     the configuration CONTENT, shared by all environments
  types/                      soft-type load files exported from Type and Attribute Management
  oir/                        object initialization rule bodies
playbooks/
  site.yml                    everything, in dependency order (types, then oir, ...)
  windchill_types.yml         one area at a time
  windchill_oir.yml
  lab_setup.yml               installs the fake Windchill on your PC
  lab_render_oir.yml          renders the OIR load files locally, no host needed
requirements-windchill.yml  which version of the collection
docker/, docker-compose.yml, bin/   the control node (Ansible cannot run natively on Windows)
lab/                        a fake Windchill that behaves like LoadFromFile
tutorial/                   the lessons and their practice playbooks
```

## What gets loaded, in what order

| Step | Role | Data here | How Windchill takes it |
|---|---|---|---|
| 1 | `acme.windchill.types` | `group_vars/windchill/types.yml`, `config/types/*.xml` | `LoadFromFile` of the export from Type and Attribute Management, site level |
| 2 | `acme.windchill.oir` | `group_vars/windchill/oir.yml`, `config/oir/*.xml` | `LoadFromFile` of a rendered `csvTypeBasedRule` document |

The order is enforced by the collection (`oir` depends on `types`), not only
by `site.yml`, so a rule for a soft type can never run before the type
exists. Each step only loads a file when it changed since the last
successful load (a copy of what was applied is kept on the server).

## Quick start (no Windchill needed)

```powershell
# 1. Both repositories side by side: C:\git\ansible and C:\git\ansible-collection-windchill
# 2. Control node (Docker Desktop running; allow sharing C:\git if Docker asks)
docker compose build
.\bin\ansible.ps1 ansible --version

# 3. Let Ansible reach this PC over WinRM (tutorial/02, "Prepare a Windows target"),
#    then put your Windows user/password in inventory/group_vars/lab/vault.yml
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml

# 4. Fake Windchill on this PC, then the whole configuration against it
.\bin\ansible.ps1 ansible-playbook playbooks/lab_setup.yml
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml
```

## Everyday commands

```powershell
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml                       # lab (default)
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=dev         # a real environment
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=live --check --diff
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=ppe --tags oir
.\bin\ansible.ps1 ansible-lint
.\bin\ansible.ps1 ansible-inventory --graph
```

Playbooks default to the lab; a real environment is always an explicit
`-e target=...`.

## Promoting a change

Edit `config/` or `group_vars/windchill/`, run against the lab, then dev,
verify in the Windchill UI, commit, then PPE and live with `--check --diff`
first. The same commit goes to every environment; per-environment values
live in `group_vars/<env>/`.

## Status

Verified: syntax, lint, local rendering, and the fake Windchill. Nothing has
run against a real Windchill yet; `tutorial/07-windchill-oir-role.md`
(Part D) and the collection README list what to confirm on dev first. The
collection's namespace `acme` is a placeholder to rename before publishing.
