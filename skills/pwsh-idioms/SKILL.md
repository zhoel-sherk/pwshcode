---
name: pwsh-idioms
description: >-
  PowerShell quoting, pipeline, error handling, and encoding patterns for AI
  agents on Windows. Use when native commands fail unexpectedly, output has
  garbled text, exit codes are wrong, or quoting produces confusing errors in
  PowerShell 7. Also use before writing non-trivial PowerShell that invokes
  native EXEs (git, npm, dotnet, uv, rg, jq, etc.). Keywords: powershell,
  pwsh, quoting, escape, stderr, LASTEXITCODE, encoding, native command, call
  operator, splatting, stop-parsing.
---

# PowerShell idioms for agents

PowerShell's parsing rules differ from Bash. Native commands (`git`, `npm`, `jq`, `rg`, etc.) are especially tricky. This skill covers patterns that reliably work in PowerShell 7 without token waste.

## Quoting rules

```powershell
# SINGLE QUOTES — verbatim, no expansion. Safe for native tool args:
jq '.foo.bar' data.json
rg 'error.*panic' src/

# DOUBLE QUOTES — expands $variables and subexpressions. Use for pwsh-native:
Write-Host "Path: $PWD, Exit: $LASTEXITCODE"
# Risk with native tools — $ expands unexpectedly:
# BAD: jq ".foo | .bar" data.json   ← PowerShell expands $foo
# GOOD: jq '.foo | .bar' data.json

# VERBATIM STRING — no expansion at all, good for regex:
$pattern = 'error\s+\d+'

# HERE-STRING — for multi-line:
$script = @'
& git status
& git diff
'@
```

## Stop-parsing token `--%`

When a native tool has complex quoting that fights PowerShell:

```powershell
# Everything after --% is passed literally (no PowerShell parsing):
winget install --id "Microsoft.VisualStudio.2022.Community" --silent --accept-source-agreements --%
msiexec /i "package.msi" /quiet --%
```

Use `--%` as **last resort** — it also disables environment variable expansion.

## Call operator `&`

```powershell
# BAD — bare string doesn't resolve .exe:
"some\program.exe" --arg

# GOOD — call operator + quoted path:
& "C:\Program Files\Some\program.exe" --arg

# BEST — separate variable + splatting:
$exe = "C:\Program Files\Some\program.exe"
$args = @('--input', 'file.txt', '--output', 'result.json')
& $exe @args
```

## Exit codes

```powershell
# BAD — $? can be $false even on success (stderr sets it):
some.exe --arg; if (-not $?) { "failed" }

# GOOD — $LASTEXITCODE is reliable:
& some.exe --arg
if ($LASTEXITCODE -ne 0) { "exit: $LASTEXITCODE" }

# Capture both stdout and exit code:
$output = & some.exe --arg 2>&1
$exitCode = $LASTEXITCODE
```

## stderr handling

```powershell
# Native.exe stderr comes wrapped in NativeCommandError.
# Merge to get clean output:
$result = & git log --oneline 2>&1

# Discard stderr noise:
& rg 'class' src/ 2>$null

# Separate streams:
$stdout = & cmd /c dir 2>&1 | Where-Object { $_ -is [string] }
$stderr = & cmd /c dir 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
```

## UTF-8 encoding

```powershell
# PowerShell defaults to UTF-16LE for redirection. Force UTF-8:
& some.exe | Out-File -Encoding utf8NoBom out.txt
& some.exe | Set-Content -Encoding utf8NoBom out.txt

# With pwsh-profile loaded, these defaults are already set.
# For truly BOM-free:
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("$PWD\out.txt", $lines, $utf8NoBom)
```

## Pipeline with native commands

```powershell
# Native-to-native pipeline — use cmd /c or Group-Object:
# BAD:  jq . file.json | uv pip install -r /dev/stdin  ← PowerShell parser interferes
# GOOD: cmd /c 'jq . file.json | uv pip install -r /dev/stdin'

# Native-to-native on Windows often needs explicit shell:
cmd /c 'type source.txt | findstr pattern > result.txt'

# PowerShell native-to-cmdlet is fine:
& rg 'class' src/ | Select-Object -First 5
```

## Paths with spaces

```powershell
# Always quote paths with spaces for cmdlets:
Get-ChildItem -LiteralPath "C:\Program Files\My App"

# For native exes, use call operator + quoted path:
& "C:\Program Files\Git\bin\git.exe" status

# Or use the 8.3 short name:
& "$env:USERPROFILE\PROGRA~1\Git\bin\git.exe" status
```

## Module autoloading

```powershell
# PowerShell 7 auto-loads modules from PSModulePath.
# If a cmdlet is missing, install the module first:
Install-Module -Name PowerShellGet -Force -Scope CurrentUser

# List available commands from a module:
Get-Command -Module Microsoft.PowerShell.Archive
```

## Error handling

```powershell
# try/catch for terminating errors:
try {
    Get-Content "missing.txt" -ErrorAction Stop
} catch {
    Write-Warning "File not found: $_"
}

# Check $? after cmdlets:
Remove-Item "locked.txt" -ErrorAction SilentlyContinue
if (-not $?) { Write-Warning "Could not remove" }

# For native exes, always $LASTEXITCODE (see above).
```

## Splatting

```powershell
# Instead of long argument lines, use splatting:
$params = @{
    Path        = '.\src'
    Recurse     = $true
    Filter      = '*.py'
    ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @params

# For native commands, use array splatting:
$args = @('--format', 'json', '--max-files', '5')
& inspect.exe @args
```

## Common mistakes

| Mistake | Wrong | Right |
|---------|-------|-------|
| Checking $? after native EXE | `if (-not $?)` | `if ($LASTEXITCODE -ne 0)` |
| Unquoted path with spaces | `C:\Program Files\app.exe` | `& "C:\Program Files\app.exe"` |
| Double quotes for jq filter | `jq ".key"` | `jq '.key'` |
| Forgetting call operator | `$exe --arg` | `& $exe --arg` |
| stderr not merged | `$out = & git status` | `$out = & git status 2>&1` |
| UTF-16 file output | `echo "text" > file.txt` | `echo "text" \| Out-File -Encoding utf8NoBom file.txt` |

## Also see

- **pwsh-profile** — state/deps/xray/inspect commands, profile loading
