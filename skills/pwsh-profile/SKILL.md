---
name: pwsh-profile
description: >-
  PowerShell 7 profile with custom commands (state, deps, xray, inspect, cmds)
  and aliases loaded from $env:USERPROFILE\pwsh_profile\profile.ps1. Requires
  winget CLI stack (jq, delta, uv, just, yq, rg, fd). Use when the agent runs
  PowerShell and needs a bounded environment snapshot, dependency info, or
  workspace overview in .py/.js/any repo on Windows. Also covers zoxide, gsudo,
  and PowerShell quoting pitfalls for agents. Keywords: pwsh, profile, state,
  deps, xray, inspect, cmds, venc, gd, gst, zoxide, gsudo.
---

# pwsh-profile (PowerShell 7)

Profile: `. "$env:USERPROFILE\pwsh_profile\profile.ps1"` — dot-source at session start.

## Required CLI (winget)

All installed via `.\Install-WingetRequirements.ps1`.

| Tool | Agent usage |
|------|-------------|
| `jq` | `state -Json \| jq .Directory` |
| `delta` | `gd` or `git diff` (profile pipes diff) |
| `uv` | `venc` creates `.venv`; `uv pip install` |
| `just` | run `just <recipe>` when Justfile exists |
| `yq` | `yq '.services' docker-compose.yml` |
| `rg` / `fd` | search / find files |
| `zoxide` | `z <dir>` to jump; also see `zoxide query <dir>` for lookups |
| `gsudo` | `gsudo <cmd>` for elevation (installed via winget: `gerardog.gsudo`) |

## Agent rules

1. **Load the profile** at task start: `. "$env:USERPROFILE\pwsh_profile\profile.ps1"`
2. Prefer opencode **Read** / **Grep** over `xray` / `inspect` when the file is small or the pattern is simple.
3. Run **`state -Json`** once per task; pipe to **`jq`** when extracting fields: `state -Json | jq .Git`.
4. Use **`-Json`** on `deps`, `xray`, `inspect`, `cmds` when parsing in-shell.
5. Bound scans: `xray -Lines 3 -MaxFiles 8` or `inspect -Json -Quiet -MaxFiles 5` (last resort).
6. **`git diff`** / **`gd`** — delta pager when installed; full `git` for commits (not `gst`/`gc`).
7. Python env: **`venc`** → `uv venv .venv` (falls back to `python -m venv`); **`just`** for Justfile; **`yq`** for YAML manifests.
8. Directory jump: **`z <dir>`** for fuzzy directory navigation via zoxide.

## PowerShell pitfalls for agents

PowerShell behaves differently from Bash. These patterns save tokens and prevent failures:

### Quoting native commands
```powershell
# BAD — PowerShell parses `|` and `$` before passing to the native tool:
jq ".foo | .bar" data.json

# GOOD — single quotes prevent expansion:
jq '.foo | .bar' data.json

# GOOD — stop-parsing token for complex args:
winget install --id "Microsoft.VisualStudio.2022.Community" --silent --accept-source-agreements -- %
```

### Calling executables
```powershell
# BAD — string as command (no .exe resolution):
"path\to\program.exe" --arg

# GOOD — call operator:
& "path\to\program.exe" --arg

# GOOD — separate argument arrays prevent quoting hell:
& "path\to\program.exe" @('--arg1', 'value with spaces', '--flag')
```

### Exit codes
```powershell
# $? is unreliable with native commands (stderr can set it to $false).
# Always use $LASTEXITCODE instead:
& some.exe --arg
if ($LASTEXITCODE -ne 0) { write-error "Exit: $LASTEXITCODE" }
```

### Stderr merging
```powershell
# Native tools write to stderr; PowerShell wraps it as NativeCommandError.
# Merge stderr into stdout to get clean output:
& some.exe --arg 2>&1

# Or discard stderr noise:
& some.exe --arg 2>$null
```

### UTF-8 output
```powershell
# PowerShell defaults to UTF-16LE for > and Out-File.
# Force UTF-8 without BOM for agent consumption:
& some.exe | Out-File -Encoding utf8NoBOM file.txt

# With the pwsh-profile, $PSDefaultParameterValues already sets UTF-8 for Out-File/Set-Content.
```

## Available commands

| Command | Description | JSON |
|---------|-------------|------|
| `state` | cwd, git branch, venv, last exit code | `-Json` |
| `deps` | package.json / requirements.txt / pip deps | `-Json` |
| `xray` | First N lines of code files | `-Json` |
| `inspect` | state + deps + xray | `-Json`, `-Quiet` |
| `cmds` | List LLM commands | `-Json` |
| `gd` | `git diff` with delta pager | — |
| `gst` / `ga` / `gc` / `gp` / `gl` | Git aliases | — |
| `venc` / `vena` | Create / activate `.venv` | — |
| `z` | Directory jump (zoxide) | — |
| `gsudo` | Elevated command | — |

Full reference: [reference.md](reference.md).

## Permission policy (opencode.json)

To reduce prompting when running safe commands, add to your `opencode.json`:

```json
{
  "permission": {
    "bash": {
      "jq *": "allow",
      "rg *": "allow",
      "fd *": "allow",
      "uv *": "allow",
      "just *": "allow",
      "yq *": "allow",
      "z *": "allow",
      "venc": "allow",
      "vena": "allow",
      "state *": "allow",
      "deps *": "allow",
      "xray *": "allow",
      "inspect *": "allow",
      "git status": "allow",
      "git diff *": "allow",
      "git log *": "allow",
      "git add *": "ask",
      "git commit *": "ask",
      "git push *": "ask",
      "rm *": "deny",
      "Remove-Item *": "deny"
    }
  }
}
```

## zoxide usage

`z` is available when zoxide is installed and the profile is loaded:

```powershell
# Jump to directory by name (fuzzy match):
z project-name

# Interactive selection (use with opencode bash tool via stdin):
z -i

# Query without changing dir:
zoxide query project-name
```

## gsudo usage

For operations that require elevation (installers, system config):

```powershell
gsudo winget install <package>
gsudo notepad C:\Windows\System32\drivers\etc\hosts
gsudo --debug <command>
```

gsudo caches credentials — subsequent calls don't prompt within the same session.

## Minimal workflow

```powershell
. "$env:USERPROFILE\pwsh_profile\profile.ps1"
state -Json | jq .
deps -Json | jq .python
```

## Related skills

- **python-env-manager** — Python venv, Ruff, pytest, mypy, uv
- **pwsh-idioms** — deeper PowerShell quoting, pipeline, and error handling
- **just-recipes** — cross-project just recipes
