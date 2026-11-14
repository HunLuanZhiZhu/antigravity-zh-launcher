# Advanced Usage

[← Back to README](../README.en.md) · [简体中文](usage.md)

## Customize Chinese Thinking Prompts

To adjust the tone, formatting, or extra rules used for Chinese thinking and replies, edit the prompt rules file directly:

- **macOS**: `~/.gemini/config/plugins/antigravity-zh-prompt/rules/AGENTS.md`
- **Windows**: `%USERPROFILE%\.gemini\config\plugins\antigravity-zh-prompt\rules\AGENTS.md`

Changes take effect the next time you launch **Antigravity 中文**.

---

## Optional CLI Commands

The installer sets up the `agy-zh` command on both macOS and Windows (PowerShell / CMD) for quick checks or scripting:

| Command | Description |
| :--- | :--- |
| `agy-zh start` | Launch in Chinese mode (same as opening the **Antigravity 中文** icon) |
| `agy-zh stop` | Stop localization and turn off the Chinese prompt plugin |
| `agy-zh status` | Check shortcuts, prompt switch, and running state |
| `agy-zh prompt on \| off \| status` | Manually turn the Chinese prompt plugin on, off, or check its state |
| `agy-zh build-overlay` | Rebuild the enhanced UI localization overlay script |
| `agy-zh shortcut` | Recreate the **Antigravity 中文** shortcut / app entry |

---

## Full Purge Uninstall

The standard uninstall command on the home page cleanly restores your setup and removes the Chinese entry while keeping the cached translation binary for easy re-install. To remove everything including that binary:

**macOS:**

```bash
curl -fsSL https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/uninstall.sh | bash -s -- --purge
```

**Windows (PowerShell):**

```powershell
$env:AGY_ZH_PURGE='1'; irm https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/uninstall.ps1 | iex
```
