<#
.SYNOPSIS
  Run any Ansible command inside the Docker control node, from PowerShell.

.EXAMPLE
  .\bin\ansible.ps1 ansible --version
  .\bin\ansible.ps1 ansible-playbook tutorial/playbooks/01_ping.yml
  .\bin\ansible.ps1 ansible-vault encrypt inventory/group_vars/windchill/vault.yml
  .\bin\ansible.ps1 bash            # drop into a shell inside the container

.NOTES
  Tip: add this to your PowerShell $PROFILE so you can type `wa ansible-playbook ...`:
    function wa { & "C:\git\ansible\bin\ansible.ps1" @args }
#>
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    if ($args.Count -eq 0) { $args = @('bash') }
    docker compose run --rm ansible @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
