# Lesson 04 - Variables, facts, templates, handlers

**Goal:** the building blocks that every role is made from. Three playbooks
to run, each short.

## 04a - Facts (`tutorial/playbooks/02_facts.yml`)

With `gather_facts: true` (the default) Ansible first runs the `setup`
module, which collects information about the host: OS, hostname, memory, IP
addresses, environment variables, and so on. Each becomes a variable named
`ansible_*`, and all of them are under `ansible_facts`.

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/02_facts.yml
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/02_facts.yml -v      # dumps everything
```

Facts cost a few seconds per host. Playbooks that do not need them set
`gather_facts: false`; the Windchill roles do, because they get everything
they need from inventory variables.

## 04b - Variables (`tutorial/playbooks/03_variables.yml`)

Where a value can come from, lowest to highest precedence:

1. a role's `defaults/main.yml`
2. `inventory/group_vars/all.yml`
3. `inventory/group_vars/windchill/`
4. `inventory/group_vars/<env>/` (child group beats parent)
5. `inventory/host_vars/<host>.yml`
6. `vars:` in a play
7. `register` / `set_fact` results during the run
8. `-e key=value` on the command line (beats everything)

Run the playbook, then run it again with `-e greeting="from the command line"`
and watch the first line change.

Three keywords appear in nearly every task file:

```yaml
- name: Run PowerShell and capture the output
  ansible.windows.win_shell: Get-Date -Format o
  register: server_time         # the task's whole result goes into "server_time"
  changed_when: false

- name: Use it
  ansible.builtin.debug:
    msg: "{{ server_time.stdout | trim }}"       # .stdout, .rc, .stderr, .changed, .failed ...

- name: Check several paths in one task
  ansible.windows.win_stat:
    path: "{{ item }}"          # "item" is the current element
  loop: "{{ paths_to_check }}"
  register: path_checks         # with a loop: path_checks.results is a list, one per item

- name: Report the ones that exist
  ansible.builtin.debug:
    msg: "{{ item.item }} exists"
  loop: "{{ path_checks.results }}"
  when: item.stat.exists        # a condition; no {{ }} inside when:
```

`set_fact` creates a variable on the spot. It is how a role computes a file
name once and reuses it in later tasks.

**Jinja2 filters** transform values inside `{{ }}`: `| trim`, `| bool`,
`| default('x')`, `| length`, `| regex_replace('a', 'b')`, `| join(', ')`,
`| ternary('yes', 'no')`. Tests go after `is`: `is defined`, `is skipped`,
`is regex('pattern')`. The `ansible-doc -t filter -l` command lists all filters.

**Windows path gotcha.** In YAML, `"C:\ansible"` inside double quotes is an
escape sequence, not a backslash. Either use single quotes `'C:\ansible'` or
double the backslashes `"C:\\ansible"`. When a variable is involved you need
double quotes (for the `{{ }}`), so you will see
`"{{ windchill_home }}\\bin\\windchill.exe"` a lot.

Second half of the gotcha: never put a backslash (or `\n`) inside a Jinja
string literal in a YAML file, as in `{{ root ~ "\\" ~ name }}`. In current
Ansible those are taken verbatim there, so you get two backslashes. Build the
path on the YAML side instead: `"{{ root }}\\{{ name }}"`. The collection's
`tests/icons_target.yml` exists because of exactly this.

## 04c - Templates and handlers (`tutorial/playbooks/04_templates_handlers.yml`)

A **template** is a file with holes. `tutorial/playbooks/templates/hello.txt.j2`:

```
Windchill home ......: {{ windchill_home }}
{% if windchill_service_name | length > 0 %}
Service to watch ....: {{ windchill_service_name }}
{% else %}
Service to watch ....: (none configured)
{% endif %}
```

`win_template` renders it with the host's variables and copies the result
to the server. It compares before writing, so it only reports `changed` when
the content actually differs. That is the core of every "configuration file"
task, and of the OIR role: the load file is a template.

A **handler** is a task that runs at the end of the play, once, and only if
some task **notified** it. The classic pairing:

```yaml
tasks:
  - name: Render config
    ansible.windows.win_template: { src: x.j2, dest: 'C:\x.conf' }
    notify: Restart the thing         # only when this task reports changed

handlers:
  - name: Restart the thing           # name must match the notify
    ansible.windows.win_service: { name: thing, state: restarted }
```

Run the playbook twice:

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/04_templates_handlers.yml
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/04_templates_handlers.yml
```

First run: `changed` and the handler fires. Second run: `ok`, handler silent.
Now edit the template, run again: `changed` again. That loop, edit → run →
only the difference is applied, is the working rhythm of Ansible.

## Dry runs

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/04_templates_handlers.yml --check --diff
```

`--check` asks every module to report what it *would* do without doing it;
`--diff` shows the before/after of files. Modules that cannot predict
(`win_shell`, `win_command`) are skipped in check mode.

## Exercise

1. Add `windchill_service_name: 'Spooler'` to `inventory/group_vars/lab/vars.yml`
   and re-run 04c. Which line of `hello.txt` changed? (The file is at
   `C:\FakeWindchill\ansible\lessons\hello.txt` on your PC.)
2. In `03_variables.yml`, add `'C:\Windows'` to `paths_to_check`. Why does the
   "exists" report include it without any other change?

Next: [05 - Roles](05-roles.md)
