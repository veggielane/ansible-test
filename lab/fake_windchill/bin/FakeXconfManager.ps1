<#
  FakeXconfManager.ps1 - stands in for `xconfmanager` in the lab.

  Understands the subset the properties role uses, with the real tool's shape:
      xconfmanager -s name=value [-s ...] -t <targetFile>     record overrides in site.xconf
      xconfmanager --reset name                               drop an override
      xconfmanager -d name                                    describe the current value
      xconfmanager -p                                         propagate site.xconf into the property files

  State lives in <WT_HOME>\site.xconf (same XML shape as the real one, minus
  the DOCTYPE). Propagation writes <WT_HOME>\<targetFile> as key=value lines.
  Exit code 0 on success, 1 on a usage error.
#>
$ErrorActionPreference = 'Stop'
$wtHome = Split-Path -Parent $PSScriptRoot
$sitePath = Join-Path $wtHome 'site.xconf'
$argv = @($args)

function Load-Site {
    if (Test-Path -LiteralPath $sitePath) {
        $doc = New-Object System.Xml.XmlDocument
        $doc.Load($sitePath)
        return $doc
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml('<?xml version="1.0" encoding="UTF-8"?><Configuration targetFile="codebase/wt.properties"></Configuration>')
    return $doc
}

$sets = @(); $resets = @(); $describes = @(); $target = 'codebase/wt.properties'; $propagate = $false
for ($i = 0; $i -lt $argv.Count; $i++) {
    switch -Regex ($argv[$i]) {
        '^(-s|--set)$'       { $i++; $sets += $argv[$i] }
        '^(-t|--targetfile)$' { $i++; $target = $argv[$i] }
        '^--reset$'          { $i++; $resets += $argv[$i] }
        '^(-d|--describe)$'  { $i++; $describes += $argv[$i] }
        '^(-p|--propagate)$' { $propagate = $true }
        '^(-F|--force)$'     { }
        default              { Write-Output "xconfmanager: unrecognised argument '$($argv[$i])'"; exit 1 }
    }
}

$doc = Load-Site
$root = $doc.DocumentElement
$changed = $false

foreach ($pair in $sets) {
    $eq = $pair.IndexOf('=')
    if ($eq -lt 1) { Write-Output "xconfmanager: -s expects name=value, got '$pair'"; exit 1 }
    $name = $pair.Substring(0, $eq); $value = $pair.Substring($eq + 1)
    $node = $root.SelectSingleNode("Property[@name='$name']")
    if (-not $node) {
        $node = $doc.CreateElement('Property')
        $node.SetAttribute('name', $name)
        $node.SetAttribute('overridable', 'true')
        $root.AppendChild($node) | Out-Null
    }
    $node.SetAttribute('targetFile', $target)
    $node.SetAttribute('value', $value)
    Write-Output "Setting property $name to '$value' in $target"
    $changed = $true
}

foreach ($name in $resets) {
    $node = $root.SelectSingleNode("Property[@name='$name']")
    if ($node) { $root.RemoveChild($node) | Out-Null; Write-Output "Reset property $name to its declared default" }
    else { Write-Output "Property $name has no site value to reset" }
    $changed = $true
}

foreach ($name in $describes) {
    $node = $root.SelectSingleNode("Property[@name='$name']")
    if ($node) { Write-Output "$name=$($node.GetAttribute('value'))  [site.xconf -> $($node.GetAttribute('targetFile'))]" }
    else { Write-Output "$name is not set in site.xconf (declared default applies)" }
}

if ($changed) { $doc.Save($sitePath) }

if ($propagate) {
    $byFile = @{}
    foreach ($p in $root.SelectNodes('Property')) {
        $f = $p.GetAttribute('targetFile'); if (-not $byFile.ContainsKey($f)) { $byFile[$f] = @() }
        $byFile[$f] += "$($p.GetAttribute('name'))=$($p.GetAttribute('value'))"
    }
    foreach ($f in $byFile.Keys) {
        $out = Join-Path $wtHome ($f -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
        Set-Content -LiteralPath $out -Value ($byFile[$f] | Sort-Object) -Encoding ASCII
        Write-Output "Propagated $($byFile[$f].Count) properties to $f"
    }
    if ($byFile.Count -eq 0) { Write-Output 'Nothing to propagate' }
}
exit 0
