#Requires -Version 7.0
<#
.SYNOPSIS
    Устанавливает pwshcode: профиль PowerShell 7 + opencode skills для AI агентов.
.DESCRIPTION
    - Копирует profile.ps1 в $env:USERPROFILE\pwshcode\
    - Устанавливает все opencode skills в $env:USERPROFILE\.config\opencode\skills\
    - Показывает дальнейшие шаги (добавление в $PROFILE, установка winget-зависимостей)
#>

[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

# ─── Targets ────────────────────────────────────────────────
$ProfileTargetDir = "$env:USERPROFILE\pwshcode"
$SkillsTargetDir  = "$env:USERPROFILE\.config\opencode\skills"

# ─── Profile ────────────────────────────────────────────────
Write-Host "`n[1/2] Installing profile.ps1 ..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $ProfileTargetDir)) {
    if ($WhatIf) {
        Write-Host "  would create $ProfileTargetDir" -ForegroundColor DarkGray
    } else {
        New-Item -ItemType Directory -Path $ProfileTargetDir -Force | Out-Null
        Write-Host "  created $ProfileTargetDir" -ForegroundColor Green
    }
}

$profileFiles = @('profile.ps1', 'requirements-winget.txt', 'Install-WingetRequirements.ps1')
foreach ($file in $profileFiles) {
    $src = Join-Path $RepoRoot $file
    $dst = Join-Path $ProfileTargetDir $file
    if (-not (Test-Path $src)) {
        Write-Warning "  $file not found at $src, skipping"
        continue
    }
    if ($WhatIf) {
        Write-Host "  would copy $file -> $dst" -ForegroundColor DarkGray
    } else {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  copied $file" -ForegroundColor Green
    }
}

# ─── Skills ─────────────────────────────────────────────────
Write-Host "[2/2] Installing opencode skills ..." -ForegroundColor Cyan

$skillDirs = Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'skills') -Directory
if (-not $skillDirs) {
    Write-Warning "  No skill directories found in $RepoRoot\skills"
} else {
    foreach ($skillDir in $skillDirs) {
        $target = Join-Path $SkillsTargetDir $skillDir.Name
        if ($WhatIf) {
            Write-Host "  would install $($skillDir.Name) -> $target" -ForegroundColor DarkGray
        } else {
            if (-not (Test-Path $target)) {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
            }
            # Copy only SKILL.md and reference.md (no nested repos, no scripts)
            foreach ($file in @('SKILL.md', 'reference.md')) {
                $src = Join-Path $skillDir.FullName $file
                if (Test-Path $src) {
                    Copy-Item -Path $src -Destination (Join-Path $target $file) -Force
                }
            }
            Write-Host "  installed $($skillDir.Name)" -ForegroundColor Green
        }
    }
}

# ─── Summary ────────────────────────────────────────────────
Write-Host "`n=== Setup complete ===" -ForegroundColor Cyan

if (-not $WhatIf) {
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "  1. Add to `$PROFILE (%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1):" -ForegroundColor White
    Write-Host "     . `"$ProfileTargetDir\profile.ps1`"" -ForegroundColor Gray
    Write-Host "  2. Install winget dependencies (if not done yet):" -ForegroundColor White
    Write-Host "     & `"$ProfileTargetDir\Install-WingetRequirements.ps1`"" -ForegroundColor Gray
    Write-Host "  3. Restart opencode to load new skills" -ForegroundColor White
    Write-Host "  4. Verify: opencode sees 6 skills (pwsh-profile, python-env-manager, pwsh-idioms, git-conventions, just-recipes, project-scaffold)" -ForegroundColor Gray
}
