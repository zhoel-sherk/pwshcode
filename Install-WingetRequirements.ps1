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
    winget install -e --id $id `
        --accept-package-agreements `
        --accept-source-agreements `
        --disable-interactivity

    if ($LASTEXITCODE -eq 0) {
        Write-Host "ok    $id" -ForegroundColor Green
        $installed++
    } else {
        Write-Host "fail  $id (exit $LASTEXITCODE)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nDone: installed=$installed skipped=$skipped failed=$failed" -ForegroundColor Cyan
if ($failed -gt 0) { exit 1 }
