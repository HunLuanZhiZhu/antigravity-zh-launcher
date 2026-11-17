[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [繁體中文](README.zh-TW.md)

# Antigravity 多語言啟動器

為 Antigravity 提供獨立語言入口、介面翻譯與 AI 語言規則。不帶參數安裝時，仍使用 **zh-CN / Antigravity 中文**。保留既有 `agy-zh` 指令、快取與外掛路徑，不變更原版應用程式檔案。

## 安裝

請先安裝 Antigravity。macOS 需要 Bash、Python 3 與 curl；Windows 使用系統內建 Windows PowerShell 5.1。執行時不需要 Node.js。

從本機儲存庫安裝：

```bash
bash install.sh --lang zh-TW
```

```powershell
& .\install.ps1 --lang zh-TW
```

遠端安裝（繁體中文範例；省略參數則使用簡體中文）：

```bash
curl -fsSL https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/install.sh | bash -s -- --lang zh-TW
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/install.ps1))) --lang zh-TW
```

| Code | Language / 语言 | Entry | CLI |
| --- | --- | --- | --- |
| `zh-CN` | 简体中文（默认） | Antigravity 中文 | `agy-zh` |
| `zh-TW` | 繁體中文 | Antigravity 繁體中文 | `agy-zh-tw` |
| `ja` | 日本語 | Antigravity 日本語 | `agy-ja` |
| `ko` | 한국어 | Antigravity 한국어 | `agy-ko` |
| `es` | Español | Antigravity Español | `agy-es` |
| `fr` | Français | Antigravity Français | `agy-fr` |
| `de` | Deutsch | Antigravity Deutsch | `agy-de` |
| `ru` | Русский | Antigravity Русский | `agy-ru` |
| `pt-BR` | Português (Brasil) | Antigravity Português | `agy-pt-br` |

## 使用與解除安裝

可並存多種語言的獨立圖示。Antigravity 共用同一個桌面工作階段；切換語言時會停止上一個注入程式，僅啟用所選語言的外掛。結束本地化工作階段後會停用外掛。要回到原版英文，請先結束本地化工作階段，再開啟原版入口。

```bash
agy-zh --lang zh-TW start
agy-zh --lang zh-TW status
agy-zh --lang zh-TW prompt status
bash uninstall.sh --lang zh-TW --purge
```

```powershell
agy-zh --lang zh-TW start
& .\uninstall.ps1 --lang zh-TW --purge
```

預設只解除安裝簡體中文。`--lang` 只移除指定語言；最後一種語言移除後才會清理共用執行檔。`--purge` 同時清理對應快取，不會移除其他語言入口。

`--no-shortcut` · `--update-engine` · `--dry-run` · `--help`

Windows 也支援 `-Lang`、`-NoShortcut`、`-UpdateEngine`、`-DryRun`；原有 `AGY_ZH_*` 與 `GEMINI_CONFIG_DIR` 設定仍然有效。

## 架構與驗證

`locales/index.json` 統一定義語言、入口、指令與外掛名稱。九份 JSON 使用相同詞條鍵，涵蓋常用 IDE 操作、代理程式互動與工具狀態。歡迎語採用範本，相對時間使用 `Intl.RelativeTimeFormat`。

簡體中文保留原有上游詞庫與增強處理（`lib/zh-overlay.*`）；其他語言共用 `lib/overlay.js`。執行時注入會跳過程式碼編輯區、使用者輸入、對話標題與回覆本文。未收錄或未來新增的文字保留原文；這不是 Antigravity 官方語言套件。

語言外掛引導計畫、可呈現的思考說明、工具摘要與回覆使用目標語言，同時保留程式碼、路徑及原始錯誤訊息。模型是否遵循及內部思考語言由模型決定。

```bash
python3 tests/test_launcher.py
node tests/overlay.test.js
# Windows PowerShell: & .\tests\powershell.test.ps1
```

[MIT License](LICENSE) · [Upstream Chinese dictionary / 原有中文词库](https://github.com/yuexps/Antigravity-Hans) · [CLI details](docs/usage.en.md)
