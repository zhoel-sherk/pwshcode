#Requires -Version 7.0
<#
.SYNOPSIS
    Installs all packages from requirements-winget.txt via winget.
.DESCRIPTION
    Skips blank lines, comments, and section headers. Skips packages already
    listed by winget list --id.
#>
[CmdletBinding()]
param(
    [string]$RequirementsFile = (Join-Path $PSScriptRoot 'requirements-winget.txt'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget not found. Install App Installer from Microsoft Store.'
}

if (-not (Test-Path $RequirementsFile)) {
    throw "Requirements file not found: $RequirementsFile"
}

$ids = [System.Collections.Generic.List[string]]::new()

Get-Content $RequirementsFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    if ($line -match '^\[') { return }
    [void]$ids.Add($line)
}

function Test-WingetInstalled {
    param([string]$Id)
    $null -ne (winget list --id $Id --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id)
}

$installed = 0
$skipped = 0
$failed = 0

foreach ($id in $ids) {
    if (Test-WingetInstalled -Id $id) {
        Write-Host "skip  $id (already installed)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    if ($WhatIf) {
        Write-Host "would install $id" -ForegroundColor Cyan
        continue
    }

    Write-Host "install $id ..." -ForegroundColor Yellow
    $retries = 3
    $ok = $false
    for ($r = 1; $r -le $retries; $r++) {
        if ($r -gt 1) {
            $wait = 5
            Write-Host "   retry $r/$retries after ${wait}s..." -ForegroundColor DarkYellow
            Start-Sleep -Seconds $wait
        }
        winget install -e --id $id `
            --accept-package-agreements `
            --accept-source-agreements `
            --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $ok = $true; break }
        Write-Host "   exit $LASTEXITCODE" -ForegroundColor DarkRed
    }

    if ($ok) {
        Write-Host "ok    $id" -ForegroundColor Green
        $installed++
    } else {
        Write-Host "fail  $id" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nDone: installed=$installed skipped=$skipped failed=$failed" -ForegroundColor Cyan
if ($failed -gt 0) { exit 1 }
