<div align="center">

# ⚡ pwshcode

**PowerShell 7 профиль + opencode skills для AI-агентов на Windows**

[![PowerShell](https://img.shields.io/badge/PowerShell-7.4+-5391FE?logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![opencode](https://img.shields.io/badge/opencode-ready-6C47FF?logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMTIgMkwyIDd2MTBsMTAgNSAxMC01VjdMMTIgMnoiIGZpbGw9IiM2QzQ3RkYiLz48L3N2Zz4=&labelColor=1a1b26)](https://opencode.ai)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Windows](https://img.shields.io/badge/OS-Windows%2011-00adef?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![GitHub release](https://img.shields.io/github/v/release/zhoel-sherk/pwshcode?color=bb9af7)](https://github.com/zhoel-sherk/pwshcode/releases)

```powershell
irm https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main/install.ps1 | iex
```

<a href="#quick-install">Быстрая установка</a> •
<a href="#features">Возможности</a> •
<a href="#prompts">Промипты</a> •
<a href="#skills">Скиллы</a> •
<a href="#structure">Структура</a>

</div>

---

## ✨ Зачем это?

AI-агенты (opencode, Claude Code, Cursor) часто тупят в PowerShell: неправильное quoting, потеря exit codes, проблемы с UTF-8, стучатся в `winget` без аргументов. **pwshcode** решает это:

- **6 opencode skills** — агент знает как работать с PowerShell, Python, Git
- **Интерактивный TUI-установщик** — выбор скиллов, промипта, настройка `$PROFILE`
- **Profile.ps1** — `state`, `deps`, `xray`, `inspect`, `cmds`, `venc`, `gd`
- **Два промипта на выбор** — Oh My Posh (tokyonight) или Starship (Tokyo Night)

---

<h2 id="quick-install">🚀 Быстрая установка</h2>

**Из сети (одна команда):**

```powershell
irm https://raw.githubusercontent.com/zhoel-sherk/pwshcode/main/install.ps1 | iex
```

**Или локально через git:**

```powershell
git clone https://github.com/zhoel-sherk/pwshcode.git $env:USERPROFILE\pwshcode
cd $env:USERPROFILE\pwshcode
.\install.ps1
```

---

<h2 id="features">🎮 Что делает установщик</h2>

<table>
<tr>
<td width="50%">

### 📋 Меню установки
- ✅ Проверка окружения (pwsh 7, winget, git, opencode)
- 📁 Выбор директории установки
- 👤 **Три режима `$PROFILE`**: добавить / заменить (с бэкапом) / позже
- 📦 **Выбор скиллов**: 7 штук, все включены по умолч.
- 🧠 **Context Compressor (PAKT)**: Auto / Manual / Off + настраиваемый порог сжатия
- 🎨 **Выбор промипта**: Oh My Posh / Starship / None
- 🔧 **Winget-зависимости**: jq, delta, uv, just, yq, rg, fd, zoxide, gsudo

</td>
<td width="50%">

### 🖥️ TUI-интерфейс
- Цветной ASCII-баннер
- **Радио-кнопки** (↑↓ + Enter)
- **Чекбоксы** (↑↓ + Space + Enter)
- **Прогресс-бары** при копировании
- Понятные ошибки с подсказками
- Fallback `git clone` если ZIP не скачался

</td>
</tr>
</table>

---

<h2 id="prompts">🎨 Промипты</h2>

Установщик предлагает выбрать промипт. Оба в стиле **Tokyo Night**:

| | Oh My Posh | Starship |
|---|---|---|
| **Тема** | `tokyonight_storm` | `Tokyo Night` (кастом) |
| **Сегменты** | path, git, status, node, python, go, ruby | user, dir, git, python, time |
| **Установка** | winget | уже в зависимостях |
| **Конфиг** | `prompt/omp-tokyonight.json` | `prompt/starship.toml` |
| **Admin-тема** | общая (красный статус root) | отдельный `starship-admin.toml` |

```powershell
# Автоопределение в profile.ps1: Oh My Posh → Starship → PS>
# Ничего настраивать не нужно — сам подхватит что установлено
```

---

<h2 id="skills">🧠 opencode skills</h2>

После установки агент в opencode автоматически подгружает скиллы по триггер-словам:

| Скилл | Триггеры | Что делает |
|-------|-----------|------------|
| `pwsh-profile` | pwsh, profile, state, deps, xray, venc, gd | Загружает profile.ps1, даёт команды `state -Json`, `xray`, `inspect` |
| `python-env-manager` | .py, python, venv, ruff, pytest, uv, pip-audit | .venv, ruff format/lint, pytest, mypy, uv, pre-commit, pyproject.toml |
| `pwsh-idioms` | powershell, quoting, LASTEXITCODE, stderr, splatting | Правильное quoting, call operator, UTF-8, exit codes |
| `git-conventions` | git, commit, branch, PR, gh, conventional commit | Conventional commits, branch naming, `gh pr create` |
| `just-recipes` | just, justfile, recipe | Justfile: format, lint, test, build, clean |
| `project-scaffold` | scaffold, template, init, boilerplate, new project | pyproject.toml, package.json, tsconfig.json, .gitignore |
| `context-compressor` | pakt, compress, decompress, @dict, @from, pipe-format | PAKT-сжатие JSON/YAML/CSV/MD, inline plugin (zero deps), decompress tool, до -50% токенов |

---

<h2 id="structure">📁 Структура репозитория</h2>

```
pwshcode/
├── install.ps1                      # 🚀 TUI-установщик (из сети или локально)
├── profile.ps1                      # ⚡ PowerShell 7 профиль (state/deps/xray)
├── Install-WingetRequirements.ps1   # 📦 Установка winget-пакетов
├── requirements-winget.txt          # 📋 Список зависимостей
│
├── prompt/                          # 🎨 Конфиги промипта
│   ├── init.ps1                     # Загрузчик: OMP → Starship → fallback
│   ├── starship.toml                # Starship: Tokyo Night
│   ├── starship-admin.toml          # Starship: Admin (красная тема)
│   └── omp-tokyonight.json          # Oh My Posh: Tokyo Night Storm
│
├── plugins/                         # 🔌 opencode plugin (context-compressor)
│   └── context-compressor.ts        #    inline PAKT, zero deps
├── skills/                          # 🧠 opencode skills (7 шт)
│   ├── python-env-manager/SKILL.md
│   ├── pwsh-profile/SKILL.md
│   ├── pwsh-profile/reference.md
│   ├── pwsh-idioms/SKILL.md
│   ├── git-conventions/SKILL.md
│   ├── just-recipes/SKILL.md
│   ├── project-scaffold/SKILL.md
│   └── context-compressor/SKILL.md
│
├── .gitignore
└── README.md
```

---

## 🔧 Зависимости (winget)

| Категория | Пакеты |
|-----------|--------|
| **Ядро** | `Microsoft.PowerShell`, `Git.Git`, `GitHub.cli`, `Starship.Starship` |
| **Утилиты** | `eza-community.eza`, `sharkdp.bat`, `BurntSushi.ripgrep.MSVC`, `sharkdp.fd` |
| **Agent tooling** | `jqlang.jq`, `dandavison.delta`, `astral-sh.uv`, `Casey.Just`, `MikeFarah.yq` |
| **Навигация** | `ajeetdsouza.zoxide`, `gerardog.gsudo` |
| **Промипт** | `JanDeDobbeleer.OhMyPosh` (устанавливается при выборе) |

```powershell
# Установить всё одной командой:
.\Install-WingetRequirements.ps1
```

---

## 📜 Лицензия

MIT © 2026 [zhoel-sherk](https://github.com/zhoel-sherk)

---

<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/zhoel-sherk/pwshcode?style=social)](https://github.com/zhoel-sherk/pwshcode)
[![GitHub forks](https://img.shields.io/github/forks/zhoel-sherk/pwshcode?style=social)](https://github.com/zhoel-sherk/pwshcode)

**Сделано с ❤️ для AI-агентов на Windows**

**PAKT (Pipe-Aligned Kompact Text)** — оригинальная концепция: [github.com/sriinnu/clipforge-PAKT](https://github.com/sriinnu/clipforge-PAKT)

</div>
