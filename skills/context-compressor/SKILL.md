---
name: context-compressor
description: >-
  PAKT-формат сжатия структурированных данных для LLM. Use when you see
  pipe-delimited content with @from json, @dict or @from csv markers, or when
  you need to decompress PAKT-encoded context. Requires context-compressor
  plugin. Keywords: pakt, compress, decompress, @dict, pipe-format, @from.
---

# Context Compressor (PAKT)

Tool outputs may be compressed using **PAKT** (Pipe-Aligned Kompact Text) — lossless, deterministic формат, который экономит токены за счёт pipe-delimited структуры и словаря.

## Распознавание

Сжатые данные выглядят так:

```
[PAKT@json]
@from json
@dict
$d: dev
@end
name|role|age:
Alice|$d|30
Bob|$d|25
```

Маркер `[PAKT@<format>]` показывает формат оригинала.

## Синтаксис

| Элемент | Описание | Пример |
|---------|----------|--------|
| `@from json\|csv\|md` | Исходный формат | `@from json` |
| `@dict ... @end` | Словарь алиасов | `$d: dev` |
| `$<letter>` | Алиас повторяющегося значения | `$d` вместо `dev` |
| `field1\|field2: val1\|val2` | Pipe-delimited строки | `name\|role: Alice\|dev` |

## Как читать PAKT

PAKT самодокументируем. Читайте его напрямую:

- **Словарь**: `$d: dev` → везде где `$d` — подставь `dev`
- **Заголовок**: `name|role|age:` — порядок полей
- **Строки**: каждая строка — одна запись, поля разделены `|`

## Decompress

Если нужно восстановить оригинал — вызовите инструмент **decompress**:

```
decompress(content: "[PAKT@json]\n@from json\nname|role:\nAlice|dev")
```

Но обычно читать PAKT можно напрямую — это lossless и модель понимает формат без декомпрессии.

## Markdown

Для .md файлов:
- Убирается разметка: `**bold**`→`bold`, `[link](url)`→`link`
- Таблицы переводятся в PAKT pipe-формат
- Код-блоки не трогаются

## Примеры

**JSON → PAKT:**
```json
[{"name":"Alice","role":"dev"},{"name":"Bob","role":"dev"}]
```
↓
```
@from json
@dict
$d: dev
@end
name|role:
Alice|$d
Bob|$d
```

**Markdown → PAKT:**
```markdown
| Name | Role |
|------|------|
| Alice | dev |
```
↓
```
@from md
Name|Role:
Alice|dev
```
