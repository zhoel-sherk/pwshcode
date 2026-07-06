#!/usr/bin/env pwsh
#Requires -Version 7.0
param([switch]$WhatIf)
<#
.SYNOPSIS
    pwshcode installer — interactive TUI для установки профиля PowerShell 7
    и opencode skills на Windows.
.DESCRIPTION
    Работает в двух режимах:
      1. Локально:  .\install.ps1
      2. Из сети:   irm https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main/install.ps1 | iex

    Показывает меню: выбор скиллов, настройка $PROFILE, установка winget-зависимостей.
#>

#region ─── Bootstrap: web vs local ─────────────────────────
$IS_WEB = [string]::IsNullOrEmpty($PSScriptRoot) -or $MyInvocation.MyCommand.Path -like '*Invoke-Expression*'
$REPO_URL = 'https://github.com/zhoel-sherk/pwshcode.git'
$RAW_URL  = 'https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main'

if ($IS_WEB) {
    $tmpDir = "$env:TEMP\pwshcode-install-$([System.IO.Path]::GetRandomFileName())"
    $null = New-Item -ItemType Directory -Path $tmpDir -Force

    # Try ZIP download first (fast, no git needed)
    $zipUrl = "https://github.com/zhoel-sherk/pwshcode/archive/main.zip"
    $zipPath = "$tmpDir\repo.zip"
    Write-Host "`n ⏳ Скачиваю pwshcode..." -ForegroundColor Cyan
    Write-Muted "   $zipUrl"

    $zipOk = $false
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        if ((Get-Item $zipPath).Length -gt 1000) {
            Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force -ErrorAction Stop
            $repoRoot = Get-ChildItem -LiteralPath $tmpDir -Directory | Select-Object -First 1 -ExpandProperty FullName
            if ($repoRoot) { $zipOk = $true }
        }
    } catch {
        Write-Warn "ZIP download failed: $_"
    }

    # Fallback: git clone
    if (-not $zipOk) {
        Write-Muted "   Пробую git clone..."
        $gitDir = "$tmpDir\pwshcode"
        try {
            git clone $REPO_URL $gitDir 2>&1 | Out-Null
            $repoRoot = $gitDir
            if (Test-Path "$repoRoot\install.ps1") { $zipOk = $true }
        } catch {
            Write-Host "   git clone тоже не сработал: $_" -ForegroundColor Red
        }
    }

    if (-not $zipOk) {
        Write-Host " ✘ Не удалось загрузить репозиторий. Проверьте:" -ForegroundColor Red
        Write-Host "   1. Доступ к github.com (файрвол/прокси?)" -ForegroundColor Red
        Write-Host "   2. Установлен ли git (для fallback)" -ForegroundColor Red
        Write-Host "   3. Затем запустите: git clone $REPO_URL" -ForegroundColor Red
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
        exit 1
    }
    Write-OK "Репозиторий загружен"
} else {
    $repoRoot = $PSScriptRoot
}
#endregion

#region ─── ANSI helpers ─────────────────────────────────────
$ESC = [char]27
$C = @{}
$C.Reset   = "$ESC[0m"
$C.Bold    = "$ESC[1m"
$C.Dim     = "$ESC[2m"
$C.Reverse = "$ESC[7m"
$C.Red     = "$ESC[91m"
$C.Green   = "$ESC[92m"
$C.Yellow  = "$ESC[93m"
$C.Blue    = "$ESC[94m"
$C.Magenta = "$ESC[95m"
$C.Cyan    = "$ESC[96m"
$C.White   = "$ESC[97m"
$C.Grey    = "$ESC[90m"

function Write-Muted   { param($Msg) Write-Host "$($C.Grey)$Msg$($C.Reset)" }
function Write-Step    { param($Msg) Write-Host "`n $($C.Bold)$($C.Cyan)◆$($C.Reset) $($C.Bold)$Msg$($C.Reset)" }
function Write-OK      { param($Msg) Write-Host "   $($C.Green)✔$($C.Reset) $Msg" }
function Write-Fail    { param($Msg) Write-Host "   $($C.Red)✘$($C.Reset) $Msg" }
function Write-Info    { param($Msg) Write-Host "   $($C.Blue)ℹ$($C.Reset) $Msg" }
function Write-Warn    { param($Msg) Write-Host "   $($C.Yellow)⚠$($C.Reset) $Msg" }
function Clear-Screen  { [Console]::Clear() }
function Show-Cursor   { [Console]::CursorVisible = $true }
function Hide-Cursor   { [Console]::CursorVisible = $false }

function Prompt-YesNo($Question, $Default = $true) {
    $def = if ($Default) { "Y/n" } else { "y/N" }
    while ($true) {
        Write-Host "   $($C.Bold)$Question [$($C.Cyan)$def$($C.Reset)$($C.Bold)]$($C.Reset) " -NoNewline
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter')  { return $Default }
        if ($k.KeyChar -in 'y','Y') { return $true }
        if ($k.KeyChar -in 'n','N') { return $false }
    }
}

function Read-String($Prompt, $Default) {
    Write-Host "   $($C.Bold)$Prompt$($C.Reset) [$($C.Cyan)$Default$($C.Reset)]: " -NoNewline
    $input = [Console]::ReadLine()
    if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
    return $input.Trim()
}

function Show-ProgressBar($Percent, $Label = "") {
    if (-not $script:pbLastLen) { $script:pbLastLen = 0 }
    $w = [Math]::Floor([Console]::WindowWidth * 0.35)
    $filled = [Math]::Floor($w * $Percent / 100)
    $empty = $w - $filled
    $bar = "$($C.Green)$('#' * $filled)$($C.Grey)$('-' * $empty)$($C.Reset)"
    $pct = "$($C.Cyan)$([Math]::Floor($Percent))%$($C.Reset)"
    $line = "   $bar $pct $Label"
    Write-Host "`r$line" -NoNewline
    $script:lastLen = $line.Length
}
#endregion

#region ─── Banner ───────────────────────────────────────────
$BANNER = @"
$($C.Bold)$($C.Magenta)
     ██████╗ ██╗    ██╗███████╗██╗  ██╗ ██████╗ ██████╗ ██████╗ ███████╗
     ██╔══██╗██║    ██║██╔════╝██║  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝
     ██████╔╝██║ █╗ ██║███████╗███████║██║     ██║   ██║██║  ██║█████╗
     ██╔═══╝ ██║███╗██║╚════██║██╔══██║██║     ██║   ██║██║  ██║██╔══╝
     ██║     ╚███╔███╔╝███████║██║  ██║╚██████╗╚██████╔╝██████╔╝███████╗
     ╚═╝      ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
$($C.Reset)
$($C.Dim)  PowerShell 7 + opencode skills installer$($C.Reset)
$($C.Dim)  https://github.com/zhoel-sherk/pwshcode$($C.Reset)

"@
#endregion

#region ─── Prerequisites ────────────────────────────────────
function Test-Prerequisites {
    $ok = $true
    Write-Step "Проверка окружения"

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-OK "PowerShell $($PSVersionTable.PSVersion.ToString())"
    } else {
        Write-Fail "PowerShell 7+ required"
        $ok = $false
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK "winget"
    } else {
        Write-Fail "winget не найден — установите App Installer из Microsoft Store"
        $ok = $false
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-OK "git $((git --version 2>$null) -replace 'git version ')"
    } else {
        Write-Warn "git не найден — будет установлен через winget"
    }

    $oc = if ($env:OPENCODE_PATH) { $env:OPENCODE_PATH } else {
        Get-Command opencode, opencode.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    }
    if ($oc) {
        Write-OK "opencode ($oc)"
    } else {
        Write-Warn "opencode не найден — скиллы будут установлены на будущее"
    }

    try {
        $null = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com' -UseBasicParsing -TimeoutSec 5 -Method Head
        Write-OK "Доступ к GitHub"
    } catch {
        Write-Fail "Нет доступа к GitHub — проверьте интернет"
        $ok = $false
    }

    if (-not $ok) {
        Write-Fail "Окружение не готово. Исправьте ошибки и запустите снова."
        Write-Host "`n   Нажмите любую клавишу для выхода..."
        $null = [Console]::ReadKey($true)
        exit 1
    }
}
#endregion

#region ─── Interactive menus ────────────────────────────────
function Show-MenuRadio($Title, $Options, $DefaultIndex = 0) {
    $sel = $DefaultIndex
    $opts = @($Options)
    Write-Host "`n   $($C.Bold)$Title$($C.Reset)"
    $top = [Console]::CursorTop
    Hide-Cursor
    try {
        while ($true) {
            for ($i = 0; $i -lt $opts.Count; $i++) {
                [Console]::SetCursorPosition(3, $top + $i)
                $mark = if ($i -eq $sel) { "$($C.Cyan)◉$($C.Reset)" } else { "$($C.Grey)○$($C.Reset)" }
                $label = if ($opts[$i] -is [hashtable]) { $opts[$i].label } else { $opts[$i] }
                $suffix = if ($i -eq $sel) { "$($C.Reverse)$label$($C.Reset)" } else { "$($C.Grey)$label$($C.Reset)" }
                Write-Host "$mark $suffix" -NoNewline
                Write-Host (' ' * [Math]::Max(0, [Console]::WindowWidth - [Console]::CursorLeft))
            }
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'UpArrow' -and $sel -gt 0) { $sel-- }
            elseif ($key.Key -eq 'DownArrow' -and $sel -lt $opts.Count - 1) { $sel++ }
            elseif ($key.Key -eq 'Enter') { break }
        }
    } finally { Show-Cursor }
    Write-Host ""
    return $sel
}

function Show-MenuCheckbox($Title, $Options) {
    $states = @($Options | ForEach-Object { $true })
    $idx = 0
    $opts = @($Options)
    Write-Host "`n   $($C.Bold)$Title$($C.Reset)"
    Write-Muted "   (↑↓ навигация, Space — переключить, Enter — OK)"
    $top = [Console]::CursorTop + 1
    Hide-Cursor
    try {
        while ($true) {
            [Console]::SetCursorPosition(0, $top)
            for ($i = 0; $i -lt $opts.Count; $i++) {
                [Console]::SetCursorPosition(3, $top + $i)
                $box = if ($states[$i]) { "$($C.Green)☑$($C.Reset)" } else { "$($C.Grey)☐$($C.Reset)" }
                if ($opts[$i] -is [hashtable]) {
                    $label = $opts[$i].label
                    $desc = if ($opts[$i].desc) { " $($C.Dim)$($opts[$i].desc)$($C.Reset)" } else { "" }
                } else { $label = $opts[$i]; $desc = "" }
                $suffix = if ($i -eq $idx) { "$($C.Reverse)$label$($C.Reset)$desc" } else { "$label$desc" }
                Write-Host "$box $suffix" -NoNewline
                Write-Host (' ' * [Math]::Max(0, [Console]::WindowWidth - [Console]::CursorLeft))
            }
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq 'UpArrow' -and $idx -gt 0) { $idx-- }
            elseif ($key.Key -eq 'DownArrow' -and $idx -lt $opts.Count - 1) { $idx++ }
            elseif ($key.Key -eq 'Spacebar') { $states[$idx] = -not $states[$idx] }
            elseif ($key.Key -eq 'Enter') { break }
        }
    } finally { Show-Cursor }
    Write-Host ""
    return $states
}
#endregion

#region ─── Install logic ────────────────────────────────────
function Install-ProfileFiles($RepoRoot, $TargetDir) {
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    $files = @('profile.ps1', 'requirements-winget.txt', 'Install-WingetRequirements.ps1')
    for ($i = 0; $i -lt $files.Count; $i++) {
        $src = Join-Path $RepoRoot $files[$i]
        $dst = Join-Path $TargetDir $files[$i]
        if (Test-Path $src) { Copy-Item -Path $src -Destination $dst -Force }
        Show-ProgressBar ([Math]::Floor(($i + 1) / $files.Count * 100)) $files[$i]
    }
    Write-Host ""
    Write-OK "Файлы профиля → $TargetDir"
}

function Install-Skills($RepoRoot, $TargetDir, $Selection) {
    $allSkills = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'skills') -Directory)
    $selected = @()
    for ($i = 0; $i -lt $allSkills.Count; $i++) { if ($Selection[$i]) { $selected += $allSkills[$i] } }
    if ($selected.Count -eq 0) { Write-Warn "Скиллы не выбраны"; return }
    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null }
    for ($i = 0; $i -lt $selected.Count; $i++) {
        $skill = $selected[$i]
        $skillTarget = Join-Path $TargetDir $skill.Name
        if (-not (Test-Path $skillTarget)) { New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null }
        foreach ($file in @('SKILL.md', 'reference.md')) {
            $src = Join-Path $skill.FullName $file
            if (Test-Path $src) { Copy-Item -Path $src -Destination (Join-Path $skillTarget $file) -Force }
        }
        Show-ProgressBar ([Math]::Floor(($i + 1) / $selected.Count * 100)) $skill.Name
    }
    Write-Host ""
    Write-OK "Скиллов: $($selected.Count) / $($allSkills.Count)"
}

function Setup-Profile($Choice, $ProfilePath) {
    $line = ". `"$env:USERPROFILE\pwshcode\profile.ps1`""
    if ($Choice -eq 0) {
        if (Test-Path $ProfilePath) {
            $content = Get-Content $ProfilePath -Raw
            if ($content -match [regex]::Escape($line)) { Write-OK "Строка уже есть в `$PROFILE"; return }
            Add-Content -Path $ProfilePath -Value "`n$line" -NoNewline
        } else { Set-Content -Path $ProfilePath -Value $line }
        Write-OK "Добавлено в `$PROFILE ($ProfilePath)"
    } elseif ($Choice -eq 1) {
        if (Test-Path $ProfilePath) {
            $backup = "$ProfilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -Path $ProfilePath -Destination $backup -Force
            Write-OK "Бэкап: $backup"
        }
        Set-Content -Path $ProfilePath -Value $line
        Write-OK "`$PROFILE заменён"
    }
}

function Install-WingetDeps($RepoRoot) {
    $script = Join-Path $RepoRoot 'Install-WingetRequirements.ps1'
    if (Test-Path $script) { Write-Step "Winget-зависимости"; & $script @args }
    else {     Write-Fail "Install-WingetRequirements.ps1 не найден" }
}

function Install-ContextCompressor($RepoRoot, $Choice, $Threshold) {
    if ($Choice -eq 2) { Write-Warn "Компрессор отключён"; return }

    # ─── Plugin ────────────────────────────────────────────────
    $pluginDir = "$env:USERPROFILE\.config\opencode\plugins"
    $pluginSrc = Join-Path $RepoRoot 'plugins' 'context-compressor.ts'
    if (Test-Path $pluginSrc) {
        if (-not (Test-Path $pluginDir)) { New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null }
        Copy-Item -Path $pluginSrc -Destination (Join-Path $pluginDir 'context-compressor.ts') -Force
        Write-OK "Plugin → $pluginDir\context-compressor.ts"
    } else {
        Write-Warn "plugins/context-compressor.ts не найден"
    }

    # ─── Skill ─────────────────────────────────────────────────
    $skillSrc = Join-Path $RepoRoot 'skills' 'context-compressor'
    $skillDir = "$env:USERPROFILE\.config\opencode\skills\context-compressor"
    if (Test-Path $skillSrc) {
        if (-not (Test-Path $skillDir)) { New-Item -ItemType Directory -Path $skillDir -Force | Out-Null }
        Copy-Item -Path (Join-Path $skillSrc 'SKILL.md') -Destination (Join-Path $skillDir 'SKILL.md') -Force
        Write-OK "Skill → $skillDir\SKILL.md"
    } else {
        Write-Warn "skills/context-compressor/ не найден"
    }

    # ─── Threshold ─────────────────────────────────────────────
    if ($Choice -eq 0) {
        $env:CONTEXT_COMPRESSOR_THRESHOLD = "$Threshold"
        Write-OK "Порог сжатия: $Threshold токенов"
    }

    if ($Choice -eq 0) { Write-OK "Режим: Auto (plugin + skill)" }
    else { Write-OK "Режим: Manual (skill only)" }
}
#endregion

#region ─── Main ─────────────────────────────────────────────
Clear-Screen
Write-Host $BANNER
Write-Muted "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')  |  режим: $(if ($IS_WEB) { 'web' } else { 'local' })"
Write-Host ""

Test-Prerequisites

# ─── Install location ──────────────────────────────────────
Write-Step "Расположение установки"
$defaultDir = "$env:USERPROFILE\pwshcode"
$installDir = Read-String "Куда установить pwshcode?" $defaultDir

# ─── Copy repo to target if web mode ───────────────────────
if ($IS_WEB) {
    Write-Step "Копирование в $installDir"
    if (Test-Path $installDir) {
        if (-not (Prompt-YesNo "Директория $installDir уже существует. Перезаписать?" $false)) {
            Write-Warn "Установка отменена"
            Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
            exit 0
        }
        Remove-Item -Recurse -Force "$installDir\*" -ErrorAction SilentlyContinue
    } else { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    if ((Resolve-Path $repoRoot).Path -ne (Resolve-Path $installDir).Path) {
        Get-ChildItem -LiteralPath $repoRoot -Exclude '.git' | Copy-Item -Destination $installDir -Recurse -Force
    }
    $repoRoot = $installDir
    Write-OK "Скопировано в $installDir"
}

# ─── Profile setup ─────────────────────────────────────────
Write-Step "Настройка `$PROFILE"
$profilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
$profileChoice = Show-MenuRadio "Действие с `$PROFILE:" @(
    @{label = "Добавить строку (рекомендуется)" }
    @{label = "Заменить полностью (с бэкапом)" }
    @{label = "Пропустить" }
)

# ─── Skills selection ──────────────────────────────────────
$skillDir = Join-Path $repoRoot 'skills'
$allSkills = @(Get-ChildItem -LiteralPath $skillDir -Directory -ErrorAction SilentlyContinue)
$skillSelections = @()
if ($allSkills.Count -eq 0) {
    Write-Warn "Папка skills/ не найдена"
} else {
    $skillOptions = $allSkills | ForEach-Object {
        $desc = switch ($_.Name) {
            'pwsh-profile'      { "state, deps, xray, inspect, venc, quoting pitfalls" }
            'python-env-manager' { ".venv, ruff, pytest, mypy, uv, pip-audit, pre-commit" }
            'pwsh-idioms'       { "PowerShell quoting, call operator, `$LASTEXITCODE" }
            'git-conventions'   { "Conventional commits, branch naming, gh PR" }
            'just-recipes'      { "Justfile: format, lint, test, build, clean" }
            'project-scaffold'  { "pyproject.toml, package.json, tsconfig шаблоны" }
            default             { "opencode skill" }
        }
        @{ label = $_.Name; desc = $desc }
    }
    $skillSelections = Show-MenuCheckbox "Выберите скиллы для opencode:" $skillOptions
}

# ─── Context compressor selection ────────────────────────────
Write-Step "Контекстный компрессор (PAKT)"
$compressorHelp = @"
   PAKT — сжатие JSON/YAML/CSV/.md в pipe-формат.
   Экономия токенов до 50% на структурированных данных.
   Подробнее: skills/context-compressor/SKILL.md
"@
Write-Muted $compressorHelp

$compressorChoice = Show-MenuRadio "Режим работы:" @(
    @{label = "Auto — plugin + skill"; desc = "автоматическое сжатие tool output'ов" }
    @{label = "Manual — только skill"; desc = "модель сама решает когда сжимать" }
    @{label = "Отключить" }
)

$compressThreshold = 200
if ($compressorChoice -le 1) {
    $thresholdInput = Read-String "Порог сжатия в токенах (ниже — не сжимать)" "200"
    if ($thresholdInput -match '^\d+$') { $compressThreshold = [int]$thresholdInput }
}
Write-Host ""

# ─── Prompt selection ───────────────────────────────────────
Write-Step "Выбор промипта"
$promptChoice = Show-MenuRadio "Какой промипт установить?" @(
    @{label = "Oh My Posh (tokyonight)"; desc = "красивый, много сегментов" }
    @{label = "Starship (Tokyo Night)";  desc = "как у автора, лёгкий и быстрый" }
    @{label = "None — минимальный PS>"; desc = "без промипта" }
)

# ─── Winget deps ───────────────────────────────────────────
Write-Step "Winget-зависимости"
$wingetExtra = if ($promptChoice -eq 0) { ' + oh-my-posh' } elseif ($promptChoice -eq 1) { ' + starship' } else { '' }
$installWinget = Prompt-YesNo "Установить winget-пакеты (jq, delta, uv, just, yq, rg, fd, bat, eza, zoxide, gsudo$wingetExtra)?" $true

# ─── Review ────────────────────────────────────────────────
Clear-Screen
Write-Host $BANNER
Write-Step "Проверьте настройки"
Write-Info "Директория:     $installDir"
$profileLabels = @('добавить в $PROFILE', 'заменить $PROFILE', 'пропустить')
Write-Info "Профиль:        $($profileLabels[$profileChoice])"
$chosenSkills = @()
for ($i = 0; $i -lt $allSkills.Count; $i++) { if ($skillSelections[$i]) { $chosenSkills += $allSkills[$i].Name } }
Write-Info "Скиллы:         $(if ($chosenSkills.Count -gt 0) { "$($chosenSkills.Count): $($chosenSkills -join ', ')" } else { 'не выбраны' })"
$promptLabels = @('Oh My Posh (tokyonight)', 'Starship (Tokyo Night)', 'None')
$compressorLabels = @('Auto (plugin + skill)', "Manual (skill only)", 'отключён')
$compressorDetail = if ($compressorChoice -le 1) { " [$compressThreshold токенов]" } else { "" }
Write-Info "Компрессор:     $($compressorLabels[$compressorChoice])$compressorDetail"
Write-Info "Промипт:        $($promptLabels[$promptChoice])"
Write-Info "Winget:         $(if ($installWinget) { 'да' } else { 'нет' })"
if (-not (Prompt-YesNo "Всё верно? Начинаем установку" $true)) {
    Write-Warn "Отменено"
    if ($IS_WEB) { Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue }
    exit 0
}

# ─── Install ───────────────────────────────────────────────
Install-ProfileFiles -RepoRoot $repoRoot -TargetDir $installDir

if ($allSkills.Count -gt 0) {
    Write-Step "Установка opencode skills"
    Install-Skills -RepoRoot $repoRoot -TargetDir "$env:USERPROFILE\.config\opencode\skills" -Selection $skillSelections
}

# ─── Context compressor ────────────────────────────────────
Write-Step "Установка контекстного компрессора"
Install-ContextCompressor -RepoRoot $repoRoot -Choice $compressorChoice -Threshold $compressThreshold

# ─── Prompt config ─────────────────────────────────────────
Write-Step "Установка промипта"
$promptTarget = Join-Path $installDir 'prompt'
if (-not (Test-Path $promptTarget)) { New-Item -ItemType Directory -Path $promptTarget -Force | Out-Null }
Copy-Item -Path (Join-Path $repoRoot 'prompt\init.ps1') -Destination $promptTarget -Force

if ($promptChoice -eq 0) {
    # Oh My Posh
    Copy-Item -Path (Join-Path $repoRoot 'prompt\omp-tokyonight.json') -Destination $promptTarget -Force
    Write-OK "Oh My Posh (tokyonight)"
} elseif ($promptChoice -eq 1) {
    # Starship
    Copy-Item -Path (Join-Path $repoRoot 'prompt\starship.toml') -Destination $promptTarget -Force
    Copy-Item -Path (Join-Path $repoRoot 'prompt\starship-admin.toml') -Destination $promptTarget -Force
    Write-OK "Starship (Tokyo Night)"
} else {
    Write-OK "Промипт не выбран — минимальный PS>"
}

if ($profileChoice -le 1) {
    Write-Step "Настройка `$PROFILE"
    Setup-Profile -Choice $profileChoice -ProfilePath $profilePath
}

if ($installWinget) {
    Install-WingetDeps -RepoRoot $repoRoot -WhatIf:$WhatIf
    if ($promptChoice -eq 0) {
        # Install oh-my-posh separately
        Write-Step "Установка Oh My Posh"
        winget install -e --id JanDeDobbeleer.OhMyPosh --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK "oh-my-posh установлен" } else { Write-Warn "oh-my-posh: exit $LASTEXITCODE (возможно уже есть)" }
    }
}

# ─── Cleanup web temp ──────────────────────────────────────
if ($IS_WEB) { Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue }

# ─── Done ──────────────────────────────────────────────────
Clear-Screen
Write-Host $BANNER
Write-Host ""
Write-Host "   $($C.Bold)$($C.Green)╔══════════════════════════════════╗$($C.Reset)"
Write-Host "   $($C.Bold)$($C.Green)║     Установка завершена! 🎉       ║$($C.Reset)"
Write-Host "   $($C.Bold)$($C.Green)╚══════════════════════════════════╝$($C.Reset)"
Write-Host ""

Write-Step "Что дальше"
Write-Info "1. Перезапустите opencode"
Write-Info "2. Убедитесь что профиль подключён:"
Write-Muted "     . `"$installDir\profile.ps1`""
if ($profileChoice -eq 2) {
    Write-Muted "   Добавьте эту строку в `$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}
if ($chosenSkills.Count -gt 0) {
    Write-Info "3. Скиллы готовы к использованию:"
    foreach ($s in $chosenSkills) { Write-Muted "     • $s" }
}
if ($compressorChoice -le 1) {
    Write-Info "4. Context Compressor $($compressorLabels[$compressorChoice]) — порог $compressThreshold токенов"
    Write-Muted "     Перезапустите opencode для активации"
}
Write-Host ""

if ($IS_WEB) {
    Write-Muted "   Репозиторий скопирован в: $installDir"
    Write-Muted "   Для обновления: git pull или запустите install.ps1 повторно"
    Write-Host ""
}

Write-Host "   Нажмите любую клавишу для выхода..."
$null = [Console]::ReadKey($true)
#endregion
