---
name: python-env-manager
description: Use when creating or editing Python projects, scripts, or tests. Manages a workspace-local .venv, installs tooling (ruff, pytest, mypy, vulture, pip-audit, pre-commit), runs format/lint on Windows 11 or Fedora 43+. Prefers uv over pip when available. Trigger keywords: .py, python, venv, virtualenv, ruff, pytest, mypy, vulture, pip, uv, format, lint, pyproject, pre-commit, pip-audit.
---

# Python environment and Ruff

Concise workflow for **Windows 11** (PowerShell 7) and **Fedora 43+** (Bash). Prefer calling the venv interpreter directly instead of relying on shell activation.

## When to use

- New Python layout, scripts, or packages in the repo.
- Editing or refactoring `.py` files, fixing imports/style, or running tests.
- Before executing Python that depends on third-party packages.

## Detect OS and venv Python

Use the workspace root `.venv` unless the project already documents another layout (e.g. Poetry, uv, conda—then follow that instead).

| OS         | Venv Python path                | Optional activate                 |
| ---------- | ------------------------------- | --------------------------------- |
| Windows 11 | `.\\.venv\\Scripts\\python.exe` | `.\\.venv\\Scripts\\Activate.ps1` |
| Fedora 43+ | `./.venv/bin/python`            | `source .venv/bin/activate`       |

Shell choice: **Windows** → `pwsh` syntax; **Fedora** → Bash. On Windows, avoid PowerShell 5.1-only patterns when writing snippets.

On Windows, the **pwsh-profile** skill provides `venc` / `vena` shortcuts for venv management.

Define once per task: `**$PY**` in PowerShell, `**PY**` in Bash.

```powershell
$PY = ".\.venv\Scripts\python.exe"
```

```bash
PY="./.venv/bin/python"
```

On Windows with pwsh-profile loaded, `. "$env:USERPROFILE\pwsh_profile\profile.ps1"` then `venc` replaces manual venv creation.

## Bootstrap `.venv`

1. If `.venv` is missing, create it from the repo root:
   - **Windows:** `python -m venv .venv` (or `py -3 -m venv .venv` if `python` is ambiguous). Faster: `uv venv .venv` if uv is installed.
   - **Fedora:** `python3 -m venv .venv` or `uv venv .venv`.
2. Upgrade pip inside the venv before heavy installs:
   - **PowerShell:** `& $PY -m pip install -U pip`
   - **Bash:** `"$PY" -m pip install -U pip`
   - With uv: `uv pip install -U pip` (or skip — uv pip auto-resolves faster)

## Prefer uv over pip

If `uv` is on PATH (check with `uv --version`), prefer it for all package operations:

| Operation | pip (fallback) | uv (preferred) |
|-----------|----------------|----------------|
| Install   | `& $PY -m pip install <pkg>` | `uv pip install <pkg>` |
| Compile deps | — | `uv pip compile pyproject.toml -o requirements.txt` |
| Sync lock  | — | `uv pip sync requirements.txt` |

uv installs packages 10–100x faster. Run from the repo root — uv auto-detects the active venv.

## pyproject.toml scaffolding

When creating a new Python package or adding config to an existing repo, scaffold `pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=75"]
build-backend = "setuptools.backends._legacy:_Backend"

[project]
name = "<repo-name>"
version = "0.1.0"
description = ""
requires-python = ">=3.11"
dependencies = []

[project.optional-dependencies]
dev = [
    "ruff>=0.9",
    "pytest>=8",
    "pytest-cov>=6",
    "mypy>=1.15",
]
audit = ["pip-audit>=2.8"]

[tool.ruff]
target-version = "py311"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "PL", "RUF"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

Omit sections the project doesn't need. Use `requires-python` matching the project's actual target.

## Tooling installs (minimal vs extended)

**Minimal (default):** Ruff only + pip-audit.

```powershell
uv pip install ruff pip-audit
```
```bash
uv pip install ruff pip-audit
```

Fallback (no uv):
```powershell
& $PY -m pip install ruff pip-audit
```
```bash
"$PY" -m pip install ruff pip-audit
```

**Tests:** only if the user runs or adds tests—install then run:

```powershell
uv pip install pytest pytest-cov
& $PY -m pytest --tb=short
```
```bash
uv pip install pytest pytest-cov
"$PY" -m pytest --tb=short
```

**Optional desktop / QA stack** (use only when the work is clearly PySide6/Qt desktop, settings models, or the user asks for static analysis / dead-code scan):

```powershell
uv pip install ruff mypy vulture loguru pydantic pyqtdarktheme qtawesome
```
```bash
uv pip install ruff mypy vulture loguru pydantic pyqtdarktheme qtawesome
```

On Fedora, GUI stacks may need system packages from `dnf` (e.g. Qt); if imports fail, suggest installing the documented distro packages for PySide6 rather than guessing versions.

## Ruff: format and lint

1. Respect project config: if `pyproject.toml` (or `ruff.toml`) defines Ruff, use it; do not fight the repo's `exclude` / `extend-exclude`.
2. Prefer **scoped paths** (files or dirs the user touched or asked about). Use `.` only when formatting/linting the whole tree is explicitly requested or clearly a small repo.
3. Ensure Ruff is available (`uv run ruff --version` or `& $PY -m ruff --version` on Windows, `"$PY" -m ruff --version` on Fedora); if missing, install per **Minimal** above.

```powershell
uv run ruff format <paths>
uv run ruff check --fix <paths>
```
```bash
uv run ruff format <paths>
uv run ruff check --fix <paths>
```

Fallback:
```powershell
& $PY -m ruff format <paths>
& $PY -m ruff check --fix <paths>
```
```bash
"$PY" -m ruff format <paths>
"$PY" -m ruff check --fix <paths>
```

If `--fix` cannot resolve a violation, report remaining diagnostics; do not claim the tree is "perfectly" clean unless Ruff (and any requested mypy/vulture) actually pass.

## Optional static analysis and dead code

When the extended stack is installed **and** relevant to the task:

```powershell
& $PY -m mypy <paths>
& $PY -m vulture <paths>
```
```bash
"$PY" -m mypy <paths>
"$PY" -m vulture <paths>
```

Tune mypy to the project's config (`pyproject.toml`, `mypy.ini`). Prefer package/module paths over raw `.` when the repo is large.

## Security audit

When reviewing dependencies or before CI, run pip-audit:

```powershell
& $PY -m pip_audit
```
```bash
"$PY" -m pip_audit
```

Or with uv (faster, no venv needed for the scan):
```powershell
uv pip audit
```
```bash
uv pip audit
```

If vulnerabilities are found, report them and suggest `uv pip compile --upgrade-package <pkg>` or pinning safe versions.

## Pre-commit hooks

If the project has a `.pre-commit-config.yaml` or the user asks for git hooks:

```powershell
& $PY -m pip install pre-commit   # or: uv pip install pre-commit
& $PY -m pre_commit install
& $PY -m pre_commit run --all-files
```
```bash
"$PY" -m pip install pre-commit
"$PY" -m pre_commit install
"$PY" -m pre_commit run --all-files
```

Common `.pre-commit-config.yaml` scaffold:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.9.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
```

## Logging and settings (PySide6 / app code)

When working on application code that already uses this stack:

- Prefer **Pydantic v2 models** for settings and structured state crossing module boundaries instead of untyped `dict` blobs; keep fields annotated for mypy.
- Prefer **loguru** (`from loguru import logger`) over `print()` in non-trivial or production paths; use `@logger.catch` on risky PySide6 slots/handlers when the codebase already follows that pattern.

## Justfile recipes

If the repo has `just` installed and a `Justfile` exists, add these common recipes. Create a `Justfile` if one is missing and the project has recurring Python tasks:

```makefile
venv:
    uv venv .venv
    uv pip install -e ".[dev,audit]"

format:
    uv run ruff format .
    uv run ruff check --fix .

lint:
    uv run ruff check .

typecheck:
    uv run mypy .

test:
    uv run pytest --tb=short -x

audit:
    uv pip audit

precommit:
    uv run pre-commit run --all-files

clean:
    rm -rf .venv __pycache__ .mypy_cache .ruff_cache
```

## Justfile examples

| Command | Effect |
|---------|--------|
| `just venv` | Create venv + install dev deps |
| `just format` | Format with ruff |
| `just lint` | Lint check |
| `just test` | Run pytest |
| `just audit` | Security audit |

## Feedback after changes

Briefly state what ran (venv created or reused, uv vs pip, exact ruff/pytest/mypy/vulture/audit commands) and paste or summarize remaining tool output if anything failed or was left unfixed.
