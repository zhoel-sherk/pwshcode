<#
.SYNOPSIS
    Init prompt: Oh My Posh (tokyonight) → Starship (Tokyo Night) → fallback.
    Sourced by profile.ps1. Configs are auto-detected from sibling directory.
#>

if ($script:PwshCodePromptInit) { return }
$script:PwshCodePromptInit = $true
$script:PromptDir = $PSScriptRoot
$script:IsAdmin = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ─── Oh My Posh (preferred) ─────────────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompConfig = Join-Path $PromptDir 'omp-tokyonight.json'
    if (Test-Path $ompConfig) {
        if ($script:IsAdmin) {
            $host.UI.RawUI.WindowTitle = "ADMIN - $((Get-Location).Path)"
        }
        oh-my-posh init pwsh --config $ompConfig | Invoke-Expression
        return
    }
}

# ─── Starship (fallback) ────────────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $configFile = if ($script:IsAdmin) { 'starship-admin.toml' } else { 'starship.toml' }
    $configPath = Join-Path $PromptDir $configFile
    if (Test-Path $configPath) {
        $env:STARSHIP_CONFIG = $configPath
    }

    if ($script:IsAdmin) {
        $host.UI.RawUI.WindowTitle = "ADMIN - $((Get-Location).Path)"
    }

    Invoke-Expression (&starship init powershell)
    return
}

# ─── Fallback: minimal prompt ───────────────────────────────
function prompt { "PS $($ExecutionContext.SessionState.Path.CurrentLocation)> " }
