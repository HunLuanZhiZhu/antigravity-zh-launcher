#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="${AGY_ZH_REPO_RAW:-https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main}"
PLUGIN_NAME="antigravity-zh-prompt"
CONFIG_DIR="${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"
PLUGIN_DEST="$CONFIG_DIR/plugins/$PLUGIN_NAME"
LOCAL_BIN="$HOME/.local/bin"

UPDATE_ENGINE="false"
CREATE_SHORTCUT="true"

usage() {
  cat <<'EOF'
Antigravity 双入口中文启动器安装脚本 (macOS)

用法:
  ./install.sh [选项]

选项:
  --update-engine   强制重新拉取最新汉化词库脚本并重建增强覆盖脚本
  --no-shortcut     仅安装 CLI 与提示词插件，不生成「Antigravity 中文.app」
  -h, --help        显示帮助信息
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update-engine)
      UPDATE_ENGINE="true"
      shift
      ;;
    --no-shortcut)
      CREATE_SHORTCUT="false"
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[错误] install.sh 仅适用于 macOS。Windows 用户请使用 install.ps1。" >&2
  exit 1
fi

for cmd in python3 curl grep; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[错误] 缺少必需系统工具: $cmd" >&2
    exit 1
  fi
done

TMP_DIR=""
cleanup_tmp() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup_tmp EXIT

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

SOURCE_ROOT=""
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/bin/agy-zh" && -f "$SCRIPT_DIR/plugins/$PLUGIN_NAME/plugin.json" ]]; then
  SOURCE_ROOT="$SCRIPT_DIR"
  echo "[信息] 使用本地仓库源文件进行安装: $SOURCE_ROOT"
else
  TMP_DIR="$(mktemp -d)"
  SOURCE_ROOT="$TMP_DIR"
  echo "[信息] 正在从 GitHub 下载 antigravity-zh-launcher 套件文件..."
  mkdir -p \
    "$SOURCE_ROOT/bin" \
    "$SOURCE_ROOT/plugins/$PLUGIN_NAME/assets" \
    "$SOURCE_ROOT/plugins/$PLUGIN_NAME/rules"

  curl -fsSL --retry 2 --connect-timeout 15 "$REPO_RAW_BASE/bin/agy-zh" -o "$SOURCE_ROOT/bin/agy-zh"
  curl -fsSL --retry 2 --connect-timeout 15 "$REPO_RAW_BASE/plugins/$PLUGIN_NAME/plugin.json" -o "$SOURCE_ROOT/plugins/$PLUGIN_NAME/plugin.json"
  curl -fsSL --retry 2 --connect-timeout 15 "$REPO_RAW_BASE/plugins/$PLUGIN_NAME/assets/logo.svg" -o "$SOURCE_ROOT/plugins/$PLUGIN_NAME/assets/logo.svg"
  curl -fsSL --retry 2 --connect-timeout 15 "$REPO_RAW_BASE/plugins/$PLUGIN_NAME/rules/AGENTS.md" -o "$SOURCE_ROOT/plugins/$PLUGIN_NAME/rules/AGENTS.md"
fi

mkdir -p "$LOCAL_BIN"

# 清理旧版本遗留的第三方二进制，全面切换为内置零二进制 CDP 脚本引擎
if [[ -f "$LOCAL_BIN/antigravity-hans" ]]; then
  rm -f "$LOCAL_BIN/antigravity-hans"
  echo "[信息] 已移除旧版外部二进制: $LOCAL_BIN/antigravity-hans"
fi

cp -f "$SOURCE_ROOT/bin/agy-zh" "$LOCAL_BIN/agy-zh"
chmod 755 "$LOCAL_BIN/agy-zh"
xattr -c "$LOCAL_BIN/agy-zh" >/dev/null 2>&1 || true
echo "[成功] 双入口编排 CLI（内置纯脚本 CDP 引擎）已安装至: $LOCAL_BIN/agy-zh"

if [[ "$UPDATE_ENGINE" == "true" ]]; then
  "$LOCAL_BIN/agy-zh" build-overlay --force
else
  "$LOCAL_BIN/agy-zh" build-overlay
fi

mkdir -p "$PLUGIN_DEST/assets" "$PLUGIN_DEST/rules"
cp -f "$SOURCE_ROOT/plugins/$PLUGIN_NAME/plugin.json" "$PLUGIN_DEST/plugin.json"
cp -f "$SOURCE_ROOT/plugins/$PLUGIN_NAME/assets/logo.svg" "$PLUGIN_DEST/assets/logo.svg"
cp -f "$SOURCE_ROOT/plugins/$PLUGIN_NAME/rules/AGENTS.md" "$PLUGIN_DEST/rules/AGENTS.md"
echo "[成功] 全流程中文思考提示词插件已安装至: $PLUGIN_DEST"

"$LOCAL_BIN/agy-zh" prompt off >/dev/null
echo "[信息] 已确保插件默认保持关闭状态，原版 Antigravity 入口不受影响。"

if [[ "$CREATE_SHORTCUT" == "true" ]]; then
  "$LOCAL_BIN/agy-zh" shortcut
fi

if [[ ":${PATH}:" != *":${LOCAL_BIN}:"* ]]; then
  echo ""
  echo "[提示] $LOCAL_BIN 当前不在 PATH 中；如需在终端直接运行 agy-zh，请将其加入 shell 配置。"
fi

echo ""
echo "🎉 安装完成！"
echo "  • 原始英文入口：直接打开原版 Antigravity.app（保持原厂英文 UI 与原始提示词）"
echo "  • 独立中文入口：打开「应用程序 / 启动台 / Spotlight」中的「Antigravity 中文.app」，或运行 agy-zh start"
echo "  • 状态查询命令：agy-zh status"
