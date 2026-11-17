[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [繁體中文](README.zh-TW.md)

# Antigravity 多言語ランチャー

Antigravity に言語別の起動アイコン、UI 翻訳、AI の言語ルールを追加します。引数なしのインストールは従来どおり **zh-CN / Antigravity 中文** です。既存の `agy-zh` コマンドとパスを維持し、元のアプリのファイルは変更しません。

## インストール

先に Antigravity をインストールしてください。macOS では Bash、Python 3、curl、Windows では標準の Windows PowerShell 5.1 を使用します。実行時に Node.js は不要です。

ローカルリポジトリから：

```bash
bash install.sh --lang ja
```

```powershell
& .\install.ps1 --lang ja
```

リモートインストール（日本語。`--lang ja` を省略すると簡体字中国語）：

```bash
curl -fsSL https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/install.sh | bash -s -- --lang ja
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main/install.ps1))) --lang ja
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

## 起動とアンインストール

言語別のアイコンを共存できます。Antigravity のデスクトップセッションは共通のため、言語を切り替えると前の注入プロセスを停止し、選択した言語のルールだけを有効にします。終了時にはプラグインを無効にします。元の英語版に戻る場合は、翻訳セッションを終了してから元のアイコンで起動してください。

```bash
agy-zh --lang ja start
agy-zh --lang ja status
agy-zh --lang ja prompt status
bash uninstall.sh --lang ja --purge
```

```powershell
agy-zh --lang ja start
& .\uninstall.ps1 --lang ja --purge
```

引数なしでは簡体字中国語だけを削除します。`--lang` で削除する言語を指定してください。最後の言語を削除したときに共通ランタイムも削除します。`--purge` は該当するキャッシュも削除します。他の言語のアイコンは維持されます。

`--no-shortcut` · `--update-engine` · `--dry-run` · `--help`

Windows では `-Lang`、`-NoShortcut`、`-UpdateEngine`、`-DryRun` も使用できます。既存の `AGY_ZH_*` と `GEMINI_CONFIG_DIR` 設定も維持されます。

## 構成と検証

`locales/index.json` で言語、アイコン名、コマンド、プラグインを管理します。9 言語の JSON は共通の翻訳キーを持ち、基本的な IDE 操作、エージェント操作、ツールの状態を収録しています。挨拶はテンプレート、相対時刻は `Intl.RelativeTimeFormat` を使用します。

簡体字中国語は従来の上流辞書と補強処理（`lib/zh-overlay.*`）を維持し、他の言語は `lib/overlay.js` を共有します。コード、ユーザー入力、会話タイトル、回答本文は翻訳対象外です。未収録の文言や今後追加される UI は原文で表示されます。公式言語パックではありません。

言語ルールは計画、表示可能な推論の要約、ツールの要約、回答を日本語にするよう促します。コードやパス、元のエラーは保持します。モデルの遵守や内部の思考言語は保証されません。

```bash
python3 tests/test_launcher.py
node tests/overlay.test.js
# Windows PowerShell: & .\tests\powershell.test.ps1
```

[MIT License](LICENSE) · [Upstream Chinese dictionary / 原有中文词库](https://github.com/yuexps/Antigravity-Hans) · [CLI details](docs/usage.en.md)
