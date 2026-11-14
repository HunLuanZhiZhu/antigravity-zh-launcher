#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="antigravity-zh-prompt"
CONFIG_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"
CONFIG_FILE="$CONFIG_DIR/config.json"
PLUGIN_DEST="$CONFIG_DIR/plugins/$PLUGIN_NAME"
LOCAL_BIN="$HOME/.local/bin"
PURGE_ENGINE="false"

usage() {
  cat <<'EOF'
Antigravity 双入口中文启动器卸载脚本 (macOS)

用法:
  ./uninstall.sh [选项]

选项:
  --purge      一并删除 ~/.local/bin/antigravity-hans 底层汉化引擎
  -h, --help   显示帮助信息
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -x "$LOCAL_BIN/agy-zh" ]]; then
  "$LOCAL_BIN/agy-zh" stop >/dev/null 2>&1 || true
elif [[ -x "$LOCAL_BIN/antigravity-hans" ]]; then
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
  app="$AGY_ZH_APPS_DIR/Antigravity 中文.app"
  if [[ -d "$app" ]]; then
    rm -rf "$app"
    echo "[成功] 已删除中文启动应用: $app"
  fi
else
  for app in "/Applications/Antigravity 中文.app" "$HOME/Applications/Antigravity 中文.app"; do
    if [[ -d "$app" ]]; then
      rm -rf "$app"
      echo "[成功] 已删除中文启动应用: $app"
    fi
  done
fi

if [[ -f "$LOCAL_BIN/antigravity-hans-overlay.js" ]]; then
  rm -f "$LOCAL_BIN/antigravity-hans-overlay.js"
  echo "[成功] 已删除增强汉化覆盖脚本: $LOCAL_BIN/antigravity-hans-overlay.js"
fi

if [[ -f "$LOCAL_BIN/agy-zh" ]]; then
  rm -f "$LOCAL_BIN/agy-zh"
  echo "[成功] 已删除 CLI: $LOCAL_BIN/agy-zh"
fi

if [[ "$PURGE_ENGINE" == "true" && -f "$LOCAL_BIN/antigravity-hans" ]]; then
  rm -f "$LOCAL_BIN/antigravity-hans"
  echo "[成功] 已删除底层汉化引擎: $LOCAL_BIN/antigravity-hans"
fi

echo ""
echo "卸载完成。原版 Antigravity.app 及原有配置保持完整无损。"
