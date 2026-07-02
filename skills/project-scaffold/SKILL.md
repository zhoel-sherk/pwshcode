---
name: project-scaffold
description: >-
  Scaffolds new projects with standard config files: pyproject.toml,
  package.json, tsconfig.json, Justfile, .gitignore, README.md. Use when
  starting a new repo, adding a new package to a monorepo, or when the project
  is missing standard config files. Triggers on: new project, scaffold, init,
  setup, boilerplate. Keywords: scaffold, template, init, boilerplate, new
  project, pyproject, package.json, tsconfig, justfile, gitignore.
---

# Project scaffold

Standard starter configs for new projects. Pick the relevant sections — don't include everything.

## .gitignore

```gitignore
# Python
.venv/
__pycache__/
*.pyc
.mypy_cache/
.ruff_cache/
*.egg-info/
dist/
build/

# Node
node_modules/
dist/
.next/

# IDE
.vs/
.vscode/
.idea/
*.swp
*.swo

# OS
Thumbs.db
.DS_Store

# Env
.env
.env.local
*.env
```

## Python package

Detect: user mentions Python, `pyproject.toml` is missing, creating a `src/` layout.

```toml
[build-system]
requires = ["setuptools>=75"]
build-backend = "setuptools.backends._legacy:_Backend"

[project]
name = "<repo-name>"
version = "0.1.0"
description = ""
readme = "README.md"
requires-python = ">=3.11"
license = { text = "MIT" }
keywords = []
authors = [{ name = "", email = "" }]
dependencies = []

[project.optional-dependencies]
dev = [
    "ruff>=0.9",
    "pytest>=8",
    "pytest-cov>=6",
    "mypy>=1.15",
]
audit = ["pip-audit>=2.8"]

[project.urls]
Repository = "https://github.com/<user>/<repo>"

[tool.ruff]
target-version = "py311"
line-length = 100

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "PL", "RUF"]

[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]

[tool.mypy]
python_version = "3.11"
strict = true
ignore_missing_imports = true

[tool.coverage.run]
source = ["src"]
```

Create directory structure:
```
<repo-name>/
├── src/
│   └── __init__.py
├── tests/
│   └── __init__.py
├── pyproject.toml
├── Justfile
├── .gitignore
└── README.md
```

## Node.js package

Detect: user mentions Node, npm, yarn, package.json is missing.

```json
{
  "name": "<package-name>",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "node --watch src/index.js",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "node --test tests/",
    "format": "prettier --write .",
    "lint": "eslint src/"
  },
  "devDependencies": {
    "typescript": "^5.7",
    "prettier": "^3.4",
    "eslint": "^9.0"
  }
}
```

## TypeScript config

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src"]
}
```

## Justfile

```makefile
format:
    uv run ruff format .   # Python
    # npm run format       # Node

lint:
    uv run ruff check .    # Python
    # npm run lint         # Node

test:
    uv run pytest --tb=short -x   # Python
    # npm test                     # Node

setup:
    uv venv .venv && uv pip install -e ".[dev,audit]"   # Python
    # npm install                                        # Node

clean:
    rm -rf .venv __pycache__ .mypy_cache .ruff_cache node_modules dist
```

## README.md template

```markdown
# <repo-name>

<one-line description>

## Setup

```bash
just setup
```

## Development

```bash
just format   # Format code
just lint     # Lint check
just test     # Run tests
```
```

## Also see

- **python-env-manager** — Python venv, Ruff, uv, pip-audit, pre-commit
- **just-recipes** — all just recipes reference
- **git-conventions** — git workflow, commit format
