#region Bootstrap
$script:IsAgentShell = ($env:TERM -eq 'dumb') -or [bool]$env:CURSOR_AGENT

if ($script:IsAgentShell) {
    $env:STARSHIP_DISABLED = '1'
}

function Initialize-ProfileToolPath {
    if (-not $script:IsAgentShell) { return }

    $segments = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    function Add-Segment {
        param([string]$Segment)
        if ([string]::IsNullOrWhiteSpace($Segment)) { return }
        $trimmed = $Segment.Trim().TrimEnd('\')
        if ($trimmed -and (Test-Path -LiteralPath $trimmed) -and $seen.Add($trimmed)) {
            [void]$segments.Add($trimmed)
        }
    }

    foreach ($scope in 'User', 'Machine') {
        $raw = [Environment]::GetEnvironmentVariable('Path', $scope)
        if ($raw) {
            foreach ($part in $raw -split ';') { Add-Segment $part }
        }
    }

    Add-Segment (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links')
    Add-Segment (Join-Path $env:USERPROFILE '.local\bin')

    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $pkgRoot) {
        Get-ChildItem -LiteralPath $pkgRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Add-Segment $_.FullName
            Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $exe = Get-ChildItem -LiteralPath $_.FullName -Filter '*.exe' -File -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($exe) { Add-Segment $_.FullName }
            }
        }
    }

    foreach ($part in ($env:Path -split ';')) { Add-Segment $part }

    if ($segments.Count -gt 0) {
        $env:Path = $segments -join ';'
    }
}

Initialize-ProfileToolPath

if (-not $script:IsAgentShell) {
    Clear-Host
}
$ProgressPreference = 'SilentlyContinue'

if (-not $script:IsAgentShell) {
    Invoke-Expression (&starship init powershell)
} else {
    function prompt { "PS $($ExecutionContext.SessionState.Path.CurrentLocation)> " }
}

$isAdmin = [Security.Principal.WindowsPrincipal]::new(
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$ProfileDir = Split-Path -Parent $PROFILE

if (-not $script:IsAgentShell) {
    if ($isAdmin) {
        $env:STARSHIP_CONFIG = "$ProfileDir\starship-admin.toml"
        $host.UI.RawUI.WindowTitle = "ADMIN - $((Get-Location).Path)"
        Write-Host "ELEVATED SHELL" -ForegroundColor Red
    } else {
        $env:STARSHIP_CONFIG = "$ProfileDir\starship.toml"
    }
}
#endregion

#region Modules
if (-not $script:IsAgentShell) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    Import-Module ZLocation -ErrorAction SilentlyContinue
}
#endregion

#region PSReadLine
if (-not $script:IsAgentShell) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
}
#endregion

#region Navigation
function Set-LocationParent { Set-Location .. }
Set-Alias -Name .. -Value Set-LocationParent -Option AllScope -Force

function Set-LocationParent2 { Set-Location ..\.. }
Set-Alias -Name ... -Value Set-LocationParent2 -Option AllScope -Force

function Set-LocationParent3 { Set-Location ..\..\.. }
Set-Alias -Name .... -Value Set-LocationParent3 -Option AllScope -Force

function New-DirectoryAndEnter {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -Path $Path
}
Set-Alias -Name take -Value New-DirectoryAndEnter -Option AllScope -Force

if ($script:IsAgentShell) {
    function Quick-L {
        Get-ChildItem @args | Select-Object Name, Length, LastWriteTime
    }
    function Quick-LL {
        Get-ChildItem @args | Select-Object Mode, Name, Length, LastWriteTime
    }
} else {
    function Quick-L { eza --icons=always --grid $args }
    function Quick-LL { eza --icons=always --long --git $args }
}
Set-Alias -Name l -Value Quick-L -Option AllScope -Force
Set-Alias -Name ll -Value Quick-LL -Option AllScope -Force
#endregion

#region FileOperations
if ($script:IsAgentShell) {
    function Quick-Cat {
        param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Path)
        if (-not $Path) { throw "Usage: cat <file>" }
        Get-Content -Path $Path[0]
    }
} else {
    function Quick-Cat { bat --style=plain $args }
}
Set-Alias -Name cat -Value Quick-Cat -Option AllScope -Force

function touch {
    $path = $args[0]
    $directory = Split-Path -Path $path -Parent
    if ($directory -and -not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    New-Item -ItemType File -Path $path -Force | Out-Null
}

function Invoke-Trash {
    param([string]$Path)
    if (-not $Path) { $Path = $args[0] }
    if (Test-Path $Path) {
        $item = Get-Item $Path
        $shell = New-Object -ComObject Shell.Application
        $shell.Namespace(0).ParseName($item.FullName).InvokeVerb('delete')
    }
}
Set-Alias -Name trash -Value Invoke-Trash -Option AllScope -Force

function Invoke-Unzip {
    param([string]$Path, [string]$Destination)
    Expand-Archive -Path $Path -DestinationPath $(if ($Destination) { $Destination } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }) -Force
}
Set-Alias -Name unzip -Value Invoke-Unzip -Option AllScope -Force
#endregion

#region System
function Get-Which {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { $cmd.Source } else { "Not found" }
}
Set-Alias -Name which -Value Get-Which -Option AllScope -Force

function Open-Explorer {
    param([string]$Path)
    if (-not $Path) { $Path = '.' }
    Invoke-Item $Path
}
Set-Alias -Name open -Value Open-Explorer -Option AllScope -Force

function Get-MyIP {
    (Invoke-WebRequest -Uri 'https://ifconfig.me/ip' -UseBasicParsing).Content.Trim()
}
Set-Alias -Name myip -Value Get-MyIP -Option AllScope -Force

function Find-ProcessByPort {
    param([int]$Port)
    $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($conn) {
        $conn | Select-Object LocalPort, @{N='ProcessName';E={(Get-Process -Id $_.OwningProcess).ProcessName}}, OwningProcess
    } else {
        "No process on port $Port"
    }
}
Set-Alias -Name port -Value Find-ProcessByPort -Option AllScope -Force

function Stop-ProcessByPort {
    param([int]$Port)
    $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($conn) {
        Stop-Process -Id $conn.OwningProcess -Force
        "Killed process on port $Port"
    } else {
        "Nothing on port $Port"
    }
}
Set-Alias -Name killport -Value Stop-ProcessByPort -Option AllScope -Force

function Clear-Dns { Clear-DnsClientCache }
Set-Alias -Name flushdns -Value Clear-Dns -Option AllScope -Force

function Set-Grep {
    param([string]$Pattern, [string]$Path = '.')
    if ($script:IsAgentShell -and (Get-Command rg -ErrorAction SilentlyContinue)) {
        rg --no-heading --line-number $Pattern $Path
        return
    }
    Get-ChildItem -Recurse -File $Path | Select-String -Pattern $Pattern
}
Set-Alias -Name grep -Value Set-Grep -Option AllScope -Force
#endregion

#region Git
function Invoke-GitStatus { git status }
Set-Alias -Name gst -Value Invoke-GitStatus -Option AllScope -Force

function Invoke-GitAdd { git add $args }
Set-Alias -Name ga -Value Invoke-GitAdd -Option AllScope -Force

function Invoke-GitCommit { git commit -m $args }
Set-Alias -Name gc -Value Invoke-GitCommit -Option AllScope -Force

function Invoke-GitPush { git push $args }
Set-Alias -Name gp -Value Invoke-GitPush -Option AllScope -Force

function Invoke-GitLog { git log --oneline --graph $args }
Set-Alias -Name gl -Value Invoke-GitLog -Option AllScope -Force

function Invoke-GitDiff {
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        git diff @args | delta
        return
    }
    git diff @args
}
Set-Alias -Name gd -Value Invoke-GitDiff -Option AllScope -Force
#endregion

#region Python
function Create-Venv {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        uv venv .venv
    } else {
        python -m venv .venv
    }
    if (-not $script:IsAgentShell) {
        Write-Host "Created .venv" -ForegroundColor Cyan
    }
}
Set-Alias -Name venc -Value Create-Venv -Option AllScope -Force

function Activate-Venv {
    if (Test-Path ".\.venv\Scripts\Activate.ps1") {
        & ".\.venv\Scripts\Activate.ps1"
    } else {
        Write-Host ".venv not found" -ForegroundColor Red
    }
}
Set-Alias -Name vena -Value Activate-Venv -Option AllScope -Force
#endregion

#region LLMTools
function Get-LLMState {
    param([switch]$Json)
    $venv = if ($env:VIRTUAL_ENV) { "Active (.venv)" } else { "None" }
    $git = if (git rev-parse --is-inside-work-tree 2>$null) { git branch --show-current } else { "Not a git repo" }

    if ($Json) {
        return @{
            Directory = (Get-Location).Path
            Git = $git
            Venv = $venv
            LastExitCode = $GLOBAL:LastExitCode
        } | ConvertTo-Json -Compress
    }

    @"
[SYSTEM_STATE]
DIR: $((Get-Location).Path)
GIT: $git
VENV: $venv
LAST_CMD_STATUS: $GLOBAL:LastExitCode
"@ | Out-String
}
Set-Alias -Name state -Value Get-LLMState -Option AllScope -Force

function Get-ProjectDepsData {
    $result = @{
        node = [System.Collections.Generic.List[string]]::new()
        python = [System.Collections.Generic.List[string]]::new()
        source = $null
    }

    if (Test-Path "package.json") {
        $result.source = "package.json"
        try {
            $json = Get-Content "package.json" -Raw | ConvertFrom-Json
            if ($json.dependencies) {
                $json.dependencies.psobject.Properties.Name | ForEach-Object { [void]$result.node.Add($_) }
            }
            if ($json.devDependencies) {
                $json.devDependencies.psobject.Properties.Name | ForEach-Object { [void]$result.node.Add($_) }
            }
        } catch {
            $result.source = "package.json (parse error)"
        }
    }

    if (Test-Path "requirements.txt") {
        $result.source = if ($result.source) { "$($result.source)+requirements.txt" } else { "requirements.txt" }
        Get-Content "requirements.txt" |
            Where-Object { $_ -and $_ -notmatch '^\s*#' } |
            ForEach-Object {
                $name = ($_ -split '==|>=|<=|~=|!=')[0].Trim()
                if ($name) { [void]$result.python.Add($name) }
            }
    } elseif ($env:VIRTUAL_ENV -and (Get-Command pip -ErrorAction SilentlyContinue)) {
        $result.source = if ($result.source) { "$($result.source)+pip" } else { "pip" }
        pip freeze | Select-Object -First 20 | ForEach-Object {
            $name = ($_ -split '==')[0].Trim()
            if ($name) { [void]$result.python.Add($name) }
        }
    }

    if (-not $result.source) {
        $result.source = "none"
    }

    return $result
}

function Get-ProjectDeps {
    param([switch]$Json)

    $data = Get-ProjectDepsData

    if ($Json) {
        return @{
            node = @($data.node)
            python = @($data.python)
            source = $data.source
        } | ConvertTo-Json -Compress
    }

    $output = "[PROJECT DEPENDENCIES]`n"
    if ($data.source -eq "none") {
        return $output + "No manifest files found (package.json, requirements.txt).`n"
    }

    if ($data.node.Count -gt 0) {
        $output += "Node.js ($($data.source)):`n"
        $data.node | ForEach-Object { $output += "    - $_`n" }
    }
    if ($data.python.Count -gt 0) {
        $output += "Python:`n"
        $data.python | ForEach-Object { $output += "    - $_`n" }
    }

    return $output
}
Set-Alias -Name deps -Value Get-ProjectDeps -Option AllScope -Force

function Get-ProjectXRayData {
    param (
        [int]$Lines = 5,
        [string]$Filter = "*",
        [int]$MaxFiles = 0
    )

    if ($MaxFiles -le 0) {
        $MaxFiles = if ($script:IsAgentShell) { 5 } else { 15 }
    }

    $AllowedExt = @('.js','.ts','.jsx','.tsx','.py','.go','.rs','.rb','.php','.cs','.html','.css','.md','.json','.yml','.yaml','.env')

    $files = Get-ChildItem -Recurse -File |
        Where-Object {
            $_.FullName -notmatch '\\(\.git|\.venv|node_modules|\.next|dist|build|public)\\?' -and
            $AllowedExt -contains $_.Extension
        }

    if ($Filter -ne "*") {
        $files = $files | Where-Object { $_.Name -like $Filter }
    }

    $totalFiles = @($files).Count
    $filesToProcess = @($files | Select-Object -First $MaxFiles)
    $fileEntries = [System.Collections.Generic.List[object]]::new()

    foreach ($file in $filesToProcess) {
        $relPath = $file.FullName.Replace((Get-Location).Path, "").TrimStart('\')
        $lineList = [System.Collections.Generic.List[string]]::new()
        try {
            $content = Get-Content $file.FullName -Head $Lines -ErrorAction Stop
            if ($content) {
                foreach ($line in $content) { [void]$lineList.Add([string]$line) }
            }
        } catch {
            [void]$lineList.Add("(read error)")
        }
        [void]$fileEntries.Add(@{ path = $relPath; lines = @($lineList) })
    }

    return @{
        total = $totalFiles
        shown = $filesToProcess.Count
        linesPerFile = $Lines
        files = @($fileEntries)
    }
}

function Get-ProjectXRay {
    param (
        [int]$Lines = 5,
        [string]$Filter = "*",
        [int]$MaxFiles = 0,
        [switch]$Json
    )

    $data = Get-ProjectXRayData -Lines $Lines -Filter $Filter -MaxFiles $MaxFiles

    if ($Json) {
        return $data | ConvertTo-Json -Depth 6 -Compress
    }

    if ($data.total -eq 0) {
        return "[X-RAY]: No code files found."
    }

    $output = @"
[X-RAY PROJECT SNAPSHOT]
Total files found: $($data.total) (Showing first: $($data.shown))
Reading first $Lines lines per file.
==================================================

"@

    foreach ($entry in $data.files) {
        $output += "FILE: $($entry.path)`n"
        $output += ("-" * 50) + "`n"
        if ($entry.lines.Count -gt 0) {
            $output += ($entry.lines -join "`n") + "`n"
        } else {
            $output += "(empty)`n"
        }
        $output += "=" * 50 + "`n`n"
    }

    return $output
}
Set-Alias -Name xray -Value Get-ProjectXRay -Option AllScope -Force

function Invoke-ProjectInspection {
    param (
        [int]$Lines = 5,
        [int]$MaxFiles = 0,
        [switch]$Json,
        [switch]$Quiet
    )

    if ($MaxFiles -le 0) {
        $MaxFiles = if ($script:IsAgentShell) { 5 } else { 10 }
    }

    if ($Json) {
        $stateObj = @{
            Directory = (Get-Location).Path
            Git = if (git rev-parse --is-inside-work-tree 2>$null) { git branch --show-current } else { "Not a git repo" }
            Venv = if ($env:VIRTUAL_ENV) { "Active (.venv)" } else { "None" }
            LastExitCode = $GLOBAL:LastExitCode
        }
        $depsData = Get-ProjectDepsData
        $depsObj = @{
            node = @($depsData.node)
            python = @($depsData.python)
            source = $depsData.source
        }
        $xrayObj = Get-ProjectXRayData -Lines $Lines -MaxFiles $MaxFiles

        return @{
            state = $stateObj
            deps = $depsObj
            xray = $xrayObj
        } | ConvertTo-Json -Depth 8 -Compress
    }

    if (-not $Quiet -and -not $script:IsAgentShell) {
        Clear-Host
        Write-Host "Project inspection for LLM..." -ForegroundColor Cyan
    }

    $state = Get-LLMState
    $deps = Get-ProjectDeps
    $xray = Get-ProjectXRay -Lines $Lines -MaxFiles $MaxFiles

    return @"
==================================================
$state
==================================================
$deps
==================================================
$xray
==================================================
"@
}
Set-Alias -Name inspect -Value Invoke-ProjectInspection -Option AllScope -Force

$script:ProfileLlmCommands = @(
    @{ name = 'state'; kind = 'alias' }
    @{ name = 'deps'; kind = 'alias' }
    @{ name = 'xray'; kind = 'alias' }
    @{ name = 'inspect'; kind = 'alias' }
    @{ name = 'cmds'; kind = 'alias' }
    @{ name = 'helpme'; kind = 'alias' }
)

function Get-ProfileCommands {
    param([switch]$Json)

    if ($Json) {
        return $script:ProfileLlmCommands | ConvertTo-Json -Compress
    }

    $cmds = @()
    Get-ChildItem Function: | Where-Object {
        $_.Name -match '^(Get|Invoke|Set|Clear|Find|Stop|New|Open|Quick|Create|Activate)'
    } | ForEach-Object {
        $cmds += [PSCustomObject]@{
            Command = $_.Name
            Type = 'Function'
        }
    }
    Get-Alias | Where-Object { $_.Definition -match '^(Get|Invoke|Set|Clear|Find|Stop|New|Open|Quick|Create|Activate)' } | ForEach-Object {
        $cmds += [PSCustomObject]@{
            Command = $_.Name
            Type = 'Alias -> ' + $_.Definition
        }
    }
    return $cmds | Sort-Object Command | Format-Table -AutoSize | Out-String
}
Set-Alias -Name cmds -Value Get-ProfileCommands -Option AllScope -Force

function Invoke-ProfileHelp {
    Write-Host "=== PowerShell Profile Help ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Navigation:" -ForegroundColor Yellow
    Write-Host "  .., ..., ....  - Go up 1/2/3 directories"
    Write-Host "  take <path>    - mkdir + cd"
    Write-Host "  l, ll          - List files (eza grid/long)"
    Write-Host ""
    Write-Host "Files:" -ForegroundColor Yellow
    Write-Host "  cat <file>     - View with bat"
    Write-Host "  touch <file>   - Create empty file"
    Write-Host "  trash <path>   - Move to recycle bin"
    Write-Host "  unzip <file>   - Extract zip"
    Write-Host ""
    Write-Host "System:" -ForegroundColor Yellow
    Write-Host "  which <cmd>    - Locate command"
    Write-Host "  open <path>    - Open in explorer"
    Write-Host "  myip           - External IP"
    Write-Host "  port <n>       - Find process on port"
    Write-Host "  killport <n>   - Kill process on port"
    Write-Host "  flushdns       - Clear DNS cache"
    Write-Host "  grep <patt>    - Search files"
    Write-Host ""
    Write-Host "Git:" -ForegroundColor Yellow
    Write-Host "  gst, ga, gc, gp, gl, gd (delta pager when installed)"
    Write-Host ""
    Write-Host "Python:" -ForegroundColor Yellow
    Write-Host "  venc           - Create .venv (uv venv if uv installed)"
    Write-Host "  vena           - Activate .venv"
    Write-Host ""
    Write-Host "LLM Tools:" -ForegroundColor Yellow
    Write-Host "  state          - System state (add -Json for JSON)"
    Write-Host "  xray           - Project file scan (-Json supported)"
    Write-Host "  deps           - Project dependencies (-Json supported)"
    Write-Host "  inspect        - Full project inspection (-Json -Quiet)"
    Write-Host "  cmds           - List profile commands (-Json for LLM cmds)"
    Write-Host "  helpme         - This help"
    Write-Host ""
    Write-Host "Profile:" -ForegroundColor Yellow
    Write-Host "  rl             - Reload profile"
}
Set-Alias -Name helpme -Value Invoke-ProfileHelp -Option AllScope -Force
#endregion

#region ProfileManagement
function Reload-Profile {
    . $PROFILE
    if (-not $script:IsAgentShell) {
        Write-Host "Profile reloaded" -ForegroundColor Green
    }
}
Set-Alias -Name rl -Value Reload-Profile -Option AllScope -Force
#endregion
