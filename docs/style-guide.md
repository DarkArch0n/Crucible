# Crucible Style Guide

## Protoss Color Palette

Crucible uses a **Protoss-inspired** color scheme from StarCraft. All banners,
terminal output, and visual elements should adhere to this palette.

> *"My life for Aiur."*

### Terminal / ANSI Colors

| Role             | ANSI Code   | Color        | Usage                                      |
|------------------|-------------|--------------|---------------------------------------------|
| **Primary**      | `1;33m`     | Bold Gold    | Titles, labels, section headers              |
| **Frame/Banner** | `1;34m`     | Bold Blue    | Borders, banner art, structural elements     |
| **Psionic Glow** | `1;36m`     | Bold Cyan    | Subtitles, dynamic values, emphasis          |
| **Psi Text**     | `0;36m`     | Cyan         | Quotes, body text, informational messages    |
| **Neutral**      | `0;37m`     | White        | Variable data, secondary content             |
| **Warning**      | `1;31m`     | Bold Red     | Warning icons only (⚠) — use sparingly       |
| **Reset**        | `0m`        | —            | Always reset after color sequences            |

### Jinja2 Template Pattern

Use this pattern for ANSI colors in `.j2` templates:

```jinja2
{{ '\x1b' }}[1;33mGold text here{{ '\x1b' }}[0m
{{ '\x1b' }}[1;34mBlue text here{{ '\x1b' }}[0m
{{ '\x1b' }}[1;36mCyan text here{{ '\x1b' }}[0m
```

### PowerShell Colors

| Role             | `-ForegroundColor` | Usage                              |
|------------------|--------------------|------------------------------------|
| **Primary**      | `Yellow`           | Headers, labels, important output  |
| **Psionic**      | `Cyan`             | Status messages, confirmations     |
| **Neutral**      | `White`            | Body text, descriptions            |

### Colors to Avoid

These colors break the Protoss aesthetic and should **not** be used:

- `Green` — Zerg
- `Magenta` / `Purple` — doesn't fit the Khalai palette
- `Red` for text — only for warning icons (⚠)

### Protoss Quotes

Rotate these in banners and templates as appropriate:

- *"My life for Aiur."*
- *"En Taro Adun."*
- *"We cannot hold."*
- *"The Khala binds us."*
- *"Honor guide me."*
- *"Power overwhelming."*
