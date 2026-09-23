# Lesson 00 - A place to run Ansible from

**Goal:** run `ansible --version` and understand why it runs inside a container.

## Control node and managed nodes

Ansible is *agentless*. Nothing gets installed on the machines it manages
(the **managed nodes**: your Windchill servers). All the software lives on one
machine, the **control node**. It connects out to each managed node over
WinRM or SSH, pushes a small PowerShell script, runs it, and collects the
result. When the run is over nothing is left running anywhere.

The catch: the control node must be Linux or macOS. Windows cannot be a
control node. On a Windows PC that leaves two options:

| Option | Pros | Cons |
|---|---|---|
| **Docker** (used here) | reproducible, one command, same image for everyone | Docker Desktop must be running |
| WSL (Ubuntu) | feels native, fast | you install and update Ansible yourself |

## Option A: Docker

1. Start Docker Desktop.
2. Build the image once (and again whenever `docker/Dockerfile` or
   `requirements.yml` change):

   ```powershell
   docker compose build
   ```

   What goes in: Python, `ansible-core`, `pywinrm` (WinRM support),
   `ansible-lint`, and the collections from `requirements.yml`.
3. Run any Ansible command by prefixing it:

   ```powershell
   docker compose run --rm ansible ansible --version
   ```

   `bin/ansible.ps1` saves the typing:

   ```powershell
   .\bin\ansible.ps1 ansible --version
   .\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml
   .\bin\ansible.ps1            # no arguments = a shell inside the container
   ```

4. Optional: an alias in your PowerShell profile (`notepad $PROFILE`):

   ```powershell
   function wa { & "C:\git\ansible\bin\ansible.ps1" @args }
   ```

   then `wa ansible-playbook tutorial/playbooks/01_ping.yml`.

How it fits together: `docker-compose.yml` mounts this folder at `/work`
inside the container, so edits you make on Windows are visible immediately.
The container reaches your own PC under the name `host.docker.internal`,
which is why the lab inventory uses that address.

Two quirks worth knowing:

- **File sharing prompt.** The first time the container mounts `C:\git\ansible`,
  Docker Desktop may pop up "Share it?" (or, with the Hyper-V backend, the
  command simply waits until you answer). Click *Share it*, or add `C:\git`
  once under *Settings ▸ Resources ▸ File sharing*. Until that is done every
  `docker compose run` appears to hang.
- **World-writable directory.** Ansible refuses to auto-load `ansible.cfg`
  from a directory that looks world-writable, and bind-mounted Windows
  folders look that way inside Linux. `docker-compose.yml` therefore sets
  `ANSIBLE_CONFIG=/work/ansible.cfg` explicitly.

## Option B: WSL

```bash
sudo apt update && sudo apt install -y python3-venv
python3 -m venv ~/ansible-venv && source ~/ansible-venv/bin/activate
pip install "ansible-core>=2.17" pywinrm ansible-lint
cd /mnt/c/git/ansible
ansible-galaxy collection install -r requirements.yml
export ANSIBLE_CONFIG=$PWD/ansible.cfg     # same world-writable quirk as above
ansible --version
```

Everything else in the lessons is identical; just drop the `.\bin\ansible.ps1` prefix.

## Check your work

```powershell
.\bin\ansible.ps1 ansible --version
.\bin\ansible.ps1 ansible-galaxy collection list
```

You should see `config file = /work/ansible.cfg` in the first output and
`ansible.windows` plus `community.windows` in the second.

## Project tour

```
ansible.cfg          settings Ansible reads on every run (inventory path, output format)
requirements.yml     collections (add-on module packages) to install
docker/, docker-compose.yml, bin/   the control node
inventory/           which machines, in which environment, with which settings
config/              Windchill configuration content (rule bodies, ...)
(roles)              live in the sibling repo ansible-collection-windchill (lesson 09)
playbooks/           what to run: numbered ones are lessons, the rest is real
lab/                 the fake Windchill
tutorial/                these lessons
```

Next: [01 - How Ansible thinks](01-concepts.md)
