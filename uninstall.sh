#!/usr/bin/env bash
set -euo pipefail

LANG_CODE="zh-CN"
LOCAL_BIN="$HOME/.local/bin"
DATA_DIR="${AGY_ZH_DATA_DIR:-$LOCAL_BIN}"
ASSETS="$LOCAL_BIN/agy-i18n"
PURGE_ENGINE="false"
DRY_RUN=false

usage() {
  cat <<'EOF'
Antigravity 双入口中文启动器卸载脚本 (macOS)

用法:
  ./uninstall.sh [选项]

选项:
  --lang <code>  只卸载指定语言（默认 zh-CN）
  --dry-run      显示计划，不删除文件
  --purge      一并删除本地缓存的基础汉化词库脚本及日志
  -h, --help   显示帮助信息
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)
      [[ $# -ge 2 ]] || { echo "[错误] --lang 缺少语言代码" >&2; exit 1; }
      LANG_CODE="$2"; shift 2 ;;
    --lang=*) LANG_CODE="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --purge)
      PURGE_ENGINE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[错误] 未知参数: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Also works with legacy installations that do not have a locale manifest.
case "$LANG_CODE" in
  zh-CN) APP_NAME="Antigravity 中文"; COMMAND_NAME=agy-zh; PLUGIN_NAME=antigravity-zh-prompt ;;
  zh-TW) APP_NAME="Antigravity 繁體中文"; COMMAND_NAME=agy-zh-tw; PLUGIN_NAME=antigravity-zh-tw-prompt ;;
  ja) APP_NAME="Antigravity 日本語"; COMMAND_NAME=agy-ja; PLUGIN_NAME=antigravity-ja-prompt ;;
  ko) APP_NAME="Antigravity 한국어"; COMMAND_NAME=agy-ko; PLUGIN_NAME=antigravity-ko-prompt ;;
  es) APP_NAME="Antigravity Español"; COMMAND_NAME=agy-es; PLUGIN_NAME=antigravity-es-prompt ;;
  fr) APP_NAME="Antigravity Français"; COMMAND_NAME=agy-fr; PLUGIN_NAME=antigravity-fr-prompt ;;
  de) APP_NAME="Antigravity Deutsch"; COMMAND_NAME=agy-de; PLUGIN_NAME=antigravity-de-prompt ;;
  ru) APP_NAME="Antigravity Русский"; COMMAND_NAME=agy-ru; PLUGIN_NAME=antigravity-ru-prompt ;;
  pt-BR) APP_NAME="Antigravity Português"; COMMAND_NAME=agy-pt-br; PLUGIN_NAME=antigravity-pt-br-prompt ;;
  *) echo "[错误] 不支持的语言: $LANG_CODE" >&2; exit 1 ;;
esac
CONFIG_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"
CONFIG_FILE="$CONFIG_DIR/config.json"
PLUGIN_DEST="$CONFIG_DIR/plugins/$PLUGIN_NAME"
OVERLAY_FILE="$DATA_DIR/antigravity-$LANG_CODE-overlay.js"
if [[ "$LANG_CODE" == zh-CN ]]; then OVERLAY_FILE="$DATA_DIR/antigravity-hans-overlay.js"; fi
if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] 移除 $APP_NAME / $COMMAND_NAME / ${PLUGIN_DEST}；purge=$PURGE_ENGINE"
  exit 0
fi

if [[ -x "$LOCAL_BIN/agy-zh" ]]; then
  if [[ -d "$ASSETS" ]]; then
    "$LOCAL_BIN/agy-zh" --lang "$LANG_CODE" stop >/dev/null 2>&1 || true
  elif [[ "$LANG_CODE" == zh-CN ]]; then
    "$LOCAL_BIN/agy-zh" stop >/dev/null 2>&1 || true
  fi
elif [[ "$LANG_CODE" == zh-CN && -x "$LOCAL_BIN/antigravity-hans" ]]; then
  "$LOCAL_BIN/antigravity-hans" --stop --app >/dev/null 2>&1 || true
fi

if [[ -f "$CONFIG_FILE" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$CONFIG_FILE" "$PLUGIN_NAME" <<'PY'
import json
import os
import sys
import tempfile

config_file, plugin_name = sys.argv[1], sys.argv[2]
try:
    mode = os.stat(config_file).st_mode & 0o777
    with open(config_file, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

if not isinstance(data, dict):
    sys.exit(0)

plugins = data.get("plugins")
if isinstance(plugins, dict) and plugin_name in plugins:
    del plugins[plugin_name]
    config_dir = os.path.dirname(config_file)
    fd, tmp_path = tempfile.mkstemp(prefix=".config.", suffix=".tmp", dir=config_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        os.chmod(tmp_path, mode)
        os.replace(tmp_path, config_file)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise
PY
  echo "[成功] 已从 $CONFIG_FILE 移除 $PLUGIN_NAME 开关记录。"
fi

if [[ -d "$PLUGIN_DEST" ]]; then
  rm -rf "$PLUGIN_DEST"
  echo "[成功] 已删除提示词插件目录: $PLUGIN_DEST"
fi

if [[ -n "${AGY_ZH_APPS_DIR:-}" ]]; then
  app="$AGY_ZH_APPS_DIR/$APP_NAME.app"
  if [[ -d "$app" ]]; then
    rm -rf "$app"
    echo "[成功] 已删除中文启动应用: $app"
  fi
else
  for app in "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"; do
    if [[ -d "$app" ]]; then
      rm -rf "$app"
      echo "[成功] 已删除中文启动应用: $app"
    fi
  done
fi

if [[ -f "$OVERLAY_FILE" ]]; then
  rm -f "$OVERLAY_FILE"
  echo "[成功] 已删除增强汉化覆盖脚本: $OVERLAY_FILE"
fi

rm -f "$ASSETS/installed/$LANG_CODE"
if [[ "$COMMAND_NAME" != agy-zh ]]; then rm -f "$LOCAL_BIN/$COMMAND_NAME"; fi
rm -f "$HOME/Library/Logs/$COMMAND_NAME-cdp.pid"
if [[ "$PURGE_ENGINE" == true ]]; then rm -f "$HOME/Library/Logs/$COMMAND_NAME.log"; fi
# Other language commands depend on the common runtime. Remove it only last.
if [[ ! -d "$ASSETS/installed" || -z "$(ls -A "$ASSETS/installed")" ]]; then
  rm -f "$LOCAL_BIN/agy-zh"
  rm -rf "$ASSETS"
fi

if [[ "$PURGE_ENGINE" == "true" && "$LANG_CODE" == zh-CN ]]; then
  if [[ -f "$DATA_DIR/antigravity-hans-overlay.base.js" ]]; then
    rm -f "$DATA_DIR/antigravity-hans-overlay.base.js"
    echo "[成功] 已删除基础汉化词库脚本: $DATA_DIR/antigravity-hans-overlay.base.js"
  fi
  if [[ -f "$LOCAL_BIN/antigravity-hans" ]]; then
    rm -f "$LOCAL_BIN/antigravity-hans"
    echo "[成功] 已删除旧版残留二进制: $LOCAL_BIN/antigravity-hans"
  fi
  rm -f "$HOME/Library/Logs/agy-zh.log" "$HOME/Library/Logs/agy-zh-cdp.pid" "$HOME/Library/Logs/antigravity-hans.log"
fi

echo ""
echo "卸载完成。原版 Antigravity.app 及原有配置保持完整无损。"
