#!/usr/bin/env pwsh
#Requires -Version 7.0
param([switch]$WhatIf)
<#
.SYNOPSIS
    pwshcode installer — interactive TUI for PowerShell 7 profile setup
    and opencode skills on Windows.
.DESCRIPTION
    Works in two modes:
      1. Local:    .\install.ps1
      2. Remote:   irm https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main/install.ps1 | iex

    Shows menus: skill selection, $PROFILE setup, winget dependencies installation.
#>

#region ─── Pre-check: pwsh version ────────────────────────────
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "`n ⚠ $($L.pwshTooOld -f $PSVersionTable.PSVersion.ToString())" -ForegroundColor Yellow
    if (Prompt-YesNo $L.offerPwsh7) {
        Write-Info $L.installingPwsh7
        if (-not $WhatIf) {
            winget install --id Microsoft.PowerShell --silent --accept-package-agreements --disable-interactivity 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK $L.pwsh7Installed
                $args = if ($WhatIf) { @('-WhatIf') } else { @() }
                pwsh -NoProfile -File "$PSCommandPath" @args
                exit 0
            } else { Write-Warn ($L.pwsh7Failed -f $LASTEXITCODE); exit 1 }
        }
    } else { exit 1 }
}
#endregion

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
    Write-Host "`n ⏳ $($L.webDownload)" -ForegroundColor Cyan
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
        Write-Warn ($L.webZipFailed -f $_)
    }

    # Fallback: git clone
    if (-not $zipOk) {
        Write-Muted "   $($L.webGitClone)"
        $gitDir = "$tmpDir\pwshcode"
        try {
            git clone $REPO_URL $gitDir 2>&1 | Out-Null
            $repoRoot = $gitDir
            if (Test-Path "$repoRoot\install.ps1") { $zipOk = $true }
        } catch {
            Write-Host ($L.webGitFailed -f $_) -ForegroundColor Red
        }
    }

    if (-not $zipOk) {
        Write-Host " ✘ $($L.webFailed)" -ForegroundColor Red
        Write-Host " $($L.webCheck1)" -ForegroundColor Red
        Write-Host " $($L.webCheck2)" -ForegroundColor Red
        Write-Host (" $($L.webCheck3 -f $REPO_URL)") -ForegroundColor Red
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
        exit 1
    }
    Write-OK $L.webDownloadOk
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
function Clear-Screen  { try { [Console]::Clear() } catch {} }
function Show-Cursor   { try { [Console]::CursorVisible = $true } catch {} }
function Hide-Cursor   { try { [Console]::CursorVisible = $false } catch {} }
function Invoke-SafeReadKey {
    try { return [Console]::ReadKey($true) }
    catch { return @{ Key = 'Enter'; KeyChar = "`r" } }
}
function Invoke-SafeReadLine {
    try { return [Console]::ReadLine() }
    catch { return "" }
}
function Set-SafeCursorPosition($Left, $Top) {
    try {
        $bh = try { [Console]::BufferHeight } catch { 9999 }
        $bw = try { [Console]::BufferWidth } catch { 120 }
        [Console]::SetCursorPosition([Math]::Min($Left, $bw - 1), [Math]::Min($Top, $bh - 1))
    } catch {}
}
function Get-SafeWindowWidth {
    try { return [Console]::WindowWidth } catch { return 80 }
}
function Get-SafeCursorTop {
    try { return [Console]::CursorTop } catch { return 0 }
}
function Get-SafeCursorLeft {
    try { return [Console]::CursorLeft } catch { return 0 }
}
function Copy-SafeItem($Path, $Destination) {
    $src = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (-not $src) { return }
    $dst = Resolve-Path $Destination -ErrorAction SilentlyContinue
    if ($dst) {
        if ($src.Path -eq $dst.Path) { return }
        if ((Get-Item $dst).PSIsContainer) {
            $target = Join-Path $dst.Path (Split-Path $Path -Leaf)
            $tgtResolved = Resolve-Path $target -ErrorAction SilentlyContinue
            if ($tgtResolved -and ($src.Path -eq $tgtResolved.Path)) { return }
        }
    }
    Copy-Item -Path $Path -Destination $Destination -Force -ErrorAction SilentlyContinue
}

function Prompt-YesNo($Question, $Default = $true) {
    $def = if ($Default) { "Y/n" } else { "y/N" }
    while ($true) {
        Write-Host "   $($C.Bold)$Question [$($C.Cyan)$def$($C.Reset)$($C.Bold)]$($C.Reset) " -NoNewline
        $k = Invoke-SafeReadKey
        if ($k.Key -eq 'Enter')  { return $Default }
        if ($k.KeyChar -in 'y','Y') { return $true }
        if ($k.KeyChar -in 'n','N') { return $false }
    }
}

function Read-String($Prompt, $Default) {
    Write-Host "   $($C.Bold)$Prompt$($C.Reset) [$($C.Cyan)$Default$($C.Reset)]: " -NoNewline
    $input = Invoke-SafeReadLine
    if ([string]::IsNullOrWhiteSpace($input)) { return $Default }
    return $input.Trim()
}

function Show-ProgressBar($Percent, $Label = "") {
    if (-not $script:pbLastLen) { $script:pbLastLen = 0 }
    $w = [Math]::Floor((Get-SafeWindowWidth) * 0.35)
    $filled = [Math]::Floor($w * $Percent / 100)
    $empty = $w - $filled
    $bar = "$($C.Green)$('#' * $filled)$($C.Grey)$('-' * $empty)$($C.Reset)"
    $pct = "$($C.Cyan)$([Math]::Floor($Percent))%$($C.Reset)"
    $line = "   $bar $pct $Label"
    Write-Host "`r$line" -NoNewline
    $script:pbLastLen = $line.Length
}
#endregion

#region ─── I18n / Language strings ──────────────────────────
$RU = @{
  langName = "Русский"
  enName = "English"
  chooseLang = "Выберите язык / Choose language:"

  checkEnv = "Проверка окружения"
  pwshVer = "PowerShell {0}"
  winget = "winget"
  git = "git {0}"
  opencode = "opencode ({0})"
  githubAccess = "Доступ к GitHub"
  envFail = "Окружение не готово. Исправьте ошибки и запустите снова."
  pressAnyKey = "Нажмите любую клавишу для выхода..."
  wingetNotFound = "winget не найден — установите App Installer из Microsoft Store"
  gitWarn = "git не найден — будет установлен через winget"
  opencodeWarn = "opencode не найден — скиллы будут установлены на будущее"
  noGithub = "Нет доступа к GitHub — проверьте интернет"

  installLoc = "Расположение установки"
  askInstallDir = "Куда установить pwshcode?"
  dirExists = "Директория {0} уже существует. Перезаписать?"
  installCancelled = "Установка отменена"
  dirCopied = "Скопировано в {0}"

  profileSetup = "Настройка `$PROFILE"
  profileAction = "Действие с `$PROFILE:"
  profileAdd = "Добавить строку (рекомендуется)"
  profileReplace = "Заменить полностью (с бэкапом)"
  profileSkip = "Пропустить"
  profileAlready = "Строка уже есть в `$PROFILE"
  profileAdded = "Добавлено в `$PROFILE ({0})"
  profileBackup = "Бэкап: {0}"
  profileReplaced = "`$PROFILE заменён"

  navUpDownCheck = "(↑↓ навигация, Space — переключить, Enter — OK)"
  selectSkills = "Выберите скиллы для opencode:"
  noSkills = "Папка skills/ не найдена"
  notSelected = "не выбраны"
  skillsSummary = "Скиллов: {0} / {1}"

  descPwshProfile = "state, deps, xray, inspect, venc, quoting pitfalls"
  descPythonEnv = ".venv, ruff, pytest, mypy, uv, pip-audit, pre-commit"
  descPwshIdioms = "PowerShell quoting, call operator, `$LASTEXITCODE"
  descGitConventions = "Conventional commits, branch naming, gh PR"
  descJustRecipes = "Justfile: format, lint, test, build, clean"
  descProjectScaffold = "pyproject.toml, package.json, tsconfig шаблоны"
  defaultDesc = "opencode skill"

  compressorTitle = "Контекстный компрессор (PAKT)"
  compressorHelp = @"
   PAKT — сжатие JSON/YAML/CSV/.md в pipe-формат.
   Экономия токенов до 50% на структурированных данных.
   Подробнее: skills/context-compressor/SKILL.md
"@
  compressorMode = "Режим работы:"
  compressorAuto = "Auto — plugin + skill"
  compressorManual = "Manual — только skill"
  compressorOff = "Отключить"
  compressorAutoDesc = "автоматическое сжатие tool output'ов"
  compressorManualDesc = "модель сама решает когда сжимать"
  compressorThreshold = "Порог сжатия в токенах (ниже — не сжимать)"
  compressorAutoMode = "Auto (plugin + skill)"
  compressorManualMode = "Manual (skill only)"
  compressorOffMode = "отключён"
  compressorTokens = " [{0} токенов]"
  pluginNotFound = "plugins/context-compressor.ts не найден"
  skillNotFound = "skills/context-compressor/ не найден"
  thresholdSet = "Порог сжатия: {0} токенов"
  modeAuto = "Режим: Auto (plugin + skill)"
  modeManual = "Режим: Manual (skill only)"
  compressorDisabled = "Компрессор отключён"

  promptTitle = "Выбор промипта"
  promptChoice = "Какой промипт установить?"
  promptOmp = "Oh My Posh (tokyonight)"
  promptStarship = "Starship (Tokyo Night)"
  promptNone = "None — минимальный PS>"
  promptOmpDesc = "красивый, много сегментов"
  promptStarshipDesc = "как у автора, лёгкий и быстрый"
  promptNoneDesc = "без промипта"
  promptOmpOk = "Oh My Posh (tokyonight)"
  promptStarshipOk = "Starship (Tokyo Night)"
  promptNoneOk = "Промипт не выбран — минимальный PS>"

  wingetDepsTitle = "Winget-зависимости"
  wingetQuestion = "Установить winget-пакеты (jq, delta, uv, just, yq, rg, fd, bat, eza, zoxide, gsudo{0})?"
  ohmyposhOk = "oh-my-posh установлен"
  ohmyposhFail = "oh-my-posh: exit {0} (возможно уже есть)"
  wingetScriptNotFound = "Install-WingetRequirements.ps1 не найден"

  reviewTitle = "Проверьте настройки"
  reviewDir = "Директория:     {0}"
  reviewProfile = "Профиль:        {0}"
  reviewSkills = "Скиллы:         {0}"
  reviewCompressor = "Компрессор:     {0}"
  reviewPrompt = "Промипт:        {0}"
  reviewWinget = "Winget:         {0}"
  confirmStart = "Всё верно? Начинаем установку"
  cancelled = "Отменено"
  yesLabel = "да"
  noLabel = "нет"

  installingProfile = "Файлы профиля → {0}"
  installingSkills = "Установка opencode skills"
  installingCompressor = "Установка контекстного компрессора"
  installingPrompt = "Установка промипта"

  doneTitle = "Установка завершена!"
  whatNext = "Что дальше"
  restartOpencode = "Перезапустите opencode"
  verifyProfile = "Убедитесь что профиль подключён:"
  addToProfile = "Добавьте эту строку в {0}"
  skillsReady = "Скиллы готовы к использованию:"
  compressorInfo = "Context Compressor {0} — порог {1} токенов"
  restartToActivate = "Перезапустите opencode для активации"
  repoCopied = "Репозиторий скопирован в: {0}"
  updateInfo = "Для обновления: git pull или запустите install.ps1 повторно"

  webDownload = "Скачиваю pwshcode..."
  webZipFailed = "ZIP download failed: {0}"
  webGitClone = "Пробую git clone..."
  webGitFailed = "git clone тоже не сработал: {0}"
  webFailed = "Не удалось загрузить репозиторий. Проверьте:"
  webCheck1 = "  1. Доступ к github.com (файрвол/прокси?)"
  webCheck2 = "  2. Установлен ли git (для fallback)"
  webCheck3 = "  3. Затем запустите: git clone {0}"
  webDownloadOk = "Репозиторий загружен"
  webMode = "режим: web"
  localMode = "режим: local"
  webOverwrite = "Директория {0} уже существует. Перезаписать?"
  webCopying = "Копирование в {0}"

  # ─── Auto-install prompts ───────────────────────────────────
  pwshTooOld = "PowerShell 7+ required (current: {0}). Установить PowerShell 7?"
  installingPwsh7 = "Устанавливаю PowerShell 7..."
  pwsh7Installed = "PowerShell 7 установлен. Перезапускаю..."
  pwsh7Failed = "PowerShell 7 не установлен: {0}"
  offerWinget = "winget не найден. Установить?"
  installingWinget = "Устанавливаю winget..."
  wingetInstalled = "winget установлен"
  wingetFailed = "winget не установлен: {0}"
  offerOpencode = "opencode не найден. Установить?"
  installingOpencode = "Устанавливаю opencode..."
  opencodeInstalled = "opencode установлен"
  opencodeFailed = "opencode не установлен: exit {0}"
  offerGit = "git не найден. Установить через winget?"
  installingGit = "Устанавливаю git..."
  gitInstalled = "git установлен"
  gitFailed = "git не установлен: exit {0}"
  offerTerminal = "Установить Windows Terminal?"
  installingTerminal = "Устанавливаю Windows Terminal..."
  terminalInstalled = "Windows Terminal установлен"
  terminalFailed = "Windows Terminal не установлен: exit {0}"
  installNow = "Установить"
  skipInstall = "Пропустить"
}
$EN = @{
  langName = "English"
  enName = "Русский"
  chooseLang = "Choose language / Выберите язык:"

  checkEnv = "Environment check"
  pwshVer = "PowerShell {0}"
  winget = "winget"
  git = "git {0}"
  opencode = "opencode ({0})"
  githubAccess = "GitHub access"
  envFail = "Environment not ready. Fix errors and run again."
  pressAnyKey = "Press any key to exit..."
  wingetNotFound = "winget not found — Install App Installer from Microsoft Store"
  gitWarn = "git not found — will be installed via winget"
  opencodeWarn = "opencode not found — skills will be installed for later use"
  noGithub = "No GitHub access — check your internet connection"

  installLoc = "Install location"
  askInstallDir = "Where to install pwshcode?"
  dirExists = "Directory {0} already exists. Overwrite?"
  installCancelled = "Installation cancelled"
  dirCopied = "Copied to {0}"

  profileSetup = "Profile setup"
  profileAction = "Action with `$PROFILE:"
  profileAdd = "Add line (recommended)"
  profileReplace = "Replace entirely (with backup)"
  profileSkip = "Skip"
  profileAlready = "Line already exists in `$PROFILE"
  profileAdded = "Added to `$PROFILE ({0})"
  profileBackup = "Backup: {0}"
  profileReplaced = "`$PROFILE replaced"

  navUpDownCheck = "(↑↓ navigate, Space — toggle, Enter — OK)"
  selectSkills = "Select opencode skills:"
  noSkills = "skills/ directory not found"
  notSelected = "none selected"
  skillsSummary = "Skills: {0} / {1}"

  descPwshProfile = "state, deps, xray, inspect, venc, quoting pitfalls"
  descPythonEnv = ".venv, ruff, pytest, mypy, uv, pip-audit, pre-commit"
  descPwshIdioms = "PowerShell quoting, call operator, `$LASTEXITCODE"
  descGitConventions = "Conventional commits, branch naming, gh PR"
  descJustRecipes = "Justfile: format, lint, test, build, clean"
  descProjectScaffold = "pyproject.toml, package.json, tsconfig templates"
  defaultDesc = "opencode skill"

  compressorTitle = "Context Compressor (PAKT)"
  compressorHelp = @"
   PAKT — compresses JSON/YAML/CSV/.md into pipe format.
   Up to 50% token savings on structured data.
   Details: skills/context-compressor/SKILL.md
"@
  compressorMode = "Mode:"
  compressorAuto = "Auto — plugin + skill"
  compressorManual = "Manual — skill only"
  compressorOff = "Disable"
  compressorAutoDesc = "automatic tool output compression"
  compressorManualDesc = "model decides when to compress"
  compressorThreshold = "Compression threshold in tokens (below — skip)"
  compressorAutoMode = "Auto (plugin + skill)"
  compressorManualMode = "Manual (skill only)"
  compressorOffMode = "disabled"
  compressorTokens = " [{0} tokens]"
  pluginNotFound = "plugins/context-compressor.ts not found"
  skillNotFound = "skills/context-compressor/ not found"
  thresholdSet = "Compression threshold: {0} tokens"
  modeAuto = "Mode: Auto (plugin + skill)"
  modeManual = "Mode: Manual (skill only)"
  compressorDisabled = "Compressor disabled"

  promptTitle = "Prompt selection"
  promptChoice = "Which prompt to install?"
  promptOmp = "Oh My Posh (tokyonight)"
  promptStarship = "Starship (Tokyo Night)"
  promptNone = "None — minimal PS>"
  promptOmpDesc = "fancy, many segments"
  promptStarshipDesc = "author's pick, lightweight"
  promptNoneDesc = "no prompt"
  promptOmpOk = "Oh My Posh (tokyonight)"
  promptStarshipOk = "Starship (Tokyo Night)"
  promptNoneOk = "No prompt selected — minimal PS>"

  wingetDepsTitle = "Winget dependencies"
  wingetQuestion = "Install winget packages (jq, delta, uv, just, yq, rg, fd, bat, eza, zoxide, gsudo{0})?"
  ohmyposhOk = "oh-my-posh installed"
  ohmyposhFail = "oh-my-posh: exit {0} (may already exist)"
  wingetScriptNotFound = "Install-WingetRequirements.ps1 not found"

  reviewTitle = "Review settings"
  reviewDir = "Directory:     {0}"
  reviewProfile = "Profile:        {0}"
  reviewSkills = "Skills:         {0}"
  reviewCompressor = "Compressor:     {0}"
  reviewPrompt = "Prompt:        {0}"
  reviewWinget = "Winget:         {0}"
  confirmStart = "Looks good? Start installation"
  cancelled = "Cancelled"
  yesLabel = "yes"
  noLabel = "no"

  installingProfile = "Profile files → {0}"
  installingSkills = "Installing opencode skills"
  installingCompressor = "Installing context compressor"
  installingPrompt = "Installing prompt"

  doneTitle = "Installation complete!"
  whatNext = "What's next"
  restartOpencode = "Restart opencode"
  verifyProfile = "Verify that the profile is sourced:"
  addToProfile = "Add this line to {0}"
  skillsReady = "Skills ready to use:"
  compressorInfo = "Context Compressor {0} — threshold {1} tokens"
  restartToActivate = "Restart opencode to activate"
  repoCopied = "Repository copied to: {0}"
  updateInfo = "To update: git pull or re-run install.ps1"

  webDownload = "Downloading pwshcode..."
  webZipFailed = "ZIP download failed: {0}"
  webGitClone = "Trying git clone..."
  webGitFailed = "git clone also failed: {0}"
  webFailed = "Failed to download repository. Check:"
  webCheck1 = "  1. Access to github.com (firewall/proxy?)"
  webCheck2 = "  2. Is git installed (for fallback)"
  webCheck3 = "  3. Then run: git clone {0}"
  webDownloadOk = "Repository downloaded"
  webMode = "mode: web"
  localMode = "mode: local"
  webOverwrite = "Directory {0} already exists. Overwrite?"
  webCopying = "Copying to {0}"

  # ─── Auto-install prompts ───────────────────────────────────
  pwshTooOld = "PowerShell 7+ required (current: {0}). Install PowerShell 7?"
  installingPwsh7 = "Installing PowerShell 7..."
  pwsh7Installed = "PowerShell 7 installed. Restarting..."
  pwsh7Failed = "PowerShell 7 not installed: {0}"
  offerWinget = "winget not found. Install it?"
  installingWinget = "Installing winget..."
  wingetInstalled = "winget installed"
  wingetFailed = "winget not installed: {0}"
  offerOpencode = "opencode not found. Install it?"
  installingOpencode = "Installing opencode..."
  opencodeInstalled = "opencode installed"
  opencodeFailed = "opencode not installed: exit {0}"
  offerGit = "git not found. Install via winget?"
  installingGit = "Installing git..."
  gitInstalled = "git installed"
  gitFailed = "git not installed: exit {0}"
  offerTerminal = "Install Windows Terminal?"
  installingTerminal = "Installing Windows Terminal..."
  terminalInstalled = "Windows Terminal installed"
  terminalFailed = "Windows Terminal not installed: exit {0}"
  installNow = "Install"
  skipInstall = "Skip"
}
#endregion

$L = $RU

#region ─── TuiEngine ─────────────────────────────────────────
. (Join-Path $PSScriptRoot 'tui-engine.ps1' -ErrorAction SilentlyContinue)
#endregion

#region ─── Prerequisites ────────────────────────────────────
function Install-Tool($Question, $WingetId, $InstallingMsg, $SuccessMsg, $FailMsg) {
    if (-not (Prompt-YesNo $Question $true)) { return $false }
    Write-Info $InstallingMsg
    if (-not $WhatIf) {
        winget install --id $WingetId --silent --accept-package-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK $SuccessMsg; return $true }
        else { Write-Warn ($FailMsg -f $LASTEXITCODE); return $false }
    } else {
        Write-Muted "  [WhatIf] winget install --id $WingetId"
        return $false
    }
}

function Test-Prerequisites {
    $ok = $true
    Write-Step $L.checkEnv

    Write-OK ($L.pwshVer -f $PSVersionTable.PSVersion.ToString())

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-OK $L.winget
    } else {
        $installed = Install-Tool $L.offerWinget 'Microsoft.DesktopAppInstaller' $L.installingWinget $L.wingetInstalled $L.wingetFailed
        if (-not (Get-Command winget -ErrorAction SilentlyContinue) -and -not $installed) {
            Write-Fail $L.wingetNotFound
            $ok = $false
        }
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-OK ($L.git -f "$((git --version 2>$null) -replace 'git version ')")
    } else {
        $installed = Install-Tool $L.offerGit 'Git.Git' $L.installingGit $L.gitInstalled $L.gitFailed
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Write-OK ($L.git -f "$((git --version 2>$null) -replace 'git version ')")
        } else { Write-Warn $L.gitWarn }
    }

    $oc = if ($env:OPENCODE_PATH) { $env:OPENCODE_PATH } else {
        Get-Command opencode, opencode.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    }
    if ($oc) {
        Write-OK ($L.opencode -f $oc)
    } else {
        $installed = Install-Tool $L.offerOpencode 'SST.opencode' $L.installingOpencode $L.opencodeInstalled $L.opencodeFailed
        if (-not $installed) { Write-Warn $L.opencodeWarn }
    }

    try {
        $null = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com' -UseBasicParsing -TimeoutSec 5 -Method Head
        Write-OK $L.githubAccess
    } catch {
        Write-Fail $L.noGithub
        $ok = $false
    }

    # Windows Terminal — always optional
    if (-not (Get-Command wt.exe -ErrorAction SilentlyContinue)) {
        $null = Install-Tool $L.offerTerminal 'Microsoft.WindowsTerminal' $L.installingTerminal $L.terminalInstalled $L.terminalFailed
    }

    if (-not $ok) {
        Write-Fail $L.envFail
        Write-Host "`n   $($L.pressAnyKey)"
        $null = Invoke-SafeReadKey
        exit 1
    }
}
#endregion

# (menu functions moved to tui-engine.ps1)

#region ─── Install logic ────────────────────────────────────
function Install-ProfileFiles {
    param($RepoRoot, $TargetDir, [switch]$WhatIf)
    if (-not (Test-Path $TargetDir)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null } }
    $files = @('profile.ps1', 'requirements-winget.txt', 'Install-WingetRequirements.ps1')
    for ($i = 0; $i -lt $files.Count; $i++) {
        $src = Join-Path $RepoRoot $files[$i]
        $dst = Join-Path $TargetDir $files[$i]
        if (Test-Path $src) { if (-not $WhatIf) { Copy-SafeItem -Path $src -Destination $dst } }
        Show-ProgressBar ([Math]::Floor(($i + 1) / $files.Count * 100)) $files[$i]
    }
    Write-Host ""
    Write-OK ($L.installingProfile -f $TargetDir)
}

function Install-Skills {
    param($RepoRoot, $TargetDir, $Selection, [switch]$WhatIf)
    $allSkills = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'skills') -Directory)
    $selected = @()
    for ($i = 0; $i -lt $allSkills.Count; $i++) { if ($Selection[$i]) { $selected += $allSkills[$i] } }
    if ($selected.Count -eq 0) { Write-Warn ($L.skillsSummary -f 0, $allSkills.Count); return }
    if (-not (Test-Path $TargetDir)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null } }
    for ($i = 0; $i -lt $selected.Count; $i++) {
        $skill = $selected[$i]
        $skillTarget = Join-Path $TargetDir $skill.Name
        if (-not (Test-Path $skillTarget)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null } }
        foreach ($file in @('SKILL.md', 'reference.md')) {
            $src = Join-Path $skill.FullName $file
            if (Test-Path $src) { if (-not $WhatIf) { Copy-Item -Path $src -Destination (Join-Path $skillTarget $file) -Force } }
        }
        Show-ProgressBar ([Math]::Floor(($i + 1) / $selected.Count * 100)) $skill.Name
    }
    Write-Host ""
    Write-OK ($L.skillsSummary -f $selected.Count, $allSkills.Count)
}

function Setup-Profile {
    param($Choice, $ProfilePath, $InstallDir, [switch]$WhatIf)
    $line = ". `"$InstallDir\profile.ps1`""
    if ($Choice -eq 2) { return }
    # Mandatory backup before any profile modification
    $backupPath = $null
    if (Test-Path $ProfilePath) {
        $backupPath = "$ProfilePath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (-not $WhatIf) { Copy-Item -Path $ProfilePath -Destination $backupPath -Force }
        Write-OK ($L.profileBackup -f $backupPath)
    }
    if ($WhatIf) { Write-Muted "  [WhatIf] $($L.profileAction) $line"; return }
    if ($Choice -eq 0) {
        if (Test-Path $ProfilePath) {
            $content = Get-Content $ProfilePath -Raw
            if ($content -match [regex]::Escape($line)) { Write-OK $L.profileAlready; return }
            Add-Content -Path $ProfilePath -Value "`n$line" -NoNewline
        } else { Set-Content -Path $ProfilePath -Value $line }
        Write-OK ($L.profileAdded -f $ProfilePath)
    } elseif ($Choice -eq 1) {
        Set-Content -Path $ProfilePath -Value $line
        Write-OK $L.profileReplaced
    }
}

function Install-WingetDeps {
    param($RepoRoot, [switch]$WhatIf)
    $script = Join-Path $RepoRoot 'Install-WingetRequirements.ps1'
    if (Test-Path $script) { Write-Step $L.wingetDepsTitle; & $script -WhatIf:$WhatIf }
    else {     Write-Fail $L.wingetScriptNotFound }
}

function Install-ContextCompressor {
    param($RepoRoot, $Choice, $Threshold, [switch]$WhatIf)
    if ($Choice -eq 2) { Write-Warn $L.compressorDisabled; return }

    # ─── Plugin ────────────────────────────────────────────────
    $pluginDir = "$env:USERPROFILE\.config\opencode\plugins"
    $pluginSrc = Join-Path $RepoRoot 'plugins' 'context-compressor.ts'
    if (Test-Path $pluginSrc) {
        if (-not (Test-Path $pluginDir)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null } }
        if (-not $WhatIf) { Copy-SafeItem -Path $pluginSrc -Destination (Join-Path $pluginDir 'context-compressor.ts') }
        Write-OK "Plugin → $pluginDir\context-compressor.ts"
    } else {
        Write-Warn $L.pluginNotFound
    }

    # ─── Skill ─────────────────────────────────────────────────
    $skillSrc = Join-Path $RepoRoot 'skills' 'context-compressor'
    $skillDir = "$env:USERPROFILE\.config\opencode\skills\context-compressor"
    if (Test-Path $skillSrc) {
        if (-not (Test-Path $skillDir)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $skillDir -Force | Out-Null } }
        if (-not $WhatIf) { Copy-SafeItem -Path (Join-Path $skillSrc 'SKILL.md') -Destination (Join-Path $skillDir 'SKILL.md') }
        Write-OK "Skill → $skillDir\SKILL.md"
    } else {
        Write-Warn $L.skillNotFound
    }

    # ─── Threshold ─────────────────────────────────────────────
    if ($Choice -eq 0) {
        if (-not $WhatIf) { $env:CONTEXT_COMPRESSOR_THRESHOLD = "$Threshold" }
        Write-OK ($L.thresholdSet -f $Threshold)
    }

    if ($Choice -eq 0) { Write-OK $L.modeAuto }
    else { Write-OK $L.modeManual }
}
#endregion

#region ─── Main ─────────────────────────────────────────────
Clear-Screen
Show-TuiBanner

# ─── Language selection ────────────────────────────────────
$L = $RU
$langChoice = Show-TuiMenuRadio $L.chooseLang @(
  @{label = $RU.langName }
  @{label = $EN.langName }
)
if ($langChoice -eq 1) { $L = $EN }
Clear-Screen
Show-TuiBanner
Write-Muted "   $(Get-Date -Format 'yyyy-MM-dd HH:mm')  |  $(if ($IS_WEB) { $L.webMode } else { $L.localMode })"
Write-Host ""

Test-Prerequisites

# ─── Install location ──────────────────────────────────────
Write-Step $L.installLoc
$defaultDir = "$env:USERPROFILE\pwshcode"
$installDir = Read-String $L.askInstallDir $defaultDir

# ─── Copy repo to target if web mode ───────────────────────
if ($IS_WEB) {
    Write-Step ($L.webCopying -f $installDir)
    if (Test-Path $installDir) {
        if (-not (Prompt-YesNo ($L.webOverwrite -f $installDir) $false)) {
            Write-Warn $L.installCancelled
            Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
            exit 0
        }
        Remove-Item -Recurse -Force "$installDir\*" -ErrorAction SilentlyContinue
    } else { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
    if ((Resolve-Path $repoRoot).Path -ne (Resolve-Path $installDir).Path) {
        Get-ChildItem -LiteralPath $repoRoot -Exclude '.git' | Copy-Item -Destination $installDir -Recurse -Force
    }
    $repoRoot = $installDir
    Write-OK ($L.dirCopied -f $installDir)
}

# ─── Profile setup ─────────────────────────────────────────
Write-Step $L.profileSetup
$profilePath = "$([Environment]::GetFolderPath('MyDocuments'))\PowerShell\Microsoft.PowerShell_profile.ps1"
$profileChoice = Show-TuiMenuRadio $L.profileAction @(
    @{label = $L.profileAdd }
    @{label = $L.profileReplace }
    @{label = $L.profileSkip }
)

# ─── Skills selection ──────────────────────────────────────
$skillDir = Join-Path $repoRoot 'skills'
$allSkills = @(Get-ChildItem -LiteralPath $skillDir -Directory -ErrorAction SilentlyContinue)
$skillSelections = @()
if ($allSkills.Count -eq 0) {
    Write-Warn $L.noSkills
} else {
    $skillOptions = $allSkills | ForEach-Object {
        $desc = switch ($_.Name) {
            'pwsh-profile'      { $L.descPwshProfile }
            'python-env-manager' { $L.descPythonEnv }
            'pwsh-idioms'       { $L.descPwshIdioms }
            'git-conventions'   { $L.descGitConventions }
            'just-recipes'      { $L.descJustRecipes }
            'project-scaffold'  { $L.descProjectScaffold }
            default             { $L.defaultDesc }
        }
        @{ label = $_.Name; desc = $desc }
    }
    $skillSelections = Show-MenuCheckbox $L.selectSkills $skillOptions
}

# ─── Context compressor selection ────────────────────────────
Write-Step $L.compressorTitle
Write-Muted $L.compressorHelp

$compressorChoice = Show-TuiMenuRadio $L.compressorMode @(
    @{label = $L.compressorAuto; desc = $L.compressorAutoDesc }
    @{label = $L.compressorManual; desc = $L.compressorManualDesc }
    @{label = $L.compressorOff }
)

$compressThreshold = 200
if ($compressorChoice -le 1) {
    $thresholdInput = Read-String $L.compressorThreshold "200"
    if ($thresholdInput -match '^\d+$') { $compressThreshold = [int]$thresholdInput }
}
Write-Host ""

# ─── Prompt selection ───────────────────────────────────────
Write-Step $L.promptTitle
$promptChoice = Show-TuiMenuRadio $L.promptChoice @(
    @{label = $L.promptOmp; desc = $L.promptOmpDesc }
    @{label = $L.promptStarship; desc = $L.promptStarshipDesc }
    @{label = $L.promptNone; desc = $L.promptNoneDesc }
)

# ─── Winget deps ───────────────────────────────────────────
Write-Step $L.wingetDepsTitle
$wingetExtra = if ($promptChoice -eq 0) { ' + oh-my-posh' } elseif ($promptChoice -eq 1) { ' + starship' } else { '' }
$installWinget = Prompt-YesNo ($L.wingetQuestion -f $wingetExtra) $true

# ─── Review ────────────────────────────────────────────────
Clear-Screen
Show-TuiBanner
Write-Step $L.reviewTitle
Write-Info ($L.reviewDir -f $installDir)
$profileLabels = @($L.profileAdd, $L.profileReplace, $L.profileSkip)
Write-Info ($L.reviewProfile -f $profileLabels[$profileChoice])
$chosenSkills = @()
for ($i = 0; $i -lt $allSkills.Count; $i++) { if ($skillSelections[$i]) { $chosenSkills += $allSkills[$i].Name } }
Write-Info ($L.reviewSkills -f $(if ($chosenSkills.Count -gt 0) { "$($chosenSkills.Count): $($chosenSkills -join ', ')" } else { $L.notSelected }))
$promptLabels = @($L.promptOmp, $L.promptStarship, $L.promptNone)
$compressorLabels = @($L.compressorAutoMode, $L.compressorManualMode, $L.compressorOffMode)
$compressorDetail = if ($compressorChoice -le 1) { ($L.compressorTokens -f $compressThreshold) } else { "" }
Write-Info ($L.reviewCompressor -f "$($compressorLabels[$compressorChoice])$compressorDetail")
Write-Info ($L.reviewPrompt -f $promptLabels[$promptChoice])
Write-Info ($L.reviewWinget -f $(if ($installWinget) { $L.yesLabel } else { $L.noLabel }))
if (-not (Prompt-YesNo $L.confirmStart $true)) {
    Write-Warn $L.cancelled
    if ($IS_WEB) { Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue }
    exit 0
}

# ─── Install ───────────────────────────────────────────────
Install-ProfileFiles -RepoRoot $repoRoot -TargetDir $installDir -WhatIf:$WhatIf

if ($allSkills.Count -gt 0) {
    Write-Step $L.installingSkills
    Install-Skills -RepoRoot $repoRoot -TargetDir "$env:USERPROFILE\.config\opencode\skills" -Selection $skillSelections -WhatIf:$WhatIf
}

# ─── Context compressor ────────────────────────────────────
Write-Step $L.installingCompressor
Install-ContextCompressor -RepoRoot $repoRoot -Choice $compressorChoice -Threshold $compressThreshold -WhatIf:$WhatIf

# ─── Prompt config ─────────────────────────────────────────
Write-Step $L.installingPrompt
$promptTarget = Join-Path $installDir 'prompt'
if (-not (Test-Path $promptTarget)) { if (-not $WhatIf) { New-Item -ItemType Directory -Path $promptTarget -Force | Out-Null } }
if (-not $WhatIf) { Copy-SafeItem -Path (Join-Path $repoRoot 'prompt\init.ps1') -Destination $promptTarget }

if ($promptChoice -eq 0) {
    if (-not $WhatIf) { Copy-SafeItem -Path (Join-Path $repoRoot 'prompt\omp-tokyonight.json') -Destination $promptTarget }
    Write-OK $L.promptOmpOk
} elseif ($promptChoice -eq 1) {
    if (-not $WhatIf) {
        Copy-SafeItem -Path (Join-Path $repoRoot 'prompt\starship.toml') -Destination $promptTarget
        Copy-SafeItem -Path (Join-Path $repoRoot 'prompt\starship-admin.toml') -Destination $promptTarget
    }
    Write-OK $L.promptStarshipOk
} else {
    Write-OK $L.promptNoneOk
}

if ($profileChoice -le 1) {
    Write-Step $L.profileSetup
    Setup-Profile -Choice $profileChoice -ProfilePath $profilePath -InstallDir $installDir -WhatIf:$WhatIf
}

if ($installWinget) {
    Install-WingetDeps -RepoRoot $repoRoot -WhatIf:$WhatIf
    if ($promptChoice -eq 0 -and -not $WhatIf) {
        Write-Step "Oh My Posh"
        winget install -e --id JanDeDobbeleer.OhMyPosh --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-OK $L.ohmyposhOk } else { Write-Warn ($L.ohmyposhFail -f $LASTEXITCODE) }
    }
}

# ─── Cleanup web temp ──────────────────────────────────────
if ($IS_WEB -and -not $WhatIf) { Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue }

# ─── Done ──────────────────────────────────────────────────
Clear-Screen
Show-TuiBanner
Write-Host ""
Write-Host "   $($C.Bold)$($C.Green)╔══════════════════════════════════╗$($C.Reset)"
Write-Host "   $($C.Bold)$($C.Green)║     $($L.doneTitle)$($C.Green)      ║$($C.Reset)"
Write-Host "   $($C.Bold)$($C.Green)╚══════════════════════════════════╝$($C.Reset)"
Write-Host ""

Write-Step $L.whatNext
Write-Info "1. $($L.restartOpencode)"
Write-Info "2. $($L.verifyProfile)"
Write-Muted "     . `"$installDir\profile.ps1`""
if ($profileChoice -eq 2) {
    Write-Muted ($L.addToProfile -f "`$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
}
if ($chosenSkills.Count -gt 0) {
    Write-Info "3. $($L.skillsReady)"
    foreach ($s in $chosenSkills) { Write-Muted "     • $s" }
}
if ($compressorChoice -le 1) {
    Write-Info "4. $($L.compressorInfo -f $compressorLabels[$compressorChoice], $compressThreshold)"
    Write-Muted "   $($L.restartToActivate)"
}
Write-Host ""

if ($IS_WEB) {
    Write-Muted ($L.repoCopied -f $installDir)
    Write-Muted $L.updateInfo
    Write-Host ""
}

Write-Host "   $($L.pressAnyKey)"
$null = Invoke-SafeReadKey
#endregion
