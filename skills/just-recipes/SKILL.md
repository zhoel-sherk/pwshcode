---
name: just-recipes
description: >-
  Cross-project just recipes: format, lint, test, build, clean, commit, and
  other common tasks. Use when the project has a Justfile and the agent needs
  to run or create just recipes, or when setting up a new project that should
  get a Justfile. Triggers on: Justfile, just, justfile, recipe.
  Requires: just (Casey.Just). Keywords: just, justfile, recipe, task runner.
---

# Just recipes

`just` is a command runner. If the repo has a `Justfile`, prefer `just <recipe>` over manual command sequences.

## Detect

```powershell
# Check if just is installed:
just --version

# Check if project has a Justfile:
Test-Path -LiteralPath "Justfile"
```

## Default Justfile template

When creating a Justfile for a new or existing project, start with this structure and keep only the relevant sections:

```makefile
# ─── Format ────────────────────────────────────────────
format: Ruff
    uv run ruff format .
    uv run ruff check --fix .

# ─── Lint ──────────────────────────────────────────────
lint: Ruff
    uv run ruff check .

typecheck: mypy
    uv run mypy .

# ─── Test ──────────────────────────────────────────────
test:
    uv run pytest --tb=short -x

test-cov:
    uv run pytest --tb=short --cov --cov-report=term-missing

# ─── Build ─────────────────────────────────────────────
build: node
    npm run build

# ─── Clean ─────────────────────────────────────────────
clean:
    rm -rf .venv __pycache__ .mypy_cache .ruff_cache node_modules dist

# ─── Git ───────────────────────────────────────────────
commit msg="update":
    git add -A
    git commit -m "{{msg}}"
    git push

pr title="update":
    gh pr create --title "{{title}}" --body ""

# ─── Security ──────────────────────────────────────────
audit:
    uv pip audit

# ─── Install deps ──────────────────────────────────────
setup:
    uv venv .venv
    uv pip install -e ".[dev,audit]"
```

## Language-specific sections

### Python (pyproject.toml)
```makefile
format: Ruff
    uv run ruff format .
    uv run ruff check --fix .

lint: Ruff
    uv run ruff check .

test:
    uv run pytest --tb=short -x

setup:
    uv venv .venv
    uv pip install -e ".[dev,audit]"

audit:
    uv pip audit

clean:
    rm -rf .venv __pycache__ .mypy_cache .ruff_cache
```

### Node.js (package.json)
```makefile
format:
    npm run format

lint:
    npm run lint

test:
    npm test

build:
    npm run build

clean:
    rm -rf node_modules dist

setup:
    npm install
```

### Generic fallback
```makefile
default:
    @just --list

format:
    @echo "No formatter configured"

test:
    @echo "No test command configured"
```

## Common recipes

| Recipe | What it does | Requires |
|--------|-------------|----------|
| `just` | List available recipes | Justfile |
| `just format` | Format code | ruff / prettier |
| `just lint` | Lint check | ruff / eslint |
| `just typecheck` | Type check | mypy / tsc |
| `just test` | Run tests | pytest / jest |
| `just build` | Build project | npm / uv build |
| `just clean` | Remove artifacts | — |
| `just setup` | Install all deps | uv / npm |
| `just audit` | Security audit | pip-audit / npm audit |
| `just commit "msg"` | Stage + commit + push | git |
| `just pr "title"` | Create PR | gh |

## Creating new recipes

When adding a recipe:

1. Place it in the appropriate section (format/lint/test/build/clean/git)
2. Use `{{variable}}` for parameters
3. Use `@` prefix to suppress echoing the command itself: `@just --list`
4. Use `&&` to chain commands that all must succeed
5. Add a doc comment above the recipe if non-obvious

## Also see

- **python-env-manager** — python-specific just recipes, pyproject.toml
- **git-conventions** — commit message format, PR workflow
