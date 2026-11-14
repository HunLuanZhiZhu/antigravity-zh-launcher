# 进阶使用说明

[← 返回首页](../README.md) · [English](usage.en.md)

## 自定义中文思考提示词

如果你希望微调中文思考的语气、格式或额外约束，可以直接编辑提示词规则文件：

- **macOS**：`~/.gemini/config/plugins/antigravity-zh-prompt/rules/AGENTS.md`
- **Windows**：`%USERPROFILE%\.gemini\config\plugins\antigravity-zh-prompt\rules\AGENTS.md`

保存后，下次通过 **「Antigravity 中文」** 启动即可生效。

---

## 命令行快捷控制（可选）

安装时已自动配置 `agy-zh` 命令（macOS 与 Windows PowerShell/CMD 均可用），适合快速检查或命令行控制：

| 命令 | 说明 |
| :--- | :--- |
| `agy-zh start` | 以中文模式启动（效果与打开「Antigravity 中文」图标相同） |
| `agy-zh stop` | 停止汉化并关闭中文思考提示词 |
| `agy-zh status` | 查看快捷方式、提示词开关与运行状态 |
| `agy-zh prompt on \| off \| status` | 手动开启 / 关闭 / 查看中文思考提示词状态 |
| `agy-zh shortcut` | 重新生成「Antigravity 中文」图标 / 快捷方式 |

---

## 彻底清理卸载（含汉化引擎）

首页提供的标准卸载命令已能完整还原配置并移除中文入口，仅保留本地缓存的汉化二进制文件以备重装。如果你希望连同该文件一起彻底删除：

**macOS：**

```bash
curl -fsSL https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/uninstall.sh | bash -s -- --purge
```

**Windows (PowerShell)：**

```powershell
$env:AGY_ZH_PURGE='1'; irm https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/uninstall.ps1 | iex
```
