# Lesson 01 - How Ansible thinks

**Goal:** know the ten words that everything else is built from, and the one
idea that makes Ansible different from a script.

## The picture

```
 control node (Docker on your PC)                 managed node (Windows server)
 ┌──────────────────────────────────┐             ┌──────────────────────────────┐
 │ inventory   who to manage        │  WinRM 5986 │                              │
 │ playbook    what to do, in order │ ──────────▶ │  PowerShell runs the module, │
 │ roles       reusable chunks      │   or SSH 22 │  returns JSON:               │
 │ variables   the details          │ ◀────────── │  {"changed": true, ...}      │
 │ templates   files with holes     │             │                              │
 └──────────────────────────────────┘             │  Windchill lives here        │
                                                  └──────────────────────────────┘
```

## Vocabulary

| Word | Meaning | In this project |
|---|---|---|
| **Inventory** | the list of machines, in groups | `inventory/hosts.yml` |
| **Host** | one machine | `wcdev01` |
| **Group** | a named set of hosts; groups can nest | `windchill` contains `lab`, `dev`, `ppe`, `live` |
| **Module** | one unit of work Ansible can do (copy a file, run a command, ...) | `ansible.windows.win_copy` |
| **Task** | one call of one module, with arguments and a name | every `- name:` block |
| **Play** | "on these hosts, run these tasks" | the top-level block in a playbook |
| **Playbook** | a YAML file holding one or more plays | `playbooks/*.yml` |
| **Role** | tasks + templates + defaults packaged for reuse | `roles/oir` in the collection repo |
| **Collection** | a downloadable, versioned bundle of modules and/or roles | `ansible.windows`; our own `acme.windchill` |
| **Variable** | a named value; from inventory, files, the command line, or a task result | `windchill_home` |
| **Fact** | a variable Ansible discovers about a host | `ansible_hostname` |
| **Template** | a text file with `{{ placeholders }}` (Jinja2) | `oir_load.xml.j2` |
| **Handler** | a task that runs once at the end, only if something notified it | "restart service" |
| **Vault** | encryption for files that hold secrets | `group_vars/*/vault.yml` |

## The one idea: desired state

A script says *do this, then this*. A playbook says *this is how the machine
should be*; Ansible works out what (if anything) needs doing.

```yaml
- name: Ensure the staging folder exists
  ansible.windows.win_file:
    path: C:\ansible\windchill
    state: directory
```

Run it once: the folder is created and the task reports **changed**.
Run it again: the folder exists, nothing happens, the task reports **ok**.
A task that behaves like this is **idempotent**. It makes re-running a
playbook safe, which is what turns it from a one-shot install script into
configuration management.

Not every module can be idempotent by itself. `win_shell` runs whatever you
give it. Making *that* idempotent is your job, and lesson 07 shows the
standard trick: keep a copy of what was last applied and compare.

## How Windows is different

- Modules for Windows start with `win_` and live in the `ansible.windows` and
  `community.windows` collections. Generic modules (`ansible.builtin.copy`)
  are for Linux; on Windows use the `win_` twin (`ansible.windows.win_copy`).
- Modules that run anywhere, on the control node: `debug`, `assert`,
  `set_fact`, `include_*`, `template`-to-localhost.
- Nothing is installed on the server. PowerShell 5.1+ is enough.
- `win_command` runs a program directly. `win_shell` runs a PowerShell
  snippet. Prefer the specific module (`win_copy`, `win_service`) over either
  whenever one exists: it knows how to be idempotent.

## YAML in five minutes

```yaml
key: value                      # a mapping (dictionary)
list:
  - first                       # a list
  - second
nested:
  inner_key: value              # indentation = structure, always spaces, never tabs
quoted: "must quote {{ these }}"   # a value that STARTS with {{ must be quoted
windows_path: 'C:\ptc\Windchill'   # single quotes: backslashes are literal
also_ok: "C:\\ptc\\Windchill"      # double quotes: backslashes must be doubled
multi: |                        # literal block: newlines kept
  line one
  line two
folded: >-                      # folded block: newlines become spaces
  one long
  sentence
```

## Commands you will use every day

| Command | Purpose |
|---|---|
| `ansible-playbook playbooks/x.yml` | run a playbook |
| `... -e target=dev` | choose the environment (this project's convention) |
| `... --check --diff` | dry run, show what would change |
| `... -v` / `-vvv` | more output / connection-level debugging |
| `... --tags oir` / `--list-tags` | run one part / list parts |
| `... --limit wcdev01` | only some of the targeted hosts |
| `... --syntax-check` | parse without running |
| `ansible windchill -m ansible.windows.win_ping` | one module, no playbook ("ad-hoc") |
| `ansible-inventory --graph` | show groups and hosts |
| `ansible-inventory --host wcdev01` | every variable that host would get |
| `ansible-doc ansible.windows.win_copy` | a module's documentation |
| `ansible-lint` | style and bug check |
| `ansible-vault encrypt/edit/view FILE` | secrets |

Next: [02 - Inventory and Windows](02-inventory-and-windows.md)
