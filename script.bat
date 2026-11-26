@echo off
setlocal
if "%~1"=="" (
  echo Usage: %~nx0 "Full Name" 1>&2
  exit /b 1
)
set "TARGET_NAME=%*"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_FILE=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = [System.IO.File]::ReadAllText($env:SCRIPT_FILE, [System.Text.UTF8Encoding]::new($false)); $parts = [regex]::Split($c, '(?m)^#__PS_START__\r?$'); Invoke-Expression $parts[1]"
exit /b %errorlevel%

#__PS_START__
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$rawName = ($env:TARGET_NAME -replace '^"|"$', '').Trim()
$cleanName = (($rawName -split '\s+') | Where-Object { $_ -ne '' }) -join ' '
if ([string]::IsNullOrWhiteSpace($cleanName)) {
  throw 'Name cannot be empty.'
}

$nameParts = $cleanName -split '\s+'
if ($nameParts.Count -eq 1) {
  $initials = $nameParts[0].Substring(0, [Math]::Min(2, $nameParts[0].Length)).ToUpper()
} else {
  $initials = ($nameParts[0].Substring(0, 1) + $nameParts[-1].Substring(0, 1)).ToUpper()
}

$compactName = (($nameParts | ForEach-Object {
  if ($_.Length -gt 1) { $_.Substring(0, 1).ToUpper() + $_.Substring(1) } else { $_.ToUpper() }
}) -join '') -replace '[^A-Za-z0-9_-]', ''
if ([string]::IsNullOrEmpty($compactName)) { $compactName = 'User' }

$escapedName = [System.Net.WebUtility]::HtmlEncode($cleanName)
$escapedCompact = [System.Net.WebUtility]::HtmlEncode($compactName)
$urlUser = [Uri]::EscapeDataString($compactName)
$urlInitials = [Uri]::EscapeDataString($initials)

function Mutate-HexId {
  param([string]$Value, [int]$Count = 2)
  $hex = '0123456789ABCDEF'.ToCharArray()
  $chars = $Value.ToUpper().ToCharArray()
  $indices = New-Object System.Collections.Generic.List[int]
  for ($i = 0; $i -lt $chars.Length; $i++) {
    if ($hex -contains $chars[$i]) { $indices.Add($i) }
  }
  $chosen = $indices | Get-Random -Count ([Math]::Min($Count, $indices.Count))
  foreach ($idx in $chosen) {
    $alts = $hex | Where-Object { $_ -ne $chars[$idx] }
    $chars[$idx] = $alts | Get-Random
  }
  return -join $chars
}

$root = $env:SCRIPT_DIR.TrimEnd('\', '/')
$indexPath = Join-Path $root 'index.html'
$vercelPath = Join-Path $root 'vercel.json'

$content = [System.IO.File]::ReadAllText($indexPath, $utf8NoBom)

$credMatch = [regex]::Match($content, 'Credential ID:\s*([0-9A-Fa-f]{16})')
$certMatch = [regex]::Match($content, 'Certification number:\s*([0-9A-Fa-f]{6}-[0-9A-Fa-f]{6})')
if (-not $credMatch.Success -or -not $certMatch.Success) {
  throw 'Could not find Credential ID or Certification number in index.html.'
}

$oldCredId = $credMatch.Groups[1].Value
$oldCertNum = $certMatch.Groups[1].Value
$newCredId = Mutate-HexId -Value $oldCredId -Count 2
$newCertNum = Mutate-HexId -Value $oldCertNum -Count 2

$script:nTitle = 0
$content = [regex]::Replace($content, '(<title>Credentials - )[^|<]+( \| Microsoft Learn</title>)', {
  param($m)
  $script:nTitle++
  $m.Groups[1].Value + $escapedCompact + $m.Groups[2].Value
})

$script:nAvatar = 0
$content = [regex]::Replace($content, "(fill='%23FFF' %3E)[A-Za-z0-9]{1,3}(%3C/text%3E)", {
  param($m)
  $script:nAvatar++
  $m.Groups[1].Value + $urlInitials + $m.Groups[2].Value
})

$script:nIssuance = 0
$content = [regex]::Replace($content, '(<a href="/users/)[^"/]+(/">\s*<h3[^>]*><!---->)[^<]+(<!----></h3>)', {
  param($m)
  $script:nIssuance++
  $m.Groups[1].Value + $urlUser + $m.Groups[2].Value + $escapedName + $m.Groups[3].Value
})

$script:nHero = 0
$content = [regex]::Replace($content, '(<div id="credential-hero-body"[^>]*>[\s\S]*?<h3[^>]*>\s*<!---->)[^<]+(<!----></h3>)', {
  param($m)
  $script:nHero++
  $m.Groups[1].Value + $escapedName + $m.Groups[2].Value
})

$script:nCred = 0
$content = [regex]::Replace($content, '(Credential ID:\s*)[0-9A-Fa-f]{16}', {
  param($m)
  $script:nCred++
  $m.Groups[1].Value + $newCredId
})

$script:nCert = 0
$content = [regex]::Replace($content, '(Certification number:\s*)[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}', {
  param($m)
  $script:nCert++
  $m.Groups[1].Value + $newCertNum
})

$newTarget = [Uri]::EscapeDataString("https://learn.microsoft.com/en-us/users/$($compactName.ToLower())/credentials/$($newCredId.ToLower())")
$content = [regex]::Replace($content, '(href="/en-us/locale\?target=)[^"]+(")', {
  param($m)
  $m.Groups[1].Value + $newTarget + $m.Groups[2].Value
})

if ($script:nTitle -lt 1 -or $script:nAvatar -lt 1 -or $script:nIssuance -lt 1 -or $script:nHero -lt 1 -or $script:nCred -lt 2 -or $script:nCert -lt 2) {
  throw "Unexpected replacement counts: title=$script:nTitle, avatar=$script:nAvatar, issuance=$script:nIssuance, hero=$script:nHero, cred=$script:nCred, cert=$script:nCert"
}

[System.IO.File]::WriteAllText($indexPath, $content, $utf8NoBom)

if (Test-Path -LiteralPath $vercelPath) {
  $vercelObj = ([System.IO.File]::ReadAllText($vercelPath, $utf8NoBom)) | ConvertFrom-Json
  foreach ($rule in $vercelObj.redirects) {
    if ($rule.source -eq '/') {
      $rule.destination = "/api/credentials/share/en-us/$urlUser/$($newCredId.ToLower())"
    }
  }
  $vercelJson = ($vercelObj | ConvertTo-Json -Depth 10) + "`n"
  [System.IO.File]::WriteAllText($vercelPath, $vercelJson, $utf8NoBom)
}

Write-Host "Updated name: $cleanName (initials: $initials, slug: $compactName)"
Write-Host "Credential ID:        $oldCredId -> $newCredId ($script:nCred occurrences)"
Write-Host "Certification number: $oldCertNum -> $newCertNum ($script:nCert occurrences)"
