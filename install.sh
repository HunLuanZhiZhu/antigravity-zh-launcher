#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="${AGY_ZH_REPO_RAW:-https://raw.githubusercontent.com/guuguo/antigravity-zh-launcher/main}"
HANS_RELEASE_BASE="https://github.com/yuexps/Antigravity-Hans/releases/latest/download"
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
  --update-engine   即使本机已安装 antigravity-hans，也重新下载最新版并校验 SHA-256
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

for cmd in python3 curl shasum; do
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
HANS_BIN="$LOCAL_BIN/antigravity-hans"

if [[ "$UPDATE_ENGINE" == "false" && -x "$HANS_BIN" ]]; then
  echo "[信息] 检测到已安装的汉化引擎，直接复用: $HANS_BIN"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    arm64)
      ASSET_NAME="antigravity-hans-macos-arm64"
      ;;
    x86_64)
      ASSET_NAME="antigravity-hans-macos-amd64"
      ;;
    *)
      echo "[错误] 不支持的 macOS CPU 架构: $ARCH" >&2
      exit 1
      ;;
  esac

  if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="$(mktemp -d)"
  fi
  ENGINE_DIR="$TMP_DIR/engine"
  mkdir -p "$ENGINE_DIR"

  echo "[信息] 正在下载汉化引擎 ($ASSET_NAME) 并验证 SHA-256..."
  curl -fsSL --retry 2 --connect-timeout 15 "$HANS_RELEASE_BASE/$ASSET_NAME" -o "$ENGINE_DIR/$ASSET_NAME"
  curl -fsSL --retry 2 --connect-timeout 15 "$HANS_RELEASE_BASE/SHA256SUMS" -o "$ENGINE_DIR/SHA256SUMS"

  HASH_LINE="$(grep -E "[[:space:]]${ASSET_NAME}$" "$ENGINE_DIR/SHA256SUMS" || true)"
  if [[ -z "$HASH_LINE" ]]; then
    echo "[错误] 在官方 SHA256SUMS 中未找到 $ASSET_NAME 的校验和。" >&2
    exit 1
  fi
  (
    cd "$ENGINE_DIR"
    printf '%s\n' "$HASH_LINE" | shasum -a 256 -c -
  )

  mv -f "$ENGINE_DIR/$ASSET_NAME" "$HANS_BIN"
  chmod 755 "$HANS_BIN"
  xattr -c "$HANS_BIN" >/dev/null 2>&1 || true
  echo "[成功] 汉化引擎已安装至: $HANS_BIN"
fi

cp -f "$SOURCE_ROOT/bin/agy-zh" "$LOCAL_BIN/agy-zh"
chmod 755 "$LOCAL_BIN/agy-zh"
xattr -c "$LOCAL_BIN/agy-zh" >/dev/null 2>&1 || true
echo "[成功] 双入口编排 CLI 已安装至: $LOCAL_BIN/agy-zh"

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
