# 语言包维护

`index.json` 是语言元数据入口。每种语言声明原生名称、独立入口名称、命令、插件 ID 与 macOS bundle ID。zh-CN 的名称、ID 和路径保持旧版值。

每份 `<code>.json` 包含：

- `code`：与索引一致的语言代码。
- `phrases`：英文 UI 原文到译文的映射。九种语言必须使用相同的键，不允许空译文。键不能仅大小写不同，以兼容 Windows PowerShell 的 JSON 解析器；运行时统一处理大小写。
- `greetings`：七种欢迎语模板，顺序见 `lib/overlay.js` 的 `greetingPatterns`。`{name}` 保留原用户名。

目前每种语言包含 273 个词条及七种欢迎语模板。相对时间由 `Intl.RelativeTimeFormat` 按目标语言生成；工具状态只匹配明确的状态词与文件目标，不对任意正文做词语替换。

`plugins/<pluginName>/plugin.json` 与 `rules/AGENTS.md` 定义语言规则。安装器复用中文插件的公共 logo，默认禁用插件。启用一种语言时，只关闭本项目其他语言的插件，不修改第三方插件。

macOS 使用 `lib/locale.py`，Windows 使用 `lib/locale.ps1` 构建覆盖脚本。两者共享语言 JSON 和 `lib/overlay.js`。zh-CN 继续使用原上游词库及 `lib/zh-overlay.py` / `lib/zh-overlay.ps1` 中的兼容增强；其他语言无需下载中文词库。旧 `AGY_ZH_OVERLAY_URL` 仍仅控制简体中文上游。

语言可并存安装，但共享 Antigravity 进程与全局 Prompt 配置，不能同时让同一桌面会话显示多种语言。卸载按语言清理；最后一种语言卸载时再移除共享运行时。要恢复运行中已注入的界面，请退出该会话后打开原版入口。

运行 `python3 tests/test_launcher.py`、`node tests/overlay.test.js`；PowerShell 下另运行 `& .\tests\powershell.test.ps1`。离线测试验证完整词条集合、内容保护与还原、默认值、路径、插件互斥、安装共存与卸载。测试中的简体中文基础脚本使用最小 fixture 验证上游锚点失配时的既有降级逻辑；实际 Antigravity 版本的显示效果仍需人工验收。
