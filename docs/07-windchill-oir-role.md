# Lesson 07 - The OIR role, end to end

**Goal:** load object initialization rules into the fake Windchill from
Ansible, understand every task that made it happen, and know what to confirm
before pointing it at dev.

## What we are automating

An **object initialization rule** (OIR) tells Windchill what to do when an
object of a given type is created: the numbering scheme, the default folder,
the life cycle and team templates, versioning, attribute constraints. Rules are
XML, belong to a container (site, organisation, product, library), and are
managed in *Site ▸ Utilities ▸ Object Initialization Rules Administrator*.

PTC's `LoadFromFile` utility loads them from the command line, on the
Windchill server itself, with the method server running:

```
windchill wt.load.LoadFromFile -d <load file> -u <site admin> -p <password> -CONT_PATH "<container path>"
```

That command is what the role runs. Everything else in the role is about
running it *only when needed*, *safely*, and *verifiably*.

## Where each piece lives

```
this repo
  inventory/group_vars/windchill/oir.yml   WHICH rules (name, type, container, which body file)
  config/oir/*.xml                         the rule BODIES (<AttributeValues> ... exported or hand-written)
../ansible-collection-windchill  (the acme.windchill collection, lesson 09)
  roles/oir/                               HOW a rule becomes a load file on the server
  roles/common/tasks/load_file.yml         HOW a file is loaded once, and only when it changed
```

## The flow

```
 rule definition            win_template / win_copy          checksum vs applied\
 (inventory + config) ───▶ staging\oir_<name>.xml ────────▶ differs?  ──no──▶ "already applied"
                                                                │ yes
                                                                ▼
                                       windchill wt.load.LoadFromFile -d staging\oir_<name>.xml ...
                                                                │
                                                   output ──▶ logs\oir_<name>_<time>.log
                                                                │
                                          rc == 0 and no failure pattern?  ──no──▶ FAIL (applied\ untouched)
                                                                │ yes
                                                                ▼
                                                copy staging\ ──▶ applied\oir_<name>.xml
```

The `applied\` folder is the role's memory of what Windchill already has.
It is what makes the role idempotent even though `LoadFromFile` itself is
not: run the playbook ten times and Windchill is touched once.

## Part A - render without any host

```powershell
.\bin\ansible.ps1 ansible-playbook playbooks/lab_render_oir.yml    # renders the load files
```

Open `build/oir/fakewc_LAB_WTPart.xml`. This is exactly the file the role
would put on the server. Now change the folder in `config/oir/example_wtpart.xml`,
render again, and diff. This is the fastest way to develop a rule.

## Part B - the lab, end to end

```powershell
.\bin\ansible.ps1 ansible-playbook playbooks/lab_setup.yml        # installs C:\FakeWindchill
.\bin\ansible.ps1 ansible-playbook playbooks/windchill_oir.yml    # loads the two lab rules
```

Walk through what happened:

1. `acme.windchill.common` checked variables, found `bin\windchill.cmd`, created
   `C:\FakeWindchill\ansible\{staging,applied,logs}`.
2. For each rule: rendered the load file, found no `applied\` copy, ran
   LoadFromFile, printed its output, saved a log, created the `applied\` copy.
3. The fake wrote `C:\FakeWindchill\Windchill\fakedb\oir\...\LAB_WTPart.xml`.

Now experiment:

| Do | Observe |
|---|---|
| run `windchill_oir.yml` again | both rules: "Already applied"; recap `changed=0` |
| change `/Default/Documents` in `group_vars/lab/oir.yml`, run again | only `LAB_WTDocument` reloads |
| `--check` | template tasks show `changed`, loads are skipped: a preview |
| `-e windchill_oir_force=true` | both reload although unchanged |
| set `vault_windchill_admin_password: wrong` in `group_vars/lab/vault.yml` | LoadFromFile prints an exception; the assert fails; `applied\` is not updated; next run retries |
| add `windchill_load_args: '-d "{{ windchill_load_file }}"'` to `group_vars/lab/vars.yml` (no `-u`/`-p`) | the fake "opens a login dialog"; after `windchill_load_timeout` (60 s) Ansible gives up with an async timeout instead of hanging forever |
| delete a file under `fakedb\oir\` and run again | Ansible does *not* notice: it trusts `applied\`. Force fixes it. This is the trade-off of tracking state on the control side |

Remove the experiments afterwards (`git checkout inventory/group_vars/lab`).

## Part C - reading the role

`roles/oir/tasks/main.yml` validates the rule list with `assert`,
then `include_tasks: load_rule.yml` once per rule, renaming `item` to
`windchill_oir_rule`.

`roles/oir/tasks/load_rule.yml`, task by task:

| Task | Concept |
|---|---|
| Work out safe names | `set_fact` + `regex_replace` (rule names may contain `\|`, illegal in file names); `default()` picks the shared container path when the rule has none |
| Render the load file | `win_template` with `src:` found in the role's `templates/`; `when: ... is not defined` |
| Copy the ready-made load file | `win_copy` from `config/`; the opposite `when:` so exactly one of the two runs |
| Load the staged file | `include_role: acme.windchill.common, tasks_from: load_file` with `vars:` as inputs |

`roles/common/tasks/load_file.yml`:

| Task | Concept |
|---|---|
| Checksum staged and applied | `win_stat` with `get_checksum` in a `loop`, `register` gives `.results[0]` and `[1]` |
| Decide whether to run | `set_fact` with a boolean expression; `default('')` guards a missing file |
| Run LoadFromFile | `win_shell` calls the launcher; `environment:` passes the password out of band; `no_log: true` hides it; `async`/`poll` = timeout; `chdir` = run from WT_HOME |
| Combine output, save a log | `set_fact` again, `win_copy` with `content:`, `strftime` for a timestamp |
| Fail on bad output | `assert` looped over `windchill_load_failure_patterns`, using the `regex` test with `ignorecase` |
| Record as applied | `win_copy` with `remote_src: true` (copy on the server, not from the control node) |

Every step after the load has `when: windchill_common_load is not skipped`,
so when nothing needed loading, nothing else runs either.

`roles/oir/templates/oir_load.xml.j2` wraps the rule body in the
`csvTypeBasedRule` element that LoadFromFile's rule handler expects, strips a
leading `<?xml ...?>` from the body (only legal at the very start of a
document) and embeds it as CDATA.

## Part D - before the first run against dev

The role has been exercised against the fake, not a real Windchill. Five
things to confirm on the dev server, in this order:

1. **The load-file element names.** On the server, look at what the loader
   accepts for your version:

   ```powershell
   $wt = 'D:\ptc\Windchill_13.0\Windchill'
   Select-String -Path "$wt\loadFiles\csvmapfile.txt" -Pattern 'TypeBasedRule'     # element -> handler
   Select-String -Path "$wt\loadXMLFiles\*.dtd" -Pattern 'csvTypeBasedRule' -Context 0,3   # its children
   Get-ChildItem "$wt\loadFiles" -Recurse -Include *.xml | Select-String 'csvTypeBasedRule' | Select-Object -First 3   # an OOTB example
   ```

   If the names differ from `csvname`, `csvtype`, `csvcontainerPath`,
   `csvruleType`, `csvenabled`, `csvcontent`, or the DTD wants the body as
   child elements rather than CDATA, change `templates/oir_load.xml.j2` to
   match and nothing else.
2. **The DTD name.** `Get-ChildItem "$wt\loadXMLFiles\standardX*.dtd"` and put
   the newest in `windchill_oir_load_dtd` (`group_vars/windchill/oir.yml`).
3. **A round trip.** Export an existing rule from the OIR Administrator,
   save the body under `config/oir/`, define it in `oir.yml` with the *same*
   name and container, and load it with `-e target=dev`. Windchill ends up
   exactly as it was, and you have proven the pipeline. Then inspect the
   rule in the UI.
4. **Failure patterns.** Read the saved log under `logs\`. If the output of
   a successful load matches one of `windchill_load_failure_patterns`
   (`\berror\b` is the likely culprit), tighten the patterns in
   `group_vars/windchill/vars.yml`. Then provoke a failure (a typo in the
   body) and check it is caught.
5. **Spaces in the container path.** PTC's docs note that on Windows an
   argument with spaces may need `\"..\"` quoting for the launcher. If a
   load into `Demo Organization` reports the container was not found, adjust
   the `-CONT_PATH` part of `windchill_load_args` in
   `roles/common/defaults/main.yml`.

Also worth knowing: the account in `windchill_admin_user` must be a site
administrator; the method server must be running; and `-UNATTENDED` /
`-NOSERVERSTOP` (documented for PTC's LoadFileSet, accepted by most
LoadFromFile versions) can be added through `windchill_load_extra_args`.

## Exercise

Add a third lab rule for `wt.change2.WTChangeRequest2` with an inline body
that sets the folder to `/Default/Changes`. Render it (Part A), load it (Part
B), find it in `fakedb\`, and confirm a second run reloads nothing.

Next: [08 - The next roles](08-next-roles.md)
