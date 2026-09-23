# Lesson 03 - Your first playbook

**Goal:** read a playbook line by line, run it, and understand every line of
the output.

## Anatomy

`playbooks/01_ping.yml`:

```yaml
---                                        # YAML file marker (optional, conventional)
- name: Lesson 03 - can Ansible reach the Windchill servers?   # a PLAY
  hosts: "{{ target | default('lab') }}"   # which inventory group/host
  gather_facts: false                      # skip fact collection (lesson 04); faster

  tasks:                                   # the list of TASKS, run in order, on every host
    - name: WinRM/SSH round trip           # human-readable, shown in the output
      ansible.windows.win_ping:            # MODULE to call; no arguments needed here
```

A playbook is a list of plays (the leading `-`). Each play targets hosts and
runs tasks top to bottom. Tasks run on all targeted hosts in parallel, task
by task: task 1 finishes on every host before task 2 starts anywhere.

Module names are written in full: `<namespace>.<collection>.<module>`.
Ansible's own modules are `ansible.builtin.*`; Windows ones are
`ansible.windows.*`. Writing the short form (`win_ping`) works but
`ansible-lint` will complain, and it is ambiguous once you use many
collections.

## Run it

```powershell
.\bin\ansible.ps1 ansible-playbook playbooks/01_ping.yml
```

```
PLAY [Lesson 03 - can Ansible reach the Windchill servers?] ******************

TASK [WinRM/SSH round trip] ***************************************************
ok: [fakewc]

PLAY RECAP ********************************************************************
fakewc : ok=1  changed=0  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

## Reading the output

| Status | Meaning |
|---|---|
| `ok` | task ran, nothing needed changing |
| `changed` | task ran and changed something (yellow) |
| `skipping` | a `when:` condition was false |
| `failed` | the module reported an error; the host drops out of the rest of the play (red) |
| `unreachable` | could not connect at all |
| `fatal` | same as failed, shown with the error detail |

The **PLAY RECAP** at the end is the summary per host. `failed=0` and
`unreachable=0` is what you want to see.

Add `-v` to print each task's full result (the JSON the module returned).
`-vvv` also shows the connection details, which is the first thing to reach
for when a host is unreachable.

## Useful variations

```powershell
# parse only, run nothing
.\bin\ansible.ps1 ansible-playbook playbooks/01_ping.yml --syntax-check

# which hosts would be targeted?
.\bin\ansible.ps1 ansible-playbook playbooks/01_ping.yml -e target=windchill --list-hosts

# a subset of the targeted hosts
.\bin\ansible.ps1 ansible-playbook playbooks/01_ping.yml -e target=windchill --limit dev

# run one module without writing a playbook ("ad-hoc")
.\bin\ansible.ps1 ansible lab -m ansible.windows.win_shell -a "Get-Date"
```

## Exercise

Add a second task to `01_ping.yml` that runs a PowerShell command and shows
the result. Two modules are involved: one runs the command, one prints.

```yaml
    - name: Count running services
      ansible.windows.win_shell: (Get-Service | Where-Object Status -eq Running).Count
      register: running          # store the result in a variable named "running"
      changed_when: false        # reading is not a change

    - name: Show the count
      ansible.builtin.debug:
        msg: "{{ running.stdout | trim }} services are running"
```

Run it twice. Notice the task reports `ok`, not `changed`, because of
`changed_when: false`. Remove that line and run again: `win_shell` reports
`changed` every time, because it cannot know whether the command changed
anything. Lesson 04 explains `register`.

Next: [04 - Variables, facts, templates, handlers](04-variables-facts-templates.md)
