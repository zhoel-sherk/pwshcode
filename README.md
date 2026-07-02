# pwshcode

PowerShell 7 profile + opencode skills for AI coding agents on Windows.

## Что входит

| Компонент | Назначение |
|-----------|------------|
| `profile.ps1` | LLM-оптимизированный PowerShell 7 профиль: state/deps/xray/inspect, git-алиасы, навигация |
| `requirements-winget.txt` | Все CLI-зависимости (jq, delta, uv, just, yq, rg, fd, bat, eza, zoxide, gsudo, gh, starship) |
| `Install-WingetRequirements.ps1` | Скрипт установки зависимостей через winget |
| `skills/` | 6 открытых скиллов: pwsh-profile, python-env-manager, pwsh-idioms, git-conventions, just-recipes, project-scaffold |

## Быстрая установка

```powershell
# 1. Клонировать
git clone https://github.com/<user>/pwshcode.git %USERPROFILE%\pwshcode

# 2. Установить зависимости
.\Install-WingetRequirements.ps1

# 3. Установить профиль и скиллы
.\Install.ps1

# 4. Перезапустить opencode
```

## После установки

Добавить в `$PROFILE` (`%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`):

```powershell
. "$env:USERPROFILE\pwshcode\profile.ps1"
```

Проверить что скиллы загружены — открыть opencode, дать промпт с "python" или "pwsh" и убедиться что скиллы активируются.

## Структура

```
pwshcode/
├── profile.ps1                    # PowerShell 7 профиль
├── Install.ps1                    # Главный установщик
├── Install-WingetRequirements.ps1 # Установка winget-пакетов
├── requirements-winget.txt        # Список winget-зависимостей
├── skills/                        # opencode скиллы
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

## Скиллы

| Скилл | Описание |
|-------|----------|
| `pwsh-profile` | profile.ps1: state, deps, xray, inspect, cmds, venc, gd, zoxide, gsudo, quoting pitfalls |
| `python-env-manager` | .venv, ruff, pytest, mypy, uv, pip-audit, pre-commit, pyproject.toml, justfile |
| `pwsh-idioms` | PowerShell quoting, call operator, `$LASTEXITCODE`, stderr, UTF-8, splatting |
| `git-conventions` | Conventional commits, branch naming, PR workflow через gh |
| `just-recipes` | Кросспроектные just рецепты (format, lint, test, build, clean, commit) |
| `project-scaffold` | Шаблоны pyproject.toml, package.json, tsconfig.json, Justfile, .gitignore |

## Лицензия

MIT
