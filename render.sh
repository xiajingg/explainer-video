#!/usr/bin/env bash
# 把一期「文案 + 分比例图片」渲染成讲解视频。
#
# 目录约定：
#   某期/
#   ├── 标题.txt          # 第一行 = 成片文件名前缀
#   ├── 文案.txt          # 每行一段，一段约 15~20 秒（80~95 个汉字）
#   ├── 16x9/             # 横版图片
#   ├── 9x16/             # 竖版图片
#   └── 成片/
#       ├── 16x9/标题-16x9.mp4
#       └── 9x16/标题-9x16.mp4
#
# 用法:
#   ./render.sh <期目录>              # 渲染所有存在的比例目录
#   ./render.sh <期目录> 16x9         # 只渲染某一个比例
#
# 可选环境变量:
#   TITLE="标题"        覆盖 标题.txt / 目录名
#   AUTO_CLIP=0         关闭「按配音时长自动算每张图停留时间」
#   CLIP_SECONDS=18     手动指定每张图停留秒数（AUTO_CLIP=0 时生效）
#   VOICE=...           换音色，默认 zh-CN-YunxiNeural-Male
#   FONT=...            字幕字体文件名，默认读 .font-name
#   MPT_DIR=...         指定 MoneyPrinterTurbo 安装目录

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "用法: ./render.sh <期目录> [16x9|9x16|1x1]"
  exit 1
fi

EP_DIR="$1"
ONLY="${2:-}"
# 允许 9x16 / 16x9 / 1x1 这种写法，内部统一成 a:b
case "$ONLY" in
  9x16|9-16) ONLY="9:16" ;;
  16x9|16-9) ONLY="16:9" ;;
  1x1|1-1)   ONLY="1:1"  ;;
esac
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MPT_DIR="${MPT_DIR:-$SCRIPT_DIR/MoneyPrinterTurbo}"
PY="$MPT_DIR/.venv/bin/python"

EP_DIR="$(cd "$EP_DIR" && pwd)"
SCRIPT_FILE="$EP_DIR/文案.txt"
[ -f "$SCRIPT_FILE" ] || { echo "缺少文案: $SCRIPT_FILE"; exit 1; }
[ -x "$PY" ] || { echo "找不到 $PY，先运行 ./setup.sh"; exit 1; }

# ---- 标题：TITLE 环境变量 > 标题.txt 第一行 > 期目录名 ----
if [ -n "${TITLE:-}" ]; then
  RAW_TITLE="$TITLE"
elif [ -f "$EP_DIR/标题.txt" ]; then
  RAW_TITLE="$(head -n 1 "$EP_DIR/标题.txt" | tr -d '\r')"
else
  RAW_TITLE="$(basename "$EP_DIR")"
fi
RAW_TITLE="$(printf '%s' "$RAW_TITLE" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$RAW_TITLE" ] || { echo "标题为空：检查 标题.txt"; exit 1; }

# 文件名里不能出现路径分隔符，换成全角。
SAFE_TITLE="${RAW_TITLE//\//／}"
SAFE_TITLE="${SAFE_TITLE//\\/＼}"
if [ "$SAFE_TITLE" != "$RAW_TITLE" ]; then
  echo "提示: 标题含路径分隔符，文件名用全角替代 -> $SAFE_TITLE"
fi

# ---- 找出比例目录 ----
ASPECTS=()
DIRS=()
SEEN=""
for d in "$EP_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  case "$name" in
    *16x9*|*16-9*|*16:9*|*横版*|*横屏*) a="16:9" ;;
    *9x16*|*9-16*|*9:16*|*竖版*|*竖屏*) a="9:16" ;;
    *1x1*|*1-1*|*1:1*|*方版*|*方形*)  a="1:1"  ;;
    *) continue ;;
  esac
  if [ -n "$ONLY" ] && [ "$a" != "$ONLY" ]; then
    continue
  fi
  case "$SEEN" in
    *",$a,"*) echo "跳过重复的比例目录: $d"; continue ;;
  esac
  SEEN="$SEEN,$a,"
  ASPECTS+=("$a")
  DIRS+=("$d")
done

if [ ${#ASPECTS[@]} -eq 0 ]; then
  echo "没找到比例目录。请在 $EP_DIR 下建 16x9/ 或 9x16/ 并放入图片。"
  exit 1
fi

PARA_COUNT="$(grep -c '[^[:space:]]' "$SCRIPT_FILE" || true)"
echo "标题: $RAW_TITLE"
echo "文案: $PARA_COUNT 段"

cd "$MPT_DIR"

FONT_NAME="${FONT:-$(cat "$SCRIPT_DIR/.font-name" 2>/dev/null || echo STHeitiMedium.ttc)}"

render_one() {
  local aspect="$1" src="$2"
  local tag="${aspect//:/x}"
  local outdir="$EP_DIR/成片/$tag"
  mkdir -p "$outdir"

  local materials count
  materials="$(find "$src" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | sort | paste -sd, -)"
  if [ -z "$materials" ]; then
    echo "[$aspect] $src 里没有图片，跳过"
    return 0
  fi
  count="$(printf '%s' "$materials" | tr ',' '\n' | grep -c . || true)"
  echo "[$aspect] $count 张图片"
  if [ "$count" != "$PARA_COUNT" ]; then
    echo "  注意: 图片 $count 张 / 文案 $PARA_COUNT 段，数量不等，画面可能和旁白错位"
  fi

  # 每张图停留多久：先只跑配音拿总时长，再按图片数均分。
  local clip="${CLIP_SECONDS:-18}"
  if [ "${AUTO_CLIP:-1}" = "1" ]; then
    local audio_json dur
    audio_json="$("$PY" cli.py \
      --video-script "$(cat "$SCRIPT_FILE")" \
      --video-terms "占位1,占位2,占位3,占位4,占位5" \
      --video-source local \
      --video-materials "$materials" \
      --video-aspect "$aspect" \
      --voice-name "${VOICE:-zh-CN-YunxiNeural-Male}" \
      --bgm-type none \
      --stop-at audio 2>&1 | tail -n 1)"
    dur="$(printf '%s' "$audio_json" | "$PY" -c 'import sys,json; print(json.load(sys.stdin)["result"]["audio_duration"])' 2>/dev/null || true)"
    if [ -n "$dur" ] && [ "$dur" -gt 0 ] 2>/dev/null; then
      clip=$(( (dur + count - 1) / count ))
      echo "  配音 ${dur}s，每张图停留 ${clip}s"
    else
      echo "  配音时长获取失败，回退到 ${clip}s/张"
    fi
  fi

  local font_size=54
  [ "$aspect" = "9:16" ] && font_size=62
  [ "$aspect" = "1:1" ] && font_size=58

  local run_json task_id
  run_json="$("$PY" cli.py \
    --video-script "$(cat "$SCRIPT_FILE")" \
    --video-terms "占位1,占位2,占位3,占位4,占位5" \
    --video-source local \
    --video-materials "$materials" \
    --video-aspect "$aspect" \
    --video-fit-mode contain \
    --image-motion static \
    --match-materials-to-script \
    --video-clip-duration "$clip" \
    --video-transition-mode none \
    --voice-name "${VOICE:-zh-CN-YunxiNeural-Male}" \
    --bgm-type none \
    --subtitle-enabled \
    --font-name "$FONT_NAME" \
    --font-size "$font_size" \
    --n-threads 4 2>&1 | tail -n 1)"

  task_id="$(printf '%s' "$run_json" | "$PY" -c 'import sys,json; print(json.load(sys.stdin)["task_id"])' 2>/dev/null || true)"
  if [ -z "$task_id" ] || [ ! -f "storage/tasks/$task_id/final-1.mp4" ]; then
    echo "[$aspect] 渲染失败，最后一行输出："
    echo "$run_json"
    return 1
  fi

  cp "storage/tasks/$task_id/final-1.mp4" "$outdir/$SAFE_TITLE-$tag.mp4"
  echo "[$aspect] 成片: $outdir/$SAFE_TITLE-$tag.mp4"
}

failed=0
i=0
while [ $i -lt ${#ASPECTS[@]} ]; do
  render_one "${ASPECTS[$i]}" "${DIRS[$i]}" || failed=1
  i=$((i + 1))
done

exit $failed
