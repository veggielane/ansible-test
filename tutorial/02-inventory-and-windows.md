# Lesson 02 - Inventory, environments and talking to Windows

**Goal:** `win_ping` answers `pong` from your own PC (the lab), and you know
how to add your dev, PPE and live servers.

## The inventory

`inventory/hosts.yml` names the machines and puts them in groups:

```
all
└── windchill          every Windchill server, whatever the environment
    ├── lab            fakewc      = your PC, running the fake Windchill
    ├── dev            wcdev01
    ├── ppe            wcppe01
    └── live           wclive01
```

A group is just a name you can target and attach variables to. Groups nest:
`dev` is a child of `windchill`, so `wcdev01` is in both.

## Where variables live

Ansible loads variables from files named after groups and hosts:

| File | Applies to | Use for |
|---|---|---|
| `group_vars/all.yml` | everything | project-wide paths |
| `group_vars/windchill/*.yml` | every Windchill server | how to connect, WT_HOME, admin user, **the rule list** |
| `group_vars/<env>/vars.yml` | one environment | what differs there (paths, org name) |
| `group_vars/<env>/vault.yml` | one environment | that environment's passwords (lesson 06) |
| `host_vars/<host>.yml` | one server | rare per-server quirks |

A folder instead of a file (`group_vars/windchill/`) means "load every YAML
file in here", which lets you keep one file per topic (`vars.yml`, `oir.yml`,
later `lifecycles.yml`).

Precedence, simplified: more specific wins. `host_vars` beats
`group_vars/<env>` beats `group_vars/windchill` beats `group_vars/all` beats a
role's `defaults`. Anything given on the command line with `-e` beats them all.

See it for yourself:

```powershell
.\bin\ansible.ps1 ansible-inventory --graph
.\bin\ansible.ps1 ansible-inventory --host wcdev01      # every variable, fully resolved
.\bin\ansible.ps1 ansible-inventory --host fakewc
```

## Choosing an environment

Every playbook starts with

```yaml
hosts: "{{ target | default('lab') }}"
```

so it runs against the lab unless you say otherwise:

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml                  # lab
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml -e target=dev
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml -e target=live
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml -e target=windchill   # all four, deliberately
```

`target` can be a group or a host name. A forgotten option lands on the lab,
never on live.

## Connection settings

These are ordinary variables, set once for the `windchill` group in
`group_vars/windchill/vars.yml`:

```yaml
ansible_connection: winrm
ansible_port: 5986
ansible_winrm_transport: ntlm
ansible_winrm_server_cert_validation: ignore
ansible_user: "{{ vault_windows_user }}"
ansible_password: "{{ vault_windows_password }}"
```

The user and password point at `vault_*` variables that each environment
defines in its own `vault.yml`. NTLM works with a local administrator account
or a domain account (`DOMAIN\user`). Kerberos single sign-on is possible but
needs extra packages in the container; start with NTLM.

## Prepare a Windows target

Do this on each machine Ansible should manage. For the lab that is **your
own PC**. Run in an **elevated** PowerShell (Run as administrator):

```powershell
# 1. Turn on remoting. -SkipNetworkProfileCheck is needed on Windows 10/11
#    when the network is classed "Public".
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# 2. An HTTPS listener with a self-signed certificate
$cert = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME, 'host.docker.internal' -CertStoreLocation Cert:\LocalMachine\My
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $cert.Thumbprint -Force

# 3. Let the port through the firewall
New-NetFirewallRule -DisplayName 'WinRM HTTPS (Ansible)' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -Profile Any

# 4. Let a LOCAL administrator account be an administrator over the network
#    (without this, only the built-in "Administrator" works)
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -Value 1 -PropertyType DWord -Force

# 5. Look at the result
winrm enumerate winrm/config/listener
```

PTC-style servers are usually domain-joined; step 4 is then unnecessary and
a domain admin account works as-is.

**Sign in with a Microsoft account on your PC?** WinRM wants a classic local
account. Create one just for Ansible and put it in `group_vars/lab/vault.yml`:

```powershell
New-LocalUser ansible -Password (Read-Host -AsSecureString 'Password') -PasswordNeverExpires
Add-LocalGroupMember -Group Administrators -Member ansible
```

Ansible also ships a script that does all of the above with more options:
`ConfigureRemotingForAnsible.ps1` (search that name; it lives in the
ansible-documentation repository on GitHub).

## Test it

```powershell
.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml
# or, without a playbook ("ad-hoc"):
.\bin\ansible.ps1 ansible lab -m ansible.windows.win_ping
```

Expected: `fakewc | SUCCESS => { "changed": false, "ping": "pong" }`.

## When it does not work

| Message | Meaning | Fix |
|---|---|---|
| `the specified credentials were rejected by the server` | wrong user/password, or a local admin without step 4 | check `vault.yml`; run step 4; try a dedicated local account |
| `Connection refused` / timeout on 5986 | no HTTPS listener, firewall, wrong address | steps 2-3; `Test-NetConnection -ComputerName <host> -Port 5986` from another machine |
| `certificate verify failed` | cert validation on with a self-signed cert | `ansible_winrm_server_cert_validation: ignore` for non-live |
| `basic auth not supported` / `unsupported transport` | transport mismatch | keep `ansible_winrm_transport: ntlm` |
| `winrm or requests is not installed` | pywinrm missing on the control node | `docker compose build` |
| `world writable directory ... ignoring it as an ansible.cfg source` | see lesson 00 | run via `bin/ansible.ps1` (sets ANSIBLE_CONFIG) |
| host.docker.internal unreachable | Docker cannot see the host | Docker Desktop settings, or use the PC's LAN IP |

Add `-vvv` to any command to see the connection attempt in detail.

## The SSH alternative

Windows 10/11 and Server 2019+ ship an OpenSSH server. If your organisation
prefers SSH, on the target:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Set-Service sshd -StartupType Automatic; Start-Service sshd
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force
```

and in `group_vars/windchill/vars.yml` swap block A for block B
(`ansible_connection: ssh`, `ansible_shell_type: powershell`).

## Add your real servers

1. Put the real names/addresses in `inventory/hosts.yml` under `dev`, `ppe`, `live`.
2. Per environment, fill in `group_vars/<env>/vault.yml` (then encrypt it, lesson 06).
3. If WT_HOME or the organisation name differ per environment, set them in
   `group_vars/<env>/vars.yml`; otherwise leave the shared values in
   `group_vars/windchill/vars.yml`.
4. `.\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml -e target=dev`

Next: [03 - Your first playbook](03-first-playbook.md)
