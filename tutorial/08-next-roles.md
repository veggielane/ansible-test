# Lesson 08 - The next roles, and promoting through dev → PPE → live

**Goal:** a map of the other Windchill configuration areas, the recipe for a
new role, and a safe way to move a change through three environments.

## The recipe for a role that loads files

Most Windchill configuration goes through `LoadFromFile`, so most roles are
the OIR role with a different template:

1. In the collection repo: `ansible-galaxy role init roles/<area>`; delete the folders you do not need.
2. `meta/main.yml`: depend on `acme.windchill.common`.
3. `defaults/main.yml`: `windchill_<area>_items: []` plus any knobs, all commented.
4. `templates/<area>_load.xml.j2`: the csv-XML wrapper for that loader
   (`loadFiles/csvmapfile.txt` on the server lists every element and handler).
5. `tasks/main.yml`: validate, then `include_tasks` per item.
6. `tasks/load_item.yml`: `set_fact` names, `win_template` to staging, then
   `include_role: acme.windchill.common, tasks_from: load_file`.
7. Data: `inventory/group_vars/windchill/<area>.yml` and `config/<area>/`.
8. Add to `playbooks/site.yml` with a tag, write the README, run `ansible-lint`.

Steps 5 and 6 are copy-and-rename from `acme.windchill.oir`; that is deliberate.

## The map

| Area | How Windchill takes it | Ansible approach | Idempotency |
|---|---|---|---|
| Object initialization rules | LoadFromFile (`csvTypeBasedRule`) | **done**: `acme.windchill.oir` | applied-copy checksum |
| Access control rules | LoadFromFile (`wt.load.LoadUser.createAccessRule`) | same recipe | same |
| Users, groups | LoadFromFile (`createUser`, `createGroup`) or LDAP | same recipe; prefer LDAP/AD for users | same |
| Folders, cabinets | LoadFromFile (`wt.folder.LoadFolder.*`) | same recipe | same |
| Life cycle templates | LoadFromFile (`wt.lifecycle.LoadLifeCycle.*`) or Import/Export | same recipe with exported XML as `load_file` | same |
| Workflow templates | Import/Export (jar) via the UI or `wt.ixb` command line | `win_copy` the jar + `win_shell` the import; track by checksum like the loader | applied copy |
| Type icons and other images | files under `codebase\netmarkets\images` | **done**: `acme.windchill.icons` (`win_copy`, no loader; `types` depends on it) | win_copy checksums |
| Soft types, attributes, layouts, enumerations | Type and Attribute Management export -> load file, LoadFromFile | **done**: `acme.windchill.types`; `oir` depends on it so types always load first | applied-copy checksum |
| Preferences | Preference Management export/import | same | applied copy |
| `wt.properties`, `site.xconf` | `xconfmanager -s key=value -t codebase/wt.properties -p` | **done**: `acme.windchill.properties` reads the current override from `site.xconf`, sets only what differs, propagates once; a **handler** restarts Windchill (`windchill_restart_command`), flushed inside the role | read-then-set |
| Business Administrative Change (BAC) | PTC's tool for promoting config between environments (11.1+) | `win_shell` the BAC import of a package exported from dev | applied copy |
| Windows layer: services, scheduled backups, firewall, Java, certificates | native | `win_service`, `community.windows.win_scheduled_task`, `win_firewall_rule`, `win_certificate_store`: idempotent by themselves | built in |

Two patterns cover everything: **"file in, load if changed"** (the shared
loader) and **"read current value, set if different, notify restart"**
(properties). Get those two right and the rest is templates.

## Where the data goes

The separation from lesson 05 holds for every role:

- `inventory/group_vars/windchill/<area>.yml` says *which* items, shared by
  all environments. Rarely, an environment needs an extra or different item:
  `group_vars/<env>/<area>.yml` overrides the whole list, so keep those
  cases rare.
- `config/<area>/` holds the bodies (XML, jars, property fragments).
- Values that legitimately differ per environment (organisation name, URLs,
  mail server) are variables in `group_vars/<env>/vars.yml`, referenced from
  the templates, never baked into `config/`.

## Promoting a change

```
edit config/ or group_vars/windchill/   ──▶  ansible-playbook site.yml                  (lab: does it render and load?)
                                         ──▶  ansible-playbook site.yml -e target=dev   (real Windchill, verify in the UI)
                                         ──▶  git commit
                                         ──▶  ansible-playbook site.yml -e target=ppe --check --diff, then for real
                                         ──▶  ansible-playbook site.yml -e target=live --check --diff, then for real
```

The same commit is applied to each environment in turn. Nothing is edited
between PPE and live; if live needs a different value, that is a variable in
`group_vars/live`, decided and committed *before* the PPE run.

Guard rails worth adding as the roles grow:

- git: feature branches, a pull request before anything reaches `main`,
  `main` is what goes to live.
- `--check --diff` first on every non-lab run; make it a habit before you make it a rule.
- a `pre_tasks` prompt or an explicit `-e confirm_live=yes` requirement in
  `site.yml` for `target=live`.
- CI: `ansible-lint` and `--syntax-check` on every push (they need no Windchill).
- a lab run in CI is possible too: the fake Windchill is just files.

## Where to read next

- `ansible-doc ansible.windows.<module>` for every Windows module you use.
- Ansible documentation: "Windows guides" and "Using Ansible playbooks".
- PTC Help Center: "Windchill Data Loading Guide" (`LoadFromFile`, load
  files, `csvmapfile.txt`) and "Business Administrative Change".
