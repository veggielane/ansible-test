# Lesson 05 - Roles

**Goal:** understand why the Windchill work is split into roles, how a role
is laid out, and how data stays out of it.

## Why roles

A playbook with 200 tasks for 15 configuration areas is unreadable and
unshareable. A **role** is a folder with a fixed layout that packages the
tasks, templates and default variables for one job. A playbook then becomes a
list of roles:

```yaml
- hosts: "{{ target | default('lab') }}"
  roles:
    - role: acme.windchill.oir
      tags: [oir]
    - role: acme.windchill.lifecycles      # future
      tags: [lifecycles]
```

The roles live in the sibling repository `../ansible-collection-windchill`,
packaged as the collection `acme.windchill` (lesson 09 explains why and how
it gets here). Paths in this lesson are relative to that repository, and a
role is always named in full: `acme.windchill.oir`.

## Layout

```
roles/oir/
├── README.md            what it does, the variables it takes
├── defaults/main.yml    variables with their LOWEST-precedence defaults (documentation by example)
├── meta/main.yml        metadata + dependencies (roles that must run first)
├── tasks/main.yml       entry point, always this file name
├── tasks/load_rule.yml  extra task files, included from main.yml
├── templates/*.j2       templates, found automatically by win_template src:
├── files/               static files, found automatically by win_copy src:
├── vars/main.yml        (optional) internal constants users should not override
└── handlers/main.yml    (optional) handlers
```

Ansible finds a role by its full name inside the collection, which
`docker-compose.yml` mounts from your checkout (dev mode) or the image has
installed from Artifactory (release mode). Only `tasks/main.yml` is
required. In the collection repo, `ansible-galaxy role init roles/x` creates
an empty skeleton.

## defaults vs inventory: keeping roles reusable

This is the answer to "how do I separate data from roles". The rule is:

> A role contains no hostname, no password, no path that belongs to one
> server, and no actual Windchill configuration. It only contains **logic**
> plus **defaults that document its inputs**.

Everything specific is data and lives in the inventory or in `config/`:

| Thing | Lives in | Why |
|---|---|---|
| how to connect, WT_HOME, admin user | `inventory/group_vars/windchill/vars.yml` | same for every environment |
| what differs per environment | `inventory/group_vars/<env>/vars.yml` | child group overrides parent |
| passwords | `inventory/group_vars/<env>/vault.yml` | encrypted, per environment |
| **which** rules to load | `inventory/group_vars/windchill/oir.yml` | the list is data, promoted dev → ppe → live |
| the rule **bodies** | `config/oir/*.xml` | content files, referenced by relative path |
| how to render + load a rule | `roles/oir` | logic, identical everywhere |

Because role `defaults` have the lowest precedence, a role can ship
`windchill_oir_rules: []` as documentation and the inventory value always
wins. Look at `roles/common/defaults/main.yml`: every variable has
a comment, and none has a value you would keep for real.

A test of whether you got it right: could you hand the collection to a colleague's
project, with a different company's servers and rules, unchanged? If yes, the
data is properly outside.

That is exactly why the roles can live in their own repository and be pulled
in as a versioned collection through `requirements-windchill.yml`, the same
way `ansible.windows` is (lesson 09).

## Dependencies

`roles/oir/meta/main.yml`:

```yaml
dependencies:
  - role: acme.windchill.common
```

`acme.windchill.common` runs first: it checks the shared variables and that
`windchill.exe` exists, and creates the working folders. Ansible runs a
dependency once per play, however many roles list it, so ten roles still
mean one set of checks.

## Reusing a task file from another role

`roles/common/tasks/load_file.yml` is the generic "run LoadFromFile if the
file changed" step. Any role can call it with its own inputs:

```yaml
- name: Load the staged file
  ansible.builtin.include_role:
    name: acme.windchill.common
    tasks_from: load_file
  vars:
    windchill_load_file: "{{ my_staged_file }}"
    windchill_load_label: "lifecycle_{{ item.name }}"
```

`include_role ... tasks_from` runs just that task file, with the variables
given under `vars:`. This is how the project avoids copying the same 40
lines into every future role.

## Looping over a task file

`include_tasks` + `loop` runs a whole file once per item:

```yaml
- name: Load each object initialization rule
  ansible.builtin.include_tasks: load_rule.yml
  loop: "{{ windchill_oir_rules }}"
  loop_control:
    loop_var: windchill_oir_rule     # rename "item" to something meaningful
    label: "{{ windchill_oir_rule.name }}"
```

## Tags

`tags: [oir]` on a role in `site.yml` lets you run one area:
`ansible-playbook playbooks/site.yml --tags oir`. `--list-tags` shows them.

## Conventions and ansible-lint

```powershell
.\bin\ansible.ps1 ansible-lint
```

`.ansible-lint` selects the strict "production" profile. What it enforces
here, and why:

- fully qualified module names: unambiguous
- every task has a `name` starting with a capital letter: readable output
- variables a role creates start with the role's name (`windchill_oir_...`):
  no collisions when many roles run in one play. This project relaxes it in
  one place (see `.ansible-lint`): what `acme.windchill.common` provides uses the
  shared prefix `windchill_` (`windchill_home`, `windchill_load_*`) so every
  Windchill role can read those names naturally
- `win_shell`/`win_command` have `changed_when`: honest `changed` reporting
- no trailing spaces, consistent indentation, lines under 160 characters

Run it before committing; it catches real bugs (undefined variables in
`when:`, wrong module arguments) as well as style.

## Exercise

In the collection repo, create `roles/hello` with just `tasks/main.yml` that
prints `windchill_home`. Add `acme.windchill.hello` to `site.yml` here with
the tag `hello` and run `playbooks/site.yml --tags hello`; in dev mode no
build or publish is needed. Then give it `meta/main.yml` with the
`acme.windchill.common` dependency and notice the checks now run first.

Next: [06 - Vault](06-vault.md)
