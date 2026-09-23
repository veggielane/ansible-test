<#
  FakeLoadFromFile.ps1 - stands in for `windchill wt.load.LoadFromFile` in the lab.

  bin\windchill.cmd calls it with the same arguments the real launcher gets:
      windchill wt.load.LoadFromFile -d <file> -u <user> -p <password> [-CONT_PATH <path>] [-UNATTENDED] [-NOSERVERSTOP]

  It imitates the real utility's habits so the Ansible role can be exercised honestly:
    * chatty stdout, and exit code 0 EVEN WHEN THE LOAD FAILS (the real one is
      unreliable about exit codes too) - callers must scan the output
    * validates that the DOCTYPE's DTD exists under <WT_HOME>\loadXMLFiles
    * "loaded" rules are written to <WT_HOME>\fakedb\oir\<container>\<rule>.xml
    * password "wrong"  -> authentication failure
    * no -u / -p        -> pretends to open a login dialog and hangs for 90 s

  No param() block on purpose: every argument lands in $args as-is, so
  switches like -CONT_PATH are parsed here instead of by PowerShell.
#>
$ErrorActionPreference = 'Stop'
$wtHome = Split-Path -Parent $PSScriptRoot
$argv = @($args)
$class = if ($argv.Count -gt 0) { $argv[0] } else { '' }

Write-Output "Fake Windchill 13.0 (lab)  WT_HOME=$wtHome"
if ($class -ne 'wt.load.LoadFromFile') {
    Write-Output "Error: Could not find or load main class $class"
    exit 1
}

# --- parse options the way the real utility does ---------------------------
$opt = @{}
$flags = @()
for ($i = 1; $i -lt $argv.Count; $i++) {
    $a = $argv[$i]
    if ($a -in @('-d', '-u', '-p', '-CONT_PATH')) {
        $i++
        $opt[$a.ToUpper()] = if ($i -lt $argv.Count) { $argv[$i] } else { $null }
    }
    elseif ($a -like '-*') {
        $flags += $a.ToUpper()
    }
    else {
        Write-Output "java.lang.ArrayIndexOutOfBoundsException: unexpected argument '$a'"
        exit 0
    }
}
$d = $opt['-D']; $u = $opt['-U']; $p = $opt['-P']
$container = if ($opt['-CONT_PATH']) { $opt['-CONT_PATH'] } else { '/wt.inf.container.ExchangeContainer=Site' }
Write-Output "wt.load.LoadFromFile: file=$d user=$u container=$container flags=$($flags -join ' ')"

if (-not $d) {
    Write-Output 'wt.util.WTException: Missing required argument -d <data file>'
    exit 0
}
if (-not (Test-Path -LiteralPath $d)) {
    Write-Output "java.io.FileNotFoundException: $d (The system cannot find the file specified)"
    exit 0
}
if (-not $u -or -not $p) {
    Write-Output 'No credentials given: opening the login dialog ... (this is where a real load hangs forever)'
    Start-Sleep -Seconds 90
    Write-Output 'Login dialog cancelled.'
    exit 0
}
if ($p -eq 'wrong') {
    Write-Output "wt.util.WTException: Authentication failed for user '$u'"
    exit 0
}

# --- DTD check: the real loader validates against <WT_HOME>\loadXMLFiles\<dtd> ---
$raw = Get-Content -Raw -LiteralPath $d
if ($raw -match '<!DOCTYPE\s+\w+\s+SYSTEM\s+"([^"]+)"') {
    $dtd = $Matches[1]
    if (-not (Test-Path -LiteralPath (Join-Path $wtHome "loadXMLFiles\$dtd"))) {
        Write-Output "java.io.FileNotFoundException: $wtHome\loadXMLFiles\$dtd (DTD referenced by the load file was not found)"
        exit 0
    }
}

# --- Parse the load file (without resolving the DTD) -----------------------
try {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $reader = [System.Xml.XmlReader]::Create($d, $settings)
    $xml = New-Object System.Xml.XmlDocument
    $xml.Load($reader)
    $reader.Close()
}
catch {
    Write-Output "org.xml.sax.SAXParseException: $($_.Exception.Message)"
    exit 0
}

$rules = $xml.SelectNodes('//csvTypeBasedRule')
if ($rules.Count -eq 0) {
    Write-Output "No csv* load elements found in $d - nothing loaded"
    exit 0
}

$n = 0
foreach ($rule in $rules) {
    $handler = $rule.GetAttribute('handler')
    if ($handler -ne 'wt.rule.LoadRule.createTypeBasedRule') {
        Write-Output "wt.load.LoadFromFile: no such handler '$handler' for element <csvTypeBasedRule>"
        exit 0
    }
    $name = $rule.SelectSingleNode('csvname').InnerText
    $type = $rule.SelectSingleNode('csvtype').InnerText
    $ruleType = if ($rule.SelectSingleNode('csvruleType')) { $rule.SelectSingleNode('csvruleType').InnerText } else { 'INIT' }
    $enabled = if ($rule.SelectSingleNode('csvenabled')) { $rule.SelectSingleNode('csvenabled').InnerText } else { 'true' }
    $target = if ($rule.SelectSingleNode('csvcontainerPath')) { $rule.SelectSingleNode('csvcontainerPath').InnerText } else { $container }
    $body = $rule.SelectSingleNode('csvcontent').InnerText

    try { [xml]$bodyXml = $body }
    catch {
        Write-Output "wt.rule.RuleException: content of rule '$name' is not well-formed XML: $($_.Exception.Message)"
        exit 0
    }
    $objType = $bodyXml.DocumentElement.GetAttribute('objType')
    $typeClass = ($type -split '\|')[1]
    if ($objType -and $typeClass -and $objType -ne $typeClass) {
        Write-Output "Warning: rule '$name' is for $type but its content says objType=$objType"
    }

    $safeTarget = $target -replace '[^A-Za-z0-9_.=-]', '_'
    $safeName = $name -replace '[^A-Za-z0-9_.-]', '_'
    $dir = Join-Path $wtHome "fakedb\oir\$safeTarget"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dest = Join-Path $dir "$safeName.xml"
    $verb = if (Test-Path -LiteralPath $dest) { 'Updated' } else { 'Created' }
    Set-Content -LiteralPath $dest -Value $body -Encoding UTF8
    Write-Output "$verb TypeBasedRule '$name' (type=$type, ruleType=$ruleType, enabled=$enabled) in $target"
    $n++
}

Write-Output "Load completed: $n rule(s) processed."
exit 0
