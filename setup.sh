#!/usr/bin/env bash
# 安装依赖：Python 虚拟环境 + MoneyPrinterTurbo 源码 + 中文字体。
# 幂等，可以反复运行。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MPT_DIR="$ROOT/MoneyPrinterTurbo"
PIP_INDEX="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
FONT_DIR="$MPT_DIR/resource/fonts"

echo "==> 安装目录: $ROOT"

# ---------- 1. Python 3.11+ ----------
PY_BIN="${PYTHON_BIN:-}"
if [ -z "$PY_BIN" ]; then
  for c in python3.12 python3.11 python3.13 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null; then
      PY_BIN="$c"
      break
    fi
  done
fi
[ -n "$PY_BIN" ] || { echo "需要 Python 3.11+，装好后再运行"; exit 1; }
echo "==> Python: $("$PY_BIN" -V 2>&1) ($PY_BIN)"

# ---------- 2. MoneyPrinterTurbo 源码 ----------
if [ -f "$MPT_DIR/cli.py" ] && [ -f "$MPT_DIR/config.example.toml" ]; then
  echo "==> MoneyPrinterTurbo 已存在，跳过下载"
else
  rm -rf "$MPT_DIR"
  clone_ok=0
  for repo in \
    "https://github.com/harry0703/MoneyPrinterTurbo.git" \
    "https://gitcode.com/gh_mirrors/mo/MoneyPrinterTurbo.git" \
    "https://gitee.com/mirrors/MoneyPrinterTurbo.git"; do
    echo "==> 尝试克隆: $repo"
    if GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=2000 -c http.lowSpeedTime=30 \
        clone --depth 1 "$repo" "$MPT_DIR" 2>/dev/null; then
      clone_ok=1
      break
    fi
    rm -rf "$MPT_DIR"
  done
  if [ "$clone_ok" != "1" ]; then
    echo "克隆失败。请手动下载 https://github.com/harry0703/MoneyPrinterTurbo 解压到:"
    echo "  $MPT_DIR"
    exit 1
  fi
fi

# ---------- 3. 虚拟环境与依赖 ----------
if [ ! -x "$MPT_DIR/.venv/bin/python" ]; then
  echo "==> 创建虚拟环境"
  "$PY_BIN" -m venv "$MPT_DIR/.venv"
fi
PY="$MPT_DIR/.venv/bin/python"
"$PY" -m pip install -q --upgrade pip -i "$PIP_INDEX"

echo "==> 安装依赖（首次约 3~5 分钟）"
# 只装 CLI 渲染需要的包；streamlit/fastapi/litellm/faster-whisper 是 WebUI 与 LLM 才用的
"$PY" -m pip install -q -i "$PIP_INDEX" \
  "moviepy==2.2.1" \
  "edge-tts==7.3.1" \
  "khatt[video]==0.4.0" \
  toml loguru requests pydub imageio-ffmpeg numpy pillow \
  pyyaml packaging filelock openai pydantic redis "PyJWT[crypto]"

# ---------- 4. 配置 ----------
[ -f "$MPT_DIR/config.toml" ] || cp "$MPT_DIR/config.example.toml" "$MPT_DIR/config.toml"

# ---------- 5. 中文字体 ----------
mkdir -p "$FONT_DIR"
FONT_NAME=""

copy_platform_font() {
  case "$(uname -s)" in
    Darwin)
      if [ -f "/System/Library/Fonts/STHeiti Medium.ttc" ]; then
        cp -f "/System/Library/Fonts/STHeiti Medium.ttc" "$FONT_DIR/STHeitiMedium.ttc"
      fi
      ;;
    Linux)
      if command -v fc-match >/dev/null 2>&1; then
        local f
        f="$(fc-match -f '%{file}' 'Noto Sans CJK SC:style=Bold' 2>/dev/null || true)"
        if [ -n "$f" ] && [ -f "$f" ]; then
          cp -f "$f" "$FONT_DIR/CJK-Bold.${f##*.}"
        fi
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if [ -f "/c/Windows/Fonts/msyhbd.ttc" ]; then
        cp -f "/c/Windows/Fonts/msyhbd.ttc" "$FONT_DIR/MicrosoftYaHeiBold.ttc"
      fi
      ;;
  esac
}

# 清掉不完整的历史字体（早期只下载了部分仓库时会留下截断文件）
if [ -f "$FONT_DIR/MicrosoftYaHeiBold.ttc" ]; then
  size="$(wc -c < "$FONT_DIR/MicrosoftYaHeiBold.ttc" | tr -d ' ')"
  if [ "$size" -lt 18000000 ]; then
    echo "==> 移除不完整的字体: MicrosoftYaHeiBold.ttc ($size bytes)"
    rm -f "$FONT_DIR/MicrosoftYaHeiBold.ttc"
  fi
fi

pick_font() {
  for cand in STHeitiMedium.ttc CJK-Bold.ttc CJK-Bold.ttf MicrosoftYaHeiBold.ttc; do
    if [ -f "$FONT_DIR/$cand" ]; then
      FONT_NAME="$cand"
      return 0
    fi
  done
  return 1
}

if ! pick_font; then
  copy_platform_font
  pick_font || true
fi

if [ -z "$FONT_NAME" ]; then
  echo "!! 没找到中文字体。请把一个 .ttc/.ttf 放进 $FONT_DIR 后重跑本脚本"
  exit 1
fi

# 确认字体真能渲染中文，避免拿到被截断或纯拉丁字体
if ! "$PY" - "$FONT_DIR/$FONT_NAME" <<'EOF'
import sys
from PIL import ImageFont
f = ImageFont.truetype(sys.argv[1], 24)
box = f.getbbox("中文")
sys.exit(0 if box and box[2] > box[0] else 1)
EOF
then
  echo "!! 字体无法渲染中文: $FONT_NAME"
  exit 1
fi

printf '%s\n' "$FONT_NAME" > "$ROOT/.font-name"
echo "==> 字幕字体: $FONT_NAME"

# ---------- 6. 自检 ----------
echo "==> 自检"
"$PY" - <<'EOF'
import edge_tts, moviepy, PIL, khatt
print("  依赖 OK")
EOF

echo ""
echo "安装完成。下一步:"
echo "  ./scripts/new-episode.sh 某期 \"标题\""
echo "  ./render.sh 某期"
