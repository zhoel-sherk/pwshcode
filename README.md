# pwshcode

PowerShell 7 profile + opencode skills for AI coding agents on Windows.

## Быстрая установка

**Одной командой (GitHub):**

```powershell
irm https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main/install.ps1 | iex
```

**Или локально:**

```powershell
git clone https://github.com/zhoel-sherk/pwshcode.git $env:USERPROFILE\pwshcode
cd $env:USERPROFILE\pwshcode
.\install.ps1
```

Инсталлятор сам покажет меню: выбор скиллов, настройка `$PROFILE`, установка winget-зависимостей.

## Что входит

| Компонент | Назначение |
|-----------|------------|
| `profile.ps1` | LLM-оптимизированный PowerShell 7 профиль: `state`, `deps`, `xray`, `inspect`, `cmds`, git-алиасы, навигация |
| `requirements-winget.txt` | CLI-зависимости (jq, delta, uv, just, yq, rg, fd, bat, eza, zoxide, gsudo, gh, starship) |
| `install.ps1` | **Интерактивный TUI-установщик** с меню и прогресс-баром |
| `skills/` | 6 скиллов для opencode |
| `Install-WingetRequirements.ps1` | Установка winget-пакетов из `requirements-winget.txt` |

## Скиллы

| Скилл | Описание |
|-------|----------|
| `pwsh-profile` | profile.ps1: state, deps, xray, inspect, cmds, venc, gd, zoxide, gsudo, quoting pitfalls |
| `python-env-manager` | .venv, ruff, pytest, mypy, uv, pip-audit, pre-commit, pyproject.toml, justfile |
| `pwsh-idioms` | PowerShell quoting, call operator, `$LASTEXITCODE`, stderr, UTF-8, splatting |
| `git-conventions` | Conventional commits, branch naming, PR workflow через gh |
| `just-recipes` | Justfile рецепты (format, lint, test, build, clean, commit) |
| `project-scaffold` | Шаблоны pyproject.toml, package.json, tsconfig.json, Justfile, .gitignore |

## Структура

```
pwshcode/
├── install.ps1                    # TUI-установщик (из сети или локально)
├── profile.ps1                    # PowerShell 7 профиль
├── Install-WingetRequirements.ps1 # Установка winget-пакетов
├── requirements-winget.txt        # Список winget-зависимостей
├── skills/
│   ├── python-env-manager/SKILL.md
│   ├── pwsh-profile/SKILL.md
│   ├── pwsh-profile/reference.md
│   ├── pwsh-idioms/SKILL.md
│   ├── git-conventions/SKILL.md
│   ├── just-recipes/SKILL.md
│   └── project-scaffold/SKILL.md
├── .gitignore
└── README.md
```

## Перед публикацией

Репозиторий: https://github.com/zhoel-sherk/pwshcode

## Лицензия

MIT
