# pwsh-profile — command reference

Interactive and agent commands from `profile.ps1`. For agent rules, see [SKILL.md](SKILL.md).

## Required winget CLI

All listed in `requirements-winget.txt`. Install: `.\Install-WingetRequirements.ps1`.

| Tool | Typical use |
|------|-------------|
| `jq` | Parse profile JSON: `state -Json \| jq .Git` |
| `delta` | Readable diffs via `gd` |
| `uv` | `venc` → `uv venv .venv`; fast pip |
| `just` | Project tasks from `justfile` |
| `yq` | Query YAML (CI, compose, k8s) |
| `rg` / `fd` | Search / find files |
| `bat` / `eza` | interactive `cat` / `l` (plain table in agent shell) |

## LLM commands

| Command | Description | JSON |
|---------|-------------|------|
| `state` | cwd, git branch, venv, last exit code | `-Json` |
| `deps` | package.json / requirements.txt / pip (names only in JSON) | `-Json` |
| `xray` | First N lines of code files (`-Lines`, `-Filter`, `-MaxFiles`) | `-Json` |
| `inspect` | state + deps + xray | `-Json`, `-Quiet` |
| `cmds` | List LLM commands | `-Json` (LLM only) |
| `helpme` | Human-readable help | — |

## Navigation

| Command | Description |
|---------|-------------|
| `..` / `...` / `....` | Up 1 / 2 / 3 directories |
| `take <path>` | mkdir -p + cd |
| `l` / `ll` | List files (eza interactive; plain table in agent shell) |

## File operations

| Command | Description |
|---------|-------------|
| `cat <file>` | View file (bat interactive; Get-Content in agent shell) |
| `touch <file>` | Create empty file (+ parent dirs) |
| `trash <path>` | Move to Recycle Bin |
| `unzip <file>` | Extract zip |

## System

| Command | Description |
|---------|-------------|
| `which <cmd>` | Resolve executable path |
| `open <path>` | Open in Explorer |
| `myip` | External IP (network) |
| `port <n>` | Process on port |
| `killport <n>` | Kill process on port |
| `flushdns` | Clear DNS cache |
| `grep <pat>` | Search (rg in agent shell) |

## Git aliases

| Alias | Command |
|-------|---------|
| `gst` | `git status` |
| `ga` | `git add` |
| `gc` | `git commit -m` |
| `gp` | `git push` |
| `gl` | `git log --oneline --graph` |
| `gd` | `git diff` piped through **delta** when installed |

## Python

| Command | Description |
|---------|-------------|
| `venc` | `uv venv .venv` if **uv** installed, else `python -m venv .venv` |
| `vena` | Activate `.venv` |

## Profile

| Command | Description |
|---------|-------------|
| `rl` | Reload `$PROFILE` |

## Workflows

```powershell
. "$env:USERPROFILE\pwsh_profile\profile.ps1"
state -Json | jq .
deps -Json | jq .node
xray -Lines 3 -MaxFiles 8
inspect -Json -Quiet
gd
just test          # if justfile exists
yq '.jobs' .github/workflows/ci.yml
```

## PowerShell tips

- Case-insensitive command names.
- Native tools: check `$LASTEXITCODE`; cmdlets: check `$?`.
- Profile path: `$PROFILE` → dot-sources `%USERPROFILE%\pwsh_profile\profile.ps1`.
