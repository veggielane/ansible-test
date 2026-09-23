# Lesson 06 - Vault: passwords in git, safely

**Goal:** the `vault.yml` files are encrypted, Ansible still runs without
prompting, and no secret ever appears in the output.

## The idea

`ansible-vault` encrypts a whole YAML file with a password. Ansible decrypts
it in memory at run time. The encrypted file is safe to commit; the vault
password is not, so it lives in a file that git ignores (`.vault_pass`, see
`.gitignore`).

The project already keeps secrets apart from settings: every secret is in a
`vault.yml`, named `vault_*`, and referenced from `vars.yml`:

```yaml
# group_vars/windchill/vars.yml     (plain, committed)
ansible_password: "{{ vault_windows_password }}"

# group_vars/dev/vault.yml          (encrypted, committed)
vault_windows_password: 'the real one'
```

That way `grep vault_` shows exactly what is secret, and error messages name
`ansible_password` rather than the value.

## Do it

```powershell
# 1. Pick a vault password and store it (this file is git-ignored)
Set-Content -NoNewline .vault_pass 'a-long-random-passphrase'

# 2. Tell Ansible where it is: uncomment in ansible.cfg
#    vault_password_file = .vault_pass

# 3. Put the real values in, then encrypt (repeat per environment)
.\bin\ansible.ps1 ansible-vault encrypt inventory/group_vars/lab/vault.yml
.\bin\ansible.ps1 ansible-vault encrypt inventory/group_vars/dev/vault.yml
```

Open one of them: it now starts with `$ANSIBLE_VAULT;1.1;AES256`. Playbooks
run exactly as before.

## Day to day

| Command | Purpose |
|---|---|
| `ansible-vault view FILE` | print decrypted |
| `ansible-vault edit FILE` | edit in place (uses `$EDITOR` inside the container: `nano`/`vi`) |
| `ansible-vault decrypt FILE` | back to plain text (to edit in your own editor, then `encrypt` again) |
| `ansible-vault rekey FILE` | change the vault password |
| `ansible-vault encrypt_string 'secret' --name vault_x` | encrypt one value to paste into a plain file |

Editing from Windows tools is easiest as decrypt → edit → encrypt. Just
never commit in between; a pre-commit check is a good idea:

```powershell
git diff --cached --name-only | Select-String 'vault.yml' | ForEach-Object {
  if (-not (Select-String -Path $_ -Pattern '^\$ANSIBLE_VAULT' -Quiet)) { throw "$_ is not encrypted" }
}
```

## One password or one per environment?

One vault password for lab/dev/ppe and a different one for live is a common
compromise. Ansible supports several at once through vault IDs:

```powershell
.\bin\ansible.ps1 ansible-vault encrypt --vault-id live@.vault_pass_live inventory/group_vars/live/vault.yml
.\bin\ansible.ps1 ansible-playbook playbooks/site.yml -e target=live --vault-id .vault_pass --vault-id live@.vault_pass_live
```

Start with one; add the second when live goes real.

## Keeping secrets out of the output

Encryption protects the file, not the screen. Two habits:

- `no_log: true` on any task whose arguments or result contain a secret. The
  LoadFromFile task in `roles/common/tasks/load_file.yml` does this
  because the command line carries `-p <password>`.
- Never `debug` a variable that holds a secret, and remember `-v` prints
  full task results.

## Exercise

Encrypt `inventory/group_vars/lab/vault.yml`, run `01_ping.yml`, then change
the password inside with `ansible-vault edit` to something wrong and run
again. Read the error, then fix it. You now know what a credential failure
looks like.

Next: [07 - The OIR role, end to end](07-windchill-oir-role.md)
